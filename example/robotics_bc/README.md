# NeurX Robotics Behavior Cloning

This folder is a minimal, runnable robotics training scaffold built on top of NeurX.

## Recommended directory layout

```text
example/robotics_bc/
  README.md
  train_behavior_cloning.py   # CLI entrypoint with sim/real modes
  robotics_bc/                # reusable Python package
    __init__.py
    config.py
    dataset.py
    policy.py
    simulation.py
    deployment.py
    train.py
  data/                       # optional demo datasets (.npz)
  checkpoints/                # optional saved weights
  logs/                       # optional training logs
```

## Training stages

1. Simulation pretrain
   - collect expert demonstrations in simulation
   - train a policy with behavior cloning
   - keep actions clipped and observation normalization stable

2. Sim-to-real adaptation
   - enable domain randomization in simulation
   - fine-tune on a small amount of real robot data
   - lower the learning rate and freeze stable perception layers if needed

3. Real robot deployment
   - run inference from a control loop
   - apply action scaling, safety limits, and emergency stop logic
   - log every episode for recovery and debugging

## Modes

- `sim`
  - generates expert demonstrations with a synthetic simulator stub
  - optionally enables domain randomization
  - trains the policy from simulation data

- `real`
  - loads recorded robot demonstrations from `.npz`
  - runs the same behavior cloning trainer
  - keeps deployment safety logic separate from training logic

## Data contract

The minimal script expects a `.npz` file with:

- `observations`: shape `[N, obs_dim]`
- `actions`: shape `[N, act_dim]`

If no dataset path is provided, the script falls back to a synthetic demo dataset so the example still runs end-to-end.

## Usage

```bash
python example/robotics_bc/train_behavior_cloning.py --mode sim --epochs 10
python example/robotics_bc/train_behavior_cloning.py --mode real --data example/robotics_bc/data/demo.npz
python example/robotics_bc/train_behavior_cloning.py --mode sim --domain-randomization
```

## What to add next

1. Replace `simulation.py` with a MuJoCo, Isaac Sim, or Gymnasium adapter.
2. Replace `deployment.py` with a ROS 2 or robot SDK control loop.
3. Add offline dataset transforms for images, proprioception, and action history.
4. Add a reward-learning or RL fine-tuning stage after behavior cloning.
