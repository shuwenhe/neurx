"""The optional NeurX compiler builder must not write outside artifact/ or clobber outputs."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('local_compiler_builder', ROOT / 'tool/build_neurx_compiler.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class CompilerIsolation(unittest.TestCase):
    def test_rejects_output_outside_artifact_before_writing(self):
        output = ROOT / ('compiler-forbidden-' + uuid.uuid4().hex)
        with self.assertRaises(ValueError):
            builder.build(ROOT / 'absent-source', output)
        self.assertFalse(output.exists())

    def test_does_not_overwrite_an_existing_output(self):
        base = ROOT / 'artifact/build/qwen35_stage1'
        base.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=base) as temporary:
            output = Path(temporary)
            marker = output / 'compiler'
            marker.write_bytes(b'keep existing compiler')
            with self.assertRaises(FileExistsError):
                builder.build(ROOT / 'absent-source', output)
            self.assertEqual(marker.read_bytes(), b'keep existing compiler')

    def test_rejects_output_escape_via_symlink(self):
        base = ROOT / 'artifact/build/qwen35_stage1'
        base.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=base) as temporary:
            link = Path(temporary) / 'outside'
            link.symlink_to(ROOT, target_is_directory=True)
            output = link / ('compiler-forbidden-' + uuid.uuid4().hex)
            with self.assertRaises(ValueError):
                builder.build(ROOT / 'absent-source', output)
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
