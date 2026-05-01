package neurx.tensor

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
        out.push(data[i])
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out.push(data[i])
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
        out.push(value)
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
        shape.push(a.shape[i])
        i = i + 1
    }

    int flat = 1
    while i <= end {
        flat = flat * a.shape[i]
        i = i + 1
    }
    shape.push(flat)

    while i < ndim {
        shape.push(a.shape[i])
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
            shape.push(a.shape[i])
        }
        i = i + 1
    }
    if len(shape) == 0 {
        shape.push(1)
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
        shape.push(a.shape[i])
        i = i + 1
    }
    shape.push(1)
    while i < ndim {
        shape.push(a.shape[i])
        i = i + 1
    }
    new(copy_float(a.data), shape, a.requires_grad)
}

func _shape_prod([]int shape) int {
    numel(shape)
}

func _unravel_index(int flat_index, []int shape) []int {
    int ndim = len(shape)
    []int coords = []int{cap: ndim}
    int i = 0
    while i < ndim {
        coords.push(0)
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

func _ravel_index([]int coords, []int shape) int {
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

    int total = _shape_prod(shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = _unravel_index(flat, shape)
        int ctmp = coords[d0]
        coords[d0] = coords[d1]
        coords[d1] = ctmp
        int src = _ravel_index(coords, a.shape)
        out.push(a.data[src])
        flat = flat + 1
    }

    new(out, shape, a.requires_grad)
}

func permute(tensor a, []int dims) tensor {
    int ndim = len(dims)
    []int shape = []int{cap: ndim}
    int i = 0
    while i < ndim {
        shape.push(a.shape[dims[i]])
        i = i + 1
    }

    int total = _shape_prod(shape)
    []float out = []float{cap: total}
    int flat = 0
    while flat < total {
        []int coords = _unravel_index(flat, shape)
        []int src_coords = []int{cap: len(a.shape)}
        int j = 0
        while j < len(a.shape) {
            src_coords.push(0)
            j = j + 1
        }
        j = 0
        while j < ndim {
            src_coords[dims[j]] = coords[j]
            j = j + 1
        }
        int src = _ravel_index(src_coords, a.shape)
        out.push(a.data[src])
        flat = flat + 1
    }

    new(out, shape, a.requires_grad)
}

func add(tensor a, tensor b) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out.push(a.data[i] + b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}

func sub(tensor a, tensor b) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out.push(a.data[i] - b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}

func mul(tensor a, tensor b) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out.push(a.data[i] * b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}

func div(tensor a, tensor b) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out.push(a.data[i] / b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}

func matmul(tensor a, tensor b) tensor {
    int rows = a.shape[0]
    int inner = a.shape[1]
    int cols = b.shape[1]
    []float out = []float{cap: rows * cols}

    for r in 0..rows {
        for c in 0..cols {
            float acc = 0.0
            for i in 0..inner {
                float x = a.data[r * inner + i]
                float y = b.data[i * cols + c]
                acc = acc + x * y
            }
            out.push(acc)
        }
    }

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

func exp(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = a.data[i]
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func log(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = a.data[i]
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
        out[i] = v
    }
    new(out, copy_int(a.shape), a.requires_grad)
}

func tanh(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = a.data[i]
    }
    new(out, copy_int(a.shape), a.requires_grad)
}
