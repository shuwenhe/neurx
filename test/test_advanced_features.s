// NeurX Advanced Features Integration Tests
// Tests for vectorization, mixed precision, gradient accumulation, and tensor parallelism
// Author: NeurX Team
// Date: 2026-06-29

package neurx.test.advanced_features

import (
    "neurx/ops/vectorization"
    "neurx/training/mixed_precision"
    "neurx/training/gradient_accumulation"
    "neurx/distributed/tensor_parallel"
)

// ============================================================
// Test Vectorization
// ============================================================

func test_vectorization_basic() bool {
    // Test element-wise operations
    var A: []float = []float(4)
    var B: []float = []float(4)
    A[0] = 1.0; A[1] = 2.0; A[2] = 3.0; A[3] = 4.0
    B[0] = 2.0; B[1] = 2.0; B[2] = 2.0; B[3] = 2.0
    
    var C = vectorization.element_wise_add(A, B)
    // Expected: [3.0, 4.0, 5.0, 6.0]
    
    var D = vectorization.element_wise_mul(A, B)
    // Expected: [2.0, 4.0, 6.0, 8.0]
    
    return C[0] == 3.0 && D[0] == 2.0
}

func test_vectorization_dot_product() bool {
    var A: []float = []float(3)
    var B: []float = []float(3)
    A[0] = 1.0; A[1] = 2.0; A[2] = 3.0
    B[0] = 4.0; B[1] = 5.0; B[2] = 6.0
    
    var result = vectorization.dot_product(A, B)
    // Expected: 1*4 + 2*5 + 3*6 = 32.0
    
    return result == 32.0
}

func test_vectorization_vector_norm() bool {
    var A: []float = []float(3)
    A[0] = 3.0; A[1] = 4.0; A[2] = 0.0
    
    var norm = vectorization.vector_norm(A)
    // Expected: sqrt(9 + 16) = 5.0
    
    return norm >= 4.9 && norm <= 5.1  // Allow floating point error
}

func test_vectorization_reduce_sum() bool {
    var A: []float = []float(4)
    A[0] = 1.0; A[1] = 2.0; A[2] = 3.0; A[3] = 4.0
    
    var sum = vectorization.reduce_sum(A)
    // Expected: 10.0
    
    return sum == 10.0
}

// ============================================================
// Test Mixed Precision
// ============================================================

func test_mixed_precision_config() bool {
    var config = mixed_precision.new_mixed_precision_config()
    
    return config.use_mixed_precision == true &&
           config.compute_dtype == "float32" &&
           config.loss_scale == 65536.0
}

func test_mixed_precision_state() bool {
    var state = mixed_precision.new_mixed_precision_state(100)
    
    return len(state.master_weights) == 100 &&
           len(state.compute_weights) == 100 &&
           state.overflow_count == 0 &&
           state.total_steps == 0
}

func test_loss_scale_scheduler() bool {
    var scheduler = mixed_precision.new_loss_scale_scheduler(65536.0, 2000, 2.0, 0.5)
    
    // Initial state
    var initial_scale = scheduler.current_scale
    
    // Simulate overflow
    scheduler = mixed_precision.update_loss_scale(scheduler, true)
    var after_overflow = scheduler.current_scale
    
    // Should decrease
    return after_overflow < initial_scale && after_overflow == initial_scale * 0.5
}

func test_overflow_detection() bool {
    var gradients: [][]float = [][]float(5)
    gradients[0] = 0.1
    gradients[1] = 0.2
    gradients[2] = 0.3
    gradients[3] = 0.4
    gradients[4] = 0.5
    
    var has_overflow = mixed_precision.detect_overflow(gradients)
    return has_overflow == false
}

func test_gradient_scaling() bool {
    var gradients: [][]float = [][]float(2)
    gradients[0] = 0.1
    gradients[1] = 0.2
    
    var scaled = mixed_precision.scale_gradients(gradients, 1000.0)
    
    return scaled[0] == 0.0001 && scaled[1] == 0.0002
}

// ============================================================
// Test Gradient Accumulation
// ============================================================

func test_accumulation_basic() bool {
    var accum = gradient_accumulation.new_accumulated_gradients(10)
    
    return accum.steps_accumulated == 0 &&
           accum.loss_sum == 0.0 &&
           accum.is_ready == false
}

func test_accumulate_gradients() bool {
    var accum = gradient_accumulation.new_accumulated_gradients(3)
    
    var step_grad: [][]float = [][]float(3)
    step_grad[0] = 0.1; step_grad[1] = 0.2; step_grad[2] = 0.3
    
    accum = gradient_accumulation.accumulate_gradients(accum, step_grad, 0.5, 0.5)
    
    return accum.steps_accumulated == 1 &&
           accum.loss_sum == 0.25 &&
           accum.gradients[0] == 0.05
}

func test_accumulation_complete() bool {
    var accum = gradient_accumulation.new_accumulated_gradients(5)
    
    var step_grad: [][]float = [][]float(5)
    var i = 0
    while i < 5 { step_grad[i] = 0.1; i = i + 1 }
    
    // First 3 steps
    i = 0
    while i < 3 {
        accum = gradient_accumulation.accumulate_gradients(accum, step_grad, 1.0, 1.0)
        i = i + 1
    }
    
    // Check not ready
    accum = gradient_accumulation.check_accumulation_complete(accum, 4)
    if accum.is_ready { return false }
    
    // Add one more
    accum = gradient_accumulation.accumulate_gradients(accum, step_grad, 1.0, 1.0)
    accum = gradient_accumulation.check_accumulation_complete(accum, 4)
    
    return accum.is_ready == true && accum.steps_accumulated == 4
}

func test_effective_batch_size() bool {
    var eff_batch = gradient_accumulation.effective_batch_size(32, 4)
    return eff_batch == 128
}

func test_accumulation_reset() bool {
    var accum = gradient_accumulation.new_accumulated_gradients(3)
    
    var step_grad: [][]float = [][]float(3)
    step_grad[0] = 0.1; step_grad[1] = 0.2; step_grad[2] = 0.3
    
    accum = gradient_accumulation.accumulate_gradients(accum, step_grad, 0.5, 1.0)
    accum = gradient_accumulation.reset_accumulation(accum)
    
    return accum.steps_accumulated == 0 &&
           accum.loss_sum == 0.0 &&
           accum.gradients[0] == 0.0
}

// ============================================================
// Test Tensor Parallelism
// ============================================================

func test_distributed_state() bool {
    var state = tensor_parallel.new_distributed_state(0, 8, 4)
    
    return state.global_rank == 0 &&
           state.world_size == 8 &&
           state.tp_rank == 0 &&
           state.tp_size == 4 &&
           state.dp_rank == 0 &&
           state.dp_size == 2
}

func test_distributed_state_rank1() bool {
    var state = tensor_parallel.new_distributed_state(1, 8, 4)
    
    return state.tp_rank == 1 &&
           state.dp_rank == 0
}

func test_tensor_parallel_config() bool {
    var config = tensor_parallel.new_tensor_parallel_config(4, 0)
    
    return config.tp_degree == 4 &&
           config.tp_rank == 0 &&
           config.sharding_strategy == "column_wise"
}

func test_communication_stats() bool {
    var stats = tensor_parallel.new_communication_stats()
    
    return stats.allreduce_calls == 0 &&
           stats.broadcast_calls == 0 &&
           stats.total_bytes_sent == 0
}

func test_update_communication_stats() bool {
    var stats = tensor_parallel.new_communication_stats()
    
    stats = tensor_parallel.update_communication_stats(stats, "allreduce", 1000, 10.0)
    
    return stats.allreduce_calls == 1 &&
           stats.total_bytes_sent == 1000 &&
           stats.total_communication_time == 10.0
}

// ============================================================
// Integration Tests
// ============================================================

func test_mixed_training_config() bool {
    // All components configured together
    var vec_config = vectorization.new_vectorization_stats()  // dummy
    var mp_config = mixed_precision.new_mixed_precision_config()
    var accum_config = gradient_accumulation.new_gradient_accumulation_config()
    var tp_config = tensor_parallel.new_tensor_parallel_config(4, 0)
    
    return mp_config.use_mixed_precision == true &&
           accum_config.accumulation_steps >= 1 &&
           tp_config.tp_degree == 4
}

func test_vectorization_with_mixed_precision() bool {
    // Test using vectorization with mixed precision
    var A: []float = []float(4)
    A[0] = 1.0; A[1] = 2.0; A[2] = 3.0; A[3] = 4.0
    
    // Simulate forward pass
    var sum = vectorization.reduce_sum(A)
    
    // Simulate gradient scaling
    var gradients: [][]float = [][]float(4)
    gradients[0] = 0.01; gradients[1] = 0.02; gradients[2] = 0.03; gradients[3] = 0.04
    
    var scaled = mixed_precision.scale_gradients(gradients, 1000.0)
    
    return sum == 10.0 && scaled[0] == 0.00001
}

// ============================================================
// Main Test Runner
// ============================================================

func run_all_advanced_tests() int {
    var passed = 0
    var total = 0
    
    // Vectorization tests
    total = total + 1
    if test_vectorization_basic() { passed = passed + 1 }
    
    total = total + 1
    if test_vectorization_dot_product() { passed = passed + 1 }
    
    total = total + 1
    if test_vectorization_vector_norm() { passed = passed + 1 }
    
    total = total + 1
    if test_vectorization_reduce_sum() { passed = passed + 1 }
    
    // Mixed precision tests
    total = total + 1
    if test_mixed_precision_config() { passed = passed + 1 }
    
    total = total + 1
    if test_mixed_precision_state() { passed = passed + 1 }
    
    total = total + 1
    if test_loss_scale_scheduler() { passed = passed + 1 }
    
    total = total + 1
    if test_overflow_detection() { passed = passed + 1 }
    
    total = total + 1
    if test_gradient_scaling() { passed = passed + 1 }
    
    // Gradient accumulation tests
    total = total + 1
    if test_accumulation_basic() { passed = passed + 1 }
    
    total = total + 1
    if test_accumulate_gradients() { passed = passed + 1 }
    
    total = total + 1
    if test_accumulation_complete() { passed = passed + 1 }
    
    total = total + 1
    if test_effective_batch_size() { passed = passed + 1 }
    
    total = total + 1
    if test_accumulation_reset() { passed = passed + 1 }
    
    // Tensor parallelism tests
    total = total + 1
    if test_distributed_state() { passed = passed + 1 }
    
    total = total + 1
    if test_distributed_state_rank1() { passed = passed + 1 }
    
    total = total + 1
    if test_tensor_parallel_config() { passed = passed + 1 }
    
    total = total + 1
    if test_communication_stats() { passed = passed + 1 }
    
    total = total + 1
    if test_update_communication_stats() { passed = passed + 1 }
    
    // Integration tests
    total = total + 1
    if test_mixed_training_config() { passed = passed + 1 }
    
    total = total + 1
    if test_vectorization_with_mixed_precision() { passed = passed + 1 }
    
    return passed
}

func main() {
    var passed = run_all_advanced_tests()
    var total = 20
    
    print("Advanced Features Tests:")
    print("Passed: " + string(passed) + " / " + string(total))
    
    if passed == total {
        print("✓ All advanced feature tests passed!")
    } else {
        print("✗ Some tests failed")
    }
}
