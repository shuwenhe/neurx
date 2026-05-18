# Workflows

`workflows/` is the compatibility orchestration layer of NeurX.

It remains in the tree for older task flows and lifecycle code:

- `train/`: training-state transitions and training-control logic
- `eval/`: evaluation-state updates and metrics aggregation
- `deploy/`: deployment and release-state transitions
- `sim/`: simulation setup and environment toggles
- `real/`: real-world connection and safety transitions
- `data/`: workflow-level dataset bookkeeping
- `policy/`: policy readiness and training flags for task pipelines

## What Belongs Here

- Multi-stage task flows that already exist
- Training / evaluation / deployment orchestration for legacy pipelines
- Simulation-to-real lifecycle control for compatibility code
- State machines that combine multiple model or runtime components

## What Does Not Belong Here

- Model architecture definitions
- Layer / block / optimizer implementations
- Tensor, autograd, runtime, or backend primitives
- New model training entrypoints
- Single-purpose utility code that does not coordinate a workflow

## Rule of Thumb

If the code answers "what step happens next in the task lifecycle for legacy code?", it belongs here.
If the code answers "how does the model compute or train?", it belongs in `model/`, `train/`, `pretrain/`, `posttrain/`, `nn/`, `tensor/`, or `runtime/`.

## Robotics

The robotics subtree remains here only as compatibility orchestration:

- `workflows/robotics/workflow.s`: end-to-end robotics orchestration
- `workflows/robotics/train/train.s`: training-state control
- `workflows/robotics/eval/eval.s`: evaluation-state control
- `workflows/robotics/deploy/deploy.s`: deployment-state control
- `workflows/robotics/sim/sim.s`: simulation-state control
- `workflows/robotics/real/real.s`: real-world connection and safety control
- `workflows/robotics/data/data.s`: workflow dataset bookkeeping
- `workflows/robotics/policy/policy.s`: policy readiness and training flags

## Scope Guard

Keep `workflows/` frozen unless you are maintaining compatibility. New robotics training code should go under `model/robotics/` instead.
