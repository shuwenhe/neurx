# NeurX CANN / Ascend

这个目录集中保存 NeurX 项目中所有华为昇腾 CANN/NPU 专属代码、配置和部署入口。

## Layout

- `env.s`: 输出 Ascend CANN 运行环境变量。
- `configs/ascend_910b_train.json`: 910B 训练入口示例，默认指向 `S` 训练脚本。
- `configs/ascend_310p3_train.json`: 310P3 推理入口示例，默认指向 `S` 服务脚本。
- `kernels/`: Ascend C / TBE 自定义推理算子。
- `operators/`: ACLNN / Graph Engine 算子封装。
- `runtime/`: ACL 设备、stream、内存及动态运行时加载。
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

多卡运行时将设备列表改为逗号分隔形式，例如
`ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7`。目标会检查 Linux、CANN
Runtime、`npu-smi`，多卡时还会检查 HCCL，然后以 `cann`/`hccl` 后端配置
启动统一 S 预训练器。

当前原生 CANN 训练算子尚未绑定，S 预训练器仍使用可移植 kernel；该入口不会把
CPU fallback 误报为已经完成的 NPU 算子加速。
