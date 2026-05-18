from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_serving_vllm_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("serving/vllm/vllm", "new_vllm_runtime_state"):
        return

    state = runtime.invoke_runtime_function(
        "serving/vllm/vllm",
        "new_vllm_runtime_state",
        2,
        16,
        4,
        8,
        64,
        "srpt",
    )

    state = runtime.invoke_runtime_function(
        "serving/vllm/vllm",
        "vllm_runtime_enqueue_request",
        state,
        "req-1",
        5,
        8,
        True,
    )
    state = runtime.invoke_runtime_function(
        "serving/vllm/vllm",
        "vllm_runtime_enqueue_request",
        state,
        "req-2",
        3,
        2,
        True,
    )

    depth = runtime.invoke_runtime_function("serving/vllm/vllm", "vllm_runtime_queue_depth", state)
    assert depth == 2

    step = runtime.invoke_runtime_function("serving/vllm/vllm", "vllm_runtime_schedule_next", state)
    assert step["selected"] is True
    assert step["request_id"] != ""

    next_state = runtime.invoke_runtime_function("serving/vllm/vllm", "vllm_runtime_record_decode", step["state"], 2)
    done_state = runtime.invoke_runtime_function("serving/vllm/vllm", "vllm_runtime_finish_request", next_state, 4)
    assert done_state["metrics"]["completed"] >= 1
