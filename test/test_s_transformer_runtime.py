from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_transformer_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "transformer.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "transformer.ir" in runtime_files

    for function_name in (
        "transformer_init",
        "transformer_config_state_dict",
        "transformer_config_load_state_dict",
        "transformer_layer_state_dict",
        "transformer_layer_load_state_dict",
        "transformer_layers_state_dict",
        "transformer_layers_load_state_dict",
        "transformer_layer_count",
        "transformer_state_dict",
        "transformer_load_state_dict",
        "transformer_forward",
        "transformer_layer_forward",
        "multihead_attention",
    ):
        assert runtime.supports_runtime_function("transformer", function_name)


def test_s_transformer_runtime_state_helpers_round_trip():
    runtime = _load_runtime_module()
    config = {"num_layers": 2, "num_heads": 4, "d_model": 8, "d_ff": 16, "dropout": 0.1}
    other_config = {"num_layers": 3, "num_heads": 6, "d_model": 12, "d_ff": 24, "dropout": 0.2}
    assert runtime.invoke_runtime_function("transformer", "transformer_config_state_dict", config) is config
    assert runtime.invoke_runtime_function("transformer", "transformer_config_load_state_dict", config, other_config) is other_config

    layer = {"w_q": 1, "w_k": 2, "w_v": 3, "w_o": 4, "w_ff1": 5, "w_ff2": 6, "b_ff1": 7, "b_ff2": 8}
    other_layer = {"w_q": 9, "w_k": 10, "w_v": 11, "w_o": 12, "w_ff1": 13, "w_ff2": 14, "b_ff1": 15, "b_ff2": 16}
    assert runtime.invoke_runtime_function("transformer", "transformer_layer_state_dict", layer) is layer
    assert runtime.invoke_runtime_function("transformer", "transformer_layer_load_state_dict", layer, other_layer) is other_layer

    layers = [layer, other_layer]
    other_layers = [other_layer, layer]
    assert runtime.invoke_runtime_function("transformer", "transformer_layers_state_dict", layers) is layers
    assert runtime.invoke_runtime_function("transformer", "transformer_layers_load_state_dict", layers, other_layers) is other_layers

    model = {"config": config, "layers": layers}
    assert runtime.invoke_runtime_function("transformer", "transformer_layer_count", model) == 2
