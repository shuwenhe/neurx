# NeurX CANN / Ascend Scaffold

这个目录保留 Ascend CANN 相关的环境脚手架，但运行入口已经改为 `S`。

## Layout

- `env.sh`: 初始化 Ascend CANN 运行环境变量。
- `configs/ascend_910b_train.json`: 910B 训练入口示例，默认指向 `S` 训练脚本。
- `configs/ascend_310p3_train.json`: 310P3 推理入口示例，默认指向 `S` 服务脚本。
- `kernels/`: Ascend C / TBE 自定义推理算子。
- `operators/`: ACLNN / Graph Engine 算子封装。
- `runtime/`: ACL 设备、stream、内存及动态运行时加载。

## Notes

`Ascend 310/310P/310P3` 通常定位于推理场景，不适合做完整训练任务。建议：

- `910/910B`: 用于训练。
- `310P3`: 用于推理或服务验证。

## Quick Start

```bash
cd /app/neurx
source arch/cann/env.sh
s train/loop.s
```

如需接入自己的任务，请把 JSON 配置中的 `train.command` 替换为你的 `S` 入口命令。
