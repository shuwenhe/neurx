import numpy as np

from tensor.core.tensor import Tensor


class Module:
    def __init__(self):
        self.training = True

    def parameters(self):
        params = []
        seen = set()

        def add_param(param):
            pid = id(param)
            if pid not in seen:
                seen.add(pid)
                params.append(param)

        for value in self.__dict__.values():
            if isinstance(value, Parameter):
                add_param(value)
            elif isinstance(value, Module):
                for p in value.parameters():
                    add_param(p)
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Parameter):
                        add_param(item)
                    elif isinstance(item, Module):
                        for p in item.parameters():
                            add_param(p)
        return params

    def zero_grad(self):
        for p in self.parameters():
            p.zero_grad()

    def train(self):
        """切换到训练模式"""
        self.training = True
        for value in self.__dict__.values():
            if isinstance(value, Module):
                value.train()
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Module):
                        item.train()

    def eval(self):
        """切换到评估模式"""
        self.training = False
        for value in self.__dict__.values():
            if isinstance(value, Module):
                value.eval()
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Module):
                        item.eval()


class Parameter(Tensor):
    def __init__(self, data):
        super().__init__(data, requires_grad=True)


class Embedding(Module):
    def __init__(self, num_embeddings, embedding_dim):
        super().__init__()
        self.weight = Parameter(np.random.randn(num_embeddings, embedding_dim) * 0.02)

    def __call__(self, input_ids):
        input_ids = np.asarray(input_ids, dtype=np.int64)
        out_data = self.weight.data[input_ids]
        out = Tensor(out_data, requires_grad=self.weight.requires_grad, _children=(self.weight,), _op="embedding")

        def _backward():
            if self.weight.requires_grad:
                grad = np.zeros_like(self.weight.data)
                np.add.at(grad, input_ids, out.grad)
                self.weight.grad += grad

        out._backward = _backward
        return out


class Linear(Module):
    def __init__(self, in_features, out_features, bias=True):
        super().__init__()
        scale = (2.0 / max(1, in_features)) ** 0.5
        self.weight = Parameter(np.random.randn(in_features, out_features) * scale)
        self.bias = Parameter(np.zeros((out_features,))) if bias else None

    def __call__(self, x):
        out = x @ self.weight
        if self.bias is not None:
            out = out + self.bias
        return out


class LayerNorm(Module):
    """层归一化：对最后一个维度进行归一化"""
    def __init__(self, normalized_shape, eps=1e-5, bias=True):
        super().__init__()
        if isinstance(normalized_shape, int):
            normalized_shape = (normalized_shape,)
        self.normalized_shape = normalized_shape
        self.eps = eps
        self.weight = Parameter(np.ones(normalized_shape))
        self.bias = Parameter(np.zeros(normalized_shape)) if bias else None

    def __call__(self, x):
        # x.shape = (..., normalized_shape)
        x_data = x.to_numpy() if hasattr(x, "to_numpy") else x.data
        if getattr(x, "device", "cpu") == "cuda":
            try:
                from tensor.cuda import ops as _cuda_ops
                w = self.weight
                b = self.bias if self.bias is not None else Tensor(np.zeros(self.normalized_shape, dtype=np.float32), device="cuda")
                out_data = _cuda_ops.layernorm(
                    x.data,
                    w.data,
                    b.data,
                    self.eps,
                )
                out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x, self.weight, self.bias) if self.bias else (x, self.weight), _op="layernorm", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            norm_dims = len(self.normalized_shape)
            norm_axes = tuple(range(x_data.ndim - norm_dims, x_data.ndim))
            mean = x_data.mean(axis=norm_axes, keepdims=True)
            var = x_data.var(axis=norm_axes, keepdims=True)
            x_normalized = (x_data - mean) / np.sqrt(var + self.eps)
            w = self.weight.to_numpy() if hasattr(self.weight, "to_numpy") else self.weight.data
            b = self.bias.to_numpy() if (self.bias is not None and hasattr(self.bias, "to_numpy")) else (self.bias.data if self.bias else 0)
            out_data = x_normalized * w + (b if self.bias else 0)

            requires_grad = x.requires_grad or self.weight.requires_grad or (self.bias is not None and self.bias.requires_grad)
            children = [c for c in [x, self.weight, self.bias] if c is not None and getattr(c, 'requires_grad', False)]
            out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="layernorm", device=x.device)

        def _backward():
            if not out.grad.any():
                return
            norm_dims = len(self.normalized_shape)
            norm_axes = tuple(range(x_data.ndim - norm_dims, x_data.ndim))
            mean = x_data.mean(axis=norm_axes, keepdims=True)
            var = x_data.var(axis=norm_axes, keepdims=True)
            x_normalized = (x_data - mean) / np.sqrt(var + self.eps)
            reduce_axes = tuple(range(out.grad.ndim - len(self.normalized_shape)))
            if self.weight.requires_grad:
                self.weight.grad += (out.grad * x_normalized).sum(axis=reduce_axes)
            if self.bias and self.bias.requires_grad:
                self.bias.grad += out.grad.sum(axis=reduce_axes)
            if x.requires_grad:
                w = self.weight.to_numpy() if hasattr(self.weight, "to_numpy") else self.weight.data
                dxhat = out.grad * w
                inv_std = 1.0 / np.sqrt(var + self.eps)
                n = float(np.prod(self.normalized_shape))
                sum_dxhat = dxhat.sum(axis=norm_axes, keepdims=True)
                sum_dxhat_xhat = (dxhat * x_normalized).sum(axis=norm_axes, keepdims=True)
                x.grad += (inv_std / n) * (n * dxhat - sum_dxhat - x_normalized * sum_dxhat_xhat)

        out._backward = _backward
        return out


class Dropout(Module):
    """Dropout正则化"""
    def __init__(self, p=0.5):
        super().__init__()
        if p < 0 or p >= 1:
            raise ValueError(f"dropout p must satisfy 0 <= p < 1, got {p}")
        self.p = p

    def __call__(self, x):
        if not self.training or self.p == 0:
            return x
        # 训练时随机置零
        mask = np.random.binomial(1, 1 - self.p, size=x.data.shape) / (1 - self.p)
        out_data = x.data * mask
        out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="dropout")

        def _backward():
            if x.requires_grad:
                x.grad += out.grad * mask

        out._backward = _backward
        return out

    def eval(self):
        """切换到评估模式"""
        self.training = False

    def train(self):
        """切换到训练模式"""
        self.training = True


class Softmax(Module):
    """Softmax（默认对最后一维）"""
    def __init__(self, axis=-1):
        super().__init__()
        self.axis = axis

    def __call__(self, x):
        if getattr(x, "device", "cpu") == "cuda" and self.axis == -1:
            try:
                from tensor.cuda import ops as _cuda_ops
                out_data = _cuda_ops.softmax(x.data)
                out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="softmax", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            x_data = x.to_numpy() if hasattr(x, "to_numpy") else x.data
            x_max = x_data.max(axis=self.axis, keepdims=True)
            exp_x = np.exp(x_data - x_max)
            denom = exp_x.sum(axis=self.axis, keepdims=True)
            out_data = exp_x / np.maximum(denom, 1e-12)
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="softmax", device=x.device)

        def _backward():
            if x.requires_grad:
                # softmax backward: s * (g - sum(g*s))
                out_host = out.to_numpy() if hasattr(out, "to_numpy") else out.data
                sum_gs = (out.grad * out_host).sum(axis=self.axis, keepdims=True)
                x.grad += out_host * (out.grad - sum_gs)

        out._backward = _backward
        return out


class RMSNorm(Module):
    """RMSNorm：对最后一个维度进行均方根归一化"""
    def __init__(self, normalized_shape, eps=1e-6, bias=False):
        super().__init__()
        if isinstance(normalized_shape, int):
            normalized_shape = (normalized_shape,)
        self.normalized_shape = normalized_shape
        self.eps = eps
        self.weight = Parameter(np.ones(normalized_shape))
        self.bias = Parameter(np.zeros(normalized_shape)) if bias else None

    def __call__(self, x):
        x_data = x.to_numpy() if hasattr(x, "to_numpy") else x.data
        norm_dims = len(self.normalized_shape)
        norm_axes = tuple(range(x_data.ndim - norm_dims, x_data.ndim))
        mean_sq = (x_data ** 2).mean(axis=norm_axes, keepdims=True)
        inv_rms = 1.0 / np.sqrt(mean_sq + self.eps)
        x_normalized = x_data * inv_rms
        w = self.weight.to_numpy() if hasattr(self.weight, "to_numpy") else self.weight.data
        b = self.bias.to_numpy() if (self.bias is not None and hasattr(self.bias, "to_numpy")) else (self.bias.data if self.bias else 0)
        out_data = x_normalized * w + (b if self.bias else 0)

        requires_grad = x.requires_grad or self.weight.requires_grad or (self.bias is not None and self.bias.requires_grad)
        children = [c for c in [x, self.weight, self.bias] if c is not None and getattr(c, 'requires_grad', False)]
        out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="rmsnorm", device=x.device)

        def _backward():
            if not out.grad.any():
                return
            reduce_axes = tuple(range(out.grad.ndim - len(self.normalized_shape)))
            if self.weight.requires_grad:
                self.weight.grad += (out.grad * x_normalized).sum(axis=reduce_axes)
            if self.bias and self.bias.requires_grad:
                self.bias.grad += out.grad.sum(axis=reduce_axes)
            if x.requires_grad:
                dxhat = out.grad * self.weight.data
                n = float(np.prod(self.normalized_shape))
                mean_dxhat_x = (dxhat * x.data).sum(axis=norm_axes, keepdims=True) / n
                x.grad += dxhat * inv_rms - x.data * (inv_rms ** 3) * mean_dxhat_x

        out._backward = _backward
        return out


class GELU(Module):
    """GELU激活函数（近似版本）"""
    def __call__(self, x):
        # GELU(x) ≈ 0.5 * x * (1 + tanh(√(2/π) * (x + 0.044715 * x³)))
        # 简化版本: GELU(x) ≈ x * sigmoid(1.702 * x)
        out_data = x.data * (1.0 / (1.0 + np.exp(-1.702 * x.data)))
        out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="gelu")

        def _backward():
            if x.requires_grad:
                # 近似梯度
                sigmoid = 1.0 / (1.0 + np.exp(-1.702 * x.data))
                grad_sigmoid = 1.702 * sigmoid * (1 - sigmoid)
                x.grad += out.grad * (sigmoid + x.data * grad_sigmoid)

        out._backward = _backward
        return out


class Sigmoid(Module):
    """Sigmoid激活函数"""
    def __call__(self, x):
        out_data = 1.0 / (1.0 + np.exp(-x.data))
        out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="sigmoid")

        def _backward():
            if x.requires_grad:
                x.grad += out.grad * out_data * (1.0 - out_data)

        out._backward = _backward
        return out


class SiLU(Module):
    """SiLU / Swish 激活函数"""
    def __init__(self):
        super().__init__()
        self.sigmoid = Sigmoid()

    def __call__(self, x):
        return x * self.sigmoid(x)


class ModuleList(Module):
    """存储Module列表"""
    def __init__(self, modules=None):
        super().__init__()
        self._modules = []
        if modules:
            self._modules.extend(modules)

    def append(self, module):
        self._modules.append(module)

    def __iter__(self):
        return iter(self._modules)

    def __getitem__(self, idx):
        return self._modules[idx]

    def __len__(self):
        return len(self._modules)

    def parameters(self):
        params = []
        seen = set()

        def add_param(param):
            pid = id(param)
            if pid not in seen:
                seen.add(pid)
                params.append(param)

        for module in self._modules:
            if isinstance(module, Module):
                for p in module.parameters():
                    add_param(p)
            elif isinstance(module, Parameter):
                add_param(module)
        return params


class ModuleDict(Module):
    """存储Module字典"""
    def __init__(self, modules=None):
        super().__init__()
        self._modules = {}
        if modules:
            self._modules.update(modules)

    def __setitem__(self, key, module):
        self._modules[key] = module

    def __getitem__(self, key):
        return self._modules[key]

    def __contains__(self, key):
        return key in self._modules

    def keys(self):
        return self._modules.keys()

    def values(self):
        return self._modules.values()

    def items(self):
        return self._modules.items()

    def parameters(self):
        params = []
        seen = set()

        def add_param(param):
            pid = id(param)
            if pid not in seen:
                seen.add(pid)
                params.append(param)

        for module in self._modules.values():
            if isinstance(module, Module):
                for p in module.parameters():
                    add_param(p)
            elif isinstance(module, Parameter):
                add_param(module)
        return params


def _rope_cache(seq_len, dim, theta=10000.0, start_pos=0):
    if dim % 2 != 0:
        raise ValueError(f"RoPE requires even head_dim, got {dim}")
    positions = np.arange(start_pos, start_pos + seq_len, dtype=np.float64)
    freqs = 1.0 / (theta ** (np.arange(0, dim, 2, dtype=np.float64) / dim))
    angles = positions[:, None] * freqs[None, :]
    cos = np.cos(angles)
    sin = np.sin(angles)
    return cos, sin


def _apply_rope(x, cos, sin):
    # x: (B, nh, T, hd)
    x1 = x[..., ::2]
    x2 = x[..., 1::2]
    cos = cos[None, None, :, :]
    sin = sin[None, None, :, :]
    x_rot = np.empty_like(x)
    x_rot[..., ::2] = x1 * cos - x2 * sin
    x_rot[..., 1::2] = x1 * sin + x2 * cos
    return x_rot


def _apply_rope_backward(dx, cos, sin):
    dx1 = dx[..., ::2]
    dx2 = dx[..., 1::2]
    cos = cos[None, None, :, :]
    sin = sin[None, None, :, :]
    dx_rot = np.empty_like(dx)
    dx_rot[..., ::2] = dx1 * cos + dx2 * sin
    dx_rot[..., 1::2] = -dx1 * sin + dx2 * cos
    return dx_rot


class MultiHeadAttention(Module):
    """多头自注意力机制（带因果遮罩）"""
    def __init__(self, n_embd, n_heads, dropout=0.1, max_seq_len=2048, use_rope=False, rope_theta=10000.0):
        super().__init__()
        assert n_embd % n_heads == 0, "n_embd 必须能被 n_heads 整除"
        self.n_heads = n_heads
        self.n_embd = n_embd
        self.head_dim = n_embd // n_heads
        self.use_rope = use_rope
        self.rope_theta = rope_theta
        
        # QKV 投影
        self.qkv = Linear(n_embd, 3 * n_embd, bias=True)
        self.out_proj = Linear(n_embd, n_embd, bias=True)
        self.attn_dropout = Dropout(dropout)
        self.resid_dropout = Dropout(dropout)
        
        # 因果遮罩（下三角布尔矩阵）
        self.causal_mask = np.tril(np.ones((max_seq_len, max_seq_len), dtype=bool))
    
    def __call__(self, x):
        out, _ = self.forward_with_cache(x, kv_cache=None)
        return out

    def forward_with_cache(self, x, kv_cache=None):
        B, T, C = x.data.shape
        past_k = None
        past_v = None
        if kv_cache is not None:
            past_k, past_v = kv_cache
            if past_k is not None and past_v is not None:
                if past_k.shape[0] != B or past_v.shape[0] != B:
                    raise ValueError("kv_cache batch size mismatch")
        total_T = T + (past_k.shape[2] if past_k is not None else 0)
        if total_T > self.causal_mask.shape[0]:
            raise ValueError(
                f"sequence length {total_T} exceeds max_seq_len {self.causal_mask.shape[0]}; "
                "increase max_seq_len when constructing MultiHeadAttention"
            )
        
        # QKV 投影: (B, T, 3*C)
        qkv = self.qkv(x)
        qkv_data = qkv.data.reshape(B, T, 3, self.n_heads, self.head_dim)
        qkv_data = qkv_data.transpose(2, 0, 3, 1, 4)  # (3, B, nh, T, hd)
        q, k, v = qkv_data[0], qkv_data[1], qkv_data[2]  # 每个 (B, nh, T, hd)

        if self.use_rope:
            cos, sin = _rope_cache(T, self.head_dim, theta=self.rope_theta, start_pos=0 if past_k is None else past_k.shape[2])
            q = _apply_rope(q, cos, sin)
            k = _apply_rope(k, cos, sin)
        else:
            cos = sin = None

        if past_k is not None and past_v is not None:
            k = np.concatenate([past_k, k], axis=2)
            v = np.concatenate([past_v, v], axis=2)
        
        # 注意力分数: Q @ K^T / sqrt(d_k)
        att = (q @ k.transpose(0, 1, 3, 2)) / np.sqrt(self.head_dim)  # (B, nh, T, total_T)
        
        # 应用因果遮罩（将上三角设为很小的值）
        mask = self.causal_mask[:total_T, :total_T]
        mask = mask[-T:, :]
        mask_value = np.finfo(att.dtype).min
        att = np.where(mask, att, mask_value)
        
        # Softmax
        att = self._softmax(att, axis=-1)
        
        # Dropout（训练时）
        dropout_mask = None
        if self.attn_dropout.training and self.attn_dropout.p > 0:
            dropout_mask = np.random.binomial(1, 1 - self.attn_dropout.p, size=att.shape) / (1 - self.attn_dropout.p)
            att = att * dropout_mask
        
        # 加权求和: (B, nh, T, T) @ (B, nh, T, hd) -> (B, nh, T, hd)
        y = att @ v
        
        # 重新组合多头: (B, nh, T, hd) -> (B, T, C)
        y = y.transpose(0, 2, 1, 3).reshape(B, T, C)
        y_tensor = Tensor(y, requires_grad=qkv.requires_grad, _children=(qkv,), _op="mha")

        def _backward():
            if not qkv.requires_grad:
                return

            dy = y_tensor.grad.reshape(B, T, self.n_heads, self.head_dim).transpose(0, 2, 1, 3)  # (B, nh, T, hd)

            # y = att @ v
            datt = dy @ v.transpose(0, 1, 3, 2)              # (B, nh, T, T)
            dv = att.transpose(0, 1, 3, 2) @ dy              # (B, nh, T, hd)

            # dropout backward on attention probabilities
            if dropout_mask is not None:
                datt = datt * dropout_mask

            # softmax backward: dscore = s * (g - sum(g*s))
            sum_gs = (datt * att).sum(axis=-1, keepdims=True)
            dscore = att * (datt - sum_gs)

            # masked positions are constants (-1e9), stop gradient
            dscore = np.where(mask[None, None, :, :], dscore, 0.0)

            scale = 1.0 / np.sqrt(self.head_dim)
            dscore = dscore * scale

            # score = q @ k^T
            dq = dscore @ k                                # (B, nh, T, hd)
            dk = dscore.transpose(0, 1, 3, 2) @ q         # (B, nh, T, hd)

            if self.use_rope and cos is not None and sin is not None:
                dq = _apply_rope_backward(dq, cos, sin)
                if past_k is not None and past_v is not None:
                    dk = _apply_rope_backward(dk[:, :, -T:, :], cos, sin)
                else:
                    dk = _apply_rope_backward(dk, cos, sin)

            if past_k is not None and past_v is not None:
                dk = dk[:, :, -T:, :]
                dv = dv[:, :, -T:, :]

            # merge back to qkv layout: (B, T, 3*C)
            dqkv_data = np.stack([dq, dk, dv], axis=0)    # (3, B, nh, T, hd)
            dqkv_data = dqkv_data.transpose(1, 3, 0, 2, 4).reshape(B, T, 3 * C)
            qkv.grad += dqkv_data

        y_tensor._backward = _backward
        
        # 输出投影
        out = self.out_proj(y_tensor)
        out = self.resid_dropout(out)

        new_cache = (k, v)
        return out, new_cache
    
    def _softmax(self, x, axis=-1):
        """数值稳定的 softmax"""
        orig_dtype = x.dtype
        if np.issubdtype(orig_dtype, np.floating) and orig_dtype.itemsize < np.dtype(np.float64).itemsize:
            x = x.astype(np.float64, copy=False)
        x_max = x.max(axis=axis, keepdims=True)
        exp_x = np.exp(x - x_max)
        denom = exp_x.sum(axis=axis, keepdims=True)
        tiny = np.finfo(exp_x.dtype).tiny
        out = exp_x / np.maximum(denom, tiny)
        return out.astype(orig_dtype, copy=False) if out.dtype != orig_dtype else out


class MLP(Module):
    """前馈神经网络（Transformer 的 FFN）"""
    def __init__(self, n_embd, hidden_dim=None, dropout=0.1, bias=True, use_swiglu=False):
        super().__init__()
        if hidden_dim is None:
            hidden_dim = 4 * n_embd
        self.use_swiglu = use_swiglu
        if use_swiglu:
            self.w1 = Linear(n_embd, hidden_dim, bias=bias)
            self.w2 = Linear(n_embd, hidden_dim, bias=bias)
            self.act = SiLU()
            self.w3 = Linear(hidden_dim, n_embd, bias=bias)
        else:
            self.fc1 = Linear(n_embd, hidden_dim, bias=bias)
            self.gelu = GELU()
            self.fc2 = Linear(hidden_dim, n_embd, bias=bias)
        self.dropout = Dropout(dropout)
    
    def __call__(self, x):
        if self.use_swiglu:
            gate = self.w1(x)
            value = self.w2(x)
            x = self.act(gate) * value
            x = self.w3(x)
        else:
            x = self.fc1(x)
            x = self.gelu(x)
            x = self.fc2(x)
        x = self.dropout(x)
        return x


class MoE(Module):
    """Mixture of Experts 前馈网络（简化版 Top-k 路由）"""
    def __init__(
        self,
        n_embd,
        num_experts=4,
        top_k=2,
        hidden_dim=None,
        dropout=0.1,
        bias=True,
        use_swiglu=False,
    ):
        super().__init__()
        if hidden_dim is None:
            hidden_dim = 4 * n_embd
        if num_experts < 1:
            raise ValueError(f"num_experts must be >= 1, got {num_experts}")
        if top_k < 1:
            raise ValueError(f"top_k must be >= 1, got {top_k}")
        self.num_experts = num_experts
        self.top_k = min(top_k, num_experts)
        self.gate = Linear(n_embd, num_experts, bias=bias)
        self.experts = ModuleList(
            [
                MLP(
                    n_embd,
                    hidden_dim=hidden_dim,
                    dropout=dropout,
                    bias=bias,
                    use_swiglu=use_swiglu,
                )
                for _ in range(num_experts)
            ]
        )

    def __call__(self, x):
        gate_logits = self.gate(x)  # (B, T, E)
        logits = gate_logits.data
        logits = logits - logits.max(axis=-1, keepdims=True)
        exp_logits = np.exp(logits)
        probs = exp_logits / (exp_logits.sum(axis=-1, keepdims=True) + 1e-12)

        k = self.top_k
        if k >= self.num_experts:
            mask = np.ones_like(probs)
        else:
            topk_idx = np.argpartition(probs, -k, axis=-1)[..., -k:]
            mask = np.zeros_like(probs)
            np.put_along_axis(mask, topk_idx, 1.0, axis=-1)

        p_sel = probs * mask
        norm = p_sel.sum(axis=-1, keepdims=True)
        norm = np.maximum(norm, 1e-9)
        weights = p_sel / norm

        expert_outs = [expert(x) for expert in self.experts]
        out_data = np.zeros_like(expert_outs[0].data)
        for i, expert_out in enumerate(expert_outs):
            out_data += expert_out.data * weights[..., i:i+1]

        requires_grad = gate_logits.requires_grad or any(e.requires_grad for e in expert_outs)
        children = [gate_logits]
        children.extend([e for e in expert_outs if e.requires_grad])
        out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="moe")

        def _backward():
            if not out.requires_grad:
                return

            grad = out.grad
            for i, expert_out in enumerate(expert_outs):
                if expert_out.requires_grad:
                    expert_out.grad += grad * weights[..., i:i+1]

            if gate_logits.requires_grad:
                expert_data = np.stack([e.data for e in expert_outs], axis=2)  # (B, T, E, C)
                dweights = (grad[:, :, None, :] * expert_data).sum(axis=-1)   # (B, T, E)

                sum_dw_p = (dweights * p_sel).sum(axis=-1, keepdims=True)
                grad_p_sel = (dweights * norm - sum_dw_p) / (norm ** 2)
                grad_p = grad_p_sel * mask

                sum_gp_p = (grad_p * probs).sum(axis=-1, keepdims=True)
                grad_logits = probs * (grad_p - sum_gp_p)
                gate_logits.grad += grad_logits

        out._backward = _backward
        return out


class TransformerBlock(Module):
    """Transformer 块：LayerNorm -> Attention -> Residual -> LayerNorm -> MLP -> Residual"""
    def __init__(
        self,
        n_embd,
        n_heads,
        dropout=0.1,
        use_moe=False,
        moe_num_experts=4,
        moe_top_k=2,
        moe_hidden_dim=None,
        use_rmsnorm=False,
        use_swiglu=False,
        use_rope=False,
        rope_theta=10000.0,
    ):
        super().__init__()
        norm_cls = RMSNorm if use_rmsnorm else LayerNorm
        self.ln1 = norm_cls(n_embd)
        self.attn = MultiHeadAttention(n_embd, n_heads, dropout, use_rope=use_rope, rope_theta=rope_theta)
        self.ln2 = norm_cls(n_embd)
        if use_moe:
            self.mlp = MoE(
                n_embd,
                num_experts=moe_num_experts,
                top_k=moe_top_k,
                hidden_dim=moe_hidden_dim,
                dropout=dropout,
                use_swiglu=use_swiglu,
            )
        else:
            self.mlp = MLP(n_embd, dropout=dropout, use_swiglu=use_swiglu)
    
    def __call__(self, x):
        # Pre-norm architecture
        x = x + self.attn(self.ln1(x))
        x = x + self.mlp(self.ln2(x))
        return x

    def forward_with_cache(self, x, kv_cache=None):
        x_norm = self.ln1(x)
        attn_out, new_cache = self.attn.forward_with_cache(x_norm, kv_cache=kv_cache)
        x = x + attn_out
        x = x + self.mlp(self.ln2(x))
        return x, new_cache
