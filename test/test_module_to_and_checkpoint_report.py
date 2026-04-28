import pickle
import numpy as np
import pytest

from neurx import nn
from neurx.neurx import Tensor
from neurx.serialization import save_checkpoint, load_checkpoint


class TinyModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(3, 4)
        self.blocks = nn.Sequential(nn.Linear(4, 2))
        self.register_buffer("running_np", np.ones((4,), dtype=np.float64))
        self.register_buffer("running_tensor", Tensor(np.ones((4,), dtype=np.float64)))

    def forward(self, x):
        return self.blocks(self.fc1(x))


def test_module_to_recursive_dtype_and_buffers():
    model = TinyModel()

    model.to(device="cpu", dtype=np.float32)

    for p in model.parameters():
        assert p.data.dtype == np.float32
        assert p.device == "cpu"

    assert model.running_np.dtype == np.float32
    assert isinstance(model.running_tensor, Tensor)
    assert model.running_tensor.dtype == np.float32
    assert model.running_tensor.device == "cpu"

    model.double()
    for p in model.parameters():
        assert p.data.dtype == np.float64

    model.half()
    for p in model.parameters():
        assert p.data.dtype == np.float16

    model.type(np.float32)
    for p in model.parameters():
        assert p.data.dtype == np.float32


def test_checkpoint_load_report_non_strict(tmp_path):
    model = TinyModel()
    ckpt_path = tmp_path / "phase3.ckpt"
    save_checkpoint(ckpt_path, model=model, step=1, epoch=1)

    with open(ckpt_path, "rb") as f:
        raw = pickle.load(f)

    keys = list(raw["model_state"].keys())
    removed_key = keys[0]
    raw["model_state"].pop(removed_key)
    raw["model_state"]["unexpected.key"] = np.array([1.0], dtype=np.float32)

    with open(ckpt_path, "wb") as f:
        pickle.dump(raw, f)

    restored = TinyModel()
    loaded = load_checkpoint(ckpt_path, model=restored, strict=False)

    report = loaded["load_report"]
    assert report["strict"] is False
    assert report["model"]["loaded"] is True
    assert removed_key in report["model"]["missing_keys"]
    assert "unexpected.key" in report["model"]["unexpected_keys"]
    assert report["model"]["error"] is None


def test_checkpoint_strict_raises_with_reportable_mismatch(tmp_path):
    model = TinyModel()
    ckpt_path = tmp_path / "phase3_strict.ckpt"
    save_checkpoint(ckpt_path, model=model, step=2, epoch=1)

    with open(ckpt_path, "rb") as f:
        raw = pickle.load(f)

    raw["model_state"].pop(next(iter(raw["model_state"])))

    with open(ckpt_path, "wb") as f:
        pickle.dump(raw, f)

    restored = TinyModel()
    with pytest.raises(RuntimeError):
        load_checkpoint(ckpt_path, model=restored, strict=True)
