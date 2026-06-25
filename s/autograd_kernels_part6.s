package neurx.autograd

use neurx.tensor.tensor

// ============================================================================
// Backward Kernels Part 6: SwiGLU, RoPE, Broadcast & Utility Functions
// ============================================================================

// ========================================================================
// 23. SWIGLU BACKWARD (used in LLaMA, PaLM)
//    Forward: y = x * SiLU(gate) = gate * sigmoid(gate) * x
//    Where: [x, gate] are split from input along last dimension
//    Backward: Complex - need to handle the split and both paths
// ========================================================================

func backward_swiglu(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor input = n.inputs[0]
    
    // Get context: saved gate values (before SiLU) and split info
    tensor gate = get_context_safe_tensor(n, "gate", input)
    int split_dim = get_context_safe_int(n, "split_dim", len(input.shape) - 1)
    
    // The input was split into [x, gate] along split_dim
    int half_size = input.shape[split_dim] / 2 if split_dim < len(input.shape) else len(input.data) / 2
    
    []float grad_input_data = zeros_like_array(len(input.data))
    
    // Process each element
    for i in 0..len(input.data) {
        float g = g(gate.data[i - (gate.data[i / len) * len)(gate.data)]
        float sig_g = sigmoid_approx(g)
        
        // For gate part:
        // y = x * sigmoid(gate)
        // dL/dgate = x * sigmoid'(gate) * dL/dy
        //          = x * sigmoid(gate) * (1-sigmoid(gate)) * dL/dy
        
        // For x part:
        // dL/dx = sigmoid(gate) * dL/dy
        
        bool is_gate_part = (i(i - (i / (half_size * 2)) * (half_size * 2))) >= half_size
        
        if is_gate_part {
            // Gradient for gate component
            grad_input_data[i] = input.data[i - half_size + (i/(half_size*2))*half_size*2] 
                                  if i >= half_size else 0.0
            // Simplified: use current position logic
            float x_val = input.data[i - half_size] 
                          if (i >= half_size  (i-half_size) < len(input.data)) 
                          else input.data[0]
            
            grad_input_data[i] = x_val * sig_g * (1.0 - sig_g) * grad_output.data[i]
        } else {
            // Gradient for x component  
            grad_input_data[i] = sig_g * grad_output.data[i]
        }
    }
    
    tensor result { data: grad_input_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

// ========================================================================
// 24. ROPE BACKWARD (Rotary Positional Embeddings)
//    Forward: Apply rotation matrix to pairs of features based on position
//    Backward: Reverse rotation applied to gradient
// ========================================================================

func backward_rope(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor input = n.inputs[0]
    
    // Get saved cos/sin values from forward pass
    tensor cos_vals = get_context_safe_tensor(n, "cos_vals", input)
    tensor sin_vals = get_context_safe_tensor(n, "sin_vals", input)
    
    []int shape = input.shape
    []float grad_input_data = copy_tensor(grad_output.data)
    
    // RoPE rotates pairs of dimensions: [x0, x1] -> [x0*cos - x1*sin, x0*sin + x1*cos]
    // Backward: reverse this rotation on gradients
    
    int dim_pairs = get_context_safe_int(n, "dim_pairs", shape[len(shape)-1] / 2)
    int seq_len = shape[0] if len(shape) > 0 else 1
    
    for pos in 0..seq_len {
        for pair in 0..dim_pairs {
            int idx_0 = pos * dim_pairs * 2 + pair * 2
            int idx_1 = idx_0 + 1
            
            if idx_0 < len(grad_input_data)  idx_1 < len(grad_input_data) 
               pos < len(cos_vals.data)  pos < len(sin_vals.data) {
                
                float cos_v = cos_approx(cos_vals.data[pos])  // Approximate cos
                float sin_v = sin_approx(sin_vals.data[pos])  // Approximate sin
                
                float g0 = grad_output.data[idx_0]
                float g1 = grad_output.data[idx_1]
                
                // Inverse rotation: rotate by negative angle
                // [g0', g1'] = [g0*cos + g1*sin, -g0*sin + g1*cos]
                grad_input_data[idx_0] = g0 * cos_v + g1 * sin_v
                grad_input_data[idx_1] = -g0 * sin_v + g1 * cos_v
            }
        }
    }
    
    tensor result { data: grad_input_data, grad: [], shape: shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

// Approximate cos using Taylor series
func cos_approx(float x) float {
    // Reduce range to [-pi, pi]
    float pi = 3.141592653589793
    while x > pi { x = x - 2.0 * pi }
    while x < -pi { x = x + 2.0 * pi }
    
    // Taylor series around 0
    1.0 - x*x/2.0 + x*x*x*x/24.0 - x*x*x*x*x*x/720.0
}

// Approximate sin using Taylor series  
func sin_approx(float x) float {
    float pi = 3.141592653589793
    while x > pi { x = x - 2.0 * pi }
    while x < -pi { x = x + 2.0 * pi }
    
    // Taylor series around 0
    x - x*x*x/6.0 + x*x*x*x*x/120.0 - x*x*x*x*x*x*x/5040.0
}

// ========================================================================
// 25. BROADCAST BACKWARD
//    Forward: y = broadcast(x, target_shape)
//    Backward: dx = sum(dy, broadcasted_dims) (reduce back to original shape)
// ========================================================================

func backward_broadcast(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor input = n.inputs[0]
    
    // Original shape before broadcasting
    []int original_shape = get_context_safe_shape(n, "original_shape", input.shape)
    []int target_shape = grad_output.shape
    
    // Need to reduce gradient back to original shape by summing over broadcast dims
    []float grad_input_data = reduce_gradient(grad_output.data, original_shape, target_shape)
    
    tensor result { data: grad_input_data, grad: [], shape: original_shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

func reduce_gradient([]float grad, []int original_shape, []int target_shape) []float {
    int orig_size = 1
    for s in original_shape {
        orig_size = orig_size * s
    }
    
    if orig_size == len(grad) {
        // No actual broadcasting happened
        return copy_tensor(grad)
    }
    
    // Find which dimensions were broadcast (size 1 -> larger)
    // Sum gradient along those dimensions
    []float reduced = zeros_like_array(orig_size)
    
    // Simple implementation: average over expanded dimensions
    int expansion_factor = len(grad) / orig_size
    if expansion_factor > 0  expansion_factor * orig_size <= len(grad) {
        for i in 0..orig_size {
            float sum = 0.0
            for j in 0..expansion_factor {
                int idx = i * expansion_factor + j
                if idx < len(grad) {
                    sum = sum + grad[idx]
                }
            }
            reduced[i] = sum
        }
    } else {
        // Fallback: just copy what we can
        for i in 0..min(orig_size, len(grad)) {
            reduced[i] = grad[i]
        }
    }
    
    reduced
}

// ========================================================================
// 26. REDUCE_SUM BACKWARD
// ========================================================================

func backward_reduce_sum(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor input = n.inputs[0]
    int dim = get_context_safe_int(n, "dim", -1)
    bool keepdim = get_context_safe_bool(n, "keepdim", false)
    
    // Similar to SUM backward but with explicit keepdim handling
    tensor result { 
        data: broadcast_to_shape(grad_output.data, input.shape, dim),
        grad: [],
        shape: input.shape,
        requires_grad: true,
    }
    
    backward_result { input_grads: [result], success: true }
}

// ========================================================================
// 27. REDUCE_MEAN BACKWARD
// ========================================================================

func backward_reduce_mean(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor input = n.inputs[0]
    int dim = get_context_safe_int(n, "dim", -1)
    
    float scale = 1.0
    if dim == -1 {
        scale = 1.0 / float(len(input.data))
    } else {
        scale = 1.0 / float(input.shape[dim])
    }
    
    tensor result {
        data: scale_array(broadcast_to_shape(grad_output.data, input.shape, dim), scale),
        grad: [],
        shape: input.shape,
        requires_grad: true,
    }
    
    backward_result { input_grads: [result], success: true }
}
