import numpy as np

from neurx import Tensor
from neurx.compile import CompileOptions, compile_module
from neurx.distributed import detect_distributed_config, is_distributed
from neurx.nn import Linear, MLP


def test_compile_module_behaves_like_eager():
    layer = Linear(3, 2)
    compiled = compile_module(layer, CompileOptions(backend="eager", mode="default"))
    assert compiled.stage_state is not None
    assert compiled.compile_state is not None
    assert compiled.stage_state["name"] == "linear"
    assert compiled.stage_state["backend"] == "eager"
    assert compiled.stage_state["mode"] == "default"
    assert compiled.stage_state["jit_enabled"] is True
    assert compiled.stage_state["lowered"] is False
    assert compiled.stage_state["compiled"] is False
    assert compiled.stage_state["executed"] is False
    assert compiled.stage_state["stages"] == ["jit"]
    assert compiled.stage_state["control_enabled"] is False
    assert compiled.stage_state["control_branches"] == []
    assert compiled.compile_state["name"] == "linear"
    assert compiled.compile_state["backend"] == "eager"
    assert compiled.compile_state["mode"] == "default"
    assert compiled.compile_state["captured"] is True
    assert compiled.compile_state["ready"] is True
    assert compiled.compile_state["compiled"] is False
    assert compiled.compile_state["passes"][:2] == ["capture", "normalize"]
    assert compiled.compile_state["nodes"] == ["root"]
    x = Tensor(np.random.randn(4, 3), requires_grad=False)
    y1 = layer(x).to_numpy()
    y2 = compiled(x).to_numpy()
    assert np.allclose(y1, y2)
    assert compiled.stage_state["executed"] is True
    assert compiled.stage_state["lowered"] is True
    assert compiled.stage_state["compiled"] is True
    assert compiled.stage_state["stages"] == ["jit", "lower", "compile", "execute"]
    assert compiled.compile_state["executed"] is True
    snapshot = compiled.state_dict()
    assert snapshot["module"] == "linear"
    assert snapshot["options"]["backend"] == "eager"
    assert snapshot["compiled"] is True
    assert snapshot["executed"] is True
    assert snapshot["graph_ready"] is True
    assert snapshot["graph_linearized"] is False
    restored = compiled.load_state_dict(snapshot)
    assert restored is compiled
    assert compiled.backend == "eager"
    assert compiled.mode == "default"


def test_compile_module_aot_stage_state_progresses():
    layer = Linear(3, 2)
    compiled = compile_module(layer, CompileOptions(backend="aot", mode="max-autotune"))
    assert compiled.stage_state is not None
    assert compiled.compile_state is not None
    assert compiled.stage_state["backend"] == "aot"
    assert compiled.stage_state["mode"] == "max-autotune"
    assert compiled.stage_state["jit_enabled"] is True
    assert compiled.stage_state["lowered"] is True
    assert compiled.stage_state["compiled"] is True
    assert compiled.stage_state["executed"] is False
    assert compiled.stage_state["stages"] == ["jit", "lower", "compile"]
    assert compiled.stage_state["control_enabled"] is True
    assert compiled.stage_state["control_scan_enabled"] is True
    assert compiled.compile_state["compiled"] is True
    assert compiled.compile_state["lowered"] is True
    assert compiled.compile_state["passes"][0] == "capture"
    assert "autotune" in compiled.compile_state["passes"]
    assert "normalize" in compiled.compile_state["passes"]
    assert compiled.compile_state["passes"][-1] == "lower"
    assert "linearized=true" in compiled.compile_state["tags"]
    assert any(tag.startswith("linear_order=") for tag in compiled.compile_state["tags"])
    assert "lowered=graph" in compiled.compile_state["tags"]
    assert any(tag.startswith("lower_graph_edges=") for tag in compiled.compile_state["tags"])
    assert "fused=none" in compiled.compile_state["tags"]
    assert "scan" in compiled.compile_state["tags"]
    x = Tensor(np.random.randn(4, 3), requires_grad=False)
    y = compiled(x).to_numpy()
    assert y.shape == (4, 2)
    assert compiled.stage_state["executed"] is True
    assert compiled.stage_state["stages"] == ["jit", "lower", "compile", "execute"]
    assert compiled.compile_state["executed"] is True
    snapshot2 = compiled.state_dict()
    assert snapshot2["module"] == "linear"
    assert snapshot2["options"]["backend"] == "aot"
    assert snapshot2["lowered"] is True
    assert snapshot2["compiled"] is True
    assert snapshot2["executed"] is True
    assert snapshot2["graph_ready"] is True
    assert snapshot2["graph_linearized"] is True


def test_compile_module_control_flags_reflect_options():
    layer = Linear(3, 2)

    fullgraph = compile_module(layer, CompileOptions(backend="eager", mode="default", fullgraph=True))
    assert fullgraph.stage_state["control_enabled"] is True
    assert fullgraph.stage_state["control_cond_enabled"] is True
    assert fullgraph.stage_state["control_loop_enabled"] is False
    assert fullgraph.stage_state["control_scan_enabled"] is False
    assert fullgraph.stage_state["control_branches"] == ["cond"]

    dynamic = compile_module(layer, CompileOptions(backend="aot", mode="default", dynamic=True))
    assert dynamic.stage_state["control_enabled"] is True
    assert dynamic.stage_state["control_cond_enabled"] is True
    assert dynamic.stage_state["control_loop_enabled"] is True
    assert dynamic.stage_state["control_scan_enabled"] is False
    assert dynamic.stage_state["control_branches"] == ["cond", "while_loop"]

    autotune = compile_module(layer, CompileOptions(backend="aot", mode="max-autotune", fullgraph=True, dynamic=True))
    assert autotune.stage_state["control_enabled"] is True
    assert autotune.stage_state["control_cond_enabled"] is True
    assert autotune.stage_state["control_loop_enabled"] is True
    assert autotune.stage_state["control_scan_enabled"] is True
    assert autotune.stage_state["control_branches"] == ["cond", "while_loop", "scan"]


def test_compile_module_captures_module_tree():
    layer = MLP(8)
    compiled = compile_module(layer, CompileOptions(backend="eager", mode="default"))
    assert compiled.compile_state is not None
    assert compiled.compile_state["node_count"] == 4
    assert compiled.compile_state["nodes"] == ["root", "root.fc1+root.gelu", "root.fc2", "root.dropout"]
    assert any(op.startswith("linear+") for op in compiled.compile_state["ops"])
    assert "fused_activation" not in compiled.compile_state["ops"]
    assert compiled.compile_state["edges"] == [
        "root->root.fc1+root.gelu",
        "root->root.fc2",
        "root->root.dropout",
    ]
    assert compiled.compile_state["params"][0] == "use_swiglu=false"
    assert any("weight:shape=[8, 32]" in param for param in compiled.compile_state["params"])
    x = Tensor(np.random.randn(2, 3, 8), requires_grad=False)
    y = compiled(x).to_numpy()
    assert y.shape == (2, 3, 8)
    assert compiled.compile_state["executed"] is True
    assert compiled.graph_node_count == 4
    assert compiled.graph_edge_count == 3


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
