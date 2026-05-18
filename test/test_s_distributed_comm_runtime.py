from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_distributed_comm_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("distributed/comm", "new_process_group"):
        return

    state = runtime.invoke_runtime_function("distributed/comm", "new_process_group", "gloo", 1, 4)
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_is_ready", state) is True
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_last_peer", state) == 0
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_send_count", state) == 0
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_recv_count", state) == 0

    broadcasted = runtime.invoke_runtime_function("distributed/comm", "broadcast", state, 0, [9.0, 8.0])
    assert broadcasted == [9.0, 8.0]
    assert runtime.invoke_runtime_function("distributed/comm", "all_reduce_max", state, [1.0, 2.0]) == [1.0, 2.0]
    assert runtime.invoke_runtime_function("distributed/comm", "all_reduce_min", state, [1.0, 2.0]) == [1.0, 2.0]
    assert runtime.invoke_runtime_function("distributed/comm", "all_reduce_prod", state, [1.0, 2.0]) == [1.0, 2.0]
    assert runtime.invoke_runtime_function("distributed/comm", "all_to_all", state, [1.0, 2.0, 3.0, 4.0]) == [1.0, 2.0, 3.0, 4.0]

    state = runtime.invoke_runtime_function("distributed/comm", "p2p_send", state, 2, [3.0, 5.0, 7.0])
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_last_peer", state) == 2
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_send_count", state) == 1
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_last_payload", state) == [3.0, 5.0, 7.0]

    recv = runtime.invoke_runtime_function("distributed/comm", "p2p_recv", state, 2, 2)
    assert recv == [3.0, 5.0]
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_recv_count", state) == 0

    state = runtime.invoke_runtime_function("distributed/comm", "process_group_reset", state)
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_send_count", state) == 0
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_last_payload", state) == []

    state = runtime.invoke_runtime_function("distributed/comm", "destroy_process_group", state)
    assert runtime.invoke_runtime_function("distributed/comm", "process_group_initialized", state) is False
