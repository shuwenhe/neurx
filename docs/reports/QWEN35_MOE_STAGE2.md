# Qwen3.5 MoE Stage 2：Gated Full Attention / Partial RoPE / KV Cache

2026-11-26；branch `feat/qwen35-native`；阶段基线 `b5f2c713`。

**状态：阶段2 FP32正确性基线通过（11项GPU测试、31项旧路径回归）；CUDA sanitizer未获得有效运行结果。未完成Decoder，Preflight仍拒绝目标模型。**

本阶段遵循已批准设计的section 5和实际计划Task4。未修改Makefile、Preflight、生产S服务/bridge、外部S源码、模型权重，也未安装依赖；四份既有设计改动保留。

## 实现与接口

- `backend/platform/cuda/hybrid_attention_cuda.h/.cu`：独立 `AttentionConfig`、row-major FP32 `AttentionWeights`、不可复制的 `FullAttentionSession`。构造时持有自身权重、固定容量KV及workspace，析构释放；输入为host `[T,H]`，输出 `[T,H]`。`forward(input, position, trace)`只允许连续位置且T不超过chunk/context容量；单session互斥，GPU device归属检查；同步调用默认stream，执行device-wide synchronize。`reset()`将逻辑长度归零，旧cache通过长度不可见；执行/数值失败标invalid直至reset。参数/容量错误在launch前拒绝，保留已提交状态。
- `backend/platform/cuda/gated_attention_kernels.cuh`：FP32 q/gate、k/v及o投影；每head拆分q/gate；q/k offset RMS `(1+w)`；只旋转前rotary维half-split；16/2 GQA、causal、稳定softmax、sigmoid门。真实维度query4096、qg8192、KV512、head256、rotary64。权重 `[out,in]`，cache `[context,kv_heads,head_dim]`，q/gate/attention `[T,query_heads,head_dim]`。
- 注意力基线每output feature重复计算score归约，workspace不随context平方增长，无动态shared scores；这是小上下文正确性基线，计算量大，不承诺模型吞吐。阶段7再优化，改变归约顺序须重新验收。
- `test/native-construction/qwen35_stage2_probe.cu`、`test_qwen35_stage2.py`：独立Python/NumPy FP64与FP32参考，显式固定每个projection/dot/RMS/softmax归约顺序。未调用生产CUDA实现作为oracle。probe可通过阶段1loader读取真实BF16单层权重，Python通过独立index/header/seek/read解码同一权重作参考。

本接口是attention模块，不是架构registry执行标志或完整混合Decoder。权重由调用方显式BF16→FP32；当前没有BF16算术路径、官方fallback舍入兼容性结论、Residual/MoE/完整层执行，也不接生产S ABI。未来阶段6须在Decoder编排中避免host中转，并做对应数值回归。

## 内存准入

每次cudaMalloc前检查显式session budget、cudaMemGetInfo实际free与独立headroom；不满足则拒绝，不能无限缓存。权重、KV、输入、qg、q、gate、k/v、attention、输出全部计入session字节；中途构造异常由RAII释放已分配对象。乘法溢出和int kernel索引范围提前验证。

令Q=query_heads*head_dim、K=kv_heads*head_dim、H=hidden、C=max_chunk、L=context、D=head_dim，显式分配字节为：

```
4 * [ H*(3Q+2K) + 2D + 2LK + C*(2H+5Q+2K) ]
```

测试独立计算并要求allocated_bytes精确一致。正常测试budget64MiB，真实权重测试budget256MiB，headroom256MiB。真实第3层context8/chunk4显式分配109,496,320 bytes；cudaMemGetInfo free差111,149,056 bytes，包含allocator粒度/运行时影响，不能用显式tensor字节冒充实测占用。完整CPU测试驱动峰值RSS287,544KiB；不是整模型内存、TTFT或TPS。全模型 admission/cache/controller仍属于阶段5，不能推导35B可完整驻留16GB。

## RED/GREEN与精度证据

- 初始RED：阶段2头文件/API不存在导致probe编译失败，日志`artifact/build/qwen35_stage2/red.log`。
- 编译适配：CUDA12.0与系统FORTIFY3头不兼容；沿用项目既有 `-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0`，不安装依赖。沙箱运行报无CUDA设备，实际GPU测试通过授权的宿主机执行。
- 初次GPU测试6项通过、1项失败：测试设context5却保留chunk8，正确触发配置拒绝。修正fixture为chunk5，不放宽生产校验。
- 配置边界RED：theta1e300、epsilon1e-300在double合法但转float成为Inf/0；补充分配前FP32可表示性校验后GREEN。`config-red.log`记录两个负例。
- 最终11项：tiny prefill、真实16/2头256/64维度、独立保留seed、64次连续decode/context容量2048、prefill/chunk/decode等价、causal不受未来token影响、全零/极端gate、shape/容量/position/预算/headroom拒绝、非有限计算使session invalid直到reset，以及真实单层权重对齐。
- 真实权重来自模型第一处Full Attention（0-based layer3）：q_proj/k_proj/v_proj/o_proj/q_norm/k_norm。执行2-token prefill及1-token decode，输入为合成FP32，不是完整模型hidden state或生成结果。

冻结的本测试分布门限：maxabs≤2e-5、relative-L2≤1e-5，分别用于M32/M64和CUDA/M32；zero参考时relative-L2分母退化为absolute L2。先测seed521，再以seed1807和真实权重测试复验，未放宽门限。RMSE同时记录。数学参考和CUDA都是显式FP32/64计算，**不把这些容差用于官方BF16执行或最终logits**。

| 指标 | 实测最大值 |
|---|---:|
| CUDA vs M32 maxabs | 2.861022949e-6 |
| M32 vs M64 maxabs | 9.497964290e-6 |
| CUDA vs M64 maxabs | 9.497964290e-6 |
| CUDA vs M32 relative L2 | 5.424536786e-7 |
| M32 vs M64 relative L2 | 1.517877658e-6 |
| CUDA vs M32 RMSE | 1.020051786e-6 |
| M32 vs M64 RMSE | 1.854602005e-6 |

395个call/tensor比较记录见`artifact/build/qwen35_stage2/numerics.json`；逐case最大值、source SHA256和memory记录见[机器报告](QWEN35_MOE_STAGE2.json)。构建约定 `--fmad=false`，禁用fast-math/TF32；修改这些条件须重新标定，不能沿用本报告。

实际命令（须在可访问GPU的环境）：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 test/native-construction/test_qwen35_stage2.py
```

脚本自动nvcc构建；`QWEN35_STAGE2_PROBE`可明确指定已构建probe。最后一次测试复用同源二进制：**Ran 11 tests in 6.446s / OK / exit0**，含time统计的完整日志为`artifact/build/qwen35_stage2/gpu-timed.log`。阶段1专项11项再次通过，日志`stage1-regression.log`。

## 审阅、限制与未通过检查

独立只读审阅：无Critical；Important的double→float参数问题已RED→GREEN。参考归约顺序、build flags、返回call长度检查已明确。仍未验证：多session隔离/device切换执行、失败构造后的GPU内存恢复测量、完整2048-position计算（目前执行64个位置，不仅分配2048容量）。这些是证据缺口，不描述为通过。

CUDA memcheck/initcheck **UNVERIFIED**：初始找不到注入库exit13；指定现有`/usr/lib/nvidia-cuda-toolkit/compute-sanitizer`后，工具在首次有效插桩前退出255；`--target-processes all`也未解决。没有获得有效“0 errors”报告，不以数值测试代替内存sanitizer。日志`memcheck.log`、`initcheck.log`、`memcheck-all.log`。未重装驱动、未安装工具。

官方固定BF16 fallback逐舍入对齐、完整hybrid层trace/logits/argmax、DeltaNet递归状态、MoE、INT4、真实32-token生成、全模型16GB显存预算和性能均未执行。`make inference`仍按原Preflight拒绝；不能将本阶段算子通过当成模型运行完成。

## 最终回归

`make native-stage4-test S_NATIVE_COMPILER="$PWD/artifact/build/qwen35_stage1/seed-toolchain/compiler"`：**31 tests in 460.193s / OK / exit0**，日志`artifact/build/qwen35_stage2/native-stage4.log`。本阶段文件独立编译，不替换旧Dense/Qwen/DeepSeek路径。阶段3尚未开始；后续仍须通过各阶段数值与资源门禁。

Preflight4项、startup5项复跑通过；`git diff --check`通过。全部阶段2新增修改限定NeurX；未推送/未合并。
