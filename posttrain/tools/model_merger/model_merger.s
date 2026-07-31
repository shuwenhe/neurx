package neurx.posttrain.tools.model_merger

use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

// Model merging utilities for combining multiple trained models

struct merge_config {
    string merge_method  // "average", "task_arithmetic", "ties", "dare"
    []float weights  // Weights for each model in merge
    float lambda  // Task arithmetic scaling factor
    int top_k_percent  // For TIES merging
    float drop_rate  // For DARE merging
    bool normalize_weights
}

struct model_delta {
    []tensor param_deltas
    []string param_names
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
    // Compute parameter deltas between finetuned and base model
    
    []tensor ft_params = finetuned.parameters()
    []tensor base_params = base.parameters()
    
    []tensor deltas = []tensor{cap: ft_params.len}
    []string names = []string{cap: ft_params.len}
    
    int i = 0
    while i < ft_params.len {
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
    []float weights
) module {
    // Simple weighted average of model parameters
    
    if models.len == 0 {
        return module{}
    }
    
    // Normalize weights
    float weight_sum = 0.0
    int i = 0
    while i < weights.len {
        weight_sum = weight_sum + weights[i]
        i = i + 1
    }
    
    []float norm_weights = []float{cap: weights.len}
    i = 0
    while i < weights.len {
        norm_weights[i] = weights[i] / weight_sum
        i = i + 1
    }
    
    // Initialize result with first model
    module result = models[0].clone()
    []tensor result_params = result.parameters()
    
    // Average parameters
    int p = 0
    while p < result_params.len {
        tensor avg_param = tensor_ops.zeros_like(result_params[p])
        
        int m = 0
        while m < models.len {
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
    []float weights,
    float lambda
) module {
    // Task arithmetic merging: base + λ * Σ(w_i * δ_i)
    
    module result = base.clone()
    []tensor result_params = result.parameters()
    
    int p = 0
    while p < result_params.len {
        tensor merged_delta = tensor_ops.zeros_like(result_params[p])
        
        // Combine weighted deltas
        int d = 0
        while d < deltas.len {
            tensor weighted_delta = tensor_ops.mul_scalar(
                deltas[d].param_deltas[p],
                weights[d]
            )
            merged_delta = tensor_ops.add(merged_delta, weighted_delta)
            d = d + 1
        }
        
        // Scale by lambda
        merged_delta = tensor_ops.mul_scalar(merged_delta, lambda)
        
        // Add to base
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
    []float weights,
    int top_k_percent
) module {
    // TIES merging: Trim, Elect Sign, Merge
    
    module result = base.clone()
    []tensor result_params = result.parameters()
    
    int p = 0
    while p < result_params.len {
        // Collect all deltas for this parameter
        []tensor param_deltas = []tensor{cap: deltas.len}
        int d = 0
        while d < deltas.len {
            param_deltas[d] = deltas[d].param_deltas[p]
            d = d + 1
        }
        
        // Step 1: Trim - keep only top-k% by magnitude
        tensor trimmed = trim_top_k(param_deltas, top_k_percent)
        
        // Step 2: Elect sign - resolve sign conflicts
        tensor signed = elect_sign(trimmed)
        
        // Step 3: Merge - weighted average
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
    []float weights,
    float drop_rate
) module {
    // DARE merging: Drop And REscale
    
    module result = base.clone()
    []tensor result_params = result.parameters()
    
    int p = 0
    while p < result_params.len {
        tensor merged_delta = tensor_ops.zeros_like(result_params[p])
        
        int d = 0
        while d < deltas.len {
            tensor delta = deltas[d].param_deltas[p]
            
            // Randomly drop delta values
            tensor mask = random_dropout_mask(delta, drop_rate)
            
            // Rescale remaining values
            float scale = 1.0 / (1.0 - drop_rate)
            tensor dropped = tensor_ops.mul(delta, mask)
            tensor rescaled = tensor_ops.mul_scalar(dropped, scale)
            
            // Weight and accumulate
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
    // Keep only top-k% of values by magnitude
    
    if deltas.len == 0 {
        return tensor{}
    }
    
    // Compute magnitudes
    tensor stacked = tensor_ops.stack(deltas, 0)
    tensor magnitudes = tensor_ops.abs(stacked)
    
    // Find threshold
    int total_elements = magnitudes.shape[0] * magnitudes.shape[1]
    int k = (total_elements * top_k_percent) / 100
    
    // Create mask for top-k
    tensor mask = tensor_ops.top_k_mask(magnitudes, k)
    
    // Apply mask
    tensor trimmed = tensor_ops.mul(stacked, mask)
    
    trimmed
}

func elect_sign(tensor trimmed) tensor {
    // Resolve sign conflicts by majority voting
    
    // Sum across models dimension
    tensor sum = tensor_ops.sum(trimmed, 0, true)
    
    // Sign of sum determines elected sign
    tensor sign_mask = tensor_ops.sign(sum)
    
    // Apply sign to original values
    tensor signed = tensor_ops.mul(trimmed, sign_mask)
    
    signed
}

func weighted_average(tensor values, []float weights) tensor {
    // Compute weighted average
    
    tensor result = tensor_ops.zeros_like(values)
    
    int i = 0
    while i < weights.len {
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
    // Create random dropout mask
    
    tensor mask = tensor_ops.random_uniform_like(t)
    mask = tensor_ops.gt(mask, drop_rate)
    tensor_ops.to_float(mask)
}
