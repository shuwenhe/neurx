from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_distributed_tp_shard_spec_runtime():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("distributed/tp", "new_tp_state"):
        return

    state = runtime.invoke_runtime_function("distributed/tp", "new_tp_state", 4, 2, -1)
    assert state["world_size"] == 4
    assert state["rank"] == 2
    assert runtime.invoke_runtime_function("distributed/tp", "tp_enabled", state) is True

    shard = runtime.invoke_runtime_function("distributed/tp", "tp_compute_shard", state, 10)
    assert shard["start"] == 6
    assert shard["end"] == 9
    assert shard["padded_size"] == 3

    restored = runtime.invoke_runtime_function("distributed/tp", "tp_load_state_dict", state, state)
    assert restored["world_size"] == state["world_size"]

    if not runtime.supports_runtime_function("distributed/tp_collective", "new_tp_collective_state"):
        return
    if not runtime.supports_runtime_function("distributed/comm", "new_process_group"):
        return

    pg = runtime.invoke_runtime_function("distributed/comm", "new_process_group", "nccl", 2, 4)
    collective = runtime.invoke_runtime_function("distributed/tp_collective", "new_tp_collective_state", state, pg)
    reduced = runtime.invoke_runtime_function("distributed/tp_collective", "tp_all_reduce_sum", collective, [1.0, 2.0])
    gathered = runtime.invoke_runtime_function("distributed/tp_collective", "tp_all_gather", collective, [3.0])

    assert len(reduced) == 2
    assert reduced[0] == 4.0
    assert len(gathered) == 4
