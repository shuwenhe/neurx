# QWEN35_PHASE1_ACCEPTANCE

状态：**PASS（文本架构、索引与本地 mmap 一致性范围）**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`591699d0`；Phase 1 验证实现提交：`46444cb8`。本报告由后续 evidence commit 保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_PHASE1_ACCEPTANCE.md` 查询报告提交。

环境：宿主机 RTX 4060 Ti，显存 16380 MiB，快照使用约 1703 MiB；驱动 580.159.03；驱动支持 CUDA 13.0，系统 nvcc 12.0.140；参考 PyTorch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100。普通沙箱不可见 GPU，CUDA 测试在获准宿主机执行。Host RAM 31 GiB，swap 8 GiB，磁盘剩余约 356 GiB。

证据目录：`artifact/build/qwen35_native_20261127/`。未更改生产 decoder、preflight、默认模型、外部编译器或权重；既有两份修改报告和两个未跟踪测试保持原样。本轮不声称 Qwen2.5/DeepSeek 回归通过，因为未重跑其端到端测试。

修改文件：`test/native-construction/qwen35_stage1_probe.cpp`、`test/native-construction/test_qwen35_mapped_payload.py`。新增 verify-mapped 入口，使用 1 MiB 缓冲逐字节比较全部 native mmap 与 bounded pread，检查实际 `/proc/self/maps` 只读权限，并释放已触及映射页。没有生产功能改动。

架构与依赖：嵌套 config → HybridDecoderConfig → ArchitectureRegistry 元数据适配器 → MappedWeightStore；依赖 g++、nlohmann/json、OpenSSL、Linux mmap。runtime_supported 仍 false。40 层配置为 30 linear + 10 full；693 text tensor 完整语义名称/形状/BF16 检查；333 vision、19 MTP 仅分类与结构字节一致性验证，首版文本推理不执行这些张量。

测试命令：

```bash
python3 test/native-construction/test_qwen35_stage1.py
python3 test/native-construction/test_qwen35_mapped_payload.py
```

RED：旧 probe 返回 unknown operation，新增测试失败（该次 unittest 同时发现 11 项既有测试，总计 12 项、1 项失败）；GREEN：新增 1/1，修改后旧回归 11/11。26 shard、1045 tensor、71903645408 payload bytes 全部逐字节一致，误差 0 byte；只读权限通过。缓冲 1048576 bytes；probe 扫描 54659.90 ms，max RSS 1018144 KiB（缓冲量不等于进程 RSS）；包括编译的测试 64.727 s。此测试同时读取两个视图，不能当作推理加载性能。

未解决：没有上游可信 payload digest，不能证明下载内容来源或语义真实性；同一文件的两个读取路径一致不是上游 checksum 验证。BF16 映射字节无损不代表 BF16 CUDA 算术通过。映射不是全模型 GPU 驻留或正式 decoder 加载。本阶段无算术误差/NaN/Inf 数值验收指标，相关项目 N/A。
