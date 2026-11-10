"""Execute construction through the actual canonical native S compiler."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'artifact/local-inference/array-construction-20261110'
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', WORK / 'diagnostic-compiler/stage1-diagnostic'))
WRAPPER = ROOT / 'src/runtime/tensor_builder/tensor_builder.s'

class NativeConstruction(unittest.TestCase):
    def compile(self, source, output, timeout=120):
        assembly = output.with_suffix('.sasm')
        result = subprocess.run([str(COMPILER),'--compile-unit',str(assembly),str(source),str(WRAPPER)],capture_output=True,text=True,timeout=timeout)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        result = subprocess.run([str(COMPILER),'--emit-bin',str(assembly),str(output)],capture_output=True,text=True,timeout=30)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        return assembly

    def test_value_semantics_and_gc_registry_roots_with_and_without_globals(self):
        original = (ROOT / 'test/native-construction/semantics.s').read_text()
        with tempfile.TemporaryDirectory(prefix='native-builder-semantics-') as temporary:
            folder=Path(temporary)
            for globals_enabled in (False,True):
                with self.subTest(globals=globals_enabled):
                    source=folder/('global.s' if globals_enabled else 'plain.s')
                    text=original
                    if globals_enabled:
                        text=text.replace('struct array_record','global_marker := 3\nstruct array_record').replace('func main() int {','func main() int {\n    if global_marker != 3 { return 99 }')
                    source.write_text(text)
                    binary=source.with_suffix('')
                    assembly=self.compile(source,binary)
                    self.assertIn('s_native_tensor_builders: .quad 0',assembly.read_text())
                    result=subprocess.run([str(binary)],capture_output=True,text=True,timeout=60)
                    self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_intrinsic_type_validation_is_not_bypassed(self):
        with tempfile.TemporaryDirectory(prefix='native-builder-types-') as temporary:
            folder=Path(temporary)
            source=folder/'bad.s'
            source.write_text('''package main
extern "intrinsic" func __native_builder_set_float(int id, int index, string value) int
func main() int { return __native_builder_set_float(1, 0, "wrong") }
''')
            result=subprocess.run([str(COMPILER),'--compile-unit',str(folder/'bad.sasm'),str(source)],capture_output=True,text=True,timeout=60)
            self.assertNotEqual(result.returncode,0)

if __name__=='__main__': unittest.main()
