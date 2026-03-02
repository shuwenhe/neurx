from __future__ import annotations

import os
from dataclasses import dataclass

from tensor.platform.errors import ConfigurationError

_VALID_BACKENDS = {"gloo", "nccl"}


@dataclass(frozen=True)
class DistributedConfig:
    world_size: int = 1
    rank: int = 0
    local_rank: int = 0
    master_addr: str = "127.0.0.1"
    master_port: int = 29500
    backend: str = "nccl"


def _int_env(name: str, default: int) -> int:
    value = os.environ.get(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError as exc:
        raise ConfigurationError(f"{name} expects int value, got: {value!r}") from exc


def detect_distributed_config() -> DistributedConfig:
    cfg = DistributedConfig(
        world_size=_int_env("WORLD_SIZE", 1),
        rank=_int_env("RANK", 0),
        local_rank=_int_env("LOCAL_RANK", 0),
        master_addr=os.environ.get("MASTER_ADDR", "127.0.0.1"),
        master_port=_int_env("MASTER_PORT", 29500),
        backend=os.environ.get("TENSOR_DIST_BACKEND", "nccl").strip().lower(),
    )
    validate_distributed_config(cfg)
    return cfg


def validate_distributed_config(cfg: DistributedConfig) -> None:
    if cfg.world_size < 1:
        raise ConfigurationError("WORLD_SIZE must be >= 1")
    if cfg.rank < 0 or cfg.rank >= cfg.world_size:
        raise ConfigurationError("RANK must satisfy 0 <= RANK < WORLD_SIZE")
    if cfg.local_rank < 0:
        raise ConfigurationError("LOCAL_RANK must be >= 0")
    if not (1 <= cfg.master_port <= 65535):
        raise ConfigurationError("MASTER_PORT must be in [1, 65535]")
    if cfg.backend not in _VALID_BACKENDS:
        raise ConfigurationError(f"TENSOR_DIST_BACKEND must be one of {_VALID_BACKENDS}")


def is_distributed(cfg: DistributedConfig | None = None) -> bool:
    current = cfg or detect_distributed_config()
    return current.world_size > 1

