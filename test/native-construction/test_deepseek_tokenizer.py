"""Native token IDs must match the independent Hugging Face tokenizer."""
import subprocess,sys
from tokenizers import Tokenizer
model=sys.argv[1]; binary=sys.argv[2]
t=Tokenizer.from_file(model+'/tokenizer.json')
cases=['Hello world!', '123456 3.14159 -42', '你好，世界！2026年', 'a\nb\r\nc\t x  ', 'café µ Ελληνικά Привет', 'The capital of France is', '<｜begin▁of▁sentence｜>Hello', 'a🙂b １２３ ١٢٣', 'abc123def456', '    \n\n  foo']
for text in cases:
 expected=t.encode(text,add_special_tokens=False).ids
 actual=list(map(int,subprocess.check_output([binary,model,text],text=True).split()))
 assert actual==expected,(repr(text),expected,actual)
print(f'PASS: {len(cases)} tokenizer parity cases: {model}')
# This vocabulary deliberately permits a cross-number merge, so merely having
# separate numeral tokens in a real vocabulary cannot hide stage errors.
import tempfile,pathlib
from tokenizers import models,pre_tokenizers
with tempfile.TemporaryDirectory() as folder:
 custom=Tokenizer(models.BPE(vocab={'Â':0,'²':1,'³':2,'Â²':3,'Â³':4,'Â²Â³':5},merges=[('Â','²'),('Â','³'),('Â²','Â³')]))
 custom.pre_tokenizer=pre_tokenizers.Sequence([pre_tokenizers.Digits(individual_digits=True),pre_tokenizers.ByteLevel(add_prefix_space=False,use_regex=False)])
 custom.save(folder+'/tokenizer.json')
 expected=custom.encode('²³').ids
 actual=list(map(int,subprocess.check_output([binary,folder,'²³'],text=True).split()))
 assert actual==expected,(expected,actual)
print('PASS: Unicode Number categories cannot merge across Digits boundaries')
