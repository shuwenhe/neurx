import numpy as np

from neurx import Tensor
from neurx.compile import CompileOptions, compile_module
from neurx.distributed import detect_distributed_config, is_distributed
from neurx.nn import Linear


def test_compile_module_behaves_like_eager():
    layer = Linear(3, 2)
    compiled = compile_module(layer, CompileOptions(backend="eager", mode="default"))
    x = Tensor(np.random.randn(4, 3), requires_grad=False)
    y1 = layer(x).to_numpy()
    y2 = compiled(x).to_numpy()
    assert np.allclose(y1, y2)


def test_detect_distributed_config(monkeypatch):
    monkeypatch.setenv("WORLD_SIZE", "4")
    monkeypatch.setenv("RANK", "2")
    monkeypatch.setenv("LOCAL_RANK", "0")
    monkeypatch.setenv("MASTER_ADDR", "127.0.0.1")
    monkeypatch.setenv("MASTER_PORT", "29501")
    monkeypatch.setenv("TENSOR_DIST_BACKEND", "gloo")
    cfg = detect_distributed_config()
    assert cfg.world_size == 4
    assert cfg.rank == 2
    assert cfg.local_rank == 0
    assert cfg.backend == "gloo"
    assert is_distributed(cfg)

