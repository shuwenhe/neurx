"""Actual pinned official fallback, isolated Torch used only as a numerical oracle."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from qwen35_official_reference import load_official, configure_runtime, run_official, bf16_fixture, error_metrics
from test_qwen35_stage3 import fixture, reference, ROOT
BUILD=ROOT/'artifact/build/qwen35_stage3/official'

class OfficialBF16(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        if importlib.util.find_spec("torch") is None:raise unittest.SkipTest("use the authorized artifact/reference-env Python")
        BUILD.mkdir(parents=True,exist_ok=True)
        cls.runtime=configure_runtime();cls.samples=[]
    def test_source_pin_fails_closed(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as folder:
            source=Path(folder)/'wrong.py';source.write_text('raise RuntimeError("must not run")\n')
            with self.assertRaisesRegex(ValueError,'SHA256'):load_official(source)
    def test_dtype_boundaries_and_cached_modes(self):
        j=bf16_fixture(fixture());a=run_official(j,partition='decode',observe=True)
        self.assertEqual(a['modes'],['chunk']+['recurrent']*4)
        self.assertEqual(a['output_dtype'],'torch.bfloat16');self.assertEqual(a['state_dtype'],'torch.float32');self.assertEqual(a['history_dtype'],'torch.bfloat16')
        l2=[e for e in a['dtype_events'] if e['scope']=='l2norm']
        for op in ['aten.mul.Tensor','aten.sum.dim_IntList','aten.add.Tensor','aten.rsqrt.default']:
            events=[e for e in l2 if e['op']==op];self.assertTrue(events,op)
            self.assertTrue(all('torch.bfloat16' in e['outputs'] for e in events),str(events))
        b=run_official(j,partition='decode',observe=False)
        for key in ['output','state','history']:np.testing.assert_array_equal(a[key],b[key])
        (BUILD/'dtype-probe.json').write_text(json.dumps({k:v for k,v in a.items() if k not in ['output','state','history','core','beta','decay']},indent=2)+'\n')
    def calibrate(self,j,label):
        bf=bf16_fixture(j);a=run_official(bf,partition='decode');m32=reference(bf,np.float32);m64=reference(bf,np.float64)
        for key in ['output','core','state','history']:
            p32=np.concatenate([np.asarray(x[key],dtype=np.float64) for x in m32]);p64=np.concatenate([np.asarray(x[key],dtype=np.float64) for x in m64])
            self.assertEqual(len(a[key]),len(p32));self.assertTrue(np.isfinite(a[key]).all())
            self.samples.append(dict(case=label,tensor=key,m32_m64=error_metrics(p32,p64),m32_official=error_metrics(p32,a[key]),m64_official=error_metrics(p64,a[key])))
        return a
    def test_mathematical_baseline_calibration(self):
        for seed in [781,2191]:self.calibrate(fixture(seed=seed),f'seed{seed}')
    def test_zero_small_norm_nonzero_initial_state(self):
        for scale in [0.,1e-8]:
            j=fixture();j['calls'][0]['x']=(np.asarray(j['calls'][0]['x'])*scale).tolist();j['initial_state']=[.1]*(4*3*4)
            self.calibrate(j,f'zero_small_{scale}')
    def test_official_prefill_and_recurrent_equivalence(self):
        for length in [1,3,4,63,64,65,257]:
            j=fixture(kd=2,vd=2,kh=1,vh=2,context=length,chunk=length);j['calls']=[dict(x=np.random.default_rng(length).standard_normal((length,7)).astype('f4').ravel().tolist(),position=0)];j=bf16_fixture(j)
            a=run_official(j,partition='prefill');b=run_official(j,partition='decode')
            self.assertEqual(a['modes'],['chunk'])
            # BF16 final values may differ one ULP across algebraically equivalent
            # FP32 accumulation orders. Final recurrent state is compared in FP32.
            self.samples.append(dict(case=f'prefill_decode_{length}',tensor='output',official_modes=error_metrics(a['output'],b['output'])))
            np.testing.assert_allclose(a['state'][-2*2*2:],b['state'][-2*2*2:],rtol=1e-4,atol=2e-5)
    @classmethod
    def tearDownClass(cls):
        (BUILD/'calibration.json').write_text(json.dumps(dict(runtime=cls.runtime,samples=cls.samples),indent=2)+'\n')
if __name__=='__main__':unittest.main(verbosity=2)
