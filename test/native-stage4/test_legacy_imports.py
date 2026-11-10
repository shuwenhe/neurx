"""Legacy IR targets must include imported implementations, not only signatures."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
S_ROOT = Path(os.environ.get('S_REPO_ROOT', ROOT.parent / 's'))


class LegacyImports(unittest.TestCase):
    def test_compiles_transitive_import_implementations(self):
        with tempfile.TemporaryDirectory(prefix='neurx-import-link-') as directory:
            project = Path(directory)
            (project / 'main.s').write_text('package main\nimport ("probe.engine.")\nfunc main() int { return load_real_text_engine() }\n')
            (project / 'engine.s').write_text('package probe.engine\nimport ("probe.weights")\nfunc load_real_text_engine() int { return loaded_weight() }\n')
            (project / 'weights.s').write_text('package probe.weights\nfunc loaded_weight() int { return 42 }\n')
            output = project / 'linked.ir'
            result = subprocess.run(['python3', str(ROOT / 'tool/build_legacy_ir.py'), '--project-root', str(project),
                                     '--s-root', str(S_ROOT), '--compiler', str(S_ROOT / 'bin/s_seed'),
                                     '--entry', str(project / 'main.s'), '--output', str(output)],
                                    capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            text = output.read_text()
            self.assertIn('FUNC_BEGIN|load_real_text_engine|', text)
            self.assertIn('FUNC_BEGIN|loaded_weight|', text)
            result = subprocess.run([str(ROOT / 'artifact/build/s_runner/s_ir_runner'), str(output)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 42, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
