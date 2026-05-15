from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_infer_vllm_runtime_state_machine_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("infer/vllm/vllm", "new_vllm_runtime_state"):
        return

    state = runtime.invoke_runtime_function(
        "infer/vllm/vllm",
        "new_vllm_runtime_state",
        2,
        16,
        4,
        8,
        64,
        "srpt",
    )

    state = runtime.invoke_runtime_function(
        "infer/vllm/vllm",
        "vllm_runtime_enqueue_request",
        state,
        "req-1",
        5,
        8,
        True,
    )
    state = runtime.invoke_runtime_function(
        "infer/vllm/vllm",
        "vllm_runtime_enqueue_request",
        state,
        "req-2",
        3,
        2,
        True,
    )

    depth = runtime.invoke_runtime_function("infer/vllm/vllm", "vllm_runtime_queue_depth", state)
    assert depth == 2

    step = runtime.invoke_runtime_function("infer/vllm/vllm", "vllm_runtime_schedule_next", state)
    assert step["selected"] is True
    assert step["request_id"] != ""

    next_state = runtime.invoke_runtime_function("infer/vllm/vllm", "vllm_runtime_record_decode", step["state"], 2)
    done_state = runtime.invoke_runtime_function("infer/vllm/vllm", "vllm_runtime_finish_request", next_state, 4)
    assert done_state["metrics"]["completed"] >= 1


def test_s_infer_pipeline_vllm_bridge_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("infer", "new_infer_pipeline_state"):
        return
    if not runtime.supports_runtime_function("infer", "infer_pipeline_to_vllm_runtime"):
        return

    pipeline = runtime.invoke_runtime_function("infer", "new_infer_pipeline_state", "req-main", "demo", 4, 6, 2, 64)
    vstate = runtime.invoke_runtime_function("infer", "infer_pipeline_to_vllm_runtime", pipeline)
    assert runtime.invoke_runtime_function("infer/vllm/vllm", "vllm_runtime_queue_depth", vstate) >= 0

    if runtime.supports_runtime_function("infer", "infer_pipeline_vllm_schedule_next"):
        step = runtime.invoke_runtime_function("infer", "infer_pipeline_vllm_schedule_next", pipeline)
        assert "selected" in step

    if runtime.supports_runtime_function("infer", "infer_pipeline_step_from_logits"):
        stepped = runtime.invoke_runtime_function(
            "infer",
            "infer_pipeline_step_from_logits",
            pipeline,
            [0.1, 0.9, 0.2],
            [1, 2],
        )
        assert stepped["decode"]["step"] >= 1
        assert stepped["vllm"]["scheduler"]["tick"] >= 1
