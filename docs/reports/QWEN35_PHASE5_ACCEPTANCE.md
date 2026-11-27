# QWEN35_PHASE5_ACCEPTANCE

状态：**BLOCKED（完整 decoder MISSING）**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`591699d0`；Phase 1 验证实现提交：`46444cb8`。本报告由后续 evidence commit 保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_PHASE5_ACCEPTANCE.md` 查询报告提交。

环境：宿主机 RTX 4060 Ti，显存 16380 MiB，快照使用约 1703 MiB；驱动 580.159.03；驱动支持 CUDA 13.0，系统 nvcc 12.0.140；参考 PyTorch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100。普通沙箱不可见 GPU，CUDA 测试在获准宿主机执行。Host RAM 31 GiB，swap 8 GiB，磁盘剩余约 356 GiB。

证据目录：`artifact/build/qwen35_native_20261127/`。未更改生产 decoder、preflight、默认模型、外部编译器或权重；既有两份修改报告和两个未跟踪测试保持原样。本轮不声称 Qwen2.5/DeepSeek 回归通过，因为未重跑其端到端测试。

本轮无修改、无本阶段测试命令执行。配置已确认 30 linear + 10 full，但完整 40 层 norm/mixer/MoE/residual、embedding/lm_head 与生产 bridge 尚未集成和验收。逐层 BF16、prefill、decode、状态维护均 UNVERIFIED。runtime_supported 保持 false。数值误差/NaN/Inf/dtype/性能均 UNVERIFIED。依赖前序门禁，未进入开发。
