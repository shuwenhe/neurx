"""Independent, ordered FP64/FP32 DeltaNet math including every recurrent state.

Changes to decay/prediction/update order, head replication, conv tap order or
storing post-conv instead of raw history must fail these numerical comparisons.
"""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import unittest
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'artifact/build/qwen35_stage3'


def fixture(kd=3,vd=4,kh=2,vh=4,context=64,chunk=8,seed=781):
    rng=np.random.default_rng(seed);h=7;conv=4;raw=2*kh*kd+vh*vd
    j=dict(hidden=h,kh=kh,vh=vh,kd=kd,vd=vd,conv=conv,context=context,chunk=chunk,eps=1e-6)
    for key,shape in [('qkv',(raw,h)),('z',(vh*vd,h)),('a',(vh,h)),('b',(vh,h)),('out',(h,vh*vd)),('conv_weight',(raw,conv))]:
        j[key]=(rng.standard_normal(shape)*.2).astype('f4').ravel().tolist()
    j['norm']=(1+rng.standard_normal(vd)*.1).astype('f4').tolist()
    j['alog']=(rng.standard_normal(vh)*.2).astype('f4').tolist();j['dt']=(rng.standard_normal(vh)*.2).astype('f4').tolist()
    j['calls']=[dict(x=rng.standard_normal((5,h)).astype('f4').ravel().tolist(),position=0)]
    return j


def reference(j,dtype):
    h,kh,vh,kd,vd,conv=[j[k] for k in ['hidden','kh','vh','kd','vd','conv']]
    kw=kh*kd;vw=vh*vd;raw=2*kw+vw
    state=np.asarray(j.get('initial_state',[0.]*(vh*kd*vd)),dtype=dtype).reshape(vh,kd,vd).copy()
    history=np.asarray(j.get('initial_history',[0.]*(raw*conv)),dtype=dtype).reshape(raw,conv).copy()
    past=0;results=[]
    def mm(x,w):
        result=np.zeros((x.shape[0],w.shape[0]),dtype=dtype)
        for f in range(x.shape[1]):result=np.add(result,x[:,f:f+1]*w[:,f][None,:],dtype=dtype)
        return result
    def sum_last(x):
        result=np.zeros(x.shape[:-1],dtype=dtype)
        for f in range(x.shape[-1]):result=np.add(result,x[...,f],dtype=dtype)
        return result
    def sigmoid(x):
        e=np.exp(-np.abs(x));return np.where(x>=0,1/(1+e),e/(1+e))
    weights={k:np.asarray(j[k],dtype=dtype) for k in ['qkv','z','a','b','out','conv_weight','norm','alog','dt']}
    for call in j['calls']:
        if 'reset' in call:
            state.fill(0);history.fill(0);past=0;results.append(dict(reset=True));continue
        x=np.asarray(call['x'],dtype=dtype).reshape(-1,h)
        qkv=mm(x,weights['qkv'].reshape(raw,h));z=mm(x,weights['z'].reshape(vw,h));a=mm(x,weights['a'].reshape(vh,h));b=mm(x,weights['b'].reshape(vh,h))
        t={k:[] for k in ['output','core','state','history','q','k','beta','decay']}
        for i in range(len(x)):
            history[:,:-1]=history[:,1:];history[:,-1]=qkv[i]
            product=history*weights['conv_weight'].reshape(raw,conv)
            activated=sum_last(product);activated*=sigmoid(activated)
            q=activated[:kw].reshape(kh,kd).copy();k=activated[kw:2*kw].reshape(kh,kd).copy();v=activated[2*kw:].reshape(vh,vd)
            q/=np.sqrt(sum_last(q*q)[:,None]+dtype(1e-6));q/=np.sqrt(dtype(kd))
            k/=np.sqrt(sum_last(k*k)[:,None]+dtype(1e-6))
            beta=sigmoid(b[i]);u=a[i]+weights['dt']
            softplus=np.maximum(u,0)+np.log1p(np.exp(-np.abs(u)))
            with np.errstate(over='ignore',under='ignore',invalid='ignore'):
                decay=np.exp(-np.exp(weights['alog'])*softplus)
            core=np.zeros((vh,vd),dtype=dtype)
            for head in range(vh):
                g=head//(vh//kh)
                state[head]*=decay[head]
                pred=np.zeros(vd,dtype=dtype)
                for f in range(kd):pred+=state[head,f]*k[g,f]
                delta=beta[head]*(v[head]-pred)
                for f in range(kd):
                    state[head,f]+=k[g,f]*delta
                    core[head]+=state[head,f]*q[g,f]
            gated=core/np.sqrt(sum_last(core*core)[:,None]/dtype(vd)+dtype(j['eps']))
            gated*=weights['norm'][None,:];gated*=z[i].reshape(vh,vd)*sigmoid(z[i].reshape(vh,vd))
            output=mm(gated.reshape(1,vw),weights['out'].reshape(h,vw))[0]
            for key,value in [('output',output),('core',core),('state',state),('history',history),('q',q),('k',k),('beta',beta),('decay',decay)]:t[key].extend(value.ravel().copy())
        past+=len(x);t['length']=past;results.append(t)
    return results


class Stage3(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        BUILD.mkdir(parents=True,exist_ok=True);cls.probe=BUILD/'probe';cls.metrics=[];cls.memory=[];cls.weight_hashes={};cls.curves=[]
        if os.environ.get('QWEN35_STAGE3_PROBE'):cls.probe=Path(os.environ['QWEN35_STAGE3_PROBE'])
        else:
            cmd=['nvcc','-std=c++17','-O2','-U_FORTIFY_SOURCE','-D_FORTIFY_SOURCE=0','--fmad=false','-arch=sm_89',str(ROOT/'test/native-construction/qwen35_stage3_probe.cu'),str(ROOT/'backend/platform/cuda/hybrid_deltanet_cuda.cu'),str(ROOT/'backend/platform/cuda/hybrid_attention_cuda.cu'),*[str(ROOT/'src/runtime/model'/f) for f in ['hybrid_config.cpp','mapped_weight_store.cpp','architecture_registry.cpp']],'-lcrypto','-o',str(cls.probe)]
            p=subprocess.run(cmd,capture_output=True,text=True,timeout=120)
            if p.returncode:raise AssertionError(p.stdout+p.stderr)
    def run_probe(self,j,success=True):
        args=[str(self.probe)];data=j
        if '__real_model' in j:
            args+=['--model',j['__real_model']]
            data={k:v for k,v in j.items() if k not in ['qkv','z','a','b','conv_weight','alog','dt','norm','out','__real_model']}
        p=subprocess.run(args,input=json.dumps(data),capture_output=True,text=True,timeout=120)
        self.assertEqual(p.returncode,0 if success else 1,p.stdout[:2000]+p.stderr)
        return json.loads(p.stdout)
    def compare(self,j):
        a=self.run_probe(j);m32=reference(j,np.float32);m64=reference(j,np.float64)
        h,kh,vh,kd,vd,conv,c=[j[k] for k in ['hidden','kh','vh','kd','vd','conv','chunk']]
        kw=kh*kd;vw=vh*vd;raw=2*kw+vw;sc=vh*kd*vd
        expected=4*(h*(raw+2*vw+2*vh)+2*raw*conv+2*vh+vd+sc+c*(2*h+raw+vw+2*vh)+raw+2*kw+2*vw+2*vh)
        self.assertEqual(a['allocated'],expected)
        self.memory.append(dict(case=self.id(),allocated=a['allocated'],free_before=a['free_before'],free_after=a['free_after']))
        self.assertEqual(len(a['calls']),len(m64));self.assertEqual(len(m32),len(m64))
        for i,(actual,b,c) in enumerate(zip(a['calls'],m32,m64)):
            if 'reset' in c:continue
            self.assertNotIn('error',actual);self.assertEqual(actual['length'],c['length'])
            for key in ['output','core','state','history','q','k','beta','decay']:
                x=np.asarray(actual[key],dtype=np.float64);y=np.asarray(b[key],dtype=np.float64);z=np.asarray(c[key],dtype=np.float64)
                metric=dict(case=self.id(),call=i,tensor=key)
                for label,left,right in [('cuda_m32',x,y),('m32_m64',y,z)]:
                    delta=left-right;norm=np.linalg.norm(right)
                    metric[label+'_maxabs']=float(np.max(np.abs(delta)));metric[label+'_rmse']=float(np.sqrt(np.mean(delta*delta)))
                    metric[label+'_relative_l2']=float(np.linalg.norm(delta)/max(norm,1e-12))
                    left_norm=np.linalg.norm(left)
                    metric[label+'_cosine']=float(np.clip(np.dot(left,right)/(left_norm*norm),-1,1)) if left_norm and norm else float(not left_norm and not norm)
                    tokens=len(j['calls'][i]['x'])//j['hidden']
                    e=delta.reshape(tokens,-1);r=right.reshape(tokens,-1)
                    self.curves.append(dict(case=self.id(),call=i,tensor=key,comparison=label,token_start=j['calls'][i]['position'],maxabs=np.max(np.abs(e),axis=1).tolist(),relative_l2=(np.linalg.norm(e,axis=1)/np.maximum(np.linalg.norm(r,axis=1),1e-12)).tolist(),rmse=np.sqrt(np.mean(e*e,axis=1)).tolist()))
                    # Frozen after calibration: tested FP32 math only, not official BF16.
                    self.assertLessEqual(metric[label+'_maxabs'],2e-5,str(metric));self.assertLessEqual(metric[label+'_relative_l2'],5e-5,str(metric))
                self.metrics.append(metric)
        return a
    def test_prefill_every_token_output_state_history(self):self.compare(fixture())
    def test_independent_heldout_seed(self):
        for seed in [2191,7419]:self.compare(fixture(seed=seed))
    def test_extreme_beta_and_zero_input_nonzero_state(self):
        j=fixture();j['b']=(np.asarray(j['b'])*1000).tolist();self.compare(j)
        j=fixture();j['calls'][0]['x']=[0.]*35;j['initial_state']=[.1]*(4*3*4);self.compare(j)
    def test_real_bf16_weights_synthetic_input(self):
        import struct
        model=ROOT.parent/'model/Qwen3.6-35B-A3B';cfg=json.loads((model/'config.json').read_text())['text_config']
        index=json.loads((model/'model.safetensors.index.json').read_text())['weight_map'];layer=cfg['layer_types'].index('linear_attention')
        j=dict(hidden=cfg['hidden_size'],kh=cfg['linear_num_key_heads'],vh=cfg['linear_num_value_heads'],kd=cfg['linear_key_head_dim'],vd=cfg['linear_value_head_dim'],conv=cfg['linear_conv_kernel_dim'],eps=cfg['rms_norm_eps'],context=8,chunk=2,budget=256<<20,__real_model=str(model))
        fields={'qkv':'in_proj_qkv.weight','z':'in_proj_z.weight','a':'in_proj_a.weight','b':'in_proj_b.weight','conv_weight':'conv1d.weight','alog':'A_log','dt':'dt_bias','norm':'norm.weight','out':'out_proj.weight'}
        for key,suffix in fields.items():
            name=f'model.language_model.layers.{layer}.linear_attn.{suffix}'
            with (model/index[name]).open('rb') as f:
                size=struct.unpack('<Q',f.read(8))[0];meta=json.loads(f.read(size))[name];self.assertEqual(meta['dtype'],'BF16')
                start,end=meta['data_offsets'];f.seek(8+size+start);raw=f.read(end-start);self.assertEqual(len(raw),end-start)
            self.weight_hashes[name]=hashlib.sha256(raw).hexdigest();j[key]=(np.frombuffer(raw,dtype='<u2').astype('<u4')<<16).view('<f4')
        x=(np.random.default_rng(1401).standard_normal((3,j['hidden']))*.2).astype('f4')
        j['calls']=[dict(x=x[:2].ravel().tolist(),position=0),dict(x=x[2:].ravel().tolist(),position=2)];self.compare(j)
    def test_hybrid_state_tags_owner_and_reset(self):
        j=fixture();j['mixer_state_test']=True;a=self.run_probe(j)
        for key in ['owner_rejected','full_kind','linear_kind','full_trace','linear_trace']:self.assertTrue(a[key])
        self.assertEqual(a['full_length'],1);self.assertEqual(a['linear_length'],1);self.assertEqual(a['reset_lengths'],[0,0]);self.assertEqual(a['full_output'],[0.]*7)
        j['calls'][0]['x']=j['calls'][0]['x'][:7]
        np.testing.assert_allclose(a['linear_output'],reference(j,np.float64)[0]['output'],atol=2e-5,rtol=5e-5)
    def test_nonzero_initial_state_and_history(self):
        j=fixture();rng=np.random.default_rng(3)
        j['initial_state']=(rng.standard_normal(4*3*4)*.1).astype('f4').tolist();j['initial_history']=(rng.standard_normal((12+16)*4)*.1).astype('f4').ravel().tolist();self.compare(j)
    def test_chunk_decode_equivalence(self):
        j=fixture();x=np.asarray(j['calls'][0]['x']).reshape(5,7);a=self.compare(j)['calls'][0]
        j['calls']=[dict(x=row.tolist(),position=i) for i,row in enumerate(x)]
        b=self.compare(j)['calls']
        for key in ['output','state','history']:np.testing.assert_allclose(a[key],np.concatenate([c[key] for c in b]),rtol=1e-6,atol=1e-7)
        j['calls']=[dict(x=x[:2].ravel().tolist(),position=0),dict(x=x[2:].ravel().tolist(),position=2)];self.compare(j)
    def test_zero_small_norm_and_extreme_decay(self):
        for scale in [0.,1e-8,1.]:
            j=fixture();j['calls'][0]['x']=(np.asarray(j['calls'][0]['x'])*scale).tolist();j['dt']=[-80.,80.,-20.,20.];j['alog']=[10.,10.,-10.,-10.];self.compare(j)
    def test_real_head_dimensions(self):self.compare(fixture(kd=128,vd=128,kh=16,vh=32,context=8,chunk=5))
    def test_sequence_and_chunk_boundaries(self):
        for length in [1,3,4,63,64,65,257]:
            j=fixture(kd=2,vd=2,kh=1,vh=2,context=length,chunk=length,seed=length+14)
            x=np.random.default_rng(3+length).standard_normal((length,7)).astype('f4')
            j['calls']=[dict(x=x.ravel().tolist(),position=0)];self.compare(j)
            if length==65:
                j['calls']=[dict(x=x[:63].ravel().tolist(),position=0),dict(x=x[63:64].ravel().tolist(),position=63),dict(x=x[64:].ravel().tolist(),position=64)];self.compare(j)
    def test_exact_unit_and_zero_decay_limits(self):
        j=fixture();j['alog']=[-1000.,100.,10.,-10.];j['dt']=[-80.,80.,20.,-20.];self.compare(j)
    def test_continuous_decode_2048(self):
        j=fixture(kd=2,vd=2,kh=1,vh=2,context=2048,chunk=1)
        rng=np.random.default_rng(91);j['calls']=[dict(x=rng.standard_normal(7).astype('f4').tolist(),position=i) for i in range(2048)];self.compare(j)
    def test_long_operator_8192(self):
        j=fixture(kd=2,vd=2,kh=1,vh=2,context=8192,chunk=8192,seed=992)
        j['alog']=[-8.]*j['vh']  # near-unit decay stresses long-state accumulation
        j['calls']=[dict(x=np.random.default_rng(109).standard_normal((8192,7)).astype('f4').ravel().tolist(),position=0)];self.compare(j)
    def test_trace_admission_bounds_actual_vector_capacity(self):
        j=fixture(kd=128,vd=128,kh=16,vh=32,context=29,chunk=29)
        j['calls']=[dict(x=[0.]*(29*7),position=0,summary_only=True)]
        actual=self.run_probe(j)['calls'][0]
        self.assertEqual(actual['length'],29)
        self.assertGreater(actual['trace_capacity_bytes'],60<<20)
        self.assertLessEqual(actual['trace_capacity_bytes'],64<<20)
    def test_failure_invalid_reset_and_trace_budget(self):
        j=fixture();x=j['calls'][0]['x'][:7]
        j['calls']=[dict(x=[3e38]*7,position=0),dict(x=x,position=0),dict(reset=True),dict(x=x,position=0)]
        a=self.run_probe(j)['calls'];self.assertIn('error',a[0]);self.assertIn('reset required',a[1]['error']);self.assertEqual(a[3]['length'],1)
        j=fixture(kd=128,vd=128,kh=16,vh=32,context=32,chunk=32);j['calls']=[dict(x=[0.]*(32*7),position=0)]
        a=self.run_probe(j)['calls'][0];self.assertIn('trace exceeds',a['error']);self.assertEqual(a['length'],0)
        for field in ['initial_state','initial_history','norm']:
            j=fixture();j[field]=[1.];self.assertIn('error',self.run_probe(j,False))
    def test_reset_capacity_position_and_budget(self):
        j=fixture(context=5,chunk=5);x=j['calls'][0]['x'][:7];j['calls']+=[dict(x=x,position=5),dict(reset=True),dict(x=x,position=1),dict(x=x,position=0)]
        a=self.run_probe(j)['calls'];self.assertIn('error',a[1]);self.assertIn('error',a[3]);self.assertEqual(a[4]['length'],1)
        for field,value in [('budget',1),('headroom',2**64-1),('eps',1e-300),('kh',3),('conv',0)]:
            with self.subTest(field=field):
                j=fixture();j[field]=value;self.assertIn('error',self.run_probe(j,False))
    @classmethod
    def tearDownClass(cls):
        (BUILD/'numerics.json').write_text(json.dumps(cls.metrics,indent=2)+'\n')
        (BUILD/'memory.json').write_text(json.dumps(cls.memory,indent=2)+'\n')
        (BUILD/'weight-hashes.json').write_text(json.dumps(cls.weight_hashes,indent=2)+'\n')
        (BUILD/'token-error-curves.json').write_text(json.dumps(cls.curves)+'\n')
if __name__=='__main__':unittest.main(verbosity=2)
