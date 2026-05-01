package neurx.tensor_stats

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func _clone(tensor a) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func sort(tensor a, int dim) tensor {
    _clone(a)
}

func argsort(tensor a, int dim) tensor {
    _clone(a)
}

func topk(tensor a, int k) tensor {
    _clone(a)
}

func unique(tensor a) tensor {
    _clone(a)
}

func median(tensor a) tensor {
    _clone(a)
}

func mode(tensor a) tensor {
    _clone(a)
}

func quantile(tensor a, float q) tensor {
    _clone(a)
}

func cumsum(tensor a, int dim) tensor {
    _clone(a)
}

func cumprod(tensor a, int dim) tensor {
    _clone(a)
}

func prod(tensor a, int dim) tensor {
    _clone(a)
}
