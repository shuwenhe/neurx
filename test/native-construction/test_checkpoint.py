"""Native checkpoint metadata and explicit empty/read failure tests."""
import json, os, struct, subprocess, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'artifact/local-inference/array-construction-20261110'
COMPILER=Path(os.environ.get('S_NATIVE_COMPILER',WORK/'diagnostic-compiler/stage1-diagnostic'))
class NativeCheckpoint(unittest.TestCase):
    def test_metadata_validation_and_bulk_read_errors(self):
        with tempfile.TemporaryDirectory(prefix='checkpoint-validation-') as temporary:
            folder=Path(temporary)
            def checkpoint(name,shape,pretty=False):
                header={'x':dict(dtype='BF16',shape=shape,data_offsets=[0,8])}
                encoded=json.dumps(header,indent=2 if pretty else None,separators=None if pretty else (',',':')).encode()
                path=folder/name;path.write_bytes(struct.pack('<Q',len(encoded))+encoded+b'\x80\x3f'*4);return str(path)
            good=checkpoint('good',[2,2],True);rank3=checkpoint('rank3',[2,2,1]);overflow=checkpoint('overflow',[18446744073709551618,2])
            empty=folder/'empty';empty.write_bytes(b'')
            source=folder/'test.s';source.write_text('''package main
import ("neurx.models.formats.safetensors_embedding"; "neurx.runtime.tensor_builder")
func main() int {
    safetensors_embedding good = load_f32_tensor("GOOD", "x")
    if !good.valid || good.rows != 2 || good.columns != 2 { return 1 }
    f32_tensor_result decoded = read_f32_tensor(good)
    if !decoded.ok || len(decoded.values) != 4 || decoded.values[3] != 1.0 { return 2 }
    safetensors_embedding rank3 = load_f32_tensor("RANK3", "x")
    if rank3.valid { return 3 }
    safetensors_embedding overflow = load_f32_tensor("OVERFLOW", "x")
    if overflow.valid { return 4 }
    safetensors_embedding empty = load_f32_tensor("EMPTY", "x")
    if empty.valid { return 5 }
    float_construction_result zero = read_float_tensor_range("EMPTY", 0, 0, 1)
    float_construction_result short_read = read_float_tensor_range("EMPTY", 0, 1, 1)
    float_construction_result missing = read_float_tensor_range("MISSING", 0, 0, 1)
    if !zero.ok || len(zero.values) != 0 || short_read.ok || short_read.error != -61 || missing.ok || missing.error != -2 { return 6 }
    if construction_stat(5) != 0 { return 7 }
    return 0
}
'''.replace('GOOD',good).replace('RANK3',rank3).replace('OVERFLOW',overflow).replace('EMPTY',str(empty)).replace('MISSING',str(folder/'missing')))
            asm=folder/'test.sasm';binary=folder/'test'
            commands=[[str(COMPILER),'--compile-unit',str(asm),str(source),str(ROOT/'src/model/formats/safetensors_embedding.s'),str(ROOT/'src/runtime/tensor_builder/tensor_builder.s')],[str(COMPILER),'--emit-bin',str(asm),str(binary)],[str(binary)]]
            for command in commands:
                result=subprocess.run(command,capture_output=True,text=True,timeout=120)
                self.assertEqual(result.returncode,0,str(command)+'\n'+result.stdout+result.stderr)
if __name__=='__main__':unittest.main()
