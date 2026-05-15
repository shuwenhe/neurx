from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_infer_admission_prefix_cache_and_multi_request_flow():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("infer/serve/admission_control", "new_admission_control_state"):
        return
    if not runtime.supports_runtime_function("infer/cache/prefix_cache", "new_prefix_cache_state"):
        return

    admission = runtime.invoke_runtime_function("infer/serve/admission_control", "new_admission_control_state_with_policy", 1, 8, "srpt")
    assert runtime.invoke_runtime_function("infer/serve/admission_control", "admission_can_enqueue", admission, 0, 4) is True
    assert runtime.invoke_runtime_function("infer/serve/admission_control", "admission_can_enqueue", admission, 1, 4) is False
    assert runtime.invoke_runtime_function("infer/serve/admission_control", "admission_can_enqueue_with_remaining", admission, 0, 4, 64) is False
    assert runtime.invoke_runtime_function("infer/serve/admission_control", "admission_should_preempt", admission, 16, 8) is True
    assert runtime.invoke_runtime_function("infer/serve/admission_control", "admission_should_preempt", admission, 8, 16) is False

    accepted = runtime.invoke_runtime_function("infer/serve/admission_control", "admission_on_enqueue", admission, 4, True)
    rejected = runtime.invoke_runtime_function("infer/serve/admission_control", "admission_on_enqueue", accepted, 4, False)
    assert accepted["admitted"] == 1
    assert rejected["rejected"] == 1
    assert accepted["last_priority_score"] >= 0

    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "new_prefix_cache_state", 2, 16)
    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "prefix_cache_lookup_with_key", prefix, "req-a", 4)
    assert prefix["misses"] == 1
    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "prefix_cache_insert_with_key", prefix, "req-a", 4)
    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "prefix_cache_lookup_with_key", prefix, "req-a", 4)
    assert prefix["hits"] == 1
    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "prefix_cache_insert_with_key", prefix, "req-b", 3)
    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "prefix_cache_lookup_with_key", prefix, "req-b", 3)
    assert prefix["hits"] == 2
    prefix = runtime.invoke_runtime_function("infer/cache/prefix_cache", "prefix_cache_lookup_with_key", prefix, "req-b", 4)
    assert prefix["misses"] == 2

    if not runtime.supports_runtime_function("infer", "new_infer_pipeline_state"):
        return

    first = runtime.invoke_runtime_function("infer", "new_infer_pipeline_state", "req-a", "demo", 4, 2, 2, 32)
    second = runtime.invoke_runtime_function("infer", "new_infer_pipeline_state", "req-b", "demo", 1000, 2, 2, 32)

    assert first["response"]["status"] == 200
    assert second["response"]["status"] in (200, 429)

    stepped = runtime.invoke_runtime_function("infer", "infer_pipeline_step", first, 3)
    assert stepped["decode"]["step"] == 1
    assert stepped["batch"]["decode_tokens"] >= 1

    if runtime.supports_runtime_function("infer", "infer_pipeline_enqueue_request"):
        queued = runtime.invoke_runtime_function("infer", "infer_pipeline_enqueue_request", stepped, "req-c", 2, 1)
        depth = runtime.invoke_runtime_function("infer", "infer_pipeline_queue_depth", queued)
        assert depth >= 0
        if runtime.supports_runtime_function("infer", "infer_pipeline_to_vllm_runtime"):
            vstate = runtime.invoke_runtime_function("infer", "infer_pipeline_to_vllm_runtime", queued)
            vdepth = runtime.invoke_runtime_function("infer/vllm/vllm", "vllm_runtime_queue_depth", vstate)
            assert depth == vdepth
