"""
Week 6 Tests: Activation Functions, Loss Functions, and Optimizer Utilities

Comprehensive test suite covering all Week 6 implementations.
"""

import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from tensor.nn.activations import (
    relu, leaky_relu, elu, selu, sigmoid, tanh, softmax, log_softmax,
    softplus, softsign, swish, mish, gelu, hardshrink, softshrink, hardtanh,
    threshold, glu, prelu, rrelu,
    ReLU, LeakyReLU, ELU, SELU, Sigmoid, Tanh, Softmax, LogSoftmax,
)

from tensor.nn.optim_utils import (
    constant_lr, step_lr, exponential_lr, polynomial_lr, cosine_lr,
    linear_warmup_lr, linear_warmup_cosine_lr, cyclic_lr, one_cycle_lr,
    apply_weight_decay, compute_grad_norm, adam_momentum_update,
    LRScheduler, GradientAccumulator,
)

from tensor.nn.loss_extended import (
    focal_loss, focal_loss_multi, hinge_loss, smooth_l1_loss,
    triplet_loss, contrastive_loss, ntxent_loss, center_loss,
    kullback_leibler_divergence, wasserstein_loss,
)


# ============================================================================
# Test Utility Functions
# ============================================================================

def test_header(name):
    print(f"\n[TEST] {name}")


def test_assertion(condition, message=""):
    if condition:
        print(f"  {message} ✓")
    else:
        print(f"  {message} ✗ FAILED")
        raise AssertionError(message)


# ============================================================================
# ACTIVATION FUNCTION TESTS (10 tests)
# ============================================================================

def test_relu_activation():
    test_header("ReLU Activation")
    x = np.array([-2, -1, 0, 1, 2], dtype=np.float32)
    y = relu(x)
    expected = np.array([0, 0, 0, 1, 2], dtype=np.float32)
    test_assertion(np.allclose(y, expected), f"Values match: {y}")
    
    # Test module
    relu_module = ReLU()
    y_module = relu_module(x)
    test_assertion(np.allclose(y_module, expected), f"Module output correct")
    print(f"  ✅ PASSED")


def test_leaky_relu_activation():
    test_header("LeakyReLU Activation")
    x = np.array([-2, -1, 0, 1, 2], dtype=np.float32)
    y = leaky_relu(x, negative_slope=0.1)
    expected = np.array([-0.2, -0.1, 0, 1, 2], dtype=np.float32)
    test_assertion(np.allclose(y, expected), f"Values match: {y}")
    print(f"  ✅ PASSED")


def test_sigmoid_activation():
    test_header("Sigmoid Activation")
    x = np.array([0.0], dtype=np.float32)
    y = sigmoid(x)
    test_assertion(np.allclose(y, 0.5), f"Sigmoid(0) = {y[0]} (expected 0.5)")
    
    # Test bounds
    x_large = np.array([-100, 100], dtype=np.float32)
    y_large = sigmoid(x_large)
    test_assertion(np.allclose(y_large, [0, 1], atol=1e-5), f"Sigmoid bounds check")
    print(f"  ✅ PASSED")


def test_softmax_activation():
    test_header("Softmax Activation")
    x = np.array([[1.0, 2.0, 3.0]], dtype=np.float32)
    y = softmax(x, axis=-1)
    
    # Check that sum = 1
    sum_y = np.sum(y, axis=-1)
    test_assertion(np.allclose(sum_y, 1.0), f"Softmax sums to 1: {sum_y}")
    
    # Check order (larger inputs -> larger outputs)
    test_assertion(y[0, 0] < y[0, 1] < y[0, 2], "Output order matches input order")
    print(f"  ✅ PASSED")


def test_elu_activation():
    test_header("ELU Activation")
    x = np.array([-1.0, 0.0, 1.0], dtype=np.float32)
    y = elu(x, alpha=1.0)
    
    # For x > 0, ELU(x) = x
    test_assertion(y[2] == 1.0, f"ELU(1.0) = {y[2]}")
    
    # For x < 0, ELU(x) = alpha * (exp(x) - 1)
    expected_neg = 1.0 * (np.exp(-1.0) - 1)
    test_assertion(np.allclose(y[0], expected_neg), f"ELU(-1.0) ≈ {y[0]}")
    print(f"  ✅ PASSED")


def test_gelu_activation():
    test_header("GELU Activation")
    x = np.array([0.0], dtype=np.float32)
    y = gelu(x, approximate=True)
    test_assertion(np.allclose(y, 0.0), f"GELU(0) = {y}")
    
    # Test positive input
    x_pos = np.array([1.0], dtype=np.float32)
    y_pos = gelu(x_pos, approximate=True)
    test_assertion(y_pos[0] > 0.5 and y_pos[0] < 1.0, f"GELU(1) in (0.5, 1): {y_pos[0]}")
    print(f"  ✅ PASSED")


def test_softmax_numerical_stability():
    test_header("Softmax Numerical Stability")
    # Large values that could cause overflow
    x = np.array([[1000, 1001, 1002]], dtype=np.float32)
    y = softmax(x, axis=-1)
    
    # Should not be NaN or Inf
    test_assertion(np.all(np.isfinite(y)), f"All outputs are finite")
    
    # Should still sum to 1
    test_assertion(np.allclose(np.sum(y, axis=-1), 1.0), f"Sum = 1.0")
    print(f"  ✅ PASSED")


def test_swish_activation():
    test_header("Swish Activation")
    x = np.array([0.0, 1.0, -1.0], dtype=np.float32)
    y = swish(x)
    
    # swish(0) = 0
    test_assertion(np.allclose(y[0], 0.0), f"Swish(0) = 0")
    
    # swish(x) = x * sigmoid(x)
    expected_1 = 1.0 * sigmoid(np.array([1.0]))
    test_assertion(np.allclose(y[1], expected_1), f"Swish(1) matches formula")
    print(f"  ✅ PASSED")


def test_hardshrink_activation():
    test_header("Hard Shrink Activation")
    x = np.array([-2.0, -0.5, 0.0, 0.5, 2.0], dtype=np.float32)
    y = hardshrink(x, lambd=1.0)
    expected = np.array([-2.0, 0.0, 0.0, 0.0, 2.0], dtype=np.float32)
    test_assertion(np.allclose(y, expected), f"Hardshrink output: {y}")
    print(f"  ✅ PASSED")


def test_hardtanh_activation():
    test_header("Hard Tanh Activation")
    x = np.array([-5.0, -1.0, 0.0, 1.0, 5.0], dtype=np.float32)
    y = hardtanh(x, min_val=-1.0, max_val=1.0)
    expected = np.array([-1.0, -1.0, 0.0, 1.0, 1.0], dtype=np.float32)
    test_assertion(np.allclose(y, expected), f"HardTanh clipping: {y}")
    print(f"  ✅ PASSED")


# ============================================================================
# LOSS FUNCTION TESTS (10 tests)
# ============================================================================

def test_focal_loss():
    test_header("Focal Loss")
    # Perfect predictions
    preds = np.array([0.9, 0.1], dtype=np.float32)
    targets = np.array([1.0, 0.0], dtype=np.float32)
    loss = focal_loss(preds, targets, alpha=0.25, gamma=2.0)
    test_assertion(loss < 1.0, f"Focal loss (good preds): {loss:.4f}")
    
    # Bad predictions
    preds_bad = np.array([0.1, 0.9], dtype=np.float32)
    loss_bad = focal_loss(preds_bad, targets, alpha=0.25, gamma=2.0)
    test_assertion(loss_bad > loss, f"Focal loss (bad preds): {loss_bad:.4f} > {loss:.4f}")
    print(f"  ✅ PASSED")


def test_focal_loss_multi():
    test_header("Multi-class Focal Loss")
    batch_size = 4
    num_classes = 3
    
    # Perfect predictions
    preds = np.eye(num_classes)[np.array([0, 1, 2, 0])]  # (4, 3)
    targets = np.array([0, 1, 2, 0], dtype=np.int32)
    
    loss = focal_loss_multi(preds, targets, alpha=0.25, gamma=2.0)
    test_assertion(loss < 0.01, f"Focal loss (multi, perfect): {loss:.6f}")
    print(f"  ✅ PASSED")


def test_hinge_loss():
    test_header("Hinge Loss")
    # Correct predictions
    preds = np.array([2.0, -2.0], dtype=np.float32)
    targets = np.array([1.0, -1.0], dtype=np.float32)
    loss = hinge_loss(preds, targets, margin=1.0)
    test_assertion(loss < 0.01, f"Hinge loss (correct): {loss:.4f}")
    
    # Incorrect predictions
    preds_bad = np.array([-1.0, 1.0], dtype=np.float32)
    loss_bad = hinge_loss(preds_bad, targets, margin=1.0)
    test_assertion(loss_bad > loss, f"Hinge loss (incorrect) > {loss:.4f}")
    print(f"  ✅ PASSED")


def test_smooth_l1_loss():
    test_header("Smooth L1 Loss")
    preds = np.array([1.0, 0.5, 0.1], dtype=np.float32)
    targets = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    loss = smooth_l1_loss(preds, targets, beta=1.0)
    
    test_assertion(loss >= 0, f"Smooth L1 loss non-negative: {loss:.4f}")
    test_assertion(loss < 1.0, f"Smooth L1 loss reasonable: {loss:.4f}")
    print(f"  ✅ PASSED")


def test_triplet_loss():
    test_header("Triplet Loss")
    # Same embeddings for anchor and positive (should have low loss)
    anchor = np.array([[1.0, 0.0]], dtype=np.float32)
    positive = np.array([[1.0, 0.0]], dtype=np.float32)
    negative = np.array([[0.0, 1.0]], dtype=np.float32)
    
    loss = triplet_loss(anchor, positive, negative, margin=1.0)
    test_assertion(loss < 0.1, f"Triplet loss (perfect): {loss:.4f}")
    
    # Different embeddings (should have higher loss)
    positive_bad = np.array([[0.0, 1.0]], dtype=np.float32)
    loss_bad = triplet_loss(anchor, positive_bad, negative, margin=1.0)
    test_assertion(loss_bad > loss, f"Triplet loss (bad) > {loss:.4f}")
    print(f"  ✅ PASSED")


def test_contrastive_loss():
    test_header("Contrastive Loss")
    # Similar embeddings with label 1
    emb1 = np.array([[1.0, 0.0]], dtype=np.float32)
    emb2 = np.array([[1.0, 0.0]], dtype=np.float32)
    labels = np.array([1.0])
    
    loss = contrastive_loss(emb1, emb2, labels, margin=1.0)
    test_assertion(loss < 0.1, f"Contrastive loss (similar): {loss:.4f}")
    
    # Dissimilar embeddings with label 0
    emb2_diff = np.array([[0.0, 1.0]], dtype=np.float32)
    labels_diff = np.array([0.0])
    loss_diff = contrastive_loss(emb1, emb2_diff, labels_diff, margin=1.0)
    test_assertion(loss_diff < 0.1, f"Contrastive loss (dissimilar): {loss_diff:.4f}")
    print(f"  ✅ PASSED")


def test_kullback_leibler_divergence():
    test_header("Kullback-Leibler Divergence")
    # Identical distributions
    p = np.array([[0.3, 0.7]], dtype=np.float32)
    q = np.array([[0.3, 0.7]], dtype=np.float32)
    kl = kullback_leibler_divergence(q, p)
    test_assertion(kl < 0.01, f"KL divergence (identical): {kl:.6f}")
    
    # Different distributions
    q_diff = np.array([[0.7, 0.3]], dtype=np.float32)
    kl_diff = kullback_leibler_divergence(q_diff, p)
    test_assertion(kl_diff > kl, f"KL divergence (different) > {kl:.6f}")
    print(f"  ✅ PASSED")


def test_wasserstein_loss():
    test_header("Wasserstein Loss")
    preds = np.array([1.0, 2.0, 3.0], dtype=np.float32)
    targets = np.array([1.0, 2.0, 3.0], dtype=np.float32)
    loss = wasserstein_loss(preds, targets)
    test_assertion(np.isclose(loss, 0.0), f"Wasserstein loss (identical): {loss:.6f}")
    
    # Different targets
    targets_diff = np.array([2.0, 3.0, 4.0], dtype=np.float32)
    loss_diff = wasserstein_loss(preds, targets_diff)
    test_assertion(loss_diff > 0, f"Wasserstein loss (different): {loss_diff:.4f}")
    print(f"  ✅ PASSED")


def test_ntxent_loss():
    test_header("NT-Xent Loss (Contrastive Learning)")
    # Create embeddings with clear groups
    embeddings = np.array([
        [1.0, 0.0],  # Group 1
        [1.0, 0.0],  # Group 1
        [0.0, 1.0],  # Group 2
        [0.0, 1.0],  # Group 2
    ], dtype=np.float32)
    labels = np.array([0, 0, 1, 1])
    
    loss = ntxent_loss(embeddings, labels, temperature=0.07)
    test_assertion(np.isfinite(loss), f"NT-Xent loss is finite: {loss:.4f}")
    test_assertion(loss >= 0, f"NT-Xent loss non-negative")
    print(f"  ✅ PASSED")


# ============================================================================
# OPTIMIZER UTILITIES TESTS (10 tests)
# ============================================================================

def test_constant_lr_schedule():
    test_header("Constant LR Schedule")
    schedule = constant_lr(0.001)
    lr_values = [schedule(i) for i in range(5)]
    expected = [0.001] * 5
    test_assertion(np.allclose(lr_values, expected), f"Constant LR: {lr_values}")
    print(f"  ✅ PASSED")


def test_step_lr_schedule():
    test_header("Step LR Schedule")
    schedule = step_lr(0.1, step_size=2, gamma=0.5)
    lr_values = [schedule(i) for i in range(6)]
    expected = [0.1, 0.1, 0.05, 0.05, 0.025, 0.025]
    test_assertion(np.allclose(lr_values, expected), f"Step LR: {lr_values}")
    print(f"  ✅ PASSED")


def test_exponential_lr_schedule():
    test_header("Exponential LR Schedule")
    schedule = exponential_lr(0.1, gamma=0.9)
    lr_0 = schedule(0)
    lr_10 = schedule(10)
    test_assertion(np.isclose(lr_0, 0.1), f"LR at step 0: {lr_0}")
    test_assertion(lr_10 < lr_0, f"LR decreases: {lr_10} < {lr_0}")
    print(f"  ✅ PASSED")


def test_polynomial_lr_schedule():
    test_header("Polynomial LR Schedule")
    schedule = polynomial_lr(0.1, total_steps=100, end_lr=0.0, power=2.0)
    lr_start = schedule(0)
    lr_mid = schedule(50)
    lr_end = schedule(100)
    
    test_assertion(np.isclose(lr_start, 0.1), f"Start LR: {lr_start}")
    test_assertion(lr_mid < lr_start, f"Mid LR < start: {lr_mid} < {lr_start}")
    test_assertion(np.isclose(lr_end, 0.0, atol=0.01), f"End LR ≈ 0: {lr_end}")
    print(f"  ✅ PASSED")


def test_cosine_lr_schedule():
    test_header("Cosine LR Schedule")
    schedule = cosine_lr(0.1, total_steps=100, min_lr=0.0)
    lr_start = schedule(0)
    lr_mid = schedule(50)
    lr_end = schedule(100)
    
    test_assertion(np.isclose(lr_start, 0.1), f"Start LR: {lr_start}")
    test_assertion(lr_mid < lr_start, f"Mid LR < start")
    test_assertion(np.isclose(lr_end, 0.0, atol=0.01), f"End LR ≈ 0")
    print(f"  ✅ PASSED")


def test_linear_warmup_lr_schedule():
    test_header("Linear Warmup LR Schedule")
    schedule = linear_warmup_lr(0.1, warmup_steps=10)
    lr_5 = schedule(5)
    lr_10 = schedule(10)
    lr_15 = schedule(15)
    
    test_assertion(np.isclose(lr_5, 0.05), f"Warmup step 5: {lr_5}")
    test_assertion(np.isclose(lr_10, 0.1), f"End warmup: {lr_10}")
    test_assertion(np.isclose(lr_15, 0.1), f"After warmup: {lr_15}")
    print(f"  ✅ PASSED")


def test_one_cycle_lr_schedule():
    test_header("One-Cycle LR Schedule")
    schedule = one_cycle_lr(0.01, 0.1, total_steps=100, pct_start=0.3)
    lr_start = schedule(0)
    lr_peak = schedule(30)
    lr_end = schedule(99)
    
    test_assertion(lr_start < lr_peak, f"Starts lower than peak")
    test_assertion(lr_peak > lr_start, f"Peak: {lr_peak}")
    test_assertion(lr_end < lr_peak, f"Ends lower than peak")
    print(f"  ✅ PASSED")


def test_gradient_norm_computation():
    test_header("Gradient Norm Computation")
    grads = [
        np.array([3.0, 4.0]),
        np.array([0.0])
    ]
    norm = compute_grad_norm(grads)
    expected = np.sqrt(9 + 16)  # sqrt(3^2 + 4^2) = 5
    test_assertion(np.isclose(norm, expected), f"Norm: {norm} (expected {expected})")
    print(f"  ✅ PASSED")


def test_weight_decay_application():
    test_header("Weight Decay Application")
    params = np.array([1.0, 2.0, 3.0])
    weight_decay = 0.01
    lr = 0.1
    
    updated = apply_weight_decay(params, weight_decay, lr)
    expected = params * (1 - weight_decay * lr)
    
    test_assertion(np.allclose(updated, expected), f"Weight decay applied: {updated}")
    test_assertion(np.all(updated < params), f"Parameters decreased")
    print(f"  ✅ PASSED")


def test_gradient_accumulator():
    test_header("Gradient Accumulator")
    accumulator = GradientAccumulator(num_accumulation_steps=3)
    
    grads1 = [np.array([1.0, 2.0])]
    grads2 = [np.array([1.0, 2.0])]
    grads3 = [np.array([1.0, 2.0])]
    
    accumulator.add_grads(grads1)
    test_assertion(not accumulator.should_update(), "No update after 1 step")
    
    accumulator.add_grads(grads2)
    test_assertion(not accumulator.should_update(), "No update after 2 steps")
    
    accumulator.add_grads(grads3)
    test_assertion(accumulator.should_update(), "Update after 3 steps")
    
    accumulated = accumulator.get_accumulated_grads()
    expected = [np.array([1.0, 2.0])]  # Averaged
    test_assertion(np.allclose(accumulated[0], expected[0]), f"Averaged gradients")
    print(f"  ✅ PASSED")


# ============================================================================
# Main Test Execution
# ============================================================================

def main():
    print("=" * 80)
    print("WEEK 6: ACTIVATION + LOSS + OPTIMIZER TESTS")
    print("=" * 80)
    
    tests_passed = 0
    tests_failed = 0
    
    # Activation Tests
    print("\n" + "=" * 80)
    print("ACTIVATION FUNCTION TESTS")
    print("=" * 80)
    
    activation_tests = [
        test_relu_activation,
        test_leaky_relu_activation,
        test_sigmoid_activation,
        test_softmax_activation,
        test_elu_activation,
        test_gelu_activation,
        test_softmax_numerical_stability,
        test_swish_activation,
        test_hardshrink_activation,
        test_hardtanh_activation,
    ]
    
    for test in activation_tests:
        try:
            test()
            tests_passed += 1
        except Exception as e:
            print(f"  ✗ FAILED: {e}")
            tests_failed += 1
    
    # Loss Tests
    print("\n" + "=" * 80)
    print("LOSS FUNCTION TESTS")
    print("=" * 80)
    
    loss_tests = [
        test_focal_loss,
        test_focal_loss_multi,
        test_hinge_loss,
        test_smooth_l1_loss,
        test_triplet_loss,
        test_contrastive_loss,
        test_kullback_leibler_divergence,
        test_wasserstein_loss,
        test_ntxent_loss,
    ]
    
    for test in loss_tests:
        try:
            test()
            tests_passed += 1
        except Exception as e:
            print(f"  ✗ FAILED: {e}")
            tests_failed += 1
    
    # Optimizer Tests
    print("\n" + "=" * 80)
    print("OPTIMIZER UTILITIES TESTS")
    print("=" * 80)
    
    optim_tests = [
        test_constant_lr_schedule,
        test_step_lr_schedule,
        test_exponential_lr_schedule,
        test_polynomial_lr_schedule,
        test_cosine_lr_schedule,
        test_linear_warmup_lr_schedule,
        test_one_cycle_lr_schedule,
        test_gradient_norm_computation,
        test_weight_decay_application,
        test_gradient_accumulator,
    ]
    
    for test in optim_tests:
        try:
            test()
            tests_passed += 1
        except Exception as e:
            print(f"  ✗ FAILED: {e}")
            tests_failed += 1
    
    # Results
    print("\n" + "=" * 80)
    print(f"RESULTS: {tests_passed} passed, {tests_failed} failed out of {tests_passed + tests_failed} tests")
    print("=" * 80)
    
    if tests_failed == 0:
        print("\n✅ ALL TESTS PASSED!")
    else:
        print(f"\n❌ {tests_failed} test(s) failed")
    
    return tests_failed == 0


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
