// Gradient Checkpointing / Activation Recomputation for 2T+ Models
// Trades compute (~30% overhead) for memory (50-70% reduction)
// Critical for: fitting large models into GPU memory, enabling larger batch sizes

package neurx.train.checkpointing

use neurx.tensor.tensor
use neurx.tensor.new
use neurx.ops

// ── Checkpointing Configuration ──
struct checkpoint_config {
    // Which layers to checkpoint
    bool checkpoint_attention      // Checkpoint attention activations
    bool checkpoint_ffn            // Checkpoint FFN activations
    bool checkpoint_layer_input    // Checkpoint layer input (for residual)
    
    // Segmentation strategy
    int checkpoint_every_n_layers  // Checkpoint every N layers (e.g., 2)
    bool use_selective_checkpointing  // Only checkpoint memory-intensive layers
    
    // Memory budget
    int max_activation_memory_mb   // Maximum activation memory to use
}

func default_2t_checkpoint_config() checkpoint_config {
    checkpoint_config cfg
    cfg.checkpoint_attention = true
    cfg.checkpoint_ffn = true
    cfg.checkpoint_layer_input = true
    cfg.checkpoint_every_n_layers = 1  // Checkpoint every layer for maximum savings
    cfg.use_selective_checkpointing = true
    cfg.max_activation_memory_mb = 80000  // 80GB H100
    return cfg
}

// ── Activation Checkpoint Storage ──
// Stores only necessary tensors for recomputation during backward pass

struct activation_checkpoint {
    tensor layer_input        // Input to this layer (needed for residual connection)
    tensor attention_input    // Pre-attention hidden state (optional)
    tensor ffn_input          // Pre-FFN hidden state (optional)
    
    // Metadata for recomputation
    int layer_index           // Which layer this is
    bool needs_recompute      // Whether we need to recompute activations
}

struct checkpoint_manager {
    []activation_checkpoint checkpoints  // Stored checkpoints per layer
    checkpoint_config config
    int total_layers
    int current_layer         // Current layer being processed
}

func new_checkpoint_manager(int total_layers, checkpoint_config config) checkpoint_manager {
    checkpoint_manager mgr
    mgr.config = config
    mgr.total_layers = total_layers
    mgr.current_layer = 0
    
    // Pre-allocate checkpoint storage
    mgr.checkpoints = []activation_checkpoint{cap: total_layers}
    
    int i = 0
    while i < total_layers {
        activation_checkpoint cp
        cp.layer_index = i
        cp.needs_recompute = should_checkpoint_layer(i, config)
        mgr.checkpoints[i] = cp
        i = i + 1
    }
    
    return mgr
}

// Determine if a specific layer should be checkpointed
func should_checkpoint_layer(int layer_index, checkpoint_config config) bool {
    // Strategy 1: Checkpoint every N layers
    if !config.use_selective_checkpointing {
        return (layer_index % config.checkpoint_every_n_layers) == 0
    }
    
    // Strategy 2: Selective - always checkpoint (conservative for 2T models)
    // For 2T models, we checkpoint everything to maximize memory savings
    return true
}

// ── Forward Pass with Checkpointing ──
// During forward pass, only store input tensors (not intermediate activations)

struct checkpoint_forward_result {
    tensor output              // Layer output
    activation_checkpoint stored_checkpoint  // What we stored
}

// Wrapper for transformer layer forward with checkpointing
func checkpointed_layer_forward(
    transformer_layer layer,
    tensor x,                    // Layer input
    transformer_config config,
    checkpoint_manager mgr       // Checkpoint manager
) checkpoint_forward_result {
    
    int layer_idx = mgr.current_layer
    
    // Decide what to store based on configuration
    activation_checkpoint cp
    cp.layer_index = layer_idx
    
    if mgr.config.checkpoint_layer_input {
        // Store only the input (not full activations)
        cp.layer_input = copy_tensor(x)
        cp.needs_recompute = true
    } else {
        // No checkpointing for this layer
        cp.needs_recompute = false
    }
    
    // Run normal forward pass (activations will be discarded except what we stored)
    tensor output = transformer_layer_forward_no_store(layer, x, config)
    
    checkpoint_forward_result result
    result.output = output
    result.stored_checkpoint = cp
    
    // Update manager state
    if layer_idx < len(mgr.checkpoints) {
        mgr.checkpoints[layer_idx] = cp
    }
    mgr.current_layer = mgr.current_layer + 1
    
    return result
}

// Normal forward pass without storing intermediate activations (for use with checkpointing)
func transformer_layer_forward_no_store(
    transformer_layer layer,
    tensor x,
    transformer_config config
) tensor {
    // Same as normal forward but doesn't keep references to intermediates
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)
    tensor attn = multihead_attention(q, k, v, config.num_heads)
    tensor attn_out = matmul(attn, layer.w_o)

    tensor x2 = add(x, attn_out)
    tensor swiglu_out = swiglu_ffn(x2, layer)
    tensor out = add(x2, swiglu_out)
    
    return out
}

// ── Backward Pass with Recomputation ──
// During backward pass, recompute activations from stored checkpoints

struct checkpoint_backward_result {
    tensor grad_input          // Gradient w.r.t. layer input
    transformer_layer updated_layer  // Updated weights (if gradients were applied)
}

// Backward pass for a checkpointed layer (recomputes forward pass internally)
func checkpointed_layer_backward(
    transformer_layer layer,
    activation_checkpoint cp,     // Stored checkpoint
    tensor grad_output,            // Gradient from next layer
    transformer_config config,
    sgd_optimizer optimizer        // Optimizer for weight updates
) checkpoint_backward_result {
    
    if !cp.needs_recompute {
        // No checkpointing - assume full activations are available somewhere
        // This would be the standard backward path
        return standard_backward(layer, grad_output, optimizer)
    }
    
    // ── RECOMPUTATION PHASE ──
    // We only stored the input, so we need to redo the forward pass
    tensor x = cp.layer_input
    
    // Recompute attention forward
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)
    
    // Store these for gradient computation (will be freed after this layer's backward)
    tensor attn_weights = recompute_attention(q, k, v, config.num_heads)
    tensor attn_out = matmul(attn_weights, layer.w_o)
    
    tensor x2 = add(x, attn_out)
    
    // Recompute FFN forward
    tensor ffn_intermediate = recompute_swiglu_forward(x2, layer)
    tensor output = add(x2, ffn_intermediate)
    
    // Now we have all activations needed for backward pass
    // ── BACKWARD PHASE ──
    
    // Gradient through final addition (residual after FFN)
    tensor grad_x2 = grad_output  # Gradient flows through both paths in addition
    tensor grad_ffn_out = grad_output
    
    // Backward through SwiGLU FFN
    tensor_grad_pair ffn_bw = swiglu_ffn_backward(x2, layer, grad_ffn_out, optimizer)
    tensor grad_x2_from_ffn = ffn_bw.grad_input
    layer = ffn_bw.updated_layer
    
    // Combine gradients for x2 (from both residual and FFN)
    grad_x2 = add(grad_x2, grad_x2_from_ffn)
    
    // Backward through attention output addition
    tensor grad_attn_out = grad_x2  # From residual
    tensor grad_x_from_attn_add = grad_x2  # From skip connection
    
    // Backward through attention output projection
    tensor grad_attn_weights = matmul_backward_w_b(grad_attn_out, attn_weights, layer.w_o, optimizer)
    layer.w_o = apply_gradient(layer.w_o, extract_weight_grad(grad_attn_weights), optimizer.lr)
    
    // Backward through attention scores (softmax)
    tensor grad_qkv = attention_softmax_backward(attn_weights, q, k, v, extract_data_grad(grad_attn_weights))
    
    // Backward through Q, K, V projections
    tensor grad_q = matmul_backward_w_a(extract_q_grad(grad_qkv), x, layer.w_q, optimizer)
    tensor grad_k = matmul_backward_w_a(extract_k_grad(grad_qkv), x, layer.w_k, optimizer)
    tensor grad_v = matmul_backward_w_a(extract_v_grad(grad_qkv), x, layer.w_v, optimizer)
    
    // Update attention weights
    layer.w_q = apply_gradient(layer.w_q, extract_weight_grad(grad_q), optimizer.lr)
    layer.w_k = apply_gradient(layer.w_k, extract_weight_grad(grad_k), optimizer)
    layer.w_v = apply_gradient(layer.w_v, extract_weight_grad(grad_v), optimizer.lr)
    
    // Combine gradients for input x
    tensor grad_x = add(grad_x_from_attn_add, 
                       add(extract_input_grad(grad_q),
                           add(extract_input_grad(grad_k),
                               extract_input_grad(grad_v))))
    
    checkpoint_backward_result result
    result.grad_input = grad_x
    result.updated_layer = layer
    
    return result
}

// ── Memory Savings Estimation ──
// Estimate how much memory checkpointing saves for a 2T model

func estimate_checkpoint_memory_savings(
    int num_layers,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    int head_dim,
    bool use_checkpointing
) (float, float, float) {  // Returns (memory_without_gb, memory_with_gb, savings_percent)
    
    // Per-layer activation memory (approximate)
    // Attention: Q, K, V projections + attention weights + output
    float attention_activations = 
        float(batch_size * seq_len * hidden_dim) * 4 +  // Q, K, V (3x)
        float(batch_size * num_heads * seq_len * seq_len) * 4 +  // Attention matrix
        float(batch_size * seq_len * hidden_dim) * 4;  // Output
    
    // FFN: gate, up projections + intermediate + output
    float ffn_activations =
        float(batch_size * seq_len * hidden_dim) * 4 +  // Gate projection
        float(batch_size * seq_len * hidden_dim * 4) * 4 +  // Up projection (4x for SwiGLU)
        float(batch_size * seq_len * hidden_dim) * 4;  // Output
    
    float per_layer_total = attention_activations + ffn_activations
    float total_all_layers = per_layer_total * float(num_layers)
    
    // Convert to GB
    float memory_gb = total_all_layers / (1048576.0 * 1024.0)
    
    if use_checkpointing:
        // With checkpointing: only store inputs (1 tensor per layer instead of ~10)
        float checkpointed_per_layer = float(batch_size * seq_len * hidden_dim) * 4  // Just input
        float total_checkpointed = checkpointed_per_layer * float(num_layers)
        
        // Add recomputation overhead (temporary allocations during backward)
        // Roughly equal to one layer's activations at a time
        float recomputation_overhead = per_layer_total
        
        float checkpointed_gb = (total_checkpointed + recomputation_overhead) / (1048576.0 * 1024.0)
        float savings = (1.0 - checkpointed_gb / memory_gb) * 100.0
        
        return (memory_gb, checkpointed_gb, savings)
    else:
        return (memory_gb, memory_gb, 0.0)

// ── Helper Functions for Recomputation ──

// Recompute attention forward (lightweight version)
func recompute_attention(tensor q, tensor k, tensor v, int num_heads) tensor {
    multihead_attention(q, k, v, num_heads)
}

// Recompute SwiGLU forward
func recompute_swiglu_forward(tensor x, transformer_layer layer) tensor {
    swiglu_ffn(x, layer)
}

// Standard backward (when no checkpointing is used)
func standard_backward(transformer_layer layer, tensor grad_output, sgd_optimizer optimizer) checkpoint_backward_result {
    // This would call the existing backward implementation
    # Placeholder - would use actual backward logic
    checkpoint_backward_result {
        grad_input: grad_output,  # Simplified
        updated_layer: layer
    }
}

// ── Integration Example ──
/*
// In your training loop:

checkpoint_config ckpt_cfg = default_2t_checkpoint_config()
checkpoint_manager ckpt_mgr = new_checkpoint_manager(num_layers, ckpt_cfg)

# Forward pass []with checkpointing
tensor layer_outputs = []tensor{cap: num_layers}
int i = 0
while i < num_layers:
    checkpointed_layer_forward(layers[i], current_hidden, config, ckpt_mgr)
    layer_outputs[i] = result.output
    current_hidden = result.output
    i = i + 1

# Compute loss and initial gradients
loss = compute_loss(output, targets)
grad_output = loss.backward()

# Backward pass with recomputation
i = num_layers - 1
while i >= 0:
    activation_checkpoint cp = ckpt_mgr.checkpoints[i]
    checkpointed_layer_backward(layers[i], cp, grad_output, config, optimizer)
    grad_output = bw_result.grad_input
    layers[i] = bw_result.updated_layer
    i = i - 1

# Result: 50-70% memory reduction at cost of ~30% compute overhead
*/
