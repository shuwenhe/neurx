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
    assert any(Path(path).as_posix().endswith("ad/tracer.ir") for path in status["ir_files"])
    assert any(Path(path).as_posix().endswith("ad/jaxpr.ir") for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    for ir_name in ("ad.ir", "context.ir", "function.ir"):
        assert ir_name in runtime_files
    assert any(Path(path).as_posix().endswith("tensor/autograd.ir") for path in runtime.compiled_runtime_files())
    assert any(Path(path).as_posix().endswith("engine/backward.ir") for path in runtime.compiled_runtime_files())
    assert any(Path(path).as_posix().endswith("engine/state.ir") for path in runtime.compiled_runtime_files())
    assert any(Path(path).as_posix().endswith("ad/tracer.ir") for path in runtime.compiled_runtime_files())
    assert any(Path(path).as_posix().endswith("ad/jaxpr.ir") for path in runtime.compiled_runtime_files())

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
        "new_tracer_state",
        "tracer_name",
        "tracer_active",
        "tracer_linearized",
        "tracer_op_count",
        "tracer_tag_count",
        "tracer_param_count",
        "tracer_input_count",
        "tracer_output_count",
        "tracer_eqn_count",
        "tracer_has_op",
        "tracer_has_param",
        "tracer_has_input",
        "tracer_has_output",
        "tracer_has_eqn",
        "tracer_has_tag",
        "tracer_add_op",
        "tracer_add_op_with_param",
        "tracer_add_eqn",
        "tracer_add_eqn_with_param",
        "tracer_add_eqn_with_io",
        "tracer_add_input",
        "tracer_add_output",
        "tracer_add_tag",
        "tracer_clear_tags",
        "tracer_clear_inputs",
        "tracer_clear_outputs",
        "tracer_clear_eqns",
        "tracer_clear_params",
        "tracer_set_active",
        "tracer_set_linearized",
        "tracer_state_dict",
        "tracer_load_state_dict",
        "tracer_capture",
        "tracer_capture_with_param",
        "tracer_capture_with_io",
        "tracer_to_transform_chain",
        "transform_chain_to_tracer",
        "new_jaxpr_graph",
        "jaxpr_name",
        "jaxpr_eqn_count",
        "jaxpr_primitive_count",
        "jaxpr_param_count",
        "jaxpr_input_count",
        "jaxpr_output_count",
        "jaxpr_has_primitive",
        "jaxpr_ready",
        "jaxpr_is_linearized",
        "jaxpr_add_eqn",
        "jaxpr_add_eqn_with_params",
        "jaxpr_add_eqn_with_io",
        "jaxpr_add_input",
        "jaxpr_add_output",
        "jaxpr_state_dict",
        "jaxpr_load_state_dict",
        "jaxpr_from_tracer",
        "jaxpr_to_tracer",
        "jaxpr_capture",
        "jaxpr_capture_with_params",
        "jaxpr_capture_with_io",
        "jaxpr_to_transform_chain",
        "transform_chain_to_jaxpr",
    ):
        assert runtime.supports_runtime_function("ad", function_name)

    for function_name in (
        "new_tracer_state",
        "tracer_name",
        "tracer_active",
        "tracer_linearized",
        "tracer_op_count",
        "tracer_param_count",
        "tracer_input_count",
        "tracer_output_count",
        "tracer_eqn_count",
        "tracer_has_op",
        "tracer_has_param",
        "tracer_has_input",
        "tracer_has_output",
        "tracer_has_eqn",
        "tracer_has_tag",
        "tracer_add_op",
        "tracer_add_op_with_param",
        "tracer_add_eqn",
        "tracer_add_eqn_with_param",
        "tracer_add_eqn_with_io",
        "tracer_add_input",
        "tracer_add_output",
        "tracer_add_tag",
        "tracer_clear_tags",
        "tracer_clear_inputs",
        "tracer_clear_outputs",
        "tracer_clear_eqns",
        "tracer_capture_with_io",
        "tracer_to_transform_chain",
        "transform_chain_to_tracer",
    ):
        assert runtime.supports_runtime_function("ad/tracer", function_name)

    for function_name in (
        "new_jaxpr_graph",
        "jaxpr_name",
        "jaxpr_eqn_count",
        "jaxpr_primitive_count",
        "jaxpr_param_count",
        "jaxpr_add_eqn_with_params",
        "jaxpr_add_eqn_with_io",
        "jaxpr_add_eqn",
        "jaxpr_from_tracer",
        "jaxpr_to_tracer",
        "jaxpr_capture_with_params",
        "jaxpr_capture_with_io",
        "jaxpr_to_transform_chain",
    ):
        assert runtime.supports_runtime_function("ad/jaxpr", function_name)

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
        "function_param_count",
        "function_has_tag",
        "function_has_param",
        "add_function_tag",
        "add_function_param",
        "clear_function_tags",
        "clear_function_params",
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


def test_s_ad_tracer_and_jaxpr_runtime_smoke():
    runtime = _load_runtime_module()

    tracer = runtime.invoke_runtime_function("ad/tracer", "new_tracer_state", "trace0")
    assert tracer["name"] == "trace0"
    assert tracer["active"] is False
    assert tracer["linearized"] is False
    assert tracer["op_count"] == 0

    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_op", tracer, "add")
    assert tracer["active"] is True
    assert tracer["op_count"] == 1
    assert tracer["ops"] == ["add"]
    assert tracer["params"] == []
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_has_op", tracer, "add") is True

    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_op_with_param", tracer, "mul", "shape=[2]")
    assert tracer["ops"] == ["add", "mul"]
    assert tracer["params"] == ["shape=[2]"]
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_has_param", tracer, "shape=[2]") is True

    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_input", tracer, "arg0")
    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_input", tracer, "arg1")
    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_output", tracer, "out0")
    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_eqn_with_io", tracer, "matmul", ["axis=1"], [], [])
    assert tracer["inputs"] == ["arg0", "arg1"]
    assert tracer["outputs"] == ["out0"]
    assert tracer["eqns"][0]["primitive"] == "add"
    assert tracer["eqns"][1]["primitive"] == "mul"
    assert tracer["eqns"][2]["primitive"] == "matmul"
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_eqn_count", tracer) == 3
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_has_eqn", tracer, "matmul") is True
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_input_count", tracer) == 2
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_output_count", tracer) == 1
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_has_input", tracer, "arg0") is True
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_has_output", tracer, "out0") is True

    tracer = runtime.invoke_runtime_function("ad/tracer", "tracer_add_tag", tracer, "alpha")
    assert tracer["tags"] == ["alpha"]
    assert runtime.invoke_runtime_function("ad/tracer", "tracer_has_tag", tracer, "alpha") is True

    tracer_chain = runtime.invoke_runtime_function("ad/tracer", "tracer_to_transform_chain", tracer)
    assert tracer_chain["steps"] == ["add", "mul"]
    assert tracer_chain["params"] == ["", "shape=[2]"]
    assert tracer_chain["inputs"] == ["arg0", "arg1"]
    assert tracer_chain["outputs"] == ["out0"]
    assert tracer_chain["ready"] is True
    assert tracer_chain["linearized"] is False

    tracer_round_trip = runtime.invoke_runtime_function("ad/tracer", "transform_chain_to_tracer", tracer_chain, "trace1")
    assert tracer_round_trip["name"] == "trace1"
    assert tracer_round_trip["ops"] == ["add", "mul"]
    assert tracer_round_trip["params"] == ["", "shape=[2]"]
    assert tracer_round_trip["inputs"] == ["arg0", "arg1"]
    assert tracer_round_trip["outputs"] == ["out0"]
    assert tracer_round_trip["op_count"] == 2

    jaxpr = runtime.invoke_runtime_function("ad/jaxpr", "new_jaxpr_graph", "graph0")
    assert jaxpr["name"] == "graph0"
    assert jaxpr["eqn_count"] == 0
    assert jaxpr["ready"] is False

    jaxpr = runtime.invoke_runtime_function("ad/jaxpr", "jaxpr_add_eqn", jaxpr, "add")
    assert jaxpr["eqn_count"] == 1
    assert jaxpr["primitives"] == ["add"]
    assert jaxpr["params"] == [""]
    assert jaxpr["ready"] is True
    assert jaxpr["eqns"][0]["primitive"] == "add"

    jaxpr = runtime.invoke_runtime_function("ad/jaxpr", "jaxpr_add_input", jaxpr, "x")
    jaxpr = runtime.invoke_runtime_function("ad/jaxpr", "jaxpr_add_output", jaxpr, "y")
    assert jaxpr["inputs"] == ["x"]
    assert jaxpr["outputs"] == ["y"]

    jaxpr_chain = runtime.invoke_runtime_function("ad/jaxpr", "jaxpr_to_transform_chain", jaxpr)
    assert jaxpr_chain["steps"] == ["add"]
    assert jaxpr_chain["params"] == [""]
    assert jaxpr_chain["ready"] is True
    assert jaxpr_chain["linearized"] is False

    jaxpr_tracer = runtime.invoke_runtime_function("ad/jaxpr", "jaxpr_to_tracer", jaxpr)
    assert jaxpr_tracer["name"] == "graph0"
    assert jaxpr_tracer["ops"] == ["add"]
    assert jaxpr_tracer["params"] == [""]
    assert jaxpr_tracer["op_count"] == 1
    assert jaxpr_tracer["eqns"][0]["primitive"] == "add"

    ad_tracer = runtime.invoke_runtime_function("ad", "new_tracer_state", "trace2")
    assert ad_tracer["name"] == "trace2"
    ad_tracer = runtime.invoke_runtime_function("ad", "tracer_add_op", ad_tracer, "mul")
    assert ad_tracer["ops"] == ["mul"]
    assert ad_tracer["params"] == []
    ad_tracer = runtime.invoke_runtime_function("ad", "tracer_add_input", ad_tracer, "arg0")
    ad_tracer = runtime.invoke_runtime_function("ad", "tracer_add_output", ad_tracer, "out0")
    assert ad_tracer["inputs"] == ["arg0"]
    assert ad_tracer["outputs"] == ["out0"]

    ad_jaxpr = runtime.invoke_runtime_function("ad", "new_jaxpr_graph", "graph2")
    assert ad_jaxpr["name"] == "graph2"
    ad_jaxpr = runtime.invoke_runtime_function("ad", "jaxpr_from_tracer", ad_tracer, "graph3")
    assert ad_jaxpr["name"] == "graph3"
    assert ad_jaxpr["primitives"] == ["mul"]
    assert ad_jaxpr["params"] == [""]
    assert ad_jaxpr["inputs"] == ["arg0"]
    assert ad_jaxpr["outputs"] == ["out0"]
    assert ad_jaxpr["eqns"][0]["primitive"] == "mul"


def test_s_function_params_round_trip():
    runtime = _load_runtime_module()

    fn = runtime.invoke_runtime_function("function", "new_function", "demo_fn", 2)
    assert fn["name"] == "demo_fn"
    assert fn["arity"] == 2
    assert fn["params"] == []
    assert runtime.invoke_runtime_function("function", "function_param_count", fn) == 0

    fn = runtime.invoke_runtime_function("function", "add_function_param", fn, "op=add")
    fn = runtime.invoke_runtime_function("function", "add_function_tag", fn, "add")
    assert fn["params"] == ["op=add"]
    assert runtime.invoke_runtime_function("function", "function_has_param", fn, "op=add") is True
    assert runtime.invoke_runtime_function("function", "function_has_tag", fn, "add") is True

    chain = runtime.invoke_runtime_function("function", "function_transform_chain", fn)
    assert chain["steps"] == ["add"]
    assert chain["params"] == ["op=add"]
    assert chain["inputs"] == []
    assert chain["outputs"] == []
    assert chain["ready"] is False

    fn_round_trip = runtime.invoke_runtime_function("function", "transform_chain_to_function", chain, "demo_fn2", 3)
    assert fn_round_trip["name"] == "demo_fn2"
    assert fn_round_trip["arity"] == 3
    assert fn_round_trip["params"] == ["op=add"]
    assert fn_round_trip["tags"] == ["add"]

    fn = runtime.invoke_runtime_function("function", "clear_function_params", fn)
    assert fn["params"] == []
