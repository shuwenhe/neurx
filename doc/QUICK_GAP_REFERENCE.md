# neurx 与 PyTorch 功能补齐 - 快速参考

**生成时间**: 2026-03-04  
**用途**: 快速查阅缺失功能和优化建议  

---

## 🎯 核心差距概览

| 维度 | neurx | PyTorch | 差距 |
|------|-------|---------|------|
| **API 覆盖率** | ~60% | 100% | ⭐⭐⭐ 40% |
| **CUDA Kernel** | ~8% | ~95% | ⭐⭐⭐ 87% |
| **训练速度** | 1x | 3-10x | ⭐⭐⭐ 3-10倍 |
| **显存效率** | 1x | 1.5-2x | ⭐⭐ 50-100% |
| **分布式支持** | 0% | 100% | ⭐⭐⭐ 缺失 |
| **量化** | 0% | 100% | ⭐⭐ 缺失 |

---

## 🔥 最高优先级缺失功能 (P0)

### 1. 张量操作
```python
# ❌ 布尔索引
mask = t > 0.5
selected = t[mask]  # NotImplemented

# ❌ 高级索引
result = t[[0, 2, 3], [1, 3, 4]]  # NotImplemented

# ❌ clamp/clip
t.clamp(-1.0, 1.0)  # NotImplemented

# ❌ cumsum/cumprod
torch.cumsum(t, dim=0)  # NotImplemented

# ❌ sign
torch.sign(t)  # NotImplemented
```

### 2. 数据类型
```python
# ❌ Float16/BFloat16
t_fp16 = t.half()  # NotImplemented
t_bf16 = t.bfloat16()  # NotImplemented

# ❌ Int8 量化
t_int8 = torch.quantize_per_tensor(t, ...)  # NotImplemented
```

### 3. CUDA 加速
```cpp
// ❌ 急需的 CUDA kernels:
- conv2d_forward / backward
- max_pool2d / avg_pool2d
- batch_norm_forward / backward
- relu / gelu / silu (GPU 版本)
- scaled_dot_product_attention
```

### 4. 分布式训练
```python
# ❌ DDP (数据并行)
model = torch.nn.parallel.DistributedDataParallel(model)  # NotImplemented
```

### 5. 内存优化
```python
# ❌ 内存池
torch.cuda.empty_cache()  # 仅部分实现

# ❌ 梯度检查点
@torch.utils.checkpoint.checkpoint
def layer(x): ...  # NotImplemented
```

---

## ⚡ 预期收益

### Phase 1 (3-4个月, 600-800小时)
| 功能 | 工作量 | 收益 |
|------|--------|------|
| Float16/BFloat16 | 100h | **速度 +2-4x** |
| CUDA Conv/Pool/BN | 150h | **速度 +3-5x** |
| 内存池 | 80h | **显存 -30%** |
| 布尔索引 | 50h | API 完整性 +30% |
| DDP 基础 | 150h | 多GPU支持 |

**总收益**: 训练速度提升 **3-5倍**，显存节省 **30-50%**

---

### Phase 2 (4-6个月, 800-1000小时)
| 功能 | 工作量 | 收益 |
|------|--------|------|
| 算子融合 & JIT | 300h | **速度 +1.5-2x** |
| Flash Attention | 60h | **Transformer +2-3x** |
| Int8 量化 | 200h | **推理 +4x** |
| 梯度检查点 | 50h | **显存 -40%** |

**总收益**: 端到端吞吐量 **+1.5-2倍**，显存 **-40%**

---

### Phase 3 (6-8个月, 600-800小时)
| 功能 | 工作量 | 收益 |
|------|--------|------|
| ONNX 导出 | 120h | 生产部署 |
| FSDP | 400h | 大模型训练 (10B+) |
| 量化推理 | 150h | 边缘部署 |

---

## 📋 详细功能清单

### 张量操作缺失 (26项)
- [ ] 布尔索引 (`t[mask]`)
- [ ] 高级索引 (`t[rows, cols]`)
- [ ] Ellipsis 支持 (`t[..., :2]`)
- [ ] `clamp` / `clip`
- [ ] `sign`
- [ ] `cumsum` / `cumprod`
- [ ] `diff`
- [ ] `flip` / `roll`
- [ ] `tile`
- [ ] `multinomial` (采样)
- [ ] `bernoulli` / `poisson` / `exponential`
- [ ] `randperm` / `shuffle`
- [ ] QR / Cholesky 分解
- [ ] `linalg.solve` / `lstsq`
- [ ] `triu` / `tril`
- [ ] `diagonal` / `trace`
- [ ] `cross` (叉积)
- [ ] `outer` (外积)
- [ ] `kron` (克罗内克积)
- [ ] `as_strided` (底层视图)
- [ ] `unfold` / `fold`
- [ ] 稀疏张量基础
- [ ] 复数张量支持
- [ ] FFT / iFFT
- [ ] `chunk` 的 `dim` 参数修复
- [ ] `repeat_interleave`

### 神经网络模块缺失 (18项)
- [ ] `Embedding` 高级功能 (padding_idx, max_norm, sparse)
- [ ] `EmbeddingBag`
- [ ] `Upsample` 多模式插值
- [ ] `grid_sample` (STN)
- [ ] `affine_grid`
- [ ] `PixelShuffle` / `PixelUnshuffle`
- [ ] `ModuleList` / `ModuleDict`
- [ ] `ParameterList` / `ParameterDict`
- [ ] `Sequential` 增强
- [ ] `scaled_dot_product_attention`
- [ ] Flash Attention 集成
- [ ] `CosineSimilarity` / `PairwiseDistance`
- [ ] `Unfold` / `Fold` 模块
- [ ] `Flatten` 模块化
- [ ] `ChannelShuffle`
- [ ] `LocalResponseNorm`
- [ ] `ReflectionPad` / `ReplicationPad`
- [ ] `ZeroPad2d`

### 优化器 & 调度器缺失 (11项)
- [ ] `LAMB` 优化器
- [ ] `LARS` 优化器
- [ ] `Sophia` 优化器
- [ ] `Lookahead` 包装器
- [ ] `LBFGS`
- [ ] `OneCycleLR` ⭐️ 关键
- [ ] `CyclicLR`
- [ ] `CosineAnnealingWarmRestarts`
- [ ] `ChainedScheduler`
- [ ] `SequentialLR`
- [ ] `Noam` Scheduler (Transformer)

### 损失函数缺失 (9项)
- [ ] `FocalLoss` (检测)
- [ ] `CosineEmbeddingLoss`
- [ ] `CenterLoss` (人脸识别)
- [ ] `ArcFaceLoss` / `CosFaceLoss`
- [ ] `DiceLoss` (医学影像)
- [ ] `TverskyLoss` / `LovászLoss`
- [ ] `LabelSmoothingCrossEntropy`
- [ ] `OHEMCrossEntropyLoss`
- [ ] `InfoNCELoss`

### CUDA Kernel 缺失 (20+ 类)
- [ ] `conv2d_forward` / `backward`
- [ ] `conv2d_depthwise`
- [ ] `conv2d_winograd`
- [ ] `max_pool2d_forward` / `backward`
- [ ] `avg_pool2d_forward` / `backward`
- [ ] `adaptive_avg_pool2d`
- [ ] `batch_norm2d_forward` / `backward`
- [ ] `group_norm_forward` / `backward`
- [ ] `relu_forward` / `backward`
- [ ] `gelu_forward` / `backward`
- [ ] `silu_forward` / `backward`
- [ ] `scaled_dot_product_attention`
- [ ] `clamp` / `sign` / `abs` (GPU)
- [ ] `topk` / `sort` (GPU 优化)
- [ ] `reduce_sum_2d` (多轴)
- [ ] `softmax_2d` (跨行/列)
- [ ] `embedding_lookup`
- [ ] `gather` / `scatter` (GPU 加速)
- [ ] `index_select` (GPU)
- [ ] `masked_fill` / `masked_select` (GPU)

### 性能优化功能 (8项)
- [ ] CUDA 内存池
- [ ] 张量视图零拷贝
- [ ] 梯度检查点
- [ ] 惰性执行引擎
- [ ] 算子融合 (JIT)
- [ ] 图优化 (CSE, DCE)
- [ ] 混合精度自动策略
- [ ] 动态损失缩放

### 分布式功能 (6项)
- [ ] DDP (All-Reduce 梯度同步)
- [ ] NCCL / Gloo 后端
- [ ] FSDP (参数分片)
- [ ] Pipeline Parallel
- [ ] RPC 框架
- [ ] Elastic Training

### 部署功能 (5项)
- [ ] ONNX 导出
- [ ] 静态量化
- [ ] 动态量化
- [ ] QAT (量化感知训练)
- [ ] 模型剪枝

### 调试与工具 (7项)
- [ ] `Profiler` (CPU + CUDA)
- [ ] Chrome Trace 导出
- [ ] 内存快照
- [ ] 泄漏检测
- [ ] `autograd.gradcheck`
- [ ] `autograd.detect_anomaly`
- [ ] TensorBoard 集成

---

## 🚀 实施路线图

### 立即开始 (本周)
```bash
# 1. 实现 clamp/sign (极小工作量，高频使用)
# 文件: neurx/python/neurx/core/neurx.py
def clamp(self, min_val=None, max_val=None): ...
def sign(self): ...

# 2. cumsum/cumprod (小工作量，重要功能)
def cumsum(self, dim=0): ...

# 3. 布尔索引开始实现 (分阶段)
def __getitem__(self, key):
    if isinstance(key, Tensor) and key.dtype == bool:
        return self._boolean_indexing(key)
```

### 第1月
- ✅ 基础张量操作补齐 (clamp/sign/cumsum/flip/roll)
- ✅ 布尔索引完整实现
- ✅ Ellipsis 支持
- ⚙️ 开始 Float16 支持 (CPU 端)

### 第2-3月
- ⚙️ Float16/BFloat16 完整实现 (CPU + CUDA)
- ⚙️ CUDA Conv2d kernel
- ⚙️ CUDA Pooling kernels
- ⚙️ CUDA BatchNorm kernel
- ⚙️ 内存池实现

### 第4-6月
- ⚙️ DDP 数据并行
- ⚙️ 算子融合框架
- ⚙️ Flash Attention 集成
- ⚙️ Int8 量化基础

### 第7-12月
- ⚙️ FSDP 参数分片
- ⚙️ ONNX 导出
- ⚙️ Profiler 工具
- ⚙️ 量化推理优化

---

## 📖 相关文档

- **详细分析**: [NEURX_PYTORCH_GAP_ANALYSIS_2026-03-04.md](NEURX_PYTORCH_GAP_ANALYSIS_2026-03-04.md)
- **实现指南**: [OPTIMIZATION_IMPLEMENTATION_GUIDE.md](OPTIMIZATION_IMPLEMENTATION_GUIDE.md)
- **历史分析**: [PYTORCH_GAP_ANALYSIS_2026.md](PYTORCH_GAP_ANALYSIS_2026.md)

---

## 💡 快速建议

### 如果只有1周时间
实现: `clamp`, `sign`, `cumsum`, `flip` (工作量 20-30h，API完整度 +5%)

### 如果有1个月时间
实现: 上述 + 布尔索引 + Float16 CPU (工作量 100-120h，API完整度 +15%)

### 如果有3个月时间
实现: Phase 1 全部 (工作量 600-800h，**速度 +3-5x，显存 -30%**)

### 如果有1年时间
实现: Phase 1-3 全部 (工作量 2000-2500h，**达到 PyTorch 85%+ 能力**)

---

**维护**: neurx 开发团队  
**反馈**: 欢迎提交 issue 或 PR
