import os

import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from neurx.nn import Linear
from neurx.optim import AdamW
from neurx.training import CheckpointManager
from neurx.neurx import Tensor


def _step_once(model, optimizer):
    x = Tensor(np.random.randn(4, 3))
    loss = model(x).mean()
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()


def test_checkpoint_manager_rotation_and_latest(tmp_path):
    np.random.seed(0)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    manager = CheckpointManager(tmp_path, max_to_keep=2, metric_name="loss", mode="min")

    for step in (1, 2, 3):
        _step_once(model, optimizer)
        manager.save(model=model, optimizer=optimizer, step=step, epoch=1, metrics={"loss": float(4 - step)})

    files = sorted(tmp_path.glob("checkpoint-step*.ckpt"))
    assert len(files) == 2
    assert files[0].name.endswith("00000002.ckpt")
    assert files[1].name.endswith("00000003.ckpt")
    assert manager.latest_ckpt_path.exists()
    assert manager.best_ckpt_path.exists()


def test_checkpoint_manager_resume_latest(tmp_path):
    np.random.seed(0)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    manager = CheckpointManager(tmp_path, max_to_keep=3)

    _step_once(model, optimizer)
    manager.save(model=model, optimizer=optimizer, step=7, epoch=2, metrics={"loss": 1.25})

    restored_model = Linear(3, 2)
    restored_optimizer = AdamW(restored_model.parameters(), lr=1e-3)
    ckpt = manager.load_latest(model=restored_model, optimizer=restored_optimizer)

    assert ckpt is not None
    assert ckpt["training"]["step"] == 7
    assert ckpt["training"]["epoch"] == 2
    assert np.isclose(ckpt["metrics"]["loss"], 1.25)


def test_checkpoint_manager_keep_every_n_steps(tmp_path):
    np.random.seed(0)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    manager = CheckpointManager(tmp_path, keep_last_n=2, keep_every_n_steps=3)

    for step in range(1, 8):
        _step_once(model, optimizer)
        manager.save(model=model, optimizer=optimizer, step=step, epoch=1, metrics={"loss": float(step)})

    steps = []
    for p in sorted(tmp_path.glob("checkpoint-step*.ckpt")):
        name = p.name
        n = int(name.split("step", 1)[1].split(".ckpt", 1)[0])
        steps.append(n)
    # keep last 2 (6,7) plus multiples of 3 (3,6)
    assert steps == [3, 6, 7]


def test_checkpoint_manager_save_best_only(tmp_path):
    np.random.seed(0)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    manager = CheckpointManager(tmp_path, save_best_only=True, metric_name="loss", mode="min")

    manager.save(model=model, optimizer=optimizer, step=1, epoch=1, metrics={"loss": 2.0})
    manager.save(model=model, optimizer=optimizer, step=2, epoch=1, metrics={"loss": 3.0})
    manager.save(model=model, optimizer=optimizer, step=3, epoch=1, metrics={"loss": 1.0})

    steps = sorted(tmp_path.glob("checkpoint-step*.ckpt"))
    assert len(steps) == 2
    assert steps[0].name.endswith("00000001.ckpt")
    assert steps[1].name.endswith("00000003.ckpt")
    best = manager.load_best()
    assert np.isclose(best["metrics"]["loss"], 1.0)
