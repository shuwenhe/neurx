# NeurX `S` Template Project

这是一个最小的 `S`-first 模板说明，用于替代旧的脚手架。

## Suggested Layout

```text
template_project/
├── s/
│   ├── model.s
│   ├── train.s
│   └── infer.s
├── config/
│   └── train.json
├── tests/
│   └── smoke.s
└── README.md
```

## Quick Start

```bash
s s/train.s
```

## Notes

- 模型定义放在 `s/model.s`。
- 训练入口放在 `s/train.s`。
- 推理入口放在 `s/infer.s`。
- 使用仓库根目录的 `make s-compile-runtime` 统一生成 IR。
