import json
import os

import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from neurx.data import DataLoader
from neurx.nn import Linear
from neurx.optim import AdamW
from neurx.neurx import Tensor
from neurx.training import CheckpointManager, GradScaler, TrainingLogger, run_training_loop


def _build_batches(n=12, d=3):
    return [np.random.randn(d).astype(np.float64) for _ in range(n)]


def _step_fn(model, batch):
    if not isinstance(batch, Tensor):
        batch = Tensor(np.asarray(batch))
    out = model(batch)
    return (out * out).mean()


def test_training_loop_emits_logs_and_checkpoints(tmp_path):
    np.random.seed(0)
    dataset = _build_batches(16, 3)
    loader = DataLoader(dataset, batch_size=4, shuffle=False)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)

    log_path = tmp_path / "train.jsonl"
    logger = TrainingLogger(log_path=log_path)
    manager = CheckpointManager(tmp_path / "ckpt", max_to_keep=2)

    result = run_training_loop(
        model=model,
        optimizer=optimizer,
        dataloader=loader,
        step_fn=_step_fn,
        epochs=1,
        checkpoint_manager=manager,
        checkpoint_interval=2,
        logger=logger,
    )

    assert result["epoch"] == 1
    assert result["step"] == 4
    assert log_path.exists()
    assert manager.latest_ckpt_path.exists()

    lines = [line for line in log_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert len(lines) == 4
    sample = json.loads(lines[0])
    assert "loss" in sample
    assert "lr" in sample
    assert "grad_norm" in sample
    assert "step_time_ms" in sample
    assert "throughput" in sample


def test_training_loop_resume_from_latest(tmp_path):
    np.random.seed(0)
    dataset = _build_batches(16, 3)
    loader = DataLoader(dataset, batch_size=4, shuffle=False)
    manager = CheckpointManager(tmp_path / "ckpt", max_to_keep=3)

    model_a = Linear(3, 2)
    optimizer_a = AdamW(model_a.parameters(), lr=1e-3)
    first = run_training_loop(
        model=model_a,
        optimizer=optimizer_a,
        dataloader=loader,
        step_fn=_step_fn,
        epochs=1,
        checkpoint_manager=manager,
        checkpoint_interval=2,
    )
    assert first["step"] == 4

    model_b = Linear(3, 2)
    optimizer_b = AdamW(model_b.parameters(), lr=1e-3)
    second = run_training_loop(
        model=model_b,
        optimizer=optimizer_b,
        dataloader=loader,
        step_fn=_step_fn,
        epochs=2,
        checkpoint_manager=manager,
        checkpoint_interval=2,
        resume=True,
    )

    assert second["epoch"] == 2
    assert second["step"] > first["step"]


def test_training_loop_with_autocast_and_scaler(tmp_path):
    np.random.seed(0)
    dataset = _build_batches(8, 3)
    loader = DataLoader(dataset, batch_size=4, shuffle=False)
    manager = CheckpointManager(tmp_path / "ckpt", max_to_keep=2)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    scaler = GradScaler(init_scale=64.0, growth_interval=1)

    result = run_training_loop(
        model=model,
        optimizer=optimizer,
        dataloader=loader,
        step_fn=_step_fn,
        epochs=1,
        checkpoint_manager=manager,
        checkpoint_interval=1,
        checkpoint_every_n_epochs=1,
        use_autocast=True,
        scaler=scaler,
    )

    assert result["step"] == 2
    assert manager.latest_ckpt_path.exists()
    assert scaler.scale >= 64.0
