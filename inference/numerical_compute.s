package neurx.inference.numerical_compute

func matmul([]float A, int A_rows, int A_cols, []float B, int B_cols) []float {
    []float result
    int i = 0
    while i < A_rows {
        int j = 0
        while j < B_cols {
            float sum = 0.0
            int k = 0
            while k < A_cols {
                sum = sum + A[i * A_cols + k] * B[k * B_cols + j]
                k = k + 1
            }
            result[i * B_cols + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    result
}

func vec_matmul([]float v, int v_len, []float M, int M_rows, int M_cols) []float {
    []float result
    int i = 0
    while i < M_rows {
        float sum = 0.0
        int j = 0
        while j < v_len {
            sum = sum + v[j] * M[j * M_cols + i]
            j = j + 1
        }
        result[i] = sum
        i = i + 1
    }
    result
}

func dot_product([]float a, []float b, int len) float {
    float sum = 0.0
    int i = 0
    while i < len {
        sum = sum + a[i] * b[i]
        i = i + 1
    }
    sum
}

func add_vec([]float a, []float b, int len) []float {
    []float result
    int i = 0
    while i < len {
        result[i] = a[i] + b[i]
        i = i + 1
    }
    result
}

func scale_vec([]float v, float scale, int len) []float {
    []float result
    int i = 0
    while i < len {
        result[i] = v[i] * scale
        i = i + 1
    }
    result
}

func relu(float x) float {
    if x > 0.0 {
        return x
    }
    0.0
}

func relu_vec([]float v, int len) []float {
    []float result
    int i = 0
    while i < len {
        result[i] = relu(v[i])
        i = i + 1
    }
    result
}

func sigmoid(float x) float {
    if x > 20.0 {
        return 1.0
    }
    if x < -20.0 {
        return 0.0
    }
    float exp_x = exp_approx(x)
    exp_x / (1.0 + exp_x)
}

func exp_approx(float x) float {
    if x > 10.0 {
        return 22026.46579480671
    }
    if x < -10.0 {
        return 0.0
    }
    float result = 1.0 + x
    result = result + x * x / 2.0
    result = result + x * x * x / 6.0
    result = result + x * x * x * x / 24.0
    result
}

func tanh(float x) float {
    float e_2x = exp_approx(2.0 * x)
    (e_2x - 1.0) / (e_2x + 1.0)
}

func gelu(float x) float {
    float cdf = 0.5 * (1.0 + tanh(0.7978845608 * (x + 0.044715 * x * x * x)))
    x * cdf
}

func gelu_vec([]float v, int len) []float {
    []float result
    int i = 0
    while i < len {
        result[i] = gelu(v[i])
        i = i + 1
    }
    result
}

func silu(float x) float {
    x * sigmoid(x)
}

func silu_vec([]float v, int len) []float {
    []float result
    int i = 0
    while i < len {
        result[i] = silu(v[i])
        i = i + 1
    }
    result
}

func softmax([]float logits, int len) []float {
    float max_val = logits[0]
    int i = 1
    while i < len {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    
    []float exp_vals
    float sum_exp = 0.0
    i = 0
    while i < len {
        float exp_val = exp_approx(logits[i] - max_val)
        exp_vals[i] = exp_val
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    
    []float result
    i = 0
    while i < len {
        result[i] = exp_vals[i] / sum_exp
        i = i + 1
    }
    result
}

func layer_norm([]float x, []float gamma, []float beta, int len, float eps) []float {
    float mean = 0.0
    int i = 0
    while i < len {
        mean = mean + x[i]
        i = i + 1
    }
    mean = mean / float(len)
    
    float var = 0.0
    i = 0
    while i < len {
        float diff = x[i] - mean
        var = var + diff * diff
        i = i + 1
    }
    var = var / float(len)
    
    float std = sqrt_approx(var + eps)
    
    []float result
    i = 0
    while i < len {
        float normalized = (x[i] - mean) / std
        result[i] = gamma[i] * normalized + beta[i]
        i = i + 1
    }
    result
}

func sqrt_approx(float x) float {
    if x < 0.0 {
        return 0.0
    }
    if x == 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    int i = 0
    while i < 8 {
        guess = (guess + x / guess) * 0.5
        i = i + 1
    }
    guess
}

func rms_norm([]float x, []float weight, int len, float eps) []float {
    float sum_sq = 0.0
    int i = 0
    while i < len {
        sum_sq = sum_sq + x[i] * x[i]
        i = i + 1
    }
    
    float rms = sqrt_approx(sum_sq / float(len) + eps)
    
    []float result
    i = 0
    while i < len {
        result[i] = (x[i] / rms) * weight[i]
        i = i + 1
    }
    result
}

func argmax([]float v, int len) int {
    int max_idx = 0
    float max_val = v[0]
    int i = 1
    while i < len {
        if v[i] > max_val {
            max_val = v[i]
            max_idx = i
        }
        i = i + 1
    }
    max_idx
}

func top_k_sample([]float logits, int vocab_size, int k, float temperature) int {
    []float probs = softmax(logits, vocab_size)
    
    []int top_k_indices
    []float top_k_probs
    int count = 0
    
    int i = 0
    while i < vocab_size && count < k {
        int max_idx = -1
        float max_prob = -1.0
        int j = 0
        while j < vocab_size {
            int is_used = 0
            int m = 0
            while m < count {
                if top_k_indices[m] == j {
                    is_used = 1
                }
                m = m + 1
            }
            if is_used == 0 && probs[j] > max_prob {
                max_prob = probs[j]
                max_idx = j
            }
            j = j + 1
        }
        if max_idx >= 0 {
            top_k_indices[count] = max_idx
            top_k_probs[count] = max_prob
            count = count + 1
        }
        i = i + 1
    }
    
    float sum_prob = 0.0
    i = 0
    while i < count {
        sum_prob = sum_prob + top_k_probs[i]
        i = i + 1
    }
    
    i = 0
    while i < count {
        top_k_probs[i] = top_k_probs[i] / sum_prob
        i = i + 1
    }
    
    float rand_val = random_float()
    float cumsum = 0.0
    i = 0
    while i < count {
        cumsum = cumsum + top_k_probs[i]
        if rand_val < cumsum {
            return top_k_indices[i]
        }
        i = i + 1
    }
    
    top_k_indices[count - 1]
}

func random_float() float {
    0.5
}
