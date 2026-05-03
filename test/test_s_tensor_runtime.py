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
    assert any(Path(path).name == "shape.ir" for path in status["ir_files"])
    assert any(Path(path).name == "reduce.ir" for path in status["ir_files"])

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
        "maximum",
        "minimum",
        "negative",
        "abs",
        "square",
        "reciprocal",
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
        "broadcast_to",
        "concatenate",
        "stack",
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
        "trace_op",
        "trace_add",
        "trace_mul",
        "trace_matmul",
        "trace_sum",
        "trace_mean",
        "trace_sum_dim",
        "trace_mean_dim",
        "trace_broadcast_to",
        "trace_concatenate",
        "trace_stack",
        "trace_to_transform_chain",
        "trace_to_jaxpr",
    ):
        assert runtime.supports_runtime_function("tensor", function_name)

    for module_name, function_names in (
        ("creation", ("zeros", "ones", "full", "zeros_like", "ones_like", "full_like", "eye", "arange", "linspace", "logspace", "rand", "randn", "randint", "randperm", "normal", "uniform", "empty", "empty_like")),
        ("indexing", ("index_select", "masked_select", "masked_fill", "masked_scatter", "nonzero", "repeat_interleave", "cat", "split", "chunk", "stack", "pad", "slice", "gather")),
        ("shape", ("broadcast_shape", "normalize_axes", "infer_matmul_shape", "expand_shape", "squeeze_shape", "infer_reduce_shape", "concat_shape", "stack_shape", "flatten_shape")),
        ("reduce", ("reduce_sum", "reduce_mean", "reduce_max", "reduce_min", "reduce_prod", "reduce_sum_dim", "reduce_mean_dim", "reduce_max_dim", "reduce_min_dim", "reduce_prod_dim")),
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

    max_out = runtime.invoke_runtime_function("tensor", "maximum", a, b)
    assert list(max_out["data"]) == [3.0, 4.0]

    min_out = runtime.invoke_runtime_function("tensor", "minimum", a, b)
    assert list(min_out["data"]) == [1.0, 2.0]

    neg_out = runtime.invoke_runtime_function("tensor", "negative", a)
    assert list(neg_out["data"]) == [-1.0, -2.0]

    abs_out = runtime.invoke_runtime_function("tensor", "abs", {"data": [-1.0, 2.0], "shape": [2], "requires_grad": False, "grad": None})
    assert list(abs_out["data"]) == [1.0, 2.0]

    square_out = runtime.invoke_runtime_function("tensor", "square", a)
    assert list(square_out["data"]) == [1.0, 4.0]

    reciprocal_out = runtime.invoke_runtime_function("tensor", "reciprocal", a)
    assert list(reciprocal_out["data"]) == [1.0, 0.5]

    broadcast_out = runtime.invoke_runtime_function("tensor", "broadcast_to", a, [2, 2])
    assert broadcast_out["data"] == [[1.0, 2.0], [1.0, 2.0]]

    cat_out = runtime.invoke_runtime_function("tensor", "concatenate", a, b, 0)
    assert list(cat_out["data"]) == [1.0, 2.0, 3.0, 4.0]

    stack_out = runtime.invoke_runtime_function("tensor", "stack", a, b, 0)
    assert stack_out["data"] == [[1.0, 2.0], [3.0, 4.0]]

    indexing_runtime = runtime
    indexed = {"data": [10.0, 20.0, 30.0], "shape": [3], "requires_grad": False, "grad": None}
    pad_out = indexing_runtime.invoke_runtime_function("indexing", "pad", indexed, 1, 2, 0.0)
    assert list(pad_out["data"]) == [0.0, 10.0, 20.0, 30.0, 0.0, 0.0]

    slice_out = indexing_runtime.invoke_runtime_function("indexing", "slice", indexed, 1, 3)
    assert list(slice_out["data"]) == [20.0, 30.0]

    gather_out = indexing_runtime.invoke_runtime_function("indexing", "gather", indexed, [2, 0])
    assert list(gather_out["data"]) == [30.0, 10.0]


def test_s_tensor_tracer_runtime_smoke():
    runtime = _load_runtime_module()
    tracer = runtime.invoke_runtime_function("ad/tracer", "new_tracer_state", "tensor-trace")
    a = {"data": [1.0, 2.0], "shape": [2], "requires_grad": True, "grad": None}
    b = {"data": [3.0, 4.0], "shape": [2], "requires_grad": True, "grad": None}

    tracer = runtime.invoke_runtime_function("tensor", "trace_add", tracer, a, b)
    tracer = runtime.invoke_runtime_function("tensor", "trace_mul", tracer, a, b)
    tracer = runtime.invoke_runtime_function("tensor", "trace_matmul", tracer, a, b)
    tracer = runtime.invoke_runtime_function("tensor", "trace_sum", tracer, a)
    tracer = runtime.invoke_runtime_function("tensor", "trace_mean", tracer, a)
    tracer = runtime.invoke_runtime_function("tensor", "trace_sum_dim", tracer, a, 0, False)
    tracer = runtime.invoke_runtime_function("tensor", "trace_mean_dim", tracer, a, 0, False)
    tracer = runtime.invoke_runtime_function("tensor", "trace_broadcast_to", tracer, a, [2, 2])
    tracer = runtime.invoke_runtime_function("tensor", "trace_concatenate", tracer, a, b, 0)
    tracer = runtime.invoke_runtime_function("tensor", "trace_stack", tracer, a, b, 0)

    assert tracer["active"] is True
    assert tracer["op_count"] == 10
    assert tracer["ops"] == [
        "add",
        "mul",
        "matmul",
        "sum",
        "mean",
        "sum_dim",
        "mean_dim",
        "broadcast_to",
        "concatenate",
        "stack",
    ]
    assert tracer["inputs"] == [
        "arg0",
        "arg1",
        "arg0",
        "arg1",
        "arg0",
        "arg0",
        "arg0",
        "arg0",
        "arg0",
        "arg1",
        "arg1",
    ]
    assert tracer["outputs"] == [
        "out0",
        "out0",
        "out0",
        "out0",
        "out0",
        "out0",
        "out0",
        "out0",
        "out0",
        "out0",
    ]
    assert [eqn["primitive"] for eqn in tracer["eqns"]] == tracer["ops"]
    assert tracer["params"] == [
        "",
        "",
        "",
        "",
        "",
        "dim=0;keepdim=False",
        "dim=0;keepdim=False",
        "shape=[2, 2]",
        "dim=0",
        "dim=0",
    ]

    tracer_chain = runtime.invoke_runtime_function("tensor", "trace_to_transform_chain", tracer)
    assert tracer_chain["steps"] == tracer["ops"]
    assert tracer_chain["params"] == tracer["params"]
    assert tracer_chain["inputs"] == tracer["inputs"]
    assert tracer_chain["outputs"] == tracer["outputs"]
    assert [eqn["primitive"] for eqn in tracer_chain["eqns"]] == tracer["ops"]
    assert tracer_chain["ready"] is True

    jaxpr = runtime.invoke_runtime_function("tensor", "trace_to_jaxpr", tracer, "tensor-graph")
    assert jaxpr["name"] == "tensor-graph"
    assert jaxpr["primitives"] == tracer["ops"]
    assert jaxpr["params"] == tracer["params"]
    assert jaxpr["inputs"] == tracer["inputs"]
    assert jaxpr["outputs"] == tracer["outputs"]
    assert [eqn["primitive"] for eqn in jaxpr["eqns"]] == tracer["ops"]
    assert jaxpr["eqn_count"] == 10


def test_s_tensor_shape_and_reduce_runtime_helpers():
    runtime = _load_runtime_module()
    a_shape = [2, 3]
    b_shape = [1, 3]

    broadcast_shape = runtime.invoke_runtime_function("shape", "broadcast_shape", a_shape, b_shape)
    assert list(broadcast_shape) == [2, 3]

    normalize_axes = runtime.invoke_runtime_function("shape", "normalize_axes", [-1, 0], 2)
    assert list(normalize_axes) == [1, 0]

    infer_matmul = runtime.invoke_runtime_function("shape", "infer_matmul_shape", [2, 3], [3, 4])
    assert list(infer_matmul) == [2, 4]

    expand_shape = runtime.invoke_runtime_function("shape", "expand_shape", [2, 3], 1)
    assert list(expand_shape) == [2, 1, 3]

    squeeze_shape = runtime.invoke_runtime_function("shape", "squeeze_shape", [2, 1, 3])
    assert list(squeeze_shape) == [2, 3]

    infer_reduce_shape = runtime.invoke_runtime_function("shape", "infer_reduce_shape", [2, 3], 1, False)
    assert list(infer_reduce_shape) == [2]

    concat_shape = runtime.invoke_runtime_function("shape", "concat_shape", [2, 3], [2, 4], 0)
    assert list(concat_shape) == [4, 3]

    stack_shape = runtime.invoke_runtime_function("shape", "stack_shape", [2, 3], 1)
    assert list(stack_shape) == [2, 1, 3]

    flatten_shape = runtime.invoke_runtime_function("shape", "flatten_shape", [2, 3, 4], 0, 1)
    assert list(flatten_shape) == [6, 4]

    tensor = {"data": [1.0, 2.0, 3.0, 4.0], "shape": [4], "requires_grad": True, "grad": None}
    reduce_sum = runtime.invoke_runtime_function("reduce", "reduce_sum", tensor)
    assert list(reduce_sum["data"]) == [10.0]

    reduce_mean = runtime.invoke_runtime_function("reduce", "reduce_mean", tensor)
    assert list(reduce_mean["data"]) == [2.5]

    reduce_max = runtime.invoke_runtime_function("reduce", "reduce_max", tensor)
    assert list(reduce_max["data"]) == [4.0]

    reduce_min = runtime.invoke_runtime_function("reduce", "reduce_min", tensor)
    assert list(reduce_min["data"]) == [1.0]

    reduce_prod = runtime.invoke_runtime_function("reduce", "reduce_prod", tensor)
    assert list(reduce_prod["data"]) == [24.0]

    matrix = {"data": [1.0, 2.0, 3.0, 4.0], "shape": [2, 2], "requires_grad": True, "grad": None}
    reduce_sum_dim = runtime.invoke_runtime_function("reduce", "reduce_sum_dim", matrix, 0, False)
    assert list(reduce_sum_dim["data"]) == [4.0, 6.0]

    reduce_mean_dim = runtime.invoke_runtime_function("reduce", "reduce_mean_dim", matrix, 1, False)
    assert list(reduce_mean_dim["data"]) == [1.5, 3.5]
