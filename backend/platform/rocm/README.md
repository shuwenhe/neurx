# NeurX ROCm Backend Implementation

ROCm (AMD GPU) 后端实现，基于 vLLM 和 SGLang 的架构设计，用 S 语言实现。

## 目录结构

```
rocm/
├── device_manager_rocm.s          # 设备管理与初始化
├── rocm_runtime.s                 # ROCm 运行时绑定
├── attention_rocm.s               # 注意力机制实现
├── rocm_kernels.s                 # 基础计算核（激活、规范化等）
├── moe_kernels_rdna.s             # 混合专家专家（RDNA 优化）
├── inference_server_rocm.s        # 推理引擎
├── memory_manager_rocm.s          # 内存管理
├── rccl_integration.s             # RCCL 分布式通信
├── CMakeLists.txt                 # 构建配置
├── Makefile.rocm                  # Make 构建脚本
└── README.md                       # 本文件
```

## 支持的功能

### 1. 设备管理
- GCN 架构识别 (RDNA, RDNA2, RDNA3, CDNA)
- 设备内存查询
- 多设备支持
- 设备同步

### 2. 运行时
- HIP 内存管理 (malloc, free, memcpy)
- rocBLAS 集成 (SGEMM, DGEMM, HGEMM)
- MIOpen 支持
- 流和事件管理

### 3. 注意力机制
- Flash Attention v2 (RDNA 优化)
- 分页注意力
- Multi-Query Attention (MQA)
- Grouped-Query Attention (GQA)
- ALiBi 支持
- RoPE (Rotary Position Embedding)

### 4. 计算核
- 激活函数：GELU, ReLU, SiLU
- 规范化：LayerNorm, RMSNorm
- 采样：Top-k, Top-p
- Embedding
- 交叉熵损失

### 5. 混合专家 (MoE)
- RDNA 专用优化
- 负载平衡损失计算
- 辅助损失
- 量化 MoE 支持

### 6. 推理引擎
- 预填充 (Prefill) 阶段
- 解码 (Decode) 阶段
- Batch 推理
- KV 缓存管理
- 性能估计

### 7. 分布式
- RCCL 集成
- AllReduce, AllGather, ReduceScatter
- 点对点通信
- 支持多卡协作

## 与 CUDA 的兼容性

### 相同点
- API 设计风格
- 内存管理模式
- 核函数接口

### 差异点
| 特性 | CUDA | ROCm |
|------|------|------|
| 编译器 | nvcc | hipcc |
| 库 | cuBLAS | rocBLAS |
| 库 | cuDNN | MIOpen |
| 通信 | NCCL | RCCL |
| 内存 API | cuda* | hip* |

## GCN 架构支持

NeurX ROCm 支持多代 AMD GPU：

### CDNA 系列 (数据中心)
- MI300, MI300X (gfx942)
- MI310, MI325X (gfx942, gfx941)

### RDNA 系列 (消费级/工作站)
- RDNA 3: RX 7900 XTX, RX 9000 系列 (gfx1100)
- RDNA 3.5: Strix Point, Strix Halo (gfx1150, gfx1151)
- RDNA 4: RX 9070 XT (gfx1201)

## 使用示例

### 创建 ROCm 引擎

```s
import "neurx.rocm.inference_server" as rocm_server

config = rocm_server.rocm_model_config {
    model_name: "llama2-7b",
    hidden_dim: 4096,
    num_layers: 32,
    num_heads: 32,
    num_kv_heads: 8,
    intermediate_size: 11008,
    max_seq_length: 4096,
    dtype: "float16",
    use_flash_attention: true,
    attention_backend: "rocm_flash_v2"
}

engine = rocm_server.create_rocm_engine(config, device_id: 0)
```

### 前向推理

```s
import "neurx.rocm.runtime" as rocm_rt

input_ids = rocm_rt.rocm_malloc(seq_len * 4)
hidden_states = rocm_server.rocm_prefill_forward(engine, input_ids, seq_len)
logits = rocm_server.rocm_generate_token(engine, hidden_states, top_k: 50, top_p: 0.9, temperature: 0.8)
```

## 构建

### 前置条件
- ROCm 5.7+
- rocBLAS
- MIOpen
- RCCL (分布式)

### 编译

```bash
cd backend/rocm
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel $(nproc)
cmake --install build
```

### Make 构建

```bash
cd backend/rocm
make -f Makefile.rocm all
make -f Makefile.rocm test
```

## 性能优化

### 1. 架构特定优化
- RDNA 3 专用 GEMM 核 (moe_kernels_rdna.s)
- 矢量缓存优化
- LDS (本地数据共享) 管理

### 2. 内存优化
- 页对齐缓冲
- 压缩 KV 缓存
- 固定内存支持

### 3. 通信优化
- RCCL 环形拓扑
- 点对点传输
- 异步 AllReduce

## 与 vLLM/SGLang 的对比

| 功能 | vLLM | SGLang | NeurX |
|------|------|--------|-------|
| ROCm 支持 | ✅ (C++) | ✅ (Python) | ✅ (S语言) |
| Flash Attention | ✅ | ✅ | ✅ |
| MoE | ✅ | ✅ | ✅ |
| 分布式 | ✅ RCCL | ✅ RCCL | ✅ RCCL |
| RDNA 优化 | ✅ | ⚠️ 基础 | ✅ 专用 |
| 编译优化 | ⚠️ 运行时 | ⚠️ 运行时 | ✅ 编译时 |

## 测试

```bash
cd backend/rocm/tests
rocm-smi  # 验证 ROCm 安装
./test_rocm_kernels
./test_attention_rocm
./test_moe_kernels
./test_distributed
```

## 已知限制

1. 某些 FP8 操作需要 CDNA2+
2. MIOpen 某些版本对 fp16 有限制
3. RDNA 消费级 GPU 上某些功能性能不理想

## 未来改进

- [ ] Triton on ROCm 集成
- [ ] 动态量化支持
- [ ] 更多 GCN 架构优化
- [ ] 性能分析工具
- [ ] 更多融合核

## 许可证

遵循 NeurX 主项目许可证

## 参考资料

- [vLLM ROCm 实现](https://github.com/vllm-project/vllm/tree/main/vllm/platforms)
- [SGLang ROCm 集成](https://github.com/hiyouga/SGLang/tree/main/python/sglang/srt/platforms)
- [HIP 文档](https://rocmdocs.amd.com/en/docs-6.0.0/deploy/linux/index.html)
- [rocBLAS 文档](https://rocmblas.readthedocs.io/)
- [RCCL 文档](https://rocmdocs.amd.com/en/docs-5.4.0/deploy/linux/user_guide/using_rccl/index.html)
