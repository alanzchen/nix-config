#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('installer', Path(__file__).resolve().parents[1]/'install-winmux.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root/'source.app'
        self.source.mkdir()
        (self.source/'binary').write_bytes(b'app executable')
        (self.source/'binary').chmod(0o755)
        # Model framework aliases, including a loop; do not follow them.
        (self.source/'alias').symlink_to('binary')
        (self.source/'loop').symlink_to('.')
        self.target = self.root/'WinMux.app'

    def test_identical_read_only_bundle_never_copied(self):
        shutil.copytree(self.source, self.target, symlinks=True)
        (self.target/'binary').chmod(0o555)
        with patch.object(installer, 'verify_signature') as verify, patch.object(installer.subprocess, 'run') as run:
            installer.install(self.source, self.target)
            run.assert_not_called()
            self.assertEqual(verify.call_count, 2)

    def test_different_or_symlink_target_preserved(self):
        self.target.symlink_to(self.source, target_is_directory=True)
        with patch.object(installer, 'verify_signature'), self.assertRaises(ValueError):
            installer.install(self.source, self.target)
        self.target.unlink()
        shutil.copytree(self.source, self.target, symlinks=True)
        (self.target/'binary').write_bytes(b'newer app')
        with patch.object(installer, 'verify_signature'), self.assertRaises(ValueError):
            installer.install(self.source, self.target)
        self.assertEqual((self.target/'binary').read_bytes(), b'newer app')

    def test_first_install_validated_and_retry_has_no_write(self):
        def copy(command, **kwargs):
            shutil.copytree(command[1], command[2], symlinks=True)
        with patch.object(installer, 'verify_signature'), patch.object(installer.subprocess, 'run', side_effect=copy) as run:
            installer.install(self.source, self.target)
            installer.install(self.source, self.target)
            self.assertEqual(run.call_count, 1)
        self.assertEqual(installer.bundle_manifest(self.source), installer.bundle_manifest(self.target))

    def test_failed_staged_signature_leaves_target_absent(self):
        def copy(command, **kwargs):
            shutil.copytree(command[1], command[2], symlinks=True)
        with patch.object(installer, 'verify_signature', side_effect=[None, ValueError('bad signature')]), \
             patch.object(installer.subprocess, 'run', side_effect=copy), self.assertRaises(ValueError):
            installer.install(self.source, self.target)
        self.assertFalse(self.target.exists())


if __name__ == '__main__':
    unittest.main()
