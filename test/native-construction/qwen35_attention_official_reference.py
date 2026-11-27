"""Pinned official eager Attention. Observation only; never a serving backend.

Math class/function AST bodies execute unchanged. Explicitly omitted decorators
are provenance-recorded. CPU FP64 diagnostics are not CUDA acceptance results.
"""
import __future__
import ast
import copy
import hashlib
from pathlib import Path
from types import SimpleNamespace
import numpy as np
from qwen35_official_reference import configure_runtime, _bf16

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('/home/shuwen/.local/lib/python3.12/site-packages/transformers/models/qwen3_5_moe/modeling_qwen3_5_moe.py')
PINS = {
    'model': '16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d',
    'cache': '0d5fd6901ce2b7108eff40e06d7ce29e9b0f9cc8ed2f40d2fb3a2e4d4f43e630',
    'generic': 'b60d9ecbbaeadb084134dda4a9b92419d35d22af6bc882e062fd530f4e47a4e1',
    'torch_functional': '724c30072ca0cb69228553a636b2937ff88b60a2a2c80b806bd2a3827033e2b6',
}


def load_official(source=SOURCE):
    import inspect
    import torch
    from abc import ABC, abstractmethod
    from contextlib import nullcontext
    source = Path(source)
    paths = {'model': source, 'cache': source.parents[2]/'cache_utils.py',
             'generic': source.parents[2]/'utils/generic.py',
             'torch_functional': Path(inspect.getsourcefile(torch.nn.functional.softmax))}
    texts = {}
    for role, path in paths.items():
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != PINS[role]:
            raise ValueError(f'official {role} SHA256 mismatch: {path}')
        texts[role] = raw.decode()
    ns = dict(__name__='neurx_pinned_attention_reference', torch=torch, nn=torch.nn,
              ABC=ABC, abstractmethod=abstractmethod, nullcontext=nullcontext,
              _is_torch_available=True, is_torchdynamo_compiling=torch.compiler.is_compiling)
    selections = {
        'generic': ['maybe_autocast'],
        'cache': ['CacheLayerMixin', 'DynamicLayer', 'Cache'],
        'model': ['Qwen3_5MoeTextRotaryEmbedding', 'rotate_half', 'apply_rotary_pos_emb',
                  'repeat_kv', 'eager_attention_forward', 'Qwen3_5MoeRMSNorm', 'Qwen3_5MoeAttention'],
    }
    provenance = dict(source_sha256=PINS.copy(), ast={}, math_bodies={}, removed_decorators=[],
                      backend='explicit_eager', rotary_policy='default only; removed dynamic-update wrapper')
    for role, names in selections.items():
        available = {n.name: n for n in ast.parse(texts[role]).body
                     if isinstance(n, (ast.ClassDef, ast.FunctionDef))}
        nodes = []
        for name in names:
            original = available[name]
            node = copy.deepcopy(original)
            provenance['ast'][name] = hashlib.sha256(ast.dump(original, include_attributes=False).encode()).hexdigest()
            for child in ast.walk(node):
                if not isinstance(child, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
                    continue
                kept = []
                for decorator in child.decorator_list:
                    text = ast.unparse(decorator)
                    if text == 'dynamic_rope_update' or text.startswith('deprecate_kwarg('):
                        provenance['removed_decorators'].append(dict(node=child.name, decorator=text))
                    else:
                        kept.append(decorator)
                child.decorator_list = kept
            # Decorator removal must not alter any function statement body.
            def body_hashes(tree):
                return {n.name + ':' + str(n.lineno): hashlib.sha256(
                    ast.dump(ast.Module(body=n.body, type_ignores=[]), include_attributes=False).encode()).hexdigest()
                    for n in ast.walk(tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
            before, after = body_hashes(original), body_hashes(node)
            if before != after:
                raise ValueError('official mathematical body changed')
            provenance['math_bodies'][name] = before
            nodes.append(node)
        exec(compile(ast.Module(body=nodes, type_ignores=[]), str(paths[role]), 'exec',
                     flags=__future__.annotations.compiler_flag), ns)
    class EagerOnly:
        @staticmethod
        def get_interface(name, default):
            if name != 'eager':
                raise ValueError('reference must explicitly select eager')
            return default
    ns['ALL_ATTENTION_FUNCTIONS'] = EagerOnly()
    ns['provenance'] = provenance
    return ns


def fixture(seed=521, length=5, dim=8, rotary=4, hidden=12, qh=4, kh=2):
    rng = np.random.default_rng(seed)
    j = dict(seed=seed, hidden=hidden, qh=qh, kh=kh, dim=dim, rotary=rotary,
             theta=1e7, eps=1e-6, origin=0, length=length)
    for key, shape in [('qg', (qh*dim*2, hidden)), ('k', (kh*dim, hidden)),
                       ('v', (kh*dim, hidden)), ('o', (hidden, qh*dim))]:
        j[key] = _bf16((rng.standard_normal(shape)*.15).astype('f4')).ravel().tolist()
    for key in ['qnorm', 'knorm']:
        j[key] = _bf16((rng.standard_normal(dim)*.1).astype('f4')).tolist()
    j['x'] = _bf16(rng.standard_normal((length, hidden)).astype('f4')).ravel().tolist()
    return j


def metrics(actual, expected, bf16=False):
    a, b = np.asarray(actual, dtype='f8'), np.asarray(expected, dtype='f8')
    if a.shape != b.shape:
        raise ValueError(f'metric shape mismatch {a.shape} != {b.shape}')
    delta = np.abs(a-b)
    finite = np.isfinite(a) & np.isfinite(b)
    if not finite.all():
        raise ValueError('nonfinite trace/diagnostic reference')
    bf16_mismatch=None;ulp=None
    if bf16:
        aw=np.asarray(a,dtype='<f4').view('<u4')>>16
        bw=np.asarray(b,dtype='<f4').view('<u4')>>16
        ordered=lambda words: np.where(words & 0x8000,0x8000-(words & 0x7fff).astype('i8'),0x8000+words.astype('i8'))
        bf16_mismatch=int(np.count_nonzero(aw!=bw));ulp=int(np.max(np.abs(ordered(aw)-ordered(bw))))
    return dict(reference_near_zero_count=int(np.count_nonzero(np.abs(b)<=np.finfo('f4').tiny)),
                nonfinite_locations=dict(actual=np.argwhere(~np.isfinite(a)).tolist(),reference=np.argwhere(~np.isfinite(b)).tolist()),
                bf16_bit_mismatch_count=bf16_mismatch,max_bf16_ulp=ulp,
                max_absolute_error=float(delta.max()), mean_absolute_error=float(delta.mean()),
                max_relative_error=float(np.max(delta/np.maximum(np.abs(b), np.finfo('f4').tiny))),
                relative_denominator_floor=float(np.finfo('f4').tiny),
                nan=int(np.isnan(a).sum()), inf=int(np.isinf(a).sum()),
                comparison='same captured operands: independent CPU FP64 semantic replay; explicit FP64->FP32->BF16 output conversion where applicable')


def run_reference(j, partition='prefill', observe=True):
    import torch
    from torch.utils._python_dispatch import TorchDispatchMode
    from torch.utils._pytree import tree_flatten
    from contextlib import nullcontext
    if partition not in ['prefill', 'decode', 'chunks']:
        raise ValueError('invalid partition')
    ns = load_official()
    h, qh, kh, dim, rotary = [j[k] for k in ['hidden', 'qh', 'kh', 'dim', 'rotary']]
    if min(h, qh, kh, dim, rotary) <= 0 or qh % kh or rotary % 2 or rotary > dim:
        raise ValueError('invalid reference geometry')
    if rotary//2 < 1:
        raise ValueError('invalid rotary geometry')
    config = SimpleNamespace(hidden_size=h, num_attention_heads=qh, num_key_value_heads=kh,
                             head_dim=dim, attention_bias=False, attention_dropout=0.,
                             rms_norm_eps=j['eps'], _attn_implementation='eager',
                             max_position_embeddings=262144,
                             rope_parameters=dict(rope_type='default', rope_theta=j['theta'],
                                                  partial_rotary_factor=rotary/dim,
                                                  mrope_section=[rotary//2, 0, 0]))
    model = ns['Qwen3_5MoeAttention'](config, 0).cuda().to(torch.bfloat16).eval()
    # Separate FP32 rotary module, moved by device only. Never .to(BF16).
    rope = ns['Qwen3_5MoeTextRotaryEmbedding'](config).cuda().eval()
    mapping = {'q_proj.weight': 'qg', 'k_proj.weight': 'k', 'v_proj.weight': 'v',
               'o_proj.weight': 'o', 'q_norm.weight': 'qnorm', 'k_norm.weight': 'knorm'}
    with torch.no_grad():
        for name, param in model.named_parameters():
            param.copy_(torch.as_tensor(j[mapping[name]], device='cuda', dtype=torch.bfloat16).reshape(param.shape))
    layer = ns['DynamicLayer']()
    cache = ns['Cache'](layers=[layer])
    nodes, events, arrays, cache_records = [], [], {}, []
    scope = ['outside']; call_id = [0]; eager_counts = {}; current_gate = [None]
    max_trace_bytes = 64 << 20
    trace_bytes = [0]
    def cpu(t):
        # Observation transfers must not appear as official mathematical ops.
        with torch._C._DisableTorchDispatch():
            return t.detach().float().cpu().numpy().copy()
    def value64(t):
        return cpu(t).astype('f8') if isinstance(t, torch.Tensor) else t
    def rounded(a, dtype):
        a = np.asarray(a, dtype='f8')
        if dtype == torch.bfloat16:
            return _bf16(a.astype('f4')).astype('f8')
        if dtype == torch.float32:
            return a.astype('f4').astype('f8')
        return a
    def dot_diagnostic(left, right, output):
        # A priori forward-error model, not fitted to any observed discrepancy.
        # This does not prove a library's hidden arithmetic follows that model.
        left, right = np.asarray(left,dtype='f8'), np.asarray(right,dtype='f8')
        n=left.shape[-1];u=2.**-24;gamma=n*u/(1.-n*u)
        center=np.matmul(left,right);bound=gamma*np.matmul(np.abs(left),np.abs(right))
        low=rounded(center-bound,output.dtype);high=rounded(center+bound,output.dtype);actual=value64(output)
        return dict(model='gamma_n*sum(abs(a*b)); no-overflow normal-input FP32 accumulation assumption',
                    n=n,u=u,gamma_n=gamma,max_accumulation_bound=float(bound.max()),
                    mismatches_outside_interval=int(np.count_nonzero((actual<low)|(actual>high))),
                    ambiguous_rounded_cells=int(np.count_nonzero(low!=high)),
                    max_quantized_interval_width=float(np.max(high-low)),
                    library_arithmetic_proof='UNVERIFIED')
    def record(name, out, inputs, expected=None, boundary='', diagnostic=None):
        if not observe:
            return
        count = out.numel()*4
        if trace_bytes[0] + count > max_trace_bytes:
            raise ValueError('official trace exceeds 64MiB budget')
        trace_bytes[0] += count
        a = cpu(out)
        if expected is None:
            raise ValueError('independent diagnostic expected value required: '+name)
        expected = np.asarray(expected, dtype='f8')
        nodes.append(dict(call=call_id[0], node=name, shape=list(out.shape),stride=list(out.stride()),layout=str(out.layout),
                          gpu_bytes=out.numel()*out.element_size(),
                          input_stride=[list(v.stride()) if isinstance(v,torch.Tensor) else [] for v in inputs],
                          input_gpu_bytes=[v.numel()*v.element_size() if isinstance(v,torch.Tensor) else 0 for v in inputs],
                          input_dtype=[str(v.dtype) if isinstance(v, torch.Tensor) else type(v).__name__ for v in inputs],
                          input_shape=[list(v.shape) if isinstance(v, torch.Tensor) else [] for v in inputs],
                          output_dtype=str(out.dtype), bf16_boundary=boundary,
                          metrics=metrics(a, expected, bf16=out.dtype==torch.bfloat16), reference_only_dot_bound=diagnostic))
        arrays[f'{call_id[0]}:{name}'] = a
    class Observer(TorchDispatchMode):
        def __torch_dispatch__(self, func, types, args=(), kwargs=None):
            result = func(*args, **(kwargs or {}))
            ins = [v for v in tree_flatten((args, kwargs))[0] if isinstance(v, torch.Tensor)]
            outs = [v for v in tree_flatten(result)[0] if isinstance(v, torch.Tensor)]
            events.append(dict(call=call_id[0], scope=scope[0], op=str(func),
                               inputs=[dict(dtype=str(t.dtype), shape=list(t.shape), device=str(t.device)) for t in ins],
                               outputs=[dict(dtype=str(t.dtype), shape=list(t.shape), device=str(t.device)) for t in outs]))
            op = str(func)
            if scope[0] == 'eager':
                if op == 'aten.matmul.default':
                    index = eager_counts.get('matmul', 0); eager_counts['matmul'] = index+1
                    name = 'qk_score' if index == 0 else 'av'
                    record(name, result, args[:2], rounded(np.matmul(value64(args[0]), value64(args[1])), result.dtype),
                           'BF16 matmul tensor output; library internal accumulation UNVERIFIED',
                           dot_diagnostic(value64(args[0]),value64(args[1]),result))
                elif op == 'aten.mul.Tensor':
                    record('scale', result, args[:2], rounded(value64(args[0])*value64(args[1]), result.dtype), 'BF16 scalar multiply output')
                elif op == 'aten.add.Tensor':
                    record('causal_mask', result, args[:2], rounded(value64(args[0])+value64(args[1]), result.dtype), 'BF16 additive mask output')
                elif op in ['aten._softmax.default', 'aten.softmax.int']:
                    x = value64(args[0]); ex = np.exp(x-x.max(axis=-1, keepdims=True)); expected = ex/ex.sum(axis=-1, keepdims=True)
                    record('fp32_softmax', result, [args[0]], rounded(expected, result.dtype), 'softmax input/output FP32; internal max/exp/sum topology UNVERIFIED')
                elif op in ['aten.to.dtype', 'aten._to_copy.default'] and outs and outs[0].dtype == torch.bfloat16 and ins and ins[0].dtype == torch.float32:
                    record('bf16_probability', outs[0], [ins[0]], rounded(value64(ins[0]), torch.bfloat16), 'FP32 softmax result -> BF16 probability')
            elif scope[0] == 'attention' and op == 'aten.sigmoid.default':
                x = value64(args[0]); expected = np.exp(-np.logaddexp(0., -x))
                record('sigmoid_gate', result, [args[0]], rounded(expected, result.dtype), 'BF16 sigmoid output')
                current_gate[0] = result
            elif scope[0] == 'attention' and op == 'aten.mul.Tensor' and current_gate[0] is not None:
                record('gated_av', result, args[:2], rounded(value64(args[0])*value64(args[1]), result.dtype), 'BF16 AV times BF16 gate output')
                current_gate[0] = None
            return result
    hook_handles=[]
    for name, module in model.named_modules():
        if not name:
            continue
        def pre(mod, args, _name=name):
            scope.append(scope[0]); scope[0] = _name
        def post(mod, args, out, _name=name):
            if _name in ['q_proj', 'k_proj', 'v_proj', 'o_proj']:
                diagnostic=dot_diagnostic(value64(args[0]),value64(mod.weight).T,out)
                diagnostic['scope']='whole unsplit QG linear tensor' if _name=='q_proj' else 'whole linear output tensor'
                exact = np.matmul(value64(args[0]), value64(mod.weight).T)
                exact = rounded(exact, out.dtype)
                if _name == 'q_proj':
                    a = out.reshape(1, -1, qh, 2*dim)
                    e = exact.reshape(1, -1, qh, 2*dim)
                    record('q_projection', a[..., :dim], [args[0], mod.weight], e[..., :dim], 'BF16 shared Q+gate projection output/split',diagnostic)
                    record('gate_projection', a[..., dim:], [args[0], mod.weight], e[..., dim:], 'BF16 shared Q+gate projection output/split',diagnostic)
                else:
                    tag = {'k_proj': 'k_projection', 'v_proj': 'v_projection', 'o_proj': 'output_projection'}[_name]
                    record(tag, out, [args[0], mod.weight], exact, 'BF16 linear output',diagnostic)
            elif _name in ['q_norm', 'k_norm']:
                x = value64(args[0]); expected = x/np.sqrt(np.mean(x*x, axis=-1, keepdims=True)+mod.eps)
                expected *= 1.+value64(mod.weight)
                record(_name.replace('_norm', '_rmsnorm'), out, [args[0], mod.weight], rounded(expected, out.dtype),
                       'input BF16 -> FP32 normalize/weight -> BF16 once at exit')
            scope[0] = scope.pop()
        if observe:
            hook_handles.append(module.register_forward_pre_hook(pre))
            hook_handles.append(module.register_forward_hook(post))
    original_rope = ns['apply_rotary_pos_emb']
    def observed_rope(q, k, cos, sin, *args, **kwargs):
        before = scope[0]; scope[0] = 'partial_rope'
        try:
            result = original_rope(q, k, cos, sin, *args, **kwargs)
        finally:
            scope[0] = before
        for name, inp, out in [('partial_rope_q', q, result[0]), ('partial_rope_k', k, result[1])]:
            x = value64(inp); c = value64(cos)[:, None]; sn = value64(sin)[:, None]
            rot, tail = x[..., :rotary], x[..., rotary:]
            rotated = np.concatenate([-rot[..., rotary//2:], rot[..., :rotary//2]], axis=-1)
            first = rounded(rot*c, out.dtype); second = rounded(rotated*sn, out.dtype)
            expected = np.concatenate([rounded(first+second, out.dtype), tail], axis=-1)
            record(name, out, [inp, cos, sin], expected, 'BF16 mul, BF16 mul, BF16 add; untouched tail')
        return result
    if observe:
        ns['apply_rotary_pos_emb'] = observed_rope
    original_eager = ns['eager_attention_forward']
    def observed_eager(*args, **kwargs):
        before = scope[0]; scope[0] = 'eager'; eager_counts.clear()
        try:
            return original_eager(*args, **kwargs)
        finally:
            scope[0] = before
    if observe:
        ns['eager_attention_forward'] = observed_eager
    original_update = layer.update
    def observed_update(k, v, *args, **kwargs):
        oldk = cpu(layer.keys) if layer.is_initialized else None
        oldv = cpu(layer.values) if layer.is_initialized else None
        result = original_update(k, v, *args, **kwargs)
        for name, inp, out, old in [('kv_cache_k', k, result[0], oldk), ('kv_cache_v', v, result[1], oldv)]:
            expected = cpu(inp) if old is None else np.concatenate([old, cpu(inp)], axis=-2)
            record(name, out, [inp], expected, 'BF16 post-RoPE K / projection V append; no dtype conversion')
        return result
    if observe:
        layer.update = observed_update
    x = torch.as_tensor(j['x'], device='cuda', dtype=torch.bfloat16).reshape(1, -1, h)
    if partition == 'prefill':
        lengths = [x.shape[1]]
    elif partition == 'decode':
        lengths = [1]*x.shape[1]
    else:
        lengths = j['chunks']
        if sum(lengths) != x.shape[1] or min(lengths) <= 0:
            raise ValueError('invalid chunk partition')
    outputs = []; offset = 0
    with torch.inference_mode(), Observer() if observe else nullcontext():
        for i, length in enumerate(lengths):
            call_id[0] = i; chunk = x[:, offset:offset+length]
            positions = torch.arange(j.get('origin', 0)+offset, j.get('origin', 0)+offset+length, device='cuda').reshape(1, -1)
            scope[0] = 'rope_generation'; cos, sin = rope(chunk, positions)
            # Explicit text causal mask; eager attention does not create it.
            visible = torch.arange(offset+length, device='cuda')[None, :] <= (offset+torch.arange(length, device='cuda'))[:, None]
            mask = torch.where(visible, torch.tensor(0., device='cuda', dtype=torch.bfloat16), torch.finfo(torch.bfloat16).min).reshape(1, 1, length, offset+length)
            scope[0] = 'attention'; y, _ = model(chunk, (cos, sin), mask, past_key_values=cache)
            outputs.append(cpu(y)); offset += length
            cache_records.append(dict(call=i, length=cache.get_seq_length(), dtype_k=str(layer.keys.dtype),
                                      dtype_v=str(layer.values.dtype), k=cpu(layer.keys).tolist(), v=cpu(layer.values).tolist(),
                                      cos=cpu(cos).tolist(), sin=cpu(sin).tolist()))
    torch.cuda.synchronize()
    return dict(output=np.concatenate(outputs, axis=1).tolist(), nodes=nodes, events=events,
                instrumentation=dict(module_hooks=len(hook_handles),wrappers=['rotary','eager','cache'] if observe else []),
                arrays={k: a.tolist() for k, a in arrays.items()}, cache=cache_records,
                provenance=ns['provenance'], inv_freq_dtype=str(rope.inv_freq.dtype),
                inv_freq=cpu(rope.inv_freq).tolist(), trace_bytes=trace_bytes[0], backend='eager',
                library_accumulation='UNVERIFIED', softmax_internal_reduction='UNVERIFIED')
