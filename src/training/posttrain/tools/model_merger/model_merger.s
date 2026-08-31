package neurx.posttrain.tools.model_merger
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct merge_config {
    string merge_method
    float[] weights
    float lambda
    int top_k_percent
    float drop_rate
    bool normalize_weights
}

struct model_delta {
    []tensor param_deltas
    string[] param_names
}

func new_merge_config() merge_config {
    merge_config {
        merge_method: "average",
        weights: []float{},
        lambda: 1.0,
        top_k_percent: 20,
        drop_rate: 0.5,
        normalize_weights: true,
    }
}

func compute_model_delta(
    module finetuned,
    module base
) model_delta {
    []tensor ft_params = finetuned.parameters()
    []tensor base_params = base.parameters()
    []tensor deltas = make([]tensor, ft_params.len)
    string[] names = make([]string, ft_params.len)
    int i = 0
    for i < ft_params.len {
        tensor delta = tensor_ops.sub(ft_params[i], base_params[i])
        deltas[i] = delta
        names[i] = finetuned.param_names[i]
        i = i + 1
    }
    model_delta {
        param_deltas: deltas,
        param_names: names,
    }
}

func merge_models_average(
    []module models,
    float[] weights
) module {
    if models.len == 0 {
        return module{}
    }
    float weight_sum = 0.0
    int i = 0
    for i < weights.len {
        weight_sum = weight_sum + weights[i]
        i = i + 1
    }
    float[] norm_weights = make([]float, weights.len)
    i = 0
    for i < weights.len {
        norm_weights[i] = weights[i] / weight_sum
        i = i + 1
    }
    module result = models[0].clone()
    []tensor result_params = result.parameters()
    int p = 0
    for p < result_params.len {
        tensor avg_param = tensor_ops.zeros_like(result_params[p])
        int m = 0
        for m < models.len {
            []tensor model_params = models[m].parameters()
            tensor weighted = tensor_ops.mul_scalar(
                model_params[p],
                norm_weights[m]
            )
            avg_param = tensor_ops.add(avg_param, weighted)
            m = m + 1
        }
        result_params[p] = avg_param
        p = p + 1
    }
    result.load_parameters(result_params)
    result
}

func merge_task_arithmetic(
    module base,
    []model_delta deltas,
    float[] weights,
    float lambda
) module {
    module result = base.clone()
    []tensor result_params = result.parameters()
    int p = 0
    for p < result_params.len {
        tensor merged_delta = tensor_ops.zeros_like(result_params[p])
        int d = 0
        for d < deltas.len {
            tensor weighted_delta = tensor_ops.mul_scalar(
                deltas[d].param_deltas[p],
                weights[d]
            )
            merged_delta = tensor_ops.add(merged_delta, weighted_delta)
            d = d + 1
        }
        merged_delta = tensor_ops.mul_scalar(merged_delta, lambda)
        result_params[p] = tensor_ops.add(
            result_params[p],
            merged_delta
        )
        p = p + 1
    }
    result.load_parameters(result_params)
    result
}

func merge_ties(
    module base,
    []model_delta deltas,
    float[] weights,
    int top_k_percent
) module {
    module result = base.clone()
    []tensor result_params = result.parameters()
    int p = 0
    for p < result_params.len {
        []tensor param_deltas = make([]tensor, deltas.len)
        int d = 0
        for d < deltas.len {
            param_deltas[d] = deltas[d].param_deltas[p]
            d = d + 1
        }
        tensor trimmed = trim_top_k(param_deltas, top_k_percent)
        tensor signed = elect_sign(trimmed)
        tensor merged = weighted_average(signed, weights)
        result_params[p] = tensor_ops.add(
            result_params[p],
            merged
        )
        p = p + 1
    }
    result.load_parameters(result_params)
    result
}

func merge_dare(
    module base,
    []model_delta deltas,
    float[] weights,
    float drop_rate
) module {
    module result = base.clone()
    []tensor result_params = result.parameters()
    int p = 0
    for p < result_params.len {
        tensor merged_delta = tensor_ops.zeros_like(result_params[p])
        int d = 0
        for d < deltas.len {
            tensor delta = deltas[d].param_deltas[p]
            tensor mask = random_dropout_mask(delta, drop_rate)
            float scale = 1.0 / (1.0 - drop_rate)
            tensor dropped = tensor_ops.mul(delta, mask)
            tensor rescaled = tensor_ops.mul_scalar(dropped, scale)
            tensor weighted = tensor_ops.mul_scalar(rescaled, weights[d])
            merged_delta = tensor_ops.add(merged_delta, weighted)
            d = d + 1
        }
        result_params[p] = tensor_ops.add(
            result_params[p],
            merged_delta
        )
        p = p + 1
    }
    result.load_parameters(result_params)
    result
}

func trim_top_k([]tensor deltas, int top_k_percent) tensor {
    if deltas.len == 0 {
        return tensor{}
    }
    tensor stacked = tensor_ops.stack(deltas, 0)
    tensor magnitudes = tensor_ops.abs(stacked)
    int total_elements = magnitudes.shape[0] * magnitudes.shape[1]
    int k = (total_elements * top_k_percent) / 100
    tensor mask = tensor_ops.top_k_mask(magnitudes, k)
    tensor trimmed = tensor_ops.mul(stacked, mask)
    trimmed
}

func elect_sign(tensor trimmed) tensor {
    tensor sum = tensor_ops.sum(trimmed, 0, true)
    tensor sign_mask = tensor_ops.sign(sum)
    tensor signed = tensor_ops.mul(trimmed, sign_mask)
    signed
}

func weighted_average(tensor values, float[] weights) tensor {
    tensor result = tensor_ops.zeros_like(values)
    int i = 0
    for i < weights.len {
        tensor weighted = tensor_ops.mul_scalar(
            tensor_ops.index_select(values, 0, i),
            weights[i]
        )
        result = tensor_ops.add(result, weighted)
        i = i + 1
    }
    result
}

func random_dropout_mask(tensor t, float drop_rate) tensor {
    tensor mask = tensor_ops.random_uniform_like(t)
    mask = tensor_ops.gt(mask, drop_rate)
    tensor_ops.to_float(mask)
}
