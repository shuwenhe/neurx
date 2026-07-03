package neurx.tensor.reduce

use neurx.tensor.tensor
use neurx.tensor.shape

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

func reduce_all(tensor a, int mode) tensor {
    float acc = 0.0
    if mode == 2 {
        acc = a.data[0]
    } else {
        if mode == 3 {
            acc = a.data[0]
        } else {
            if mode == 4 {
                acc = 1.0
            }
        }
    }
    int i = 0
    while i < len(a.data) {
        float value = a.data[i]
        if mode == 0 {
            acc = acc + value
        } else {
            if mode == 1 {
                acc = acc + value
            } else {
                if mode == 2 {
                    if value > acc {
                        acc = value
                    }
                } else {
                    if mode == 3 {
                        if value < acc {
                            acc = value
                        }
                    } else {
                        acc = acc * value
                    }
                }
            }
        }
        i = i + 1
    }
    if mode == 1 {
        float denom = len(a.data)
        if denom == 0.0 {
            denom = 1.0
        }
        acc = acc / denom
    }
    []float out = []float{cap: 1}
    out[0] = acc
    neurx.tensor.tensor.new(out, [1], a.requires_grad)
}

func reduce_sum(tensor a) tensor {
    reduce_all(a, 0)
}

func reduce_mean(tensor a) tensor {
    reduce_all(a, 1)
}

func reduce_max(tensor a) tensor {
    reduce_all(a, 2)
}

func reduce_min(tensor a) tensor {
    reduce_all(a, 3)
}

func reduce_prod(tensor a) tensor {
    reduce_all(a, 4)
}

func reduce_dim_all(tensor a, int dim, bool keepdim, int mode) tensor {
    int axis = neurx.tensor.shape.normalize_dim(dim, len(a.shape))
    if axis < 0 || axis >= len(a.shape) {
        return neurx.tensor.tensor.clone(a)
    }
    if len(a.shape) == 1 {
        return reduce_all(a, mode)
    }
    []int out_shape = neurx.tensor.shape.infer_reduce_shape(a.shape, dim, keepdim)
    int total = neurx.tensor.tensor.shape_prod(out_shape)
    []float out = []float{cap: total}
    int axis_size = a.shape[axis]
    int flat = 0
    while flat < total {
        []int coords = neurx.tensor.tensor.unravel_index(flat, out_shape)
        []int src_coords = []int{cap: len(a.shape)}
        int i = 0
        int j = 0
        while i < len(a.shape) {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float acc = 0.0
        if mode == 2 || mode == 3 {
            src_coords[axis] = 0
            acc = a.data[neurx.tensor.tensor.ravel_index(src_coords, a.shape)]
        } else {
            if mode == 4 {
                acc = 1.0
            }
        }
        int red = 0
        while red < axis_size {
            src_coords[axis] = red
            float value = a.data[neurx.tensor.tensor.ravel_index(src_coords, a.shape)]
            if mode == 0 || mode == 1 {
                acc = acc + value
            } else {
                if mode == 2 {
                    if value > acc {
                        acc = value
                    }
                } else {
                    if mode == 3 {
                        if value < acc {
                            acc = value
                        }
                    } else {
                        acc = acc * value
                    }
                }
            }
            red = red + 1
        }
        if mode == 1 {
            float denom = axis_size
            if denom == 0.0 {
                denom = 1.0
            }
            acc = acc / denom
        }
        out[flat] = acc
        flat = flat + 1
    }
    neurx.tensor.tensor.new(out, out_shape, a.requires_grad)
}

func reduce_sum_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_dim_all(a, dim, keepdim, 0)
}

func reduce_mean_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_dim_all(a, dim, keepdim, 1)
}

func reduce_max_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_dim_all(a, dim, keepdim, 2)
}

func reduce_min_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_dim_all(a, dim, keepdim, 3)
}

func reduce_prod_dim(tensor a, int dim, bool keepdim) tensor {
    reduce_dim_all(a, dim, keepdim, 4)
}
