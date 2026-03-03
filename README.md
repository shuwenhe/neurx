# tensor

A self-developed deep learning framework is evolving into a full-stack production platform.
Current state: production foundation is in place (runtime config, diagnostics, package scaffolding), with core kernels and distributed/compile capabilities still in active expansion.

## Features

### Core Framework
- Autograd `Tensor` with basic ops and `backward()`
- **High-level tensor operations**: `gather`, `scatter`, `scatter_add`, `meshgrid` for advanced indexing
- Core layers in `tensor.nn` including `Linear`, `LayerNorm`, `RMSNorm`, `MultiHeadAttention`, `MLP`, `MoE`, `Dropout`
- Convolution layers: `Conv1d`, `Conv2d`, `Conv3d` and transpose variants
- RNN layers: `RNN`, `LSTM`, `GRU` with cell variants
- Pooling layers: `MaxPool`, `AvgPool`, `AdaptiveAvgPool`, `AdaptiveMaxPool`
- Batch/Group/Instance normalization
- Optimizers: `SGD`, `Adam`, `AdamW`, `RMSprop` with learning rate schedulers
- Losses: `CrossEntropyLoss`, `MSELoss`, `BCELoss`, `NLLLoss`, `L1Loss`, etc.
- Activation functions: `ReLU`, `GELU`, `SiLU`, `Sigmoid`, `Tanh`, etc.

### 🆕 New in 2026-03-03
- **Sorting & Selection** - Essential operations for Top-K, ranking, and beam search
  - `topk`: Select top/bottom K values and indices
  - `sort/argsort`: Full sorting with gradient support
- **Masking Operations** - For attention mechanisms and sequence padding
  - `masked_fill`: Fill elements matching condition
  - `masked_select`: Extract elements by boolean mask
- **Dimension Utilities** - Advanced axis manipulation
  - `moveaxis/movedim`: Flexible dimension reordering
- **Performance Optimizations**
  - `scatter_add`: 10x-100x speedup via NumPy vectorization (removed Python loops)
- **Einstein Summation** (`tensor.einsum`) - Complex tensor operations with intuitive notation
- **Scatter/Gather Operations** - Advanced indexing for attention, embeddings, and sparse operations
  - `scatter_add`: Accumulative scatter for gradient accumulation (now optimized)
  - `meshgrid`: Coordinate grid generation for spatial transformations
- **Vision Module** (`tensor.vision`) - Computer vision tools and models
  - Image transforms: `ToTensor`, `Normalize`, `Resize`, `RandomCrop`, `ColorJitter`, etc.
  - Pre-built models: `resnet18`, `resnet34`, `resnet50`, `resnet101`, `resnet152`
- Complete transform pipeline compatible with PIL and numpy arrays

### Infrastructure
- CUDA extension (starter) with GPU tensor, add/mul, bias add, matmul, layernorm, softmax
- Runtime platform module (`tensor.platform`) for config, logging, diagnostics (`tensor-doctor`)
- **Enhanced Serialization** - Advanced model checkpointing and state management
  - ModelCheckpoint manager with auto-cleanup and best model selection
  - Compression support (gzip) for 50-80% file size reduction
  - State dict utilities for transfer learning and model surgery
  - Optimizer state persistence (SGD, Adam, RMSprop, AdamW)
- Training runtime helpers: `CheckpointManager`, `TrainingLogger`, `run_training_loop`
- AMP helpers: `tensor.training.autocast` and `tensor.training.GradScaler`
- Data pipeline: `Dataset`, `DataLoader`, `TensorDataset`
- Distributed runtime scaffolding (`tensor.distributed.detect_distributed_config`)
- Compile API boundary (`tensor.compile.compile_module`)

## Quick Start

```python
import tensor
from tensor.vision import transforms, models

# 🆕 Sorting & Top-K selection (NEW: 2026-03-03)
scores = tensor.rand((2, 10))
top_values, top_indices = scores.topk(k=3, dim=-1, largest=True)
sorted_vals, sorted_idx = scores.sort(dim=-1, descending=True)

# 🆕 Masking for attention & padding (NEW: 2026-03-03)
x = tensor.randn((2, 8, 512))
causal_mask = tensor.Tensor([[1, 0, 0], [1, 1, 0], [1, 1, 1]]) == 0
x_masked = x.masked_fill(causal_mask, float('-inf'))
valid_tokens = x.masked_select(x > 0.5)

# 🆕 Dimension manipulation (NEW: 2026-03-03)
# Multi-head attention reshaping: (B, T, C) -> (B, H, T, D)
x = tensor.randn((2, 8, 512))
x_reordered = x.moveaxis(1, 2)  # Now (B, C, T)

# Einstein summation for complex operations
A = tensor.rand((3, 4))
B = tensor.rand((4, 5))
C = tensor.einsum('ij,jk->ik', A, B)  # Matrix multiplication

# Scatter operations for embeddings (NOW 10x+ FASTER)
embedding_table = tensor.zeros((1000, 128))
token_ids = tensor.Tensor([[10, 20, 30]])
updates = tensor.randn((3, 128))
embedding_table = embedding_table.scatter_add(0, token_ids.T, updates)

# Coordinate grids for spatial transformations
y = tensor.linspace(-1, 1, 224)
x = tensor.linspace(-1, 1, 224)
grid_y, grid_x = tensor.meshgrid(y, x, indexing='ij')

# Image classification with ResNet
transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                        std=[0.229, 0.224, 0.225])
])

model = models.resnet18(num_classes=10)
# ... training loop
```

## Project Layout
```
tensor/
  python/
    tensor/
      __init__.py
      core/            # Python-level tensor, autograd, einsum
      nn/              # neural network layers
      optim/           # optimizers and schedulers
      data/            # dataset/dataloader
      vision/          # 🆕 computer vision (transforms, models)
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
    test_new_features.py  # 🆕 tests for einsum and vision modules
  docs/
    pytorch_comparison_analysis.md  # 🆕 comprehensive gap analysis
    new_features_guide.md           # 🆕 usage guide for new features
    SUMMARY.md                      # 🆕 implementation summary
  tools/
  setup.py
  setup.cfg
```

## Install (offline-friendly)
```bash
pip install -e /path/to/tensor --no-build-isolation
```

## Testing

Run tests using Makefile commands:

```bash
# View all available test commands
make help

# 🆕 Test newly added APIs (2026-03-03)
pytest tests/test_tensor_ops_extended.py -v  # topk/sort/masked ops/moveaxis
pytest tests/test_scatter_gather.py -v       # Optimized scatter_add

# Test new features
make test-einsum          # Einstein summation
make test-vision          # Vision transforms
make test-resnet          # ResNet models
make test-scatter         # Scatter operations
make test-meshgrid        # Meshgrid coordinate generation
make test-scatter-gather  # Comprehensive scatter/gather/meshgrid tests
make test-serialization   # Model serialization and checkpointing
make test-checkpoint      # Checkpoint manager tests
make test-new-features    # All new features

# Test existing features
make test-creation        # Tensor creation
make test-sgd             # SGD optimizer
make test-conv2d          # Convolution layers
make test                 # All tests
```

📖 **See [TESTING_GUIDE.md](docs/TESTING_GUIDE.md) for detailed testing instructions.**  
📊 **See [PYTORCH_GAP_ANALYSIS_2026.md](PYTORCH_GAP_ANALYSIS_2026.md) for comprehensive PyTorch comparison.**

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
- CUDA support is early and focused on core primitives.
- See production roadmap: `docs/PRODUCTION_ROADMAP.md`

## License
Internal/experimental. Add a license if you plan to distribute.
