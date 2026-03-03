# tensor

A self-developed deep learning framework is evolving into a full-stack production platform.
Current state: production foundation is in place (runtime config, diagnostics, package scaffolding), with core kernels and distributed/compile capabilities still in active expansion.

## Features
- Autograd `Tensor` with basic ops and `backward()`
- Core layers in `tensor.core.nn` including `Linear`, `LayerNorm`, `RMSNorm`, `MultiHeadAttention`, `MLP`, `MoE`, `Dropout`
- Optimizer `AdamW` and `clip_grad_norm`
- Losses `cross_entropy` and `cross_entropy_loss`
- CUDA extension (starter) with GPU tensor, add/mul, bias add, matmul, layernorm, softmax
- Runtime platform module (`tensor.platform`) for config, logging, diagnostics (`tensor-doctor`)
- Serialization helpers including training checkpoint save/load (`tensor.serialization.save_checkpoint`)
- Training runtime helpers: `CheckpointManager`, `TrainingLogger`, `run_training_loop`
- AMP helpers: `tensor.training.autocast` and `tensor.training.GradScaler`
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
      training/        # training loop + checkpoint manager + metrics logger
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

## Tensor Ops Examples
```python
import numpy as np
from tensor import (
    Tensor,
    where,
    cat, stack, split, chunk,
    matmul, mm, bmm, inverse, svd, eig,
)

# Arithmetic + unary ops
x = Tensor(np.array([2.0, 4.0, 8.0]), requires_grad=True)
y = Tensor(np.array([2.0, 2.0, 2.0]), requires_grad=True)
z = (x / y) + (x ** y)
u = z.abs() + z.sqrt() + z.exp() + z.log() + z.sin() + z.cos()
loss = u.sum()
loss.backward()

# Shape ops
a = Tensor(np.arange(6.0).reshape(1, 2, 3), requires_grad=True)
b = a.squeeze(0).unsqueeze(1)          # (2, 1, 3)
c = b.repeat(2, 1, 1)                  # (4, 1, 3)
d = Tensor([[1.0], [2.0]], requires_grad=True).expand(2, 3)

# Indexing / gather / scatter / index_select
m = Tensor(np.arange(12.0).reshape(3, 4), requires_grad=True)
part = m[1:, 1:3]
idx = Tensor(np.array([[0, 2], [1, 3], [0, 1]], dtype=np.int64))
g = m.gather(1, idx)
s = m.scatter(1, idx, Tensor(np.ones((3, 2))))
sel = m.index_select(0, Tensor(np.array([2, 0], dtype=np.int64)))

# Concat / stack / split / chunk
p = Tensor(np.ones((2, 3)), requires_grad=True)
q = Tensor(np.zeros((1, 3)), requires_grad=True)
cc = cat([p, q], dim=0)                # (3, 3)
ss = stack([p, p], dim=0)              # (2, 2, 3)
s1, s2 = split(cc, [1, 2], dim=0)
ch = chunk(cc, 2, dim=0)

# Reductions
r = Tensor(np.array([[3.0, 4.0], [0.0, 0.0]]), requires_grad=True)
n = r.norm(dim=1)                      # [5, 0]
std = r.std(dim=1, correction=0)

# Comparisons + where
mask = r > 1.0
picked = where(mask, r, Tensor(np.zeros_like(r.to_numpy())))

# Linear algebra
A = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]))
B = Tensor(np.array([[2.0, 0.0], [0.0, 2.0]]))
M1 = matmul(A, B)
M2 = mm(A, B)
X3 = Tensor(np.arange(12.0).reshape(2, 2, 3))
Y3 = Tensor(np.arange(12.0).reshape(2, 3, 2))
M3 = bmm(X3, Y3)
A_inv = inverse(A)
U, S, Vh = svd(A)
W, V = eig(A)

# In-place ops
t = Tensor(np.array([-2.0, 3.0]))
t.relu_().add_(1.0).mul_(2.0)

# Device / dtype shortcuts
xf = x.float()
xl = x.long()
xcpu = x.cpu()
# xcuda = x.cuda()  # requires CUDA backend
```

## Notes
- This is not a drop-in replacement for PyTorch; it is intentionally minimal.
- CUDA support is early and focused on core primitives.
- See production roadmap: `docs/PRODUCTION_ROADMAP.md`

## License
Internal/experimental. Add a license if you plan to distribute.
