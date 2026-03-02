import numpy as np

try:
    from . import _tensor_cuda as _cuda
except Exception:
    _cuda = None


class DeviceArray:
    def __init__(self, capsule, shape, dtype):
        self.capsule = capsule
        self.shape = tuple(int(x) for x in shape)
        self.dtype = np.dtype(dtype)

    @property
    def size(self) -> int:
        n = 1
        for d in self.shape:
            n *= d
        return n


def available() -> bool:
    return _cuda is not None


def _ensure_array(x: np.ndarray) -> np.ndarray:
    if not isinstance(x, np.ndarray):
        raise TypeError("cuda ops require numpy.ndarray inputs")
    if not x.flags["C_CONTIGUOUS"]:
        x = np.ascontiguousarray(x)
    if x.dtype not in (np.float32,):
        raise TypeError("cuda ops only support float32")
    return x


def to_device(x: np.ndarray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    x = _ensure_array(x)
    capsule = _cuda.to_device(x)
    return DeviceArray(capsule, x.shape, x.dtype)


def to_host(x: DeviceArray) -> np.ndarray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if not isinstance(x, DeviceArray):
        raise TypeError("to_host expects DeviceArray")
    return _cuda.to_host(x.capsule, x.shape, str(x.dtype))


def add(a: DeviceArray, b: DeviceArray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if a.shape != b.shape or a.dtype != b.dtype:
        raise ValueError("add expects same shape and dtype")
    capsule = _cuda.add_device(a.capsule, b.capsule, a.size, str(a.dtype))
    return DeviceArray(capsule, a.shape, a.dtype)


def mul(a: DeviceArray, b: DeviceArray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if a.shape != b.shape or a.dtype != b.dtype:
        raise ValueError("mul expects same shape and dtype")
    capsule = _cuda.mul_device(a.capsule, b.capsule, a.size, str(a.dtype))
    return DeviceArray(capsule, a.shape, a.dtype)


def add_bias(a: DeviceArray, bias: DeviceArray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if a.dtype != bias.dtype:
        raise ValueError("add_bias expects same dtype")
    if len(a.shape) != 2 or len(bias.shape) != 1:
        raise ValueError("add_bias expects (m,n) + (n)")
    m, n = a.shape
    if bias.shape[0] != n:
        raise ValueError("add_bias shape mismatch")
    capsule = _cuda.add_bias_device(a.capsule, bias.capsule, m, n, str(a.dtype))
    return DeviceArray(capsule, a.shape, a.dtype)


def add_bias_3d(a: DeviceArray, bias: DeviceArray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if a.dtype != bias.dtype:
        raise ValueError("add_bias_3d expects same dtype")
    if len(a.shape) != 3 or len(bias.shape) != 1:
        raise ValueError("add_bias_3d expects (b,t,c) + (c)")
    b, t, c = a.shape
    if bias.shape[0] != c:
        raise ValueError("add_bias_3d shape mismatch")
    capsule = _cuda.add_bias_3d_device(a.capsule, bias.capsule, b, t, c, str(a.dtype))
    return DeviceArray(capsule, a.shape, a.dtype)


def matmul(a: DeviceArray, b: DeviceArray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if a.dtype != b.dtype:
        raise ValueError("matmul expects same dtype")
    if len(a.shape) != 2 or len(b.shape) != 2:
        raise ValueError("matmul expects 2D matrices")
    if a.shape[1] != b.shape[0]:
        raise ValueError("matmul shape mismatch")
    m, k = a.shape
    _, n = b.shape
    capsule = _cuda.matmul_device(a.capsule, b.capsule, m, k, n, str(a.dtype))
    return DeviceArray(capsule, (m, n), a.dtype)


def layernorm(a: DeviceArray, gamma: DeviceArray, beta: DeviceArray, eps: float) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if a.dtype != gamma.dtype or a.dtype != beta.dtype:
        raise ValueError("layernorm expects same dtype")
    if len(a.shape) not in (2, 3):
        raise ValueError("layernorm expects 2D or 3D input")
    if len(a.shape) == 2:
        m, n = a.shape
    else:
        b, t, n = a.shape
        m = b * t
    if gamma.shape[0] != n or beta.shape[0] != n:
        raise ValueError("layernorm shape mismatch")
    capsule = _cuda.layernorm_device(a.capsule, gamma.capsule, beta.capsule, m, n, float(eps), str(a.dtype))
    return DeviceArray(capsule, a.shape, a.dtype)


def softmax(a: DeviceArray) -> DeviceArray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    if len(a.shape) not in (2, 3):
        raise ValueError("softmax expects 2D or 3D input")
    if len(a.shape) == 2:
        m, n = a.shape
    else:
        b, t, n = a.shape
        m = b * t
    capsule = _cuda.softmax_device(a.capsule, m, n, str(a.dtype))
    return DeviceArray(capsule, a.shape, a.dtype)
