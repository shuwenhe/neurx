import os
import random

import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from neurx.nn import Linear
from neurx.optim import AdamW
from neurx.serialization import load_checkpoint, save_checkpoint
from neurx.neurx import Tensor


def _train_one_step(model, optimizer):
    x = Tensor(np.random.randn(4, 3), requires_grad=False)
    y = model(x).mean()
    optimizer.zero_grad()
    y.backward()
    optimizer.step()


def test_checkpoint_roundtrip_model_optimizer(tmp_path):
    np.random.seed(0)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    _train_one_step(model, optimizer)

    ckpt_path = tmp_path / "run.ckpt"
    save_checkpoint(
        ckpt_path,
        model=model,
        optimizer=optimizer,
        step=12,
        epoch=3,
        metadata={"run_id": "unit-test"},
    )

    restored_model = Linear(3, 2)
    restored_optimizer = AdamW(restored_model.parameters(), lr=1e-3)
    loaded = load_checkpoint(ckpt_path, model=restored_model, optimizer=restored_optimizer)

    src_state = model.state_dict()
    dst_state = restored_model.state_dict()
    for key in src_state:
        assert np.allclose(src_state[key], dst_state[key])

    src_opt = optimizer.state_dict()
    dst_opt = restored_optimizer.state_dict()
    assert src_opt["step_count"] == dst_opt["step_count"]
    for src_m, dst_m in zip(src_opt["m"], dst_opt["m"]):
        assert np.allclose(src_m, dst_m)
    for src_v, dst_v in zip(src_opt["v"], dst_opt["v"]):
        assert np.allclose(src_v, dst_v)

    assert loaded["training"]["step"] == 12
    assert loaded["training"]["epoch"] == 3
    assert loaded["metadata"]["run_id"] == "unit-test"


def test_checkpoint_restores_rng_state(tmp_path):
    np.random.seed(123)
    random.seed(123)

    # Advance RNG once so the saved state is not the default initial state.
    _ = np.random.rand()
    _ = random.random()

    ckpt_path = tmp_path / "rng.ckpt"
    save_checkpoint(ckpt_path)

    expected_np = np.random.rand()
    expected_py = random.random()

    np.random.seed(999)
    random.seed(999)
    _ = np.random.rand()
    _ = random.random()

    load_checkpoint(ckpt_path, restore_rng_state=True)

    assert np.isclose(np.random.rand(), expected_np)
    assert random.random() == expected_py


def test_checkpoint_validates_serializable_objects(tmp_path):
    ckpt_path = tmp_path / "bad.ckpt"

    class BadModel:
        pass

    try:
        save_checkpoint(ckpt_path, model=BadModel())
    except TypeError as exc:
        assert "state_dict" in str(exc)
    else:
        raise AssertionError("expected TypeError for model without state_dict")
