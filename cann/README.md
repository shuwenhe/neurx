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
eval "$(s cann/env.s)"
s train/loop.s
```

如需接入自己的任务，请把 JSON 配置中的 `train.command` 替换为你的 `S` 入口命令。
