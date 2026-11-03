#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import contextlib
import io
import json
import os
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
colab_ssh = load('colab-ssh-config')
agentsview = load('agentsview-start')


class MigrationTests(unittest.TestCase):
    def test_colab_endpoint_validation_and_custom_config_preservation(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home/'.ssh').mkdir()
            (home/'.ssh/1password-colab.pub').write_text('ssh-ed25519 cHVibGlj\n')
            for hostname in ['bad.com', 'a.trycloudflare.com\nProxyCommand bad', '-oProxyCommand=bad']:
                with self.assertRaises(ValueError):
                    colab_ssh.configure(hostname, home, '/nix/store/test/bin/cloudflared')
            colab_ssh.configure('first.trycloudflare.com', home, '/nix/store/test/bin/cloudflared')
            target = home/'.ssh/config.d/30-colab.conf'
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            colab_ssh.configure('second.trycloudflare.com', home, '/nix/store/test/bin/cloudflared')
            self.assertIn('second.trycloudflare.com', target.read_text())
            self.assertIn('StrictHostKeyChecking ask', target.read_text())
            target.write_text('custom routing')
            with self.assertRaises(ValueError):
                colab_ssh.configure('third.trycloudflare.com', home, '/nix/store/test/bin/cloudflared')
            self.assertEqual(target.read_text(), 'custom routing')

    def test_hpc_effective_routing_and_existing_trusted_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)/'config'
            config.write_text((ROOT/'config/migration/ssh-hosts.conf').read_text() + '\nHost *\n  IdentityAgent /tmp/test-agent.sock\n')
            for host, alias in [('ganymede2','ganymede2.circ.utdallas.edu'),('juno','juno.hpcre.utdallas.edu')]:
                result = subprocess.run(['/usr/bin/ssh','-G','-F',str(config),host], capture_output=True,text=True,check=True)
                settings = dict(line.split(' ',1) for line in result.stdout.splitlines())
                self.assertEqual(settings['proxyjump'],'oracle-ts')
                self.assertEqual(settings['hostkeyalias'],alias)
                self.assertEqual(settings['identityagent'],'/tmp/test-agent.sock')
                self.assertEqual(settings['identityfile'],'~/.ssh/1password-hpc.pub')
                self.assertEqual(settings['stricthostkeychecking'],'true')
                self.assertEqual(settings['forwardagent'],'no')
                found = subprocess.run(['/usr/bin/ssh-keygen','-F',alias,'-f',str(ROOT/'config/migration/known_hosts')],capture_output=True)
                self.assertEqual(found.returncode,0)

    def test_agentsview_waits_for_tailscale_and_uses_destination_address(self):
        for data in [{'BackendState':'NeedsLogin'}, {'BackendState':'Running','Self':{'TailscaleIPs':['192.168.1.1']}}]:
            with patch.object(agentsview.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout=json.dumps(data))):
                with self.assertRaises(ValueError):agentsview.tailscale_address('/fake/tailscale')
        data={'BackendState':'Running','Self':{'TailscaleIPs':['100.100.100.100']}}
        with patch.object(agentsview.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout=json.dumps(data))):
            self.assertEqual(agentsview.tailscale_address('/fake/tailscale'),'100.100.100.100')

    def test_agentsview_start_isolated_state_and_no_vault_access(self):
        with tempfile.TemporaryDirectory() as tmp:
            home=Path(tmp)
            old=home/'.agentsview/config.toml'
            old.parent.mkdir();old.write_text('original config')
            previous_umask=os.umask(0o077)
            try:
                with patch.object(sys,'argv',['agentsview-start','/fake/agentsview','/fake/tailscale']), patch.object(agentsview.Path,'home',return_value=home), patch.object(agentsview,'tailscale_address',return_value='100.100.100.100'), patch.dict(os.environ,{'AGENTSVIEW_AUTH_TOKEN':'synthetic old token'},clear=True), patch.object(agentsview.os,'execv') as execute:
                    agentsview.main()
                    args=execute.call_args.args[1]
                    self.assertIn('--require-auth',args)
                    self.assertIn('--no-sync',args)
                    self.assertIn('100.100.100.100',args)
                    self.assertEqual(os.environ['AGENTSVIEW_DATA_DIR'],str(home/'.local/share/agentsview-nix'))
                    self.assertNotIn('AGENTSVIEW_AUTH_TOKEN',os.environ)
                    cfg=home/'.local/share/agentsview-nix/config.toml'
                    self.assertEqual(cfg.stat().st_mode & 0o777,0o600)
                    cfg.write_text('require_auth = true\n# retained edit\n')
                    agentsview.main()
                    self.assertIn('retained edit',cfg.read_text())
                    self.assertEqual(old.read_text(),'original config')
            finally:
                os.umask(previous_umask)

    def test_verification_reports_missing_keys_without_vault_or_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            home=Path(tmp)
            with patch.object(setup.Path,'home',return_value=home), patch.object(setup.shutil,'which',return_value=None), patch.object(setup.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout='')) as run, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(setup.verify(ROOT),2)
                run.assert_called_once()
                self.assertEqual(run.call_args.args[0][:2],['/bin/launchctl','print'])
            report=json.loads((home/'.local/state/mac-bootstrap/verification.json').read_text())
            self.assertFalse(report['vaultQueried'])
            self.assertTrue(any('hpc: mapped public key' in x for x in report['pending']))
            self.assertTrue(any('Google OAuth' in x for x in report['manual']))

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
            root = home/'repo'
            directory = root/'config/migration'
            directory.mkdir(parents=True)
            (directory/'credentials.json').write_text('{"githubSshPublicKey":"op://vault/github/public_key","additionalSshPublicKeys":{"colab":"op://vault/colab/public_key","hpc":"op://hermes/hpc/public_key"}}')
            response = SimpleNamespace(returncode=0, stdout='[[colab]]\nssh-ed25519 Y29sYWI= colab-comment\n[[/colab]]\n[[hpc]]\nssh-ed25519 aHBj hpc-comment\n[[/hpc]]\n[[github]]\nssh-ed25519 cHVibGlj test-comment\n\n[[/github]]\n')
            with patch.object(setup.Path, 'home', return_value=home), patch.object(setup.shutil, 'which', return_value='/fake/op'), patch.object(setup.subprocess, 'run', return_value=response) as run:
                self.assertTrue(setup.restore_github_identity(root))
                run.assert_called_once()
                args = run.call_args.args[0]
                self.assertEqual(args, ['/fake/op', 'inject'])
                template = run.call_args.kwargs['input']
                self.assertIn('/public_key', template)
                self.assertNotIn('/private_key', template)
                self.assertIn('op://vault/colab/public_key', template)
                self.assertIn('op://hermes/hpc/public_key', template)
                self.assertEqual((home/'.ssh/1password-colab.pub').read_text(), 'ssh-ed25519 Y29sYWI=\n')
                self.assertEqual((home/'.ssh/1password-hpc.pub').read_text(), 'ssh-ed25519 aHBj\n')
                key = home/'.ssh/1password-github.pub'
                self.assertEqual(key.read_text(), 'ssh-ed25519 cHVibGlj\n')
                self.assertEqual(key.stat().st_mode & 0o777, 0o600)
                config = home/'.ssh/config.d/10-github.conf'
                config.write_text('user routing')
                self.assertFalse(setup.restore_github_identity(root))
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
