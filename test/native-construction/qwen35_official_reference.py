"""Pinned, unfused official DeltaNet used only by tests, never by NeurX serving.

The original AST bodies execute unchanged. Only Hub/accelerate decorators are
removed to select the pure fallback. No global Transformers files are modified.
"""
import __future__
import ast
import copy
import hashlib
from pathlib import Path
from types import SimpleNamespace
import numpy as np

SOURCE=Path('/home/shuwen/.local/lib/python3.12/site-packages/transformers/models/qwen3_5_moe/modeling_qwen3_5_moe.py')
PINS={
    'model':'16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d',
    'cache':'0d5fd6901ce2b7108eff40e06d7ce29e9b0f9cc8ed2f40d2fb3a2e4d4f43e630',
    'activation':'5b20c0a3625edc0001a98f09ce3c6b5baa1100e1d7ad8dee649e4d45c8468665',
}
REMOVED={'use_kernel_func_from_hub_with_fallback','use_kernel_forward_from_hub','force_accelerate_hooks'}


def load_official(source=SOURCE):
    source=Path(source)
    paths={'model':source,'cache':source.parents[2]/'cache_utils.py','activation':source.parents[2]/'activations.py'}
    texts={}
    # Verify all bytes before executing any source or importing its dependencies.
    for role,path in paths.items():
        data=path.read_bytes()
        if hashlib.sha256(data).hexdigest()!=PINS[role]:raise ValueError(f'official {role} SHA256 mismatch: {path}')
        texts[role]=data.decode()
    import torch
    from abc import ABC,abstractmethod
    ns=dict(__name__='neurx_pinned_official_reference',torch=torch,nn=torch.nn,F=torch.nn.functional,
            ABC=ABC,abstractmethod=abstractmethod,is_torchdynamo_compiling=torch.compiler.is_compiling,
            _is_torch_greater_or_equal_than_2_7=False)
    selections={
        'activation':['SiLUActivation'],
        'cache':['LinearAttentionCacheLayerMixin','LinearAttentionLayer','Cache'],
        'model':['Qwen3_5MoeRMSNormGated','apply_mask_to_padding_states','causal_conv1d_update','causal_conv1d_fn','l2norm','torch_chunk_gated_delta_rule','torch_recurrent_gated_delta_rule','Qwen3_5MoeGatedDeltaNet'],
    }
    provenance=dict(source_sha256=PINS.copy(),ast={},removed_decorators=[])
    for role,names in selections.items():
        tree=ast.parse(texts[role]);available={n.name:n for n in tree.body if isinstance(n,(ast.ClassDef,ast.FunctionDef))}
        nodes=[]
        for name in names:
            original=available[name];node=copy.deepcopy(original)
            provenance['ast'][name]=hashlib.sha256(ast.dump(original,include_attributes=False).encode()).hexdigest()
            for child in ast.walk(node):
                if not isinstance(child,(ast.ClassDef,ast.FunctionDef,ast.AsyncFunctionDef)):continue
                keep=[]
                for decorator in child.decorator_list:
                    key=decorator.func.id if isinstance(decorator,ast.Call) and isinstance(decorator.func,ast.Name) else None
                    if key in REMOVED:provenance['removed_decorators'].append(dict(node=child.name,decorator=ast.unparse(decorator)))
                    else:keep.append(decorator)
                child.decorator_list=keep
            nodes.append(node)
        code=compile(ast.Module(body=nodes,type_ignores=[]),str(paths[role]),'exec',flags=__future__.annotations.compiler_flag)
        exec(code,ns)
        if role=='activation':ns['ACT2FN']={'silu':ns['SiLUActivation']()}
    ns['provenance']=provenance
    return ns


def configure_runtime():
    import os,torch
    if not torch.__version__.startswith('2.6.0+cu124'):raise RuntimeError(f'unpinned Torch runtime: {torch.__version__}')
    if not torch.cuda.is_available():raise RuntimeError('official GPU oracle requires CUDA access')
    if os.environ.get('CUBLAS_WORKSPACE_CONFIG')!=':4096:8':raise RuntimeError('set CUBLAS_WORKSPACE_CONFIG=:4096:8 before Torch CUDA initialization')
    torch.set_num_threads(1);torch.manual_seed(781)
    torch.set_float32_matmul_precision('highest')
    torch.backends.cuda.matmul.allow_tf32=False
    torch.backends.cuda.matmul.allow_bf16_reduced_precision_reduction=False
    torch.backends.cudnn.allow_tf32=False;torch.backends.cudnn.benchmark=False
    torch.backends.cudnn.deterministic=True;torch.use_deterministic_algorithms(True)
    torch.cuda.set_per_process_memory_fraction(.1)
    return dict(torch=torch.__version__,cuda=torch.version.cuda,cudnn=torch.backends.cudnn.version(),
                device=torch.cuda.get_device_name(),matmul='highest',tf32=False,bf16_reduced_precision_reduction=False,
                deterministic=True,allocator_fraction=.1,autocast=False,compile=False)


def _bf16(values):
    a=np.asarray(values,dtype=np.float32)
    if not np.isfinite(a).all():raise ValueError('nonfinite reference input')
    bits=a.view(np.uint32)
    words=((bits+np.uint32(0x7fff)+((bits>>16)&1))>>16).astype(np.uint32)
    result=(words<<16).view(np.float32)
    if not np.isfinite(result).all():raise ValueError('BF16 conversion overflow')
    return result if isinstance(values,np.ndarray) else result.tolist()


def bf16_fixture(j):
    result=copy.deepcopy(j)
    for key in ['qkv','z','a','b','out','conv_weight','norm','alog','dt','initial_history']:
        if key in result:result[key]=_bf16(result[key])
    if 'initial_state' in result:result['initial_state']=np.asarray(result['initial_state'],dtype=np.float32).tolist()
    for call in result['calls']:
        if 'x' in call:call['x']=_bf16(call['x'])
    return result


def error_metrics(actual,reference):
    a=np.asarray(actual,dtype=np.float64);b=np.asarray(reference,dtype=np.float64)
    if a.shape!=b.shape:raise ValueError('reference comparison shape mismatch')
    if not np.isfinite(a).all() or not np.isfinite(b).all():raise ValueError('nonfinite reference comparison')
    delta=a-b;na=np.linalg.norm(a);nb=np.linalg.norm(b)
    return dict(maxabs=float(np.max(np.abs(delta))),rmse=float(np.sqrt(np.mean(delta*delta))),
                relative_l2=float(np.linalg.norm(delta)/max(nb,1e-12)),
                cosine=float(np.clip(np.dot(a.ravel(),b.ravel())/(na*nb),-1,1)) if na and nb else float(not na and not nb))


def run_official(j,partition='decode',observe=False,trace_stages=False):
    import torch
    from torch.utils._python_dispatch import TorchDispatchMode
    from torch.utils._pytree import tree_flatten
    from collections import Counter
    if partition not in ['decode','prefill']:raise ValueError('unknown reference partition')
    ns=load_official();modes=[];snap={};events=[];scope=['mixer'];counts=Counter();stages={};l2_calls=[0];conv_length=[0];current_tokens=[0]
    class Observer(TorchDispatchMode):
        def __torch_dispatch__(self,func,types,args=(),kwargs=None):
            result=func(*args,**(kwargs or {}))
            if trace_stages and str(func)=='aten.conv1d.default':
                trimmed=result[...,-conv_length[0]:] if scope[0]=='conv.decode' else result[...,:conv_length[0]]
                stages.setdefault('conv',[]).append(cpu(trimmed[...,-current_tokens[0]:].transpose(1,2)))
            if counts[scope[0]]<32:
                ins=[x for x in tree_flatten((args,kwargs))[0] if isinstance(x,torch.Tensor)]
                outs=[x for x in tree_flatten(result)[0] if isinstance(x,torch.Tensor)]
                events.append(dict(scope=scope[0],op=str(func),inputs=[str(x.dtype) for x in ins],outputs=[str(x.dtype) for x in outs],shapes=[list(x.shape) for x in outs]))
                counts[scope[0]]+=1
            return result
    def cpu(tensor):return tensor.detach().float().cpu().numpy().ravel().copy()
    def scoped(name,fn):
        def call(*args,**kwargs):
            before=scope[0];scope[0]=name
            try:return fn(*args,**kwargs)
            finally:scope[0]=before
        return call
    original_l2=ns['l2norm']
    def observed_l2(x,*args,**kwargs):
        result=original_l2(x,*args,**kwargs)
        if trace_stages:
            # Official repeats key heads before L2; native stores unique heads.
            name='q' if l2_calls[0]%2==0 else 'k';l2_calls[0]+=1
            stages.setdefault(name,[]).append(cpu(result[:,:,::(j['vh']//j['kh']),:]))
        return result
    ns['l2norm']=scoped('l2norm',observed_l2)
    for mode in ['chunk','recurrent']:
        name='torch_'+mode+'_gated_delta_rule';fn=ns[name]
        def core_call(*args,_fn=fn,_mode=mode,**kwargs):
            modes.append(_mode)
            result=_fn(*args,**kwargs)
            snap['core']=cpu(result[0]);snap['beta']=cpu(kwargs['beta']);snap['decay']=cpu(kwargs['g'].exp())
            return result
        ns[name]=scoped('core.'+mode,core_call)
    for name,tag in [('causal_conv1d_fn','conv.prefill'),('causal_conv1d_update','conv.decode')]:
        fn=ns[name]
        def conv_call(*args,_fn=fn,**kwargs):
            conv_length[0]=args[0].shape[-1]
            result=_fn(*args,**kwargs)
            if trace_stages:stages.setdefault('activated',[]).append(cpu(result[...,-current_tokens[0]:].transpose(1,2)))
            return result
        ns[name]=scoped(tag,conv_call)
    h,kh,vh,kd,vd,kernel=[j[n] for n in ['hidden','kh','vh','kd','vd','conv']]
    config=SimpleNamespace(hidden_size=h,linear_num_value_heads=vh,linear_num_key_heads=kh,
        linear_key_head_dim=kd,linear_value_head_dim=vd,linear_conv_kernel_dim=kernel,
        hidden_act='silu',rms_norm_eps=j['eps'],layer_types=['linear_attention'])
    model=ns['Qwen3_5MoeGatedDeltaNet'](config,0).to(device='cuda',dtype=torch.bfloat16).eval()
    mapping={'in_proj_qkv.weight':'qkv','in_proj_z.weight':'z','in_proj_a.weight':'a','in_proj_b.weight':'b',
             'conv1d.weight':'conv_weight','A_log':'alog','dt_bias':'dt','norm.weight':'norm','out_proj.weight':'out'}
    state={name:torch.as_tensor(np.asarray(j[key],dtype=np.float32)).reshape(model.state_dict()[name].shape).to(device='cuda',dtype=torch.bfloat16) for name,key in mapping.items()}
    model.load_state_dict(state,strict=True);del state
    cache=ns['Cache'](layers=[ns['LinearAttentionLayer']()]);layer=cache.layers[0]
    if 'initial_state' in j or 'initial_history' in j:
        history=torch.as_tensor(j.get('initial_history',[0.]*( (2*kh*kd+vh*vd)*kernel)),device='cuda',dtype=torch.bfloat16).reshape(1,-1,kernel)
        initial=torch.as_tensor(j.get('initial_state',[0.]*(vh*kd*vd)),device='cuda',dtype=torch.float32).reshape(1,vh,kd,vd)
        layer.lazy_initialization(conv_states=history,recurrent_states=initial,conv_kernel_size=kernel)
        layer.conv_states[0].copy_(history);layer.recurrent_states[0].copy_(initial);layer.has_previous_state[0]=True
    # Module hooks change observation scope only, never values or implementation.
    for name,module in model.named_modules():
        if not name:continue
        def pre(module,args,_name=name):scope.append(scope[0]);scope[0]='module.'+_name
        def post(module,args,output,_name=name):
            if trace_stages:
                key={'in_proj_qkv':'qkv','in_proj_z':'z','in_proj_a':'a','in_proj_b':'b','norm':'gated'}.get(_name)
                if key:stages.setdefault(key,[]).append(cpu(output))
            scope[0]=scope.pop()
        module.register_forward_pre_hook(pre);module.register_forward_hook(post)
    collected={k:[] for k in ['output','core','state','history','beta','decay']};dtype={}
    from contextlib import nullcontext
    with torch.inference_mode(),torch.autocast(device_type='cuda',enabled=False),Observer() if observe or trace_stages else nullcontext():
        for call in j['calls']:
            if 'reset' in call:cache.reset();continue
            x=torch.as_tensor(call['x'],device='cuda',dtype=torch.bfloat16).reshape(1,-1,h)
            if x.shape[1]>j['context']:raise ValueError('reference context limit')
            chunks=x.split(1,dim=1) if partition=='decode' else [x]
            for chunk in chunks:
                current_tokens[0]=chunk.shape[1]
                y=model(chunk,cache_params=cache)
                for key,tensor in [('output',y),('state',layer.recurrent_states[0]),('history',layer.conv_states[0])]:
                    collected[key].append(cpu(tensor));dtype[key+'_dtype']=str(tensor.dtype)
                for key in ['core','beta','decay']:collected[key].append(snap[key])
    torch.cuda.synchronize()
    return dict(**{k:np.concatenate(v) for k,v in collected.items()},**{k:np.concatenate(v) for k,v in stages.items()},**dtype,modes=modes,dtype_events=events,
                provenance=ns['provenance'],gpu_peak_allocated=torch.cuda.max_memory_allocated(),gpu_peak_reserved=torch.cuda.max_memory_reserved())
