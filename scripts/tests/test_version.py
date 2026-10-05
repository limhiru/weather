import shutil
import subprocess
import tempfile
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class VersionTests(unittest.TestCase):
    def test_commits_sync_versions_and_tag(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for file in ['scripts/version.py','.githooks/pre-commit','.githooks/post-commit','VERSION','android_app/pubspec.yaml','android_app/lib/version.dart','ios_app/project.yml','ios_app/Weather.xcodeproj/project.pbxproj']:
                target=root/file
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(ROOT/file,target)
            def git(*args): return subprocess.run(['git',*args],cwd=root,capture_output=True,text=True,check=True)
            git('init','-b','main')
            git('config','user.name','Version Test')
            git('config','user.email','version-test@example.invalid')
            git('config','core.hooksPath','.githooks')
            git('add','.')
            git('commit','-m','initial')
            self.assertEqual((root/'VERSION').read_text().strip(),'1.0.0')
            self.assertEqual(git('tag').stdout.strip(),'v1.0.0')
            (root/'change.txt').write_text('next commit')
            git('add','change.txt')
            git('commit','-m','second')
            self.assertEqual((root/'VERSION').read_text().strip(),'1.0.1')
            self.assertIn('version: 1.0.1+2',(root/'android_app/pubspec.yaml').read_text())
            self.assertIn('MARKETING_VERSION = 1.0.1;', (root/'ios_app/Weather.xcodeproj/project.pbxproj').read_text())
            self.assertIn('v1.0.1',git('tag').stdout)
            subprocess.run(['python3','scripts/version.py','--check'],cwd=root,check=True,capture_output=True)
            # Refuse to accidentally include unstaged changes to version-managed files.
            with (root/'android_app/pubspec.yaml').open('a') as handle: handle.write('\n# unstaged\n')
            (root/'change.txt').write_text('third commit')
            git('add','change.txt')
            result=subprocess.run(['git','commit','-m','must refuse partial file'],cwd=root,capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual((root/'VERSION').read_text().strip(),'1.0.1')

if __name__ == '__main__': unittest.main()
