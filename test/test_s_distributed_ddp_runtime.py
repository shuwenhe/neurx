from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_distributed_ddp_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("distributed/ddp", "new_ddp_state"):
        return
    if not runtime.supports_runtime_function("distributed/comm", "new_process_group"):
        return

    state = runtime.invoke_runtime_function("distributed/ddp", "new_ddp_state", "ddp-demo", 32, False)
    pg = runtime.invoke_runtime_function("distributed/comm", "new_process_group", "gloo", 1, 4)
    state = runtime.invoke_runtime_function("distributed/ddp", "ddp_attach_process_group", state, pg)

    assert runtime.invoke_runtime_function("distributed/ddp", "ddp_process_group_backend", state) == "gloo"
    assert runtime.invoke_runtime_function("distributed/ddp", "ddp_process_group_rank", state) == 1
    assert runtime.invoke_runtime_function("distributed/ddp", "ddp_process_group_world_size", state) == 4
    assert runtime.invoke_runtime_function("distributed/ddp", "ddp_process_group_initialized", state) is True
    assert runtime.invoke_runtime_function("distributed/ddp", "ddp_is_distributed", state) is True
    assert runtime.invoke_runtime_function("distributed/ddp", "ddp_sync_scale", state) == 0.25

    state = runtime.invoke_runtime_function("distributed/ddp", "ddp_add_param", state, "w1", 128)
    state = runtime.invoke_runtime_function("distributed/ddp", "ddp_mark_grad_ready", state, "w1")

    reduced = runtime.invoke_runtime_function("distributed/ddp", "ddp_all_reduce_grad", state, pg, [1.0, 2.0])
    broadcasted = runtime.invoke_runtime_function("distributed/ddp", "ddp_broadcast_params", state, pg, [3.0, 4.0])

    assert reduced == [4.0, 8.0]
    assert broadcasted == [3.0, 4.0]
