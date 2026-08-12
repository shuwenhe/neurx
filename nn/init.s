package neurx.nn.init
struct init_config {
    string method
    float gain
    float a
    float b
    float mean
    float std
}


func new_init_config(string method) init_config {
    init_config {
        method: method,
        gain: 1.0,
        a: 0.0,
        b: 1.0,
        mean: 0.0,
        std: 1.0,
    }
}


func uniform_([]float tensor, float a, float b) []float {
    int i = 0
    while i < len(tensor) {
        float u = uniform_random()
        tensor[i] = a + u * (b - a)
        i = i + 1
    }
    return tensor
}


func normal_([]float tensor, float mean, float std) []float {
    int i = 0
    while i < len(tensor) {
        float z = box_muller_random()
        tensor[i] = mean + z * std
        i = i + 1
    }
    return tensor
}


func constant_([]float tensor, float val) []float {
    int i = 0
    while i < len(tensor) {
        tensor[i] = val
        i = i + 1
    }
    return tensor
}


func ones_([]float tensor) []float {
    return constant_(tensor, 1.0)
}


func zeros_([]float tensor) []float {
    return constant_(tensor, 0.0)
}


func eye_([]float tensor, int size) []float {
    int i = 0
    while i < size {
        int j = 0
        while j < size {
            tensor[i * size + j] = 0.0
            if i == j {
                tensor[i * size + j] = 1.0
            }
            j = j + 1
        }
        i = i + 1
    }
    return tensor
}


func xavier_uniform_([]float tensor, int fan_in, int fan_out) []float {
    float limit = calculate_gain_xavier() * sqrt_approx(6.0 / float(fan_in + fan_out))
    return uniform_(tensor, 0.0 - limit, limit)
}


func xavier_normal_([]float tensor, int fan_in, int fan_out) []float {
    float std = calculate_gain_xavier() * sqrt_approx(2.0 / float(fan_in + fan_out))
    return normal_(tensor, 0.0, std)
}


func kaiming_uniform_([]float tensor, int fan_in, int fan_out, float a) []float {
    float gain = sqrt_approx(2.0 / (1.0 + a * a))
    float std = gain / sqrt_approx(float(fan_in))
    float bound = sqrt_approx(3.0) * std
    return uniform_(tensor, 0.0 - bound, bound)
}


func kaiming_normal_([]float tensor, int fan_in, int fan_out, float a) []float {
    float gain = sqrt_approx(2.0 / (1.0 + a * a))
    float std = gain / sqrt_approx(float(fan_in))
    return normal_(tensor, 0.0, std)
}


func orthogonal_([]float tensor, int rows, int cols, float gain) []float {
    if rows < cols {
        rows = cols
    }
    []float gaussian = []float{cap: rows * cols}
    int i = 0
    while i < rows * cols {
        gaussian[i] = box_muller_random()
        i = i + 1
    }
    int k = 0
    while k < cols {
        float norm = 0.0
        int j = 0
        while j < rows {
            norm = norm + gaussian[j * cols + k] * gaussian[j * cols + k]
            j = j + 1
        }
        norm = sqrt_approx(norm)
        if norm > 0.0000001 {
            int j = 0
            while j < rows {
                gaussian[j * cols + k] = gaussian[j * cols + k] / norm
                j = j + 1
            }
        }
        k = k + 1
    }
    i = 0
    while i < len(tensor) {
        if i < len(gaussian) {
            tensor[i] = gain * gaussian[i]
        }
        i = i + 1
    }
    return tensor
}


func dirac_([]float tensor, int size) []float {
    int i = 0
    while i < len(tensor) {
        tensor[i] = 0.0
        i = i + 1
    }
    int center = size / 2
    int k = 0
    while k < size {
        tensor[center * size + k] = 1.0
        k = k + 1
    }
    return tensor
}


func sparse_([]float tensor, int size, float sparsity) []float {
    int count = 0
    int i = 0
    while i < len(tensor) {
        float u = uniform_random()
        if u < sparsity {
            tensor[i] = 0.0
        } else {
            tensor[i] = box_muller_random()
            count = count + 1
        }
        i = i + 1
    }
    if count > 0 {
        float std = sqrt_approx(1.0 / float(count))
        i = 0
        while i < len(tensor) {
            if tensor[i] != 0.0 {
                tensor[i] = tensor[i] * std
            }
            i = i + 1
        }
    }
    return tensor
}


func calculate_gain_xavier() float {
    return 1.0
}


func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    if x > 1.0 {
        y = x
    }
    int i = 0
    while i < 32 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    return y
}


func uniform_random() float {
    return 0.5
}


func box_muller_random() float {
    float u1 = uniform_random()
    float u2 = uniform_random()
    float r = sqrt_approx(-2.0 * log_approx(u1))
    float theta = 2.0 * 3.14159265358979323846 * u2
    return r * cos_approx(theta)
}


func log_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y_sq = y * y
    float result = 0.0
    float term = y
    int i = 0
    while i < 20 {
        result = result + term / float(2 * i + 1)
        term = term * y_sq
        i = i + 1
    }
    return 2.0 * result
}


func cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    float x8 = x6 * x2
    float x10 = x8 * x2
    return 1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0) + (x8 / 40320.0) - (x10 / 3628800.0)
}

