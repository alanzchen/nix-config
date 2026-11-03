#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
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


class MigrationTests(unittest.TestCase):
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
