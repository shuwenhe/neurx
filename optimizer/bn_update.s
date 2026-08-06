package neurx.optimizer.bn_update
use neurx.tensor.tensor
use neurx.tensor.new
struct batch_norm_stats {
    []float running_mean
    []float running_var
    []int num_batches
}

func new_batch_norm_stats(int num_features) batch_norm_stats {
    batch_norm_stats {
        running_mean: make_zeros(num_features),
        running_var: make_ones(num_features),
        num_batches: make([]int, 0),
    }
}

func reset_running_stats(batch_norm_stats stats) batch_norm_stats {
    int i = 0
    while i < len(stats.running_mean) {
        stats.running_mean[i] = 0.0
        stats.running_var[i] = 1.0
        i = i + 1
    }
    stats.num_batches = make([]int, 0)
    return stats
}

func update_batch_norm_from_batch(
    batch_norm_stats stats,
    tensor batch_data
) batch_norm_stats {
    int num_features = len(stats.running_mean)
    int batch_size = len(batch_data.data)
    if batch_size <= 0 {
        return stats
    }
    []float batch_mean = make_zeros(num_features)
    []float batch_var = make_zeros(num_features)
    int f = 0
    while f < num_features {
        float sum_f = 0.0
        int count_f = 0
        int i = 0
        while i < batch_size {
            int idx = i * num_features + f
            if idx < len(batch_data.data) {
                sum_f = sum_f + batch_data.data[idx]
                count_f = count_f + 1
            }
            i = i + 1
        }
        if count_f > 0 {
            batch_mean[f] = sum_f / float(count_f)
        }
        f = f + 1
    }
    f = 0
    while f < num_features {
        float sum_sq = 0.0
        int count_sq = 0
        int i = 0
        while i < batch_size {
            int idx = i * num_features + f
            if idx < len(batch_data.data) {
                float diff = batch_data.data[idx] - batch_mean[f]
                sum_sq = sum_sq + diff * diff
                count_sq = count_sq + 1
            }
            i = i + 1
        }
        if count_sq > 0 {
            batch_var[f] = sum_sq / float(count_sq)
        }
        f = f + 1
    }
    float momentum = 0.1
    f = 0
    while f < num_features {
        stats.running_mean[f] = stats.running_mean[f] * (1.0 - momentum) + batch_mean[f] * momentum
        stats.running_var[f] = stats.running_var[f] * (1.0 - momentum) + batch_var[f] * momentum
        f = f + 1
    }
    return stats
}

func apply_batch_norm(
    batch_norm_stats stats,
    tensor input_data,
    float eps
) tensor {
    int batch_size = len(input_data.data)
    int num_features = len(stats.running_mean)
    []float out = make_zeros(batch_size)
    int i = 0
    while i < batch_size {
        int f = 0
        while f < num_features {
            int idx = i * num_features + f
            if idx < len(input_data.data) {
                float normalized = (input_data.data[idx] - stats.running_mean[f]) /
                                  (sqrt_approx(stats.running_var[f] + eps))
                out[idx] = normalized
            }
            f = f + 1
        }
        i = i + 1
    }
    return new(out, input_data.shape, input_data.requires_grad)
}

func make_zeros(int n) []float {
    []float arr = []float{cap: n}
    int i = 0
    while i < n {
        arr[i] = 0.0
        i = i + 1
    }
    return arr
}

func make_ones(int n) []float {
    []float arr = []float{cap: n}
    int i = 0
    while i < n {
        arr[i] = 1.0
        i = i + 1
    }
    return arr
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
