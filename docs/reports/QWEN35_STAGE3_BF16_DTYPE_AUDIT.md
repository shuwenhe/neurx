# Stage 3 官方 BF16 dtype 审计（部分）

2026-11-26。官方 Transformers 文件 `modeling_qwen3_5_moe.py` SHA256 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`；参考 PyTorch 2.6.0+cu124、RTX 4060 Ti、驱动 580.159.03。运行仓库既有纯 fallback 加载器，验证 model/cache/activation 三个文件哈希，禁用 Hub 装饰器与 FLA、autocast、TF32 和 compile；先 chunk 后 recurrent。对既有观察器仅在临时副本将每 scope 记录数限制提高到 10000，不修改官方函数体或运行计算；完整 1277 条运行 trace 与脚本存于 `artifact/build/qwen35_stage3/final_bf16_20261126/`。

下表区分可见 tensor dtype 与 GPU kernel 内部累加：Torch dispatch 只能观测算子边界，不能证明 cuDNN/cuBLAS BF16 乘法或 reduction 内部累加类型；这些项标 UNVERIFIED，不凭变量名推断。官方行号位于固定哈希的 `modeling_qwen3_5_moe.py`。

| 运算 / 官方位置 | 实测输入 → 可见输出；累加 | 执行顺序与舍入 / 状态 |
|---|---|---|
| 输入 QKV、z、a、b 投影，约 437–447 行 | BF16 × BF16 → BF16；内部累加 UNVERIFIED | 各 linear 的结果 BF16 舍入。 |
| causal conv1d，201–240 行 | BF16 输入和权重 → BF16；kernel 内部累加 UNVERIFIED | prefill pad 后 conv；单步 decode concat 已缓存 history 后 copy 最近状态，再 conv。两个模式均观测 BF16 conv 输出及 BF16 history。 |
| conv SiLU，201–240 行 | BF16 → BF16；内部精度 UNVERIFIED | conv 输出先产生 BF16 tensor，SiLU 结果再为 BF16。 |
| Q/K L2，243–247 行 | BF16 平方→BF16 sum→BF16 加 epsilon→BF16 rsqrt→BF16 相乘；sum 内部累加 UNVERIFIED | 每个 tensor 级操作后 BF16 可见；两个模式调用相同 L2，先于 core 转 FP32。 |
| beta，约 489 行 | BF16 sigmoid→BF16；内部精度 UNVERIFIED | b 的 BF16 输出 sigmoid 后 BF16，再在 core 中转 FP32。 |
| decay，约 490–492 行 | `A_log.float()` 和 `a.float()`；add/softplus/exp/mul 可见 FP32 | `-exp(A_log.float()) * softplus(a.float()+dt_bias)`，core 对 g 再 exp；BF16 参数先按官方算子转换/类型提升。内部 transcendental 精度 UNVERIFIED。 |
| recurrent update，332–382 行 | Q/K/V/beta 从 BF16 转 FP32、g FP32；乘法、sum 和 state 可见 FP32 | 对旧 state 乘 decay；`pred=sum(state*k)`；`delta=(v-pred)*beta`；state 加 `k*delta`；新 state 与 q 归约。state 保持 FP32，core 输出转回原 BF16。FP32 sum 内部归约顺序未由 dispatch 证明。 |
| chunk prefill，250–329 行 | L2 后 Q/K/V/beta 转 FP32，matmul 与 state 可见 FP32，core 出口 BF16 | chunk 的三角块计算与 recurrent 算式路径不同；最终 core 转回 BF16。两路径可见边界相同，不据此声称每一步舍入或计算顺序相同。 |
| gated RMSNorm，169–184 行 | core BF16→FP32 平方/mean/rsqrt/归一化→BF16；乘 BF16 weight 得 BF16；z 转 FP32，SiLU 后乘法 FP32→BF16 | norm 先舍入 BF16，再与权重相乘并产生 BF16；门控后最终 BF16。kernel 内部累加 UNVERIFIED。 |
| output projection，约 514 行 | BF16 输入和权重→BF16；内部累加 UNVERIFIED | linear 的输出 BF16。 |

实际 BF16 半 ULP 边界、极端值，以及 GPU kernel 内部累加类型尚未完成全覆盖；上述 tensor 边界探针不是内部硬件累加证明。参考与实现仍需完整逐 token 中间量及真实多层数值验收；见 [验收报告](QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md)。

## 本轮门禁核对

基线 `main` / `19cae974`；2026-11-26 宿主机 GPU RTX 4060 Ti、驱动 580.159.03、固定官方 model SHA256 未变。dtype 边界审计 **PARTIAL**：现有 1277 条 tensor 操作 trace 未给出 GPU kernel 内部累加 dtype，也没有覆盖四路所有 13 个中间量；不能据此证明 BF16 原生实现逐舍入兼容。BF16 每节点独立门限保持 PENDING，直到独立参考、足够分布与独立审查完成。

本轮新增 `test/native-construction/test_qwen35_bf16_rounding.py`：36 个正负、次正规/正规及 BF16 tie 和相邻 FP32 位模式，比较 NumPy RNE fixture 转换与 GPU Torch BF16 转换，**1/1 PASS**。该结果只验证参考输入转换，不证明 kernel 内部运算或完整算子舍入语义。
