package neurx.tensor.core
struct tensor_desc {
    []int shape
    []int strides
    int storage_offset
    int numel
    string dtype
    string device
    bool requires_grad
    bool is_view
    bool is_contiguous
}
struct tensor {
    []float storage
    tensor_desc desc
    []float grad
    bool has_grad
}
func tensor_numel(tensor t) int {
    return t.desc.numel
}
func tensor_rank(tensor t) int {
    return len(t.desc.shape)
}
func tensor_is_view(tensor t) bool {
    return t.desc.is_view
}
func tensor_is_contiguous(tensor t) bool {
    return t.desc.is_contiguous
}
func tensor_clone_storage(tensor t) tensor {
    tensor {
        storage: copy_float(t.storage),
        desc: tensor_desc {
            shape: copy_int(t.desc.shape),
            strides: copy_int(t.desc.strides),
            storage_offset: t.desc.storage_offset,
            numel: t.desc.numel,
            dtype: t.desc.dtype,
            device: t.desc.device,
            requires_grad: t.desc.requires_grad,
            is_view: false,
            is_contiguous: true,
        },
        grad: copy_float(t.grad),
        has_grad: t.has_grad,
    }
}
func tensor_summary(tensor t) string {
    string summary = "tensor(shape="
    summary = summary + str(t.desc.shape)
    summary = summary + ", dtype="
    summary = summary + t.desc.dtype
    summary = summary + ", device="
    summary = summary + t.desc.device
    summary = summary + ", requires_grad="
    summary = summary + str(t.desc.requires_grad)
    summary = summary + ", is_view="
    summary = summary + str(t.desc.is_view)
    summary = summary + ", contiguous="
    summary = summary + str(t.desc.is_contiguous)
    summary = summary + ")"
    return summary
}
func copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    return out
}
func copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    return out
}
func zeros_float(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    return out
}
func shape_numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    return n
}
func contiguous_strides([]int shape) []int {
    int ndim = len(shape)
    []int strides = []int{cap: ndim}
    int stride = 1
    int i = ndim - 1
    while i >= 0 {
        strides[i] = stride
        stride = stride * shape[i]
        i = i - 1
    }
    return strides
}
func same_ints([]int a, []int b) bool {
    if len(a) != len(b) {
        return false
    }
    int i = 0
    while i < len(a) {
        if a[i] != b[i] {
            return false
        }
        i = i + 1
    }
    return true
}
func int_to_float(int n) float {
    return 0.0 + n
}
func broadcast_shape([]int a, []int b) []int {
    if !broadcastable_shape(a, b) {
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return empty_shape
    }
    int ndim_a = len(a)
    int ndim_b = len(b)
    int ndim = ndim_a
    if ndim_b > ndim {
        ndim = ndim_b
    }
    []int out = []int{cap: ndim}
    int i = 0
    while i < ndim {
        out[i] = 1
        i = i + 1
    }
    int ia = ndim_a - 1
    int ib = ndim_b - 1
    int io = ndim - 1
    while io >= 0 {
        int dim_a = 1
        int dim_b = 1
        if ia >= 0 {
            dim_a = a[ia]
        }
        if ib >= 0 {
            dim_b = b[ib]
        }
        if dim_a == 1 {
            out[io] = dim_b
        } else if dim_b == 1 {
            out[io] = dim_a
        } else if dim_a >= dim_b {
            out[io] = dim_a
        } else {
            out[io] = dim_b
        }
        ia = ia - 1
        ib = ib - 1
        io = io - 1
    }
    return out
}
func broadcastable_shape([]int a, []int b) bool {
    int ndim_a = len(a)
    int ndim_b = len(b)
    int ndim = ndim_a
    if ndim_b > ndim {
        ndim = ndim_b
    }
    int ia = ndim_a - 1
    int ib = ndim_b - 1
    int i = ndim - 1
    while i >= 0 {
        int dim_a = 1
        int dim_b = 1
        if ia >= 0 {
            dim_a = a[ia]
        }
        if ib >= 0 {
            dim_b = b[ib]
        }
        if dim_a != dim_b && dim_a != 1 && dim_b != 1 {
            return false
        }
        ia = ia - 1
        ib = ib - 1
        i = i - 1
    }
    return true
}
func sum_to_shape(tensor src, []int target_shape) tensor {
    tensor input = contiguous(src)
    if !broadcastable_shape(target_shape, input.desc.shape) {
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return empty(empty_shape, input.desc.dtype, input.desc.device, input.desc.requires_grad)
    }
    int target_rank = len(target_shape)
    int input_rank = len(input.desc.shape)
    []int out_shape = copy_int(target_shape)
    tensor out = empty(out_shape, input.desc.dtype, input.desc.device, input.desc.requires_grad)
    int total = input.desc.numel
    int flat = 0
    while flat < total {
        []int src_coords = unravel_index(flat, input.desc.shape)
        []int dst_coords = []int{cap: target_rank}
        int i = 0
        while i < target_rank {
            dst_coords[i] = 0
            i = i + 1
        }
        int src_axis = input_rank - 1
        int dst_axis = target_rank - 1
        while dst_axis >= 0 {
            int src_dim = 1
            int dst_dim = target_shape[dst_axis]
            if src_axis >= 0 {
                src_dim = input.desc.shape[src_axis]
                if dst_dim == 1 {
                    dst_coords[dst_axis] = 0
                } else if src_dim == dst_dim {
                    dst_coords[dst_axis] = src_coords[src_axis]
                } else if src_dim == 1 {
                    dst_coords[dst_axis] = 0
                } else {
                    dst_coords[dst_axis] = src_coords[src_axis]
                }
            } else {
                dst_coords[dst_axis] = 0
            }
            src_axis = src_axis - 1
            dst_axis = dst_axis - 1
        }
        int dst_flat = ravel_index(dst_coords, target_shape)
        out.storage[dst_flat] = out.storage[dst_flat] + input.storage[flat]
        flat = flat + 1
    }
    return out
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
        int coord = 0
        if size > 0 {
            coord = remaining - (remaining / size) * size
            remaining = remaining / size
        }
        coords[i] = coord
        i = i - 1
    }
    return coords
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
    return flat
}
func dtype_size_bytes(string dtype) int {
    if dtype == "fp32" {
        return 4
    }
    if dtype == "bf16" {
        return 2
    }
    if dtype == "fp16" {
        return 2
    }
    if dtype == "fp8" {
        return 1
    }
    if dtype == "int8" {
        return 1
    }
    return 4
}
func make_desc([]int shape, string dtype, string device, bool requires_grad) tensor_desc {
    []int shape_copy = copy_int(shape)
    []int strides = contiguous_strides(shape_copy)
    return tensor_desc {
        shape: shape_copy,
        strides: strides,
        storage_offset: 0,
        numel: shape_numel(shape_copy),
        dtype: dtype,
        device: device,
        requires_grad: requires_grad,
        is_view: false,
        is_contiguous: true,
    }
}
func empty([]int shape, string dtype, string device, bool requires_grad) tensor {
    tensor_desc desc = make_desc(shape, dtype, device, requires_grad)
    return tensor {
        storage: zeros_float(desc.numel),
        desc: desc,
        grad: zeros_float(desc.numel),
        has_grad: false,
    }
}
func full([]int shape, float value, string dtype, string device, bool requires_grad) tensor {
    tensor out = empty(shape, dtype, device, requires_grad)
    int i = 0
    while i < out.desc.numel {
        out.storage[i] = value
        i = i + 1
    }
    return out
}
func zeros([]int shape, string dtype, string device, bool requires_grad) tensor {
    return full(shape, 0.0, dtype, device, requires_grad)
}
func ones([]int shape, string dtype, string device, bool requires_grad) tensor {
    return full(shape, 1.0, dtype, device, requires_grad)
}
func from_data([]float data, []int shape, string dtype, string device, bool requires_grad) tensor {
    tensor_desc desc = make_desc(shape, dtype, device, requires_grad)
    []float storage = zeros_float(desc.numel)
    int i = 0
    while i < desc.numel && i < len(data) {
        storage[i] = data[i]
        i = i + 1
    }
    return tensor {
        storage: storage,
        desc: desc,
        grad: zeros_float(desc.numel),
        has_grad: false,
    }
}
func tensor_nbytes(tensor t) int {
    return t.desc.numel * dtype_size_bytes(t.desc.dtype)
}
func storage_offset_for_linear(tensor t, int linear_index) int {
    int remaining = linear_index
    int offset = t.desc.storage_offset
    int i = len(t.desc.shape) - 1
    while i >= 0 {
        int dim = t.desc.shape[i]
        int coord = 0
        if dim > 0 {
            coord = remaining - (remaining / dim) * dim
            remaining = remaining / dim
        }
        offset = offset + coord * t.desc.strides[i]
        i = i - 1
    }
    return offset
}
func get(tensor t, int linear_index) float {
    int offset = storage_offset_for_linear(t, linear_index)
    return t.storage[offset]
}
func set_value(tensor t, int linear_index, float value) tensor {
    tensor out = t
    int offset = storage_offset_for_linear(out, linear_index)
    out.storage[offset] = value
    return out
}
func as_strided(tensor base, []int shape, []int strides, int storage_offset) tensor {
    tensor_desc desc = tensor_desc {
        shape: copy_int(shape),
        strides: copy_int(strides),
        storage_offset: storage_offset,
        numel: shape_numel(shape),
        dtype: base.desc.dtype,
        device: base.desc.device,
        requires_grad: base.desc.requires_grad,
        is_view: true,
        is_contiguous: same_ints(strides, contiguous_strides(shape)),
    }
    return tensor {
        storage: base.storage,
        desc: desc,
        grad: zeros_float(desc.numel),
        has_grad: false,
    }
}
func view(tensor base, []int shape) tensor {
    if shape_numel(shape) != base.desc.numel {
        return base
    }
    return as_strided(base, shape, contiguous_strides(shape), base.desc.storage_offset)
}
func reshape(tensor base, []int shape) tensor {
    return view(base, shape)
}
func transpose2d(tensor base) tensor {
    if len(base.desc.shape) != 2 {
        return clone(base)
    }
    []int shape = []int{cap: 2}
    shape[0] = base.desc.shape[1]
    shape[1] = base.desc.shape[0]
    []int strides = []int{cap: 2}
    strides[0] = base.desc.strides[1]
    strides[1] = base.desc.strides[0]
    return as_strided(base, shape, strides, base.desc.storage_offset)
}
func broadcast_offset(tensor t, []int out_coords) int {
    int out_ndim = len(out_coords)
    int src_ndim = len(t.desc.shape)
    int src_axis = src_ndim - 1
    int out_axis = out_ndim - 1
    int offset = t.desc.storage_offset
    while out_axis >= 0 {
        if src_axis >= 0 {
            int dim = t.desc.shape[src_axis]
            int coord = out_coords[out_axis]
            if dim == 1 {
                coord = 0
            }
            offset = offset + coord * t.desc.strides[src_axis]
            src_axis = src_axis - 1
        }
        out_axis = out_axis - 1
    }
    return offset
}
func elementwise_binary(tensor a, tensor b, string op) tensor {
    tensor left = contiguous(a)
    tensor right = contiguous(b)
    if !broadcastable_shape(left.desc.shape, right.desc.shape) {
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return empty(empty_shape, left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    }
    []int out_shape = broadcast_shape(left.desc.shape, right.desc.shape)
    tensor out = empty(out_shape, left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    int total = out.desc.numel
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, out_shape)
        int left_off = broadcast_offset(left, coords)
        int right_off = broadcast_offset(right, coords)
        float lv = left.storage[left_off]
        float rv = right.storage[right_off]
        if op == "add" {
            out.storage[flat] = lv + rv
        } else if op == "sub" {
            out.storage[flat] = lv - rv
        } else if op == "mul" {
            out.storage[flat] = lv * rv
        } else if op == "div" {
            out.storage[flat] = lv / rv
        } else {
            out.storage[flat] = lv
        }
        flat = flat + 1
    }
    return out
}
func broadcast_to(tensor a, []int target_shape) tensor {
    tensor src = contiguous(a)
    if !broadcastable_shape(src.desc.shape, target_shape) {
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return empty(empty_shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    }
    tensor out = empty(target_shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    int total = out.desc.numel
    int flat = 0
    while flat < total {
        []int dst_coords = unravel_index(flat, target_shape)
        int src_off = broadcast_offset(src, dst_coords)
        out.storage[flat] = src.storage[src_off]
        flat = flat + 1
    }
    return out
}
func contiguous(tensor t) tensor {
    if t.desc.is_contiguous && t.desc.storage_offset == 0 {
        return t
    }
    tensor out = empty(t.desc.shape, t.desc.dtype, t.desc.device, t.desc.requires_grad)
    int i = 0
    while i < t.desc.numel {
        out.storage[i] = get(t, i)
        i = i + 1
    }
    return out
}
func tensor_materialize(tensor t) tensor {
    return contiguous(t)
}
func clone(tensor t) tensor {
    return contiguous(t)
}
func exp_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    return 1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0) + (x5 / 120.0)
}
func tanh_approx(float x) float {
    float x2 = x * x
    return (x * (27.0 + x2)) / (27.0 + 9.0 * x2)
}
func fill_like(tensor like, float value) tensor {
    tensor out = empty(like.desc.shape, like.desc.dtype, like.desc.device, like.desc.requires_grad)
    int i = 0
    while i < out.desc.numel {
        out.storage[i] = value
        i = i + 1
    }
    return out
}
func zeros_like(tensor like) tensor {
    return fill_like(like, 0.0)
}
func ones_like(tensor like) tensor {
    return fill_like(like, 1.0)
}
func unary_elementwise(tensor a, string op) tensor {
    tensor src = contiguous(a)
    tensor out = empty(src.desc.shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    int i = 0
    while i < src.desc.numel {
        float v = src.storage[i]
        if op == "relu" {
            if v < 0.0 {
                v = 0.0
            }
        } else if op == "exp" {
            float term = 1.0
            float sum = 1.0
            int k = 1
            while k <= 6 {
                term = term * v / int_to_float(k)
                sum = sum + term
                k = k + 1
            }
            v = sum
        } else if op == "log" {
            float x = v
            if x <= 0.0 {
                x = 0.000000000001
            }
            float y = (x - 1.0) / (x + 1.0)
            float y2 = y * y
            float y3 = y2 * y
            float y5 = y3 * y2
            v = 2.0 * (y + y3 / 3.0 + y5 / 5.0)
        } else if op == "sqrt" {
            float x2 = v
            if x2 < 0.0 {
                x2 = 0.0
            }
            float guess = x2
            if guess < 1.0 {
                guess = 1.0
            }
            int k2 = 0
            while k2 < 6 {
                guess = 0.5 * (guess + x2 / guess)
                k2 = k2 + 1
            }
            v = guess
        } else if op == "tanh" {
            float x3 = v * v
            v = (v * (27.0 + x3)) / (27.0 + 9.0 * x3)
        }
        out.storage[i] = v
        i = i + 1
    }
    return out
}
func relu(tensor a) tensor {
    return unary_elementwise(a, "relu")
}
func exp(tensor a) tensor {
    return unary_elementwise(a, "exp")
}
func log(tensor a) tensor {
    return unary_elementwise(a, "log")
}
func sqrt(tensor a) tensor {
    return unary_elementwise(a, "sqrt")
}
func tanh(tensor a) tensor {
    return unary_elementwise(a, "tanh")
}
func gelu(tensor a) tensor {
    tensor src = contiguous(a)
    tensor out = empty(src.desc.shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    int i = 0
    while i < src.desc.numel {
        float x = src.storage[i]
        float inner = 0.7978845608 * (x + 0.044715 * x * x * x)
        out.storage[i] = 0.5 * x * (1.0 + tanh_approx(inner))
        i = i + 1
    }
    return out
}
func softmax(tensor a, int dim) tensor {
    tensor src = contiguous(a)
    int ndim = len(src.desc.shape)
    if ndim == 0 {
        return clone(src)
    }
    int axis = dim
    if axis < 0 {
        axis = axis + ndim
    }
    if axis < 0 || axis >= ndim {
        return clone(src)
    }
    []int out_shape = copy_int(src.desc.shape)
    tensor out = empty(out_shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    int outer = 1
    int i = 0
    while i < ndim {
        if i != axis {
            outer = outer * src.desc.shape[i]
        }
        i = i + 1
    }
    int outer_index = 0
    while outer_index < outer {
        []int base = unravel_index(outer_index, out_shape)
        []int coords = []int{cap: ndim}
        int j = 0
        int k = 0
        while j < ndim {
            if j == axis {
                coords[j] = 0
            } else {
                coords[j] = base[k]
                k = k + 1
            }
            j = j + 1
        }
        float max_v = src.storage[ravel_index(coords, src.desc.shape)]
        int axis_size = src.desc.shape[axis]
        int aidx = 1
        while aidx < axis_size {
            coords[axis] = aidx
            float v = src.storage[ravel_index(coords, src.desc.shape)]
            if v > max_v {
                max_v = v
            }
            aidx = aidx + 1
        }
        float denom = 0.0
        aidx = 0
        while aidx < axis_size {
            coords[axis] = aidx
            int dst = ravel_index(coords, src.desc.shape)
            float v = exp_approx(src.storage[dst] - max_v)
            out.storage[dst] = v
            denom = denom + v
            aidx = aidx + 1
        }
        if denom == 0.0 {
            denom = 1.0
        }
        aidx = 0
        while aidx < axis_size {
            coords[axis] = aidx
            int dst2 = ravel_index(coords, src.desc.shape)
            out.storage[dst2] = out.storage[dst2] / denom
            aidx = aidx + 1
        }
        outer_index = outer_index + 1
    }
    return out
}
func core_backend_smoke() bool {
    []int shape2 = []int{cap: 2}
    shape2[0] = 2
    shape2[1] = 2
    tensor a = ones(shape2, "fp32", "cpu", false)
    tensor b = full(shape2, 2.0, "fp32", "cpu", false)
    tensor c = add(a, b)
    tensor d = matmul2d(a, b)
    if c.storage[0] != 3.0 || c.storage[3] != 3.0 {
        return false
    }
    if d.storage[0] != 4.0 || d.storage[3] != 4.0 {
        return false
    }
    true
}
func add(tensor a, tensor b) tensor {
    return elementwise_binary(a, b, "add")
}
func sub(tensor a, tensor b) tensor {
    return elementwise_binary(a, b, "sub")
}
func mul(tensor a, tensor b) tensor {
    return elementwise_binary(a, b, "mul")
}
func div(tensor a, tensor b) tensor {
    return elementwise_binary(a, b, "div")
}
func sum_all(tensor a) tensor {
    tensor src = contiguous(a)
    []int scalar_shape = []int{cap: 1}
    scalar_shape[0] = 1
    tensor out = zeros(scalar_shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    int i = 0
    while i < src.desc.numel {
        out.storage[0] = out.storage[0] + src.storage[i]
        i = i + 1
    }
    return out
}
func reduce_dim(tensor a, int dim, bool keepdim, string mode) tensor {
    tensor src = contiguous(a)
    int ndim = len(src.desc.shape)
    int axis = dim
    if axis < 0 {
        axis = axis + ndim
    }
    if axis < 0 || axis >= ndim {
        return clone(src)
    }
    []int out_shape
    if keepdim {
        out_shape = copy_int(src.desc.shape)
        out_shape[axis] = 1
    } else {
        if ndim <= 1 {
            out_shape = []int{cap: 1}
            out_shape[0] = 1
        } else {
            out_shape = []int{cap: ndim - 1}
            int i = 0
            int j = 0
            while i < ndim {
                if i != axis {
                    out_shape[j] = src.desc.shape[i]
                    j = j + 1
                }
                i = i + 1
            }
        }
    }
    tensor out = empty(out_shape, src.desc.dtype, src.desc.device, src.desc.requires_grad)
    int total = out.desc.numel
    int flat = 0
    while flat < total {
        []int coords = unravel_index(flat, out_shape)
        float acc = 0.0
        if mode == "max" || mode == "min" {
            int red = 0
            int first_off = 0
            if keepdim {
                []int base_coords = copy_int(coords)
                base_coords[axis] = 0
                first_off = broadcast_offset(src, base_coords)
            } else {
                []int base_coords2 = []int{cap: ndim}
                int i2 = 0
                int j2 = 0
                while i2 < ndim {
                    if i2 == axis {
                        base_coords2[i2] = 0
                    } else {
                        base_coords2[i2] = coords[j2]
                        j2 = j2 + 1
                    }
                    i2 = i2 + 1
                }
                first_off = broadcast_offset(src, base_coords2)
            }
            acc = src.storage[first_off]
            while red < src.desc.shape[axis] {
                int src_off
                if keepdim {
                    []int base_coords3 = copy_int(coords)
                    base_coords3[axis] = red
                    src_off = broadcast_offset(src, base_coords3)
                } else {
                    []int base_coords4 = []int{cap: ndim}
                    int i3 = 0
                    int j3 = 0
                    while i3 < ndim {
                        if i3 == axis {
                            base_coords4[i3] = red
                        } else {
                            base_coords4[i3] = coords[j3]
                            j3 = j3 + 1
                        }
                        i3 = i3 + 1
                    }
                    src_off = broadcast_offset(src, base_coords4)
                }
                if mode == "max" {
                    if src.storage[src_off] > acc {
                        acc = src.storage[src_off]
                    }
                } else {
                    if src.storage[src_off] < acc {
                        acc = src.storage[src_off]
                    }
                }
                red = red + 1
            }
        } else if mode == "prod" {
            acc = 1.0
            int red2 = 0
            while red2 < src.desc.shape[axis] {
                int src_off2
                if keepdim {
                    []int base_coords5 = copy_int(coords)
                    base_coords5[axis] = red2
                    src_off2 = broadcast_offset(src, base_coords5)
                } else {
                    []int base_coords6 = []int{cap: ndim}
                    int i4 = 0
                    int j4 = 0
                    while i4 < ndim {
                        if i4 == axis {
                            base_coords6[i4] = red2
                        } else {
                            base_coords6[i4] = coords[j4]
                            j4 = j4 + 1
                        }
                        i4 = i4 + 1
                    }
                    src_off2 = broadcast_offset(src, base_coords6)
                }
                acc = acc * src.storage[src_off2]
                red2 = red2 + 1
            }
        } else {
            int red3 = 0
            while red3 < src.desc.shape[axis] {
                int src_off3
                if keepdim {
                    []int base_coords7 = copy_int(coords)
                    base_coords7[axis] = red3
                    src_off3 = broadcast_offset(src, base_coords7)
                } else {
                    []int base_coords8 = []int{cap: ndim}
                    int i5 = 0
                    int j5 = 0
                    while i5 < ndim {
                        if i5 == axis {
                            base_coords8[i5] = red3
                        } else {
                            base_coords8[i5] = coords[j5]
                            j5 = j5 + 1
                        }
                        i5 = i5 + 1
                    }
                    src_off3 = broadcast_offset(src, base_coords8)
                }
                if mode == "mean" || mode == "sum" {
                    acc = acc + src.storage[src_off3]
                }
                red3 = red3 + 1
            }
            if mode == "mean" && src.desc.shape[axis] > 0 {
                acc = acc / int_to_float(src.desc.shape[axis])
            }
        }
        out.storage[flat] = acc
        flat = flat + 1
    }
    return out
}
func sum_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim(a, dim, keepdim, "sum")
}
func mean_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim(a, dim, keepdim, "mean")
}
func max_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim(a, dim, keepdim, "max")
}
func min_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim(a, dim, keepdim, "min")
}
func prod_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim(a, dim, keepdim, "prod")
}
func mean_all(tensor a) tensor {
    tensor out = sum_all(a)
    if a.desc.numel > 0 {
        out.storage[0] = out.storage[0] / int_to_float(a.desc.numel)
    }
    return out
}
func matmul2d(tensor a, tensor b) tensor {
    tensor left = contiguous(a)
    tensor right = contiguous(b)
    if len(left.desc.shape) != 2 || len(right.desc.shape) != 2 {
        return empty([0], left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    }
    int m = left.desc.shape[0]
    int k = left.desc.shape[1]
    int k2 = right.desc.shape[0]
    int n = right.desc.shape[1]
    if k != k2 {
        return empty([0], left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    }
    []int shape = []int{cap: 2}
    shape[0] = m
    shape[1] = n
    tensor out = zeros(shape, left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    int row = 0
    while row < m {
        int col = 0
        while col < n {
            float acc = 0.0
            int p = 0
            while p < k {
                acc = acc + left.storage[row * k + p] * right.storage[p * n + col]
                p = p + 1
            }
            out.storage[row * n + col] = acc
            col = col + 1
        }
        row = row + 1
    }
    return out
}
