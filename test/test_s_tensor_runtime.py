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
    assert any(Path(path).name == "creation.ir" for path in status["ir_files"])
    assert any(Path(path).name == "indexing.ir" for path in status["ir_files"])
    assert any(Path(path).name == "stats.ir" for path in status["ir_files"])
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
        "sum",
        "mean",
        "sum_dim",
        "mean_dim",
        "exp",
        "log",
        "sqrt",
        "relu",
        "sigmoid",
        "tanh",
        "clamp",
        "clip",
        "sign",
        "flip",
        "roll",
        "tile",
        "where",
        "softmax",
        "log_softmax",
        "take_along_dim",
        "tensor_backward_add_grad_a",
        "tensor_backward_add_grad_b",
        "tensor_backward_mul_grad_a",
        "tensor_backward_mul_grad_b",
        "tensor_backward_matmul_grad_a",
        "tensor_backward_matmul_grad_b",
        "tensor_backward_sum_grad",
        "tensor_backward_mean_grad",
    ):
        assert runtime.supports_runtime_function("tensor", function_name)

    for module_name, function_names in (
        ("creation", ("zeros", "ones", "full", "zeros_like", "ones_like", "full_like", "eye", "arange", "linspace", "logspace", "rand", "randn", "randint", "randperm", "normal", "uniform", "empty", "empty_like")),
        ("indexing", ("index_select", "masked_select", "masked_fill", "masked_scatter", "nonzero", "repeat_interleave", "cat", "split", "chunk", "stack")),
        ("stats", ("sort", "argsort", "topk", "unique", "median", "mode", "quantile", "cumsum", "cumprod", "prod")),
        ("linalg", ("matrix_rank", "inv", "det", "eig", "eigh", "svd", "qr", "cholesky", "solve", "lstsq", "cross", "outer", "inner", "matrix_power")),
        ("einsum", ("einsum",)),
    ):
        for function_name in function_names:
            assert runtime.supports_runtime_function(module_name, function_name)


def test_s_tensor_runtime_autograd_helpers():
    runtime = _load_runtime_module()
    a = {"data": [1.0, 2.0], "shape": [2], "requires_grad": True, "grad": None}
    b = {"data": [3.0, 4.0], "shape": [2], "requires_grad": True, "grad": None}
    upstream = {"data": [5.0, 6.0], "shape": [2], "requires_grad": False, "grad": None}
    scalar_upstream = {"data": [5.0], "shape": [1], "requires_grad": False, "grad": None}
    add_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_add_grad_a", upstream)
    assert list(add_grad["data"]) == [5.0, 6.0]

    mul_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_mul_grad_a", a, b, upstream)
    assert list(mul_grad["data"]) == [15.0, 24.0]

    sub_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_sub_grad_b", upstream)
    assert list(sub_grad["data"]) == [-5.0, -6.0]

    div_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_div_grad_a", a, b, upstream)
    assert list(div_grad["data"]) == [5.0 / 3.0, 1.5]

    matmul_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_matmul_grad_a", a, b, scalar_upstream)
    assert list(matmul_grad["data"]) == [15.0, 20.0]

    sum_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_sum_grad", a, scalar_upstream)
    assert list(sum_grad["data"]) == [5.0, 5.0]

    mean_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_mean_grad", a, {"data": [6.0], "shape": [1], "requires_grad": False, "grad": None})
    assert list(mean_grad["data"]) == [3.0, 3.0]

    sum_dim_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_sum_dim_grad", a, scalar_upstream, 0, False)
    assert list(sum_dim_grad["data"]) == [5.0, 5.0]

    mean_dim_grad = runtime.invoke_runtime_function("tensor", "tensor_backward_mean_dim_grad", a, scalar_upstream, 0, False)
    assert list(mean_dim_grad["data"]) == [2.5, 2.5]
