# KV Cache：PARTIAL（仅官方参考）

日期：2026-11-27。起始 Git：`a56388ea`；运行期间用户/外部提交 `c43c0577` 保留；本轮参考修正提交：`2bed257e7dd1e9c16e7a8782e3d2732424d41c63`。原始基线/index/diff/untracked 和22项受保护 SHA256 保存在 `artifact/build/qwen35_attention_bf16/reference/baseline.json`，最终逐项复核一致。

修改范围：独立官方参考 Harness、测试、执行计划及本轮报告/证据。未修改 DeltaNet、FP32 Attention、Bridge、Preflight 或其他模型路径。无 Native Attention BF16 Kernel。

环境：宿主机 RTX4060Ti，16380MiB，驱动580.159.03；PyTorch2.6.0+cu124、CUDA12.4、cuDNN90100；nvcc12.0.140、Compute Sanitizer2022.4.1。沙箱 nvidia-smi 退出9，宿主机读取退出0，两个结果均保留于 environment-final.json。

参考测试命令：
```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 \
 artifact/reference-env/bin/python test/native-construction/test_qwen35_attention_official_bf16.py
```
原始证据：`artifact/build/qwen35_attention_bf16/reference/`；最终日志 `phase-a-final-reviewed.log`，退出0，7/7，5.774秒。该时间是测试总耗时，不是 Attention 延迟。节点误差见 `node-summary.json`、各 trace JSON；源码版本/SHA、dtype与舍入合同见 [TOLERANCE](QWEN35_ATTENTION_BF16_TOLERANCE.md)。

官方DynamicLayer/Cache的BF16 K/V观察覆盖prefill、逐token decode、chunks，初始position=7，缓存长度按[5]、[1,2,3,4,5]、[2,4,5]检查。观察开关结果/cache逐bit一致。它不等于Native与官方的增量对齐，也不等于非零已填充初始Cache验收。

Native BF16 cache尚未实现；非零初始cache导入、Reset、异常恢复、buffer生命周期、不同长度压力测试、prefill-vs-decode组合误差、memcheck/initcheck均UNVERIFIED。后续必须逐项建失败测试，并在真实GPU记录原始退出码和实际Kernel启动证据。无TPOT、显存峰值或吞吐结果。
