from __future__ import annotations

import time
from typing import Any

import numpy as np

from tensor.training.amp import autocast
from tensor.training.logging import TrainingLogger


def _infer_batch_size(batch) -> int:
    if hasattr(batch, "shape"):
        shape = getattr(batch, "shape")
        if shape:
            return int(shape[0])
    if isinstance(batch, np.ndarray):
        return int(batch.shape[0]) if batch.ndim > 0 else 1
    if isinstance(batch, (list, tuple)):
        if len(batch) == 0:
            return 0
        return _infer_batch_size(batch[0])
    if isinstance(batch, dict):
        for value in batch.values():
            return _infer_batch_size(value)
    return 1


def _global_grad_norm(params) -> float:
    total = 0.0
    for p in params:
        grad = getattr(p, "grad", None)
        if grad is None:
            continue
        total += float((grad ** 2).sum())
    return float(total ** 0.5)


def run_training_loop(
    *,
    model,
    optimizer,
    dataloader,
    step_fn,
    epochs: int,
    checkpoint_manager=None,
    checkpoint_interval: int = 0,
    checkpoint_at_epoch_end: bool = True,
    checkpoint_every_n_epochs: int = 1,
    logger: TrainingLogger | None = None,
    resume: bool = False,
    scaler=None,
    use_autocast: bool = False,
    autocast_dtype=np.float16,
    strict_load: bool = True,
) -> dict[str, Any]:
    if epochs < 1:
        raise ValueError("epochs must be >= 1")
    if checkpoint_interval < 0:
        raise ValueError("checkpoint_interval must be >= 0")
    if checkpoint_every_n_epochs < 1:
        raise ValueError("checkpoint_every_n_epochs must be >= 1")

    training_logger = logger or TrainingLogger(log_path=None)
    start_epoch = 0
    global_step = 0

    if resume and checkpoint_manager is not None:
        ckpt = checkpoint_manager.load_latest(model=model, optimizer=optimizer, scaler=scaler, strict=strict_load)
        if ckpt is not None:
            training = ckpt.get("training") or {}
            start_epoch = int(training.get("epoch") or 0)
            global_step = int(training.get("step") or 0)

    model.train()
    for epoch in range(start_epoch, epochs):
        last_loss_value = None
        for batch in dataloader:
            t0 = time.perf_counter()
            optimizer.zero_grad()

            with autocast(enabled=use_autocast, dtype=autocast_dtype):
                loss = step_fn(model, batch)
            if hasattr(loss, "backward"):
                if scaler is not None:
                    scaled = scaler.scale_loss(loss)
                    scaled.backward()
                else:
                    loss.backward()
                loss_value = float(loss.item())
            else:
                loss_value = float(loss)

            grad_norm = _global_grad_norm(model.parameters())
            if scaler is not None:
                scaler.step(optimizer)
            else:
                optimizer.step()
            global_step += 1

            elapsed = max(time.perf_counter() - t0, 1e-12)
            batch_size = _infer_batch_size(batch)
            metrics = {
                "loss": loss_value,
                "lr": float(getattr(optimizer, "lr", 0.0)),
                "grad_norm": grad_norm,
                "step_time_ms": elapsed * 1000.0,
                "throughput": float(batch_size) / elapsed,
            }
            last_loss_value = loss_value
            training_logger.log(step=global_step, epoch=epoch + 1, metrics=metrics)

            if checkpoint_manager is not None and checkpoint_interval > 0 and (global_step % checkpoint_interval == 0):
                checkpoint_manager.save(
                    model=model,
                    optimizer=optimizer,
                    scaler=scaler,
                    step=global_step,
                    epoch=epoch + 1,
                    metrics=metrics,
                )

        if (
            checkpoint_manager is not None
            and checkpoint_at_epoch_end
            and ((epoch + 1) % checkpoint_every_n_epochs == 0)
        ):
            checkpoint_manager.save(
                model=model,
                optimizer=optimizer,
                scaler=scaler,
                step=global_step,
                epoch=epoch + 1,
                metrics={"loss": last_loss_value} if last_loss_value is not None else {},
            )

    return {
        "epoch": epochs,
        "step": global_step,
    }
