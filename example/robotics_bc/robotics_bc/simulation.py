from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .config import BCConfig, SimConfig
from .dataset import RobotDemoDataset


@dataclass
class SimulatedRobotTask:
    name: str
    obs_dim: int
    act_dim: int
    horizon: int


def generate_simulation_dataset(task: SimulatedRobotTask, bc: BCConfig, sim: SimConfig, num_samples: int = 4096) -> RobotDemoDataset:
    rng = np.random.default_rng(bc.seed + 101)
    observations = rng.normal(size=(num_samples, task.obs_dim)).astype(np.float32)
    teacher_w = rng.normal(size=(task.obs_dim, task.act_dim)).astype(np.float32) * 0.4
    teacher_b = rng.normal(size=(task.act_dim,)).astype(np.float32) * 0.05
    actions = observations @ teacher_w + teacher_b
    if sim.domain_randomization:
        observations = observations + rng.normal(size=observations.shape).astype(np.float32) * sim.observation_noise_std
        actions = actions + rng.normal(size=actions.shape).astype(np.float32) * sim.action_noise_std
    actions = np.tanh(actions).astype(np.float32)
    return RobotDemoDataset(observations, actions)

