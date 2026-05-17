from __future__ import annotations

from dataclasses import dataclass

import numpy as np

import neurx

from .config import DeployConfig


@dataclass
class RealRobotSafetyState:
    action_dim: int
    clip: float
    emergency_stop_threshold: float
    observation_smoothing: float
    last_observation: np.ndarray | None = None
    emergency_stop: bool = False


def build_real_robot_safety_config(action_dim: int = 4) -> DeployConfig:
    return DeployConfig(action_dim=action_dim)


class RealRobotPolicyRunner:
    def __init__(self, model, config: DeployConfig):
        self.model = model
        self.config = config
        self.state = RealRobotSafetyState(
            action_dim=config.action_dim,
            clip=config.action_clip,
            emergency_stop_threshold=config.emergency_stop_threshold,
            observation_smoothing=config.observation_smoothing,
        )

    def smooth_observation(self, observation: np.ndarray) -> np.ndarray:
        if self.state.last_observation is None:
            self.state.last_observation = observation.astype(np.float32, copy=False)
            return self.state.last_observation
        alpha = self.state.observation_smoothing
        current = observation.astype(np.float32, copy=False)
        self.state.last_observation = (1.0 - alpha) * self.state.last_observation + alpha * current
        return self.state.last_observation

    def check_emergency_stop(self, observation: np.ndarray) -> bool:
        if float(np.max(np.abs(observation))) > self.state.emergency_stop_threshold:
            self.state.emergency_stop = True
        return self.state.emergency_stop

    def act(self, observation: np.ndarray) -> np.ndarray:
        if self.check_emergency_stop(observation):
            return np.zeros((1, self.state.action_dim), dtype=np.float32)
        smoothed = self.smooth_observation(observation)
        with neurx.no_grad():
            action = self.model(neurx.Tensor(smoothed.astype(np.float32, copy=False)))
        action_np = np.asarray(action.data if hasattr(action, "data") else action, dtype=np.float32)
        return np.clip(action_np, -self.state.clip, self.state.clip)
