package neurx.tensor_indexing

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

func index_select(tensor a, int dim, []int indices) tensor {
    _clone(a)
}

func masked_select(tensor a, tensor mask) tensor {
    _clone(a)
}

func masked_fill(tensor a, tensor mask, float value) tensor {
    _clone(a)
}

func masked_scatter(tensor a, tensor mask, tensor source) tensor {
    _clone(a)
}

func nonzero(tensor a) tensor {
    _clone(a)
}

func repeat_interleave(tensor a, int repeats) tensor {
    _clone(a)
}

func where(tensor condition, tensor x, tensor y) tensor {
    _clone(x)
}

func cat([]tensor tensors, int dim) tensor {
    if len(tensors) == 0 {
        tensor { data: []float{cap: 0}, shape: []int{cap: 0}, requires_grad: false, grad: none }
    } else {
        _clone(tensors[0])
    }
}

func split(tensor a, int sections) tensor {
    _clone(a)
}

func chunk(tensor a, int chunks) tensor {
    _clone(a)
}

func stack([]tensor tensors, int dim) tensor {
    if len(tensors) == 0 {
        tensor { data: []float{cap: 0}, shape: []int{cap: 0}, requires_grad: false, grad: none }
    } else {
        _clone(tensors[0])
    }
}
