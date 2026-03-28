import numpy as np

try:
    import torch
    import torch_npu  # noqa: F401
except Exception:
    torch = None


_TORCH_TO_NUMPY_DTYPE = {
    "torch.float16": np.dtype("float16"),
    "torch.float32": np.dtype("float32"),
    "torch.int32": np.dtype("int32"),
    "torch.int64": np.dtype("int64"),
}


def _torch_dtype_from_numpy(dtype: np.dtype):
    dtype = np.dtype(dtype)
    if dtype == np.dtype("float64"):
        # Keep parity with existing CUDA path: promote float64 host arrays to float32 on accelerator.
        return torch.float32
    if dtype == np.dtype("float32"):
        return torch.float32
    if dtype == np.dtype("float16"):
        return torch.float16
    if dtype == np.dtype("int32"):
        return torch.int32
    if dtype == np.dtype("int64"):
        return torch.int64
    raise TypeError("npu ops only support float16/float32/int32/int64 host arrays")


def _numpy_dtype_from_torch(dtype) -> np.dtype:
    key = str(dtype)
    if key in _TORCH_TO_NUMPY_DTYPE:
        return _TORCH_TO_NUMPY_DTYPE[key]
    raise TypeError(f"unsupported torch dtype on NPU backend: {dtype}")


class DeviceArray:
    def __init__(self, tensor):
        if torch is None:
            raise RuntimeError("torch is unavailable")
        if not isinstance(tensor, torch.Tensor):
            raise TypeError("DeviceArray expects torch.Tensor")
        self.tensor = tensor
        self.shape = tuple(int(x) for x in tensor.shape)
        self.dtype = _numpy_dtype_from_torch(tensor.dtype)

    @property
    def size(self) -> int:
        n = 1
        for d in self.shape:
            n *= d
        return n


def available() -> bool:
    if torch is None:
        return False
    if not hasattr(torch, "npu"):
        return False
    try:
        return bool(torch.npu.is_available())
    except Exception:
        return False


def _ensure_array(x: np.ndarray) -> np.ndarray:
    if not isinstance(x, np.ndarray):
        raise TypeError("npu ops require numpy.ndarray inputs")
    if not x.flags["C_CONTIGUOUS"]:
        x = np.ascontiguousarray(x)
    target_dtype = _torch_dtype_from_numpy(x.dtype)
    if target_dtype == torch.float32 and x.dtype != np.float32:
        x = x.astype(np.float32, copy=False)
    return x


def _normalize_axis(axis, ndim):
    if axis is None:
        return None
    if isinstance(axis, tuple):
        return tuple(a + ndim if a < 0 else a for a in axis)
    if not isinstance(axis, int):
        return axis
    return axis + ndim if axis < 0 else axis


def _ensure_device_array(x):
    if not isinstance(x, DeviceArray):
        raise TypeError("expected DeviceArray")
    return x


def _wrap(tensor) -> DeviceArray:
    return DeviceArray(tensor)


def _ensure_npu_context() -> None:
    if not available():
        raise RuntimeError("neurx.npu backend not available")
    try:
        torch.npu.current_device()
    except Exception:
        torch.npu.set_device("npu:0")


def to_device(x: np.ndarray) -> DeviceArray:
    _ensure_npu_context()
    x = _ensure_array(x)
    tensor = torch.from_numpy(x)
    tensor = tensor.to("npu")
    return _wrap(tensor)


def to_host(x: DeviceArray) -> np.ndarray:
    _ensure_device_array(x)
    return x.tensor.detach().cpu().numpy()


def add(a: DeviceArray, b: DeviceArray) -> DeviceArray:
    a = _ensure_device_array(a)
    b = _ensure_device_array(b)
    if a.shape != b.shape or a.dtype != b.dtype:
        raise ValueError("add expects same shape and dtype")
    return _wrap(a.tensor + b.tensor)


def mul(a: DeviceArray, b: DeviceArray) -> DeviceArray:
    a = _ensure_device_array(a)
    b = _ensure_device_array(b)
    if a.shape != b.shape or a.dtype != b.dtype:
        raise ValueError("mul expects same shape and dtype")
    return _wrap(a.tensor * b.tensor)


def add_bias(a: DeviceArray, bias: DeviceArray) -> DeviceArray:
    a = _ensure_device_array(a)
    bias = _ensure_device_array(bias)
    if a.dtype != bias.dtype:
        raise ValueError("add_bias expects same dtype")
    if len(a.shape) != 2 or len(bias.shape) != 1:
        raise ValueError("add_bias expects (m,n) + (n)")
    m, n = a.shape
    if bias.shape[0] != n:
        raise ValueError("add_bias shape mismatch")
    return _wrap(a.tensor + bias.tensor)


def add_bias_3d(a: DeviceArray, bias: DeviceArray) -> DeviceArray:
    a = _ensure_device_array(a)
    bias = _ensure_device_array(bias)
    if a.dtype != bias.dtype:
        raise ValueError("add_bias_3d expects same dtype")
    if len(a.shape) != 3 or len(bias.shape) != 1:
        raise ValueError("add_bias_3d expects (b,t,c) + (c)")
    b, t, c = a.shape
    if bias.shape[0] != c:
        raise ValueError("add_bias_3d shape mismatch")
    return _wrap(a.tensor + bias.tensor.view(1, 1, c))


def matmul(a: DeviceArray, b: DeviceArray) -> DeviceArray:
    a = _ensure_device_array(a)
    b = _ensure_device_array(b)
    if a.dtype != b.dtype:
        raise ValueError("matmul expects same dtype")
    if len(a.shape) != 2 or len(b.shape) != 2:
        raise ValueError("matmul expects 2D matrices")
    if a.shape[1] != b.shape[0]:
        raise ValueError("matmul shape mismatch")
    return _wrap(a.tensor @ b.tensor)


def reduce_sum(a: DeviceArray, axis=None, keepdims=False) -> DeviceArray:
    a = _ensure_device_array(a)
    axis = _normalize_axis(axis, len(a.shape))
    out = a.tensor.sum(dim=axis, keepdim=bool(keepdims))
    return _wrap(out)


def reduce_mean(a: DeviceArray, axis=None, keepdims=False) -> DeviceArray:
    a = _ensure_device_array(a)
    axis = _normalize_axis(axis, len(a.shape))
    out = a.tensor.float().mean(dim=axis, keepdim=bool(keepdims))
    return _wrap(out)


def reduce_max(a: DeviceArray, axis=None, keepdims=False) -> DeviceArray:
    a = _ensure_device_array(a)
    axis = _normalize_axis(axis, len(a.shape))
    if axis is None:
        return _wrap(a.tensor.max())
    out = a.tensor.max(dim=axis, keepdim=bool(keepdims)).values
    return _wrap(out)


def reduce_min(a: DeviceArray, axis=None, keepdims=False) -> DeviceArray:
    a = _ensure_device_array(a)
    axis = _normalize_axis(axis, len(a.shape))
    if axis is None:
        return _wrap(a.tensor.min())
    out = a.tensor.min(dim=axis, keepdim=bool(keepdims)).values
    return _wrap(out)


def argmax(a: DeviceArray, axis=None):
    a = _ensure_device_array(a)
    axis = _normalize_axis(axis, len(a.shape))
    if axis is None:
        return _wrap(torch.argmax(a.tensor).to(torch.int64))
    return _wrap(torch.argmax(a.tensor, dim=axis).to(torch.int64))


def argmin(a: DeviceArray, axis=None):
    a = _ensure_device_array(a)
    axis = _normalize_axis(axis, len(a.shape))
    if axis is None:
        return _wrap(torch.argmin(a.tensor).to(torch.int64))
    return _wrap(torch.argmin(a.tensor, dim=axis).to(torch.int64))