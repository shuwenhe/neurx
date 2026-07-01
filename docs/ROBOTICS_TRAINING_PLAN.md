# NeurX Robotics Training Plan

This document defines the recommended structure for using `neurx` to train robots.

## Goal

Keep `neurx` focused on framework primitives while treating robotics as a first-class workflow:

- framework core: tensor, autograd, optimizers, distributed, compile, runtime
- robotics workflow: data collection, simulation, behavior cloning, RL fine-tuning, deployment
- safety: action limits, emergency stop, observation filtering, logging

## Recommended Directory Structure

```text
neurx/
  core/
    tensor/
    ad/
    engine/
    nn/
    ops/
    losses/
    optim/
    data/
    train/
    runtime/

  compile/
  distributed/
  serving/
  backends/
  workflows/
    robotics/
      sim/
      real/
      policy/
      train/
      eval/
      deploy/

  example/
    robotics_bc/
      README.md
      train_behavior_cloning.py
      robotics_bc/
        __init__.py
        config.py
        dataset.py
        policy.py
        simulation.py
        deployment.py
        train.py
      data/
      checkpoints/
      logs/

  tests/
  doc/
  scripts/
  legacy/
```

## What Goes Where

### `workflows/robotics/`

Use this for the formal robotics pipeline.

- `sim/`: simulation adapters and domain randomization
- `real/`: robot SDK or ROS 2 integration
- `policy/`: policy models and action heads
- `train/`: training loops and losses
- `eval/`: rollout evaluation and metrics
- `deploy/`: inference loop, safety checks, control bridge

### `example/robotics_bc/`

Use this for the smallest runnable baseline.

- `train_behavior_cloning.py`: single entrypoint
- `robotics_bc/dataset.py`: demo dataset loader
- `robotics_bc/policy.py`: behavior cloning policy
- `robotics_bc/simulation.py`: simulation demo generator
- `robotics_bc/deployment.py`: safety wrapper for real robot inference
- `robotics_bc/train.py`: shared training logic

## Training Stages

1. Simulation pretraining
   - collect expert demonstrations
   - train with behavior cloning
   - validate on held-out rollouts

2. Sim-to-real adaptation
   - add observation and action randomization
   - fine-tune on a small amount of real data
   - lower learning rate and freeze stable layers if needed

3. Real robot deployment
   - run inference in a control loop
   - clip actions and enforce emergency stop
   - log every episode for debugging and recovery

4. Continuous improvement
   - store failures and edge cases
   - periodically refresh the dataset
   - add offline RL or reward learning later

## File Ownership Guidance

- `train/loop.s` and `train/parallel.s`: keep as general training infrastructure
- `pretrain/` and `posttrain/`: keep as workflow-specific sequencing for language/model training
- `example/robotics_bc/`: keep the first robotics runnable entrypoint here
- `workflows/robotics/`: promote to this layer once the robotics stack becomes a stable product path

## Recommended Priority Order

1. Behavior cloning baseline
2. Simulation adapters
3. Real robot safety bridge
4. RL fine-tuning
5. Distributed robotics training
6. Compiler/runtime optimizations for policy inference

## Minimal Data Contract

The first robot dataset format should be simple:

- `observations`: `[N, obs_dim]`
- `actions`: `[N, act_dim]`

Optional later fields:

- `next_observations`
- `rewards`
- `dones`
- `timestamps`
- `camera_frames`
- `proprioception`

## Practical Recommendation

Do not create a top-level `robot/` folder yet.

Use `example/robotics_bc/` for the current working entrypoint and add `workflows/robotics/` only when the robotics pipeline becomes a stable long-term track.

