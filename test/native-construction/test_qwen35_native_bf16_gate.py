"""Phase 2 RED gate: native DeltaNet must produce actual BF16 values.

The existing FP32 session is expected to FAIL until a BF16 path exists.
No numeric tolerance is invented from the implementation's observed errors.
Run with artifact/reference-env/bin/python on a real CUDA device.
"""
import json
import subprocess
import unittest
import numpy as np
from test_qwen35_stage3 import fixture, ROOT
from qwen35_official_reference import bf16_fixture, run_official, configure_runtime, _bf16
BUILD = ROOT / 'artifact/build/qwen35_native_20261127'


class NativeBF16Gate(unittest.TestCase):
    def test_native_output_has_bf16_precision(self):
        runtime = configure_runtime()
        j = bf16_fixture(fixture())
        result = subprocess.run([str(ROOT / 'artifact/build/qwen35_stage3/probe')],
                                input=json.dumps(j), text=True, capture_output=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        native = json.loads(result.stdout)
        actual = np.concatenate([np.asarray(c['output'], dtype=np.float32) for c in native['calls']])
        expected = np.asarray(run_official(j, partition='decode')['output'], dtype=np.float32)
        delta = np.abs(actual.astype(np.float64) - expected.astype(np.float64))
        non_bf16 = int(np.count_nonzero(actual.view(np.uint32) != _bf16(actual).view(np.uint32)))
        report = dict(runtime=runtime, native_storage='FP32', native_arithmetic='FP32',
                      reference_output='BF16', reference_state='FP32', fp16_used=False,
                      max_absolute_error=float(delta.max()), mean_absolute_error=float(delta.mean()),
                      max_relative_error=float(np.max(delta / np.maximum(np.abs(expected), np.finfo(np.float32).tiny))),
                      relative_error_denominator_floor=float(np.finfo(np.float32).tiny),
                      native_nan=int(np.isnan(actual).sum()), native_inf=int(np.isinf(actual).sum()),
                      non_bf16_outputs=non_bf16, outputs=int(actual.size),
                      numerical_budget='PENDING: no numerical PASS asserted',
                      status='BLOCKED' if non_bf16 else 'PARTIAL')
        BUILD.mkdir(parents=True, exist_ok=True)
        (BUILD / 'phase2-bf16-gate.json').write_text(json.dumps(report, indent=2) + '\n')
        self.assertTrue(np.isfinite(actual).all())
        self.assertEqual(non_bf16, 0, 'Native DeltaNet remains FP32; BF16 execution is missing')


if __name__ == '__main__':
    unittest.main(verbosity=2)
