from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_ad_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    for ir_name in ("ad.ir", "context.ir", "function.ir"):
        assert any(Path(path).name == ir_name for path in status["ir_files"])
    assert any(Path(path).as_posix().endswith("engine/backward.ir") for path in status["ir_files"])
    assert any(Path(path).as_posix().endswith("engine/state.ir") for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    for ir_name in ("ad.ir", "context.ir", "function.ir"):
        assert ir_name in runtime_files
    assert any(Path(path).as_posix().endswith("engine/backward.ir") for path in runtime.compiled_runtime_files())
    assert any(Path(path).as_posix().endswith("engine/state.ir") for path in runtime.compiled_runtime_files())

    for function_name in (
        "new_state",
        "record_count",
        "has_record",
        "set_grad_enabled",
        "no_grad",
        "enable_grad",
        "set_gradient_accumulation",
        "gradient_accumulation",
        "is_grad_enabled",
        "is_grad_accumulation_enabled",
        "get_gradient_accumulation",
        "set_detect_anomaly",
        "zeros_like",
        "ones_like",
        "register_tensor",
        "set_grad",
        "clear_grad",
        "zero_grad",
        "accumulate_grad",
        "grad_of",
        "backward_seed",
        "grad_record_state_dict",
        "grad_record_load_state_dict",
        "autograd_state_dict",
        "autograd_load_state_dict",
        "grad_enabled_state",
        "grad_accumulation_state",
        "backward",
    ):
        assert runtime.supports_runtime_function("ad", function_name)

    for function_name in (
        "new_state",
        "set_grad_enabled",
        "no_grad",
        "enable_grad",
        "set_gradient_accumulation",
        "gradient_accumulation",
        "is_grad_enabled",
        "is_grad_accumulation_enabled",
        "get_gradient_accumulation",
        "set_detect_anomaly",
    ):
        assert runtime.supports_runtime_function("context", function_name)

    for function_name in (
        "new_state",
        "_copy_float",
        "_copy_int",
        "_copy_record",
        "_copy_records",
        "set_grad_enabled",
        "no_grad",
        "enable_grad",
        "set_gradient_accumulation",
        "gradient_accumulation",
        "is_grad_enabled",
        "is_grad_accumulation_enabled",
        "get_gradient_accumulation",
        "set_detect_anomaly",
        "zeros_like",
        "ones_like",
        "register_tensor",
        "record_count",
        "has_record",
        "set_grad",
        "clear_grad",
        "zero_grad",
        "accumulate_grad",
        "grad_of",
        "backward_seed",
        "grad_record_state_dict",
        "grad_record_load_state_dict",
        "autograd_state_dict",
        "autograd_load_state_dict",
        "grad_enabled_state",
        "grad_accumulation_state",
    ):
        assert runtime.supports_runtime_function("engine/state", function_name)

    assert runtime.supports_runtime_function("engine/backward", "backward")
    for function_name in ("forward", "backward", "apply"):
        assert runtime.supports_runtime_function("function", function_name)
