"""Real native tokenizer construction, EOS and fail-closed regression tests."""
import json, os
from pathlib import Path
import subprocess, tempfile, unittest
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'artifact/local-inference/array-construction-20261110'
COMPILER=Path(os.environ.get('S_NATIVE_COMPILER',WORK/'diagnostic-compiler/stage1-diagnostic'))
class NativeTokenizerConstruction(unittest.TestCase):
    def test_bulk_tables_qwen_eos_and_malformed_input(self):
        with tempfile.TemporaryDirectory(prefix='tokenizer-construction-') as temporary:
            folder=Path(temporary);model=folder/'model';model.mkdir()
            document=dict(model=dict(type='BPE',vocab={'<unk>':0,'a':1,'b':2,'ab':3},merges=['a b']),added_tokens=[dict(id=4,content='<|endoftext|>'),dict(id=5,content='<|im_end|>')],pre_tokenizer=dict(type='ByteLevel'))
            (model/'tokenizer.json').write_text(json.dumps(document, indent=2))
            bad=folder/'bad';bad.mkdir();(bad/'tokenizer.json').write_text('{}')
            source=folder/'test.s';source.write_text('''package main
import ("neurx.inference.tokenizer.hf_bpe_tokenizer"; "neurx.runtime.tensor_builder")
func main() int {
    reset_construction_stats()
    hf_bpe_tokenizer tokenizer = load_hf_bpe_tokenizer("MODEL")
    if !tokenizer.valid || tokenizer.vocab_count != 4 || tokenizer.merge_count != 1 || tokenizer.added_count != 2 { return 1 }
    if construction_stat(0) < 13 || construction_stat(5) != 0 { return 2 }
    if tokenizer.eos_id != 5 { return 3 }
    hf_bpe_result result = hf_bpe_encode(tokenizer, "ab", 8)
    if !result.ok || len(result.token_ids) != 1 || result.token_ids[0] != 3 { return 4 }
    hf_bpe_tokenizer malformed = load_hf_bpe_tokenizer("BAD")
    if malformed.valid || construction_stat(5) != 0 { return 5 }
    return 0
}
'''.replace('MODEL',str(model)).replace('BAD',str(bad)))
            assembly=folder/'test.sasm';binary=folder/'test'
            sources=[ROOT/'src/inference/tokenizer/hf_bpe_tokenizer.s',ROOT/'src/core/unicode/normalization.s',ROOT/'src/runtime/tensor_builder/tensor_builder.s']
            for command in ([str(COMPILER),'--compile-unit',str(assembly),str(source),*map(str,sources)],[str(COMPILER),'--emit-bin',str(assembly),str(binary)],[str(binary)]):
                result=subprocess.run(command,capture_output=True,text=True,timeout=120)
                self.assertEqual(result.returncode,0,str(command)+'\n'+result.stdout+result.stderr)
if __name__=='__main__':unittest.main()
