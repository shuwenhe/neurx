from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_nn_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "nn.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "nn.ir" in runtime_files

    for function_name in (
        "new_linear",
        "linear_forward",
        "layer_norm",
        "rms_norm",
        "mlp_block",
        "transformer_block_forward",
        "qkv_projection",
        "rope_apply",
        "embedding_lookup",
    ):
        assert runtime.supports_runtime_function("nn", function_name)
