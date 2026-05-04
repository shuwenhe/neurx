# neurx 优化实现指南

**文档目的**: 提供具体的代码实现方案和优化示例  
**目标受众**: neurx 核心开发人员  
**最后更新**: 2026-03-04

---

## 🎯 一、高优先级功能实现示例

### 1.1 布尔索引实现

#### 基础实现框架
```python
# 文件: neurx/python/neurx/core/neurx.py

class Tensor:
    def __getitem__(self, key):
        """增强的索引方法，支持布尔索引"""
        # 1. 处理布尔张量索引
        if isinstance(key, Tensor) and self.dtype == np.bool_:
            return self._boolean_indexing(key)
        
        # 2. 处理高级索引（整数数组）
        if isinstance(key, (list, tuple)):
            return self._advanced_indexing(key)
        
        # 3. 处理 Ellipsis
        if key is Ellipsis or (isinstance(key, tuple) and Ellipsis in key):
            return self._ellipsis_indexing(key)
        
        # 4. 原有切片逻辑
        return self._basic_indexing(key)
    
    def _boolean_indexing(self, mask):
        """布尔索引实现"""
        # 确保 mask 和 self 形状兼容
        if mask.shape != self.shape:
            raise ValueError(
                f"Boolean mask shape {mask.shape} does not match tensor shape {self.shape}"
            )
        
        # 转换为 NumPy 进行索引
        data_np = _to_numpy(self.data)
        mask_np = _to_numpy(mask.data).astype(bool)
        result = data_np[mask_np]
        
        # 构建计算图
        out = Tensor(result, requires_grad=self.requires_grad, device=self.device)
        
        if self.requires_grad:
            def _backward():
                # 梯度回传到原始位置
                grad_full = np.zeros_like(self.data)
                grad_full[mask_np] = _to_numpy(out.grad)
                self.grad += grad_full
            out._backward = _backward
            out._prev = {self}
        
        return out
    
    def _advanced_indexing(self, indices):
        """高级索引实现"""
        # 转换所有索引为 NumPy 数组
        np_indices = []
        for idx in indices:
            if isinstance(idx, Tensor):
                np_indices.append(_to_numpy(idx.data).astype(int))
            elif isinstance(idx, (list, np.ndarray)):
                np_indices.append(np.array(idx, dtype=int))
            else:
                np_indices.append(idx)
        
        # 执行索引
        data_np = _to_numpy(self.data)
        result = data_np[tuple(np_indices)]
        
        out = Tensor(result, requires_grad=self.requires_grad, device=self.device)
        
        if self.requires_grad:
            def _backward():
                grad_full = np.zeros_like(self.data)
                # 使用 np.add.at 进行梯度累积
                np.add.at(grad_full, tuple(np_indices), _to_numpy(out.grad))
                self.grad += grad_full
            out._backward = _backward
            out._prev = {self}
        
        return out
    
    def _ellipsis_indexing(self, key):
        """Ellipsis 索引实现"""
        # 展开 Ellipsis 为具体的切片
        if key is Ellipsis:
            return self
        
        # 计算 Ellipsis 应该展开的维度数
        key = list(key) if isinstance(key, tuple) else [key]
        ellipsis_count = key.count(Ellipsis)
        
        if ellipsis_count > 1:
            raise IndexError("Only one ellipsis (...) is allowed in indexing")
        
        if ellipsis_count == 0:
            return self.__getitem__(tuple(key))
        
        ellipsis_idx = key.index(Ellipsis)
        num_explicit = len([k for k in key if k is not Ellipsis and k is not None])
        num_missing = self.ndim - num_explicit
        
        # 将 Ellipsis 替换为相应数量的 slice(None)
        expanded_key = (
            key[:ellipsis_idx] + 
            [slice(None)] * num_missing + 
            key[ellipsis_idx + 1:]
        )
        
        return self.__getitem__(tuple(expanded_key))
```

---

### 1.2 Float16/BFloat16 支持

#### 数据类型扩展
```python
# 文件: neurx/python/neurx/core/dtypes.py

import numpy as np

class DType:
    """数据类型类"""
    def __init__(self, name, numpy_dtype, itemsize, is_floating=False):
        self.name = name
        self.numpy_dtype = numpy_dtype
        self.itemsize = itemsize
        self.is_floating = is_floating

# 定义支持的数据类型
float32 = DType("float32", np.float32, 4, True)
float64 = DType("float64", np.float64, 8, True)
float16 = DType("float16", np.float16, 2, True)
bfloat16 = DType("bfloat16", None, 2, True)  # 需要自定义实现
int8 = DType("int8", np.int8, 1, False)
int16 = DType("int16", np.int16, 2, False)
int32 = DType("int32", np.int32, 4, False)
int64 = DType("int64", np.int64, 8, False)
bool_ = DType("bool", np.bool_, 1, False)

# BFloat16 自定义实现（NumPy 不原生支持）
class BFloat16:
    """BFloat16 数据类型模拟"""
    def __init__(self, value):
        if isinstance(value, np.ndarray):
            # 从 float32 转换
            self.data = self._float32_to_bfloat16(value)
        else:
            self.data = value
    
    @staticmethod
    def _float32_to_bfloat16(arr):
        """Float32 → BFloat16 转换（截断后16位）"""
        # 将 float32 视为 uint32，然后截断
        f32_bits = arr.view(np.uint32)
        # BFloat16 = Float32 的高 16 位
        bf16_bits = (f32_bits >> 16).astype(np.uint16)
        return bf16_bits
    
    @staticmethod
    def _bfloat16_to_float32(bf16_arr):
        """BFloat16 → Float32 转换"""
        # 将低 16 位补零
        f32_bits = bf16_arr.astype(np.uint32) << 16
        return f32_bits.view(np.float32)
```

#### Tensor 类型转换增强
```python
# 文件: neurx/python/neurx/core/neurx.py

class Tensor:
    def half(self):
        """转换为 float16"""
        return self.to(dtype=float16)
    
    def bfloat16(self):
        """转换为 bfloat16"""
        return self.to(dtype=bfloat16)
    
    def to(self, device=None, dtype=None):
        """统一的设备和类型转换"""
        target_device = device if device is not None else self.device
        target_dtype = dtype if dtype is not None else self.dtype
        
        # 设备转换
        if target_device != self.device:
            if target_device == "cuda":
                new_data = _cuda_ops.to_device(self.to_numpy())
            else:
                new_data = self.to_numpy()
        else:
            new_data = self.data
        
        # 数据类型转换
        if target_dtype != self.dtype:
            if target_dtype == bfloat16:
                # BFloat16 特殊处理
                new_data = BFloat16(_to_numpy(new_data).astype(np.float32)).data
            else:
                new_data = _to_numpy(new_data).astype(target_dtype.numpy_dtype)
        
        return Tensor(new_data, requires_grad=self.requires_grad, device=target_device)
```

---

### 1.3 CUDA Kernel 实现示例 - Conv2d

#### CUDA Kernel 实现
```cuda
// 文件: neurx/cuda/kernels/conv2d.cu

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

// Im2Col 变换 kernel
__global__ void im2col_kernel(
    const float* input,        // [N, C, H, W]
    float* col,                // [C*kH*kW, out_H*out_W]
    int C, int H, int W,
    int kH, int kW,
    int stride_h, int stride_w,
    int pad_h, int pad_w,
    int out_H, int out_W
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total_elements = C * kH * kW * out_H * out_W;
    
    if (idx < total_elements) {
        // 计算在输出空间的位置
        int w_out = idx % out_W;
        int h_out = (idx / out_W) % out_H;
        int kw = (idx / (out_W * out_H)) % kW;
        int kh = (idx / (out_W * out_H * kW)) % kH;
        int c = idx / (out_W * out_H * kW * kH);
        
        // 计算在输入中的位置
        int h_in = h_out * stride_h - pad_h + kh;
        int w_in = w_out * stride_w - pad_w + kw;
        
        // 边界检查
        if (h_in >= 0 && h_in < H && w_in >= 0 && w_in < W) {
            int input_idx = c * H * W + h_in * W + w_in;
            col[idx] = input[input_idx];
        } else {
            col[idx] = 0.0f;  // Padding
        }
    }
}

// Conv2d Forward (Im2Col + GEMM)
extern "C" void cuda_conv2d_forward(
    const float* input,   // [N, C_in, H, W]
    const float* weight,  // [C_out, C_in, kH, kW]
    const float* bias,    // [C_out] or nullptr
    float* output,        // [N, C_out, out_H, out_W]
    int N, int C_in, int H, int W,
    int C_out, int kH, int kW,
    int stride_h, int stride_w,
    int pad_h, int pad_w
) {
    int out_H = (H + 2 * pad_h - kH) / stride_h + 1;
    int out_W = (W + 2 * pad_w - kW) / stride_w + 1;
    
    // 分配临时 column buffer
    float* d_col;
    size_t col_size = C_in * kH * kW * out_H * out_W * sizeof(float);
    cudaMalloc(&d_col, col_size);
    
    for (int n = 0; n < N; ++n) {
        // 1. Im2Col 变换
        int threads = 256;
        int blocks = (C_in * kH * kW * out_H * out_W + threads - 1) / threads;
        im2col_kernel<<<blocks, threads>>>(
            input + n * C_in * H * W,
            d_col,
            C_in, H, W,
            kH, kW,
            stride_h, stride_w,
            pad_h, pad_w,
            out_H, out_W
        );
        
        // 2. GEMM: output = weight @ col
        // 使用 cuBLAS
        // cublasSgemm(...);
        
        // 3. Add bias (如果有)
        if (bias != nullptr) {
            // bias_add_kernel<<<...>>>();
        }
    }
    
    cudaFree(d_col);
}

// Conv2d Backward
extern "C" void cuda_conv2d_backward(
    const float* grad_output,  // [N, C_out, out_H, out_W]
    const float* input,        // [N, C_in, H, W]
    const float* weight,       // [C_out, C_in, kH, kW]
    float* grad_input,         // [N, C_in, H, W]
    float* grad_weight,        // [C_out, C_in, kH, kW]
    float* grad_bias,          // [C_out] or nullptr
    int N, int C_in, int H, int W,
    int C_out, int kH, int kW,
    int stride_h, int stride_w,
    int pad_h, int pad_w
) {
    // 实现梯度反向传播
    // grad_input = col2im(weight.T @ grad_output_col)
    // grad_weight = grad_output @ input_col.T
    // grad_bias = sum(grad_output, dim=(0, 2, 3))
    // ...
}
```

#### Python 绑定
```cpp
文件: neurx/backends/cuda/bindings.s

static PyObject* tensor_cuda_conv2d_forward(PyObject* /*self*/, PyObject* args) {
    PyObject* input_capsule = nullptr;
    PyObject* weight_capsule = nullptr;
    PyObject* bias_capsule = nullptr;  // 可选
    int N, C_in, H, W, C_out, kH, kW, stride_h, stride_w, pad_h, pad_w;
    
    if (!PyArg_ParseTuple(args, "OOOiiiiiiiiiii",
        &input_capsule, &weight_capsule, &bias_capsule,
        &N, &C_in, &H, &W, &C_out, &kH, &kW,
        &stride_h, &stride_w, &pad_h, &pad_w)) {
        return nullptr;
    }
    
    auto* input_arr = _get_device_array(input_capsule);
    auto* weight_arr = _get_device_array(weight_capsule);
    auto* bias_arr = bias_capsule != Py_None ? _get_device_array(bias_capsule) : nullptr;
    
    int out_H = (H + 2 * pad_h - kH) / stride_h + 1;
    int out_W = (W + 2 * pad_w - kW) / stride_w + 1;
    size_t output_size = N * C_out * out_H * out_W;
    
    void* d_output = nullptr;
    cudaMalloc(&d_output, output_size * sizeof(float));
    
    cuda_conv2d_forward(
        (const float*)input_arr->ptr,
        (const float*)weight_arr->ptr,
        bias_arr ? (const float*)bias_arr->ptr : nullptr,
        (float*)d_output,
        N, C_in, H, W, C_out, kH, kW,
        stride_h, stride_w, pad_h, pad_w
    );
    
    auto* out = new DeviceArray{d_output, output_size};
    return PyCapsule_New(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
```

#### Python 层调用
```python
# 文件: neurx/python/neurx/nn/modules/conv.py

class Conv2d(Module):
    def forward(self, x):
        if x.device == "cuda" and _cuda_ops is not None:
            # 使用 CUDA kernel
            return _cuda_ops.conv2d_forward(
                x.data, self.weight.data, 
                self.bias.data if self.bias is not None else None,
                self.kernel_size, self.stride, self.padding
            )
        else:
            # CPU fallback
            return self._conv2d_cpu(x)
```

---

### 1.4 内存池实现

#### CUDA 内存池
```python
# 文件: neurx/python/neurx/cuda/memory.py

import threading
from collections import defaultdict

class CUDAMemoryPool:
    """CUDA 显存池管理器"""
    def __init__(self):
        self.pool = defaultdict(list)  # {size: [ptr1, ptr2, ...]}
        self.allocated = {}  # {ptr: size}
        self.lock = threading.Lock()
        self.stats = {
            'allocated_bytes': 0,
            'cached_bytes': 0,
            'num_alloc_calls': 0,
            'num_free_calls': 0,
        }
    
    def allocate(self, size_bytes):
        """分配显存"""
        with self.lock:
            # 1. 尝试从池中复用
            if size_bytes in self.pool and self.pool[size_bytes]:
                ptr = self.pool[size_bytes].pop()
                self.stats['cached_bytes'] -= size_bytes
                return ptr
            
            # 2. 分配新内存
            import cupy as cp  # 或直接使用 pycuda
            ptr = cp.cuda.alloc(size_bytes)
            self.allocated[ptr] = size_bytes
            self.stats['allocated_bytes'] += size_bytes
            self.stats['num_alloc_calls'] += 1
            return ptr
    
    def free(self, ptr):
        """释放显存（回收到池中）"""
        with self.lock:
            if ptr not in self.allocated:
                raise ValueError("Trying to free unmanaged pointer")
            
            size = self.allocated[ptr]
            # 不真正释放，而是放回池中
            self.pool[size].append(ptr)
            self.stats['cached_bytes'] += size
            self.stats['num_free_calls'] += 1
    
    def empty_cache(self):
        """清空缓存池"""
        with self.lock:
            for size, ptrs in self.pool.items():
                for ptr in ptrs:
                    # 真正释放显存
                    import cupy as cp
                    cp.cuda.free(ptr)
                    self.stats['allocated_bytes'] -= size
                    self.stats['cached_bytes'] -= size
            self.pool.clear()
    
    def memory_summary(self):
        """显存统计"""
        return {
            'allocated': f"{self.stats['allocated_bytes'] / 1024**2:.2f} MB",
            'cached': f"{self.stats['cached_bytes'] / 1024**2:.2f} MB",
            'num_allocs': self.stats['num_alloc_calls'],
            'num_frees': self.stats['num_free_calls'],
        }

# 全局内存池实例
_memory_pool = CUDAMemoryPool()

def cuda_malloc(size_bytes):
    return _memory_pool.allocate(size_bytes)

def cuda_free(ptr):
    _memory_pool.free(ptr)

def empty_cache():
    _memory_pool.empty_cache()

def memory_summary():
    return _memory_pool.memory_summary()
```

---

### 1.5 算子融合示例 - LayerNorm + Dropout

#### 融合 Kernel
```cuda
// 文件: neurx/cuda/kernels/fused_ops.cu

// 融合 LayerNorm + Dropout
__global__ void fused_layernorm_dropout_kernel(
    const float* input,
    const float* gamma,
    const float* beta,
    float* output,
    unsigned char* mask,  // dropout mask
    int M, int N,
    float eps,
    float dropout_p,
    unsigned long long seed
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= M) return;
    
    // 1. LayerNorm (per row)
    const float* row = input + idx * N;
    float* out_row = output + idx * N;
    unsigned char* mask_row = mask + idx * N;
    
    // 计算均值和方差
    float mean = 0.0f, var = 0.0f;
    for (int i = 0; i < N; ++i) {
        mean += row[i];
    }
    mean /= N;
    
    for (int i = 0; i < N; ++i) {
        float diff = row[i] - mean;
        var += diff * diff;
    }
    var = var / N + eps;
    float inv_std = rsqrtf(var);
    
    // 2. 归一化 + Dropout
    float scale = 1.0f / (1.0f - dropout_p);
    for (int i = 0; i < N; ++i) {
        // LayerNorm
        float normalized = (row[i] - mean) * inv_std;
        float scaled = normalized * gamma[i] + beta[i];
        
        // Dropout
        // 使用线程随机数生成
        unsigned long long rng_state = seed + idx * N + i;
        float rand_val = __uint_as_float(rng_state) / UINT_MAX;
        bool keep = rand_val > dropout_p;
        
        mask_row[i] = keep ? 1 : 0;
        out_row[i] = keep ? scaled * scale : 0.0f;
    }
}
```

---

## 🔨 二、中优先级功能实现

### 2.1 完整 DDP 实现框架

#### 梯度同步实现
```python
# 文件: neurx/python/neurx/distributed/ddp.py

import numpy as np
from neurx.distributed import get_world_size, get_rank, all_reduce

class DistributedDataParallel:
    """分布式数据并行包装器"""
    def __init__(
        self,
        module,
        device_ids=None,
        output_device=None,
        broadcast_buffers=True,
        find_unused_parameters=False,
        gradient_as_bucket_view=False,
        bucket_cap_mb=25
    ):
        self.module = module
        self.device_ids = device_ids or [0]
        self.output_device = output_device or self.device_ids[0]
        self.broadcast_buffers = broadcast_buffers
        self.find_unused_parameters = find_unused_parameters
        self.bucket_cap_mb = bucket_cap_mb
        
        self.world_size = get_world_size()
        self.rank = get_rank()
        
        # 梯度桶
        self.gradient_buckets = self._build_gradient_buckets()
        
        # 注册梯度 hook
        self._register_gradient_hooks()
    
    def _build_gradient_buckets(self):
        """将参数分组到桶中以优化通信"""
        buckets = []
        current_bucket = []
        current_size = 0
        bucket_size_limit = self.bucket_cap_mb * 1024 * 1024  # 转换为字节
        
        for param in self.module.parameters():
            if param.requires_grad:
                param_size = param.numel() * 4  # float32 = 4 bytes
                if current_size + param_size > bucket_size_limit and current_bucket:
                    buckets.append(current_bucket)
                    current_bucket = []
                    current_size = 0
                
                current_bucket.append(param)
                current_size += param_size
        
        if current_bucket:
            buckets.append(current_bucket)
        
        return buckets
    
    def _register_gradient_hooks(self):
        """注册梯度计算后的同步 hook"""
        for bucket_idx, bucket in enumerate(self.gradient_buckets):
            for param in bucket:
                # 每个参数梯度计算完成后触发
                param.register_hook(
                    lambda grad, b_idx=bucket_idx: self._gradient_ready_hook(grad, b_idx)
                )
    
    def _gradient_ready_hook(self, grad, bucket_idx):
        """梯度就绪时触发的 hook"""
        # 检查桶中所有参数的梯度是否都已计算
        bucket = self.gradient_buckets[bucket_idx]
        all_ready = all(p.grad is not None for p in bucket)
        
        if all_ready:
            # 执行 All-Reduce
            self._sync_bucket_gradients(bucket_idx)
    
    def _sync_bucket_gradients(self, bucket_idx):
        """同步一个桶的梯度"""
        bucket = self.gradient_buckets[bucket_idx]
        
        # 1. 将桶中所有梯度打包成一个连续张量
        grad_list = [p.grad.to_numpy().flatten() for p in bucket]
        packed_grad = np.concatenate(grad_list)
        
        # 2. All-Reduce (平均梯度)
        synced_grad = all_reduce(packed_grad, op='mean')
        
        # 3. 解包回各个参数
        offset = 0
        for param in bucket:
            numel = param.grad.numel()
            param.grad = synced_grad[offset:offset + numel].reshape(param.grad.shape)
            offset += numel
    
    def forward(self, *inputs, **kwargs):
        """前向传播"""
        # 广播输入到所有设备
        if self.rank == 0 and self.broadcast_buffers:
            self._broadcast_buffers()
        
        return self.module(*inputs, **kwargs)
    
    def _broadcast_buffers(self):
        """广播 buffer (如 BN 的 running_mean)"""
        for buffer in self.module.buffers():
            # 从 rank 0 广播到所有进程
            from neurx.distributed import broadcast
            broadcast(buffer, src=0)
```

#### 通信后端（NCCL绑定示例）
```python
# 文件: neurx/python/neurx/distributed/comm.py

import ctypes
import numpy as np

# 加载 NCCL 库（需要预先安装 NCCL）
try:
    nccl = ctypes.CDLL("libnccl.so")
except OSError:
    nccl = None

class NCCLCommunicator:
    """NCCL 通信包装器"""
    def __init__(self):
        if nccl is None:
            raise RuntimeError("NCCL library not found")
        self.comm = None
        self.rank = None
        self.world_size = None
    
    def init_process_group(self, backend='nccl', init_method='env://'):
        """初始化进程组"""
        # 读取环境变量
        import os
        self.rank = int(os.environ.get('RANK', 0))
        self.world_size = int(os.environ.get('WORLD_SIZE', 1))
        
        # 初始化 NCCL
        # nccl.ncclCommInitRank(...)
        ...
    
    def all_reduce(self, tensor, op='sum'):
        """All-Reduce 操作"""
        # 将 tensor 转换为 GPU 指针
        # 调用 NCCL 的 ncclAllReduce
        # nccl.ncclAllReduce(...)
        ...
    
    def broadcast(self, tensor, src=0):
        """广播操作"""
        # nccl.ncclBroadcast(...)
        ...
    
    def barrier(self):
        """同步屏障"""
        # nccl.ncclBarrier(...)
        ...
```

---

### 2.2 ONNX 导出实现框架

```python
# 文件: neurx/python/neurx/onnx/export.py

import onnx
from onnx import helper, TensorProto
from collections import OrderedDict

class ONNXExporter:
    """neurx 模型导出为 ONNX"""
    def __init__(self, model, example_inputs):
        self.model = model
        self.example_inputs = example_inputs
        self.node_list = []
        self.initializers = []
        self.inputs = []
        self.outputs = []
        self.value_info = []
    
    def export(self, output_path, input_names=None, output_names=None):
        """导出模型"""
        # 1. 追踪计算图
        self._trace_graph()
        
        # 2. 转换为 ONNX 节点
        self._convert_to_onnx_nodes()
        
        # 3. 构建 ONNX graph
        graph = helper.make_graph(
            nodes=self.node_list,
            name="neurx_model",
            inputs=self.inputs,
            outputs=self.outputs,
            initializer=self.initializers,
            value_info=self.value_info
        )
        
        # 4. 创建 ONNX model
        model = helper.make_model(graph, producer_name="neurx")
        
        # 5. 保存
        onnx.save(model, output_path)
        print(f"Model exported to {output_path}")
    
    def _trace_graph(self):
        """追踪计算图"""
        # 使用 hook 记录所有操作
        self.operations = []
        
        def forward_hook(module, input, output):
            self.operations.append({
                'type': type(module).__name__,
                'module': module,
                'input': input,
                'output': output
            })
        
        # 注册 hook
        hooks = []
        for module in self.model.modules():
            hook = module.register_forward_hook(forward_hook)
            hooks.append(hook)
        
        # 执行前向传播
        self.model(self.example_inputs)
        
        # 移除 hook
        for hook in hooks:
            hook.remove()
    
    def _convert_to_onnx_nodes(self):
        """将 neurx 操作转换为 ONNX 节点"""
        for idx, op in enumerate(self.operations):
            op_type = op['type']
            
            if op_type == 'Linear':
                self._convert_linear(op, idx)
            elif op_type == 'Conv2d':
                self._convert_conv2d(op, idx)
            elif op_type == 'ReLU':
                self._convert_relu(op, idx)
            # ... 其他层类型
    
    def _convert_linear(self, op, idx):
        """Linear -> ONNX Gemm"""
        module = op['module']
        
        # 权重初始化器
        weight_name = f"linear_{idx}_weight"
        self.initializers.append(
            helper.make_tensor(
                name=weight_name,
                data_type=TensorProto.FLOAT,
                dims=module.weight.shape,
                vals=module.weight.to_numpy().flatten().tolist()
            )
        )
        
        # 偏置
        bias_name = f"linear_{idx}_bias"
        if module.bias is not None:
            self.initializers.append(
                helper.make_tensor(
                    name=bias_name,
                    data_type=TensorProto.FLOAT,
                    dims=module.bias.shape,
                    vals=module.bias.to_numpy().flatten().tolist()
                )
            )
        
        # ONNX Gemm 节点
        node = helper.make_node(
            'Gemm',
            inputs=[f"input_{idx}", weight_name, bias_name],
            outputs=[f"output_{idx}"],
            alpha=1.0,
            beta=1.0,
            transB=1
        )
        self.node_list.append(node)
```

---

## 📈 三、性能优化技巧

### 3.1 内存池使用示例

```python
# 训练前启用内存池
import neurx

# 预热 GPU（避免首次分配延迟）
warmup_tensor = neurx.randn((1000, 1000), device='cuda')
del warmup_tensor
neurx.cuda.empty_cache()

# 训练循环
for epoch in range(num_epochs):
    for batch in dataloader:
        optimizer.zero_grad()
        output = model(batch)
        loss = criterion(output, labels)
        loss.backward()
        optimizer.step()
        
        # 每 100 个 batch 清理一次缓存
        if batch_idx % 100 == 0:
            neurx.cuda.empty_cache()
```

### 3.2 混合精度训练模板

```python
import neurx
from neurx.training import autocast, GradScaler

model = MyModel().cuda()
optimizer = neurx.optim.AdamW(model.parameters(), lr=1e-4)
scaler = GradScaler()

for epoch in range(num_epochs):
    for batch in dataloader:
        optimizer.zero_grad()
        
        # 自动混合精度
        with autocast(dtype=neurx.float16):
            output = model(batch)
            loss = criterion(output, labels)
        
        # 缩放损失并反向传播
        scaler.scale(loss).backward()
        
        # 梯度裁剪
        scaler.unscale_(optimizer)
        neurx.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        
        # 优化器步进
        scaler.step(optimizer)
        scaler.update()
```

### 3.3 梯度检查点使用

```python
# 定义需要检查点的模块
class CheckpointedBlock(neurx.nn.Module):
    def __init__(self, block):
        super().__init__()
        self.block = block
    
    def forward(self, x):
        # 使用梯度检查点节省显存
        return neurx.utils.checkpoint(self.block, x)

# 构建模型
model = neurx.nn.Sequential(
    CheckpointedBlock(TransformerLayer()),
    CheckpointedBlock(TransformerLayer()),
    CheckpointedBlock(TransformerLayer()),
    # 最后一层不使用检查点（避免重计算开销）
    TransformerLayer()
)
```

---

## 🎯 四、测试与验证

### 4.1 梯度数值验证模板

```python
import neurx
import numpy as np

def numerical_gradient(func, x, eps=1e-5):
    """数值梯度计算"""
    grad = np.zeros_like(x.to_numpy())
    x_np = x.to_numpy()
    
    for i in range(x_np.size):
        # f(x + eps)
        x_np.flat[i] += eps
        x_plus = neurx.Tensor(x_np.copy(), requires_grad=False)
        f_plus = func(x_plus).to_numpy().sum()
        
        # f(x - eps)
        x_np.flat[i] -= 2 * eps
        x_minus = neurx.Tensor(x_np.copy(), requires_grad=False)
        f_minus = func(x_minus).to_numpy().sum()
        
        # 中心差分
        grad.flat[i] = (f_plus - f_minus) / (2 * eps)
        x_np.flat[i] += eps  # 恢复
    
    return grad

def test_gradient(func, x_shape):
    """测试自动求导与数值梯度的一致性"""
    x = neurx.randn(x_shape, requires_grad=True)
    
    # 自动求导
    y = func(x)
    loss = y.sum()
    loss.backward()
    auto_grad = x.grad.copy()
    
    # 数值梯度
    num_grad = numerical_gradient(func, x)
    
    # 比较
    diff = np.abs(auto_grad - num_grad).max()
    rel_error = diff / (np.abs(auto_grad).max() + 1e-8)
    
    print(f"Max absolute difference: {diff:.6e}")
    print(f"Relative error: {rel_error:.6e}")
    assert rel_error < 1e-4, f"Gradient check failed: {rel_error}"
    print("✅ Gradient check passed")

# 示例：测试自定义操作
def custom_op(x):
    return (x ** 2).sum(dim=1).sqrt()

test_gradient(custom_op, (4, 8))
```

### 4.2 性能基准测试模板

```python
import time
import neurx

def benchmark_op(func, *args, warmup=10, iters=100):
    """操作性能基准测试"""
    # Warmup
    for _ in range(warmup):
        result = func(*args)
        if hasattr(result, 'device') and result.device == 'cuda':
            neurx.cuda.synchronize()
    
    # Benchmark
    start = time.perf_counter()
    for _ in range(iters):
        result = func(*args)
        if hasattr(result, 'device') and result.device == 'cuda':
            neurx.cuda.synchronize()
    end = time.perf_counter()
    
    avg_time = (end - start) / iters * 1000  # ms
    return avg_time

# 示例：对比 CPU vs GPU
x_cpu = neurx.randn((1024, 1024), device='cpu')
x_gpu = neurx.randn((1024, 1024), device='cuda')

cpu_time = benchmark_op(lambda x: x @ x, x_cpu)
gpu_time = benchmark_op(lambda x: x @ x, x_gpu)

print(f"CPU: {cpu_time:.2f} ms")
print(f"GPU: {gpu_time:.2f} ms")
print(f"Speedup: {cpu_time / gpu_time:.2f}x")
```

---

## 📚 五、参考资源

### 开源实现参考
- **PyTorch**: https://github.com/pytorch/pytorch
- **TinyGrad**: https://github.com/geohot/tinygrad (简化实现)
- **JAX**: https://github.com/google/jax (XLA 编译器)

### CUDA 编程资源
- CUDA C++ Programming Guide
- CuDNN Developer Guide
- CUTLASS (NVIDIA GPU GEMM templates)

### 分布式训练
- Horovod: https://github.com/horovod/horovod
- DeepSpeed: https://github.com/microsoft/DeepSpeed
- Megatron-LM: https://github.com/NVIDIA/Megatron-LM

---

**文档维护**: neurx 核心开发团队  
**最后更新**: 2026-03-04
