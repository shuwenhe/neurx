from __future__ import annotations

import os
import threading
from dataclasses import dataclass

from neurx.platform.errors import ConfigurationError

_ENV_KEYS = (
    "TENSOR_DEVICE",
    "TENSOR_FALLBACK_TO_CPU",
    "TENSOR_STRICT_CHECKS",
    "TENSOR_LOG_LEVEL",
    "TENSOR_DETERMINISTIC",
    "TENSOR_SEED",
)

_VALID_LOG_LEVELS = {"CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"}
_VALID_DEVICES = {"cpu", "cuda", "npu"}


def _parse_bool(name: str, value: str | None, default: bool) -> bool:
    if value is None:
        return default
    v = value.strip().lower()
    if v in {"1", "true", "on", "yes"}:
        return True
    if v in {"0", "false", "off", "no"}:
        return False
    raise ConfigurationError(f"{name} expects bool-like value, got: {value!r}")


def _parse_int(name: str, value: str | None) -> int | None:
    if value is None or value.strip() == "":
        return None
    try:
        return int(value)
    except ValueError as exc:
        raise ConfigurationError(f"{name} expects int value, got: {value!r}") from exc


def _normalize_device(device: str | None) -> str:
    if device is None:
        return "cpu"
    out = device.strip().lower()
    if out not in _VALID_DEVICES:
        raise ConfigurationError(f"TENSOR_DEVICE must be one of {_VALID_DEVICES}, got: {device!r}")
    return out


def _normalize_log_level(level: str | None) -> str:
    if level is None or level.strip() == "":
        return "INFO"
    out = level.strip().upper()
    if out not in _VALID_LOG_LEVELS:
        raise ConfigurationError(f"TENSOR_LOG_LEVEL must be one of {_VALID_LOG_LEVELS}, got: {level!r}")
    return out


@dataclass(frozen=True)
class RuntimeConfig:
    default_device: str = "cpu"
    fallback_to_cpu: bool = True
    strict_checks: bool = False
    log_level: str = "INFO"
    deterministic: bool = False
    seed: int | None = None


def _from_env() -> RuntimeConfig:
    cfg = RuntimeConfig(
        default_device=_normalize_device(os.environ.get("TENSOR_DEVICE")),
        fallback_to_cpu=_parse_bool("TENSOR_FALLBACK_TO_CPU", os.environ.get("TENSOR_FALLBACK_TO_CPU"), True),
        strict_checks=_parse_bool("TENSOR_STRICT_CHECKS", os.environ.get("TENSOR_STRICT_CHECKS"), False),
        log_level=_normalize_log_level(os.environ.get("TENSOR_LOG_LEVEL")),
        deterministic=_parse_bool("TENSOR_DETERMINISTIC", os.environ.get("TENSOR_DETERMINISTIC"), False),
        seed=_parse_int("TENSOR_SEED", os.environ.get("TENSOR_SEED")),
    )
    if cfg.seed is not None and cfg.seed < 0:
        raise ConfigurationError("TENSOR_SEED must be >= 0")
    return cfg


_LOCK = threading.Lock()
_CACHED_CFG: RuntimeConfig | None = None
_CACHED_ENV_KEY: tuple[str | None, ...] | None = None


def _env_key() -> tuple[str | None, ...]:
    return tuple(os.environ.get(k) for k in _ENV_KEYS)


def get_runtime_config(reload: bool = False) -> RuntimeConfig:
    global _CACHED_CFG, _CACHED_ENV_KEY
    key = _env_key()
    with _LOCK:
        if reload or _CACHED_CFG is None or _CACHED_ENV_KEY != key:
            _CACHED_CFG = _from_env()
            _CACHED_ENV_KEY = key
        return _CACHED_CFG


def reset_runtime_config_cache() -> None:
    global _CACHED_CFG, _CACHED_ENV_KEY
    with _LOCK:
        _CACHED_CFG = None
        _CACHED_ENV_KEY = None

