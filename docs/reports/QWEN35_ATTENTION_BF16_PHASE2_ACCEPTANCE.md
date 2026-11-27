# Native Batch 2–4：BLOCKED

日期：2026-11-27。起始 Git：`a56388ea`；运行期间用户/外部提交 `c43c0577` 保留；本轮参考修正提交：`2bed257e7dd1e9c16e7a8782e3d2732424d41c63`。原始基线/index/diff/untracked 和22项受保护 SHA256 保存在 `artifact/build/qwen35_attention_bf16/reference/baseline.json`，最终逐项复核一致。

修改范围：独立官方参考 Harness、测试、执行计划及本轮报告/证据。未修改 DeltaNet、FP32 Attention、Bridge、Preflight 或其他模型路径。无 Native Attention BF16 Kernel。

环境：宿主机 RTX4060Ti，16380MiB，驱动580.159.03；PyTorch2.6.0+cu124、CUDA12.4、cuDNN90100；nvcc12.0.140、Compute Sanitizer2022.4.1。沙箱 nvidia-smi 退出9，宿主机读取退出0，两个结果均保留于 environment-final.json。

参考测试命令：
```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 \
 artifact/reference-env/bin/python test/native-construction/test_qwen35_attention_official_bf16.py
```
原始证据：`artifact/build/qwen35_attention_bf16/reference/`；最终日志 `phase-a-final-reviewed.log`，退出0，7/7，5.774秒。该时间是测试总耗时，不是 Attention 延迟。节点误差见 `node-summary.json`、各 trace JSON；源码版本/SHA、dtype与舍入合同见 [TOLERANCE](QWEN35_ATTENTION_BF16_TOLERANCE.md)。

官方计算图：BF16 Q/K/V与共享Q/gate投影 → Q/K FP32 RMSNorm并写回BF16 → Partial RoPE逐乘/加BF16边界 → BF16缓存 → BF16 QK出口 → BF16 scale/mask → FP32 softmax → BF16 probability → BF16 AV → BF16 sigmoid/gated AV → BF16 O projection。内部cuBLAS算法精度仍UNVERIFIED。

官方小fixture BF16节点对同操作数FP64诊断差异0；FP32 softmax最大绝对差5.960464477539063e-8。真实head O projection最大绝对差0.25。此诊断不证明Native语义或通用容差。

Native RoPE、score、softmax、AV、O未实施。先完成并审查冻结norm/softmax/组合误差预算，再依照原计划逐批建立失败测试和最小实现；不得跳批。Sanitizer与组件性能UNVERIFIED。
