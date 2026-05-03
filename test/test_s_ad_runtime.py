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
    assert any(Path(path).as_posix().endswith("tensor/autograd.ir") for path in status["ir_files"])
    assert any(Path(path).as_posix().endswith("engine/backward.ir") for path in status["ir_files"])
    assert any(Path(path).as_posix().endswith("engine/state.ir") for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    for ir_name in ("ad.ir", "context.ir", "function.ir"):
        assert ir_name in runtime_files
    assert any(Path(path).as_posix().endswith("tensor/autograd.ir") for path in runtime.compiled_runtime_files())
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
        "new_linearize_state",
        "set_forward_mode",
        "set_reverse_mode",
        "forward_mode_enabled",
        "reverse_mode_enabled",
        "linearize_ready",
        "linearize_tensor",
        "register_dual_tensor",
        "linearize_record_count",
        "linearize_has_record",
        "linearize_shape_of",
        "linearize_requires_grad",
        "linearize_primal_of",
        "linearize_tangent_of",
        "linearize_cotangent_of",
        "set_linearize_primal",
        "set_linearize_tangent",
        "set_linearize_cotangent",
        "accumulate_linearize_tangent",
        "accumulate_linearize_cotangent",
        "linearize_state_dict",
        "linearize_load_state_dict",
        "jvp_seed_data",
        "vjp_seed_state",
        "linearize_backward_state",
        "function_state",
        "function_linearized",
        "function_enable_forward",
        "function_enable_backward",
        "function_enable_apply",
        "function_linearize",
        "function_ready_for_linearize",
        "function_to_linearize_state",
        "linearize_state_to_function",
        "function_capture",
        "function_jvp_capture",
        "function_vjp_capture",
        "function_linearize_capture",
        "function_jvp",
        "function_vjp",
        "function_grad",
        "function_value_and_grad",
        "function_add",
        "function_mul",
        "function_matmul",
        "function_sum",
        "function_mean",
        "function_add_op",
        "function_mul_op",
        "function_matmul_op",
        "function_sum_op",
        "function_mean_op",
        "backward_rule_add",
        "backward_rule_mul",
        "backward_rule_matmul",
        "backward_rule_sum",
        "backward_rule_mean",
        "tensor_backward_rule_add",
        "tensor_backward_rule_mul",
        "tensor_backward_rule_matmul",
        "tensor_backward_rule_sum",
        "tensor_backward_rule_mean",
        "tensor_transform_chain_add",
        "tensor_transform_chain_mul",
        "tensor_transform_chain_matmul",
        "tensor_transform_chain_sum",
        "tensor_transform_chain_mean",
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
    for function_name in (
        "new_function",
        "function_name",
        "function_arity",
        "function_tag_count",
        "function_has_tag",
        "add_function_tag",
        "clear_function_tags",
        "enable_forward",
        "enable_backward",
        "enable_apply",
        "set_linearized",
        "function_ready",
        "function_is_linearized",
        "function_state_dict",
        "function_load_state_dict",
        "forward",
        "backward",
        "apply",
        "linearize",
        "jvp",
        "vjp",
        "grad",
        "value_and_grad",
        "add",
        "mul",
        "matmul",
        "sum",
        "mean",
        "tag_flow",
        "backward_pass",
        "backward_pass_state",
        "function_transform_chain",
        "transform_chain_to_function",
        "backward_rule_add",
        "backward_rule_mul",
        "backward_rule_matmul",
        "backward_rule_sum",
        "backward_rule_mean",
    ):
        assert runtime.supports_runtime_function("function", function_name)


def test_s_tensor_autograd_runtime_smoke():
    runtime = _load_runtime_module()
    a = {"data": [1.0, 2.0], "shape": [2], "requires_grad": True, "grad": None}
    b = {"data": [3.0, 4.0], "shape": [2], "requires_grad": True, "grad": None}
    upstream = {"data": [5.0, 6.0], "shape": [2], "requires_grad": False, "grad": None}
    scalar_upstream = {"data": [5.0], "shape": [1], "requires_grad": False, "grad": None}

    add_rule = runtime.invoke_runtime_function("tensor/autograd", "tensor_backward_rule_add", a, b, upstream)
    assert add_rule["ready"] is True
    assert add_rule["grad_a"]["data"] == [5.0, 6.0]
    assert add_rule["grad_b"]["data"] == [5.0, 6.0]

    mul_rule = runtime.invoke_runtime_function("tensor/autograd", "tensor_backward_rule_mul", a, b, upstream)
    assert mul_rule["ready"] is True
    assert mul_rule["grad_a"]["data"] == [15.0, 24.0]
    assert mul_rule["grad_b"]["data"] == [5.0, 12.0]

    sub_rule = runtime.invoke_runtime_function("tensor/autograd", "tensor_backward_rule_sub", a, b, upstream)
    assert sub_rule["ready"] is True
    assert sub_rule["grad_a"]["data"] == [5.0, 6.0]
    assert sub_rule["grad_b"]["data"] == [-5.0, -6.0]

    div_rule = runtime.invoke_runtime_function("tensor/autograd", "tensor_backward_rule_div", a, b, upstream)
    assert div_rule["ready"] is True
    assert list(div_rule["grad_a"]["data"]) == [5.0 / 3.0, 1.5]

    chain = runtime.invoke_runtime_function("tensor/autograd", "tensor_transform_chain_add")
    assert chain["steps"] == ["add"]
    assert chain["ready"] is True
    assert chain["linearized"] is True

    sum_dim_rule = runtime.invoke_runtime_function("tensor/autograd", "tensor_backward_rule_sum_dim", a, scalar_upstream, 0, False)
    assert sum_dim_rule["ready"] is True
    assert sum_dim_rule["grad_a"]["data"] == [5.0, 5.0]

    mean_dim_rule = runtime.invoke_runtime_function("tensor/autograd", "tensor_backward_rule_mean_dim", a, scalar_upstream, 0, False)
    assert mean_dim_rule["ready"] is True
    assert mean_dim_rule["grad_a"]["data"] == [2.5, 2.5]

    for function_name in (
        "tensor_backward_rule_add",
        "tensor_backward_rule_mul",
        "tensor_backward_rule_matmul",
        "tensor_backward_rule_sum",
        "tensor_backward_rule_mean",
        "tensor_transform_chain_add",
        "tensor_transform_chain_mul",
        "tensor_transform_chain_matmul",
        "tensor_transform_chain_sum",
        "tensor_transform_chain_mean",
    ):
        assert runtime.supports_runtime_function("tensor/autograd", function_name)
