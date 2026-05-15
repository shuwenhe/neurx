from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_infer_continuous_batch_and_paged_kv_helpers():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("infer/serve/continuous_batch", "new_continuous_batch_state"):
        return
    if not runtime.supports_runtime_function("infer/cache/paged_kv_cache", "new_paged_kv_cache_state"):
        return

    batch = runtime.invoke_runtime_function("infer/serve/continuous_batch", "new_continuous_batch_state", 2)
    batch = runtime.invoke_runtime_function("infer/serve/continuous_batch", "continuous_batch_enqueue_request", batch, 16)
    batch = runtime.invoke_runtime_function("infer/serve/continuous_batch", "continuous_batch_enqueue_request", batch, 8)
    batch = runtime.invoke_runtime_function("infer/serve/continuous_batch", "continuous_batch_enqueue_request", batch, 4)

    assert batch["active_requests"] == 2
    assert batch["queued_requests"] == 1
    assert batch["prefill_tokens"] == 28

    batch = runtime.invoke_runtime_function("infer/serve/continuous_batch", "continuous_batch_record_decode_step", batch, 3)
    assert batch["decode_tokens"] == 3

    batch = runtime.invoke_runtime_function("infer/serve/continuous_batch", "continuous_batch_finish_request", batch)
    assert batch["active_requests"] == 2
    assert batch["queued_requests"] == 0
    assert batch["total_served"] == 1

    paged = runtime.invoke_runtime_function("infer/cache/paged_kv_cache", "new_paged_kv_cache_state", 24, 4, 2)
    paged = runtime.invoke_runtime_function("infer/cache/paged_kv_cache", "paged_kv_reserve_tokens", paged, 3)
    assert paged["allocated_blocks"] == 1

    paged = runtime.invoke_runtime_function("infer/cache/paged_kv_cache", "paged_kv_reserve_tokens", paged, 8)
    assert paged["allocated_blocks"] == 2
    assert paged["evictions"] > 0

    paged = runtime.invoke_runtime_function("infer/cache/paged_kv_cache", "paged_kv_release_tokens", paged, 8)
    assert paged["used_tokens"] >= 0
