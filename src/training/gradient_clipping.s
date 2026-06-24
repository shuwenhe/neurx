// Global Gradient Clipping + Gradient Accumulation for 2T+ Models
// Prevents gradient explosion, enables effective batch_size scaling
// Critical for: training stability, large effective batch sizes (1M+ tokens)

package neurx.training.gradient_management

use neurx.tensor.tensor
use neurx.tensor.new
use neurx.ops

// ── Gradient Clipping Configuration ──
struct gradient_clip_config {
    // Clipping method
    string clip_type  // "norm" (global norm), "value" (per-element), "adaptive"
    
    float max_norm           // Maximum gradient norm (e.g., 1.0)
    float max_value          // Maximum per-element value (e.g., 5.0)
    
    // Adaptive clipping (for 2T models)
    bool use_adaptive_clipping
    float initial_clip_norm  // Starting clip norm (e.g., 5.0)
    float adaptation_rate     // How fast to adapt (e.g., 0.001)
    int adaptation_interval   // Steps between adaptations (e.g., 100)
    
    // Per-layer clipping options
    bool enable_per_layer_clipping
    float layer_max_ratio     // Max ratio of layer norm to global norm
}

// Default config for 2T model training
func default_2t_gradient_clip_config() gradient_clip_config {
    gradient_clip_config cfg
    cfg.clip_type = "norm"
    cfg.max_norm = 1.0
    cfg.max_value = 5.0
    cfg.use_adaptive_clipping = true
    cfg.initial_clip_norm = 5.0
    cfg.adaptation_rate = 0.001
    cfg.adaptation_interval = 100
    cfg.enable_per_layer_clipping = true
    cfg.layer_max_ratio = 5.0
    return cfg
}

// ── Adaptive Gradient Clipper State ──
struct adaptive_clipper_state {
    float current_clip_norm      // Current adaptive clip threshold
    int steps_since_adaptation   // Steps since last adaptation
    []float recent_norms         // History of recent gradient norms
    int max_history_size         // Maximum history to keep
}

func new_adaptive_clipper(config gradient_clip_config) adaptive_clipper_state {
    adaptive_clipper_state state
    state.current_clip_norm = config.initial_clip_norm
    state.steps_since_adaptation = 0
    state.recent_norms = []float{cap: 100}
    state.max_history_size = 100
    return state
}

// ── Global Norm Computation ──
// Compute total L2 norm across all gradients (critical for transformer stability)
func compute_global_gradient_norm(gradients []tensor) float {
    float total_squared_norm = 0.0
    
    int i = 0
    while i < len(gradients) {
        if len(gradients[i].data) > 0 {
            int j = 0
            while j < len(gradients[i].data) {
                float v = gradients[i].data[j]
                total_squared_norm = total_squared_norm + v * v
                j = j + 1
            }
        }
        i = i + 1
    }
    
    return sqrt_approx(total_squared_norm)
}

// Compute per-layer gradient norms (for monitoring and per-layer clipping)
func compute_per_layer_norms(gradients []tensor) []float {
    []float norms = []float{cap: len(gradients)}
    
    int i = 0
    while i < len(gradients) {
        float layer_norm_sq = 0.0
        
        if len(gradients[i].data) > 0 {
            int j = 0
            while j < len(gradients[i].data) {
                float v = gradients[i].data[j]
                layer_norm_sq = layer_norm_sq + v * v
                j = j + 1
            }
        }
        
        norms[i] = sqrt_approx(layer_norm_sq)
        i = i + 1
    }
    
    return norms
}

// ── Gradient Clipping Operations ──

// Clip gradients by global L2 norm (most common for transformers)
func clip_gradients_by_global_norm(
    gradients []tensor,
    max_norm float,
    config gradient_clip_config
) []tensor {
    
    // Compute global norm
    float global_norm = compute_global_gradient_norm(gradients)
    
    // If global_norm is zero or very small, return as-is
    if global_norm < 1e-8 {
        return gradients
    }
    
    // Compute clipping scale factor
    float clip_coef = max_norm / global_norm
    
    // Only clip if norm exceeds threshold
    if clip_coef >= 1.0 {
        return gradients  // No clipping needed
    }
    
    // Apply clipping to all gradients
    []tensor clipped_grads = []tensor{cap: len(gradients)}
    int i = 0
    while i < len(gradients) {
        []float clipped_data = []float{cap: len(gradients[i].data)}
        
        int j = 0
        while j < len(gradients[i].data) {
            clipped_data[j] = gradients[i].data[j] * clip_coef
            j = j + 1
        }
        
        clipped_grads[i] = new(clipped_data, copy_int(gradients[i].shape), gradients[i].requires_grad)
        i = i + 1
    }
    
    return clipped_grads
}

// Clip by per-element absolute value
func clip_gradients_by_value(
    gradients []tensor,
    max_value float
) []tensor {
    
    []tensor clipped_grads = []tensor{cap: len(gradients)}
    int i = 0
    while i < len(gradients) {
        []float clipped_data = []float{cap: len(gradients[i].data)}
        
        int j = 0
        while j < len(gradients[i].data) {
            float v = gradients[i].data[j]
            
            // Clamp to [-max_value, max_value]
            if v > max_value {
                clipped_data[j] = max_value
            } else if v < -max_value {
                clipped_data[j] = -max_value
            } else {
                clipped_data[j] = v
            }
            
            j = j + 1
        }
        
        clipped_grads[i] = new(clipped_data, copy_int(gradients[i].shape), gradients[i].requires_grad)
        i = i + 1
    }
    
    return clipped_grads
}

// Per-layer clipping (prevents any single layer from dominating)
func clip_gradients_per_layer(
    gradients []tensor,
    global_norm float,
    config gradient_clip_config
) []tensor {
    
    // Compute per-layer norms
    []float layer_norms = compute_per_layer_norms(gradients)
    
    []tensor clipped_grads = []tensor{cap: len(gradients)}
    int i = 0
    while i < len(gradients) {
        float layer_norm = layer_norms[i]
        
        // Check if this layer's norm is too large relative to global
        float max_allowed = global_norm * config.layer_max_ratio
        
        if layer_norm > max_allowed && layer_norm > 1e-8 {
            // Clip this layer
            float clip_coef = max_allowed / layer_norm
            
            []float clipped_data = []float{cap: len(gradients[i].data)}
            int j = 0
            while j < len(gradients[i].data) {
                clipped_data[j] = gradients[i].data[j] * clip_coef
                j = j + 1
            }
            
            clipped_grads[i] = new(clipped_data, copy_int(gradients[i].shape), gradients[i].requires_grad)
        } else {
            // No clipping needed for this layer
            clipped_grads[i] = gradients[i]
        }
        
        i = i + 1
    }
    
    return clipped_grads
}

// ── Adaptive Gradient Clipping ──
// Automatically adjusts clip threshold based on gradient statistics
func adaptive_gradient_clip(
    gradients []tensor,
    clipper adaptive_clipper_state,
    config gradient_clip_config
) ([]tensor, adaptive_clipper_state) {
    
    // Compute current global norm
    float current_norm = compute_global_gradient_norm(gradients)
    
    // Store in history
    if len(clipper.recent_norms) < clipper.max_history_size {
        clipper.recent_norms.push(current_norm)
    } else {
        // Shift history left and add new value
        int k = 0
        while k < len(clipper.recent_norms) - 1 {
            clipper.recent_norms[k] = clipper.recent_norms[k + 1]
            k = k + 1
        }
        clipper.recent_norms[len(clipper.recent_norms) - 1] = current_norm
    }
    
    // Adapt clip norm periodically
    clipper.steps_since_adaptation = clipper.steps_since_adaptation + 1
    
    if clipper.steps_since_adaptation >= config.adaptation_interval {
        // Compute moving average of recent norms
        if len(clipper.recent_norms) > 10 {
            float sum_norms = 0.0
            int m = 0
            while m < len(clipper.recent_norms) {
                sum_norms = sum_norms + clipper.recent_norms[m]
                m = m + 1
            }
            float avg_norm = sum_norms / float(len(clipper.recent_norms))
            
            // Adapt towards average norm with some headroom
            float target_clip = avg_norm * 1.5
            
            // Smooth adaptation
            clipper.current_clip_norm = 
                clipper.current_clip_norm * (1.0 - config.adaptation_rate) +
                target_clip * config.adaptation_rate
            
            // Keep within reasonable bounds
            if clipper.current_clip_norm < 0.1 {
                clipper.current_clip_norm = 0.1
            }
            if clipper.current_clip_norm > 100.0 {
                clipper.current_clip_norm = 100.0
            }
        }
        
        clipper.steps_since_adaptation = 0
    }
    
    // Clip using current adaptive threshold
    []tensor clipped_grads = clip_gradients_by_global_norm(
        gradients, 
        clipper.current_clip_norm, 
        config
    )
    
    return (clipped_grads, clipper)
}

// ── Combined Clipping Pipeline ──
// Full pipeline: value clip -> per-layer clip -> global norm clip
struct clipping_result {
    []tensor clipped_gradients
    float original_global_norm
    float final_global_norm
    float clip_ratio  // How much was clipped (0-1)
    adaptive_clipper_state clipper_state
}

func full_clipping_pipeline(
    gradients []tensor,
    clipper adaptive_clipper_state,
    config gradient_clip_config
) clipping_result {
    
    // Step 1: Record original norm
    float original_norm = compute_global_gradient_norm(gradients)
    
    // Step 2: Per-element value clipping (hard limit)
    []tensor current_grads = gradients
    if config.max_value > 0 {
        current_grads = clip_gradients_by_value(current_grads, config.max_value)
    }
    
    // Step 3: Per-layer clipping (if enabled)
    if config.enable_per_layer_clipping {
        float intermediate_norm = compute_global_gradient_norm(current_grads)
        current_grads = clip_gradients_per_layer(current_grads, intermediate_norm, config)
    }
    
    // Step 4: Adaptive global norm clipping
    adaptive_clipper_state updated_clipper
    []tensor final_grads
    (final_grads, updated_clipper) = adaptive_gradient_clip(current_grads, clipper, config)
    
    // Step 5: Compute final metrics
    float final_norm = compute_global_gradient_norm(final_grads)
    
    float clip_ratio = 0.0
    if original_norm > 1e-8 {
        clip_ratio = 1.0 - (final_norm / original_norm)
    }
    
    clipping_result result
    result.clipped_gradients = final_grads
    result.original_global_norm = original_norm
    result.final_global_norm = final_norm
    result.clip_ratio = clip_ratio
    result.clipper_state = updated_clipper
    
    return result
}

// ── Transformer-Specific Gradient Management ──
// Special handling for attention vs FFN layers

struct transformer_gradient_stats {
    float attention_grad_norm
    float ffn_grad_norm
    float embedding_grad_norm
    float output_head_grad_norm
    int num_attention_layers
    int num_ffn_layers
}

// Analyze gradient distribution across transformer components
func analyze_transformer_gradients(
    gradients []tensor,
    gradient_names []string  // e.g., ["layer_0.w_q", "layer_0.w_k", ...]
) transformer_gradient_stats {
    
    transformer_gradient_stats stats
    stats.attention_grad_norm = 0.0
    stats.ffn_grad_norm = 0.0
    stats.embedding_grad_norm = 0.0
    stats.output_head_grad_norm = 0.0
    stats.num_attention_layers = 0
    stats.num_ffn_layers = 0
    
    int i = 0
    while i < len(gradients) {
        string name = ""
        if i < len(gradient_names) {
            name = gradient_names[i]
        }
        
        float grad_norm_sq = 0.0
        if len(gradients[i].data) > 0 {
            int j = 0
            while j < len(gradients[i].data) {
                float v = gradients[i].data[j]
                grad_norm_sq = grad_norm_sq + v * v
                j = j + 1
            }
        }
        float grad_norm = sqrt_approx(grad_norm_sq)
        
        // Categorize by layer type
        if contains(name, "w_q") || contains(name, "w_k") || contains(name, "w_v") || contains(name, "w_o") {
            stats.attention_grad_norm = stats.attention_grad_norm + grad_norm
            stats.num_attention_layers = stats.num_attention_layers + 1
        } else if contains(name, "w_gate") || contains(name, "w_up") || contains(name, "w_down") {
            stats.ffn_grad_norm = stats.ffn_grad_norm + grad_norm
            stats.num_ffn_layers = stats.num_ffn_layers + 1
        } else if contains(name, "embedding") || contains(name, "token_embed") {
            stats.embedding_grad_norm = stats.embedding_grad_norm + grad_norm
        } else if contains(name, "lm_head") || contains(name, "output") {
            stats.output_head_grad_norm = stats.output_head_grad_norm + grad_norm
        }
        
        i = i + 1
    }
    
    return stats
}

// Helper: check if string contains substring
func contains(s string, substr string) bool {
    int slen = len(s)
    int sublen = len(substr)
    
    if sublen > slen { return false }
    
    int i = 0
    while i <= slen - sublen {
        bool match = true
        int j = 0
        while j < sublen {
            if s[i + j] != substr[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match { return true }
        i = i + 1
    }
    
    return false
}

// ── Usage Example in Training Loop ──
/*
// In your training loop:

gradient_clip_config clip_cfg = default_2t_gradient_clip_config()
adaptive_clipper_state clipper = new_adaptive_clipper(clip_cfg)

while step < max_steps:
    // Forward + backward pass
    loss, gradients = forward_backward(model, batch)
    
    // Full clipping pipeline
    clipping_result clip_res = full_clipping_pipeline(gradients, clipper, clip_cfg)
    clipper = clip_res.clipper_state
    
    // Log gradient statistics
    print("Step:", step, "Grad norm:", clip_res.original_global_norm, 
          "->", clip_res.final_global_norm, "Clip ratio:", clip_res.clip_ratio)
    
    // Optimizer step with clipped gradients
    optimizer.step(clip_res.clipped_gradients)
*/
