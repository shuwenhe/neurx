# neurx

neurx is a deep learning framework with a Python runtime and an S-language core rewrite.

## Layout

- `python/neurx/`: Python runtime and compatibility surface
- `tensor/`: S source for tensor primitives and helpers
- `ad/`: S source for automatic differentiation
- `dl/`: S source for datasets and dataloading
- `lf/`: S source for loss functions
- `train/`: S source for training utilities
- `nn/`: S source for neural network building blocks
- `opt/`: S source for optimizers
- `s/`: legacy S entry scripts and notes
- `reports/s_ir/`: generated S IR artifacts
- `python/neurx/compile/_s_runtime/`: packaged runtime IR artifacts

## S Modules

- `ad/ad.s`: automatic differentiation state, grad mode, backward skeleton
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
- `dl/dataset.s`: dataset abstraction, splitting, and concatenation
- `dl/dataloader.s`: data loading and batch assembly
- `lf/losses.s`: loss function entry point and placeholder implementation
- `train/amp.s`: autocast and GradScaler skeleton
- `train/checkpoint_manager.s`: checkpoint manager skeleton
- `train/logging.s`: training logging skeleton
- `train/loop.s`: training loop skeleton

## Notes

The S modules are compiled into runtime IR during the `s-compile-runtime` step.
