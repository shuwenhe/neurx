# Robotics Workflows

`workflows/robotics/` is the compatibility orchestration subtree for robotics lifecycle control.

## Active Subtrees

- `train/`: trajectory-training workflow around `model/robotics/`
- `data/`: dataset bookkeeping state
- `eval/`: evaluation bookkeeping state
- `sim/`: simulation state and environment toggles
- `real/`: real-world connection and safety transitions
- `deploy/`: deployment and release-state transitions

## Boundary

- New model logic belongs in `model/robotics/`.
- New training logic belongs in `model/robotics/` and `workflows/robotics/train/`.
- `sim/`, `real/`, and `deploy/` stay focused on orchestration and lifecycle control.
