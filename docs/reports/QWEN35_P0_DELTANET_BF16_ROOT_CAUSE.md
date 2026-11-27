# DeltaNet BF16 根因与修复

状态：**PASS（本次 P0 有限测试范围）**；不构成完整 Phase 2 / 真实模型 BF16 验收。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`cba0f5a3`；实现 Git Commit：`9e8dd875`。本报告与原始证据由后续文档提交保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_P0_DELTANET_BF16_ROOT_CAUSE.md` 查询。

环境：RTX 4060 Ti，16380 MiB VRAM，驱动 580.159.03；nvcc 12.0.140；Compute Sanitizer 2022.4.1。CUDA runtime API 12000、driver API 13000，设备数 1，三个 API 均返回 0。官方参考 torch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100；TF32/autocast/compile 关闭。真实 GPU 测试在宿主机执行，普通沙箱仍隔离 GPU。版本与硬件日志位于 `artifact/build/qwen35_p0_20261127/`。

## 只读审计与根因

旧 DeltaNet 的 `DeltaWeights`、GPU 输入/权重/临时张量/history/output 均是 float；投影、卷积、L2、norm 与 recurrence 都是 FP32，state 也是 FP32。BF16 checkpoint 只在载入时展开为 FP32。prefill 在一次 forward 内逐 token 调用相同 recurrence，decode 是一次调用一个 token；此前没有 BF16 执行模式。原 35/35 失败的直接原因是测试把 FP32 baseline 当作 BF16；同时存在内部计算/存储舍入边界缺失，不是仅输出容器类型的问题。

官方固定 SHA256 源码 AST 保持原函数体执行；新增 dispatch/hooks 只抓取中间值，不替换数学运算。观测涵盖 qkv/z/a/b、conv、SiLU activated、L2 q/k、beta/decay、core、gated norm、output、state、history 共 15 个节点。首次 prefill 会把 history padding 后传入 conv，观测层按真实 token 范围裁剪；最初两次采集因 dispatch 名称及 padding 范围错误而失败，修正观测后重新测试，失败日志保留，不当作 kernel 数值通过。

## 最早分歧与三路对照

相同 BF16 舍入输入与权重，seed781，第一个 token 的原生 FP32 qkv 对官方 BF16 qkv：max abs **0.0018458366394042969**、mean abs **0.0004931901182447161**、max relative **0.0030571039575729925**。分歧已在首个 QKV 投影出口出现，早于卷积、state 更新或最终输出。输入字节及权重取值相同，区别在投影输出的 BF16 边界。

seed781 全部 35 个输出：

| 路径 vs 官方 | max abs | mean abs | max relative |
|---|---:|---:|---:|
| 旧 FP32 native | 0.004984676837921143 | 0.001210341469517776 | 0.15117818842489253 |
| 仅将旧输出转 BF16（诊断负对照） | 0.0048828125 | 0.0011387416294642858 | 0.15343915343915343 |
| 新 BF16 operands/storage + FP32 accum/state | 0 | 0 | 0 |

转换输出仍有误差，不能替代内部 BF16 路径。逐 token、逐节点数据见 `per-token-metrics.json` 与 native/official-seed*.json，三 seed 聚合见 bf16-stage-metrics.json。相对误差分母为 max(abs(reference), FP32 tiny)，不将近零处相对误差单独用作通过门限。

## 原生实现

新增 `backend/platform/cuda/hybrid_deltanet_bf16.h/.cu`，独立 `DeltaNetBF16Session`，保留原 FP32 源码与 API。host float vector 仅是传输接口；GPU 使用真正 __nv_bfloat16 的权重、input、projection、conv pre/SiLU、q/k、beta、core、gated output、final output 及 history。FP32 累加与 state 不转 BF16；FP16 未使用。

| 阶段 | GPU 存储与算术边界 |
|---|---|
| Input/weights | host 转换 RNE 后传输 BF16，检查非有限/溢出 |
| Projections | BF16 operands，float sum，BF16 出口 |
| Conv/SiLU | BF16 history 与权重，float sum；conv 先 BF16，再 SiLU BF16 |
| Q/K L2 | 平方 BF16，float reduction→BF16，epsilon/rsqrt/multiply 各 BF16；query scaling 在 recurrent 内 FP32 |
| Gates | beta BF16；A_log/a/dt 转 FP32计算 decay |
| Recurrent | FP32 state/prediction/delta/update/reduction；core 出口 BF16 |
| Gated norm | core 转 FP32 norm，归一化 BF16、乘权重 BF16、FP32 SiLU gate、结果 BF16 |
| Output | BF16 operands + float sum → BF16 |

原生内部累加类型可从 native kernel 的 float accumulator 及 --fmad=false 编译确认；官方 cuBLAS/cuDNN 内部累加细节仍不能仅凭 tensor dispatch 证明，保持 UNVERIFIED，不声称内部实现逐指令相同。新路径是逐 token recurrent prefill 的正确性基线，不是优化 chunk kernel。

## 测试与限制

RED：新增测试首先因 native BF16 probe 缺失而失败；原 35/35 RED 证据仍在上次目录。GREEN：新增 5/5（13.969s）：三 seed 5 token、非零 state/history、prefill/decode 精确一致与 reset、65 token h32/kd8/vd8 的官方 chunk 对照、9 项拒绝/恢复检查。

三 seed BF16 节点精确相等；output max/mean/relative 全为 0、NaN/Inf=0。FP32 state 最大 abs 7.450580596923828e-9，mean abs 最坏 2.8206462350984414e-10，max relative 最坏 3.289316792455623e-6；decay max abs 5.960464477539063e-8。65-token output 精确相等；最终 state max abs 5.811452865600586e-7、mean abs 1.9930439520976506e-8、max relative 0.0007337390478656826，NaN/Inf=0。

容差未放宽：所有 BF16 节点用 array_equal；FP32 state/decay 使用既有官方 prefill/recurrent 的 rtol=1e-4、atol=2e-5，判断为 abs(error) <= atol + rtol*abs(reference)，近零处不要求 max relative 小于 rtol。该容差不是根据新 CUDA 误差反推的新预算；完整模型的模块/长度预算仍未冻结。

执行命令（需真实 GPU）：

```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 artifact/reference-env/bin/python test/native-construction/test_qwen35_p0_bf16.py
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 artifact/reference-env/bin/python test/native-construction/test_qwen35_native_bf16_gate.py
```

测试自动用 nvcc -O2 -lineinfo --fmad=false -arch=sm_89 重建 probe；无 fast-math。未对真实 checkpoint 多层、真实模型 hidden state、2048/8192 BF16 continuation 作验收，未集成完整 norm/MoE/residual decoder 层。trace 有 64MiB admission、预算/headroom、异常 invalidation/reset，单 GPU验证不代表多 GPU owner 验证。不得据此放行完整 Phase 2 或后续阶段。
