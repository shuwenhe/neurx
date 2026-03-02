# tensor

A minimal NumPy-based autograd framework extracted from the `llm` project. It now follows a scalable, industrial-style project layout with clear separation between Python front-end, C++ runtime, and CUDA kernels.

## Features
- Autograd `Tensor` with basic ops and `backward()`
- Core layers in `tensor.core.nn` including `Linear`, `LayerNorm`, `RMSNorm`, `MultiHeadAttention`, `MLP`, `MoE`, `Dropout`
- Optimizer `AdamW` and `clip_grad_norm`
- Losses `cross_entropy` and `cross_entropy_loss`
- CUDA extension (starter) with GPU tensor, add/mul, bias add, matmul, layernorm, softmax

## Project Layout
```
tensor/
  python/
    tensor/
      __init__.py
      core/            # Python-level tensor, autograd, utils
      nn/              # layers (currently in core/nn.py)
      optim/           # optimizers (currently in core/optim.py)
      data/            # dataset/dataloader (planned)
      distributed/     # DDP, collectives (planned)
      compile/         # JIT/AOT front-end (planned)
  cpp/
    tensor/
      core/            # C++ Tensor, Storage, Memory, Device (planned)
      autograd/        # C++ autograd engine (planned)
      ops/             # operator definitions (planned)
      runtime/         # execution engine, streams (planned)
      device/          # CPU/CUDA device abstractions (planned)
      jit/             # graph + kernel fusion (planned)
  cuda/
    bindings.cpp
    kernels/
      kernels.cu
    primitives/        # GEMM/conv primitives (planned)
    utils/
  tests/
  docs/
  tools/
  setup.py
  setup.cfg
```

## Install (offline-friendly)
```bash
pip install -e /path/to/tensor --no-build-isolation
```

## CUDA Extension (starter)
The CUDA extension is built from `cuda/bindings.cpp` and `cuda/kernels/kernels.cu`.

```bash
CUDA_HOME=/usr pip install -e /path/to/tensor --no-build-isolation
export TENSOR_DEVICE=cuda
```

## Quick Start
```python
import numpy as np
from tensor import Tensor
from tensor.core.nn import Linear
from tensor.core.optim import AdamW

x = Tensor(np.random.randn(4, 8), requires_grad=True)
layer = Linear(8, 4)

out = layer(x)
loss = out.mean()

opt = AdamW(layer.parameters(), lr=1e-3)
opt.zero_grad()
loss.backward()
opt.step()
```

## Notes
- This is not a drop-in replacement for PyTorch; it is intentionally minimal.
- CUDA support is early and focused on core primitives.

## License
Internal/experimental. Add a license if you plan to distribute.
