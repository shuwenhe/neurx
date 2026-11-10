"""Fail closed on untied or corrupt output heads; explicit tying remains supported."""
import json,os,shutil,struct,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'artifact/local-inference/array-construction-20261110'
COMPILER=Path(os.environ.get('S_NATIVE_COMPILER',WORK/'diagnostic-compiler/stage1-diagnostic'))
class NativeLoaderValidation(unittest.TestCase):
    def test_missing_untied_and_truncated_tied_heads_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix='head-validation-') as temporary:
            folder=Path(temporary);paths=[]
            raw=bytes.fromhex((ROOT/'test/fixture/hf_tiny/model.safetensors.hex').read_text());size=struct.unpack('<Q',raw[:8])[0]
            for name,tied,corrupt in [('untied',False,False),('corrupt',True,True),('tied',True,False)]:
                model=folder/name;model.mkdir();config=json.loads((ROOT/'test/fixture/hf_tiny/config.json').read_text());config['tie_word_embeddings']=tied;(model/'config.json').write_text(json.dumps(config))
                header=json.loads(raw[8:8+size])
                if not corrupt: del header['lm_head.weight']
                encoded=json.dumps(header,separators=(',',':')).encode()
                data=struct.pack('<Q',len(encoded))+encoded+raw[8+size:]
                if corrupt:
                    header=json.loads(raw[8:8+size]);n=len(raw)-8-size;header['lm_head.weight']=dict(dtype='F32',shape=[7,2],data_offsets=[n,n+56]);encoded=json.dumps(header,separators=(',',':')).encode();data=struct.pack('<Q',len(encoded))+encoded+raw[8+size:]
                (model/'model.safetensors').write_bytes(data);paths.append(str(model))
            source=folder/'probe.s';source.write_text('''package main
import ("neurx.models.loaders.hf_transformer"; "neurx.runtime.tensor_builder")
func main() int {
    hf_model_weights untied = load_hf_model("UNTIED")
    println("untied error=" + untied.error_code + " live=" + hf_int_string(construction_stat(5)))
    if untied.valid { println("unexpected valid untied model") }
    if untied.valid || construction_stat(5) != 0 { return 1 }
    hf_model_weights corrupt = load_hf_model("CORRUPT")
    if corrupt.valid || construction_stat(5) != 0 { return 2 }
    hf_model_weights tied = load_hf_model("TIED")
    if !tied.valid || len(tied.lm_head) != 14 || construction_stat(5) != 0 { return 3 }
    return 0
}
'''.replace('UNTIED',paths[0]).replace('CORRUPT',paths[1]).replace('TIED',paths[2]))
            asm=folder/'probe.sasm';binary=folder/'probe';sources=['src/model/loaders/hf_transformer.s','src/model/formats/hf_config.s','src/model/formats/safetensors_embedding.s','src/runtime/command/command.s','src/runtime/tensor_builder/tensor_builder.s']
            for command in ([str(COMPILER),'--compile-unit',str(asm),str(source),*[os.environ.get('S_HF_LOADER_SOURCE',str(ROOT/p)) if p.endswith('hf_transformer.s') else str(ROOT/p) for p in sources]],[str(COMPILER),'--emit-bin',str(asm),str(binary)],[str(binary)]):
                result=subprocess.run(command,capture_output=True,text=True,timeout=120);self.assertEqual(result.returncode,0,result.stdout+result.stderr+' exit='+str(result.returncode))
if __name__=='__main__':unittest.main()
