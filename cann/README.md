# NeurX CANN / Ascend

这个目录集中保存 NeurX 项目中所有华为昇腾 CANN/NPU 专属代码、配置和部署入口。

## Layout

- `env.s`: 输出 Ascend CANN 运行环境变量。
- `configs/ascend_910b_train.json`: 910B 训练入口示例，默认指向 `S` 训练脚本。
- `configs/ascend_310p3_train.json`: 310P3 推理入口示例，默认指向 `S` 服务脚本。
- `kernels/`: Ascend C / TBE 自定义推理算子。
- `operators/`: ACLNN / Graph Engine 算子封装。
- `runtime/`: ACL 设备、stream、内存及动态运行时加载。
- `model/`: NXTRFMV2 checkpoint 检查、FP16 转换与设备权重加载。
- `cache/`: 单卡物理分页 KV Cache 和请求 block table。
- `hccl/`: 华为集合通信运行时动态加载。
- `inference/`: CANN 推理后端适配器。
- `deploy/`: 昇腾专属部署清单。
- `scripts/`: 昇腾专属运行脚本。

## Notes

`Ascend 310/310P/310P3` 通常定位于推理场景，不适合做完整训练任务。建议：

- `910/910B`: 用于训练。
- `310P3`: 用于推理或服务验证。

## Quick Start

```bash
cd /app/neurx
ASCEND_HOME_PATH=/usr/local/Ascend/ascend-toolkit/latest \
ASCEND_RT_VISIBLE_DEVICES=0 \
make pretrain-npu
```

训练多卡运行时将设备列表改为逗号分隔形式，例如
`ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7`。目标会检查 Linux、CANN
Runtime、`npu-smi`，多卡时还会检查 HCCL，然后以 `cann`/`hccl` 后端配置
启动统一 S 预训练器。

当前原生 CANN 训练算子尚未绑定，S 预训练器仍使用可移植 kernel；该入口不会把
CPU fallback 误报为已经完成的 NPU 算子加速。

## 310P3 inference

310P3 服务采用 8 个单卡副本，不在 token 执行路径使用 HCCL。每个 worker
拥有独立的 ACL context、模型权重和分页 KV Cache。

```bash
cmake -S cann -B artifacts/build/cann
cmake --build artifacts/build/cann
```

310P3 ATB 算子插件实现位于 `operators/atb_310p_plugin.cpp`，编译后生成
`libneurx_cann_operators.so`：

```bash
source "${ASCEND_HOME_PATH}/set_env.sh"
source "${ATB_HOME_PATH}/set_env.sh"
cmake -S cann -B artifacts/build/cann-310p \
  -DNEURX_ENABLE_ATB_310P=ON
cmake --build artifacts/build/cann-310p
```

插件实现 `operators/operator_abi.h` 中的 ABI v1 prefill/decode 接口，执行
Gather、RMSNorm、Linear、RoPE、ReshapeAndCache、PagedAttention、残差、
SwiGLU 和 LM Head。KV Cache 使用 310P
`FRACTAL_NZ` 格式。

八卡进程入口为 `scripts/launch_8card_310p3_inference.sh`。它要求设置
`NEURX_ASCEND_WORKER_BIN`、`NEURX_CHECKPOINT` 和
`NEURX_CANN_OPERATOR_LIBRARY`。

当前实现要求 FP16、head size 为16的倍数且不超过256、KV block size 为16的
倍数且不超过128。Prefill 支持分块：每个 query token 使用独立的 block-table
行和递增 context length，从已经写入的分页 KV Cache 中读取历史上下文。数值
正确性和性能仍必须在 310P3+CANN/ATB 环境与 CPU/CUDA golden 对齐。
