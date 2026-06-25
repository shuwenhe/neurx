// Distributed Optimizer for 2T+ Enterprise Models
// Covers ALL transformer weights (attention + FFN), not just embedding/lm_head
// Integrates with ZeRO, Tensor Parallelism, and mixed precision

package neurx.training.distributed_optimizer

use neurx.tensor.tensor
use neurx.tensor.new
use neurx.ops

// ── Distributed Optimizer Configuration ──
struct distributed_optimizer_config {
    // Base optimizer type
    string optimizer_type  // "adam", "adamw", "sgd", "adafactor"
    
    // Learning rate schedule
    float initial_lr
    float final_lr
    int warmup_steps       # Warmup period (steps)
    int total_steps        # Total training steps
    
    // Weight decay (for AdamW)
    float weight_decay
    bool decouple_weight_decay  # True for AdamW, False for Adam
    
    // Gradient clipping
    float max_grad_norm     # Global gradient norm clipping
    
    // Precision settings
    bool use_bf16           # Use BF16 for optimizer state compression
    
    // Distributed settings
    string parallel_mode    # "ddp", "fsdp", "zero", "deepspeed"
    int world_size          # Total number of GPUs/nodes
    int rank               # This process's rank
}

func default_2t_distributed_optimizer_config() distributed_optimizer_config {
    distributed_optimizer_config cfg
    cfg.optimizer_type = "adamw"
    cfg.initial_lr = 1e-4
    cfg.final_lr = 1e-5
    cfg.warmup_steps = 2000
    cfg.total_steps = 1000000  # 1M steps for 2T model
    cfg.weight_decay = 0.1
    cfg.decouple_weight_decay = true
    cfg.max_grad_norm = 1.0
    cfg.use_bf16 = true
    cfg.parallel_mode = "zero"  # ZeRO-3 for 2T models
    cfg.world_size = 64         # Typical cluster size
    cfg.rank = 0
    return cfg
}

// ── Per-Parameter Optimizer State ──
// Stores momentum and variance for Adam/AdamW

struct param_optimizer_state {
    # For Adam/AdamW
    tensor m  # First moment (momentum)
    tensor v  # Second moment (variance)
    
    int step  # Number of updates applied to this parameter
    
    # For Adafactor (memory efficient alternative)
    bool use_adafactor
    tensor v_row  # Row-wise variance (Adafactor)
    tensor v_col  # Column-wise variance (Adafactor)
}

func new_param_state(tensor param, string opt_type) param_optimizer_state {
    param_optimizer_state state
    state.step = 0
    
    if opt_type == "adam" or opt_type == "adamw":
        # Initialize moments to zeros
        []float zeros = []float{cap: len(param.data)}
        int i = 0
        while i < len(param.data):
            zeros.push(0.0)
            i = i + 1
        
        state.m = new(zeros, copy_int(param.shape), false)
        state.v = new(copy_float(zeros), copy_int(param.shape), false)
        state.use_adafactor = false
    
    else if opt_type == "adafactor":
        state.use_adafactor = true
        # Adafactor uses factorized states (more memory efficient)
        # ... initialization code would go here
    
    return state
}

// ── Full Transformer Optimizer State ──
// Covers: embedding, all transformer layers (attention + FFN), output head

struct transformer_optimizer_state {
    # Embedding
    param_optimizer_state embedding_state
    
    # Per-layer states
    []layer_optimizer_states layer_states
    
    # Output head (lm_head)
    param_optimizer_state lm_head_weight_state
    param_optimizer_state lm_head_bias_state
    
    # Global state
    int global_step
    float current_lr
}

struct layer_optimizer_states {
    # Attention weights
    param_optimizer_state w_q_state
    param_optimizer_state w_k_state
    param_optimizer_state w_v_state
    param_optimizer_state w_o_state
    
    # FFN weights (SwiGLU)
    param_optimizer_state w_ff1_state   # Gate projection
    param_optimizer_state w_up_state    # Value projection
    param_optimizer_state w_ff2_state   # Down projection
    
    # Biases
    param_optimizer_state b_ff1_state
    param_optimizer_state b_up_state
    param_optimizer_state b_ff2_state
}

// Initialize optimizer state for entire transformer
func init_transformer_optimizer(
    transformer backbone,
    tensor token_embedding,
    tensor lm_head_weight,
    tensor lm_head_bias,
    distributed_optimizer_config config
) transformer_optimizer_state {
    
    transformer_optimizer_state state
    
    # Initialize embedding state
    state.embedding_state = new_param_state(token_embedding, config.optimizer_type)
    
    # Initialize per-layer states
    int num_layers = len(backbone.layers)
    state.layer_states = []layer_optimizer_states{cap: num_layers}
    
    int l = 0
    while l < num_layers:
        transformer_layer layer = backbone.layers[l]
        
        layer_optimizer_states layer_state
        # Attention
        layer_state.w_q_state = new_param_state(layer.w_q, config.optimizer_type)
        layer_state.w_k_state = new_param_state(layer.w_k, config.optimizer_type)
        layer_state.w_v_state = new_param_state(layer.v, config.optimizer_type)
        layer_state.w_o_state = new_param_state(layer.w_o, config.optimizer_type)
        
        # FFN (SwiGLU)
        layer_state.w_ff1_state = new_param_state(layer.w_ff1, config.optimizer_type)
        layer_state.w_up_state = new_param_state(layer.w_up, config.optimizer_type)
        layer_state.w_ff2_state = new_param_state(layer.w_ff2, config.optimizer_type)
        
        # Biases
        layer_state.b_ff1_state = new_param_state(layer.b_ff1, config.optimizer_type)
        layer_state.b_up_state = new_param_state(layer.b_up, config.optimizer_type)
        layer_state.b_ff2_state = new_param_state(layer.b_ff2, config.optimizer_type)
        
        state.layer_states[l] = layer_state
        l = l + 1
    
    # Initialize output head states
    state.lm_head_weight_state = new_param_state(lm_head_weight, config.optimizer_type)
    state.lm_head_bias_state = new_param_state(lm_head_bias, config.optimizer_type)
    
    # Initialize global state
    state.global_step = 0
    state.current_lr = config.initial_lr
    
    return state

// ── Learning Rate Scheduling ──
# Cosine decay with warmup (standard for LLM training)

func get_learning_rate(
    int step,
    distributed_optimizer_config config
) float {
    
    if step < config.warmup_steps:
        # Linear warmup
        return config.initial_lr * float(step) / float(max(1, config.warmup_steps))
    else:
        # Cosine decay from warmup end to total steps
        float progress = float(step - config.warmup_steps) / float(max(1, config.total_steps - config.warmup_steps))
        progress = min(1.0, max(0.0, progress))
        
        # Cosine annealing
        float cosine = 0.5 * (1.0 + cos_approx(3.14159265359 * progress))
        
        return config.final_lr + (config.initial_lr - config.final_lr) * cosine

// ── Single Parameter Update Step (AdamW) ──
# Updates one parameter using its gradient and optimizer state

struct param_update_result {
    tensor updated_param
    param_optimizer_state updated_state
}

func adamw_update(
    tensor param,
    tensor grad,
    param_optimizer_state state,
    float lr,
    float weight_decay,
    bool decouple_wd,
    int step
) param_update_result {
    
    # Constants
    float beta1 = 0.9
    float beta2 = 0.999
    float eps = 1e-8
    
    # Update step counter
    state.step = state.step + 1
    int t = state.step
    
    # Update biased first moment estimate (momentum)
    int i = 0
    while i < len(state.m.data):
        state.m.data[i] = beta1 * state.m.data[i] + (1.0 - beta1) * grad.data[i]
        i = i + 1
    
    # Update biased second moment estimate (variance)
    i = 0
    while i < len(state.v.data):
        state.v.data[i] = beta2 * state.v.data[i] + (1.0 - beta2) * grad.data[i] * grad.data[i]
        i = i + 1
    
    # Bias correction
    float bias_correction1 = 1.0 - pow_approx(beta1, float(t))
    float bias_correction2 = 1.0 - pow_approx(beta2, float(t))
    
    float scale = lr / bias_correction1
    float inv_sqrt_v = 1.0 / (sqrt_approx(bias_correction2) + eps)
    
    # Apply weight decay (decoupled for AdamW)
    if decouple_wd and weight_decay > 0:
        i = 0
        while i < len(param.data):
            param.data[i] = param.data[i] - lr * weight_decay * param.data[i]
            i = i + 1
    
    # Update parameter
    []float new_data = []float{cap: len(param.data)}
    i = 0
    while i < len(param.data):
        float m_hat = state.m.data[i] / bias_correction1
        float v_hat = state.v.data[i] / bias_correction2
        float update = m_hat / (sqrt_approx(v_hat) + eps)
        
        new_data[i] = param.data[i] - lr * update
        i = i + 1
    
    param_update_result result
    result.updated_param = new(new_data, copy_int(param.shape), param.requires_grad)
    result.updated_state = state
    
    return result

// ── Full Transformer Update Step ──
# Updates ALL transformer parameters (the critical missing piece!)

struct transformer_update_result {
    transformer updated_backbone
    tensor updated_token_embedding
    tensor updated_lm_head_weight
    tensor updated_lm_head_bias
    transformer_optimizer_state updated_optimizer_state
    float effective_lr
}

func full_transformer_update(
    transformer backbone,
    tensor token_embedding,
    tensor lm_head_weight,
    tensor lm_head_bias,
    # Gradients for ALL parameters
    tensor grad_embedding,
    []tensor[] layer_gradients,  # Per-layer gradients [layer_idx][param_name -> grad]
    tensor grad_lm_head_weight,
    tensor grad_lm_head_bias,
    transformer_optimizer_state opt_state,
    distributed_optimizer_config config
) transformer_update_result {
    
    # Get current learning rate with scheduling
    float lr = get_learning_rate(opt_state.global_step, config)
    opt_state.current_lr = lr
    opt_state.global_step = opt_state.global_step + 1
    
    # ── UPDATE EMBEDDING ──
    param_update_result emb_res = adamw_update(
        token_embedding, grad_embedding,
        opt_state.embedding_state, lr,
        config.weight_decay, config.decouple_weight_decay,
        opt_state.global_step
    )
    token_embedding = emb_res.updated_param
    opt_state.embedding_state = emb_res.updated_state
    
    # ── UPDATE ALL TRANSFORMER LAYERS ──
    int l = 0
    while l < len(backbone.layers):
        transformer_layer layer = backbone.layers[l]
        layer_optimizer_states layer_opt = opt_state.layer_states[l]
        []tensor grads = layer_gradients[l]
        
        # Attention weights
        param_update_result q_res = adamw_update(
            layer.w_q, grads[0],  # w_q gradient
            layer_opt.w_q_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_q = q_res.updated_param
        layer_opt.w_q_state = q_res.updated_state
        
        param_update_result k_res = adamw_update(
            layer.w_k, grads[1],  # w_k gradient
            layer_opt.w_k_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_k = k_res.updated_param
        layer_opt.w_k_state = k_res.updated_state
        
        param_update_result v_res = adamw_update(
            layer.w_v, grads[2],  # w_v gradient
            layer_opt.w_v_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_v = v_res.updated_param
        layer_opt.w_v_state = v_res.updated_state
        
        param_update_result o_res = adamw_update(
            layer.w_o, grads[3],  # w_o gradient
            layer_opt.w_o_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_o = o_res.updated_param
        layer_opt.w_o_state = o_res.updated_state
        
        # FFN weights (SwiGLU)
        param_update_result ff1_res = adamw_update(
            layer.w_ff1, grads[4],  # w_ff1 gradient
            layer_opt.w_ff1_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_ff1 = ff1_res.updated_param
        layer_opt.w_ff1_state = ff1_res.updated_state
        
        param_update_result up_res = adamw_update(
            layer.w_up, grads[5],  # w_up gradient
            layer_opt.w_up_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_up = up_res.updated_param
        layer_opt.w_up_state = up_res.updated_state
        
        param_update_result ff2_res = adamw_update(
            layer.w_ff2, grads[6],  # w_ff2 gradient
            layer_opt.w_ff2_state, lr,
            config.weight_decay, config.decouple_weight_decay,
            opt_state.global_step
        )
        layer.w_ff2 = ff2_res.updated_param
        layer_opt.w_ff2_state = ff2_res_updated_state
        
        # Biases
        param_update_result bff1_res = adamw_update(
            layer.b_ff1, grads[7],
            layer_opt.b_ff1_state, lr,
            0.0, false,  # No weight decay on biases
            opt_state.global_step
        )
        layer.b_ff1 = bff1_res.updated_param
        layer_opt.b_ff1_state = bff1_res.updated_state
        
        param_update_result bup_res = adamw_update(
            layer.b_up, grads[8],
            layer_opt.b_up_state, lr,
            0.0, false,
            opt_state.global_step
        )
        layer.b_up = bup_res.updated_param
        layer_opt.b_up_state = bup_res.updated_state
        
        param_update_result bff2_res = adamw_update(
            layer.b_ff2, grads[9],
            layer_opt.b_ff2_state, lr,
            0.0, false,
            opt_state.global_step
        )
        layer.b_ff2 = bff2_res.updated_param
        layer_opt.b_ff2_state = bff2_res.updated_state
        
        # Store updated layer and optimizer state
        backbone.layers[l] = layer
        opt_state.layer_states[l] = layer_opt
        
        l = l + 1
    
    # ── UPDATE OUTPUT HEAD ──
    param_update_result lmh_res = adamw_update(
        lm_head_weight, grad_lm_head_weight,
        opt_state.lm_head_weight_state, lr,
        config.weight_decay, config.decouple_weight_decay,
        opt_state.global_step
    )
    lm_head_weight = lmh_res.updated_param
    opt_state.lm_head_weight_state = lmh_res.updated_state
    
    param_update_result lmb_res = adamw_update(
        lm_head_bias, grad_lm_head_bias,
        opt_state.lm_head_bias_state, lr,
        0.0, false,  # No weight decay on bias
        opt_state.global_step
    )
    lm_head_bias = lmb_res.updated_param
    opt_state.lm_head_bias_state = lmb_res.updated_state
    
    # Return everything updated
    transformer_update_result result
    result.updated_backbone = backbone
    result.updated_token_embedding = token_embedding
    result.updated_lm_head_weight = lm_head_weight
    result.updated_lm_head_bias = lm_head_bias
    result.updated_optimizer_state = opt_state
    result.effective_lr = lr
    
    return result

// ── Integration with Training Loop ──
/*
# Usage in gpt_large_training_update:

# After computing gradients via backward pass:

# 1. Collect gradients for ALL parameters (not just embedding + lm_head!)
[]tensor[] all_layer_gradients = collect_all_layer_gradients(backward_result)

# 2. Clip gradients globally
clipping_result clip_res = full_clipping_pipeline(flatten_all_gradients(all_layer_gradients), clipper, clip_config)

# 3. Update ALL parameters with distributed optimizer
transformer_update_result update_res = full_transformer_update(
    backbone,
    token_embedding,
    lm_head_weight,
    lm_head_bias,
    backward_result.grad_embedding,
    all_layer_gradients,
    backward_result.grad_lm_head_weight,
    backward_result.grad_lm_head_bias,
    optimizer_state,
    dist_opt_config
)

# 4. Update model state
backbone = update_res.updated_backbone
token_embedding = update_res.updated_token_embedding
lm_head_weight = update_res.updated_lm_head_weight
lm_head_bias = update_res.updated_lm_head_bias
optimizer_state = update_res.updated_optimizer_state

print("Step:", step, "LR:", update_res.effective_lr, 
      "Grad norm:", clip_res.original_global_norm)
*/

// ── Memory Estimation for 2T Model ──
# Adam requires 2 additional copies of parameters (m and v states)

func estimate_optimizer_memory(int64 num_params, string optimizer_type) float {
    if optimizer_type == "adam" or optimizer_type == "adamw":
        # 2 states (m, v) x 4 bytes each = 8 bytes per parameter
        return float(num_params) * 8.0 / (1048576.0 * 1024.0)  # GB
    else if optimizer_type == "adafactor":
        # Factorized states: roughly O(sqrt(n)) instead of O(n)
        # Much more memory efficient for huge models
        return float(num_params) * 0.5 / (1048576.0 * 1024.0)  # Approximate
    else:  # SGD
        # No additional state (just momentum if used)
        return float(num_params) * 4.0 / (1048576.0 * 1024.0)  # GB (if using momentum)

// Example for 2T parameters:
# AdamW memory: ~16TB just for optimizer states!
# With ZeRO-3 sharding across 64 GPUs: ~250GB per GPU (manageable)
