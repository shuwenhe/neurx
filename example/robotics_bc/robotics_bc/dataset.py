from __future__ import annotations

from pathlib import Path
from typing import Iterator, Tuple

import numpy as np

from .config import BCConfig


class RobotDemoDataset:
    def __init__(self, observations: np.ndarray, actions: np.ndarray):
        if observations.ndim != 2:
            raise ValueError("observations must have shape [N, obs_dim]")
        if actions.ndim != 2:
            raise ValueError("actions must have shape [N, act_dim]")
        if len(observations) != len(actions):
            raise ValueError("observations and actions must have the same length")

        self.observations = observations.astype(np.float32, copy=False)
        self.actions = actions.astype(np.float32, copy=False)

    @classmethod
    def from_npz(cls, path: Path, fallback: BCConfig) -> "RobotDemoDataset":
        if path.exists():
            data = np.load(path)
            return cls(data["observations"], data["actions"])
        return synthetic_demo_dataset(fallback)

    def __len__(self) -> int:
        return len(self.observations)

    def batches(self, batch_size: int, shuffle: bool = True) -> Iterator[Tuple[np.ndarray, np.ndarray]]:
        indices = np.arange(len(self))
        if shuffle:
            np.random.shuffle(indices)
        for start in range(0, len(self), batch_size):
            batch_ids = indices[start : start + batch_size]
            yield self.observations[batch_ids], self.actions[batch_ids]


def synthetic_demo_dataset(cfg: BCConfig, num_samples: int = 2048) -> RobotDemoDataset:
    rng = np.random.default_rng(cfg.seed)
    observations = rng.normal(size=(num_samples, cfg.obs_dim)).astype(np.float32)
    teacher_w = rng.normal(size=(cfg.obs_dim, cfg.act_dim)).astype(np.float32) * 0.5
    teacher_b = rng.normal(size=(cfg.act_dim,)).astype(np.float32) * 0.1
    actions = np.tanh(observations @ teacher_w + teacher_b).astype(np.float32)
    return RobotDemoDataset(observations, actions)

