"""Compile real commands with the self-hosted compiler, then exercise their CLI contracts."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
S_ROOT = Path(os.environ.get('S_REPO_ROOT', ROOT.parent / 's'))
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', S_ROOT / '.bootstrap/native-imports/stage4'))


class NativeCommands(unittest.TestCase):
    def compile(self, name, output):
        sources = [ROOT / 'src/runtime/command/command.s']
        if name == 'train':
            sources.append(ROOT / 'src/training/api/contracts.s')
        sources.append(ROOT / 'cmd' / name / 'main.s')
        assembly = output.with_suffix('.sasm')
        result = subprocess.run([str(COMPILER), '--compile-unit', str(assembly), *map(str, sources)], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run([str(COMPILER), '--emit-bin', str(assembly), str(output)], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_train_rejects_missing_job_id(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / 'train'
            self.compile('train', executable)
            environment = {k: v for k, v in os.environ.items() if not k.startswith('NEURX_')}
            result = subprocess.run([str(executable)], env=environment, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn('missing_job_id', result.stdout)

    def test_benchmark_rejects_missing_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / 'benchmark'
            self.compile('benchmark', executable)
            environment = {k: v for k, v in os.environ.items() if not k.startswith('NEURX_')}
            result = subprocess.run([str(executable)], env=environment, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn('required', result.stdout)

    def test_benchmark_propagates_child_exit_and_quotes_path(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            executable = folder / 'benchmark'
            self.compile('benchmark', executable)
            child = folder / "measure ' quoted $(touch injected)"
            child.write_text('#!/bin/sh\nexit 23\n')
            child.chmod(0o755)
            environment = {k: v for k, v in os.environ.items() if not k.startswith('NEURX_')}
            environment.update(NEURX_BENCHMARK_BIN=str(child), NEURX_BENCHMARK_ENGINE='neurx',
                               NEURX_BENCHMARK_OUTPUT=str(folder / 'result.json'), NEURX_MODEL='fixture',
                               NEURX_BENCHMARK_REPETITIONS='3')
            result = subprocess.run([str(executable)], cwd=folder, env=environment, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
            self.assertIn('measurement failed', result.stdout)
            self.assertFalse((folder / 'injected').exists())

    def test_train_launches_make_in_quoted_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            executable = folder / 'train'
            self.compile('train', executable)
            project = folder / "project ' quoted"
            project.mkdir()
            (project / 'makefile').write_text('pretrain-gpu:\n\t@printf launched > marker\n')
            environment = {k: v for k, v in os.environ.items() if not k.startswith('NEURX_')}
            environment.update(NEURX_JOB_ID='native-test', NEURX_MODEL='fixture', NEURX_DATASET='fixture',
                               NEURX_BACKEND='cpu', NEURX_MAX_STEPS='10', NEURX_CHECKPOINT_INTERVAL='5',
                               WORLD_SIZE='1', NEURX_ROOT=str(project))
            result = subprocess.run([str(executable)], env=environment, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((project / 'marker').read_text(), 'launched')

    def test_benchmark_writes_and_validates_measurement(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            executable = folder / 'benchmark'
            self.compile('benchmark', executable)
            child = folder / "measure ' quoted"
            child.write_text("#!/bin/sh\nprintf '{\"ok\":true}' > \"$NEURX_BENCHMARK_OUTPUT\"\n")
            child.chmod(0o755)
            validator = folder / "validate ' quoted.js"
            validator.write_text('const fs = require("fs"); if (JSON.parse(fs.readFileSync(process.argv[2], "utf8")).ok !== true) process.exit(1);')
            result_path = folder / "result ' quoted.json"
            environment = {k: v for k, v in os.environ.items() if not k.startswith('NEURX_')}
            environment.update(NEURX_BENCHMARK_BIN=str(child), NEURX_BENCHMARK_ENGINE='neurx',
                               NEURX_BENCHMARK_OUTPUT=str(result_path), NEURX_MODEL='fixture',
                               NEURX_BENCHMARK_VALIDATOR=str(validator), NEURX_BENCHMARK_REPETITIONS='3')
            result = subprocess.run([str(executable)], env=environment, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result_path.read_text(), '{"ok":true}')
            self.assertIn('measured result:', result.stdout)


class NativeBuild(unittest.TestCase):
    def test_builds_train_with_project_imports(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--commands', 'train',
                                     '--output-dir', str(output)], capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(output / 'train')], env={}, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2)
            self.assertIn('missing_job_id', result.stdout)

    def test_missing_import_fails_and_removes_stale_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / 'cmd/train').mkdir(parents=True)
            (project / 'cmd/train/main.s').write_text('package main\nimport ("neurx.missing")\nfunc main() int { return 0 }\n')
            output = project / 'output'
            output.mkdir()
            (output / 'train').write_text('stale binary')
            result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--commands', 'train',
                                     '--project-root', str(project), '--output-dir', str(output)],
                                    capture_output=True, text=True, timeout=60)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('neurx.missing', result.stdout + result.stderr)
            self.assertFalse((output / 'train').exists())

    def test_unavailable_compiler_invalidates_previous_build(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            (output / 'train').write_text('stale binary')
            (output / 'manifest.json').write_text('{"results":[{"command":"train","status":"built"}]}')
            result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--commands', 'train',
                                     '--compiler', str(output / 'missing-compiler'), '--output-dir', str(output)],
                                    capture_output=True, text=True, timeout=60)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((output / 'train').exists())
            import json
            self.assertEqual(json.loads((output / 'manifest.json').read_text())['results'][0]['status'], 'failed')

    def test_rejects_nonexistent_member_of_existing_package(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / 'cmd/train').mkdir(parents=True)
            (project / 'lib').mkdir()
            (project / 'lib/example.s').write_text('package neurx.example\nfunc present() int { return 1 }\n')
            (project / 'cmd/train/main.s').write_text('package main\nimport ("neurx.example.absent")\nfunc main() int { return 0 }\n')
            result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--commands', 'train',
                                     '--project-root', str(project), '--output-dir', str(project / 'output')],
                                    capture_output=True, text=True, timeout=60)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('neurx.example.absent', result.stdout + result.stderr)

    def test_resolves_declared_member_and_terminal_dot_imports(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / 'cmd/train').mkdir(parents=True)
            (project / 'lib').mkdir()
            (project / 'lib/example.s').write_text('package neurx.example\nfunc present() int { return 7 }\n')
            for imported in ('neurx.example.present', 'neurx.example.'):
                with self.subTest(imported=imported):
                    (project / 'cmd/train/main.s').write_text('package main\nimport ("' + imported + '")\nfunc main() int { return present() }\n')
                    output = project / 'output'
                    result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--commands', 'train',
                                             '--project-root', str(project), '--output-dir', str(output)],
                                            capture_output=True, text=True, timeout=60)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    result = subprocess.run([str(output / 'train')], timeout=10)
                    self.assertEqual(result.returncode, 7)


if __name__ == '__main__':
    unittest.main()
