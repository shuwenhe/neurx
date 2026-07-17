# NeurX 异构大模型推理框架

该框架将请求生命周期拆为独立的 **Prefill** 与 **Decode** 阶段。调度器只生成同构批次，CUDA 与 Ascend 请求不会混入同一个 kernel launch；设备适配器负责将批次映射到 CUDA/cuBLAS/FlashAttention/NCCL 或 CANN/ACL/FlashAttention/HCCL。

```
HTTP/gRPC request
       │
admission + prefix/KV cache
       │
DisaggregatedScheduler
   ┌───┴────────────┐
Prefill lane      Decode lane (priority)
large-token batch  continuous 1-token batch
   │                    │
CUDA / Ascend adapters ─ KV block handoff ─ sampler/stream
```

## 性能策略

- **算子优化**：RMSNorm + QKV 融合、Flash/Paged Attention、RoPE 融合、logits + sampling 融合；CUDA 优先 FP8（支持时），Ascend 使用 BF16。
- **通信优化**：张量并行以 NCCL（CUDA）或 HCCL（Ascend）all-reduce 为默认；Prefill 与 Decode 分离部署时，以页式 KV block 经同机 P2P 或 RDMA 交接，避免重算 prompt。
- **调度优化**：Decode 优先保障 TTFT 后的每 token 延迟；Prefill 以 token budget 分块，避免长上下文阻塞短请求；batch key 固定为 `(backend, dtype)`，保证 graph capture 与 kernel 形状稳定。
- **分布式推理**：每个 replica 独立维护连续批；路由层按 KV-cache 命中、队列 token 深度、后端能力选择 replica。跨节点仅传递请求元数据和 KV block，不传模型权重。

## 当前可执行控制面

`inference/runtime/inference_runtime.h` 是无硬件依赖的调度核心，提供 CUDA/Ascend 能力表、算子执行计划、同构动态批处理、Prefill 分块与 Decode 优先级。运行：

```bash
make inference-runtime-test
```

设备适配器必须在完成一个批次后调用 `complete_prefill()` 或 `complete_decode()`；这使生命周期和调度状态可审计，并防止同一请求被重复发射。

## 接入边界

CUDA 适配器应复用 `cuda/transformer_kernels.cuh` 和 NCCL；Ascend 适配器应通过 ACL/CANN graph、FlashAttention 与 HCCL 实现相同的批次契约。真实设备内核、KV pool 分配和 RPC/HTTP transport 不在控制面内，必须在对应后端运行时实现并做端到端压测。

设备代码目录：CUDA kernel 和适配器位于 `cuda/` 与 `inference/runtime/backends/`，Ascend 适配器、kernel、算子封装、ACL runtime 与 HCCL 位于 `cann/`，NCCL 位于 `distributed/nccl/`。
