from __future__ import annotations

from dataclasses import dataclass


@dataclass
class BCConfig:
    obs_dim: int = 32
    act_dim: int = 4
    hidden_dim: int = 128
    batch_size: int = 64
    epochs: int = 10
    lr: float = 1e-3
    seed: int = 7


@dataclass
class SimConfig:
    domain_randomization: bool = True
    observation_noise_std: float = 0.01
    action_noise_std: float = 0.02
    reward_bonus: float = 1.0


@dataclass
class DeployConfig:
    action_dim: int = 4
    action_clip: float = 1.0
    emergency_stop_threshold: float = 2.5
    observation_smoothing: float = 0.2
