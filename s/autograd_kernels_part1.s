package neurx.autograd

use neurx.tensor.tensor

// ============================================================================
// Backward Kernels for All Operations
// Each function computes gradients w.r.t. inputs given gradient of output
// ============================================================================

// ========================================================================
// 1. MATMUL BACKWARD
//    Forward: C = A @ B
//    Backward: dA = dC @ B^T, dB = A^T @ dC
// ========================================================================

func backward_matmul(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor a = n.inputs[0]
    tensor b = n.inputs[1]
    
    // Get shapes from context (saved during forward)
    []int shape_a = get_context_safe(n, "shape_a", a.shape)
    []int shape_b = get_context_safe(n, "shape_b", b.shape)
    
    // dL/dA = dL/dOut @ B^T
    tensor grad_a = matmul_transpose_b(grad_output.data, b.data, shape_a, shape_b)
    
    // dL/dB = A^T @ dL/dOut
    tensor grad_b = matmul_transpose_a(a.data, grad_output.data, shape_a, shape_b)
    
    backward_result {
        input_grads: [grad_a, grad_b],
        success: true,
    }
}

// Matrix multiply with transposed second matrix: grad @ B^T
func matmul_transpose_b([]float grad, []float b, []int shape_grad, []int shape_b) tensor {
    // Assuming 2D matrices: grad is [M, K], B is [K, N]
    // Result should be [M, N]
    int M = shape_grad[0]
    int K = shape_grad[1] if len(shape_grad) > 1 else shape_b[0]
    int N = shape_b[1] if len(shape_b) > 1 else K
    
    []float result = []float{cap: M * N}
    for i in 0..M*N {
        result[i] = 0.0
    }
    
    for m in 0..M {
        for n in 0..N {
            float sum = 0.0
            for k in 0..K {
                // grad[m, k] * b[n, k] (b transposed)
                sum = sum + grad[m * K + k] * b[n * K + k]
            }
            result[m * N + n] = sum
        }
    }
    
    tensor { data: result, grad: [], shape: [M, N], requires_grad: true }
}

// Matrix multiply with transposed first matrix: A^T @ grad
func matmul_transpose_a([]float a, []float grad, []int shape_a, []int shape_grad) tensor {
    // A is [M, K], grad is [K, N]
    // Result should be [M, N]
    int M = shape_a[0]
    int K = shape_a[1] if len(shape_a) > 1 else shape_grad[0]
    int N = shape_grad[1] if len(shape_grad) > 1 else K
    
    []float result = []float{cap: M * N}
    for i in 0..M*N {
        result[i] = 0.0
    }
    
    for m in 0..M {
        for n in 0..N {
            float sum = 0.0
            for k in 0..K {
                // a[k, m] (a transposed) * grad[k, n]
                sum = sum + a[k * M + m] * grad[k * N + n]
            }
            result[m * N + n] = sum
        }
    }
    
    tensor { data: result, grad: [], shape: [M, N], requires_grad: true }
}

// ========================================================================
// 2. ADD BACKWARD
//    Forward: C = A + B (or C = A + scalar)
//    Backward: dA = dC, dB = dC (gradient flows through unchanged)
// ========================================================================

func backward_add(node n, tensor grad_output) backward_result {
    []tensor grads
    
    if len(n.inputs) == 1 {
        // Scalar addition - just pass through
        grads = [copy_tensor_with_grad(grad_output)]
    } else if len(n.inputs) == 2 {
        tensor grad_a = copy_tensor_with_grad(grad_output)
        tensor grad_b = copy_tensor_with_grad(grad_output)
        
        // Handle broadcasting
        if len(n.inputs[0].shape) != len(grad_output.shape) || 
           !shapes_equal(n.inputs[0].shape, grad_output.shape) {
            grad_a = broadcast_gradient(grad_a, n.inputs[0].shape, grad_output.shape)
        }
        if len(n.inputs[1].shape) != len(grad_output.shape) ||
           !shapes_equal(n.inputs[1].shape, grad_output.shape) {
            grad_b = broadcast_gradient(grad_b, n.inputs[1].shape, grad_output.shape)
        }
        
        grads = [grad_a, grad_b]
    } else {
        grads = []
        for i in 0..len(n.inputs) {
            grads.push(copy_tensor_with_grad(grad_output))
        }
    }
    
    backward_result { input_grads: grads, success: true }
}

func copy_tensor_with_grad(tensor t) tensor {
    []float data = []float{cap: len(t.data)}
    for i in 0..len(t.data) {
        data[i] = t.data[i]
    }
    tensor { data: data, grad: [], shape: copy_shape(t.shape), requires_grad: true }
}

func copy_shape([]int s) []int {
    []int out = []int{cap: len(s)}
    for i in 0..len(s) {
        out[i] = s[i]
    }
    out
}

func shapes_equal([]int a, []int b) bool {
    if len(a) != len(b) { return false }
    for i in 0..len(a) {
        if a[i] != b[i] { return false }
    }
    true
}

// ========================================================================
// 3. MUL BACKWARD
//    Forward: C = A * B (element-wise or broadcast)
//    Backward: dA = dC * B, dB = dC * A
// ========================================================================

func backward_mul(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [copy_tensor_with_grad(grad_output)], success: true }
    }
    
    tensor a = n.inputs[0]
    tensor b = n.inputs[1]
    
    // dL/dA = dL/dOut * B
    []float grad_a_data = elementwise_mul(grad_output.data, b.data)
    tensor grad_a { data: grad_a_data, grad: [], shape: a.shape, requires_grad: true }
    
    // dL/dB = dL/dOut * A  
    []float grad_b_data = elementwise_mul(grad_output.data, a.data)
    tensor grad_b { data: grad_b_data, grad: [], shape: b.shape, requires_grad: true }
    
    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func elementwise_mul([]float a, []float b) []float {
    int n = min_len(a, b)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = a[i] * b[i]
    }
    out
}

func min_len([]float a, []float b) int {
    if len(a) < len(b) { len(a) } else { len(b) }
}

// ========================================================================
// 4. SUB BACKWARD
//    Forward: C = A - B
//    Backward: dA = dC, dB = -dC
// ========================================================================

func backward_sub(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [copy_tensor_with_grad(grad_output)], success: true }
    }
    
    tensor grad_a = copy_tensor_with_grad(grad_output)
    
    // dL/dB = -dL/dOut
    []float neg_grad = negate(grad_output.data)
    tensor grad_b { data: neg_grad, grad: [], shape: n.inputs[1].shape, requires_grad: true }
    
    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func negate([]float data) []float {
    []float out = []float{cap: len(data)}
    for i in 0..len(data) {
        out[i] = -data[i]
    }
    out
}

// ========================================================================
// 5. DIV BACKWARD
//    Forward: C = A / B
//    Backward: dA = dC / B, dB = -dC * A / B^2
// ========================================================================

func backward_div(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [copy_tensor_with_grad(grad_output)], success: true }
    }
    
    tensor a = n.inputs[0]
    tensor b = n.inputs[1]
    
    // dL/dA = dL/dOut / B
    []float grad_a_data = elementwise_div(grad_output.data, b.data)
    tensor grad_a { data: grad_a_data, grad: [], shape: a.shape, requires_grad: true }
    
    // dL/dB = -dL/dOut * A / B^2
    []float b_squared = elementwise_mul(b.data, b.data)
    []float numerator = elementwise_mul(elementwise_mul(grad_output.data, a.data), float_to_array(-1.0))
    []float grad_b_data = elementwise_div(numerator, b_squared)
    tensor grad_b { data: grad_b_data, grad: [], shape: b.shape, requires_grad: true }
    
    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func elementwise_div([]float a, []float b) []float {
    int n = min_len(a, b)
    []float out = []float{cap: n}
    for i in 0..n {
        if abs_float(b[i]) > 1e-8 {
            out[i] = a[i] / b[i]
        } else {
            out[i] = 0.0  // Avoid division by zero
        }
    }
    out
}

func abs_float(float x) float {
    if x < 0.0 { -x } else { x }
}
