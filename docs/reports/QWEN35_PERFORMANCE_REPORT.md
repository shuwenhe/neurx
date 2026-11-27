# QWEN35_PERFORMANCE_REPORT

状态：**BLOCKED（仅审计/验证耗时）**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`591699d0`；Phase 1 验证实现提交：`46444cb8`。本报告由后续 evidence commit 保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_PERFORMANCE_REPORT.md` 查询报告提交。

环境：宿主机 RTX 4060 Ti，显存 16380 MiB，快照使用约 1703 MiB；驱动 580.159.03；驱动支持 CUDA 13.0，系统 nvcc 12.0.140；参考 PyTorch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100。普通沙箱不可见 GPU，CUDA 测试在获准宿主机执行。Host RAM 31 GiB，swap 8 GiB，磁盘剩余约 356 GiB。

证据目录：`artifact/build/qwen35_native_20261127/`。未更改生产 decoder、preflight、默认模型、外部编译器或权重；既有两份修改报告和两个未跟踪测试保持原样。本轮不声称 Qwen2.5/DeepSeek 回归通过，因为未重跑其端到端测试。

本轮无性能实现修改，无全模型 benchmark 命令执行。仅测得全量 mmap/pread 一致性扫描 54.6599 s、probe max RSS 1018144 KiB，单次运行，缓存状态未控制，不分冷/热基线；不可替代模型加载时间。扫描使用约 1MiB 显式缓冲，但实际 RSS 包含文件映射页。

模型加载耗时/权重加载峰值内存/正式显存峰值/prefill TTFT/decode TPOT/tokens/s/32 token E2E/CPU-GPU transfer/expert paging 开销全部 UNVERIFIED。冷启动、预热、稳定运行全部未测，不能以组件测试时间或 GPU 空闲快照填充。全模型数值误差与执行 dtype 未验收。
