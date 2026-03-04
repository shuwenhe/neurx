from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

from neurx.serialization import load_checkpoint, save_checkpoint


class CheckpointManager:
    def __init__(
        self,
        directory: str | os.PathLike[str],
        *,
        prefix: str = "checkpoint",
        max_to_keep: int | None = None,
        keep_last_n: int | None = None,
        keep_every_n_steps: int = 0,
        metric_name: str = "loss",
        mode: str = "min",
        save_best_only: bool = False,
    ):
        if keep_last_n is None:
            keep_last_n = max_to_keep if max_to_keep is not None else 5
        if keep_last_n < 1:
            raise ValueError("keep_last_n must be >= 1")
        if keep_every_n_steps < 0:
            raise ValueError("keep_every_n_steps must be >= 0")
        if mode not in ("min", "max"):
            raise ValueError("mode must be one of {'min', 'max'}")
        self.directory = Path(directory)
        self.prefix = prefix
        self.keep_last_n = int(keep_last_n)
        self.keep_every_n_steps = int(keep_every_n_steps)
        self.metric_name = metric_name
        self.mode = mode
        self.save_best_only = bool(save_best_only)
        self.directory.mkdir(parents=True, exist_ok=True)

    @property
    def latest_ckpt_path(self) -> Path:
        return self.directory / "latest.ckpt"

    @property
    def best_ckpt_path(self) -> Path:
        return self.directory / "best.ckpt"

    def _step_ckpt_path(self, step: int) -> Path:
        return self.directory / f"{self.prefix}-step{int(step):08d}.ckpt"

    def _copy_latest(self, source: Path) -> None:
        tmp = self.latest_ckpt_path.with_suffix(".tmp")
        with open(source, "rb") as src, open(tmp, "wb") as dst:
            dst.write(src.read())
            dst.flush()
            os.fsync(dst.fileno())
        os.replace(tmp, self.latest_ckpt_path)

    def _is_better(self, metric: float, best_metric: float) -> bool:
        if self.mode == "min":
            return metric < best_metric
        return metric > best_metric

    def _current_best_metric(self) -> float | None:
        if not self.best_ckpt_path.exists():
            return None
        best = load_checkpoint(self.best_ckpt_path, restore_rng_state=False)
        metrics = best.get("metrics") or {}
        if self.metric_name not in metrics:
            return None
        return float(metrics[self.metric_name])

    def _maybe_update_best(self, source: Path, metrics: dict[str, Any]) -> None:
        if self.metric_name not in metrics:
            return
        metric = float(metrics[self.metric_name])
        best_metric = self._current_best_metric()
        if best_metric is None or self._is_better(metric, best_metric):
            tmp = self.best_ckpt_path.with_suffix(".tmp")
            with open(source, "rb") as src, open(tmp, "wb") as dst:
                dst.write(src.read())
                dst.flush()
                os.fsync(dst.fileno())
            os.replace(tmp, self.best_ckpt_path)

    def _list_step_checkpoints(self) -> list[Path]:
        return sorted(self.directory.glob(f"{self.prefix}-step*.ckpt"))

    def _extract_step(self, path: Path) -> int | None:
        m = re.search(r"step(\d+)\.ckpt$", path.name)
        if m is None:
            return None
        return int(m.group(1))

    def _prune(self) -> None:
        checkpoints = self._list_step_checkpoints()
        if len(checkpoints) <= self.keep_last_n:
            return
        keep = set(checkpoints[-self.keep_last_n :])
        if self.keep_every_n_steps > 0:
            for p in checkpoints:
                step = self._extract_step(p)
                if step is not None and step % self.keep_every_n_steps == 0:
                    keep.add(p)
        for p in checkpoints:
            if p not in keep and p.exists():
                p.unlink()

    def save(
        self,
        *,
        model=None,
        optimizer=None,
        scaler=None,
        step: int,
        epoch: int | None = None,
        metrics: dict[str, Any] | None = None,
        metadata: dict[str, Any] | None = None,
        extra_state: dict[str, Any] | None = None,
        include_rng_state: bool = True,
    ) -> dict[str, Any]:
        metrics = dict(metrics or {})
        best_metric = self._current_best_metric()
        metric = float(metrics[self.metric_name]) if self.metric_name in metrics else None
        improved = metric is not None and (best_metric is None or self._is_better(metric, best_metric))
        save_step_ckpt = not self.save_best_only or improved

        target = self._step_ckpt_path(step) if save_step_ckpt else self.latest_ckpt_path
        payload = save_checkpoint(
            target,
            model=model,
            optimizer=optimizer,
            scaler=scaler,
            step=step,
            epoch=epoch,
            metrics=metrics,
            metadata=metadata,
            extra_state=extra_state,
            include_rng_state=include_rng_state,
        )

        if save_step_ckpt:
            self._copy_latest(target)
        if improved:
            self._maybe_update_best(target, metrics)
        if save_step_ckpt:
            self._prune()
        return payload

    def load_latest(self, *, model=None, optimizer=None, scaler=None, strict: bool = True) -> dict[str, Any] | None:
        if not self.latest_ckpt_path.exists():
            return None
        ckpt = load_checkpoint(
            self.latest_ckpt_path,
            model=model,
            optimizer=optimizer,
            scaler=scaler,
            strict=strict,
            restore_rng_state=True,
        )
        return ckpt

    def load_best(self, *, model=None, optimizer=None, scaler=None, strict: bool = True) -> dict[str, Any] | None:
        if not self.best_ckpt_path.exists():
            return None
        ckpt = load_checkpoint(
            self.best_ckpt_path,
            model=model,
            optimizer=optimizer,
            scaler=scaler,
            strict=strict,
            restore_rng_state=False,
        )
        return ckpt
