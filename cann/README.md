# NeurX CANN / Ascend Scaffold

这个目录用于放置华为昇腾 CANN 相关的训练与环境脚手架，方便在 Ascend NPU 环境中启动训练任务。

## 目录说明

- `env.sh`: 初始化 Ascend CANN 运行环境变量。
- `train_launcher.py`: 训练启动器，负责配置解析、环境预检和命令转发。
- `configs/ascend_910b_train.json`: 可直接作为训练模板的示例配置。
- `configs/ascend_310p3_train.json`: 310P3 示例配置，启动时会明确阻止训练。
- `examples/torch_npu_train_template.py`: 基于 `torch` + `torch_npu` 的最小训练模板。

## 重要说明

`Ascend 310/310P/310P3` 通常定位于推理场景，不适合做完整训练任务。这个脚手架会在检测到 `310` 或 `310P3` 时直接拒绝 `mode=train`，并提示改用 `Ascend 910/910B` 等训练卡。

如果你的目标是：

- 在 `310P3` 上做推理部署，可以复用这里的环境脚本，但不应走训练入口。
- 在 `910/910B` 上做训练，可以直接使用本目录的启动器和模板。

## 快速开始

```bash
cd /app/neurx
source cann/env.sh
make cann-doctor CONFIG=cann/configs/ascend_910b_train.json
make cann-train CONFIG=cann/configs/ascend_910b_train.json
```

只做预检：

```bash
python3 cann/train_launcher.py --config cann/configs/ascend_910b_train.json --dry-run
```

如果你要接入自己的模型训练脚本，只需要把 JSON 配置中的 `train.command` 替换为你的实际命令即可。