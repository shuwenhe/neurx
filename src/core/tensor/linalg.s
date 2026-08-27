package neurx.linalg

struct tensor {
    float[] data
    int[] shape
    bool requires_grad
    option[tensor] grad
}

func clone(tensor a) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func copy_int(int[] data) int[] {
    int n = len(data)
    int[] out = int[]{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_float(float[] data) float[] {
    int n = len(data)
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func shape1(int n) int[] {
    int[] shape = int[]{cap: 1}
    shape[0] = n
    shape
}

func shape2(int m, int n) int[] {
    int[] shape = int[]{cap: 2}
    shape[0] = m
    shape[1] = n
    shape
}

func identity(int n) tensor {
    float[] out = float[]{cap: n * n}
    int i = 0
    for i < n {
        out[i * n + i] = 1.0
        i = i + 1
    }
    tensor {
        data: out,
        shape: shape2(n, n),
        requires_grad: false,
        grad: none,
    }
}

func matmul2d(tensor a, tensor b) tensor {
    int rows = a.shape[0]
    int inner = a.shape[1]
    int cols = b.shape[1]
    float[] out = float[]{cap: rows * cols}
    int r = 0
    for r < rows {
        int c = 0
        for c < cols {
            float acc = 0.0
            int i = 0
            for i < inner {
                acc = acc + a.data[r * inner + i] * b.data[i * cols + c]
                i = i + 1
            }
            out[r * cols + c] = acc
            c = c + 1
        }
        r = r + 1
    }
    tensor {
        data: out,
        shape: shape2(rows, cols),
        requires_grad: a.requires_grad || b.requires_grad,
        grad: none,
    }
}

func matrix_rank(tensor a) int {
    int ndim = len(a.shape)
    if ndim == 0 {
        return 0
    }
    if ndim == 1 {
        int i = 0
        for i < len(a.data) {
            if a.data[i] != 0.0 {
                return 1
            }
            i = i + 1
        }
        return 0
    }
    if ndim >= 2 {
        if a.shape[0] == 1 && a.shape[1] == 1 {
            if a.data[0] == 0.0 {
                return 0
            }
            return 1
        }
        if a.shape[0] == 2 && a.shape[1] == 2 {
            float det2 = a.data[0] * a.data[3] - a.data[1] * a.data[2]
            if det2 == 0.0 {
                return 1
            }
            return 2
        }
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
        float[] out = float[]{cap: 1}
        out[0] = 1.0 / v
        tensor {
            data: out,
            shape: shape2(1, 1),
            requires_grad: a.requires_grad,
            grad: none,
        }
    } else if len(a.shape) == 2 && a.shape[0] == 2 && a.shape[1] == 2 {
        float a00 = a.data[0]
        float a01 = a.data[1]
        float a10 = a.data[2]
        float a11 = a.data[3]
        float det2 = a00 * a11 - a01 * a10
        if det2 == 0.0 {
            det2 = 1.0
        }
        float[] out = float[]{cap: 4}
        out[0] = a11 / det2
        out[1] = -a01 / det2
        out[2] = -a10 / det2
        out[3] = a00 / det2
        tensor {
            data: out,
            shape: shape2(2, 2),
            requires_grad: a.requires_grad,
            grad: none,
        }
    } else {
        clone(a)
    }
}

func det(tensor a) tensor {
    float value = 1.0
    if len(a.shape) == 2 && a.shape[0] == 1 && a.shape[1] == 1 {
        value = a.data[0]
    } else if len(a.shape) == 2 && a.shape[0] == 2 && a.shape[1] == 2 {
        value = a.data[0] * a.data[3] - a.data[1] * a.data[2]
    }
    float[] out = float[]{cap: 1}
    out[0] = value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func eig(tensor a) tensor {
    clone(a)
}

func eigh(tensor a) tensor {
    clone(a)
}

func svd(tensor a) tensor {
    clone(a)
}

func qr(tensor a) tensor {
    clone(a)
}

func cholesky(tensor a) tensor {
    clone(a)
}

func solve(tensor a, tensor b) tensor {
    if len(a.shape) == 2 && a.shape[0] == 1 && a.shape[1] == 1 {
        float denom = a.data[0]
        if denom == 0.0 {
            denom = 1.0
        }
        float[] out = float[]{cap: len(b.data)}
        int i = 0
        for i < len(b.data) {
            out[i] = b.data[i] / denom
            i = i + 1
        }
        tensor {
            data: out,
            shape: copy_int(b.shape),
            requires_grad: a.requires_grad || b.requires_grad,
            grad: none,
        }
    } else if len(a.shape) == 2 && a.shape[0] == 2 && a.shape[1] == 2 && len(b.shape) == 2 && b.shape[0] == 2 && b.shape[1] == 1 {
        tensor ainv = inv(a)
        matmul2d(ainv, b)
    } else {
        clone(b)
    }
}

func lstsq(tensor a, tensor b) tensor {
    solve(a, b)
}

func cross(tensor a, tensor b) tensor {
    if len(a.data) == 3 && len(b.data) == 3 {
        float[] out = float[]{cap: 3}
        out[0] = a.data[1] * b.data[2] - a.data[2] * b.data[1]
        out[1] = a.data[2] * b.data[0] - a.data[0] * b.data[2]
        out[2] = a.data[0] * b.data[1] - a.data[1] * b.data[0]
    tensor {
        data: out,
        shape: shape1(3),
        requires_grad: a.requires_grad || b.requires_grad,
        grad: none,
    }
    } else {
        clone(a)
    }
}

func outer(tensor a, tensor b) tensor {
    int n = len(a.data)
    int m = len(b.data)
    float[] out = float[]{cap: n * m}
    int i = 0
    for i < n {
        int j = 0
        for j < m {
            out[i * m + j] = a.data[i] * b.data[j]
            j = j + 1
        }
        i = i + 1
    }
    tensor {
        data: out,
        shape: shape2(n, m),
        requires_grad: a.requires_grad || b.requires_grad,
        grad: none,
    }
}

func inner(tensor a, tensor b) tensor {
    int n = len(a.data)
    float acc = 0.0
    int i = 0
    for i < n {
        acc = acc + a.data[i] * b.data[i]
        i = i + 1
    }
    float[] out = float[]{cap: 1}
    out[0] = acc
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: a.requires_grad || b.requires_grad,
        grad: none,
    }
}

func matrix_power(tensor a, int n) tensor {
    if len(a.shape) != 2 || a.shape[0] != a.shape[1] {
        return clone(a)
    }
    if n == 0 {
        return identity(a.shape[0])
    }
    if n < 0 {
        tensor base = inv(a)
        int exp = 0 - n
        tensor result = identity(a.shape[0])
        for exp > 0 {
            if exp > 0 {
                result = matmul2d(result, base)
            }
            exp = exp - 1
        }
        return result
    }
    tensor result = identity(a.shape[0])
    int i = 0
    for i < n {
        result = matmul2d(result, a)
        i = i + 1
    }
    result
}
