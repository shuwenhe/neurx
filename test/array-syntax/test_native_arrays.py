"""Execute migrated dynamic and nested arrays with the installed Stage4."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from test_normalize_arrays import migration
ROOT=Path(__file__).resolve().parents[2]
DRIVER=ROOT/'artifact/local-inference/array-construction-20261110/toolchain/bin/s'
COMPILER=Path(os.environ.get('S_NATIVE_COMPILER',DRIVER.resolve().parent/'s_compiler'))
class NativeArraySyntax(unittest.TestCase):
    def test_postfix_arrays_compile_and_retain_values(self):
        source='''package main
struct array_state {
    []float processed_logits
    []int masked_tokens
}
func modify([]float input) []float {
    []float output = input
    output[0] = 9.0
    return output
}
func main() int {
    []int ids = []int{1, 2, 3}
    []float input = []float{1.0, 2.0}
    []float output = modify(input)
    [][]int nested = make([][]int, 2)
    nested[0] = []int{7, 8}
    array_state state = array_state{processed_logits: output, masked_tokens: []int{ids[0], ids[1], ids[2]}}
    if len(ids) != 3 || ids[2] != 3 { return 1 }
    if input[0] != 1.0 || output[0] != 9.0 { return 2 }
    if nested[0][1] != 8 || len(nested) != 2 { return 3 }
    if state.processed_logits[1] != 2.0 || state.masked_tokens[1] != 2 { return 4 }
    return 0
}
'''
        with tempfile.TemporaryDirectory(prefix='postfix-arrays-') as temporary:
            folder=Path(temporary);path=folder/'arrays.s';path.write_text(migration.normalize(source));assembly=folder/'arrays.sasm';binary=folder/'arrays'
            for command in ([str(COMPILER),'--compile-unit',str(assembly),str(path)],[str(COMPILER),'--emit-bin',str(assembly),str(binary)],[str(binary)]):
                result=subprocess.run(command,capture_output=True,text=True,timeout=90)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
if __name__=='__main__':unittest.main()
