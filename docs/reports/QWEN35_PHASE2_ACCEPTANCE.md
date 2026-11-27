# QWEN35_PHASE2_ACCEPTANCE

状态：**BLOCKED**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`591699d0`；Phase 1 验证实现提交：`46444cb8`。本报告由后续 evidence commit 保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_PHASE2_ACCEPTANCE.md` 查询报告提交。

环境：宿主机 RTX 4060 Ti，显存 16380 MiB，快照使用约 1703 MiB；驱动 580.159.03；驱动支持 CUDA 13.0，系统 nvcc 12.0.140；参考 PyTorch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100。普通沙箱不可见 GPU，CUDA 测试在获准宿主机执行。Host RAM 31 GiB，swap 8 GiB，磁盘剩余约 356 GiB。

证据目录：`artifact/build/qwen35_native_20261127/`。未更改生产 decoder、preflight、默认模型、外部编译器或权重；既有两份修改报告和两个未跟踪测试保持原样。本轮不声称 Qwen2.5/DeepSeek 回归通过，因为未重跑其端到端测试。

修改文件：新增 `test/native-construction/test_qwen35_native_bf16_gate.py`，保留明确 RED 状态，不隐藏或 skip。此测试检查 BF16 输出必要条件；即使将来通过，也不足以证明完整 BF16 精度。当前生产代码仍为 FP32。

依赖分析：完整 DeltaNet mixer 投影/conv/L2/gates/recurrent/gated norm/output projection 已有 FP32 实现；输入要求已做 layer norm。完整 decoder 层的 input norm/MoE/residual 尚未组成；BF16 实际算术、各节点误差预算及完整层参考对齐缺失。

执行命令（宿主机）：

```bash
python3 test/native-construction/test_qwen35_stage3.py
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 artifact/reference-env/bin/python test/native-construction/test_qwen35_official_bf16.py
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 artifact/reference-env/bin/python test/native-construction/test_qwen35_native_bf16_gate.py
compute-sanitizer --injection-path /usr/lib/nvidia-cuda-toolkit/compute-sanitizer --tool memcheck --target-processes all artifact/build/qwen35_stage3/probe < artifact/build/qwen35_native_20261127/sanitizer-input.json
# 同一命令将 --tool 替换为 initcheck 复核
```

实际：FP32 CUDA 16/16，43.663 s；官方 BF16 参考 5/5，6.398 s；新增 BF16 gate 1 项 FAIL，4.603 s。fixture seed 781，同一 BF16 舍入输入/权重，5 token × hidden 7。原生 FP32，官方 output/history BF16、state FP32；未执行 FP16。35/35 原生输出不是 BF16 可表示值。Max abs 0.004984676837921143；mean abs 0.001210341469517776；max relative 0.15117818842489253（分母 floor 为 FP32 tiny，1.1754943508222875e-38）；native NaN=0、Inf=0。这些观测不是获准数值容差，未根据结果反推门限。详见 `phase2-bf16-gate.json`。

memcheck/initcheck 均报 Target application terminated before first instrumented API call；内存安全 UNVERIFIED，而非零错误 PASS。存在 sanitizer 程序与注入库，但缺少可有效工作的插桩环境，原因未最终定位，不能断言驱动故障。依赖修复必须限制在 NeurX 目录内或另行获得系统修改授权；本轮未修改系统。

阶段门禁失败，停止后续阶段。未实现本阶段 BF16 功能；下一步先恢复有效 sanitizer 验收能力，制定独立参考误差预算，再对 BF16 路径执行逐节点 RED/GREEN、真实权重与完整层验证。组件测试耗时不是 TTFT/TPOT。
