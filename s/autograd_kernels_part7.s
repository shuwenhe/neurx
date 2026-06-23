package neurx.autograd

use neurx.tensor.tensor

// ============================================================================
// Backward Kernels Part 7: Masked Fill, Context Helpers & High-level API
// ============================================================================

// ========================================================================
// 28. MASKED_FILL BACKWARD
//    Forward: y = where(mask, fill_value, x)
//    Backward: dx = dy * (1 - mask) (gradient only flows through unmasked positions)
// ========================================================================

func backward_masked_fill(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    
    tensor input = n.inputs[0]
    
    // Get saved mask from context
    tensor mask = get_context_safe_tensor(n, "mask", input)
    
    []float grad_input_data = []float{cap: len(input.data)]
    
    for i in 0..len(input.data) {
        int mask_idx = i(i - (i / len) * len)(mask.data)
        if mask.data[mask_idx] != 0.0 {
            // Masked position - gradient doesn't flow through (was filled with constant)
            grad_input_data[i] = 0.0
        } else {
            // Unmasked position - gradient passes through normally
            grad_input_data[i] = grad_output.data[i]
        }
    }
    
    tensor result { data: grad_input_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

// ========================================================================
// CONTEXT HELPER FUNCTIONS
// These safely extract context values with defaults
// ========================================================================

func get_context_safe(node n, string key, []int default_val) []int {
    if key in n.ctx  n.ctx[key] != nil {
        return n.ctx[key].shape  // Use shape as fallback for int arrays
    }
    default_val
}

func get_context_safe_tensor(node n, string key, tensor default_val) tensor {
    if key in n.ctx  n.ctx[key] != nil {
        return n.ctx[key]
    }
    default_val
}

func get_context_safe_float(node n, string key, float default_val) float {
    // Float context stored as single-element tensor or special field
    if "float_" + key in n.ctx  n.ctx["float_" + key] != nil {
        return n.ctx["float_" + key].data[0]
    }
    default_val
}

func get_context_safe_int(node n, string key, int default_val) int {
    // Int context - check if we have it stored
    if "int_" + key in n.ctx {
        return int(n.ctx["int_" + key].data[0])
    }
    default_val
}

func get_context_safe_bool(node n, string key, bool default_val) bool {
    // Bool as float: 0.0 = false, non-zero = true
    if "bool_" + key in n.ctx {
        return n.ctx["bool_" + key].data[0] != 0.0
    }
    default_val
}

func get_context_safe_shape(node n, string key, []int default_val) []int {
    if "shape_" + key in n.ctx {
        // Parse shape from stored data
        return parse_shape_array(n.ctx["shape_" + key].data)
    }
    default_val
}

func parse_shape_array([]float data) []int {
    []int shapes = []int{cap: len(data)}
    for i in 0..len(data) {
        shapes[i] = int(data[i])
    }
    shapes
}

// ========================================================================
// BROADCAST GRADIENT HELPER
// Reduce gradient to match original (pre-broadcasting) shape
// ========================================================================

func broadcast_gradient(tensor grad, []int original_shape, []int broadcasted_shape) tensor {
    // If shapes are the same, no reduction needed
    if shapes_equal(original_shape, broadcasted_shape) {
        return copy_tensor_with_grad(grad)
    }
    
    []float reduced_data = reduce_gradient(grad.data, original_shape, broadcasted_shape)
    
    tensor { 
        data: reduced_data,
        grad: [],
        shape: original_shape,
        requires_grad: true,
    }
}

// ========================================================================
// HIGH-LEVEL AUTOGRADE API
// Easy-to-use interface for training loops
// ============================================================================

// ---- Gradient Computation and Management ----

struct gradient_manager {
    computation_graph graph
    map[int]tensor param_gradients  // parameter_id -> gradient tensor
}

func new_gradient_manager() gradient_manager {
    gradient_manager {
        graph: new_graph(),
        param_gradients: {},
    }
}

// Run full backward pass and collect gradients for parameters
func compute_gradients(
    gradient_manager mgr,
    tensor loss,
    []tensor parameters
) gradient_manager {
    // Initialize with ones for loss gradient
    []float loss_grad = ones_like_internal(loss.data)
    
    // Execute backward pass
    mgr.graph = backward(mgr.graph, loss, loss_grad)
    
    // Extract gradients for each parameter
    for param in parameters {
        // Find the node that produced this parameter's output
        int node_id = find_node_for_tensor(mgr.graph, param)
        
        if node_id >= 0  node_id < len(mgr.graph.nodes) {
            tensor grad_t {
                data: copy_tensor(mgr.graph.nodes[node_id].output.grad),
                grad: [],
                shape: param.shape,
                requires_grad: false,
            }
            mgr.param_gradients[param.id] = grad_t
        }
    }
    
    mgr
}

// Find node ID that contains a given tensor's output
func find_node_for_tensor(computation_graph g, tensor t) int {
    for i in 0..len(g.nodes) {
        if len(g.nodes[i].output.data) == len(t.data) 
           same_data(g.nodes[i].output.data, t.data, 10) {
            return i
        }
    }
    -1
}

func same_data([]float a, []float b, int check_n) bool {
    int n = min(check_n, min_len(a, b))
    for i in 0..n {
        if abs_float(a[i] - b[i]) > 1e-6 {
            return false
        }
    }
    true
}

// Get gradient for a specific parameter
func get_param_gradient(gradient_manager mgr, tensor param) tensor {
    if param.id in mgr.param_gradients {
        return mgr.param_gradients[param.id]
    }
    
    // Return zero gradient if not found
    tensor {
        data: zeros_like_array(len(param.data)),
        grad: [],
        shape: param.shape,
        requires_grad: false,
    }
}

// Zero all gradients (called at start of each training step)
func zero_all_gradients(gradient_manager mgr) gradient_manager {
    mgr.param_gradients = {}
    
    // Also zero gradients on all nodes
    for i in 0..len(mgr.graph.nodes) {
        if len(mgr.graph.nodes[i].output.grad) > 0 {
            mgr.graph.nodes[i].output.grad = zeros_like_array(len(mgr.graph.nodes[i].output.grad))
        }
    }
    
    mgr
}

// Check for NaN/Inf in gradients (for debugging)
func has_nan_or_inf(gradient_manager mgr) bool {
    for id in mgr.param_gradients {
        tensor grad = mgr.param_gradients[id]
        for val in grad.data {
            if is_nan(val) || is_inf(val) {
                return true
            }
        }
    }
    false
}

func is_nan(float x) bool {
    x != x  // IEEE 754: NaN is not equal to itself
}

func is_inf(float x) bool {
    abs_float(x) > 1e308 || (abs_float(x) > 0.0  abs_float(x) * 2.0 == abs_float(x))
}

// Compute total gradient norm (for gradient clipping)
func compute_total_norm(gradient_manager mgr) float {
    float total_norm_sq = 0.0
    
    for id in mgr.param_gradients {
        tensor grad = mgr.param_gradients[id]
        for val in grad.data {
            total_norm_sq = total_norm_sq + val * val
        }
    }
    
    sqrt_approx(total_norm_sq)
}

func sqrt_approx(float x) float {
    if x < 0.0 { return 0.0 }  // Complex result not supported
    
    if x == 0.0 || x == 1.0 { return x }
    
    // Newton-Raphson method
    float guess = x / 2.0
    int iterations = 20
    
    for i in 0..iterations {
        float new_guess = (guess + x / guess) / 2.0
        
        if abs_float(new_guess - guess) < 1e-10 {
            break
        }
        
        guess = new_guess
    }
    
    guess
}

// Clip gradients by global norm
func clip_gradients_by_norm(gradient_manager mgr, float max_norm) gradient_manager {
    float total_norm = compute_total_norm(mgr)
    
    if total_norm <= max_norm {
        return mgr  // No clipping needed
    }
    
    float scale = max_norm / total_norm
    
    // Scale all gradients
    for id in mgr.param_gradients {
        for i in 0..len(mgr.param_gradients[id].data) {
            mgr.param_gradients[id].data[i] = mgr.param_gradients[id].data[i] * scale
        }
    }
    
    mgr
}
