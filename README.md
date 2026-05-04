# neurx

neurx is a deep learning framework with S-language write.

## Layout

- `python/neurx/`: Python runtime and compatibility surface
- `tensor/`: S source for tensor primitives and helpers
- `ad/`: S source for automatic differentiation
- `engine/`: S source for backward execution and autograd state
- `data/`: S source for datasets and dataloading
- `lf/`: S source for loss functions
- `train/`: S source for training utilities
- `runtime/`: S source for runtime state helpers, I/O adapters, stage state, and control-flow helpers
- `nn/`: S source for neural network building blocks
- `opt/`: S source for optimizers
- `s/`: legacy S entry scripts and notes
- `build/ir/`: generated S IR artifacts
- `build/logs/`: generated compiler and runtime logs

## S Modules

- `ad/ad.s`: automatic differentiation state, grad mode, record tracking, and backward skeleton
- `engine/backward.s`: backward engine entrypoint
- `engine/state.s`: autograd state helpers
- `tensor/tensor.s`: tensor structure, construction, views, elementwise ops, matmul
- `tensor/creation.s`: tensor creation and fill helpers
- `tensor/indexing.s`: indexing, concatenation, and splitting helpers
- `tensor/stats.s`: sorting and statistical helpers
- `tensor/linalg.s`: linear algebra helpers
- `tensor/einsum.s`: einsum entry point
- `ops.s`: operator entry points
- `autograd.s`: automatic differentiation prototype
- `schedule.s`: scheduling prototype
- `nn/nn.s`: linear layer and basic nn entry points
- `multimodal.s`: multimodal batch abstraction
- `trainer.s`: training config and step state
- `opt/optim_mvp.s`: minimal SGD and learning rate implementation
- `dataloader_mvp.s`: minimal dataloader for batch/sequence slicing
- `data/dataset.s`: dataset abstraction, slicing, splitting, and concatenation
- `data/dataloader.s`: data loading, batching, and dataloader state
- `lf/losses.s`: loss function entry point and core loss implementations
- `train/amp.s`: autocast and GradScaler state utilities
- `train/checkpoint_manager.s`: checkpoint retention and best-score tracking
- `train/logging.s`: training logging state and flush tracking
- `train/loop.s`: training loop and single-step training pipeline state machine
- `runtime/runtime.s`: runtime state and discovery helpers
- `runtime/io.s`: file, JSON, and environment adapters for the runtime layer
- `runtime/stage.s`: staged compile state helpers for jit/lower/compile/execute
- `runtime/control.s`: control-flow state helpers and simple cond/loop/scan primitives
- `runtime/control.s`: control-flow state helpers and simple cond/loop/scan primitives

## Notes

The S modules are compiled into runtime IR during the `s-compile-runtime` step and written under `build/ir/`.
