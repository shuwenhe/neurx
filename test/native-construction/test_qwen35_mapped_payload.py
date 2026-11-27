"""Phase 1: compare actual native mmap bytes with bounded file reads.

A wrong mapped offset, shortened traversal or writable mapping must fail.
This proves local mapping consistency, not upstream checkpoint authenticity.
"""
import json
import subprocess
import unittest
from pathlib import Path
import test_qwen35_stage1 as stage1
BUILD, MODEL = stage1.BUILD, stage1.MODEL


class MappedPayload(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        stage1.Stage1.setUpClass()
        cls.probe = stage1.Stage1.probe

    def test_all_real_checkpoint_payload_bytes(self):
        result = subprocess.run([str(self.probe), 'verify-mapped', str(MODEL)],
                                capture_output=True, text=True, timeout=900)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report['verified_tensors'], 1045)
        self.assertEqual(report['verified_bytes'], 71903645408)
        self.assertEqual(report['verified_shards'], 26)
        self.assertTrue(report['read_only'])
        self.assertLess(report['buffer_bytes'], 2 << 20)
        (BUILD / 'mapped-payload.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
