"""
Minimal robotics training entrypoint for NeurX.

Modes:
- sim: generate simulation demonstrations and train a policy
- real: load real robot demonstrations and train a policy

The script remains intentionally small so it can be used as a starting point
for robotics projects without bringing in a full simulator or ROS stack.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from robotics_bc import BCConfig, SimConfig
from robotics_bc.deployment import RealRobotPolicyRunner, build_real_robot_safety_config
from robotics_bc.simulation import SimulatedRobotTask, generate_simulation_dataset
from robotics_bc.train import load_dataset_or_demo, train_behavior_cloning


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="NeurX robotics behavior cloning scaffold")
    parser.add_argument("--mode", choices=["sim", "real"], default="sim")
    parser.add_argument("--data", type=str, default="", help="Path to a .npz file with observations/actions")
    parser.add_argument("--task-name", type=str, default="pick-place")
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--obs-dim", type=int, default=32)
    parser.add_argument("--act-dim", type=int, default=4)
    parser.add_argument("--hidden-dim", type=int, default=128)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--domain-randomization", action="store_true")
    parser.add_argument("--demo-samples", type=int, default=4096)
    return parser


def run_sim_mode(cfg: BCConfig, task_name: str, demo_samples: int, domain_randomization: bool):
    sim_cfg = SimConfig(domain_randomization=domain_randomization)
    task = SimulatedRobotTask(name=task_name, obs_dim=cfg.obs_dim, act_dim=cfg.act_dim, horizon=200)
    dataset = generate_simulation_dataset(task, cfg, sim_cfg, num_samples=demo_samples)
    return train_behavior_cloning(cfg, dataset)


def run_real_mode(cfg: BCConfig, data_path: Path):
    dataset = load_dataset_or_demo(data_path, cfg)
    return train_behavior_cloning(cfg, dataset)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    cfg = BCConfig(
        obs_dim=args.obs_dim,
        act_dim=args.act_dim,
        hidden_dim=args.hidden_dim,
        batch_size=args.batch_size,
        epochs=args.epochs,
        lr=args.lr,
        seed=args.seed,
    )

    np.random.seed(cfg.seed)
    data_path = Path(args.data) if args.data else Path("example/robotics_bc/data/demo.npz")

    if args.mode == "sim":
        result = run_sim_mode(cfg, args.task_name, args.demo_samples, args.domain_randomization)
        print("mode=sim")
    else:
        result = run_real_mode(cfg, data_path)
        print("mode=real")

    print(f"train_loss={result.train_loss:.6f} valid_loss={result.valid_loss:.6f}")

    safety_cfg = build_real_robot_safety_config(action_dim=cfg.act_dim)
    runner = RealRobotPolicyRunner(result.model, safety_cfg)
    sample_obs = np.zeros((1, cfg.obs_dim), dtype=np.float32)
    action = runner.act(sample_obs)
    print(f"sample_action_shape={action.shape}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
