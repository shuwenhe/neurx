# NeurX Module

`module/` is the PyTorch-like module facade for NeurX.

It intentionally reuses the existing `neurx.nn.module` and
`neurx.nn.parameter` structs so the codebase has one Module/Parameter identity.

Core flow:

```text
Tensor -> Parameter -> Module -> state_dict -> Optimizer/Checkpoint/Trainer
```

Files:

- `module.s`: module registration, traversal, train/eval, freeze/unfreeze
- `parameter.s`: Parameter and ParameterList helpers
- `state_dict.s`: named parameter/buffer state helpers

Keep layer implementations in `nn/`. Keep model architectures in `model/`.
