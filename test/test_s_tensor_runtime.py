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
    assert any(Path(path).name == "tensor_creation.ir" for path in status["ir_files"])
    assert any(Path(path).name == "tensor_indexing.ir" for path in status["ir_files"])
    assert any(Path(path).name == "tensor_stats.ir" for path in status["ir_files"])
    assert any(Path(path).name == "linalg.ir" for path in status["ir_files"])
    assert any(Path(path).name == "einsum.ir" for path in status["ir_files"])

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

    for module_name, function_names in (
        ("tensor_creation", ("zeros", "ones", "full", "zeros_like", "ones_like", "full_like", "eye", "arange", "rand", "randn", "empty")),
        ("tensor_indexing", ("index_select", "masked_select", "masked_fill", "masked_scatter", "nonzero", "repeat_interleave", "cat", "split", "chunk", "stack")),
        ("tensor_stats", ("sort", "argsort", "topk", "unique", "median", "mode", "quantile", "cumsum", "cumprod", "prod")),
        ("linalg", ("matrix_rank", "inv", "det", "eig", "eigh", "svd", "qr", "cholesky", "solve", "lstsq", "cross", "outer", "inner", "matrix_power")),
        ("einsum", ("einsum",)),
    ):
        for function_name in function_names:
            assert runtime.supports_runtime_function(module_name, function_name)
