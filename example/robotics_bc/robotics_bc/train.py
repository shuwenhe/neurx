from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np

import neurx
import neurx.nn as nn
import neurx.optim as optim

from .config import BCConfig
from .dataset import RobotDemoDataset
from .policy import BehaviorCloningPolicy


@dataclass
class BCTrainResult:
    train_loss: float
    valid_loss: float
    model: BehaviorCloningPolicy


def to_tensor(array: np.ndarray):
    return neurx.Tensor(array.astype(np.float32, copy=False))


def split_dataset(dataset: RobotDemoDataset, train_ratio: float = 0.9):
    split = max(1, int(len(dataset) * train_ratio))
    split = min(split, len(dataset) - 1)
    train = RobotDemoDataset(dataset.observations[:split], dataset.actions[:split])
    valid = RobotDemoDataset(dataset.observations[split:], dataset.actions[split:])
    return train, valid


def _train_one_epoch(model, optimizer, loss_fn, dataset: RobotDemoDataset, batch_size: int) -> float:
    model.train()
    total_loss = 0.0
    steps = 0
    for obs_np, act_np in dataset.batches(batch_size, shuffle=True):
        obs = to_tensor(obs_np)
        act = to_tensor(act_np)
        pred = model(obs)
        loss = loss_fn(pred, act)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        total_loss += float(loss.item())
        steps += 1
    return total_loss / max(steps, 1)


def _evaluate(model, loss_fn, dataset: RobotDemoDataset, batch_size: int) -> float:
    model.eval()
    total_loss = 0.0
    steps = 0
    with neurx.no_grad():
        for obs_np, act_np in dataset.batches(batch_size, shuffle=False):
            obs = to_tensor(obs_np)
            act = to_tensor(act_np)
            pred = model(obs)
            loss = loss_fn(pred, act)
            total_loss += float(loss.item())
            steps += 1
    return total_loss / max(steps, 1)


def train_behavior_cloning(cfg: BCConfig, dataset: RobotDemoDataset) -> BCTrainResult:
    np.random.seed(cfg.seed)
    train_set, valid_set = split_dataset(dataset)
    model = BehaviorCloningPolicy(cfg.obs_dim, cfg.hidden_dim, cfg.act_dim)
    optimizer = optim.Adam(model.parameters(), lr=cfg.lr)
    loss_fn = nn.MSELoss()

    train_loss = 0.0
    valid_loss = 0.0
    for _ in range(cfg.epochs):
        train_loss = _train_one_epoch(model, optimizer, loss_fn, train_set, cfg.batch_size)
        valid_loss = _evaluate(model, loss_fn, valid_set, cfg.batch_size)
    return BCTrainResult(train_loss=train_loss, valid_loss=valid_loss, model=model)


def load_dataset_or_demo(data_path: Path, cfg: BCConfig) -> RobotDemoDataset:
    return RobotDemoDataset.from_npz(data_path, cfg)

