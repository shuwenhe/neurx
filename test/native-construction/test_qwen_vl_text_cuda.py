"""Independent numerical regression for the Qwen VL text-only offload path."""
import json,pathlib,subprocess,sys,tempfile,os,struct
import numpy as np
probe=str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix='neurx-qwen-vl-parity-') as folder:
 subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('qwen_vl_text_reference.py')),folder],check=True)
 subprocess.run([probe,folder,folder+'/actual.json'],check=True)
 expected=np.array(json.load(open(folder+'/expected.json'))['logits']);actual=np.array(json.load(open(folder+'/actual.json')))
 np.testing.assert_allclose(actual,expected,rtol=1e-4,atol=2e-5)
 assert np.array_equal(actual.argmax(-1),expected.argmax(-1))
 print('PASS: Qwen GQA, QKV bias, RoPE, BF16/F32 logits, max error',abs(actual-expected).max())

 # Force staging with a 1MiB cache: an unused 1,048,000-byte tensor reserves
 # almost all capacity, leaving real projection weights to the upload slot.
 checkpoint=pathlib.Path(folder)/'model.safetensors'
 data=checkpoint.read_bytes();size=struct.unpack('<Q',data[:8])[0];header=json.loads(data[8:8+size]);payload=data[8+size:]
 header['test_cache_padding.weight']=dict(dtype='BF16',shape=[524000],data_offsets=[len(payload),len(payload)+1048000])
 encoded=json.dumps(header,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%8)
 checkpoint.write_bytes(len(encoded).to_bytes(8,'little')+encoded+payload+b'\0'*1048000)
 subprocess.run([probe,folder,folder+'/staged.json'],check=True,env=dict(os.environ,NEURX_QWEN_WEIGHT_CACHE_MB='1'))
 staged=np.array(json.load(open(folder+'/staged.json')));np.testing.assert_allclose(staged,expected,rtol=1e-4,atol=2e-5)
 print('PASS: bounded staging path preserves logits with 1MiB weight cache')
