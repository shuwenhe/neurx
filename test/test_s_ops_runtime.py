from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_ops_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "ops.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "ops.ir" in runtime_files

    for function_name in (
        "add",
        "sub",
        "mul",
        "div",
        "pow",
        "matmul",
        "linear",
        "layer_norm",
        "rms_norm",
        "scaled_dot_product_attention",
        "causal_attention",
        "kv_cache_attention",
        "qkv_projection",
        "rope_apply",
        "mlp_block",
        "transformer_block_forward",
        "lm_head_logits",
        "sampling_top_k_top_p",
        "generation_step",
        "embedding_lookup",
        "exp",
        "log",
        "sqrt",
        "sum",
        "mean",
        "sum_last_dim",
        "mean_last_dim",
        "softmax_last_dim",
        "log_softmax_last_dim",
        "sum_first_dim",
        "mean_first_dim",
        "softmax_first_dim",
        "log_softmax_first_dim",
        "mse_loss",
        "bce_loss",
        "bce_with_logits_loss",
        "l1_loss",
        "smooth_l1_loss",
        "kl_div_loss",
        "nll_loss",
        "cross_entropy",
        "sgd_step",
        "adam_step",
        "adamw_step",
        "rmsprop_step",
        "relu",
        "sigmoid",
        "tanh",
        "softmax",
        "log_softmax",
        "leaky_relu",
        "elu",
        "selu",
        "gelu",
        "silu",
        "mish",
        "softplus",
        "softsign",
        "swish",
        "hardtanh",
        "hardswish",
        "prelu",
        "rrelu",
    ):
        assert runtime.supports_runtime_function("ops", function_name)


def test_s_ops_runtime_basic_arithmetic_round_trip():
    runtime = _load_runtime_module()
    assert runtime.invoke_runtime_function("ops", "sum", [1.0, 2.0, 3.0], 0, False) == 6.0
    assert runtime.invoke_runtime_function("ops", "mean", [1.0, 2.0, 3.0], 0, False) == 2.0


def test_s_ops_runtime_last_dim_helpers_round_trip():
    runtime = _load_runtime_module()
    values = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]
    assert runtime.invoke_runtime_function("ops", "sum_last_dim", values, False).tolist() == [6.0, 15.0]
    assert runtime.invoke_runtime_function("ops", "mean_last_dim", values, False).tolist() == [2.0, 5.0]

    softmax_out = runtime.invoke_runtime_function("ops", "softmax_last_dim", [[1.0, 2.0, 3.0]])
    log_softmax_out = runtime.invoke_runtime_function("ops", "log_softmax_last_dim", [[1.0, 2.0, 3.0]])
    assert softmax_out.shape == (1, 3)
    assert log_softmax_out.shape == (1, 3)


def test_s_ops_runtime_first_dim_helpers_round_trip():
    runtime = _load_runtime_module()
    values = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]
    assert runtime.invoke_runtime_function("ops", "sum_first_dim", values, False).tolist() == [5.0, 7.0, 9.0]
    assert runtime.invoke_runtime_function("ops", "mean_first_dim", values, False).tolist() == [2.5, 3.5, 4.5]

    softmax_out = runtime.invoke_runtime_function("ops", "softmax_first_dim", values)
    log_softmax_out = runtime.invoke_runtime_function("ops", "log_softmax_first_dim", values)
    assert softmax_out.shape == (2, 3)
    assert log_softmax_out.shape == (2, 3)
