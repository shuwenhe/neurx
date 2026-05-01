package neurx.linalg

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

func matrix_rank(tensor a) int {
    len(a.shape)
}

func inv(tensor a) tensor {
    _clone(a)
}

func det(tensor a) tensor {
    _clone(a)
}

func eig(tensor a) tensor {
    _clone(a)
}

func eigh(tensor a) tensor {
    _clone(a)
}

func svd(tensor a) tensor {
    _clone(a)
}

func qr(tensor a) tensor {
    _clone(a)
}

func cholesky(tensor a) tensor {
    _clone(a)
}

func solve(tensor a, tensor b) tensor {
    _clone(a)
}

func lstsq(tensor a, tensor b) tensor {
    _clone(a)
}

func cross(tensor a, tensor b) tensor {
    _clone(a)
}

func outer(tensor a, tensor b) tensor {
    _clone(a)
}

func inner(tensor a, tensor b) tensor {
    _clone(a)
}

func matrix_power(tensor a, int n) tensor {
    _clone(a)
}
