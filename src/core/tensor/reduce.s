package neurx.tensor.reduce
use neurx.tensor.core

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    return out
}

func shape_prod([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    return n
}

func normalize_dim_local(int dim, int ndim) int {
    int axis = dim
    if axis < 0 {
        axis = axis + ndim
    }
    return axis
}

func make_scalar_from_like(float value, tensor like) tensor {
    []int shape = []int{cap: 1}
    shape[0] = 1
    tensor out = neurx.tensor.core.empty(shape, like.desc.dtype, like.desc.device, like.desc.requires_grad)
    if out.desc.numel > 0 {
        out.storage[0] = value
    }
    return out
}

func reduce_identity(int mode) float {
    if mode == 4 {
        return 1.0
    }
    return 0.0
}

func reduce_init_value(tensor a, int mode) float {
    if len(a.storage) == 0 {
        return reduce_identity(mode)
    }
    if mode == 2 || mode == 3 {
        return a.storage[0]
    }
    return reduce_identity(mode)
}

func reduce_step(float acc, float value, int mode) float {
    if mode == 0 || mode == 1 {
        return acc + value
    }
    if mode == 2 {
        if value > acc {
            return value
        }
        return acc
    }
    if mode == 3 {
        if value < acc {
            return value
        }
        return acc
    }
    return acc * value
}

func reduce_all(tensor a, int mode) tensor {
    float acc = reduce_init_value(a, mode)
    int i = 0
    while i < len(a.storage) {
        acc = reduce_step(acc, a.storage[i], mode)
        i = i + 1
    }
    if mode == 1 {
        float denom = len(a.storage)
        if denom == 0.0 {
            denom = 1.0
        }
        acc = acc / denom
    }
    return make_scalar_from_like(acc, a)
}

func reduce_sum(tensor a) tensor {
    return reduce_all(a, 0)
}

func sum(tensor a) tensor {
    return reduce_sum(a)
}

func reduce_mean(tensor a) tensor {
    return reduce_all(a, 1)
}

func mean(tensor a) tensor {
    return reduce_mean(a)
}

func reduce_max(tensor a) tensor {
    return reduce_all(a, 2)
}

func max(tensor a) tensor {
    return reduce_max(a)
}

func reduce_min(tensor a) tensor {
    return reduce_all(a, 3)
}

func min(tensor a) tensor {
    return reduce_min(a)
}

func reduce_prod(tensor a) tensor {
    return reduce_all(a, 4)
}

func prod(tensor a) tensor {
    return reduce_prod(a)
}

func reduce_arg_all(tensor a, int mode) tensor {
    int n = len(a.storage)
    float best = 0.0
    float best_idx = 0.0
    int i = 0
    while i < n {
        float value = a.storage[i]
        if i == 0 {
            best = value
            best_idx = 0.0
        } else {
            if mode == 0 {
                if value > best {
                    best = value
                    best_idx = i * 1.0
                }
            } else {
                if value < best {
                    best = value
                    best_idx = i * 1.0
                }
            }
        }
        i = i + 1
    }
    return make_scalar_from_like(best_idx, a)
}

func reduce_argmax(tensor a) tensor {
    return reduce_arg_all(a, 0)
}

func argmax(tensor a) tensor {
    return reduce_argmax(a)
}

func reduce_argmin(tensor a) tensor {
    return reduce_arg_all(a, 1)
}

func argmin(tensor a) tensor {
    return reduce_argmin(a)
}

func reduce_output_shape([]int shape, int dim, bool keepdim) []int {
    int ndim = len(shape)
    int axis = normalize_dim_local(dim, ndim)
    if keepdim {
        []int out = copy_int(shape)
        if axis >= 0 && axis < len(out) {
            out[axis] = 1
        }
        return out
    }
    if ndim <= 1 {
        []int out = []int{cap: 1}
        out[0] = 1
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
    return out
}

func reduce_dim_all(tensor a, int dim, bool keepdim, int mode) tensor {
    int ndim = len(a.desc.shape)
    if ndim == 0 {
        return reduce_all(a, mode)
    }
    int axis = normalize_dim_local(dim, ndim)
    if axis < 0 || axis >= ndim {
        return neurx.tensor.core.tensor_clone_storage(a)
    }
    tensor input = neurx.tensor.core.contiguous(a)
    []int out_shape = reduce_output_shape(input.desc.shape, dim, keepdim)
    int total = shape_prod(out_shape)
    tensor out = neurx.tensor.core.empty(out_shape, input.desc.dtype, input.desc.device, input.desc.requires_grad)
    int axis_size = input.desc.shape[axis]
    int flat = 0
    while flat < total {
        []int coords = neurx.tensor.core.unravel_index(flat, out_shape)
        []int src_coords = []int{cap: ndim}
        int i = 0
        int j = 0
        while i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float acc = reduce_init_value(input, mode)
        if mode == 2 || mode == 3 {
            src_coords[axis] = 0
            acc = input.storage[neurx.tensor.core.ravel_index(src_coords, input.desc.shape)]
        }
        int red = 0
        while red < axis_size {
            src_coords[axis] = red
            float value = input.storage[neurx.tensor.core.ravel_index(src_coords, input.desc.shape)]
            acc = reduce_step(acc, value, mode)
            red = red + 1
        }
        if mode == 1 {
            float denom = axis_size
            if denom == 0.0 {
                denom = 1.0
            }
            acc = acc / denom
        }
        out.storage[flat] = acc
        flat = flat + 1
    }
    return out
}

func reduce_sum_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim_all(a, dim, keepdim, 0)
}

func sum_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_sum_dim(a, dim, keepdim)
}

func reduce_mean_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim_all(a, dim, keepdim, 1)
}

func mean_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_mean_dim(a, dim, keepdim)
}

func reduce_max_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim_all(a, dim, keepdim, 2)
}

func max_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_max_dim(a, dim, keepdim)
}

func reduce_min_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim_all(a, dim, keepdim, 3)
}

func min_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_min_dim(a, dim, keepdim)
}

func reduce_prod_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_dim_all(a, dim, keepdim, 4)
}

func prod_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_prod_dim(a, dim, keepdim)
}

func reduce_arg_dim_all(tensor a, int dim, bool keepdim, int mode) tensor {
    int ndim = len(a.desc.shape)
    if ndim == 0 {
        return reduce_arg_all(a, mode)
    }
    int axis = normalize_dim_local(dim, ndim)
    if axis < 0 || axis >= ndim {
        return neurx.tensor.core.tensor_clone_storage(a)
    }
    tensor input = neurx.tensor.core.contiguous(a)
    []int out_shape = reduce_output_shape(input.desc.shape, dim, keepdim)
    int total = shape_prod(out_shape)
    tensor out = neurx.tensor.core.empty(out_shape, input.desc.dtype, input.desc.device, input.desc.requires_grad)
    int axis_size = input.desc.shape[axis]
    int flat = 0
    while flat < total {
        []int coords = neurx.tensor.core.unravel_index(flat, out_shape)
        []int src_coords = []int{cap: ndim}
        int i = 0
        int j = 0
        while i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float best = 0.0
        float best_idx = 0.0
        int red = 0
        while red < axis_size {
            src_coords[axis] = red
            float value = input.storage[neurx.tensor.core.ravel_index(src_coords, input.desc.shape)]
            if red == 0 {
                best = value
                best_idx = 0.0
            } else {
                if mode == 0 {
                    if value > best {
                        best = value
                        best_idx = red * 1.0
                    }
                } else {
                    if value < best {
                        best = value
                        best_idx = red * 1.0
                    }
                }
            }
            red = red + 1
        }
        out.storage[flat] = best_idx
        flat = flat + 1
    }
    return out
}

func reduce_argmax_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_arg_dim_all(a, dim, keepdim, 0)
}

func argmax_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_argmax_dim(a, dim, keepdim)
}

func reduce_argmin_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_arg_dim_all(a, dim, keepdim, 1)
}

func argmin_dim(tensor a, int dim, bool keepdim) tensor {
    return reduce_argmin_dim(a, dim, keepdim)
}
