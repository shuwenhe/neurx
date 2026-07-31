package main
struct tensor_desc {
    []int shape
    []int strides
    int numel
}

struct tensor {
    []float storage
    tensor_desc desc
}
func shape_numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    return n
}

func contiguous_strides([]int shape) []int {
    int ndim = len(shape)
    []int strides = []int{cap: ndim}
    int stride = 1
    int i = ndim - 1
    while i >= 0 {
        strides[i] = stride
        stride = stride * shape[i]
        i = i - 1
    }
    return strides
}

func zeros_float(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    return out
}

func from_data([]float data, []int shape) tensor {
    int n = shape_numel(shape)
    []float storage = zeros_float(n)
    int i = 0
    while i < n {
        storage[i] = data[i]
        i = i + 1
    }
    return tensor {
        storage: storage,
        desc: tensor_desc {
            shape: shape,
            strides: contiguous_strides(shape),
            numel: n,
        },
    }
}

func add(tensor a, tensor b) tensor {
    tensor_desc ad = a.desc
    []float adata = a.storage
    []float bdata = b.storage
    []float storage = zeros_float(ad.numel)
    int i = 0
    while i < ad.numel {
        storage[i] = adata[i] + bdata[i]
        i = i + 1
    }
    return tensor {
        storage: storage,
        desc: a.desc,
    }
}

func matmul2d(tensor a, tensor b) tensor {
    tensor_desc ad = a.desc
    tensor_desc bd = b.desc
    []int ashape = ad.shape
    []int bshape = bd.shape
    []float adata = a.storage
    []float bdata = b.storage
    int m = ashape[0]
    int k = ashape[1]
    int n = bshape[1]
    []int shape = []int{cap: 2}
    shape[0] = m
    shape[1] = n
    []float storage = zeros_float(m * n)
    int row = 0
    while row < m {
        int col = 0
        while col < n {
            float acc = 0.0
            int p = 0
            while p < k {
                acc = acc + adata[row * k + p] * bdata[p * n + col]
                p = p + 1
            }
            storage[row * n + col] = acc
            col = col + 1
        }
        row = row + 1
    }
    return tensor {
        storage: storage,
        desc: tensor_desc {
            shape: shape,
            strides: contiguous_strides(shape),
            numel: m * n,
        },
    }
}

func assert_close(float actual, float expected, string name) {
    float diff = actual - expected
    if diff < 0.0 {
        diff = -diff
    }
    if diff < 0.0001 {
        println("PASS " + name)
    } else {
        println("FAIL " + name)
    }
}

func main() {
    println("NeurX tensor core runtime smoke")
    []float adata = []float{cap: 4}
    adata[0] = 1.0
    adata[1] = 2.0
    adata[2] = 3.0
    adata[3] = 4.0
    []float bdata = []float{cap: 4}
    bdata[0] = 5.0
    bdata[1] = 6.0
    bdata[2] = 7.0
    bdata[3] = 8.0
    []int shape = []int{cap: 2}
    shape[0] = 2
    shape[1] = 2
    tensor a = from_data(adata, shape)
    tensor b = from_data(bdata, shape)
    tensor c = add(a, b)
    tensor d = matmul2d(a, b)
    []float cdata = c.storage
    []float ddata = d.storage
    assert_close(cdata[0], 6.0, "add")
    assert_close(ddata[0], 19.0, "matmul 00")
    assert_close(ddata[3], 50.0, "matmul 11")
}
