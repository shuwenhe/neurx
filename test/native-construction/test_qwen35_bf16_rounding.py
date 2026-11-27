"""Check reference fixture conversion against GPU Torch at BF16 ties."""
import unittest
import numpy as np
import torch
from qwen35_official_reference import _bf16

class BF16Rounding(unittest.TestCase):
    def test_ties_to_even_and_adjacent_values(self):
        self.assertTrue(torch.cuda.is_available(), 'CUDA GPU required')
        # Include positive, negative, subnormal, normal and high finite BF16 values.
        bases = np.array([0x0000, 0x0001, 0x007f, 0x0080, 0x3f80, 0x3f81,
                          0x4000, 0x7f00, 0x8000, 0x8001, 0xbf80, 0xbf81], dtype=np.uint32)
        bits = np.concatenate([(bases << 16) + np.uint32(delta) for delta in (0x7fff, 0x8000, 0x8001)])
        values = bits.view(np.float32)
        expected = _bf16(values)
        actual = torch.from_numpy(values.copy()).cuda().to(torch.bfloat16).float().cpu().numpy()
        np.testing.assert_array_equal(expected.view(np.uint32), actual.view(np.uint32))

if __name__ == '__main__':
    unittest.main()
