"""Reference-only contract evidence. No Native kernels or fitted tolerances."""
import hashlib,json,subprocess
from pathlib import Path
import numpy as np
from qwen35_attention_official_reference import load_official,configure_runtime,fixture,run_reference,metrics
OUT=Path(__file__).resolve().parents[2]/'artifact/build/qwen35_attention_bf16/contract-review/v4'

def stats(a,b,bf16=False):
    a=np.asarray(a,dtype='f8');b=np.asarray(b,dtype='f8')
    finite=np.isfinite(a)&np.isfinite(b);delta=np.abs(a[finite]-b[finite])
    ulp=None
    if bf16 and finite.any():
        def ordered(x):
            bits=(x[finite].astype('f4').view('u4')>>16).astype('i8')
            return np.where(bits&32768,65535-bits,bits+32768)
        ulp=int(np.abs(ordered(a)-ordered(b)).max(initial=0))
    return dict(max_bf16_ulp=ulp,shape=list(a.shape),max_absolute_error=float(delta.max()) if delta.size else None,mean_absolute_error=float(delta.mean()) if delta.size else None,
      max_relative_error=float((delta/np.maximum(np.abs(b[finite]),np.finfo('f4').tiny)).max(initial=0)),
      near_zero=int((np.abs(b)<np.finfo('f4').tiny).sum()),near_zero_1e_6=int((np.abs(b)<1e-6).sum()),nan=int(np.isnan(a).sum()),inf=int(np.isinf(a).sum()),
      nan_pattern_equal=bool(np.array_equal(np.isnan(a),np.isnan(b))),inf_pattern_equal=bool(np.array_equal(np.isposinf(a),np.isposinf(b)) and np.array_equal(np.isneginf(a),np.isneginf(b))),
      finite_count=int(finite.sum()))

def main():
    import torch
    from torch.utils._python_dispatch import TorchDispatchMode
    OUT.mkdir(parents=True,exist_ok=True)
    runtime=configure_runtime();ns=load_official();norm=[];soft=[]
    def cpu(t):
        with torch._C._DisableTorchDispatch():return t.detach().float().cpu().numpy().astype('f8')
    class Observe(TorchDispatchMode):
        def __torch_dispatch__(self,func,types,args=(),kwargs=None):
            y=func(*args,**(kwargs or {}))
            if isinstance(y,torch.Tensor):
                op=str(func);aa=[cpu(v) if isinstance(v,torch.Tensor) else v for v in args]
                expected=None
                with np.errstate(all='ignore'):
                    if op=='aten.pow.Tensor_Scalar':expected=aa[0]**aa[1]
                    elif op=='aten.mean.dim':expected=np.mean(aa[0],axis=tuple(aa[1]),keepdims=aa[2] if len(aa)>2 else False)
                    elif op=='aten.add.Tensor':expected=aa[0]+aa[1]
                    elif op=='aten.mul.Tensor':expected=aa[0]*aa[1]
                    elif op=='aten.rsqrt.default':expected=1/np.sqrt(aa[0])
                local=None
                if expected is not None:
                    with torch._C._DisableTorchDispatch():rounded=torch.tensor(expected).to(y.dtype).float().numpy()
                    local=stats(cpu(y),rounded,bf16=y.dtype==torch.bfloat16)
                events.append(dict(op=op,dtype=str(y.dtype),device=str(y.device),values=cpu(y).tolist(),local_same_operands_fp64_metrics=local))
            return y
    for d in [6,8,64,256]:
      for seed in [521,1807]:
       rng=np.random.default_rng(seed)
       for kind,scale in [('random',1.),('zero',0.),('nearzero',1e-10),('tiny',1e-30),('large_safe',1e10),('overflow',1e20)]:
        m=ns['Qwen3_5MoeRMSNorm'](d,eps=1e-6).cuda().bfloat16()
        x=torch.tensor(rng.standard_normal((2,d))*scale,device='cuda',dtype=torch.bfloat16)
        w=rng.standard_normal(d)*.1;w[0]=-1.;w[1]=-0.99609375;w[2]=-1.0078125
        with torch.no_grad():m.weight.copy_(torch.tensor(w,device='cuda',dtype=torch.bfloat16))
        events=[]
        with torch.inference_mode(),Observe():y=m(x)
        a=cpu(x);weight=cpu(m.weight);ideal=a/np.sqrt(np.mean(a*a,axis=-1,keepdims=True)+1e-6)*(1+weight)
        expected=torch.tensor(ideal.astype('f4')).bfloat16().float().numpy()
        r=stats(cpu(y),expected,bf16=True);r['bf16_bits_mismatch']=int((cpu(y).astype('f4').view('u4')!=expected.view('u4')).sum())
        norm.append(dict(d=d,seed=seed,kind=kind,input=a.tolist(),weight=weight.tolist(),output=cpu(y).tolist(),metrics=r,events=events))
    for n in [1,3,63,64,65,257]:
     for seed in [521,1807]:
      rng=np.random.default_rng(seed)
      for kind in ['random','causal','all_finite_mask','all_inf_mask','extreme','tiny_prob']:
       a=rng.standard_normal((2,n))*3
       if kind=='causal':a[:,(n+1)//2:]=torch.finfo(torch.bfloat16).min
       if kind=='all_finite_mask':a[:]=torch.finfo(torch.bfloat16).min
       if kind=='all_inf_mask':a[:]=-np.inf
       if kind=='extreme':a[:]=np.linspace(-1e4,1e4,n)
       if kind=='tiny_prob':a[:]=np.linspace(-110,0,n)
       x=torch.tensor(a,device='cuda',dtype=torch.bfloat16)
       with torch.inference_mode():y=torch.nn.functional.softmax(x,dim=-1,dtype=torch.float32);p=y.bfloat16()
       a=cpu(x)
       with np.errstate(invalid='ignore',divide='ignore',under='ignore'):
        z=a-a.max(-1,keepdims=True);e=np.exp(z);ideal=e/e.sum(-1,keepdims=True)
       expected=ideal.astype('f4');bp=torch.tensor(expected).bfloat16().float().numpy()
       r=stats(cpu(p),bp,bf16=True);r['bf16_bits_mismatch']=int((cpu(p).astype('f4').view('u4')!=bp.view('u4')).sum())
       # Explicit decomposed GPU diagnostic is NOT torch softmax's hidden implementation.
       with torch.inference_mode():
        f=x.float();mx=f.max(-1,keepdim=True).values;sub=f-mx;ex=sub.exp();sm=ex.sum(-1,keepdim=True);div=ex/sm
       soft.append(dict(n=n,seed=seed,kind=kind,input=a.tolist(),fp32_output=cpu(y).tolist(),bf16_output=cpu(p).tolist(),
          fp32_metrics=stats(cpu(y),expected),bf16_metrics=r,decomposed_not_internal=dict(max=cpu(mx).tolist(),subtract=cpu(sub).tolist(),exp=cpu(ex).tolist(),sum=cpu(sm).tolist(),normalize=cpu(div).tolist(),metrics_vs_official=stats(cpu(div),cpu(y)))))
    comp=[];propagation=[]
    for length in [3,17,65]:
      j=fixture(seed=521,length=length);j['chunks']=[1,length-1]
      runs={k:run_reference(j,k) for k in ['prefill','decode','chunks']}
      perturbed=dict(j);perturbed['x']=list(j['x'])
      # One known BF16 representable step away, no Native results involved.
      first=np.float32(perturbed['x'][0]);bits=np.asarray(first).view('u4').item();perturbed['x'][0]=np.asarray(bits+65536,dtype='u4').view('f4').item()
      changed=run_reference(perturbed,'prefill')
      propagation.append(dict(length=length,input_before=float(first),input_after=perturbed['x'][0],
        description='upstream input perturbation, not local kernel error or universal bound',
        stage_total_changes={key:stats(value,runs['prefill']['arrays'][key]) for key,value in changed['arrays'].items()},
        perturbed_local_same_operands=[dict(node=z['node'],metrics=z['metrics']) for z in changed['nodes']]))
      (OUT/f'composition-t{length}-perturbed.json').write_text(json.dumps(changed))
      for k,r in runs.items():
       (OUT/f'composition-t{length}-{k}.json').write_text(json.dumps(r))
       comp.append(dict(length=length,partition=k,output_vs_prefill=stats(r['output'],runs['prefill']['output']),
         cache_k_vs_prefill=stats(r['cache'][-1]['k'],runs['prefill']['cache'][-1]['k']),
         cache_v_vs_prefill=stats(r['cache'][-1]['v'],runs['prefill']['cache'][-1]['v']),
         local_same_operands=[dict(node=z['node'],call=z['call'],metrics=z['metrics']) for z in r['nodes']]))
    for name,data in [('norm',norm),('softmax',soft),('composition',comp),('propagation',propagation),('runtime',runtime),('provenance',ns['provenance'])]:
      (OUT/(name+'.json')).write_text(json.dumps(data,indent=2,allow_nan=True))
    torch.cuda.synchronize()
    print(json.dumps(dict(norm_cases=len(norm),softmax_cases=len(soft),composition_partitions=len(comp),device=runtime['device'],status='REFERENCE_DIAGNOSTICS_COMPLETED_NOT_NATIVE_PASS')))
if __name__=='__main__':main()
