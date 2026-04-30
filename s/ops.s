package neurx.ops

use neurx.tensor.tensor

func add(tensor a, tensor b) tensor {
    add(a, b)
}

func mul(tensor a, tensor b) tensor {
    mul(a, b)
}

func matmul(tensor a, tensor b) tensor {
    matmul(a, b)
}

func relu(tensor a) tensor {
    relu(a)
}

func sigmoid(tensor a) tensor {
    sigmoid(a)
}

func tanh(tensor a) tensor {
    tanh(a)
}

func softmax(tensor a, int dim) tensor {
    softmax(a, dim)
}

func log_softmax(tensor a, int dim) tensor {
    log_softmax(a, dim)
}

func leaky_relu(tensor a, float negative_slope) tensor {
    leaky_relu(a, negative_slope)
}

func elu(tensor a, float alpha) tensor {
    elu(a, alpha)
}

func selu(tensor a) tensor {
    selu(a)
}

func gelu(tensor a, bool approximate) tensor {
    gelu(a, approximate)
}

func silu(tensor a) tensor {
    silu(a)
}

func mish(tensor a) tensor {
    mish(a)
}

func hardtanh(tensor a, float min_val, float max_val) tensor {
    hardtanh(a, min_val, max_val)
}

func hardswish(tensor a) tensor {
    hardswish(a)
}
