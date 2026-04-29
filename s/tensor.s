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

func add(tensor a, tensor b) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    for i in 0..n {
        out.push(a.data[i] + b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}
