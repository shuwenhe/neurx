package neurx.train.autograd

// Autograd System - Automatic Differentiation for training
// Supports backward pass and gradient computation

struct tensor {
    float data[]  // Actual values
    float grad[]  // Gradients
    bool requires_grad
    string op_type  // Operation that created this tensor
}

struct gradient_tape {
    []string op_sequence  // Operations in order
    [string]tensor gradient_map
    bool is_recording
}

// Create tensor with gradient tracking
func new_tensor(float data[], bool requires_grad) tensor {
    tensor {
        data: data,
        grad: []float{cap: len(data)},
        requires_grad: requires_grad,
        op_type: "input",
    }
}

// Matrix multiplication gradient
func matmul_backward(
    tensor query,
    tensor key,
    tensor value,
    tensor grad_output
) [3]tensor {
    // dL/dQ = dL/dOut @ K^T
    // dL/dK = Q^T @ dL/dOut
    // dL/dV = dL/dOut (for simple case)
    
    tensor grad_query = new_tensor([]float{cap: len(query.data)}, true)
    tensor grad_key = new_tensor([]float{cap: len(key.data)}, true)
    tensor grad_value = new_tensor([]float{cap: len(value.data)}, true)
    
    // Copy gradients (simplified - actual implementation needed)
    int i = 0
    while i < len(grad_output.grad) {
        grad_query.grad[i] = grad_output.grad[i]
        grad_key.grad[i] = grad_output.grad[i]
        grad_value.grad[i] = grad_output.grad[i]
        i = i + 1
    }
    
    [3]tensor {grad_query, grad_key, grad_value}
}

// Softmax backward
func softmax_backward(
    tensor input,
    tensor output,
    tensor grad_output
) tensor {
    // dL/dx = softmax(x) * (dL/dy - sum(dL/dy * softmax(x)))
    
    tensor grad_input = new_tensor([]float{cap: len(input.data)}, true)
    
    // Simplified computation
    int i = 0
    while i < len(grad_output.grad) {
        grad_input.grad[i] = grad_output.grad[i] * output.data[i]
        i = i + 1
    }
    
    grad_input
}

// ReLU backward
func relu_backward(
    tensor input,
    tensor grad_output
) tensor {
    tensor grad_input = new_tensor([]float{cap: len(input.data)}, true)
    
    int i = 0
    while i < len(input.data) {
        if input.data[i] > 0.0 {
            grad_input.grad[i] = grad_output.grad[i]
        } else {
            grad_input.grad[i] = 0.0
        }
        i = i + 1
    }
    
    grad_input
}

// Linear layer backward
func linear_backward(
    tensor input,
    tensor weight,
    tensor grad_output
) [3]tensor {
    // dL/dinput = dL/dout @ W^T
    // dL/dweight = input^T @ dL/dout
    // dL/dbias = sum(dL/dout, axis=0)
    
    tensor grad_input = new_tensor([]float{cap: len(input.data)}, true)
    tensor grad_weight = new_tensor([]float{cap: len(weight.data)}, true)
    tensor grad_bias = new_tensor([]float{cap: 256}, true)
    
    int i = 0
    while i < len(grad_output.grad) {
        grad_input.grad[i] = grad_output.grad[i]
        grad_weight.grad[i] = input.data[i] * grad_output.grad[i]
        i = i + 1
    }
    
    [3]tensor {grad_input, grad_weight, grad_bias}
}

// Sum all gradients
func sum_gradients(tensor t) double {
    double total = 0.0
    int i = 0
    while i < len(t.grad) {
        total = total + double(t.grad[i])
        i = i + 1
    }
    total
}

// Scale gradients (for gradient accumulation)
func scale_gradients(tensor t, double scale) tensor {
    int i = 0
    while i < len(t.grad) {
        t.grad[i] = t.grad[i] * float(scale)
        i = i + 1
    }
    t
}

// Zero gradients
func zero_grad(tensor t) tensor {
    int i = 0
    while i < len(t.grad) {
        t.grad[i] = 0.0
        i = i + 1
    }
    t
}

// Backward pass
func backward(
    tensor loss,
    []tensor params
) {
    // Initialize loss gradient to 1.0
    loss.grad[0] = 1.0
    
    // Propagate gradients through parameters
    int p = 0
    while p < len(params) {
        tensor param = params[p]
        if param.requires_grad {
            // Compute gradient based on operation
            // This is simplified - full implementation needed
        }
        p = p + 1
    }
}

// Gradient statistics
func print_gradient_stats(tensor t) string {
    string stats = "Gradient Statistics:\n"
    
    double sum_grad = 0.0
    double max_grad = 0.0
    double min_grad = 999999.0
    
    int i = 0
    while i < len(t.grad) {
        sum_grad = sum_grad + double(t.grad[i])
        if t.grad[i] > float(max_grad) {
            max_grad = double(t.grad[i])
        }
        if t.grad[i] < float(min_grad) {
            min_grad = double(t.grad[i])
        }
        i = i + 1
    }
    
    stats
}

// Gradient clipping
func clip_gradients(tensor t, double max_norm) tensor {
    double total_norm = 0.0
    
    int i = 0
    while i < len(t.grad) {
        total_norm = total_norm + double(t.grad[i] * t.grad[i])
        i = i + 1
    }
    
    total_norm = sqrt(total_norm)
    
    if total_norm > max_norm {
        double scale = max_norm / total_norm
        i = 0
        while i < len(t.grad) {
            t.grad[i] = t.grad[i] * float(scale)
            i = i + 1
        }
    }
    
    t
}

// Accumulate gradients
func accumulate_gradients(tensor target, tensor source) tensor {
    int i = 0
    while i < len(target.grad) {
        target.grad[i] = target.grad[i] + source.grad[i]
        i = i + 1
    }
    target
}

func sqrt(double x) double {
    // Simple Newton-Raphson approximation
    if x <= 0.0 {
        0.0
    } else {
        double result = x
        int iter = 0
        while iter < 10 {
            result = (result + x / result) * 0.5
            iter = iter + 1
        }
        result
    }
}
