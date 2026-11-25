"""Run after compiling test/deepseek_cuda_probe.cu; needs a CUDA device."""
import json,pathlib,subprocess,sys,tempfile
import numpy as np
probe=str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix='neurx-deepseek-parity-') as folder:
 subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('deepseek_reference.py')),folder],check=True)
 subprocess.run([probe,folder,folder+'/actual.json'],check=True)
 expected=np.array(json.load(open(folder+'/expected.json'))['logits']);actual=np.array(json.load(open(folder+'/actual.json')))
 np.testing.assert_allclose(actual,expected,rtol=1e-4,atol=2e-5)
 assert np.array_equal(actual.argmax(-1),expected.argmax(-1))
 print('PASS: independent BF16 MLA/YaRN/MoE logits, max absolute error',abs(actual-expected).max())
 config=json.load(open(folder+'/config.json'))
 config['topk_method']='group_limited_greedy';pathlib.Path(folder+'/config.json').write_text(json.dumps(config))
 failed=subprocess.run([probe,folder,folder+'/invalid.json'],capture_output=True,text=True)
 assert failed.returncode!=0 and 'unsupported DeepSeek variant' in failed.stderr,failed.stderr
 print('PASS: unsupported architecture fails explicitly')
