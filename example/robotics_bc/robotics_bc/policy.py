from __future__ import annotations

import neurx.nn as nn


class BehaviorCloningPolicy(nn.Module):
    def __init__(self, obs_dim: int, hidden_dim: int, act_dim: int):
        super().__init__()
        self.net = nn.Sequential(
            [
                nn.Linear(obs_dim, hidden_dim),
                nn.ReLU(),
                nn.Linear(hidden_dim, hidden_dim),
                nn.ReLU(),
                nn.Linear(hidden_dim, act_dim),
            ]
        )

    def forward(self, x):
        return self.net(x)

