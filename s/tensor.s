package neurx.tensor

struct tensor {
    []f32 data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func new([]f32 data, []int shape, bool requires_grad) tensor {
    tensor {
        data: data,
        shape: shape,
        requires_grad: requires_grad,
        grad: none,
    }
}

func add(tensor a, tensor b) tensor {
    let n = len(a.data)
    let mut out = []f32{cap: n}
    for i in 0..n {
        out.push(a.data[i] + b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}
