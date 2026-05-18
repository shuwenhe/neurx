from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "runtime" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_serving_alias_supports_runtime_function():
    runtime = _load_runtime_module()

    infer_supported = runtime.supports_runtime_function("infer/serve/admission_control", "new_admission_control_state")
    serving_supported = runtime.supports_runtime_function("serving/serve/admission_control", "new_admission_control_state")

    if not infer_supported:
        return

    assert serving_supported is True


def test_serving_alias_invokes_same_runtime_module():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("infer/serve/admission_control", "new_admission_control_state_with_policy"):
        return
    if not runtime.supports_runtime_function("infer/serve/admission_control", "admission_can_enqueue"):
        return

    infer_state = runtime.invoke_runtime_function(
        "infer/serve/admission_control",
        "new_admission_control_state_with_policy",
        2,
        64,
        "srpt",
    )
    serving_state = runtime.invoke_runtime_function(
        "serving/serve/admission_control",
        "new_admission_control_state_with_policy",
        2,
        64,
        "srpt",
    )

    infer_can = runtime.invoke_runtime_function("infer/serve/admission_control", "admission_can_enqueue", infer_state, 0, 8)
    serving_can = runtime.invoke_runtime_function("serving/serve/admission_control", "admission_can_enqueue", serving_state, 0, 8)

    assert serving_can == infer_can
