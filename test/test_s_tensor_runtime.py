from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_tensor_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert any(Path(path).name == "tensor.ir" for path in status["ir_files"])

    for function_name in (
        "new",
        "numel",
        "copy_float",
        "copy_int",
        "normalize_dim",
        "fill_like",
        "zeros_like",
        "ones_like",
        "clone",
        "reshape",
        "view",
        "flatten",
        "squeeze",
        "unsqueeze",
        "transpose",
        "permute",
        "add",
        "sub",
        "mul",
        "div",
        "matmul",
    ):
        assert runtime.supports_runtime_function("tensor", function_name)
