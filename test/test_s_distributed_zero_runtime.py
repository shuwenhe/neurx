from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_distributed_zero_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("distributed/zero", "new_zero_state"):
        return
    if not runtime.supports_runtime_function("distributed/comm", "new_process_group"):
        return

    state = runtime.invoke_runtime_function(
        "distributed/zero",
        "new_zero_state",
        "zero-demo",
        "nccl",
        4,
        1,
        2,
        32,
        "zero-2",
    )
    assert runtime.invoke_runtime_function("distributed/zero", "zero_enabled", state) is True
    assert runtime.invoke_runtime_function("distributed/zero", "zero_optimizer_sharded", state) is True
    assert runtime.invoke_runtime_function("distributed/zero", "zero_name", state) == "zero-demo"
    assert runtime.invoke_runtime_function("distributed/zero", "zero_stage", state) == "zero-2"

    state = runtime.invoke_runtime_function("distributed/zero", "zero_add_param", state, "w1", 128)
    state = runtime.invoke_runtime_function("distributed/zero", "zero_mark_grad_ready", state, "w1")
    reduced = runtime.invoke_runtime_function("distributed/zero", "zero_reduce_scatter_grads", state, [1.0, 2.0, 3.0, 4.0])
    gathered = runtime.invoke_runtime_function("distributed/zero", "zero_all_gather_params", state, [5.0, 6.0])

    assert reduced == [4.0]
    assert gathered == [5.0, 6.0, 5.0, 6.0, 5.0, 6.0, 5.0, 6.0]

    state = runtime.invoke_runtime_function("distributed/zero", "zero_mark_reduced", state)
    state = runtime.invoke_runtime_function("distributed/zero", "zero_mark_gathered", state)
    state = runtime.invoke_runtime_function("distributed/zero", "zero_finalize_step", state)
    assert runtime.invoke_runtime_function("distributed/zero", "zero_ready_param_count", state) == 0
