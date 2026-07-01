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
        storage: copy_float(base.storage),
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

func add(tensor a, tensor b) tensor {
    tensor left = contiguous(a)
    tensor right = contiguous(b)
    tensor out = empty(left.desc.shape, left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    int i = 0
    while i < out.desc.numel {
        out.storage[i] = left.storage[i] + right.storage[i]
        i = i + 1
    }
    return out
}

func mul(tensor a, tensor b) tensor {
    tensor left = contiguous(a)
    tensor right = contiguous(b)
    tensor out = empty(left.desc.shape, left.desc.dtype, left.desc.device, left.desc.requires_grad || right.desc.requires_grad)
    int i = 0
    while i < out.desc.numel {
        out.storage[i] = left.storage[i] * right.storage[i]
        i = i + 1
    }
    return out
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

func mean_all(tensor a) tensor {
    tensor out = sum_all(a)
    if a.desc.numel > 0 {
        out.storage[0] = out.storage[0] / float(a.desc.numel)
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
