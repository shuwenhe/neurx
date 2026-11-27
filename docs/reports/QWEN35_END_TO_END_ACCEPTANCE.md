# QWEN35_END_TO_END_ACCEPTANCE

状态：**BLOCKED**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`591699d0`；Phase 1 验证实现提交：`46444cb8`。本报告由后续 evidence commit 保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_END_TO_END_ACCEPTANCE.md` 查询报告提交。

环境：宿主机 RTX 4060 Ti，显存 16380 MiB，快照使用约 1703 MiB；驱动 580.159.03；驱动支持 CUDA 13.0，系统 nvcc 12.0.140；参考 PyTorch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100。普通沙箱不可见 GPU，CUDA 测试在获准宿主机执行。Host RAM 31 GiB，swap 8 GiB，磁盘剩余约 356 GiB。

证据目录：`artifact/build/qwen35_native_20261127/`。未更改生产 decoder、preflight、默认模型、外部编译器或权重；既有两份修改报告和两个未跟踪测试保持原样。本轮不声称 Qwen2.5/DeepSeek 回归通过，因为未重跑其端到端测试。

本轮未执行正式 make inference；先执行 `python3 scripts/check_inference_model.py /home/shuwen/shuwen/model/Qwen3.6-35B-A3B --json`，26 个分片存在，唯一报告错误为 native qwen3_5_moe decoder 未实现。详见 preflight.json。未绕过门禁。

配置/本地映射通过不等于完整加载执行；40 层 forward、32 token 真实生成、多轮 chat、KV/state 正确性、Qwen2.5 与 DeepSeek E2E 回归均 UNVERIFIED。所有 E2E 数值误差、NaN/Inf、实际 dtype 与性能数据缺失。文本模型尚未可用；图像、视频输入明确未实现/未验收。Phase 2 失败后停止，不宣布完成。
