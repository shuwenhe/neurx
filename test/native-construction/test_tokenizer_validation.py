"""Missing/optional fields and truncated tokenizer documents must not abort or leak."""
import json,os,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'artifact/local-inference/array-construction-20261110'
COMPILER=Path(os.environ.get('S_NATIVE_COMPILER',WORK/'diagnostic-compiler/stage1-diagnostic'))
class NativeTokenizerValidation(unittest.TestCase):
    def test_missing_merges_optional_added_and_truncated_arrays(self):
        with tempfile.TemporaryDirectory(prefix='tokenizer-fields-') as temporary:
            folder=Path(temporary);documents=[json.dumps({'model':{'vocab':{'a':0}}}),json.dumps({'model':{'vocab':{'a':0},'merges':[]}}),'{"model":{"vocab":{"a":0},"merges":["a a"']
            for i,text in enumerate(documents):
                p=folder/str(i);p.mkdir();(p/'tokenizer.json').write_text(text)
            source=folder/'test.s';source.write_text('''package main
import ("neurx.inference.tokenizer.hf_bpe_tokenizer"; "neurx.runtime.tensor_builder")
func main() int {
    hf_bpe_tokenizer missing = load_hf_bpe_tokenizer("ROOT/0")
    if missing.valid || construction_stat(5) != 0 { return 1 }
    hf_bpe_tokenizer optional = load_hf_bpe_tokenizer("ROOT/1")
    if !optional.valid || optional.added_count != 0 || construction_stat(5) != 0 { return 2 }
    hf_bpe_tokenizer truncated = load_hf_bpe_tokenizer("ROOT/2")
    if truncated.valid || construction_stat(5) != 0 { return 3 }
    return 0
}
'''.replace('ROOT',str(folder)))
            asm=folder/'test.sasm';binary=folder/'test';sources=['src/inference/tokenizer/hf_bpe_tokenizer.s','src/core/unicode/normalization.s','src/runtime/tensor_builder/tensor_builder.s']
            for command in ([str(COMPILER),'--compile-unit',str(asm),str(source),*[str(ROOT/p) for p in sources]],[str(COMPILER),'--emit-bin',str(asm),str(binary)],[str(binary)]):
                result=subprocess.run(command,capture_output=True,text=True,timeout=120);self.assertEqual(result.returncode,0,result.stdout+result.stderr+' exit='+str(result.returncode))
if __name__=='__main__':unittest.main()
