"""Independent NumPy FP64/FP32 oracle versus the native CUDA attention session.

Removing head-local gate layout, partial RoPE, causal masking or KV append must
change measured outputs. No production implementation is used by the oracle.
"""
import copy
import json
import os
from pathlib import Path
import subprocess
import unittest
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'artifact/build/qwen35_stage2'


def fixture(dim=8, rotary=4, context=32, chunk=8, qh=4, seed=521):
    rng=np.random.default_rng(seed)
    h,kh=12,2
    j=dict(hidden=h,qh=qh,kh=kh,dim=dim,rotary=rotary,context=context,chunk=chunk,theta=1e7,eps=1e-6)
    for name,shape in [('qg',(qh*dim*2,h)),('k',(kh*dim,h)),('v',(kh*dim,h)),('o',(h,qh*dim))]:
        j[name]=(rng.standard_normal(shape)*.15).astype('f4').ravel().tolist()
    for name in ['qnorm','knorm']:j[name]=(rng.standard_normal(dim)*.1).astype('f4').tolist()
    j['calls']=[dict(x=rng.standard_normal((5,h)).astype('f4').ravel().tolist(),position=0)]
    return j


def reference(j,dtype):
    h,qh,kh,d,r=[j[k] for k in ['hidden','qh','kh','dim','rotary']]
    ks=[];vs=[];results=[]
    # Explicit ordered reductions in each dtype, independent CPU array algebra.
    def matmul(a,b):
        out=np.zeros((a.shape[0],b.shape[1]),dtype=dtype)
        for f in range(a.shape[1]):out=np.add(out,np.multiply(a[:,f:f+1],b[f:f+1,:],dtype=dtype),dtype=dtype)
        return out
    def sum_last(a):
        out=np.zeros(a.shape[:-1],dtype=dtype)
        for f in range(a.shape[-1]):out=np.add(out,a[...,f],dtype=dtype)
        return out
    for call in j['calls']:
        if 'reset' in call:ks=[];vs=[];results.append(dict(reset=True));continue
        x=np.asarray(call['x'],dtype=dtype).reshape(-1,h)
        qg=matmul(x,np.asarray(j['qg'],dtype=dtype).reshape(qh*2*d,h).T).reshape(-1,qh,2*d)
        q=qg[:,:,:d].copy();gate=qg[:,:,d:]
        k=matmul(x,np.asarray(j['k'],dtype=dtype).reshape(kh*d,h).T).reshape(-1,kh,d)
        v=matmul(x,np.asarray(j['v'],dtype=dtype).reshape(kh*d,h).T).reshape(-1,kh,d)
        for a,n in [(q,'qnorm'),(k,'knorm')]:
            a*=1/np.sqrt((sum_last(a*a)[...,None]/dtype(d))+dtype(j['eps']))
            a*=1+np.asarray(j[n],dtype=dtype)
            angles=np.arange(call['position'],call['position']+len(x),dtype=dtype)[:,None]*np.power(dtype(j['theta']),-2*np.arange(r//2,dtype=dtype)/r)[None,:]
            cs=np.cos(angles)[:,None,:];sn=np.sin(angles)[:,None,:]
            first=a[:,:,:r//2].copy();second=a[:,:,r//2:r].copy()
            a[:,:,:r//2]=first*cs-second*sn;a[:,:,r//2:r]=second*cs+first*sn
        att=np.empty_like(q)
        for t in range(len(x)):
            ks.append(k[t].copy());vs.append(v[t].copy())
            for head in range(qh):
                g=head//(qh//kh)
                scores=matmul(np.asarray(ks)[:,g,:],q[t,head][:,None])[:,0]/np.sqrt(dtype(d))
                probs=np.exp(scores-np.max(scores));probs/=sum_last(probs)
                att[t,head]=matmul(probs[None,:],np.asarray(vs)[:,g,:])[0]
        # Stable sigmoid avoids overflow at deliberately extreme gates.
        sig=np.exp(-np.abs(gate));sig=np.where(gate>=0,1/(1+sig),sig/(1+sig))
        att*=sig
        out=matmul(att.reshape(-1,qh*d),np.asarray(j['o'],dtype=dtype).reshape(h,qh*d).T)
        results.append(dict(output=out.ravel(),q=q.ravel(),k=k.ravel(),v=v.ravel(),attention=att.ravel(),length=len(ks)))
    return results


class Stage2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        BUILD.mkdir(parents=True,exist_ok=True)
        cls.probe=BUILD/'probe'
        if not os.environ.get('QWEN35_STAGE2_PROBE'):
            cmd=['nvcc','-std=c++17','-O2','-U_FORTIFY_SOURCE','-D_FORTIFY_SOURCE=0','--fmad=false','-arch=sm_89',str(ROOT/'test/native-construction/qwen35_stage2_probe.cu'),str(ROOT/'backend/platform/cuda/hybrid_attention_cuda.cu'),*[str(ROOT/'src/runtime/model'/f) for f in ['hybrid_config.cpp','mapped_weight_store.cpp','architecture_registry.cpp']],'-lcrypto','-o',str(cls.probe)]
            p=subprocess.run(cmd,capture_output=True,text=True,timeout=120)
            if p.returncode:raise AssertionError(p.stdout+p.stderr)
        else:cls.probe=Path(os.environ['QWEN35_STAGE2_PROBE'])
        cls.metrics=[];cls.memory=[]

    def run_probe(self,j,success=True):
        args=[str(self.probe)];data=j
        if '__real_model' in j:
            args+=['--model',j['__real_model']]
            data={k:v for k,v in j.items() if k not in ['qg','k','v','o','qnorm','knorm','__real_model']}
        p=subprocess.run(args,input=json.dumps(data),capture_output=True,text=True,timeout=60)
        self.assertEqual(p.returncode,0 if success else 1,p.stdout+p.stderr)
        return json.loads(p.stdout)

    def compare(self,j):
        actual=self.run_probe(j);m64=reference(j,np.float64);m32=reference(j,np.float32)
        h,q,k,d,c,ctx=[j[n] for n in ['hidden','qh','kh','dim','chunk','context']]
        expected=4*(h*(3*q*d+2*k*d)+2*d+2*ctx*k*d+c*(2*h+5*q*d+2*k*d))
        self.assertEqual(actual['allocated'],expected)
        self.memory.append(dict(case=self.id(),allocated=actual['allocated'],free_before=actual['free_before'],free_after=actual['free_after']))
        self.assertEqual(len(actual['calls']),len(m64));self.assertEqual(len(m64),len(m32))
        for i,(a,b,c) in enumerate(zip(actual['calls'],m64,m32)):
            if 'reset' in b:continue
            self.assertNotIn('error',a);self.assertEqual(a['length'],b['length'])
            for key in ['output','q','k','v','attention']:
                x=np.asarray(a[key]);y=b[key];z=c[key]
                metric=dict(case=self.id(),call=i,tensor=key,m32_m64_maxabs=float(np.max(np.abs(z-y))),cuda_m32_maxabs=float(np.max(np.abs(x-z))),cuda_m64_maxabs=float(np.max(np.abs(x-y))))
                for label,left,right in [('cuda_m32',x,z),('m32_m64',z,y)]:
                    delta=left-right
                    metric[label+'_rmse']=float(np.sqrt(np.mean(delta*delta)))
                    denominator=float(np.linalg.norm(right))
                    relative=float(np.linalg.norm(delta))/denominator if denominator else float(np.linalg.norm(delta))
                    metric[label+'_relative_l2']=relative
                    self.assertLessEqual(float(np.max(np.abs(delta))),2e-5,str(metric))
                    self.assertLessEqual(relative,1e-5,str(metric))
                self.metrics.append(metric)
        return actual

    def test_prefill_matches_independent_reference(self):self.compare(fixture())
    def test_heldout_reference_seed(self):self.compare(fixture(256,64,qh=16,seed=1807))
    def test_real_head_dimension_partial_rope(self):self.compare(fixture(256,64,qh=16))
    def test_decode_chunk_and_prefill_equivalence(self):
        j=fixture();x=np.asarray(j['calls'][0]['x']).reshape(5,-1)
        full=self.compare(j)['calls'][0]
        j['calls']=[dict(x=row.tolist(),position=i) for i,row in enumerate(x)]
        steps=self.compare(j)['calls']
        np.testing.assert_allclose(np.concatenate([a['output'] for a in steps]),full['output'],rtol=2e-5,atol=2e-6)
        j['calls']=[dict(x=x[:2].ravel().tolist(),position=0),dict(x=x[2:].ravel().tolist(),position=2)]
        chunks=self.compare(j)['calls'];np.testing.assert_allclose(np.concatenate([a['output'] for a in chunks]),full['output'],rtol=2e-5,atol=2e-6)
    def test_causal_future_tokens_do_not_change_prefix(self):
        j=fixture();a=self.run_probe(j)['calls'][0];j['calls'][0]['x'][-12:]=[100.]*12
        b=self.run_probe(j)['calls'][0]
        np.testing.assert_array_equal(a['output'][:-12],b['output'][:-12])
    def test_zero_input_and_extreme_gates(self):
        j=fixture();j['calls'][0]['x']=[0.]*60;self.compare(j)
        j=fixture();w=np.asarray(j['qg']).reshape(4,16,12);w[:,8:,:]*=1000;j['qg']=w.ravel().tolist();self.compare(j)
    def test_reject_invalid_position_capacity_and_reset(self):
        j=fixture(context=5,chunk=5);x=j['calls'][0]['x'];j['calls']+=[dict(x=x[:12],position=5),dict(reset=True),dict(x=x[:12],position=1),dict(x=x[:12],position=0)]
        a=self.run_probe(j)['calls'];self.assertIn('error',a[1]);self.assertEqual(a[1]['length'],5);self.assertIn('error',a[3]);self.assertEqual(a[4]['length'],1)
    def test_real_bf16_layer_weights_with_synthetic_input(self):
        import struct
        model=ROOT.parent/'model/Qwen3.6-35B-A3B'
        cfg=json.loads((model/'config.json').read_text())['text_config']
        idx=json.loads((model/'model.safetensors.index.json').read_text())['weight_map']
        layer=cfg['layer_types'].index('full_attention')
        j=dict(hidden=cfg['hidden_size'],qh=cfg['num_attention_heads'],kh=cfg['num_key_value_heads'],dim=cfg['head_dim'],rotary=int(cfg['head_dim']*cfg['rope_parameters']['partial_rotary_factor']),theta=cfg['rope_parameters']['rope_theta'],eps=cfg['rms_norm_eps'],context=8,chunk=4,budget=256<<20,__real_model=str(model))
        for key,name in [('qg','q_proj'),('k','k_proj'),('v','v_proj'),('o','o_proj'),('qnorm','q_norm'),('knorm','k_norm')]:
            name=f'model.language_model.layers.{layer}.self_attn.{name}.weight'
            with (model/idx[name]).open('rb') as f:
                size=struct.unpack('<Q',f.read(8))[0];meta=json.loads(f.read(size))[name]
                self.assertEqual(meta['dtype'],'BF16');a,b=meta['data_offsets'];f.seek(8+size+a)
                raw=f.read(b-a);self.assertEqual(len(raw),b-a)
            j[key]=(np.frombuffer(raw,dtype='<u2').astype('<u4')<<16).view('<f4')
        rng=np.random.default_rng(109)
        x=(rng.standard_normal((3,j['hidden']))*.2).astype('f4')
        j['calls']=[dict(x=x[:2].ravel().tolist(),position=0),dict(x=x[2:].ravel().tolist(),position=2)]
        self.compare(j)
    def test_continuous_decode_nonzero_positions(self):
        j=fixture(context=2048);rng=np.random.default_rng(181)
        j['calls']=[dict(x=rng.standard_normal(12).astype('f4').tolist(),position=i) for i in range(64)]
        self.compare(j)
    def test_numeric_failure_invalidates_until_reset(self):
        j=fixture();x=j['calls'][0]['x'][:12]
        j['calls']=[dict(x=[3e38]*12,position=0),dict(x=x,position=0),dict(reset=True),dict(x=x,position=0)]
        a=self.run_probe(j)['calls'];self.assertIn('error',a[0]);self.assertIn('reset required',a[1]['error']);self.assertEqual(a[3]['length'],1)
    def test_reject_bad_shapes_and_memory_budget(self):
        for field,value in [('budget',1),('rotary',3),('kh',3),('dim',0),('theta',1e300),('eps',1e-300),('headroom',2**64-1)]:
            with self.subTest(field=field):
                j=fixture();j[field]=value;self.assertIn('error',self.run_probe(j,False))
        j=fixture();j['qnorm']=[];self.assertIn('error',self.run_probe(j,False))
    @classmethod
    def tearDownClass(cls):
        (BUILD/'numerics.json').write_text(json.dumps(cls.metrics,indent=2)+'\n')
        (BUILD/'memory.json').write_text(json.dumps(cls.memory,indent=2)+'\n')

if __name__=='__main__':unittest.main(verbosity=2)
