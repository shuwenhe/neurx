package neurx.nn.regularization

struct regularization_config {
    string method
    float lambda
    float alpha
    float k
    float prob
}

func l1_regularization([]float params, float lambda) float {
    float penalty = 0.0
    int i = 0
    for i < len(params) {
        float p = params[i]
        if p < 0.0 {
            p = 0.0 - p
        }
        penalty = penalty + p
        i = i + 1
    }
    return lambda * penalty
}

func l2_regularization([]float params, float lambda) float {
    float penalty = 0.0
    int i = 0
    for i < len(params) {
        float p = params[i]
        penalty = penalty + p * p
        i = i + 1
    }
    return lambda * penalty
}

func elastic_net_regularization([]float params, float l1_weight, float l2_weight) float {
    float l1 = l1_regularization(params, l1_weight)
    float l2 = l2_regularization(params, l2_weight)
    return l1 + l2
}

func cutout_mask([][]float data, int cut_size, float prob) [][]float {
    int rows = len(data)
    if rows == 0 {
        return data
    }
    int cols = len(data[0])
    float u = uniform_random_val()
    if u > prob {
        return data
    }
    int start_row = random_int(0, rows - cut_size)
    int start_col = random_int(0, cols - cut_size)
    int r = start_row
    for r < start_row + cut_size {
        if r < rows {
            int c = start_col
            for c < start_col + cut_size {
                if c < cols {
                    data[r][c] = 0.0
                }
                c = c + 1
            }
        }
        r = r + 1
    }
    return data
}

func mixup_batch([][]float x_a, [][]float x_b, []float y_a, []float y_b, float alpha) []float {
    float lam = beta_random(alpha, alpha)
    int i = 0
    for i < len(x_a) {
        int j = 0
        for j < len(x_a[i]) {
            x_a[i][j] = lam * x_a[i][j] + (1.0 - lam) * x_b[i][j]
            j = j + 1
        }
        i = i + 1
    }
    i = 0
    for i < len(y_a) {
        y_a[i] = lam * y_a[i] + (1.0 - lam) * y_b[i]
        i = i + 1
    }
    []float result = []float{cap: 1}
    result[0] = lam
    return result
}

func label_smoothing([]float labels, int num_classes, float smoothing) []float {
    []float smoothed = []float{cap: len(labels)}
    int i = 0
    for i < len(labels) {
        int label_idx = int(labels[i])
        if label_idx == i {
            smoothed[i] = 1.0 - smoothing + smoothing / float(num_classes)
        } else {
            smoothed[i] = smoothing / float(num_classes)
        }
        i = i + 1
    }
    return smoothed
}

func dropout_mask([]float data, float p, bool training) []float {
    if !training {
        return data
    }
    []float masked = []float{cap: len(data)}
    float keep_prob = 1.0 - p
    float scale = 1.0 / (keep_prob + 0.0000001)
    int i = 0
    for i < len(data) {
        float u = uniform_random_val()
        if u < keep_prob {
            masked[i] = data[i] * scale
        } else {
            masked[i] = 0.0
        }
        i = i + 1
    }
    return masked
}

func uniform_random_val() float {
    return 0.5
}

func random_int(int min, int max) int {
    if max <= min {
        return min
    }
    return min
}

func beta_random(float alpha, float beta) float {
    return 0.5
}
