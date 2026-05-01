import numpy as np
from collections import namedtuple

from neurx.neurx import Tensor


IncompatibleKeys = namedtuple(
    "IncompatibleKeys",
    ["missing_keys", "unexpected_keys", "shape_mismatch", "dtype_mismatch"],
    defaults=[[], [], [], []]  # 默认空列表
)


def _make_incompatible_keys(
    missing_keys=None,
    unexpected_keys=None,
    shape_mismatch=None,
    dtype_mismatch=None
):
    """创建IncompatibleKeys实例，默认值为空列表。"""
    return IncompatibleKeys(
        missing_keys=missing_keys or [],
        unexpected_keys=unexpected_keys or [],
        shape_mismatch=shape_mismatch or [],
        dtype_mismatch=dtype_mismatch or []
    )


class Module:
    def __init__(self):
        self.training = True
        self._buffers = {}

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
            elif isinstance(value, dict):
                for item in value.values():
                    if isinstance(item, Parameter):
                        add_param(item)
                    elif isinstance(item, Module):
                        for p in item.parameters():
                            add_param(p)
        return params

    def zero_grad(self):
        for p in self.parameters():
            p.zero_grad()

    def train(self, mode=True):
        """切换到训练模式，返回self以支持链式调用"""
        self.training = mode
        for value in self.__dict__.values():
            if isinstance(value, Module):
                value.train(mode)
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Module):
                        item.train(mode)
            elif isinstance(value, dict):
                for item in value.values():
                    if isinstance(item, Module):
                        item.train(mode)
        return self

    def eval(self):
        """切换到评估模式，返回self以支持链式调用"""
        self.training = False
        for value in self.__dict__.values():
            if isinstance(value, Module):
                value.eval()
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Module):
                        item.eval()
            elif isinstance(value, dict):
                for item in value.values():
                    if isinstance(item, Module):
                        item.eval()
        return self

    def forward(self, *args, **kwargs):
        raise NotImplementedError("Module.forward is not implemented")

    def __call__(self, *args, **kwargs):
        return self.forward(*args, **kwargs)
    
    def __repr__(self):
        """返回模块结构的字符串表示"""
        class_name = self.__class__.__name__
        lines = [class_name + "("]
        for name, child in self.named_children():
            child_class = child.__class__.__name__
            lines.append(f"  ({name}): {child_class}()")
        lines.append(")")
        return "\n".join(lines)

    def _named_parameters(self, prefix=""):
        named = {}

        def add_param(name, param):
            if name not in named:
                named[name] = param

        for name, value in self.__dict__.items():
            if name == "_buffers":
                continue
            if isinstance(value, Parameter):
                add_param(prefix + name, value)
            elif isinstance(value, Module):
                child = value._named_parameters(prefix + name + ".")
                named.update(child)
            elif isinstance(value, (list, tuple)):
                for idx, item in enumerate(value):
                    if isinstance(item, Parameter):
                        add_param(f"{prefix}{name}.{idx}", item)
                    elif isinstance(item, Module):
                        child = item._named_parameters(f"{prefix}{name}.{idx}.")
                        named.update(child)
            elif isinstance(value, dict):
                for key, item in value.items():
                    if isinstance(item, Parameter):
                        add_param(f"{prefix}{name}.{key}", item)
                    elif isinstance(item, Module):
                        child = item._named_parameters(f"{prefix}{name}.{key}.")
                        named.update(child)
        return named

    def named_parameters(self):
        return list(self._named_parameters().items())

    def register_buffer(self, name, neurx, persistent=True):
        self._buffers[name] = {"value": neurx, "persistent": persistent}
        setattr(self, name, neurx)

    def _named_buffers(self, prefix="", include_non_persistent=True):
        named = {}

        for name, meta in self._buffers.items():
            if not include_non_persistent and not meta["persistent"]:
                continue
            named[prefix + name] = meta["value"]

        for name, value in self.__dict__.items():
            if name in ("_buffers",):
                continue
            if isinstance(value, Module):
                child = value._named_buffers(prefix + name + ".", include_non_persistent=include_non_persistent)
                named.update(child)
            elif isinstance(value, (list, tuple)):
                for idx, item in enumerate(value):
                    if isinstance(item, Module):
                        child = item._named_buffers(f"{prefix}{name}.{idx}.", include_non_persistent=include_non_persistent)
                        named.update(child)
            elif isinstance(value, dict):
                for key, item in value.items():
                    if isinstance(item, Module):
                        child = item._named_buffers(f"{prefix}{name}.{key}.", include_non_persistent=include_non_persistent)
                        named.update(child)
        return named

    def named_buffers(self, include_non_persistent=True):
        return list(self._named_buffers(include_non_persistent=include_non_persistent).items())

    def buffers(self, include_non_persistent=True):
        for _, buf in self.named_buffers(include_non_persistent=include_non_persistent):
            yield buf

    def children(self):
        for value in self.__dict__.values():
            if isinstance(value, Module):
                yield value
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Module):
                        yield item
            elif isinstance(value, dict):
                for item in value.values():
                    if isinstance(item, Module):
                        yield item

    def named_children(self):
        for name, value in self.__dict__.items():
            if isinstance(value, Module):
                yield name, value
            elif isinstance(value, (list, tuple)):
                for idx, item in enumerate(value):
                    if isinstance(item, Module):
                        yield f"{name}.{idx}", item
            elif isinstance(value, dict):
                for key, item in value.items():
                    if isinstance(item, Module):
                        yield f"{name}.{key}", item

    def modules(self):
        seen = set()

        def walk(module):
            mid = id(module)
            if mid in seen:
                return
            seen.add(mid)
            yield module
            for child in module.children():
                yield from walk(child)

        yield from walk(self)

    def named_modules(self):
        seen = set()

        def walk(module, prefix=""):
            mid = id(module)
            if mid in seen:
                return
            seen.add(mid)
            yield prefix, module
            for name, child in module.named_children():
                child_prefix = f"{prefix}.{name}" if prefix else name
                yield from walk(child, child_prefix)

        yield from walk(self)

    def state_dict(self):
        state = {}
        for name, param in self._named_parameters().items():
            if isinstance(param, Tensor):
                state[name] = param.to_numpy().copy()
            else:
                state[name] = np.array(param, copy=True)
        for name, buf in self._named_buffers(include_non_persistent=False).items():
            if isinstance(buf, Tensor):
                state[name] = buf.to_numpy().copy()
            else:
                state[name] = np.array(buf, copy=True)
        return state

    def load_state_dict(self, state, strict=True, auto_convert=False):
        """加载state_dict，支持自动dtype/shape转换。
        
        参数：
            state: 状态字典
            strict: 严格模式（不允许missing/unexpected keys）
            auto_convert: 非strict模式下自动转换shape/dtype不匹配的参数
        """
        named = self._named_parameters()
        buffers = self._named_buffers(include_non_persistent=False)
        missing = []
        shape_mismatch = []
        dtype_mismatch = []
        
        # 检测shape/dtype不匹配
        def _get_shape_dtype(obj):
            if isinstance(obj, Tensor):
                return obj.shape, obj.dtype
            elif isinstance(obj, np.ndarray):
                return obj.shape, obj.dtype
            else:
                arr = np.asarray(obj)
                return arr.shape, arr.dtype
        
        for name, param in named.items():
            if name not in state:
                missing.append(name)
                continue
            loaded_val = state[name]
            current_shape, current_dtype = _get_shape_dtype(param.data)
            loaded_shape, loaded_dtype = _get_shape_dtype(loaded_val)
            
            if current_shape != loaded_shape:
                shape_mismatch.append(
                    {"name": name, "expected": current_shape, "got": loaded_shape}
                )
            if current_dtype != loaded_dtype:
                dtype_mismatch.append(
                    {"name": name, "expected": str(current_dtype), "got": str(loaded_dtype)}
                )
            
            # 自动转换逻辑（如果启用）
            if auto_convert:
                if current_shape != loaded_shape:
                    try:
                        loaded_val = np.reshape(loaded_val, current_shape)
                        shape_mismatch[-1]['auto_converted'] = True
                    except (ValueError, RuntimeError, IndexError):
                        pass
                
                if current_dtype != loaded_dtype:
                    try:
                        loaded_val = np.asarray(loaded_val, dtype=current_dtype)
                        dtype_mismatch[-1]['auto_converted'] = True
                    except (ValueError, TypeError):
                        pass
            
            param.data = loaded_val.copy() if isinstance(loaded_val, np.ndarray) else np.array(loaded_val, copy=True)
        
        for name, buf in buffers.items():
            if name not in state:
                missing.append(name)
                continue
            loaded_val = state[name]
            current_shape, current_dtype = _get_shape_dtype(buf)
            loaded_shape, loaded_dtype = _get_shape_dtype(loaded_val)
            
            if current_shape != loaded_shape:
                shape_mismatch.append(
                    {"name": name, "expected": current_shape, "got": loaded_shape}
                )
            if current_dtype != loaded_dtype:
                dtype_mismatch.append(
                    {"name": name, "expected": str(current_dtype), "got": str(loaded_dtype)}
                )
            
            # 自动转换逻辑（如果启用）
            if auto_convert:
                if current_shape != loaded_shape:
                    try:
                        loaded_val = np.reshape(loaded_val, current_shape)
                        if len(shape_mismatch) > 0:
                            shape_mismatch[-1]['auto_converted'] = True
                    except (ValueError, RuntimeError, IndexError):
                        pass
                
                if current_dtype != loaded_dtype:
                    try:
                        loaded_val = np.asarray(loaded_val, dtype=current_dtype)
                        if len(dtype_mismatch) > 0:
                            dtype_mismatch[-1]['auto_converted'] = True
                    except (ValueError, TypeError):
                        pass
            
            if isinstance(buf, Tensor):
                buf.data = loaded_val.copy() if isinstance(loaded_val, np.ndarray) else np.array(loaded_val, copy=True)
            else:
                loaded = np.array(loaded_val, copy=True)
                try:
                    buf[...] = loaded
                except Exception:
                    buffers[name] = loaded
        
        known = set(named.keys()) | set(buffers.keys())
        unexpected = [name for name in state.keys() if name not in known]
        
        if strict and (missing or unexpected or shape_mismatch or dtype_mismatch):
            error_parts = []
            if missing:
                error_parts.append(f"missing_keys={missing}")
            if unexpected:
                error_parts.append(f"unexpected_keys={unexpected}")
            if shape_mismatch:
                error_parts.append(f"shape_mismatch={shape_mismatch}")
            if dtype_mismatch:
                error_parts.append(f"dtype_mismatch={dtype_mismatch}")
            raise RuntimeError(
                f"Error(s) in loading state_dict for {self.__class__.__name__}: "
                + ", ".join(error_parts)
            )
        
        return _make_incompatible_keys(
            missing_keys=missing,
            unexpected_keys=unexpected,
            shape_mismatch=shape_mismatch,
            dtype_mismatch=dtype_mismatch
        )


class Parameter(Tensor):
    def __init__(self, data):
        super().__init__(data, requires_grad=True)


class Embedding(Module):
    def __init__(self, num_embeddings, embedding_dim):
        super().__init__()
        self.weight = Parameter(np.random.randn(num_embeddings, embedding_dim) * 0.02)

    def __call__(self, input_ids):
        from . import functional as F

        return F.embedding(input_ids, self.weight)


class Linear(Module):
    def __init__(self, in_features, out_features, bias=True):
        super().__init__()
        scale = (2.0 / max(1, in_features)) ** 0.5
        self.weight = Parameter(np.random.randn(in_features, out_features) * scale)
        self.bias = Parameter(np.zeros((out_features,))) if bias else None

    def __call__(self, x):
        from . import functional as F

        return F.linear(x, self.weight, self.bias)


class RNNCell(Module):
    """Elman RNN cell."""

    def __init__(self, input_size, hidden_size, bias=True, nonlinearity="tanh"):
        super().__init__()
        if nonlinearity not in ("tanh", "relu"):
            raise ValueError(f"nonlinearity must be 'tanh' or 'relu', got {nonlinearity}")

        self.input_size = int(input_size)
        self.hidden_size = int(hidden_size)
        self.nonlinearity = nonlinearity
        self.bias = bool(bias)

        scale_ih = (1.0 / max(1, self.input_size)) ** 0.5
        scale_hh = (1.0 / max(1, self.hidden_size)) ** 0.5
        self.weight_ih = Parameter(np.random.randn(self.input_size, self.hidden_size) * scale_ih)
        self.weight_hh = Parameter(np.random.randn(self.hidden_size, self.hidden_size) * scale_hh)
        self.bias_ih = Parameter(np.zeros((self.hidden_size,))) if self.bias else None
        self.bias_hh = Parameter(np.zeros((self.hidden_size,))) if self.bias else None

    def __call__(self, input, hx=None):
        from . import functional as F

        x = input if isinstance(input, Tensor) else Tensor(input)
        squeeze_output = False
        if x.ndim == 1:
            x = x.unsqueeze(0)
            squeeze_output = True
        if x.ndim != 2:
            raise ValueError(f"RNNCell input must be 1D or 2D, got {x.shape}")
        if x.shape[1] != self.input_size:
            raise ValueError(f"RNNCell input_size expected {self.input_size}, got {x.shape[1]}")

        if hx is None:
            h = Tensor(np.zeros((x.shape[0], self.hidden_size), dtype=x.to_numpy().dtype), device=x.device)
        else:
            h = hx if isinstance(hx, Tensor) else Tensor(hx)
            if h.ndim == 1:
                h = h.unsqueeze(0)
            if h.ndim != 2:
                raise ValueError(f"RNNCell hx must be 1D or 2D, got {h.shape}")
            if h.shape != (x.shape[0], self.hidden_size):
                raise ValueError(
                    f"RNNCell hx shape must be ({x.shape[0]}, {self.hidden_size}), got {h.shape}"
                )

        h_next = F.rnn_cell(
            x,
            h,
            self.weight_ih,
            self.weight_hh,
            bias_ih=self.bias_ih,
            bias_hh=self.bias_hh,
            nonlinearity=self.nonlinearity,
        )
        return h_next.squeeze(0) if squeeze_output else h_next


class LSTMCell(Module):
    """LSTM cell."""

    def __init__(self, input_size, hidden_size, bias=True):
        super().__init__()
        self.input_size = int(input_size)
        self.hidden_size = int(hidden_size)
        self.bias = bool(bias)

        gate_size = 4 * self.hidden_size
        scale_ih = (1.0 / max(1, self.input_size)) ** 0.5
        scale_hh = (1.0 / max(1, self.hidden_size)) ** 0.5
        self.weight_ih = Parameter(np.random.randn(self.input_size, gate_size) * scale_ih)
        self.weight_hh = Parameter(np.random.randn(self.hidden_size, gate_size) * scale_hh)
        self.bias_ih = Parameter(np.zeros((gate_size,))) if self.bias else None
        self.bias_hh = Parameter(np.zeros((gate_size,))) if self.bias else None

    def __call__(self, input, hx=None):
        from . import functional as F

        x = input if isinstance(input, Tensor) else Tensor(input)
        squeeze_output = False
        if x.ndim == 1:
            x = x.unsqueeze(0)
            squeeze_output = True
        if x.ndim != 2:
            raise ValueError(f"LSTMCell input must be 1D or 2D, got {x.shape}")
        if x.shape[1] != self.input_size:
            raise ValueError(f"LSTMCell input_size expected {self.input_size}, got {x.shape[1]}")

        if hx is None:
            h = Tensor(np.zeros((x.shape[0], self.hidden_size), dtype=x.to_numpy().dtype), device=x.device)
            c = Tensor(np.zeros((x.shape[0], self.hidden_size), dtype=x.to_numpy().dtype), device=x.device)
        else:
            if not isinstance(hx, (tuple, list)) or len(hx) != 2:
                raise ValueError("LSTMCell hx must be a tuple (h, c)")
            h = hx[0] if isinstance(hx[0], Tensor) else Tensor(hx[0])
            c = hx[1] if isinstance(hx[1], Tensor) else Tensor(hx[1])
            if h.ndim == 1:
                h = h.unsqueeze(0)
            if c.ndim == 1:
                c = c.unsqueeze(0)
            if h.ndim != 2 or c.ndim != 2:
                raise ValueError(f"LSTMCell h/c must be 1D or 2D, got {h.shape} and {c.shape}")
            if h.shape != (x.shape[0], self.hidden_size) or c.shape != (x.shape[0], self.hidden_size):
                raise ValueError(
                    f"LSTMCell h/c shape must be ({x.shape[0]}, {self.hidden_size}), got {h.shape} and {c.shape}"
                )

        h_next, c_next = F.lstm_cell(
            x,
            (h, c),
            self.weight_ih,
            self.weight_hh,
            bias_ih=self.bias_ih,
            bias_hh=self.bias_hh,
        )
        if squeeze_output:
            return h_next.squeeze(0), c_next.squeeze(0)
        return h_next, c_next


class GRUCell(Module):
    """GRU cell."""

    def __init__(self, input_size, hidden_size, bias=True):
        super().__init__()
        self.input_size = int(input_size)
        self.hidden_size = int(hidden_size)
        self.bias = bool(bias)

        gate_size = 3 * self.hidden_size
        scale_ih = (1.0 / max(1, self.input_size)) ** 0.5
        scale_hh = (1.0 / max(1, self.hidden_size)) ** 0.5
        self.weight_ih = Parameter(np.random.randn(self.input_size, gate_size) * scale_ih)
        self.weight_hh = Parameter(np.random.randn(self.hidden_size, gate_size) * scale_hh)
        self.bias_ih = Parameter(np.zeros((gate_size,))) if self.bias else None
        self.bias_hh = Parameter(np.zeros((gate_size,))) if self.bias else None

    def __call__(self, input, hx=None):
        from . import functional as F

        x = input if isinstance(input, Tensor) else Tensor(input)
        squeeze_output = False
        if x.ndim == 1:
            x = x.unsqueeze(0)
            squeeze_output = True
        if x.ndim != 2:
            raise ValueError(f"GRUCell input must be 1D or 2D, got {x.shape}")
        if x.shape[1] != self.input_size:
            raise ValueError(f"GRUCell input_size expected {self.input_size}, got {x.shape[1]}")

        if hx is None:
            h = Tensor(np.zeros((x.shape[0], self.hidden_size), dtype=x.to_numpy().dtype), device=x.device)
        else:
            h = hx if isinstance(hx, Tensor) else Tensor(hx)
            if h.ndim == 1:
                h = h.unsqueeze(0)
            if h.ndim != 2:
                raise ValueError(f"GRUCell hx must be 1D or 2D, got {h.shape}")
            if h.shape != (x.shape[0], self.hidden_size):
                raise ValueError(
                    f"GRUCell hx shape must be ({x.shape[0]}, {self.hidden_size}), got {h.shape}"
                )

        h_next = F.gru_cell(
            x,
            h,
            self.weight_ih,
            self.weight_hh,
            bias_ih=self.bias_ih,
            bias_hh=self.bias_hh,
        )
        return h_next.squeeze(0) if squeeze_output else h_next


def _reverse_sequence(x, batch_first):
    return x[:, ::-1, :] if batch_first else x[::-1, :, :]


def _prepare_recurrent_state(state, expected_layers, hidden_size, batch_size, name):
    if state is None:
        return None

    state = state if isinstance(state, Tensor) else Tensor(state)
    if state.ndim == 2:
        if expected_layers != 1:
            raise ValueError(
                f"{name} with shape (batch, hidden) is only valid when num_layers * num_directions == 1"
            )
        state = state.unsqueeze(0)

    if state.ndim != 3:
        raise ValueError(f"{name} must have 3 dims, got {state.shape}")
    if state.shape[0] != expected_layers:
        raise ValueError(
            f"{name} first dim must be num_layers * num_directions ({expected_layers}), got {state.shape[0]}"
        )
    if state.shape[1] != batch_size:
        raise ValueError(f"{name} batch dim must be {batch_size}, got {state.shape[1]}")
    if state.shape[2] != hidden_size:
        raise ValueError(f"{name} hidden dim must be {hidden_size}, got {state.shape[2]}")
    return state


class RNN(Module):
    """Multi-layer Elman RNN."""

    def __init__(
        self,
        input_size,
        hidden_size,
        num_layers=1,
        nonlinearity="tanh",
        bias=True,
        batch_first=False,
        dropout=0.0,
        bidirectional=False,
    ):
        super().__init__()
        if nonlinearity not in ("tanh", "relu"):
            raise ValueError(f"nonlinearity must be 'tanh' or 'relu', got {nonlinearity}")
        if num_layers <= 0:
            raise ValueError(f"num_layers must be positive, got {num_layers}")
        if dropout < 0 or dropout >= 1:
            raise ValueError(f"dropout must satisfy 0 <= dropout < 1, got {dropout}")

        self.input_size = int(input_size)
        self.hidden_size = int(hidden_size)
        self.num_layers = int(num_layers)
        self.nonlinearity = nonlinearity
        self.bias = bool(bias)
        self.batch_first = bool(batch_first)
        self.dropout = float(dropout)
        self.bidirectional = bool(bidirectional)
        self.num_directions = 2 if self.bidirectional else 1

        for layer in range(self.num_layers):
            layer_input_size = self.input_size if layer == 0 else self.hidden_size * self.num_directions
            for direction in range(self.num_directions):
                suffix = "_reverse" if direction == 1 else ""
                scale_ih = (1.0 / max(1, layer_input_size)) ** 0.5
                scale_hh = (1.0 / max(1, self.hidden_size)) ** 0.5

                w_ih = Parameter(np.random.randn(layer_input_size, self.hidden_size) * scale_ih)
                w_hh = Parameter(np.random.randn(self.hidden_size, self.hidden_size) * scale_hh)
                b_ih = Parameter(np.zeros((self.hidden_size,))) if self.bias else None
                b_hh = Parameter(np.zeros((self.hidden_size,))) if self.bias else None

                setattr(self, f"weight_ih_l{layer}{suffix}", w_ih)
                setattr(self, f"weight_hh_l{layer}{suffix}", w_hh)
                setattr(self, f"bias_ih_l{layer}{suffix}", b_ih)
                setattr(self, f"bias_hh_l{layer}{suffix}", b_hh)

    def __call__(self, x, hx=None):
        from . import functional as F
        from neurx.neurx import cat

        x = x if isinstance(x, Tensor) else Tensor(x)
        if x.ndim != 3:
            raise ValueError(
                f"input must be 3D with shape (seq, batch, feature) or (batch, seq, feature), got {x.shape}"
            )
        if x.shape[2] != self.input_size:
            raise ValueError(f"input feature dim must be {self.input_size}, got {x.shape[2]}")

        batch_size = x.shape[0] if self.batch_first else x.shape[1]
        expected_layers = self.num_layers * self.num_directions
        hx = _prepare_recurrent_state(hx, expected_layers, self.hidden_size, batch_size, "hx")

        output = x
        h_states = []
        for layer in range(self.num_layers):
            layer_outputs = []
            for direction in range(self.num_directions):
                suffix = "_reverse" if direction == 1 else ""
                layer_hx = None
                if hx is not None:
                    layer_hx = hx[layer * self.num_directions + direction]

                layer_input = _reverse_sequence(output, self.batch_first) if direction == 1 else output
                direction_output, h_n = F.rnn(
                    layer_input,
                    getattr(self, f"weight_ih_l{layer}{suffix}"),
                    getattr(self, f"weight_hh_l{layer}{suffix}"),
                    bias_ih=getattr(self, f"bias_ih_l{layer}{suffix}"),
                    bias_hh=getattr(self, f"bias_hh_l{layer}{suffix}"),
                    hx=layer_hx,
                    nonlinearity=self.nonlinearity,
                    batch_first=self.batch_first,
                )
                if direction == 1:
                    direction_output = _reverse_sequence(direction_output, self.batch_first)
                layer_outputs.append(direction_output)
                h_states.append(h_n)

            output = layer_outputs[0] if self.num_directions == 1 else cat(layer_outputs, axis=2)
            if self.dropout > 0 and layer < self.num_layers - 1:
                output = F.dropout(output, p=self.dropout, training=self.training)

        return output, cat(h_states, axis=0)


class LSTM(Module):
    """Multi-layer LSTM."""

    def __init__(
        self,
        input_size,
        hidden_size,
        num_layers=1,
        bias=True,
        batch_first=False,
        dropout=0.0,
        bidirectional=False,
    ):
        super().__init__()
        if num_layers <= 0:
            raise ValueError(f"num_layers must be positive, got {num_layers}")
        if dropout < 0 or dropout >= 1:
            raise ValueError(f"dropout must satisfy 0 <= dropout < 1, got {dropout}")

        self.input_size = int(input_size)
        self.hidden_size = int(hidden_size)
        self.num_layers = int(num_layers)
        self.bias = bool(bias)
        self.batch_first = bool(batch_first)
        self.dropout = float(dropout)
        self.bidirectional = bool(bidirectional)
        self.num_directions = 2 if self.bidirectional else 1

        gate_size = 4 * self.hidden_size
        for layer in range(self.num_layers):
            layer_input_size = self.input_size if layer == 0 else self.hidden_size * self.num_directions
            for direction in range(self.num_directions):
                suffix = "_reverse" if direction == 1 else ""
                scale_ih = (1.0 / max(1, layer_input_size)) ** 0.5
                scale_hh = (1.0 / max(1, self.hidden_size)) ** 0.5

                w_ih = Parameter(np.random.randn(layer_input_size, gate_size) * scale_ih)
                w_hh = Parameter(np.random.randn(self.hidden_size, gate_size) * scale_hh)
                b_ih = Parameter(np.zeros((gate_size,))) if self.bias else None
                b_hh = Parameter(np.zeros((gate_size,))) if self.bias else None

                setattr(self, f"weight_ih_l{layer}{suffix}", w_ih)
                setattr(self, f"weight_hh_l{layer}{suffix}", w_hh)
                setattr(self, f"bias_ih_l{layer}{suffix}", b_ih)
                setattr(self, f"bias_hh_l{layer}{suffix}", b_hh)

    def __call__(self, x, hx=None):
        from . import functional as F
        from neurx.neurx import cat

        x = x if isinstance(x, Tensor) else Tensor(x)
        if x.ndim != 3:
            raise ValueError(
                f"input must be 3D with shape (seq, batch, feature) or (batch, seq, feature), got {x.shape}"
            )
        if x.shape[2] != self.input_size:
            raise ValueError(f"input feature dim must be {self.input_size}, got {x.shape[2]}")

        batch_size = x.shape[0] if self.batch_first else x.shape[1]
        expected_layers = self.num_layers * self.num_directions

        h0 = None
        c0 = None
        if hx is not None:
            if not isinstance(hx, (tuple, list)) or len(hx) != 2:
                raise ValueError("hx for LSTM must be a tuple (h0, c0)")
            h0 = _prepare_recurrent_state(hx[0], expected_layers, self.hidden_size, batch_size, "h0")
            c0 = _prepare_recurrent_state(hx[1], expected_layers, self.hidden_size, batch_size, "c0")

        output = x
        h_states = []
        c_states = []
        for layer in range(self.num_layers):
            layer_outputs = []
            for direction in range(self.num_directions):
                suffix = "_reverse" if direction == 1 else ""
                layer_hx = None
                if h0 is not None and c0 is not None:
                    idx = layer * self.num_directions + direction
                    layer_hx = (h0[idx], c0[idx])

                layer_input = _reverse_sequence(output, self.batch_first) if direction == 1 else output
                direction_output, (h_n, c_n) = F.lstm(
                    layer_input,
                    getattr(self, f"weight_ih_l{layer}{suffix}"),
                    getattr(self, f"weight_hh_l{layer}{suffix}"),
                    bias_ih=getattr(self, f"bias_ih_l{layer}{suffix}"),
                    bias_hh=getattr(self, f"bias_hh_l{layer}{suffix}"),
                    hx=layer_hx,
                    batch_first=self.batch_first,
                )
                if direction == 1:
                    direction_output = _reverse_sequence(direction_output, self.batch_first)
                layer_outputs.append(direction_output)
                h_states.append(h_n)
                c_states.append(c_n)

            output = layer_outputs[0] if self.num_directions == 1 else cat(layer_outputs, axis=2)
            if self.dropout > 0 and layer < self.num_layers - 1:
                output = F.dropout(output, p=self.dropout, training=self.training)

        return output, (cat(h_states, axis=0), cat(c_states, axis=0))


class GRU(Module):
    """Multi-layer GRU."""

    def __init__(
        self,
        input_size,
        hidden_size,
        num_layers=1,
        bias=True,
        batch_first=False,
        dropout=0.0,
        bidirectional=False,
    ):
        super().__init__()
        if num_layers <= 0:
            raise ValueError(f"num_layers must be positive, got {num_layers}")
        if dropout < 0 or dropout >= 1:
            raise ValueError(f"dropout must satisfy 0 <= dropout < 1, got {dropout}")

        self.input_size = int(input_size)
        self.hidden_size = int(hidden_size)
        self.num_layers = int(num_layers)
        self.bias = bool(bias)
        self.batch_first = bool(batch_first)
        self.dropout = float(dropout)
        self.bidirectional = bool(bidirectional)
        self.num_directions = 2 if self.bidirectional else 1

        gate_size = 3 * self.hidden_size
        for layer in range(self.num_layers):
            layer_input_size = self.input_size if layer == 0 else self.hidden_size * self.num_directions
            for direction in range(self.num_directions):
                suffix = "_reverse" if direction == 1 else ""
                scale_ih = (1.0 / max(1, layer_input_size)) ** 0.5
                scale_hh = (1.0 / max(1, self.hidden_size)) ** 0.5

                w_ih = Parameter(np.random.randn(layer_input_size, gate_size) * scale_ih)
                w_hh = Parameter(np.random.randn(self.hidden_size, gate_size) * scale_hh)
                b_ih = Parameter(np.zeros((gate_size,))) if self.bias else None
                b_hh = Parameter(np.zeros((gate_size,))) if self.bias else None

                setattr(self, f"weight_ih_l{layer}{suffix}", w_ih)
                setattr(self, f"weight_hh_l{layer}{suffix}", w_hh)
                setattr(self, f"bias_ih_l{layer}{suffix}", b_ih)
                setattr(self, f"bias_hh_l{layer}{suffix}", b_hh)

    def __call__(self, x, hx=None):
        from . import functional as F
        from neurx.neurx import cat

        x = x if isinstance(x, Tensor) else Tensor(x)
        if x.ndim != 3:
            raise ValueError(
                f"input must be 3D with shape (seq, batch, feature) or (batch, seq, feature), got {x.shape}"
            )
        if x.shape[2] != self.input_size:
            raise ValueError(f"input feature dim must be {self.input_size}, got {x.shape[2]}")

        batch_size = x.shape[0] if self.batch_first else x.shape[1]
        expected_layers = self.num_layers * self.num_directions
        hx = _prepare_recurrent_state(hx, expected_layers, self.hidden_size, batch_size, "hx")

        output = x
        h_states = []
        for layer in range(self.num_layers):
            layer_outputs = []
            for direction in range(self.num_directions):
                suffix = "_reverse" if direction == 1 else ""
                layer_hx = None
                if hx is not None:
                    layer_hx = hx[layer * self.num_directions + direction]

                layer_input = _reverse_sequence(output, self.batch_first) if direction == 1 else output
                direction_output, h_n = F.gru(
                    layer_input,
                    getattr(self, f"weight_ih_l{layer}{suffix}"),
                    getattr(self, f"weight_hh_l{layer}{suffix}"),
                    bias_ih=getattr(self, f"bias_ih_l{layer}{suffix}"),
                    bias_hh=getattr(self, f"bias_hh_l{layer}{suffix}"),
                    hx=layer_hx,
                    batch_first=self.batch_first,
                )
                if direction == 1:
                    direction_output = _reverse_sequence(direction_output, self.batch_first)
                layer_outputs.append(direction_output)
                h_states.append(h_n)

            output = layer_outputs[0] if self.num_directions == 1 else cat(layer_outputs, axis=2)
            if self.dropout > 0 and layer < self.num_layers - 1:
                output = F.dropout(output, p=self.dropout, training=self.training)

        return output, cat(h_states, axis=0)


class Conv1d(Module):
    """1D Convolutional layer."""

    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0, dilation=1, groups=1, bias=True):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, int) else int(kernel_size[0])
        self.stride = stride if isinstance(stride, int) else int(stride[0])
        self.padding = padding if isinstance(padding, int) else int(padding[0])
        self.dilation = dilation if isinstance(dilation, int) else int(dilation[0])
        self.groups = groups

        if in_channels % groups != 0:
            raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
        if out_channels % groups != 0:
            raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")

        fan_in = (in_channels // groups) * self.kernel_size
        # Keep a conservative scale to match existing training stability expectations.
        scale = (2.0 / max(1, fan_in)) ** 0.5 * 0.1
        self.weight = Parameter(np.random.randn(out_channels, in_channels // groups, self.kernel_size) * scale)
        self.bias = Parameter(np.zeros((out_channels,))) if bias else None

    def __call__(self, x):
        from . import functional as F

        return F.conv1d(
            x,
            self.weight,
            bias=self.bias,
            stride=self.stride,
            padding=self.padding,
            dilation=self.dilation,
            groups=self.groups,
        )


class Conv2d(Module):
    """2D Convolutional layer.
    
    Applies a 2D convolution over an input signal composed of several input planes.
    
    Args:
        in_channels: Number of channels in the input image
        out_channels: Number of channels produced by the convolution
        kernel_size: Size of the convolving kernel (int or tuple)
        stride: Stride of the convolution (default: 1)
        padding: Padding added to all four sides of the input (default: 0)
        dilation: Spacing between kernel elements (default: 1)
        groups: Number of groups (default: 1)
        bias: If True, adds a learnable bias (default: True)
    
    Example:
        >>> conv = Conv2d(3, 64, kernel_size=3, stride=1, padding=1)
        >>> x = neurx.randn(1, 3, 32, 32)
        >>> out = conv(x)  # shape: (1, 64, 32, 32)
    """
    
    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0, 
                 dilation=1, groups=1, bias=True):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.stride = stride if isinstance(stride, tuple) else (stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation)
        self.groups = groups
        
        if isinstance(kernel_size, int):
            self.kernel_size = (kernel_size, kernel_size)
        else:
            self.kernel_size = kernel_size
        
        assert in_channels % groups == 0, f"in_channels ({in_channels}) must be divisible by groups ({groups})"
        assert out_channels % groups == 0, f"out_channels ({out_channels}) must be divisible by groups ({groups})"
        
        # Weight shape: (out_channels, in_channels // groups, kernel_h, kernel_w)
        fan_in = (in_channels // groups) * self.kernel_size[0] * self.kernel_size[1]
        scale = (2.0 / fan_in) ** 0.5 * 0.1  # Extra factor to stabilize
        self.weight = Parameter(np.random.randn(out_channels, in_channels // groups, 
                                                 self.kernel_size[0], self.kernel_size[1]) * scale)
        self.bias = Parameter(np.zeros((out_channels,))) if bias else None
    
    def __call__(self, x):
        return self._conv2d_forward(x)
    
    def _conv2d_forward(self, x):
        """Forward pass for Conv2d layer."""
        # x shape: (batch, in_channels, height, width)
        # weight shape: (out_channels, in_channels // groups, kernel_h, kernel_w)
        
        batch_size, in_channels, in_h, in_w = x.shape
        out_channels, _, kernel_h, kernel_w = self.weight.shape
        
        # Calculate output dimensions
        out_h = (in_h + 2 * self.padding[0] - self.dilation[0] * (kernel_h - 1) - 1) // self.stride[0] + 1
        out_w = (in_w + 2 * self.padding[1] - self.dilation[1] * (kernel_w - 1) - 1) // self.stride[1] + 1
        
        x_data = x.data.astype(np.float64)
        w_data = self.weight.data.astype(np.float64)
        
        # Apply padding
        if self.padding[0] > 0 or self.padding[1] > 0:
            x_data = np.pad(x_data, ((0, 0), (0, 0), 
                                     (self.padding[0], self.padding[0]), 
                                     (self.padding[1], self.padding[1])), mode='constant')
        
        # Perform convolution
        out_data = np.zeros((batch_size, out_channels, out_h, out_w), dtype=np.float64)
        
        if self.groups == 1:
            # Standard convolution
            for b in range(batch_size):
                for oc in range(out_channels):
                    for oh in range(out_h):
                        for ow in range(out_w):
                            ih_start = oh * self.stride[0]
                            iw_start = ow * self.stride[1]
                            ih_end = ih_start + self.dilation[0] * (kernel_h - 1) + 1
                            iw_end = iw_start + self.dilation[1] * (kernel_w - 1) + 1
                            
                            x_patch = x_data[b, :, ih_start:ih_end:self.dilation[0], 
                                           iw_start:iw_end:self.dilation[1]]
                            w_patch = w_data[oc]
                            
                            out_data[b, oc, oh, ow] = np.sum(x_patch * w_patch, dtype=np.float64)
        else:
            # Grouped convolution
            in_ch_per_group = in_channels // self.groups
            out_ch_per_group = out_channels // self.groups
            
            for b in range(batch_size):
                for g in range(self.groups):
                    for oc_local in range(out_ch_per_group):
                        oc = g * out_ch_per_group + oc_local
                        for oh in range(out_h):
                            for ow in range(out_w):
                                ih_start = oh * self.stride[0]
                                iw_start = ow * self.stride[1]
                                ih_end = ih_start + self.dilation[0] * (kernel_h - 1) + 1
                                iw_end = iw_start + self.dilation[1] * (kernel_w - 1) + 1
                                
                                ic_start = g * in_ch_per_group
                                ic_end = ic_start + in_ch_per_group
                                
                                x_patch = x_data[b, ic_start:ic_end, 
                                               ih_start:ih_end:self.dilation[0], 
                                               iw_start:iw_end:self.dilation[1]]
                                w_patch = w_data[oc]
                                
                                out_data[b, oc, oh, ow] = np.sum(x_patch * w_patch, dtype=np.float64)
        
        # Add bias
        if self.bias is not None:
            bias_data = self.bias.data.astype(np.float64)
            out_data = out_data + bias_data.reshape(1, -1, 1, 1)
        
        # Convert back to original dtype
        out_data = out_data.astype(np.float32)
        
        # Create output neurx with gradient tracking
        out = Tensor(out_data, requires_grad=x.requires_grad or self.weight.requires_grad, 
                    _children=(x, self.weight) if self.bias is None else (x, self.weight, self.bias),
                    _op="conv2d")
        
        def _backward():
            if not out.grad.any():
                return
            
            grad_data = out.grad.astype(np.float64)
            
            # Gradient w.r.t. weight
            if self.weight.requires_grad:
                w_grad = np.zeros_like(w_data)
                
                x_data_padded = x_data
                if self.padding[0] > 0 or self.padding[1] > 0:
                    x_data_padded = np.pad(x_data, ((0, 0), (0, 0), 
                                                    (self.padding[0], self.padding[0]), 
                                                    (self.padding[1], self.padding[1])), mode='constant')
                
                if self.groups == 1:
                    for b in range(batch_size):
                        for oc in range(out_channels):
                            for oh in range(out_h):
                                for ow in range(out_w):
                                    ih_start = oh * self.stride[0]
                                    iw_start = ow * self.stride[1]
                                    ih_end = ih_start + self.dilation[0] * (kernel_h - 1) + 1
                                    iw_end = iw_start + self.dilation[1] * (kernel_w - 1) + 1
                                    
                                    x_patch = x_data_padded[b, :, 
                                                          ih_start:ih_end:self.dilation[0], 
                                                          iw_start:iw_end:self.dilation[1]]
                                    w_grad[oc] += x_patch * grad_data[b, oc, oh, ow]
                
                self.weight.grad += w_grad.astype(self.weight.grad.dtype)
            
            # Gradient w.r.t. bias
            if self.bias is not None and self.bias.requires_grad:
                self.bias.grad += grad_data.sum(axis=(0, 2, 3)).astype(self.bias.grad.dtype)
            
            # Gradient w.r.t. input
            if x.requires_grad:
                x_grad = np.zeros_like(x_data)
                
                if self.padding[0] > 0 or self.padding[1] > 0:
                    x_grad_padded = np.zeros((batch_size, in_channels, 
                                             in_h + 2 * self.padding[0], 
                                             in_w + 2 * self.padding[1]), dtype=np.float64)
                else:
                    x_grad_padded = x_grad
                
                if self.groups == 1:
                    for b in range(batch_size):
                        for oc in range(out_channels):
                            for oh in range(out_h):
                                for ow in range(out_w):
                                    ih_start = oh * self.stride[0]
                                    iw_start = ow * self.stride[1]
                                    ih_end = ih_start + self.dilation[0] * (kernel_h - 1) + 1
                                    iw_end = iw_start + self.dilation[1] * (kernel_w - 1) + 1
                                    
                                    grad_contrib = w_data[oc] * grad_data[b, oc, oh, ow]
                                    
                                    # Handle dilation
                                    for kh in range(kernel_h):
                                        for kw in range(kernel_w):
                                            ih = ih_start + kh * self.dilation[0]
                                            iw = iw_start + kw * self.dilation[1]
                                            x_grad_padded[b, :, ih, iw] += grad_contrib[:, kh, kw]
                
                if self.padding[0] > 0 or self.padding[1] > 0:
                    x_grad = x_grad_padded[:, :, 
                                         self.padding[0]:self.padding[0]+in_h, 
                                         self.padding[1]:self.padding[1]+in_w]
                    x.grad += x_grad.astype(x.grad.dtype)
                else:
                    x.grad += x_grad_padded.astype(x.grad.dtype)
        
        out._backward = _backward
        return out


class Conv3d(Module):
    """3D Convolutional layer."""

    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0, dilation=1, groups=1, bias=True):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding, padding)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation, dilation)
        self.groups = groups

        if in_channels % groups != 0:
            raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
        if out_channels % groups != 0:
            raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")

        fan_in = (in_channels // groups) * self.kernel_size[0] * self.kernel_size[1] * self.kernel_size[2]
        scale = (2.0 / max(1, fan_in)) ** 0.5
        self.weight = Parameter(
            np.random.randn(
                out_channels,
                in_channels // groups,
                self.kernel_size[0],
                self.kernel_size[1],
                self.kernel_size[2],
            )
            * scale
        )
        self.bias = Parameter(np.zeros((out_channels,))) if bias else None

    def __call__(self, x):
        from . import functional as F

        return F.conv3d(
            x,
            self.weight,
            bias=self.bias,
            stride=self.stride,
            padding=self.padding,
            dilation=self.dilation,
            groups=self.groups,
        )


class ConvTranspose1d(Module):
    """1D Transposed Convolution layer."""

    def __init__(
        self,
        in_channels,
        out_channels,
        kernel_size,
        stride=1,
        padding=0,
        output_padding=0,
        groups=1,
        bias=True,
        dilation=1,
    ):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, int) else int(kernel_size[0])
        self.stride = stride if isinstance(stride, int) else int(stride[0])
        self.padding = padding if isinstance(padding, int) else int(padding[0])
        self.output_padding = output_padding if isinstance(output_padding, int) else int(output_padding[0])
        self.groups = groups
        self.dilation = dilation if isinstance(dilation, int) else int(dilation[0])

        if in_channels % groups != 0:
            raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
        if out_channels % groups != 0:
            raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")

        fan_in = (out_channels // groups) * self.kernel_size
        scale = (2.0 / max(1, fan_in)) ** 0.5
        # PyTorch-compatible layout: (in_channels, out_channels // groups, kernel_size)
        self.weight = Parameter(np.random.randn(in_channels, out_channels // groups, self.kernel_size) * scale)
        self.bias = Parameter(np.zeros((out_channels,))) if bias else None

    def __call__(self, x):
        from . import functional as F

        return F.conv_transpose1d(
            x,
            self.weight,
            bias=self.bias,
            stride=self.stride,
            padding=self.padding,
            output_padding=self.output_padding,
            groups=self.groups,
            dilation=self.dilation,
        )


class ConvTranspose2d(Module):
    """2D Transposed Convolution layer."""

    def __init__(
        self,
        in_channels,
        out_channels,
        kernel_size,
        stride=1,
        padding=0,
        output_padding=0,
        groups=1,
        bias=True,
        dilation=1,
    ):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding)
        self.output_padding = output_padding if isinstance(output_padding, tuple) else (output_padding, output_padding)
        self.groups = groups
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation)

        if in_channels % groups != 0:
            raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
        if out_channels % groups != 0:
            raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")

        fan_in = (out_channels // groups) * self.kernel_size[0] * self.kernel_size[1]
        scale = (2.0 / max(1, fan_in)) ** 0.5
        # PyTorch-compatible layout: (in_channels, out_channels // groups, kH, kW)
        self.weight = Parameter(
            np.random.randn(in_channels, out_channels // groups, self.kernel_size[0], self.kernel_size[1]) * scale
        )
        self.bias = Parameter(np.zeros((out_channels,))) if bias else None

    def __call__(self, x):
        from . import functional as F

        return F.conv_transpose2d(
            x,
            self.weight,
            bias=self.bias,
            stride=self.stride,
            padding=self.padding,
            output_padding=self.output_padding,
            groups=self.groups,
            dilation=self.dilation,
        )


class ConvTranspose3d(Module):
    """3D Transposed Convolution layer."""

    def __init__(
        self,
        in_channels,
        out_channels,
        kernel_size,
        stride=1,
        padding=0,
        output_padding=0,
        groups=1,
        bias=True,
        dilation=1,
    ):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding, padding)
        self.output_padding = (
            output_padding if isinstance(output_padding, tuple) else (output_padding, output_padding, output_padding)
        )
        self.groups = groups
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation, dilation)

        if in_channels % groups != 0:
            raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
        if out_channels % groups != 0:
            raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")

        fan_in = (out_channels // groups) * self.kernel_size[0] * self.kernel_size[1] * self.kernel_size[2]
        scale = (2.0 / max(1, fan_in)) ** 0.5
        # PyTorch-compatible layout: (in_channels, out_channels // groups, kD, kH, kW)
        self.weight = Parameter(
            np.random.randn(
                in_channels,
                out_channels // groups,
                self.kernel_size[0],
                self.kernel_size[1],
                self.kernel_size[2],
            )
            * scale
        )
        self.bias = Parameter(np.zeros((out_channels,))) if bias else None

    def __call__(self, x):
        from . import functional as F

        return F.conv_transpose3d(
            x,
            self.weight,
            bias=self.bias,
            stride=self.stride,
            padding=self.padding,
            output_padding=self.output_padding,
            groups=self.groups,
            dilation=self.dilation,
        )


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
                from neurx.cuda import ops as _cuda_ops
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
            runtime_backend = "python"
            out_data = None
            if getattr(x, "device", "cpu") != "cuda":
                try:
                    from neurx.compile.runtime import try_invoke_ops_function

                    out_data = try_invoke_ops_function("layer_norm", x.data, w, np.asarray(b if self.bias else 0), int(norm_dims), float(self.eps))
                except Exception:
                    out_data = None
            if out_data is None:
                out_data = x_normalized * w + (b if self.bias else 0)
            else:
                runtime_backend = "s"

            requires_grad = x.requires_grad or self.weight.requires_grad or (self.bias is not None and self.bias.requires_grad)
            children = [c for c in [x, self.weight, self.bias] if c is not None and getattr(c, 'requires_grad', False)]
            out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="layernorm", device=x.device)
            out._runtime_backend = runtime_backend

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


class CrossEntropyLoss(Module):
    """Cross Entropy Loss compatible with common PyTorch arguments."""

    def __init__(self, weight=None, ignore_index=-100, reduction="mean", label_smoothing=0.0):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        if label_smoothing < 0.0 or label_smoothing >= 1.0:
            raise ValueError(f"label_smoothing must satisfy 0 <= label_smoothing < 1, got {label_smoothing}")

        if weight is None:
            self.weight = None
        elif isinstance(weight, Tensor):
            self.weight = weight
        else:
            self.weight = Tensor(np.asarray(weight), requires_grad=False)

        self.ignore_index = int(ignore_index)
        self.reduction = reduction
        self.label_smoothing = float(label_smoothing)

    def __call__(self, input, target):
        from . import functional as F

        return F.cross_entropy(
            input,
            target,
            weight=self.weight,
            ignore_index=self.ignore_index,
            reduction=self.reduction,
            label_smoothing=self.label_smoothing,
        )


class FocalLoss(Module):
    """Focal Loss wrapper over ``neurx.nn.functional.focal_loss``."""

    def __init__(self, alpha=0.25, gamma=2.0, weight=None, ignore_index=-100, reduction="mean"):
        super().__init__()
        if not (0 <= alpha <= 1.0):
            raise ValueError(f"alpha must be in [0, 1], got {alpha}")
        if gamma < 0:
            raise ValueError(f"gamma must be non-negative, got {gamma}")
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")

        self.alpha = float(alpha)
        self.gamma = float(gamma)
        self.ignore_index = int(ignore_index)
        self.reduction = reduction

        if weight is None:
            self.weight = None
        elif isinstance(weight, Tensor):
            self.weight = weight
        else:
            self.weight = Tensor(np.asarray(weight), requires_grad=False)

    def __call__(self, input, target):
        from . import functional as F

        return F.focal_loss(
            input,
            target,
            alpha=self.alpha,
            gamma=self.gamma,
            weight=self.weight,
            ignore_index=self.ignore_index,
            reduction=self.reduction,
        )


class NLLLoss(Module):
    """Negative Log-Likelihood Loss."""

    def __init__(self, weight=None, ignore_index=-100, reduction="mean"):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        if weight is None:
            self.weight = None
        elif isinstance(weight, Tensor):
            self.weight = weight
        else:
            self.weight = Tensor(np.asarray(weight), requires_grad=False)
        self.ignore_index = int(ignore_index)
        self.reduction = reduction

    def __call__(self, input, target):
        from . import functional as F

        return F.nll_loss(
            input,
            target,
            weight=self.weight,
            ignore_index=self.ignore_index,
            reduction=self.reduction,
        )


class MSELoss(Module):
    """Mean Squared Error Loss."""

    def __init__(self, reduction="mean"):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        self.reduction = reduction

    def __call__(self, input, target):
        from . import functional as F

        return F.mse_loss(input, target, reduction=self.reduction)


class L1Loss(Module):
    """L1 Loss."""

    def __init__(self, reduction="mean"):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        self.reduction = reduction

    def __call__(self, input, target):
        from . import functional as F

        return F.l1_loss(input, target, reduction=self.reduction)


class SmoothL1Loss(Module):
    """Smooth L1 Loss."""

    def __init__(self, beta=1.0, reduction="mean"):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        self.beta = float(beta)
        self.reduction = reduction

    def __call__(self, input, target):
        from . import functional as F

        return F.smooth_l1_loss(input, target, reduction=self.reduction, beta=self.beta)


class BCELoss(Module):
    """Binary Cross Entropy Loss."""

    def __init__(self, weight=None, reduction="mean"):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        if weight is None:
            self.weight = None
        elif isinstance(weight, Tensor):
            self.weight = weight
        else:
            self.weight = Tensor(np.asarray(weight), requires_grad=False)
        self.reduction = reduction

    def __call__(self, input, target):
        from . import functional as F

        return F.bce_loss(input, target, weight=self.weight, reduction=self.reduction)


class BCEWithLogitsLoss(Module):
    """Binary Cross Entropy with Logits Loss."""

    def __init__(self, weight=None, reduction="mean", pos_weight=None):
        super().__init__()
        if reduction not in ("none", "mean", "sum"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
        if weight is None:
            self.weight = None
        elif isinstance(weight, Tensor):
            self.weight = weight
        else:
            self.weight = Tensor(np.asarray(weight), requires_grad=False)

        if pos_weight is None:
            self.pos_weight = None
        elif isinstance(pos_weight, Tensor):
            self.pos_weight = pos_weight
        else:
            self.pos_weight = Tensor(np.asarray(pos_weight), requires_grad=False)
        self.reduction = reduction

    def __call__(self, input, target):
        from . import functional as F

        return F.bce_with_logits_loss(
            input,
            target,
            weight=self.weight,
            reduction=self.reduction,
            pos_weight=self.pos_weight,
        )


class KLDivLoss(Module):
    """Kullback-Leibler Divergence Loss."""

    def __init__(self, reduction="mean", log_target=False):
        super().__init__()
        if reduction not in ("none", "mean", "sum", "batchmean"):
            raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', 'batchmean', got {reduction}")
        self.reduction = reduction
        self.log_target = bool(log_target)

    def __call__(self, input, target):
        from . import functional as F

        return F.kl_div_loss(input, target, reduction=self.reduction, log_target=self.log_target)


class Softmax(Module):
    """Softmax（默认对最后一维）"""
    def __init__(self, axis=-1):
        super().__init__()
        self.axis = axis

    def __call__(self, x):
        if getattr(x, "device", "cpu") == "cuda" and self.axis == -1:
            try:
                from neurx.cuda import ops as _cuda_ops
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
        runtime_backend = "python"
        out_data = None
        if getattr(x, "device", "cpu") != "cuda":
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("rms_norm", x.data, w, np.asarray(b if self.bias else 0), int(norm_dims), float(self.eps))
            except Exception:
                out_data = None
        if out_data is None:
            out_data = x_normalized * w + (b if self.bias else 0)
        else:
            runtime_backend = "s"

        requires_grad = x.requires_grad or self.weight.requires_grad or (self.bias is not None and self.bias.requires_grad)
        children = [c for c in [x, self.weight, self.bias] if c is not None and getattr(c, 'requires_grad', False)]
        out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="rmsnorm", device=x.device)
        out._runtime_backend = runtime_backend

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
    try:
        from neurx.compile.runtime import try_invoke_ops_function

        out = try_invoke_ops_function("rope_apply", x, cos, sin)
    except Exception:
        out = None
    if out is not None:
        return out
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

        can_use_s_cache_attention = (
            not qkv.requires_grad
            and (not self.attn_dropout.training or self.attn_dropout.p == 0)
            and (not self.resid_dropout.training or self.resid_dropout.p == 0)
            and not self.out_proj.weight.requires_grad
            and (self.out_proj.bias is None or not self.out_proj.bias.requires_grad)
        )
        if can_use_s_cache_attention:
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                empty_key = np.zeros((B, self.n_heads, 0, self.head_dim), dtype=q.dtype)
                runtime_result = try_invoke_ops_function(
                    "kv_cache_attention",
                    q,
                    k,
                    v,
                    past_k if past_k is not None else empty_key,
                    past_v if past_v is not None else empty_key,
                    past_k is not None and past_v is not None,
                )
            except Exception:
                runtime_result = None
            if runtime_result is not None:
                y, _, next_k, next_v = runtime_result
                y = y.transpose(0, 2, 1, 3).reshape(B, T, C)
                y_tensor = Tensor(y, requires_grad=False, device=x.device)
                y_tensor._runtime_backend = "s"
                out = self.out_proj(y_tensor)
                out = self.resid_dropout(out)
                out._runtime_backend = "s"
                return out, (next_k, next_v)

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
        if (
            not self.use_swiglu
            and not getattr(x, "requires_grad", False)
            and not self.fc1.weight.requires_grad
            and (self.fc1.bias is None or not self.fc1.bias.requires_grad)
            and not self.fc2.weight.requires_grad
            and (self.fc2.bias is None or not self.fc2.bias.requires_grad)
            and (not self.dropout.training or self.dropout.p == 0)
        ):
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                fc1_bias = self.fc1.bias.data if self.fc1.bias is not None else np.zeros((self.fc1.weight.shape[-1],), dtype=x.data.dtype)
                fc2_bias = self.fc2.bias.data if self.fc2.bias is not None else np.zeros((self.fc2.weight.shape[-1],), dtype=x.data.dtype)
                out_data = try_invoke_ops_function("mlp_block", x.data, self.fc1.weight.data, fc1_bias, self.fc2.weight.data, fc2_bias)
            except Exception:
                out_data = None
            if out_data is not None:
                out = Tensor(out_data, requires_grad=False, device=x.device)
                out._runtime_backend = "s"
                return out
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
        self.use_moe = use_moe
        self.use_rmsnorm = use_rmsnorm
        self.use_swiglu = use_swiglu
        self.use_rope = use_rope
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
        fused = self._try_s_fused_forward(x)
        if fused is not None:
            return fused
        x = x + self.attn(self.ln1(x))
        x = x + self.mlp(self.ln2(x))
        return x

    def _try_s_fused_forward(self, x):
        if (
            self.use_moe
            or self.use_rmsnorm
            or self.use_swiglu
            or self.use_rope
            or getattr(x, "requires_grad", False)
            or self.ln1.weight.requires_grad
            or (self.ln1.bias is not None and self.ln1.bias.requires_grad)
            or self.attn.qkv.weight.requires_grad
            or (self.attn.qkv.bias is not None and self.attn.qkv.bias.requires_grad)
            or self.attn.out_proj.weight.requires_grad
            or (self.attn.out_proj.bias is not None and self.attn.out_proj.bias.requires_grad)
            or self.ln2.weight.requires_grad
            or (self.ln2.bias is not None and self.ln2.bias.requires_grad)
            or not isinstance(self.mlp, MLP)
            or self.mlp.fc1.weight.requires_grad
            or (self.mlp.fc1.bias is not None and self.mlp.fc1.bias.requires_grad)
            or self.mlp.fc2.weight.requires_grad
            or (self.mlp.fc2.bias is not None and self.mlp.fc2.bias.requires_grad)
            or (self.attn.attn_dropout.training and self.attn.attn_dropout.p > 0)
            or (self.attn.resid_dropout.training and self.attn.resid_dropout.p > 0)
            or (self.mlp.dropout.training and self.mlp.dropout.p > 0)
        ):
            return None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function(
                "transformer_block_forward",
                x.data,
                self.ln1.weight.data,
                self.ln1.bias.data if self.ln1.bias is not None else np.zeros_like(self.ln1.weight.data),
                self.attn.qkv.weight.data,
                self.attn.qkv.bias.data if self.attn.qkv.bias is not None else np.zeros((3 * self.attn.n_embd,), dtype=x.data.dtype),
                self.attn.out_proj.weight.data,
                self.attn.out_proj.bias.data if self.attn.out_proj.bias is not None else np.zeros((self.attn.n_embd,), dtype=x.data.dtype),
                self.ln2.weight.data,
                self.ln2.bias.data if self.ln2.bias is not None else np.zeros_like(self.ln2.weight.data),
                self.mlp.fc1.weight.data,
                self.mlp.fc1.bias.data if self.mlp.fc1.bias is not None else np.zeros((self.mlp.fc1.weight.shape[-1],), dtype=x.data.dtype),
                self.mlp.fc2.weight.data,
                self.mlp.fc2.bias.data if self.mlp.fc2.bias is not None else np.zeros((self.mlp.fc2.weight.shape[-1],), dtype=x.data.dtype),
                float(self.ln1.eps),
                int(self.attn.n_heads),
            )
        except Exception:
            out_data = None
        if out_data is None:
            return None
        out = Tensor(out_data, requires_grad=False, device=x.device)
        out._runtime_backend = "s"
        return out

    def forward_with_cache(self, x, kv_cache=None):
        x_norm = self.ln1(x)
        attn_out, new_cache = self.attn.forward_with_cache(x_norm, kv_cache=kv_cache)
        x = x + attn_out
        x = x + self.mlp(self.ln2(x))
        return x, new_cache

# ================ Batch Normalization Layers ================

class BatchNorm1d(Module):
    """1D Batch Normalization (对样本和特征维度进行归一化)
    
    应用于形状为 (batch, features) 或 (batch, features, length) 的张量
    """
    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, track_running_stats=True):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats
        
        if affine:
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None
        
        if track_running_stats:
            self.register_buffer('running_mean', np.zeros(num_features))
            self.register_buffer('running_var', np.ones(num_features))
            self.register_buffer('num_batches_tracked', np.array(0))
        else:
            self.running_mean = None
            self.running_var = None
            self.num_batches_tracked = None

    def __call__(self, x):
        from . import functional as F

        x_data = x.data if hasattr(x, "data") else np.asarray(x)
        if x_data.ndim not in (2, 3):
            raise ValueError(f"BatchNorm1d expects 2D or 3D input, got {x_data.ndim}D")

        # When track_running_stats=False, always use batch statistics
        bn_training = self.training if self.track_running_stats else True
        if self.training and self.track_running_stats and self.num_batches_tracked is not None:
            self.num_batches_tracked += 1

        return F.batch_norm(
            x,
            running_mean=self.running_mean if self.track_running_stats else None,
            running_var=self.running_var if self.track_running_stats else None,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            training=bn_training,
            momentum=self.momentum,
            eps=self.eps,
        )


class BatchNorm2d(Module):
    """2D Batch Normalization (对通道维度进行归一化)
    
    应用于形状为 (batch, channels, height, width) 的张量
    """
    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, track_running_stats=True):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats
        
        if affine:
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None
        
        if track_running_stats:
            self.register_buffer('running_mean', np.zeros(num_features))
            self.register_buffer('running_var', np.ones(num_features))
            self.register_buffer('num_batches_tracked', np.array(0))
        else:
            self.running_mean = None
            self.running_var = None
            self.num_batches_tracked = None

    def __call__(self, x):
        from . import functional as F

        x_data = x.data if hasattr(x, "data") else np.asarray(x)
        if x_data.ndim != 4:
            raise ValueError(f"BatchNorm2d expects 4D input, got {x_data.ndim}D")

        # When track_running_stats=False, always use batch statistics
        bn_training = self.training if self.track_running_stats else True
        if self.training and self.track_running_stats and self.num_batches_tracked is not None:
            self.num_batches_tracked += 1

        return F.batch_norm(
            x,
            running_mean=self.running_mean if self.track_running_stats else None,
            running_var=self.running_var if self.track_running_stats else None,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            training=bn_training,
            momentum=self.momentum,
            eps=self.eps,
        )


class BatchNorm3d(Module):
    """3D Batch Normalization (N, C, D, H, W)."""

    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, track_running_stats=True):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats

        if affine:
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None

        if track_running_stats:
            self.register_buffer("running_mean", np.zeros(num_features))
            self.register_buffer("running_var", np.ones(num_features))
            self.register_buffer("num_batches_tracked", np.array(0))
        else:
            self.running_mean = None
            self.running_var = None
            self.num_batches_tracked = None

    def __call__(self, x):
        from . import functional as F

        x_data = x.data if hasattr(x, "data") else np.asarray(x)
        if x_data.ndim != 5:
            raise ValueError(f"BatchNorm3d expects 5D input, got {x_data.ndim}D")

        bn_training = self.training or not self.track_running_stats
        if self.training and self.track_running_stats and self.num_batches_tracked is not None:
            self.num_batches_tracked += 1

        return F.batch_norm(
            x,
            running_mean=self.running_mean if self.track_running_stats else None,
            running_var=self.running_var if self.track_running_stats else None,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            training=bn_training,
            momentum=self.momentum,
            eps=self.eps,
        )


class GroupNorm(Module):
    """Group Normalization."""

    def __init__(self, num_groups, num_channels, eps=1e-5, affine=True):
        super().__init__()
        if num_groups <= 0:
            raise ValueError(f"num_groups must be positive, got {num_groups}")
        if num_channels % num_groups != 0:
            raise ValueError(f"num_channels ({num_channels}) must be divisible by num_groups ({num_groups})")
        self.num_groups = num_groups
        self.num_channels = num_channels
        self.eps = eps
        self.affine = affine

        if affine:
            self.weight = Parameter(np.ones(num_channels))
            self.bias = Parameter(np.zeros(num_channels))
        else:
            self.weight = None
            self.bias = None

    def __call__(self, x):
        from . import functional as F

        return F.group_norm(
            x,
            num_groups=self.num_groups,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            eps=self.eps,
        )


class InstanceNorm1d(Module):
    """Instance Normalization for 1D inputs."""

    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=False, track_running_stats=False):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats

        if affine:
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None

        if track_running_stats:
            self.register_buffer("running_mean", np.zeros(num_features))
            self.register_buffer("running_var", np.ones(num_features))
            self.register_buffer("num_batches_tracked", np.array(0))
        else:
            self.running_mean = None
            self.running_var = None
            self.num_batches_tracked = None

    def __call__(self, x):
        from . import functional as F

        x_data = x.data if hasattr(x, "data") else np.asarray(x)
        if x_data.ndim != 3:
            raise ValueError(f"InstanceNorm1d expects 3D input, got {x_data.ndim}D")

        use_input_stats = self.training or not self.track_running_stats
        if self.training and self.track_running_stats and self.num_batches_tracked is not None:
            self.num_batches_tracked += 1

        return F.instance_norm(
            x,
            running_mean=self.running_mean if self.track_running_stats else None,
            running_var=self.running_var if self.track_running_stats else None,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            use_input_stats=use_input_stats,
            momentum=self.momentum,
            eps=self.eps,
        )


class InstanceNorm2d(Module):
    """Instance Normalization for 2D inputs."""

    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=False, track_running_stats=False):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats

        if affine:
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None

        if track_running_stats:
            self.register_buffer("running_mean", np.zeros(num_features))
            self.register_buffer("running_var", np.ones(num_features))
            self.register_buffer("num_batches_tracked", np.array(0))
        else:
            self.running_mean = None
            self.running_var = None
            self.num_batches_tracked = None

    def __call__(self, x):
        from . import functional as F

        x_data = x.data if hasattr(x, "data") else np.asarray(x)
        if x_data.ndim != 4:
            raise ValueError(f"InstanceNorm2d expects 4D input, got {x_data.ndim}D")

        use_input_stats = self.training or not self.track_running_stats
        if self.training and self.track_running_stats and self.num_batches_tracked is not None:
            self.num_batches_tracked += 1

        return F.instance_norm(
            x,
            running_mean=self.running_mean if self.track_running_stats else None,
            running_var=self.running_var if self.track_running_stats else None,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            use_input_stats=use_input_stats,
            momentum=self.momentum,
            eps=self.eps,
        )


class InstanceNorm3d(Module):
    """Instance Normalization for 3D inputs."""

    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=False, track_running_stats=False):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats

        if affine:
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None

        if track_running_stats:
            self.register_buffer("running_mean", np.zeros(num_features))
            self.register_buffer("running_var", np.ones(num_features))
            self.register_buffer("num_batches_tracked", np.array(0))
        else:
            self.running_mean = None
            self.running_var = None
            self.num_batches_tracked = None

    def __call__(self, x):
        from . import functional as F

        x_data = x.data if hasattr(x, "data") else np.asarray(x)
        if x_data.ndim != 5:
            raise ValueError(f"InstanceNorm3d expects 5D input, got {x_data.ndim}D")

        use_input_stats = self.training or not self.track_running_stats
        if self.training and self.track_running_stats and self.num_batches_tracked is not None:
            self.num_batches_tracked += 1

        return F.instance_norm(
            x,
            running_mean=self.running_mean if self.track_running_stats else None,
            running_var=self.running_var if self.track_running_stats else None,
            weight=self.weight if self.affine else None,
            bias=self.bias if self.affine else None,
            use_input_stats=use_input_stats,
            momentum=self.momentum,
            eps=self.eps,
        )


# ================ Pooling Layers ================

class MaxPool1d(Module):
    """1D Maximum Pooling."""

    def __init__(self, kernel_size, stride=None, padding=0, dilation=1, ceil_mode=False, return_indices=False):
        super().__init__()
        self.kernel_size = kernel_size
        self.stride = stride
        self.padding = padding
        self.dilation = dilation
        self.ceil_mode = ceil_mode
        self.return_indices = return_indices

    def __call__(self, x):
        from . import functional as F

        return F.max_pool1d(
            x,
            kernel_size=self.kernel_size,
            stride=self.stride,
            padding=self.padding,
            dilation=self.dilation,
            ceil_mode=self.ceil_mode,
            return_indices=self.return_indices,
        )


class AvgPool1d(Module):
    """1D Average Pooling."""

    def __init__(self, kernel_size, stride=None, padding=0, ceil_mode=False, count_include_pad=True, divisor_override=None):
        super().__init__()
        self.kernel_size = kernel_size
        self.stride = stride
        self.padding = padding
        self.ceil_mode = ceil_mode
        self.count_include_pad = count_include_pad
        self.divisor_override = divisor_override

    def __call__(self, x):
        from . import functional as F

        return F.avg_pool1d(
            x,
            kernel_size=self.kernel_size,
            stride=self.stride,
            padding=self.padding,
            ceil_mode=self.ceil_mode,
            count_include_pad=self.count_include_pad,
            divisor_override=self.divisor_override,
        )


class MaxPool2d(Module):
    """2D Maximum Pooling."""

    def __init__(self, kernel_size, stride=None, padding=0, dilation=1, ceil_mode=False, return_indices=False):
        super().__init__()
        self.kernel_size = kernel_size
        self.stride = stride
        self.padding = padding
        self.dilation = dilation
        self.ceil_mode = ceil_mode
        self.return_indices = return_indices

    def __call__(self, x):
        from . import functional as F

        return F.max_pool2d(
            x,
            kernel_size=self.kernel_size,
            stride=self.stride,
            padding=self.padding,
            dilation=self.dilation,
            ceil_mode=self.ceil_mode,
            return_indices=self.return_indices,
        )


class AvgPool2d(Module):
    """2D Average Pooling."""

    def __init__(self, kernel_size, stride=None, padding=0, ceil_mode=False, count_include_pad=True, divisor_override=None):
        super().__init__()
        self.kernel_size = kernel_size
        self.stride = stride
        self.padding = padding
        self.ceil_mode = ceil_mode
        self.count_include_pad = count_include_pad
        self.divisor_override = divisor_override

    def __call__(self, x):
        from . import functional as F

        return F.avg_pool2d(
            x,
            kernel_size=self.kernel_size,
            stride=self.stride,
            padding=self.padding,
            ceil_mode=self.ceil_mode,
            count_include_pad=self.count_include_pad,
            divisor_override=self.divisor_override,
        )


class AdaptiveAvgPool1d(Module):
    """1D Adaptive Average Pooling."""

    def __init__(self, output_size):
        super().__init__()
        self.output_size = output_size

    def __call__(self, x):
        from . import functional as F

        return F.adaptive_avg_pool1d(x, self.output_size)


class AdaptiveAvgPool2d(Module):
    """2D Adaptive Average Pooling."""

    def __init__(self, output_size):
        super().__init__()
        self.output_size = output_size

    def __call__(self, x):
        from . import functional as F

        return F.adaptive_avg_pool2d(x, self.output_size)


class AdaptiveAvgPool3d(Module):
    """3D Adaptive Average Pooling."""

    def __init__(self, output_size):
        super().__init__()
        self.output_size = output_size

    def __call__(self, x):
        from . import functional as F

        return F.adaptive_avg_pool3d(x, self.output_size)


class AdaptiveMaxPool1d(Module):
    """1D Adaptive Max Pooling."""

    def __init__(self, output_size, return_indices=False):
        super().__init__()
        self.output_size = output_size
        self.return_indices = return_indices

    def __call__(self, x):
        from . import functional as F

        return F.adaptive_max_pool1d(x, self.output_size, return_indices=self.return_indices)


class AdaptiveMaxPool2d(Module):
    """2D Adaptive Max Pooling."""

    def __init__(self, output_size, return_indices=False):
        super().__init__()
        self.output_size = output_size
        self.return_indices = return_indices

    def __call__(self, x):
        from . import functional as F

        return F.adaptive_max_pool2d(x, self.output_size, return_indices=self.return_indices)


class AdaptiveMaxPool3d(Module):
    """3D Adaptive Max Pooling."""

    def __init__(self, output_size, return_indices=False):
        super().__init__()
        self.output_size = output_size
        self.return_indices = return_indices

    def __call__(self, x):
        from . import functional as F

        return F.adaptive_max_pool3d(x, self.output_size, return_indices=self.return_indices)


# ================ Container Modules ================

class Sequential(Module):
    """顺序容器 - 按顺序应用模块列表"""
    def __init__(self, *args):
        super().__init__()
        if len(args) == 1 and isinstance(args[0], dict):
            # 从有序字典初始化
            self._modules_ordered = list(args[0].items())
        else:
            # 从Module列表初始化
            self._modules_ordered = [(str(i), module) for i, module in enumerate(args)]
        
        # 同时存储为属性以便参数收集
        for name, module in self._modules_ordered:
            setattr(self, name, module)

    def __call__(self, x):
        for name, module in self._modules_ordered:
            x = module(x)
        return x

    def __getitem__(self, index):
        if isinstance(index, slice):
            return Sequential(*[module for _, module in self._modules_ordered[index]])
        else:
            return self._modules_ordered[index][1]

    def __len__(self):
        return len(self._modules_ordered)


# ================ Weight Initialization ================

def _calculate_fan_in_and_fan_out(tensor_shape):
    """计算扇入和扇出用于Kaiming和Xavier初始化"""
    if len(tensor_shape) < 2:
        raise ValueError("Tensor must have at least 2 dimensions")
    
    num_input = tensor_shape[1]
    num_output = tensor_shape[0]
    
    if len(tensor_shape) > 2:
        # Convolutional or higher dimensional
        receptive_field_size = np.prod(tensor_shape[2:])
        fan_in = num_input * receptive_field_size
        fan_out = num_output * receptive_field_size
    else:
        fan_in = num_input
        fan_out = num_output
    
    return fan_in, fan_out


def kaiming_uniform_(neurx, a=0, mode='fan_in', nonlinearity='leaky_relu'):
    """Kaiming均匀初始化（原地）"""
    if not hasattr(neurx, 'data'):
        tensor_data = neurx
        is_parameter = False
    else:
        tensor_data = neurx.data
        is_parameter = True
    
    fan_in, fan_out = _calculate_fan_in_and_fan_out(tensor_data.shape)
    
    if mode == 'fan_in':
        num = fan_in
    elif mode == 'fan_out':
        num = fan_out
    elif mode == 'fan_avg':
        num = (fan_in + fan_out) / 2
    else:
        raise ValueError(f"Mode {mode} not supported")
    
    if nonlinearity == 'leaky_relu':
        gain = np.sqrt(2.0 / (1 + a ** 2))
    else:
        gain = 1.0
    
    std = gain / np.sqrt(num)
    bound = np.sqrt(3.0) * std
    
    init_vals = np.random.uniform(-bound, bound, tensor_data.shape)
    
    if is_parameter:
        neurx.data = init_vals.astype(neurx.data.dtype)
    else:
        neurx[:] = init_vals
    
    return neurx


def kaiming_normal_(neurx, a=0, mode='fan_in', nonlinearity='leaky_relu'):
    """Kaiming正态初始化（原地）"""
    if not hasattr(neurx, 'data'):
        tensor_data = neurx
        is_parameter = False
    else:
        tensor_data = neurx.data
        is_parameter = True
    
    fan_in, fan_out = _calculate_fan_in_and_fan_out(tensor_data.shape)
    
    if mode == 'fan_in':
        num = fan_in
    elif mode == 'fan_out':
        num = fan_out
    elif mode == 'fan_avg':
        num = (fan_in + fan_out) / 2
    else:
        raise ValueError(f"Mode {mode} not supported")
    
    if nonlinearity == 'leaky_relu':
        gain = np.sqrt(2.0 / (1 + a ** 2))
    else:
        gain = 1.0
    
    std = gain / np.sqrt(num)
    init_vals = np.random.normal(0, std, tensor_data.shape)
    
    if is_parameter:
        neurx.data = init_vals.astype(neurx.data.dtype)
    else:
        neurx[:] = init_vals
    
    return neurx


def xavier_uniform_(neurx, gain=1.0):
    """Xavier均匀初始化（原地）"""
    if not hasattr(neurx, 'data'):
        tensor_data = neurx
        is_parameter = False
    else:
        tensor_data = neurx.data
        is_parameter = True
    
    fan_in, fan_out = _calculate_fan_in_and_fan_out(tensor_data.shape)
    std = gain * np.sqrt(2.0 / (fan_in + fan_out))
    bound = np.sqrt(3.0) * std
    
    init_vals = np.random.uniform(-bound, bound, tensor_data.shape)
    
    if is_parameter:
        neurx.data = init_vals.astype(neurx.data.dtype)
    else:
        neurx[:] = init_vals
    
    return neurx


def xavier_normal_(neurx, gain=1.0):
    """Xavier正态初始化（原地）"""
    if not hasattr(neurx, 'data'):
        tensor_data = neurx
        is_parameter = False
    else:
        tensor_data = neurx.data
        is_parameter = True
    
    fan_in, fan_out = _calculate_fan_in_and_fan_out(tensor_data.shape)
    std = gain * np.sqrt(2.0 / (fan_in + fan_out))
    
    init_vals = np.random.normal(0, std, tensor_data.shape)
    
    if is_parameter:
        neurx.data = init_vals.astype(neurx.data.dtype)
    else:
        neurx[:] = init_vals
    
    return neurx


# ================ Module Utilities ================

def _add_module_methods():
    """为Module基类添加额外的方法"""

    def requires_grad_(self, requires_grad=True):
        """设置所有参数的requires_grad属性（原地）"""
        for param in self.parameters():
            param.requires_grad = requires_grad
        return self

    def _convert_tensor_like(obj, *, device=None, dtype=None):
        if isinstance(obj, Parameter):
            if dtype is not None:
                target_dtype = np.dtype(dtype)
                if obj.requires_grad and not np.issubdtype(target_dtype, np.floating):
                    raise ValueError("Cannot cast Parameter requiring grad to non-floating dtype")
                obj.data = np.asarray(obj.data).astype(target_dtype, copy=False)
                if obj.grad is not None:
                    obj.grad = np.asarray(obj.grad).astype(target_dtype, copy=False)
            if device is not None:
                moved = Tensor(np.asarray(obj.data), requires_grad=obj.requires_grad, device=device)
                obj.data = moved.data
                obj.device = moved.device
            return obj

        if isinstance(obj, Tensor):
            return obj.to(device=device, dtype=dtype)

        if isinstance(obj, np.ndarray):
            if dtype is not None:
                return obj.astype(dtype, copy=False)
            return obj

        return obj

    def _convert_container(value, *, device=None, dtype=None):
        if isinstance(value, (Module, Parameter, Tensor, np.ndarray)):
            return _convert_tensor_like(value, device=device, dtype=dtype)

        if isinstance(value, list):
            for i, item in enumerate(value):
                value[i] = _convert_container(item, device=device, dtype=dtype)
            return value

        if isinstance(value, tuple):
            return tuple(_convert_container(item, device=device, dtype=dtype) for item in value)

        if isinstance(value, dict):
            for k, item in list(value.items()):
                value[k] = _convert_container(item, device=device, dtype=dtype)
            return value

        return value

    def to(self, device=None, dtype=None, non_blocking=False, copy=True):
        """递归转换模块参数/缓冲区的device与dtype（原地）。
        
        参数：
            device: 目标设备（'cpu'或'cuda'）
            dtype: 目标dtype（numpy dtype或字符串）
            non_blocking: PyTorch兼容参数，在NumPy中无效（忽略）
            copy: 是否创建副本（默认True）。当False时，对numpy数组进行原地转换。
        """
        if dtype is None and device is not None and not isinstance(device, str):
            try:
                parsed_dtype = np.dtype(device)
            except Exception:
                parsed_dtype = None
            if parsed_dtype is not None:
                dtype = parsed_dtype
                device = None

        for module in self.modules():
            if device is not None:
                module.device = device

            for name, value in list(module.__dict__.items()):
                if name in ("training", "_buffers"):
                    continue
                if isinstance(value, Module):
                    continue
                converted = _convert_container(value, device=device, dtype=dtype)
                if converted is not value:
                    setattr(module, name, converted)

            if hasattr(module, "_buffers"):
                for buf_name, meta in list(module._buffers.items()):
                    current = getattr(module, buf_name)
                    converted = _convert_container(current, device=device, dtype=dtype)
                    setattr(module, buf_name, converted)
                    meta["value"] = converted

        return self

    def cpu(self):
        """将模块移动到CPU"""
        return self.to(device='cpu')

    def cuda(self):
        """将模块移动到CUDA"""
        return self.to(device='cuda')

    def double(self):
        """将参数转换为float64"""
        return self.to(dtype=np.float64)

    def float(self):
        """将参数转换为float32"""
        return self.to(dtype=np.float32)

    def half(self):
        """将参数转换为float16"""
        return self.to(dtype=np.float16)

    def type(self, dtype):
        """按dtype转换模块参数（PyTorch风格）"""
        return self.to(dtype=dtype)

    Module.requires_grad_ = requires_grad_
    Module.to = to
    Module.cpu = cpu
    Module.cuda = cuda
    Module.double = double
    Module.float = float
    Module.half = half
    Module.type = type


_add_module_methods()
