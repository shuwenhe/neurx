"""P0 BF16 RED/GREEN gates: compare native intermediate stages, not casts alone."""
import json
import os
import subprocess
import unittest
import numpy as np
from pathlib import Path
from test_qwen35_stage3 import fixture, ROOT
from qwen35_official_reference import configure_runtime, bf16_fixture, run_official, _bf16
BUILD = ROOT/'artifact/build/qwen35_p0_20261127'

def build_probe():
    selected=os.environ.get('QWEN35_BF16_PROBE')
    if selected:
        return Path(selected).resolve()
    BUILD.mkdir(parents=True,exist_ok=True)
    probe=BUILD/'bf16-probe'
    command=['nvcc','-std=c++17','-O2','-lineinfo','-U_FORTIFY_SOURCE','-D_FORTIFY_SOURCE=0',
             '--fmad=false','-arch=sm_89',str(ROOT/'test/native-construction/qwen35_p0_bf16_probe.cu'),
             str(ROOT/'backend/platform/cuda/hybrid_deltanet_bf16.cu'),'-o',str(probe)]
    result=subprocess.run(command,capture_output=True,text=True,timeout=120)
    (BUILD/'bf16-build-final.log').write_text(' '.join(command)+'\n'+result.stdout+result.stderr)
    if result.returncode:raise AssertionError(result.stdout+result.stderr)
    return probe


class P0BF16(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runtime=configure_runtime();cls.records=[];cls.probe=build_probe()

    def test_native_bf16_stages(self):
        probe=self.probe
        self.assertTrue(probe.is_file(), 'native BF16 execution path missing')
        for seed in [781,2191,7419]:
            j=bf16_fixture(fixture(seed=seed))
            p=subprocess.run([str(probe)],input=json.dumps(j),capture_output=True,text=True,timeout=120)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)
            native=json.loads(p.stdout)
            self.assertEqual(native['storage'],'BF16');self.assertEqual(native['state_storage'],'FP32')
            self.assertEqual(native['accumulation'],'FP32')
            official=run_official(j,partition='decode',trace_stages=True)
            (BUILD/f'native-seed{seed}.json').write_text(json.dumps(native)+'\n')
            (BUILD/f'official-seed{seed}.json').write_text(json.dumps({k:v.tolist() for k,v in official.items() if isinstance(v,np.ndarray)})+'\n')
            for key,actual,expected in [('fp32_qkv',native['fp32_qkv'],official['qkv']),
                                        ('fp32_output',native['fp32_output'],official['output']),
                                        ('cast_only_output',native['cast_only_output'],official['output'])]:
                error=np.abs(np.asarray(actual,dtype='f8')-np.asarray(expected,dtype='f8'))
                self.records.append(dict(seed=seed,node=key,maxabs=float(error.max()),meanabs=float(error.mean()),maxrelative=float(np.max(error/np.maximum(np.abs(expected),np.finfo('f4').tiny)))))
            for key in ['qkv','z','a','b','conv','activated','q','k','beta','decay','core','gated','output','state','history']:
                a=np.asarray(native[key],dtype=np.float32);b=np.asarray(official[key],dtype=np.float32)
                self.assertEqual(a.shape,b.shape,key)
                self.assertTrue(np.isfinite(a).all(),key)
                error=np.abs(a.astype('f8')-b.astype('f8'))
                self.records.append(dict(seed=seed,node=key,maxabs=float(error.max()),meanabs=float(error.mean()),maxrelative=float(np.max(error/np.maximum(np.abs(b),np.finfo('f4').tiny))),nan=int(np.isnan(a).sum()),inf=int(np.isinf(a).sum())))
                # Exact tensor boundary equality is a strict initial gate, not a
                # tolerance selected from the native implementation's errors.
                if key not in ['state','decay']:
                    np.testing.assert_array_equal(a,b,err_msg=f'seed={seed} node={key}')
                else:
                    # Existing official prefill/recurrent FP32 state assertion.
                    np.testing.assert_allclose(a,b,rtol=1e-4,atol=2e-5,err_msg=key)
            for key in ['qkv','z','a','b','conv','activated','q','k','beta','core','gated','output','history']:
                a=np.asarray(native[key],dtype='f4')
                np.testing.assert_array_equal(a.view('u4'),_bf16(a).view('u4'),err_msg=key)

    def run_native(self,j):
        p=subprocess.run([str(self.probe)],input=json.dumps(j),capture_output=True,text=True,timeout=120)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        return json.loads(p.stdout)

    def test_prefill_decode_partition_and_reset(self):
        j=bf16_fixture(fixture())
        prefill=self.run_native(j)
        x=np.asarray(j['calls'][0]['x']).reshape(-1,j['hidden'])
        decode=dict(j,calls=[dict(x=row.tolist(),position=i) for i,row in enumerate(x)])
        decoded=self.run_native(decode)
        for key in ['output','state','history','qkv','conv','activated','core','gated']:
            np.testing.assert_array_equal(prefill[key],decoded[key],err_msg=key)
        reset=dict(j,calls=j['calls']+[dict(reset=True)]+j['calls'])
        restarted=self.run_native(reset)
        for key in ['output','state','history']:
            np.testing.assert_array_equal(restarted[key],prefill[key]*2,err_msg=key)

    def test_nonzero_state_and_history(self):
        j=fixture();j['initial_state']=[.1]*(j['vh']*j['kd']*j['vd'])
        j['initial_history']=(np.random.default_rng(913).standard_normal((2*j['kh']*j['kd']+j['vh']*j['vd'])*j['conv'])*.1).tolist()
        j=bf16_fixture(j);a=self.run_native(j);b=run_official(j,partition='decode',trace_stages=True)
        for key in ['output','history','core','gated']:
            np.testing.assert_array_equal(a[key],b[key],err_msg=key)
        np.testing.assert_allclose(a['state'],b['state'],rtol=1e-4,atol=2e-5)

    def test_lifecycle_and_admission(self):
        j=bf16_fixture(fixture(context=8,chunk=8));j['lifecycle_tests']=True
        result=self.run_native(j)
        self.assertEqual(len(result),9)
        self.assertTrue(all(result.values()),result)
        (BUILD/'bf16-lifecycle.json').write_text(json.dumps(result,indent=2)+'\n')

    def test_wider_prefill_65_against_official_chunk(self):
        j=fixture(kd=8,vd=8,kh=2,vh=4,context=65,chunk=65,seed=913)
        h=32;raw=2*j['kh']*j['kd']+j['vh']*j['vd'];vw=j['vh']*j['vd'];rng=np.random.default_rng(913)
        j['hidden']=h
        for key,shape in [('qkv',(raw,h)),('z',(vw,h)),('a',(j['vh'],h)),('b',(j['vh'],h)),('out',(h,vw))]:
            j[key]=(rng.standard_normal(shape)*.2).astype('f4').ravel().tolist()
        j['calls']=[dict(x=rng.standard_normal((65,h)).astype('f4').ravel().tolist(),position=0)]
        j=bf16_fixture(j);a=self.run_native(j);b=run_official(j,partition='prefill',trace_stages=True)
        (BUILD/'wide-native.json').write_text(json.dumps(a)+'\n')
        (BUILD/'wide-official.json').write_text(json.dumps({k:v.tolist() for k,v in b.items() if isinstance(v,np.ndarray)})+'\n')
        # Official chunk returns only final state/history, native trace every token.
        for key in ['output','qkv','conv','activated','q','k','beta','decay','core','gated']:
            if key=='decay':
                np.testing.assert_allclose(a[key],b[key],rtol=1e-4,atol=2e-5,err_msg=key)
            else:
                np.testing.assert_array_equal(a[key],b[key],err_msg=key)
        np.testing.assert_allclose(a['state'][-j['vh']*j['kd']*j['vd']:],b['state'],rtol=1e-4,atol=2e-5)

    @classmethod
    def tearDownClass(cls):
        BUILD.mkdir(parents=True,exist_ok=True)
        (BUILD/'bf16-stage-metrics.json').write_text(json.dumps(dict(runtime=cls.runtime,records=cls.records),indent=2)+'\n')

if __name__=='__main__':unittest.main(verbosity=2)
