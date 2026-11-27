# 总体：PARTIAL；Native门禁BLOCKED

日期：2026-11-27。起始 Git：`a56388ea`；运行期间用户/外部提交 `c43c0577` 保留；本轮参考修正提交：`2bed257e7dd1e9c16e7a8782e3d2732424d41c63`。原始基线/index/diff/untracked 和22项受保护 SHA256 保存在 `artifact/build/qwen35_attention_bf16/reference/baseline.json`，最终逐项复核一致。

修改范围：独立官方参考 Harness、测试、执行计划及本轮报告/证据。未修改 DeltaNet、FP32 Attention、Bridge、Preflight 或其他模型路径。无 Native Attention BF16 Kernel。

环境：宿主机 RTX4060Ti，16380MiB，驱动580.159.03；PyTorch2.6.0+cu124、CUDA12.4、cuDNN90100；nvcc12.0.140、Compute Sanitizer2022.4.1。沙箱 nvidia-smi 退出9，宿主机读取退出0，两个结果均保留于 environment-final.json。

参考测试命令：
```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 \
 artifact/reference-env/bin/python test/native-construction/test_qwen35_attention_official_bf16.py
```
原始证据：`artifact/build/qwen35_attention_bf16/reference/`；最终日志 `phase-a-final-reviewed.log`，退出0，7/7，5.774秒。该时间是测试总耗时，不是 Attention 延迟。节点误差见 `node-summary.json`、各 trace JSON；源码版本/SHA、dtype与舍入合同见 [TOLERANCE](QWEN35_ATTENTION_BF16_TOLERANCE.md)。

Phase A有限范围PASS：7/7真实GPU官方参考自检；12个case、342个节点记录。覆盖固定seed、T1/3/63/64/65、真实head形状合成输入、官方prefill/decode/chunks和观察无干扰。并非checkpoint全层或模型推理验收。

Phase B：候选合同已形成，但FP32 norm、softmax及组合传播规则尚未充分建立，状态PARTIAL/NOT FROZEN。不能从已观测最大误差反向放宽门限。人审冻结尚未发生；本轮没有开始Native实现。

独立参考代码审查发现两项记录/无干扰测试缺口，已先RED再修复，最终7/7。详见 independent-review.md；此代码审查不替代人工数值合同审查。

后续最小顺序：补齐参考侧数值预算及输入范围 → 人审并SHA冻结 → projections/norm → RoPE → score/softmax → AV/gate/O → KV生命周期 → Sanitizer正负对照 → 全部回归及组件性能。预计生产新增文件仅hybrid_attention_bf16.h/.cu；测试新增独立probe/harness，不改旧FP32 API。

本轮未重跑原有FullAttention FP32 11/11、DeltaNet FP32 16/16、DeltaNet BF16 5/5、Phase1 11/11；这些是历史基线，不列为本次PASS。新Native不存在，memcheck/initcheck及故意越界/未初始化负对照未执行，均UNVERIFIED。prefill延迟、TPOT、launch、显存读写量、占用和转换开销均UNVERIFIED。

未推进MoE、Shared Expert、Hybrid Decoder、分页、Bridge或E2E；不宣布完整Phase2或Attention BF16模块PASS。当前交付是可复核的官方参考证据和未冻结合同，而非完成的Native模块。
