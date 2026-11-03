#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT/'scripts'/f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


setup = load('setup-user')
secrets = load('with-secrets')
imports = load('import-credentials')


class MigrationTests(unittest.TestCase):
    def test_encrypted_import_keeps_original_key_unchanged(self):
        try:
            from cryptography.hazmat.primitives import serialization
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        except ImportError:
            self.skipTest('Run with credential-python to test encrypted imports')
        with tempfile.TemporaryDirectory() as tmp:
            key = Ed25519PrivateKey.generate()
            encrypted = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.OpenSSH, serialization.BestAvailableEncryption(b'test passphrase'))
            path = Path(tmp)/'key'
            path.write_bytes(encrypted)
            public = key.public_key().public_bytes(serialization.Encoding.OpenSSH,serialization.PublicFormat.OpenSSH)
            Path(str(path)+'.pub').write_bytes(public)
            plan = {'tag':'test','sshKeys':[{'title':'encrypted','path':str(path),'passphraseReference':'op://vault/item/password'}]}
            self.assertTrue(imports.encrypted_openssh(encrypted))
            items = imports.prepare_items(plan,set(),lambda ref: b'test passphrase')
            restored = serialization.load_ssh_private_key(items[0]['fields'][0]['value'].encode(),password=None)
            self.assertEqual(restored.public_key().public_bytes(serialization.Encoding.OpenSSH,serialization.PublicFormat.OpenSSH),public)
            self.assertEqual(path.read_bytes(),encrypted)
            with self.assertRaises(ValueError):
                imports.prepare_items(plan,set(),lambda ref: b'wrong passphrase')
            self.assertEqual(path.read_bytes(),encrypted)

    def test_import_preview_never_calls_onepassword(self):
        with patch.object(sys, 'argv', ['import-credentials']), patch.object(imports.subprocess, 'run') as run:
            imports.main()
            run.assert_not_called()

    def test_import_builds_only_missing_items(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'key'
            path.write_text('synthetic test material')
            Path(str(path)+'.pub').write_text('ssh-ed25519 cHVibGlj test')
            plan = {'tag':'test', 'sshKeys':[{'title':'existing','path':'/does/not/exist'}, {'title':'new','path':str(path)}]}
            with patch.object(imports.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='ssh-ed25519 cHVibGlj\n')) as run:
                items = imports.prepare_items(plan, {'existing'})
                self.assertEqual(len(items),1)
                self.assertEqual(items[0]['title'],'new')
                self.assertEqual(items[0]['fields'][0]['value'],'synthetic test material')
                self.assertNotIn('synthetic test material',str(run.call_args.args))

    def test_import_response_parser_accepts_stream_or_array(self):
        self.assertEqual(imports.decode_objects('{"id":"a"}\n{"id":"b"}'),[{'id':'a'},{'id':'b'}])
        self.assertEqual(imports.decode_objects('[{"id":"a"}]'),[{'id':'a'}])

    def test_github_setup_exports_only_public_key_and_preserves_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            response = SimpleNamespace(returncode=0, stdout='[[github]]\nssh-ed25519 cHVibGlj test-comment\n\n[[/github]]\n')
            with patch.object(setup.Path, 'home', return_value=home), patch.object(setup.shutil, 'which', return_value='/fake/op'), patch.object(setup.subprocess, 'run', return_value=response) as run:
                self.assertTrue(setup.restore_github_identity(ROOT))
                args = run.call_args.args[0]
                self.assertEqual(args, ['/fake/op', 'inject'])
                template = run.call_args.kwargs['input']
                self.assertIn('/public_key', template)
                self.assertNotIn('/private_key', template)
                key = home/'.ssh/1password-github.pub'
                self.assertEqual(key.read_text(), 'ssh-ed25519 cHVibGlj\n')
                self.assertEqual(key.stat().st_mode & 0o777, 0o600)
                config = home/'.ssh/config.d/10-github.conf'
                config.write_text('user routing')
                self.assertFalse(setup.restore_github_identity(ROOT))
                self.assertEqual(config.read_text(), 'user routing')

    def test_github_setup_rejects_private_key_reference_before_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            directory = root/'config/migration'
            directory.mkdir(parents=True)
            (directory/'credentials.json').write_text('{"githubSshPublicKey":"op://vault/item/private_key"}')
            with patch.object(setup.shutil,'which',return_value='/fake/op'), patch.object(setup.subprocess,'run') as run:
                with self.assertRaises(ValueError):
                    setup.restore_github_identity(root)
                run.assert_not_called()

    def test_github_setup_treats_declined_authorization_as_pending(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            with patch.object(setup.Path,'home',return_value=home), patch.object(setup.shutil,'which',return_value='/fake/op'), patch.object(setup.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout='')):
                self.assertFalse(setup.restore_github_identity(ROOT))
                self.assertFalse((home/'.ssh').exists())

    def test_seed_preserves_changes_and_dangling_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src, dst = root/'source', root/'target'
            src.write_text('template')
            self.assertTrue(setup.seed(src, dst))
            dst.write_text('user edits')
            self.assertFalse(setup.seed(src, dst))
            self.assertEqual(dst.read_text(), 'user edits')
            dst.unlink()
            dst.symlink_to(root/'missing')
            self.assertFalse(setup.seed(src, dst))
            self.assertTrue(dst.is_symlink())

    def test_secret_file_allows_references_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp)/'refs.env'
            for value in ['TOKEN=op://vault/item/field', 'TOKEN="op://My Vault/My Item/token"']:
                file.write_text(value)
                secrets.reference_file(file)
            for value in ['TOKEN=plaintext', 'TOKEN=$(command)', 'TOKEN="op://vault/$(command)/field"', 'TOKEN=op://vault', '# empty']:
                file.write_text(value)
                with self.assertRaises(ValueError):
                    secrets.reference_file(file)

    def test_secret_wrapper_does_not_expand_or_shell_execute(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp)/'refs.env'
            file.write_text('TOKEN=op://vault/item/field')
            with patch.object(sys, 'argv', ['with-secrets', str(file), 'program', 'literal; argument']), patch.object(secrets.shutil, 'which', return_value='/fake/op'), patch.object(secrets.os, 'execv') as execute:
                secrets.main()
                execute.assert_called_once_with('/fake/op', ['/fake/op','run','--env-file',str(file.resolve()),'--','program','literal; argument'])

    def test_preview_does_not_change_identity(self):
        path = ROOT/'hosts/personal-new/identity.json'
        before = path.read_bytes()
        result = subprocess.run(['bash',str(ROOT/'scripts/bootstrap-mac.sh'),'--plan'], capture_output=True,text=True)
        self.assertEqual(result.returncode,0)
        self.assertIn('no changes made', result.stdout)
        self.assertEqual(path.read_bytes(),before)

    def test_identity_uses_new_machine_not_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'hosts/personal-new').mkdir(parents=True)
            with patch.object(setup.getpass,'getuser',return_value='newuser'), patch.object(setup.Path,'home',return_value=Path('/Users/newuser')), patch.object(setup.subprocess,'check_output',side_effect=['new-mac\n','New Mac\n']):
                setup.identity(root)
            data = setup.json.loads((root/'hosts/personal-new/identity.json').read_text())
            self.assertEqual(data,dict(username='newuser',hostName='new-mac',computerName='New Mac'))


if __name__ == '__main__':
    unittest.main()
