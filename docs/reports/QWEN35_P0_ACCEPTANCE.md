# Qwen3.6 P0 验收

最终状态：**PASS（本次 P0 测试范围）**。完整 Phase 2 与 Qwen3.6 全模型仍 **BLOCKED**，本报告不授权进入后续阶段。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`cba0f5a3`；实现 Git Commit：`9e8dd875`。本报告与原始证据由后续文档提交保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_P0_ACCEPTANCE.md` 查询。

环境：RTX 4060 Ti，16380 MiB VRAM，驱动 580.159.03；nvcc 12.0.140；Compute Sanitizer 2022.4.1。CUDA runtime API 12000、driver API 13000，设备数 1，三个 API 均返回 0。官方参考 torch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100；TF32/autocast/compile 关闭。真实 GPU 测试在宿主机执行，普通沙箱仍隔离 GPU。版本与硬件日志位于 `artifact/build/qwen35_p0_20261127/`。

## 修改文件与范围

- backend/platform/cuda/hybrid_deltanet_bf16.h、hybrid_deltanet_bf16.cu：真实 BF16 存储、FP32 accumulate/state 的独立原生路径。
- scripts/run_cuda_sanitizer.py：修复本地 injection/helper 布局，不修改系统。
- test/native-construction/cuda_sanitizer_minimal.cu、test_cuda_sanitizer_p0.py：实际 GPU 正负对照。
- test/native-construction/qwen35_p0_bf16_probe.cu、test_qwen35_p0_bf16.py：原生三路控制、15节点、prefill/decode/reset/拒绝恢复验收。
- test/native-construction/qwen35_official_reference.py：添加可选观察层，官方固定哈希函数体保持不变。
- test/native-construction/test_qwen35_native_bf16_gate.py：原输出契约现在调用新 BF16 session，保留相同必要条件，不把旧 FP32 转换结果冒充新实现。旧失败证据未覆盖。

起始两份已修改历史报告及两个未跟踪 rounding 测试保持原样；旧 FP32 DeltaNet、Full Attention、preflight、架构门禁、正式推理 bridge 与外部 S 编译器未修改。没有 MoE/完整 Decoder/E2E 集成。

## 最终真实测试

| 测试 | 实际结果 | 日志 |
|---|---|---|
| 原 Phase1 test_qwen35_stage1.py | 11/11，10.102s | phase1.log |
| DeltaNet FP32 test_qwen35_stage3.py | 16/16，41.841s | deltanet-fp32.log |
| Full Attention FP32 test_qwen35_stage2.py | 11/11，26.571s | attention-fp32.log |
| 固定官方 BF16 参考 | 5/5，3.331s | official-bf16.log |
| 新 BF16 stage/lifecycle/prefill/reset | 5/5，13.969s | bf16-final.log |
| 原 35输出 BF16 必要条件 | 1/1；0/35 违规，output误差0 | bf16-output-gate.log、phase2-bf16-gate.json |
| sanitizer clean + 故障负对照 | 4/4，3.616s | sanitizer-controls-final.log |
| FP32 DeltaNet memcheck/initcheck | 两项有效0错误 | deltanet-*-fp32.log |
| BF16 DeltaNet memcheck/initcheck | 两项有效0错误 | bf16-memcheck.log、bf16-initcheck.log |

所有日志/数组/逐 token 指标位于 artifact/build/qwen35_p0_20261127。final-commands.json 与 regression-commands.json 记录命令与退出码；BF16 与 sanitizer 测试脚本会重建各自 probe。命令见两份根因报告，GPU 环境不可用时应失败并标 BLOCKED，不能使用 CPU 模拟。

三 seed 与 65 token wider fixture 的 output max abs/mean abs/max relative = 0/0/0，NaN/Inf=0；三 seed state max abs7.45058e-9，65 token最终state max abs5.81145e-7。BF16边界精确比较，FP32 state保留既有官方混合容差，未放宽。完整逐节点指标见根因报告和JSON。没有进行性能优化或吞吐验收，测试耗时不能用作模型TTFT/TPOT。

## 独立审查和结论边界

按 requesting-code-review 技能派发可读本地源码的独立只读审查；审查者确认工具可用并实际读取源码。未发现阻断性实现问题，指出的宽维度覆盖、sanitizer负对照和probe异常清理均已补充；复审无新增具体阻断项。生命周期测试随后真实执行通过。审查原文摘要保存 independent-review.md，不将执行者检查冒充独立审查。

本次修复证明旧35/35故障可由真实内部BF16路径关闭，并恢复指定程序的有效sanitizer。仍未验证真实checkpoint各层/真实hidden state、2048/8192 BF16连续decode、所有输入分布、多GPU、完整层Norm/MoE/Residual及独立冻结的逐模块/长度误差预算；这不满足完整Phase2验收。新BF16路径未接生产decoder，正式Qwen3.6推理仍不可用。旧Qwen2.5/DeepSeek端到端回归本轮未执行，不能声称通过。原模型注册与preflight继续拒绝。

源代码/测试/报告的 whitespace 检查与 Python 语法检查通过。原始 sanitizer 故障日志含三处工具输出行尾空格，完整 diff --check 会报告这些原始日志；为保持原始证据未清理。未将该输出描述为整体 diff --check 通过。
