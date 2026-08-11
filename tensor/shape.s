package neurx.tensor.shape
func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
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
func normalize_axes([]int axes, int ndim) []int {
    []int out = copy_int(axes)
    int i = 0
    while i < len(out) {
        out[i] = normalize_dim(out[i], ndim)
        i = i + 1
    }
    out
}
func broadcast_shape([]int a, []int b) []int {
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
    int out_i = ndim - 1
    while out_i >= 0 {
        int dim_a = 1
        int dim_b = 1
        if ia >= 0 {
            dim_a = a[ia]
        }
        if ib >= 0 {
            dim_b = b[ib]
        }
        if dim_a == 1 {
            out[out_i] = dim_b
        } else {
            if dim_b == 1 {
                out[out_i] = dim_a
            } else {
                if dim_a > dim_b {
                    out[out_i] = dim_a
                } else {
                    out[out_i] = dim_b
                }
            }
        }
        ia = ia - 1
        ib = ib - 1
        out_i = out_i - 1
    }
    out
}
func infer_matmul_shape([]int a, []int b) []int {
    int ndim_a = len(a)
    int ndim_b = len(b)
    []int out = copy_int(a)
    if ndim_a == 1 && ndim_b == 1 {
        out = []int{cap: 1}
        out[0] = 1
    } else {
        if ndim_a == 1 && ndim_b == 2 {
            out = []int{cap: 1}
            out[0] = b[1]
        } else {
            if ndim_a == 2 && ndim_b == 1 {
                out = []int{cap: 1}
                out[0] = a[0]
            } else {
                if ndim_a == 2 && ndim_b == 2 {
                    out = []int{cap: 2}
                    out[0] = a[0]
                    out[1] = b[1]
                }
            }
        }
    }
    out
}
func expand_shape([]int shape, int dim) []int {
    int ndim = len(shape)
    int axis = dim
    if axis < 0 {
        axis = axis + ndim + 1
    }
    []int out = []int{cap: ndim + 1}
    int i = 0
    while i < axis {
        out[i] = shape[i]
        i = i + 1
    }
    out[i] = 1
    i = i + 1
    while i < len(out) {
        out[i] = shape[i - 1]
        i = i + 1
    }
    out
}
func squeeze_shape([]int shape) []int {
    []int out = []int{cap: len(shape)}
    int i = 0
    while i < len(shape) {
        if shape[i] != 1 {
            out[i] = shape[i]
        }
        i = i + 1
    }
    if len(out) == 0 {
        out = []int{cap: 1}
        out[0] = 1
    }
    out
}
func infer_reduce_shape([]int shape, int dim, bool keepdim) []int {
    int ndim = len(shape)
    int axis = normalize_dim(dim, ndim)
    if keepdim {
        []int out = copy_int(shape)
        out[axis] = 1
        return out
    }
    []int out = []int{cap: ndim - 1}
    int i = 0
    int j = 0
    while i < ndim {
        if i != axis {
            out[j] = shape[i]
            j = j + 1
        }
        i = i + 1
    }
    if len(out) == 0 {
        out = []int{cap: 1}
        out[0] = 1
    }
    out
}
func concat_shape([]int a, []int b, int dim) []int {
    int ndim = len(a)
    int axis = normalize_dim(dim, ndim)
    []int out = copy_int(a)
    if len(b) == len(a) {
        out[axis] = a[axis] + b[axis]
    }
    out
}
func stack_shape([]int a, int dim) []int {
    expand_shape(a, dim)
}
func flatten_shape([]int shape, int start_dim, int end_dim) []int {
    int ndim = len(shape)
    int start = normalize_dim(start_dim, ndim)
    int end = normalize_dim(end_dim, ndim)
    if start > end {
        return copy_int(shape)
    }
    int out_ndim = ndim - (end - start)
    []int out = []int{cap: out_ndim}
    int i = 0
    int j = 0
    while i < start {
        out[j] = shape[i]
        i = i + 1
        j = j + 1
    }
    int flat = 1
    while i <= end {
        flat = flat * shape[i]
        i = i + 1
    }
    out[j] = flat
    j = j + 1
    while i < ndim {
        out[j] = shape[i]
        j = j + 1
        i = i + 1
    }
    out
}
