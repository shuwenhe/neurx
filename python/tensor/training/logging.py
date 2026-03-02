from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from tensor.platform import get_logger


class TrainingLogger:
    def __init__(self, log_path: str | os.PathLike[str] | None = None, *, logger_name: str = "training"):
        self._logger = get_logger(logger_name)
        self.log_path = Path(log_path) if log_path is not None else None
        if self.log_path is not None:
            self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log(self, *, step: int, epoch: int | None = None, metrics: dict[str, Any] | None = None) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "timestamp": time.time(),
            "step": int(step),
            "epoch": int(epoch) if epoch is not None else None,
        }
        if metrics:
            payload.update(metrics)

        compact = ", ".join(f"{k}={v}" for k, v in payload.items() if k != "timestamp")
        self._logger.info(compact)

        if self.log_path is not None:
            with open(self.log_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(payload, ensure_ascii=True, separators=(",", ":")))
                f.write("\n")
        return payload
