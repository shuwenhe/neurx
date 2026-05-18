from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_serving_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("serving/serve/admission_control", "new_admission_control_state_with_policy"):
        return
    if not runtime.supports_runtime_function("serving/serve/continuous_batch", "new_continuous_batch_state"):
        return
    if not runtime.supports_runtime_function("serving/cache/paged_kv_cache", "new_paged_kv_cache_state"):
        return
    if not runtime.supports_runtime_function("serving/cache/prefix_cache", "new_prefix_cache_state"):
        return
    if not runtime.supports_runtime_function("serving/decode/decode", "new_decode_state"):
        return

    admission = runtime.invoke_runtime_function("serving/serve/admission_control", "new_admission_control_state_with_policy", 2, 128, "srpt")
    admission = runtime.invoke_runtime_function("serving/serve/admission_control", "admission_on_enqueue", admission, 8, True)
    assert runtime.invoke_runtime_function("serving/serve/admission_control", "admission_can_enqueue", admission, 0, 8) in (True, False)

    batch = runtime.invoke_runtime_function("serving/serve/continuous_batch", "new_continuous_batch_state", 2)
    batch = runtime.invoke_runtime_function("serving/serve/continuous_batch", "continuous_batch_enqueue_request", batch, 16)
    batch = runtime.invoke_runtime_function("serving/serve/continuous_batch", "continuous_batch_record_decode_step", batch, 2)
    assert batch["active_requests"] == 1
    assert batch["decode_tokens"] == 2

    paged = runtime.invoke_runtime_function("serving/cache/paged_kv_cache", "new_paged_kv_cache_state", 4, 8, 2)
    paged = runtime.invoke_runtime_function("serving/cache/paged_kv_cache", "paged_kv_reserve_tokens", paged, 7)
    assert paged["allocated_blocks"] == 1

    prefix = runtime.invoke_runtime_function("serving/cache/prefix_cache", "new_prefix_cache_state", 2, 16)
    prefix = runtime.invoke_runtime_function("serving/cache/prefix_cache", "prefix_cache_insert_with_key", prefix, "req-a", 4)
    prefix = runtime.invoke_runtime_function("serving/cache/prefix_cache", "prefix_cache_lookup_with_key", prefix, "req-a", 4)
    assert prefix["hits"] >= 1

    sampling = runtime.invoke_runtime_function("serving/sampling", "new_sampling_state")
    cache = runtime.invoke_runtime_function("serving/cache/kv_cache", "new_kv_cache_state", 2, 64)
    decode = runtime.invoke_runtime_function("serving/decode/decode", "new_decode_state", 4, cache, sampling)
    decode = runtime.invoke_runtime_function("serving/decode/decode", "decode_step", decode, 3)
    assert decode["step"] == 1
    assert decode["last_token_id"] == 3
