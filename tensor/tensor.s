package neurx.tensor

use neurx.backends.compute_backend
use neurx.ad.ir
use neurx.ad.tracer

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func new([]float data, []int shape, bool requires_grad) tensor {
    tensor {
        data: data,
        shape: shape,
        requires_grad: requires_grad,
        grad: none,
    }
}

func numel([]int shape) int {
    int n = 1
    for i in 0..len(shape) {
        n = n * shape[i]
    }
    n
}

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func normalize_dim(int dim, int ndim) int {
    int out = dim
    if out < 0 {
        out = out + ndim
    }
    out
}

func fill_like(tensor like, float value) tensor {
    int n = len(like.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = value
    }
    new(out, like.shape, like.requires_grad)
}

func zeros_like(tensor like) tensor {
    fill_like(like, 0.0)
}

func ones_like(tensor like) tensor {
    fill_like(like, 1.0)
}

func clone(tensor a) tensor {
    new(copy_float(a.data), copy_int(a.shape), a.requires_grad)
}

func reshape(tensor a, []int shape) tensor {
    new(copy_float(a.data), copy_int(shape), a.requires_grad)
}

func view(tensor a, []int shape) tensor {
    reshape(a, shape)
}

func flatten(tensor a, int start_dim, int end_dim) tensor {
    int ndim = len(a.shape)
    int start = normalize_dim(start_dim, ndim)
    int end = normalize_dim(end_dim, ndim)
    if start > end {
        return clone(a)
    }

    []int shape = []int{cap: ndim}
    int i = 0
    while i < start {
        shape[i] = a.shape[i]
        i = i + 1
    }

    int flat = 1
    while i <= end {
        flat = flat * a.shape[i]
        i = i + 1
    }
    shape[i] = flat

    while i < ndim {
        shape[i] = a.shape[i]
        i = i + 1
    }

    new(copy_float(a.data), shape, a.requires_grad)
}

func squeeze(tensor a) tensor {
    int ndim = len(a.shape)
    []int shape = []int{cap: ndim}
    int i = 0
    while i < ndim {
        if a.shape[i] != 1 {
            shape[i] = a.shape[i]
        }
        i = i + 1
    }
    if len(shape) == 0 {
        shape[0] = 1
    }
    new(copy_float(a.data), shape, a.requires_grad)
}

func unsqueeze(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int d = dim
    if d < 0 {
        d = d + ndim + 1
    }
    []int shape = []int{cap: ndim + 1}
    int i = 0
    while i < d {
        shape[i] = a.shape[i]
        i = i + 1
    }
    shape[i] = 1
    while i < ndim {
        shape[i + 1] = a.shape[i]
        i = i + 1
    }
    new(copy_float(a.data), shape, a.requires_grad)
}

func shape_prod([]int shape) int {
    numel(shape)
}

func unravel_index(int flat_index, []int shape) []int {
    int ndim = len(shape)
    []int coords = []int{cap: ndim}
    int i = 0
    while i < ndim {
        coords[i] = 0
        i = i + 1
    }

    int remaining = flat_index
    i = ndim - 1
    while i >= 0 {
        int size = shape[i]
        int coord = remaining - (remaining / size) * size
        coords[i] = coord
        remaining = remaining / size
        i = i - 1
    }
    coords
}

func ravel_index([]int coords, []int shape) int {
    int ndim = len(shape)
    int flat = 0
    int stride = 1
    int i = ndim - 1
    while i >= 0 {
        flat = flat + coords[i] * stride
        stride = stride * shape[i]
        i = i - 1
    }
    flat
}

func transpose(tensor a, int dim0, int dim1) tensor {
    int ndim = len(a.shape)
    int d0 = normalize_dim(dim0, ndim)
    int d1 = normalize_dim(dim1, ndim)
    if d0 == d1 {
        return clone(a)
    }

    []int shape = copy_int(a.shape)
    int tmp = shape[d0]
    shape[d0] = shape[d1]
    shape[d1] = tmp

    int total = shape_prod(shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, shape)
        int ctmp = coords[d0]
        coords[d0] = coords[d1]
        coords[d1] = ctmp
        int src = ravel_index(coords, a.shape)
        out[flat] = a.data[src]
        flat = flat + 1
    }

    new(out, shape, a.requires_grad)
}

func permute_inverse([]int dims) []int {
    int ndim = len(dims)
    []int inv = []int{cap: ndim}
    int i = 0
    while i < ndim {
        inv[i] = 0
        i = i + 1
    }
    i = 0
    while i < ndim {
        inv[dims[i]] = i
        i = i + 1
    }
    inv
}

func permute(tensor a, []int dims) tensor {
    int ndim = len(dims)
    []int shape = []int{cap: ndim}
    int i = 0
    while i < ndim {
        shape[i] = a.shape[dims[i]]
        i = i + 1
    }

    int total = shape_prod(shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, shape)
    []int src_coords = []int{cap: len(a.shape)}
    int j = 0
    while j < len(a.shape) {
            src_coords[j] = 0
            j = j + 1
        }
        j = 0
        while j < ndim {
            src_coords[dims[j]] = coords[j]
            j = j + 1
        }
        int src = ravel_index(src_coords, a.shape)
        out[flat] = a.data[src]
        flat = flat + 1
    }

    new(out, shape, a.requires_grad)
}

func broadcast_shape([]int a, []int b) []int {
    int ndim_a = len(a)
    int ndim_b = len(b)
    int ndim = ndim_a
    if ndim_b > ndim {
        ndim = ndim_b
    }
    []int shape = []int{cap: ndim}
    int i = 0
    while i < ndim {
        shape[i] = 1
        i = i + 1
    }
    int ia = ndim_a - 1
    int ib = ndim_b - 1
    int out = ndim - 1
    while out >= 0 {
        int dim_a = 1
        int dim_b = 1
        if ia >= 0 {
            dim_a = a[ia]
        }
        if ib >= 0 {
            dim_b = b[ib]
        }
        if dim_a != dim_b && dim_a != 1 && dim_b != 1 {
            shape[out] = dim_a
        } else {
            if dim_a > dim_b {
                shape[out] = dim_a
            } else {
                shape[out] = dim_b
            }
        }
        ia = ia - 1
        ib = ib - 1
        out = out - 1
    }
    shape
}

func broadcast_index([]int coords, []int shape) int {
    int ndim_coords = len(coords)
    int ndim_shape = len(shape)
    int offset = ndim_coords - ndim_shape
    []int aligned = []int{cap: ndim_shape}
    int i = 0
    while i < ndim_shape {
        aligned[i] = 0
        i = i + 1
    }
    i = 0
    while i < ndim_shape {
        int coord = coords[i + offset]
        if shape[i] == 1 {
            coord = 0
        }
        aligned[i] = coord
        i = i + 1
    }
    ravel_index(aligned, shape)
}

func binary_broadcast(tensor a, tensor b, int op) tensor {
    []int shape = broadcast_shape(a.shape, b.shape)
    int total = shape_prod(shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, shape)
        int ia = broadcast_index(coords, a.shape)
        int ib = broadcast_index(coords, b.shape)
        float v = 0.0
        if op == 0 {
            v = a.data[ia] + b.data[ib]
        } else {
            if op == 1 {
                v = a.data[ia] - b.data[ib]
            } else {
                if op == 2 {
                    v = a.data[ia] * b.data[ib]
                } else {
                    if op == 3 {
                        v = a.data[ia] / b.data[ib]
                    } else {
                        if op == 4 {
                            if a.data[ia] > b.data[ib] {
                                v = a.data[ia]
                            } else {
                                v = b.data[ib]
                            }
                        } else {
                            if a.data[ia] < b.data[ib] {
                                v = a.data[ia]
                            } else {
                                v = b.data[ib]
                            }
                        }
                    }
                }
            }
        }
        out[flat] = v
        flat = flat + 1
    }
    new(out, shape, a.requires_grad || b.requires_grad)
}

func add(tensor a, tensor b) tensor {
    binary_broadcast(a, b, 0)
}

func sub(tensor a, tensor b) tensor {
    binary_broadcast(a, b, 1)
}

func mul(tensor a, tensor b) tensor {
    binary_broadcast(a, b, 2)
}

func div(tensor a, tensor b) tensor {
    binary_broadcast(a, b, 3)
}

func maximum(tensor a, tensor b) tensor {
    binary_broadcast(a, b, 4)
}

func minimum(tensor a, tensor b) tensor {
    binary_broadcast(a, b, 5)
}

func negative(tensor a) tensor {
    sub(zeros_like(a), a)
}

func abs(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        float v = a.data[i]
        if v < 0.0 {
            v = -v
        }
        out[i] = v
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func square(tensor a) tensor {
    mul(a, a)
}

func reciprocal(tensor a) tensor {
    div(scalar_tensor(1.0), a)
}

func matmul(tensor a, tensor b) tensor {
    int ndim_a = len(a.shape)
    int ndim_b = len(b.shape)
    if ndim_a == 1 && ndim_b == 1 {
        int n = a.shape[0]
        float acc = 0.0
        int i = 0
        while i < n {
            acc = acc + a.data[i] * b.data[i]
            i = i + 1
        }
        []float out = []float{cap: 1}
        out[0] = acc
        return new(out, [1], a.requires_grad || b.requires_grad)
    }

    if ndim_a == 2 && ndim_b == 1 {
        int rows = a.shape[0]
        int inner = a.shape[1]
        []float out = []float{cap: rows}
        int r = 0
        while r < rows {
            float acc = 0.0
            int i = 0
            while i < inner {
                acc = acc + a.data[r * inner + i] * b.data[i]
                i = i + 1
            }
            out[r] = acc
            r = r + 1
        }
        return new(out, [rows], a.requires_grad || b.requires_grad)
    }

    int rows = a.shape[0]
    int inner = a.shape[1]
    int cols = b.shape[1]
    compute_context ctx = resolve_compute_context("", "")
    []float out = backend_matmul_dispatch(ctx, a.data, b.data, rows, inner, cols)
    new(out, [rows, cols], a.requires_grad || b.requires_grad)
}

func sum(tensor a) tensor {
    float acc = 0.0
    int i = 0
    while i < len(a.data) {
        acc = acc + a.data[i]
        i = i + 1
    }
    []float out = []float{cap: 1}
    out[0] = acc
    new(out, [1], a.requires_grad)
}

func mean(tensor a) tensor {
    tensor total = sum(a)
    float denom = len(a.data)
    []float out = []float{cap: 1}
    out[0] = total.data[0] / denom
    new(out, [1], a.requires_grad)
}

func scalar_tensor(float value) tensor {
    new([value], [1], false)
}

func scale_tensor(tensor value, float scale) tensor {
    mul(value, scalar_tensor(scale))
}

func tensor_backward_add_grad_a(tensor upstream) tensor {
    clone(upstream)
}

func tensor_backward_add_grad_b(tensor upstream) tensor {
    clone(upstream)
}

func tensor_backward_mul_grad_a(tensor a, tensor b, tensor upstream) tensor {
    tensor grad = mul(upstream, b)
    sum_to_shape(grad, a.shape)
}

func tensor_backward_mul_grad_b(tensor a, tensor b, tensor upstream) tensor {
    tensor grad = mul(upstream, a)
    sum_to_shape(grad, b.shape)
}

func negate_tensor(tensor value) tensor {
    sub(zeros_like(value), value)
}

func tensor_backward_sub_grad_a(tensor upstream) tensor {
    clone(upstream)
}

func tensor_backward_sub_grad_b(tensor upstream) tensor {
    negate_tensor(upstream)
}

func tensor_backward_div_grad_a(tensor a, tensor b, tensor upstream) tensor {
    tensor grad = div(upstream, b)
    sum_to_shape(grad, a.shape)
}

func tensor_backward_div_grad_b(tensor a, tensor b, tensor upstream) tensor {
    tensor numerator = mul(upstream, a)
    tensor denominator = mul(b, b)
    tensor grad = negate_tensor(div(numerator, denominator))
    sum_to_shape(grad, b.shape)
}

func tensor_backward_matmul_grad_a(tensor a, tensor b, tensor upstream) tensor {
    int ndim_a = len(a.shape)
    int ndim_b = len(b.shape)
    if ndim_a == 1 && ndim_b == 1 {
        return scale_tensor(b, upstream.data[0])
    }
    if ndim_a == 2 && ndim_b == 2 {
        return matmul(upstream, transpose(b, 0, 1))
    }
    if ndim_a == 2 && ndim_b == 1 {
        return mul(unsqueeze(upstream, 1), unsqueeze(b, 0))
    }
    zeros_like(a)
}

func tensor_backward_matmul_grad_b(tensor a, tensor b, tensor upstream) tensor {
    int ndim_a = len(a.shape)
    int ndim_b = len(b.shape)
    if ndim_a == 1 && ndim_b == 1 {
        return scale_tensor(a, upstream.data[0])
    }
    if ndim_a == 2 && ndim_b == 2 {
        return matmul(transpose(a, 0, 1), upstream)
    }
    if ndim_a == 2 && ndim_b == 1 {
        return matmul(transpose(a, 0, 1), upstream)
    }
    zeros_like(b)
}

func tensor_backward_sum_grad(tensor a, tensor upstream) tensor {
    float scalar = 0.0
    if len(upstream.data) > 0 {
        scalar = upstream.data[0]
    }
    fill_like(a, scalar)
}

func tensor_backward_mean_grad(tensor a, tensor upstream) tensor {
    float scalar = 0.0
    if len(upstream.data) > 0 {
        scalar = upstream.data[0]
    }
    float denom = len(a.data)
    fill_like(a, scalar / denom)
}

func tensor_backward_sum_dim_grad(tensor a, tensor upstream, int dim, bool keepdim) tensor {
    tensor expanded = upstream
    if !keepdim {
        expanded = unsqueeze(upstream, dim)
    }
    mul(fill_like(a, 1.0), expanded)
}

func tensor_backward_mean_dim_grad(tensor a, tensor upstream, int dim, bool keepdim) tensor {
    int axis = normalize_dim(dim, len(a.shape))
    float denom = a.shape[axis]
    tensor grad = tensor_backward_sum_dim_grad(a, upstream, dim, keepdim)
    div(grad, scalar_tensor(denom))
}

func tensor_backward_relu_grad(tensor a, tensor upstream) tensor {
    tensor mask = maximum(sign(a), zeros_like(a))
    mul(upstream, mask)
}

func tensor_backward_exp_grad(tensor a, tensor upstream) tensor {
    mul(upstream, exp(a))
}

func tensor_backward_log_grad(tensor a, tensor upstream) tensor {
    div(upstream, clamp(a, 0.000000000001, 1000000000.0))
}

func tensor_backward_sqrt_grad(tensor a, tensor upstream) tensor {
    div(upstream, mul(scalar_tensor(2.0), sqrt(a)))
}

func tensor_backward_tanh_grad(tensor a, tensor upstream) tensor {
    tensor y = tanh(a)
    mul(upstream, sub(ones_like(a), mul(y, y)))
}

func tensor_backward_sigmoid_grad(tensor a, tensor upstream) tensor {
    tensor y = sigmoid(a)
    mul(upstream, mul(y, sub(ones_like(a), y)))
}

func reduce_over_dim(tensor a, int dim, bool keepdim, int mode) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    int axis_size = a.shape[axis]
    []int out_shape = []int{cap: ndim}
    int i = 0
    while i < ndim {
        if i != axis {
            out_shape[i] = a.shape[i]
        } else {
            if keepdim {
                out_shape[i] = 1
            }
        }
        i = i + 1
    }
    if len(out_shape) == 0 {
        out_shape[0] = 1
    }
    int total = shape_prod(out_shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, out_shape)
    []int src_coords = []int{cap: ndim}
    int j = 0
    int k = 0
    while j < ndim {
            src_coords[j] = 0
            j = j + 1
        }
        j = 0
        while j < ndim {
            if j == axis {
                if keepdim {
                    src_coords[j] = 0
                }
            } else {
                src_coords[j] = coords[k]
                k = k + 1
            }
            j = j + 1
        }
        float acc = 0.0
        bool first = true
        int r = 0
        while r < axis_size {
            src_coords[axis] = r
            float value = a.data[ravel_index(src_coords, a.shape)]
            if first {
                acc = value
                first = false
            } else {
                if mode == 0 {
                    acc = acc + value
                } else {
                    acc = acc + value
                }
            }
            r = r + 1
        }
        if mode == 1 {
            acc = acc / axis_size
        }
        out[flat] = acc
        flat = flat + 1
    }
    new(out, out_shape, a.requires_grad)
}

func sum_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_over_dim(a, dim, keepdim, 0)
}

func mean_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_over_dim(a, dim, keepdim, 1)
}

func exp_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0) + (x5 / 120.0)
}

func log_approx(float x) float {
    float v = x
    if v <= 0.0 {
        v = 0.000000000001
    }
    float y = (v - 1.0) / (v + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    float y7 = y5 * y2
    2.0 * (y + (y3 / 3.0) + (y5 / 5.0) + (y7 / 7.0))
}

func sqrt_approx(float x) float {
    float v = x
    if v < 0.0 {
        v = 0.0
    }
    if v == 0.0 {
        return 0.0
    }
    float guess = v
    int i = 0
    while i < 6 {
        guess = 0.5 * (guess + v / guess)
        i = i + 1
    }
    guess
}

func tanh_approx(float x) float {
    float x2 = x * x
    float numerator = x * (27.0 + x2)
    float denominator = 27.0 + (9.0 * x2)
    numerator / denominator
}

func exp(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = exp_approx(a.data[i])
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func log(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = log_approx(a.data[i])
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func sqrt(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = sqrt_approx(a.data[i])
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func relu(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        float v = a.data[i]
        if v < 0.0 {
            v = 0.0
        }
        out[i] = v
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func sigmoid(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        float v = a.data[i]
        out[i] = 1.0 / (1.0 + exp_approx(-v))
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func tanh(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = tanh_approx(a.data[i])
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func clamp(tensor a, float min, float max) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        float v = a.data[i]
        if v < min {
            v = min
        }
        if v > max {
            v = max
        }
        out[i] = v
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func clip(tensor a, float min, float max) tensor {
    clamp(a, min, max)
}

func sign(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        float v = a.data[i]
        if v > 0.0 {
            out[i] = 1.0
        } else {
            if v < 0.0 {
                out[i] = -1.0
            } else {
                out[i] = 0.0
            }
        }
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func shift_index(int index, int shift, int size) int {
    int out = index - shift
    while out < 0 {
        out = out + size
    }
    while out >= size {
        out = out - size
    }
    out
}

func flip(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    int total = len(a.data)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, a.shape)
        coords[axis] = a.shape[axis] - 1 - coords[axis]
        int src = ravel_index(coords, a.shape)
        out[flat] = a.data[src]
        flat = flat + 1
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func roll(tensor a, int shifts, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    int size = a.shape[axis]
    int shift = shifts
    while shift < 0 {
        shift = shift + size
    }
    while shift >= size {
        shift = shift - size
    }

    int total = len(a.data)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, a.shape)
        coords[axis] = shift_index(coords[axis], shift, size)
        int src = ravel_index(coords, a.shape)
        out[flat] = a.data[src]
        flat = flat + 1
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func broadcast_to(tensor a, []int shape) tensor {
    []int target = copy_int(shape)
    int total = shape_prod(target)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, target)
        int src = broadcast_index(coords, a.shape)
        out[flat] = a.data[src]
        flat = flat + 1
    }
    new(out, target, a.requires_grad)
}

func concatenate(tensor a, tensor b, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if len(b.shape) != ndim {
        return clone(a)
    }
    []int shape = copy_int(a.shape)
    shape[axis] = a.shape[axis] + b.shape[axis]
    int total = shape_prod(shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, shape)
        if coords[axis] < a.shape[axis] {
            int src_a = ravel_index(coords, a.shape)
            out[flat] = a.data[src_a]
        } else {
            coords[axis] = coords[axis] - a.shape[axis]
            int src_b = ravel_index(coords, b.shape)
            out[flat] = b.data[src_b]
        }
        flat = flat + 1
    }
    new(out, shape, a.requires_grad || b.requires_grad)
}

func stack(tensor a, tensor b, int dim) tensor {
    concatenate(unsqueeze(a, dim), unsqueeze(b, dim), dim)
}

func tile(tensor a, int repeats) tensor {
    if repeats <= 1 {
        return clone(a)
    }
    int n = len(a.data)
    []float out = []float{cap: n * repeats}
    int k = 0
    int r = 0
    while r < repeats {
        int i = 0
        while i < n {
            out[k] = a.data[i]
            k = k + 1
            i = i + 1
        }
        r = r + 1
    }
    []int shape = copy_int(a.shape)
    if len(shape) > 0 {
        shape[0] = shape[0] * repeats
    }
    new(out, shape, a.requires_grad)
}

func where(tensor condition, tensor x, tensor y) tensor {
    int n = len(x.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        if condition.data[i] != 0.0 {
            out[i] = x.data[i]
        } else {
            out[i] = y.data[i]
        }
        i = i + 1
    }
    new(out, copy_int(x.shape), x.requires_grad || y.requires_grad)
}

func softmax(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    if ndim == 0 {
        return clone(a)
    }
    int axis = normalize_dim(dim, ndim)
    []int out_shape = copy_int(a.shape)
    int total = len(a.data)
    []float out = []float{cap: total}
    []int coords = []int{cap: ndim}
    int i = 0
    while i < ndim {
        coords[i] = 0
        i = i + 1
    }

    int outer = 1
    i = 0
    while i < ndim {
        if i != axis {
            outer = outer * a.shape[i]
        }
        i = i + 1
    }

    int outer_index = 0
    while outer_index < outer {
        []int base = unravel_index(outer_index, out_shape)
        int j = 0
        int k = 0
        while j < ndim {
            if j != axis {
                coords[j] = base[k]
                k = k + 1
            }
            j = j + 1
        }
        float max_v = a.data[ravel_index(coords, a.shape)]
        int axis_size = a.shape[axis]
        int aidx = 1
        while aidx < axis_size {
            coords[axis] = aidx
            float v = a.data[ravel_index(coords, a.shape)]
            if v > max_v {
                max_v = v
            }
            aidx = aidx + 1
        }
        float denom = 0.0
        aidx = 0
        while aidx < axis_size {
            coords[axis] = aidx
            float shifted = a.data[ravel_index(coords, a.shape)] - max_v
            float v = exp_approx(shifted)
            out[ravel_index(coords, a.shape)] = v
            denom = denom + v
            aidx = aidx + 1
        }
        if denom == 0.0 {
            denom = 1.0
        }
        aidx = 0
        while aidx < axis_size {
            coords[axis] = aidx
            int dst = ravel_index(coords, a.shape)
            out[dst] = out[dst] / denom
            aidx = aidx + 1
        }
        outer_index = outer_index + 1
    }
    new(out, out_shape, a.requires_grad)
}

func log_softmax(tensor a, int dim) tensor {
    log(softmax(a, dim))
}

func take_along_dim(tensor a, tensor indices, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    int total = len(indices.data)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, indices.shape)
        int src_index = 0
        int i = 0
        while i < ndim {
            if i == axis {
                coords[i] = int(indices.data[flat])
            }
            i = i + 1
        }
        src_index = ravel_index(coords, a.shape)
        out[flat] = a.data[src_index]
        flat = flat + 1
    }
    new(out, copy_int(indices.shape), a.requires_grad || indices.requires_grad)
}

func trace_op(tracer_state state, string op) tracer_state {
    neurx.ad.tracer.tracer_capture(state, op)
}

func trace_op_with_param(tracer_state state, string op, string param) tracer_state {
    neurx.ad.tracer.tracer_capture_with_param(state, op, param)
}

func empty_strings() []string {
    []string out = []string{cap: 0}
    out
}

func single_string(string value) []string {
    []string out = []string{cap: 1}
    out[0] = value
    out
}

func pair_strings(string a, string b) []string {
    []string out = []string{cap: 2}
    out[0] = a
    out[1] = b
    out
}

func trace_add(tracer_state state, tensor a, tensor b) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "add", empty_strings(), pair_strings("arg0", "arg1"), single_string("out0"))
}

func trace_mul(tracer_state state, tensor a, tensor b) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "mul", empty_strings(), pair_strings("arg0", "arg1"), single_string("out0"))
}

func trace_matmul(tracer_state state, tensor a, tensor b) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "matmul", empty_strings(), pair_strings("arg0", "arg1"), single_string("out0"))
}

func trace_sum(tracer_state state, tensor a) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "sum", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_mean(tracer_state state, tensor a) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "mean", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_sum_dim(tracer_state state, tensor a, int dim, bool keepdim) tracer_state {
    del a
    string param = "dim=" + str(dim) + ";keepdim=" + str(keepdim)
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "sum_dim", single_string(param), single_string("arg0"), single_string("out0"))
}

func trace_mean_dim(tracer_state state, tensor a, int dim, bool keepdim) tracer_state {
    del a
    string param = "dim=" + str(dim) + ";keepdim=" + str(keepdim)
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "mean_dim", single_string(param), single_string("arg0"), single_string("out0"))
}

func trace_relu(tracer_state state, tensor a) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "relu", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_exp(tracer_state state, tensor a) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "exp", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_log(tracer_state state, tensor a) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "log", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_sqrt(tracer_state state, tensor a) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "sqrt", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_tanh(tracer_state state, tensor a) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "tanh", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_sigmoid(tracer_state state, tensor a) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "sigmoid", empty_strings(), single_string("arg0"), single_string("out0"))
}

func trace_broadcast_to(tracer_state state, tensor a, []int shape) tracer_state {
    del a
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "broadcast_to", single_string("shape=" + str(shape)), single_string("arg0"), single_string("out0"))
}

func trace_concatenate(tracer_state state, tensor a, tensor b, int dim) tracer_state {
    del a
    del b
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "concatenate", single_string("dim=" + str(dim)), pair_strings("arg0", "arg1"), single_string("out0"))
}

func trace_stack(tracer_state state, tensor a, tensor b, int dim) tracer_state {
    del a
    del b
    neurx.ad.tracer.tracer_add_eqn_with_io(state, "stack", single_string("dim=" + str(dim)), pair_strings("arg0", "arg1"), single_string("out0"))
}

func trace_to_transform_chain(tracer_state state) transform_chain {
    neurx.ad.tracer.tracer_to_transform_chain(state)
}

func trace_to_jaxpr(tracer_state state, string name) ir_graph {
    neurx.ad.ir.ir_from_tracer(state, name)
}
