package neurx.einsum

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func einsum(string equation, tensor a, tensor b) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}
