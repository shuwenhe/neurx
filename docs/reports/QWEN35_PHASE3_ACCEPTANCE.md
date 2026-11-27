# QWEN35_PHASE3_ACCEPTANCE

状态：**PARTIAL；后续开发 BLOCKED**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`591699d0`；Phase 1 验证实现提交：`46444cb8`。本报告由后续 evidence commit 保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_PHASE3_ACCEPTANCE.md` 查询报告提交。

环境：宿主机 RTX 4060 Ti，显存 16380 MiB，快照使用约 1703 MiB；驱动 580.159.03；驱动支持 CUDA 13.0，系统 nvcc 12.0.140；参考 PyTorch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100。普通沙箱不可见 GPU，CUDA 测试在获准宿主机执行。Host RAM 31 GiB，swap 8 GiB，磁盘剩余约 356 GiB。

证据目录：`artifact/build/qwen35_native_20261127/`。未更改生产 decoder、preflight、默认模型、外部编译器或权重；既有两份修改报告和两个未跟踪测试保持原样。本轮不声称 Qwen2.5/DeepSeek 回归通过，因为未重跑其端到端测试。

本轮无生产修改。只读审计和已有回归诊断：`python3 test/native-construction/test_qwen35_stage2.py`，真实 GPU 11/11，25.628 s；日志 attention-fp32.log。Q/K/V、gate、partial RoPE、KV、prefill/decode 有 FP32 独立 session。尚未完成 BF16 执行、完整 decoder 层及 PyTorch BF16 数值对齐；不得将独立测试算作 Phase 3 通过。数值误差/性能本报告不另行声称，原测试指标仍在 qwen35_stage2 目录；全模型指标 UNVERIFIED。Phase 2 门禁失败，未进入此阶段开发。
