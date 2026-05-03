package neurx.tensor.reduce

use neurx.tensor.tensor
use neurx.tensor.shape

func _copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _reduce_all(tensor a, int mode) tensor {
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
    _reduce_all(a, 0)
}

func reduce_mean(tensor a) tensor {
    _reduce_all(a, 1)
}

func reduce_max(tensor a) tensor {
    _reduce_all(a, 2)
}

func reduce_min(tensor a) tensor {
    _reduce_all(a, 3)
}

func reduce_prod(tensor a) tensor {
    _reduce_all(a, 4)
}

func _reduce_dim_all(tensor a, int dim, bool keepdim, int mode) tensor {
    int axis = neurx.tensor.shape.normalize_dim(dim, len(a.shape))
    if len(a.shape) == 1 {
        return _reduce_all(a, mode)
    }
    if axis != 0 {
        return neurx.tensor.tensor.clone(a)
    }
    int rows = a.shape[0]
    int cols = a.shape[1]
    []float out = []float{cap: cols}
    int c = 0
    while c < cols {
        float acc = 0.0
        if mode == 2 {
            acc = a.data[c]
        } else {
            if mode == 3 {
                acc = a.data[c]
            } else {
                if mode == 4 {
                    acc = 1.0
                }
            }
        }
        int r = 0
        while r < rows {
            float value = a.data[r * cols + c]
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
            r = r + 1
        }
        if mode == 1 {
            float denom = rows
            if denom == 0.0 {
                denom = 1.0
            }
            acc = acc / denom
        }
        out[c] = acc
        c = c + 1
    }
    []int out_shape = neurx.tensor.shape.infer_reduce_shape(a.shape, dim, keepdim)
    neurx.tensor.tensor.new(out, out_shape, a.requires_grad)
}

func reduce_sum_dim(tensor a, int dim, bool keepdim) tensor {
    _reduce_dim_all(a, dim, keepdim, 0)
}

func reduce_mean_dim(tensor a, int dim, bool keepdim) tensor {
    _reduce_dim_all(a, dim, keepdim, 1)
}

func reduce_max_dim(tensor a, int dim, bool keepdim) tensor {
    _reduce_dim_all(a, dim, keepdim, 2)
}

func reduce_min_dim(tensor a, int dim, bool keepdim) tensor {
    _reduce_dim_all(a, dim, keepdim, 3)
}

func reduce_prod_dim(tensor a, int dim, bool keepdim) tensor {
    _reduce_dim_all(a, dim, keepdim, 4)
}
