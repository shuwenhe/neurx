package neurx.einsum
struct tensor {
    float[] data
    int[] shape
    bool requires_grad
    option[tensor] grad
}
func einsum(string equation, tensor a, tensor b) tensor {
    if equation == "ij,jk.ik" || equation == "ab,bc.ac" || equation == "mn,nk.mk" {
        if len(a.shape) == 2 && len(b.shape) == 2 {
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
                shape: [rows, cols],
                requires_grad: a.requires_grad || b.requires_grad,
                grad: none,
            }
        } else {
            tensor {
                data: a.data,
                shape: a.shape,
                requires_grad: a.requires_grad,
                grad: none,
            }
        }
    } else if equation == "i,i." || equation == "a,a." {
        int n = len(a.data)
        if len(b.data) < n {
            n = len(b.data)
        }
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
            shape: [1],
            requires_grad: a.requires_grad || b.requires_grad,
            grad: none,
        }
    } else if equation == "i,j.ij" || equation == "a,b.ab" {
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
            shape: [n, m],
            requires_grad: a.requires_grad || b.requires_grad,
            grad: none,
        }
    } else {
        tensor {
            data: a.data,
            shape: a.shape,
            requires_grad: a.requires_grad,
            grad: none,
        }
    }
}
