# tensor

A NumPy-based deep learning framework evolving toward a full-stack production platform.  
Current state: production foundation is in place (runtime config, diagnostics, package scaffolding), with core kernels and distributed/compile capabilities still in active expansion.

## Features
- Autograd `Tensor` with basic ops and `backward()`
- Core layers in `tensor.core.nn` including `Linear`, `LayerNorm`, `RMSNorm`, `MultiHeadAttention`, `MLP`, `MoE`, `Dropout`
- Optimizer `AdamW` and `clip_grad_norm`
- Losses `cross_entropy` and `cross_entropy_loss`
- CUDA extension (starter) with GPU tensor, add/mul, bias add, matmul, layernorm, softmax
- Runtime platform module (`tensor.platform`) for config, logging, diagnostics (`tensor-doctor`)
- Data pipeline scaffolding (`tensor.data.Dataset`, `tensor.data.DataLoader`)
- Distributed runtime scaffolding (`tensor.distributed.detect_distributed_config`)
- Compile API boundary (`tensor.compile.compile_module`)

## Project Layout
```
tensor/
  python/
    tensor/
      __init__.py
      core/            # Python-level tensor, autograd, utils
      nn/              # layers (currently in core/nn.py)
      optim/           # optimizers (currently in core/optim.py)
      data/            # dataset/dataloader
      distributed/     # distributed runtime config/launcher scaffold
      compile/         # compile API scaffold
      platform/        # runtime config, logging, diagnostics, errors
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

## Runtime Config
Environment variables:

- `TENSOR_DEVICE` (`cpu`/`cuda`, default `cpu`)
- `TENSOR_FALLBACK_TO_CPU` (`1`/`0`, default `1`)
- `TENSOR_LOG_LEVEL` (`DEBUG/INFO/WARNING/ERROR/CRITICAL`, default `INFO`)
- `TENSOR_STRICT_CHECKS` (`1`/`0`, default `0`)
- `TENSOR_DETERMINISTIC` (`1`/`0`, default `0`)
- `TENSOR_SEED` (optional non-negative integer)

Diagnostics:

```bash
tensor-doctor
tensor-doctor --json
tensor-doctor --require-cuda
```

## CUDA Extension (starter)
The CUDA extension is built from `cuda/bindings.cpp` and `cuda/kernels/kernels.cu`.

```bash
CUDA_HOME=/usr pip install -e /path/to/tensor --no-build-isolation
export TENSOR_DEVICE=cuda
```

## Reduction & Indices Semantics
- `sum/mean/max/min` support `axis`/`dim` and `keepdims`/`keepdim`.
- `max/min` with `axis` return `(values, indices)`.
- `argmax/argmin` and `max/min` indices are integer tensors:
  - CPU input: `int64` on CPU.
  - CUDA input: `int64` on CUDA.
- CUDA reduction supports full axes for 2D/3D inputs; last-dim uses dedicated kernels.

## CUDA Benchmark
Run CUDA operator benchmark and print the slowest case:

```bash
python tools/benchmark_cuda_ops.py --warmup 10 --iters 50
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
- See production roadmap: `docs/PRODUCTION_ROADMAP.md`

## License
Internal/experimental. Add a license if you plan to distribute.
