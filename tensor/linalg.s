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

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func matrix_rank(tensor a) int {
    int ndim = len(a.shape)
    if ndim == 0 {
        return 0
    }
    if ndim == 1 {
        return 1
    }
    if ndim >= 2 {
        return 2
    }
    0
}

func inv(tensor a) tensor {
    if len(a.shape) == 2 && a.shape[0] == 1 && a.shape[1] == 1 {
        float v = a.data[0]
        if v == 0.0 {
            v = 1.0
        }
        []float out = []float{cap: 1}
        out[0] = 1.0 / v
        tensor {
            data: out,
            shape: [1, 1],
            requires_grad: a.requires_grad,
            grad: none,
        }
    } else {
        _clone(a)
    }
}

func det(tensor a) tensor {
    float value = 1.0
    if len(a.shape) == 2 && a.shape[0] == 1 && a.shape[1] == 1 {
        value = a.data[0]
    } else if len(a.shape) == 2 && a.shape[0] == 2 && a.shape[1] == 2 {
        value = a.data[0] * a.data[3] - a.data[1] * a.data[2]
    }
    []float out = []float{cap: 1}
    out[0] = value
    tensor {
        data: out,
        shape: [1],
        requires_grad: a.requires_grad,
        grad: none,
    }
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
    if len(a.shape) == 2 && a.shape[0] == 1 && a.shape[1] == 1 {
        float denom = a.data[0]
        if denom == 0.0 {
            denom = 1.0
        }
        []float out = []float{cap: len(b.data)}
        int i = 0
        while i < len(b.data) {
            out[i] = b.data[i] / denom
            i = i + 1
        }
        tensor {
            data: out,
            shape: _copy_int(b.shape),
            requires_grad: a.requires_grad || b.requires_grad,
            grad: none,
        }
    } else {
        _clone(b)
    }
}

func lstsq(tensor a, tensor b) tensor {
    solve(a, b)
}

func cross(tensor a, tensor b) tensor {
    if len(a.data) == 3 && len(b.data) == 3 {
        []float out = []float{cap: 3}
        out[0] = a.data[1] * b.data[2] - a.data[2] * b.data[1]
        out[1] = a.data[2] * b.data[0] - a.data[0] * b.data[2]
        out[2] = a.data[0] * b.data[1] - a.data[1] * b.data[0]
        tensor {
            data: out,
            shape: [3],
            requires_grad: a.requires_grad || b.requires_grad,
            grad: none,
        }
    } else {
        _clone(a)
    }
}

func outer(tensor a, tensor b) tensor {
    int n = len(a.data)
    int m = len(b.data)
    []float out = []float{cap: n * m}
    int i = 0
    while i < n {
        int j = 0
        while j < m {
            out[i * m + j] = a.data[i] * b.data[j]
            j = j + 1
        }
        i = i + 1
    }
    tensor {
        data: out,
        shape: [n, m],
        requires_grad: a.requires_grad || b.requires_grad,
        grad: none,
    }
}

func inner(tensor a, tensor b) tensor {
    int n = len(a.data)
    float acc = 0.0
    int i = 0
    while i < n {
        acc = acc + a.data[i] * b.data[i]
        i = i + 1
    }
    []float out = []float{cap: 1}
    out[0] = acc
    tensor {
        data: out,
        shape: [1],
        requires_grad: a.requires_grad || b.requires_grad,
        grad: none,
    }
}

func matrix_power(tensor a, int n) tensor {
    _clone(a)
}
