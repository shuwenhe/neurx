"""Regression: a failed CUDA probe must preserve the actual CUDA diagnostic."""
import ctypes
from pathlib import Path

root = Path(__file__).resolve().parents[1]
bridge = ctypes.CDLL(str(root / 'artifact/build/s_gpu_runtime/libneurx_s_cuda.so'))
bridge.neurx_s_cuda_last_error.restype = ctypes.c_char_p
count = bridge.neurx_s_cuda_device_count()
message = bridge.neurx_s_cuda_last_error().decode()
if count < 0:
    assert 'cudaGetDeviceCount:' in message and 'check NVIDIA driver' in message, message
elif count == 0:
    assert 'zero visible GPUs' in message, message
else:
    assert message == '', message
print(f'PASS enumeration diagnostic: count={count}, message={message!r}')
