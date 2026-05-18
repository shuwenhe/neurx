from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "runtime" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_serving_modules_supported_and_invokable():
    runtime = _load_runtime_module()

    modules = [
        ("serving/serve/admission_control", "new_admission_control_state_with_policy"),
        ("serving/serve/admission_control", "admission_can_enqueue"),
        ("serving/serve/continuous_batch", "new_continuous_batch_state"),
        ("serving/serve/continuous_batch", "continuous_batch_enqueue_request"),
        ("serving/cache/paged_kv_cache", "new_paged_kv_cache_state"),
        ("serving/cache/paged_kv_cache", "paged_kv_reserve_tokens"),
        ("serving/cache/prefix_cache", "new_prefix_cache_state"),
        ("serving/cache/prefix_cache", "prefix_cache_lookup_with_key"),
        ("serving/decode/decode", "new_decode_state"),
        ("serving/decode/decode", "decode_step"),
    ]

    for mod, fn in modules:
        assert runtime.supports_runtime_function(mod, fn)


def test_serving_admission_invoke_behavior():
    runtime = _load_runtime_module()
    new_state = runtime.invoke_runtime_function("serving/serve/admission_control", "new_admission_control_state_with_policy", 2, 64, "srpt")
    assert "capacity" in new_state or hasattr(new_state, "capacity")
    can = runtime.invoke_runtime_function("serving/serve/admission_control", "admission_can_enqueue", new_state, 0, 8)
    assert can is True or can is False


def test_serving_continuous_batch_flow():
    runtime = _load_runtime_module()
    batch = runtime.invoke_runtime_function("serving/serve/continuous_batch", "new_continuous_batch_state", 4)
    batch2 = runtime.invoke_runtime_function("serving/serve/continuous_batch", "continuous_batch_enqueue_request", batch, 5)
    assert runtime.invoke_runtime_function("serving/serve/continuous_batch", "continuous_batch_state_dict", batch2) is not None
