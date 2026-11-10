"""Run the real freestanding runtime with sanitizer allocator diagnostics."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
COMPILER_ROOT = ROOT / 'artifact/local-inference/compiler-source'

class ConstructionRuntime(unittest.TestCase):
    def test_sanitized_native_runtime(self):
        with tempfile.TemporaryDirectory(prefix='construction-runtime-') as temporary:
            folder = Path(temporary)
            runtime = COMPILER_ROOT / 'src/cmd/compile/internal/codegen/native_runtime_extensions.c'
            command = ['gcc','-std=c11','-O1','-g','-Wall','-Wextra','-Werror','-fsanitize=address,undefined','-fno-omit-frame-pointer',
                       '-DNEURX_COMPILER_RUNTIME="'+str(runtime)+'"', str(ROOT / 'test/native-construction/runtime_test.c'), '-lm','-o',str(folder/'probe')]
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            # LeakSanitizer cannot enumerate threads under this sandbox's ptrace policy.
            # ASan/UBSan remain enabled; lifecycle is checked by live-registry counts.
            environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=0:halt_on_error=1', UBSAN_OPTIONS='halt_on_error=1')
            result = subprocess.run([str(folder/'probe'), str(folder/'weights.bin')], capture_output=True, text=True, timeout=30, env=environment)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('PASS',result.stdout)

if __name__=='__main__': unittest.main()
