# tensor

A minimal NumPy-based autograd framework extracted from the `llm` project. It provides a small `Tensor` with automatic differentiation, a lightweight `nn` module set, optimizers, and losses. The goal is clarity and hackability over performance.

## Features
- Autograd `Tensor` with basic ops and `backward()`
- Core layers in `tensor.core.nn` including `Linear`, `LayerNorm`, `RMSNorm`, `MultiHeadAttention`, `MLP`, `MoE`, `Dropout`
- Optimizer `AdamW` and `clip_grad_norm`
- Losses `cross_entropy` and `cross_entropy_loss`
- Simple text generation helpers when used via the `llm` project

## Install (offline-friendly)
This repo is designed to be installed in editable mode without internet access.

```bash
pip install -e /path/to/tensor --no-build-isolation
```

## Quick Start
```python
import numpy as np
from tensor import Tensor
from tensor.core.nn import Linear, LayerNorm
from tensor.core.optim import AdamW

# Simple linear model
x = Tensor(np.random.randn(4, 8), requires_grad=True)
layer = Linear(8, 4)

# Forward
out = layer(x)
loss = out.mean()

# Backward + update
opt = AdamW(layer.parameters(), lr=1e-3)
opt.zero_grad()
loss.backward()
opt.step()
```

## Package Layout
```
tensor/
  tensor/
    __init__.py
    core/
      tensor.py
      nn.py
      optim.py
      losses.py
```

## API Notes
- `Tensor` expects NumPy arrays or array-like inputs.
- `Module.parameters()` returns a flat list of `Parameter` tensors.
- Most ops are eager NumPy, not optimized for speed.
- This is not a drop-in replacement for PyTorch, it is intentionally minimal.

## Using From `llm`
The `llm` project imports this package as:
```python
from tensor.core.nn import Linear, LayerNorm
from tensor.core.tensor import Tensor
```

## Limitations
- No GPU support
- No mixed precision
- Not optimized for large-scale training

## License
Internal/experimental. Add a license if you plan to distribute.
