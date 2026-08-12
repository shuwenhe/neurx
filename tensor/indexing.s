package neurx.indexing
struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}


func clone(tensor a) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}


func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}


func shape_prod([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}


func normalize_dim(int dim, int ndim) int {
    int axis = dim
    if axis < 0 {
        axis = axis + ndim
    }
    axis
}


func unravel_index(int flat_index, []int shape) []int {
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


func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}


func index_select(tensor a, int dim, []int indices) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if ndim == 1 {
        int n = len(indices)
        []float out = []float{cap: n}
        int i = 0
        while i < n {
            out[i] = a.data[indices[i]]
            i = i + 1
        }
        []int shape = []int{cap: 1}
        shape[0] = n
        tensor {
            data: out,
            shape: shape,
            requires_grad: a.requires_grad,
            grad: none,
        }
    } else {
        if axis != 0 {
            return clone(a)
        }
        int rows = len(indices)
        int row_size = a.shape[1]
        []float out = []float{cap: rows * row_size}
        int r = 0
        while r < rows {
            int src_row = indices[r]
            int c = 0
            while c < row_size {
                out[r * row_size + c] = a.data[src_row * row_size + c]
                c = c + 1
            }
            r = r + 1
        }
        []int shape = copy_int(a.shape)
        shape[0] = rows
        tensor {
            data: out,
            shape: shape,
            requires_grad: a.requires_grad,
            grad: none,
        }
    }
}


func masked_select(tensor a, tensor mask) tensor {
    int n = len(a.data)
    int count = 0
    int i = 0
    while i < n {
        if mask.data[i] != 0.0 {
            count = count + 1
        }
        i = i + 1
    }
    []float out = []float{cap: count}
    int cursor = 0
    i = 0
    while i < n {
        if mask.data[i] != 0.0 {
            out[cursor] = a.data[i]
            cursor = cursor + 1
        }
        i = i + 1
    }
    []int result_shape = []int{cap: 1}
    result_shape[0] = count
    tensor {
        data: out,
        shape: result_shape,
        requires_grad: a.requires_grad || mask.requires_grad,
        grad: none,
    }
}


func masked_fill(tensor a, tensor mask, float value) tensor {
    tensor out = clone(a)
    int n = len(out.data)
    int i = 0
    while i < n {
        if mask.data[i] != 0.0 {
            out.data[i] = value
        }
        i = i + 1
    }
    out
}


func masked_scatter(tensor a, tensor mask, tensor source) tensor {
    tensor out = clone(a)
    int n = len(out.data)
    int cursor = 0
    int i = 0
    while i < n {
        if mask.data[i] != 0.0 {
            if cursor < len(source.data) {
                out.data[i] = source.data[cursor]
                cursor = cursor + 1
            }
        }
        i = i + 1
    }
    out
}


func nonzero(tensor a) tensor {
    int n = len(a.data)
    int count = 0
    int i = 0
    while i < n {
        if a.data[i] != 0.0 {
            count = count + 1
        }
        i = i + 1
    }
    []float out = []float{cap: count}
    int cursor = 0
    i = 0
    while i < n {
        if a.data[i] != 0.0 {
            out[cursor] = i
            cursor = cursor + 1
        }
        i = i + 1
    }
    []int result_shape2 = []int{cap: 1}
    result_shape2[0] = count
    tensor {
        data: out,
        shape: result_shape2,
        requires_grad: false,
        grad: none,
    }
}


func repeat_interleave(tensor a, int repeats) tensor {
    if repeats <= 1 {
        return clone(a)
    }
    int n = len(a.data)
    []float out = []float{cap: n * repeats}
    int cursor = 0
    int i = 0
    while i < n {
        int r = 0
        while r < repeats {
            out[cursor] = a.data[i]
            cursor = cursor + 1
            r = r + 1
        }
        i = i + 1
    }
    []int shape = []int{cap: 1}
    shape[0] = n * repeats
    tensor {
        data: out,
        shape: shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
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
    tensor {
        data: out,
        shape: copy_int(x.shape),
        requires_grad: x.requires_grad || y.requires_grad || condition.requires_grad,
        grad: none,
    }
}


func cat([]tensor tensors, int dim) tensor {
    if len(tensors) == 0 {
        tensor { data: []float{cap: 0}, shape: []int{cap: 0}, requires_grad: false, grad: none }
    } else {
        int axis = normalize_dim(dim, len(tensors[0].shape))
        if axis != 0 {
            return clone(tensors[0])
        }
        int total = 0
        int i = 0
        while i < len(tensors) {
            total = total + len(tensors[i].data)
            i = i + 1
        }
        []float out = []float{cap: total}
        int cursor = 0
        i = 0
        while i < len(tensors) {
            int j = 0
            while j < len(tensors[i].data) {
                out[cursor] = tensors[i].data[j]
                cursor = cursor + 1
                j = j + 1
            }
            i = i + 1
        }
        []int shape = copy_int(tensors[0].shape)
        shape[axis] = 0
        i = 0
        while i < len(tensors) {
            shape[axis] = shape[axis] + tensors[i].shape[axis]
            i = i + 1
        }
        tensor {
            data: out,
            shape: shape,
            requires_grad: false,
            grad: none,
        }
    }
}


func split(tensor a, int sections) tensor {
    if sections <= 0 {
        return clone(a)
    }
    int n = len(a.data)
    int chunk = n / sections
    if chunk <= 0 {
        chunk = 1
    }
    []float out = []float{cap: chunk}
    int i = 0
    while i < chunk && i < n {
        out[i] = a.data[i]
        i = i + 1
    }
    []int shape = []int{cap: 1}
    shape[0] = chunk
    tensor {
        data: out,
        shape: shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}


func chunk(tensor a, int chunks) tensor {
    split(a, chunks)
}


func stack([]tensor tensors, int dim) tensor {
    if len(tensors) == 0 {
        tensor { data: []float{cap: 0}, shape: []int{cap: 0}, requires_grad: false, grad: none }
    } else {
        int base_ndim = len(tensors[0].shape)
        int axis = normalize_dim(dim, base_ndim + 1)
        int n = len(tensors)
        if axis != 0 {
            return clone(tensors[0])
        }
        int total = 0
        int i = 0
        while i < n {
            total = total + len(tensors[i].data)
            i = i + 1
        }
        []float out = []float{cap: total}
        int cursor = 0
        i = 0
        while i < n {
            int j = 0
            while j < len(tensors[i].data) {
                out[cursor] = tensors[i].data[j]
                cursor = cursor + 1
                j = j + 1
            }
            i = i + 1
        }
        []int shape = []int{cap: base_ndim + 1}
        shape[0] = n
        i = 0
        while i < base_ndim {
            shape[i + 1] = tensors[0].shape[i]
            i = i + 1
        }
        tensor {
            data: out,
            shape: shape,
            requires_grad: false,
            grad: none,
        }
    }
}


func pad(tensor a, int before, int after, float value) tensor {
    int n = len(a.data)
    if before < 0 {
        before = 0
    }
    if after < 0 {
        after = 0
    }
    int total = before + n + after
    []float out = []float{cap: total}
    int i = 0
    while i < before {
        out[i] = value
        i = i + 1
    }
    int cursor = before
    while cursor < before + n {
        out[cursor] = a.data[cursor - before]
        cursor = cursor + 1
    }
    i = before + n
    while i < total {
        out[i] = value
        i = i + 1
    }
    []int result_shape3 = []int{cap: 1}
    result_shape3[0] = total
    tensor {
        data: out,
        shape: result_shape3,
        requires_grad: a.requires_grad,
        grad: none,
    }
}


func slice(tensor a, int start, int end) tensor {
    int n = len(a.data)
    int s = start
    int e = end
    if s < 0 {
        s = 0
    }
    if e > n {
        e = n
    }
    if e < s {
        e = s
    }
    int total = e - s
    []float out = []float{cap: total}
    int i = 0
    while i < total {
        out[i] = a.data[s + i]
        i = i + 1
    }
    []int slice_shape = []int{cap: 1}
    slice_shape[0] = total
    tensor {
        data: out,
        shape: slice_shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}


func gather(tensor a, []int indices) tensor {
    int n = len(indices)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = a.data[indices[i]]
        i = i + 1
    }
    []int gather_shape = []int{cap: 1}
    gather_shape[0] = n
    tensor {
        data: out,
        shape: gather_shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

