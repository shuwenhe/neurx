package kernels

type reduction_op string

const (
    reduce_sum      reduction_op = "sum"
    reduce_mean     reduction_op = "mean"
    reduce_max      reduction_op = "max"
    reduce_min      reduction_op = "min"
)

type norm_type string

const (
    norm_layer      norm_type = "layer_norm"
    norm_batch      norm_type = "batch_norm"
    norm_group      norm_type = "group_norm"
    norm_instance   norm_type = "instance_norm"
)

struct reduction_config {
    reduction_op op
    int32 axis
    bool keep_dims
}

struct norm_config {
    norm_type type
    float32 epsilon
    bool affine
}

struct oink_ops {
    map[string]interface{} kernel_cache
    int32 total_ops_executed
    float32 total_execution_time_us
}

func create_oink_ops() oink_ops* {
    return *oink_ops{
        kernel_cache: make(map[string]interface{}),
        total_ops_executed: 0,
        total_execution_time_us: 0.0,
    }
}

func (oink_ops* ops) reduce_sum(vec[vec[float32]] input, int32 axis) vec[float32] {
    result := make(vec[float32])

    if len(input) == 0 {
        return result
    }

    if axis == 0 {
        for j := 0; j < len(input[0]); j = j + 1 {
            sum := 0.0
            for i := 0; i < len(input); i = i + 1 {
                sum = sum + input[i][j]
            }
            result = append(result, sum)
        }
    } else if axis == 1 {
        for i := 0; i < len(input); i = i + 1 {
            sum := 0.0
            for j := 0; j < len(input[i]); j = j + 1 {
                sum = sum + input[i][j]
            }
            result = append(result, sum)
        }
    }

    return result
}

func (oink_ops* ops) reduce_mean(vec[vec[float32]] input, int32 axis) vec[float32] {
    sum_result := ops.reduce_sum(input, axis)

    result := make(vec[float32])

    divisor := 1.0
    if axis == 0 && len(input) > 0 {
        divisor = float32(len(input))
    } else if axis == 1 && len(input) > 0 {
        divisor = float32(len(input[0]))
    }

    for i := 0; i < len(sum_result); i = i + 1 {
        result = append(result, sum_result[i] / divisor)
    }

    return result
}

func (oink_ops* ops) reduce_max(vec[float32] input) float32 {
    if len(input) == 0 {
        return 0.0
    }

    max_val := input[0]
    for i := 1; i < len(input); i = i + 1 {
        if input[i] > max_val {
            max_val = input[i]
        }
    }

    return max_val
}

func (oink_ops* ops) reduce_min(vec[float32] input) float32 {
    if len(input) == 0 {
        return 0.0
    }

    min_val := input[0]
    for i := 1; i < len(input); i = i + 1 {
        if input[i] < min_val {
            min_val = input[i]
        }
    }

    return min_val
}

func (oink_ops* ops) layer_norm(vec[float32] input, float32 epsilon) vec[float32] {
    mean := 0.0
    for i := 0; i < len(input); i = i + 1 {
        mean = mean + input[i]
    }
    mean = mean / float32(len(input))

    variance := 0.0
    for i := 0; i < len(input); i = i + 1 {
        diff := input[i] - mean
        variance = variance + (diff * diff)
    }
    variance = variance / float32(len(input))

    normalized := make(vec[float32])
    std := 0.0
    if variance > 0.0 {
        std = 1.0 / (variance + epsilon)
    }

    for i := 0; i < len(input); i = i + 1 {
        normalized = append(normalized, (input[i] - mean) * std)
    }

    return normalized
}

func (oink_ops* ops) batch_norm(vec[vec[float32]] input, float32 epsilon) vec[vec[float32]] {
    result := make(vec[vec[float32]])

    for i := 0; i < len(input); i = i + 1 {
        normalized := ops.layer_norm(input[i], epsilon)
        result = append(result, normalized)
    }

    return result
}

func (oink_ops* ops) group_norm(vec[float32] input, int32 num_groups, float32 epsilon) vec[float32] {
    group_size := len(input) / num_groups
    if group_size <= 0 {
        group_size = 1
    }

    result := make(vec[float32])

    for g := 0; g < num_groups; g = g + 1 {
        start := g * group_size
        end := start + group_size

        if end > len(input) {
            end = len(input)
        }

        group := make(vec[float32])
        for i := start; i < end; i = i + 1 {
            group = append(group, input[i])
        }

        normalized := ops.layer_norm(group, epsilon)

        for i := 0; i < len(normalized); i = i + 1 {
            result = append(result, normalized[i])
        }
    }

    return result
}

func (oink_ops* ops) relu(vec[float32] input) vec[float32] {
    output := make(vec[float32])

    for i := 0; i < len(input); i = i + 1 {
        if input[i] > 0.0 {
            output = append(output, input[i])
        } else {
            output = append(output, 0.0)
        }
    }

    return output
}

func (oink_ops* ops) swish(vec[float32] input) vec[float32] {
    output := make(vec[float32])

    for i := 0; i < len(input); i = i + 1 {
        sigmoid := 1.0 / (1.0 + (2.718 ^ (-input[i])))
        output = append(output, input[i] * sigmoid)
    }

    return output
}

func (oink_ops* ops) fused_linear_activation(vec[vec[float32]] weight, vec[float32] bias, vec[float32] input, string activation) vec[float32] {
    output := make(vec[float32])

    for i := 0; i < len(weight); i = i + 1 {
        result := 0.0
        for j := 0; j < len(weight[i]) && j < len(input); j = j + 1 {
            result = result + (weight[i][j] * input[j])
        }

        if i < len(bias) {
            result = result + bias[i]
        }

        if activation == "relu" {
            if result < 0.0 {
                result = 0.0
            }
        } else if activation == "swish" {
            sigmoid := 1.0 / (1.0 + (2.718 ^ (-result)))
            result = result * sigmoid
        }

        output = append(output, result)
    }

    return output
}

func (oink_ops* ops) fused_attention_qkv(vec[float32] query, vec[float32] key, vec[float32] value, float32 scale) vec[float32] {
    scores := make(vec[float32])

    for i := 0; i < len(query) && i < len(key); i = i + 1 {
        score := (query[i] * key[i]) * scale
        scores = append(scores, score)
    }

    max_score := ops.reduce_max(scores)

    sum_exp := 0.0
    exp_scores := make(vec[float32])

    for i := 0; i < len(scores); i = i + 1 {
        exp_val := 2.718 ^ (scores[i] - max_score)
        exp_scores = append(exp_scores, exp_val)
        sum_exp = sum_exp + exp_val
    }

    output := make(vec[float32])
    for i := 0; i < len(exp_scores) && i < len(value); i = i + 1 {
        attn_weight := exp_scores[i] / sum_exp
        output = append(output, attn_weight * value[i])
    }

    return output
}

func (oink_ops* ops) get_oink_ops_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["total_ops"] = ops.total_ops_executed
    stats["total_time_us"] = ops.total_execution_time_us
    stats["avg_op_time_us"] = 0.0

    if ops.total_ops_executed > 0 {
        stats["avg_op_time_us"] = ops.total_execution_time_us / float32(ops.total_ops_executed)
    }

    return stats
}
