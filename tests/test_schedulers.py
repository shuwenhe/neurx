"""
Test Learning Rate Schedulers
"""
import sys
sys.path.insert(0, '/home/shuwen/tensor/python')

import tensor
import tensor.optim as optim
import numpy as np


def test_step_lr():
    """Test StepLR scheduler."""
    print("Testing StepLR...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.StepLR(optimizer, step_size=3, gamma=0.1)
    
    lrs = []
    for epoch in range(10):
        lrs.append(optimizer.lr)
        scheduler.step()
    
    # Check LR schedule
    assert lrs[0] == 1.0, f"Initial LR should be 1.0, got {lrs[0]}"
    assert abs(lrs[3] - 0.1) < 1e-6, f"LR at epoch 3 should be 0.1, got {lrs[3]}"
    assert abs(lrs[6] - 0.01) < 1e-6, f"LR at epoch 6 should be 0.01, got {lrs[6]}"
    
    print(f"  ✓ StepLR works (LRs: {lrs[:7]})")


def test_exponential_lr():
    """Test ExponentialLR scheduler."""
    print("Testing ExponentialLR...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.ExponentialLR(optimizer, gamma=0.9)
    
    lrs = []
    for epoch in range(5):
        lrs.append(optimizer.lr)
        scheduler.step()
    
    # Check exponential decay
    expected = [1.0, 0.9, 0.81, 0.729, 0.6561]
    for i, (actual, exp) in enumerate(zip(lrs, expected)):
        assert abs(actual - exp) < 1e-4, f"Epoch {i}: expected {exp}, got {actual}"
    
    print(f"  ✓ ExponentialLR works (LRs: {[f'{lr:.4f}' for lr in lrs]})")


def test_cosine_annealing_lr():
    """Test CosineAnnealingLR scheduler."""
    print("Testing CosineAnnealingLR...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.CosineAnnealingLR(optimizer, T_max=10, eta_min=0)
    
    lrs = []
    for epoch in range(11):
        lrs.append(optimizer.lr)
        scheduler.step()
    
    # Check cosine pattern
    assert lrs[0] == 1.0, "Initial LR should be 1.0"
    assert lrs[5] < lrs[0], "LR should decrease"
    assert lrs[10] < 0.1, "LR should be close to eta_min at T_max"
    
    print(f"  ✓ CosineAnnealingLR works (LRs: {[f'{lr:.3f}' for lr in lrs[::2]]})")


def test_cosine_annealing_warm_restarts():
    """Test CosineAnnealingWarmRestarts scheduler."""
    print("Testing CosineAnnealingWarmRestarts...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.CosineAnnealingWarmRestarts(optimizer, T_0=5, T_mult=2)
    
    lrs = []
    for epoch in range(16):
        lrs.append(optimizer.lr)
        scheduler.step()
    
    # Check restarts
    assert lrs[0] == 1.0, "Initial LR should be 1.0"
    assert lrs[5] > lrs[4], "Should restart at epoch 5"
    
    print(f"  ✓ CosineAnnealingWarmRestarts works")


def test_reduce_lr_on_plateau():
    """Test ReduceLROnPlateau scheduler."""
    print("Testing ReduceLROnPlateau...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.ReduceLROnPlateau(optimizer, mode='min', patience=2, factor=0.5)
    
    # Simulate plateauing loss
    losses = [1.0, 0.9, 0.85, 0.84, 0.84, 0.84, 0.84, 0.84]
    lrs = []
    
    for loss in losses:
        lrs.append(optimizer.lr)
        scheduler.step(loss)
    
    # LR should reduce after patience epochs of no improvement
    assert lrs[0] == 1.0, "Initial LR should be 1.0"
    assert lrs[-1] < lrs[0], "LR should be reduced when plateauing"
    
    print(f"  ✓ ReduceLROnPlateau works (LRs: {[f'{lr:.3f}' for lr in lrs]})")


def test_linear_lr():
    """Test LinearLR scheduler."""
    print("Testing LinearLR...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.LinearLR(optimizer, start_factor=0.1, end_factor=1.0, total_iters=5)
    
    lrs = []
    for epoch in range(8):
        lrs.append(optimizer.lr)
        scheduler.step()
    
    # Check linear warmup
    assert abs(lrs[0] - 0.1) < 1e-6, f"Initial LR should be ~0.1, got {lrs[0]}"
    assert abs(lrs[5] - 1.0) < 1e-6, f"LR at epoch 5 should be ~1.0, got {lrs[5]}"
    assert abs(lrs[7] - 1.0) < 1e-6, "LR should stay at 1.0 after total_iters"
    
    print(f"  ✓ LinearLR works (LRs: {[f'{lr:.2f}' for lr in lrs]})")


def test_lambda_lr():
    """Test LambdaLR scheduler."""
    print("Testing LambdaLR...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    
    # Custom lambda: multiply by 0.95 each epoch
    scheduler = optim.LambdaLR(optimizer, lr_lambda=lambda epoch: 0.95 ** epoch)
    
    lrs = []
    for epoch in range(5):
        lrs.append(optimizer.lr)
        scheduler.step()
    
    # Check custom schedule
    expected = [1.0, 0.95, 0.9025, 0.857375, 0.81450625]
    for i, (actual, exp) in enumerate(zip(lrs, expected)):
        assert abs(actual - exp) < 1e-4, f"Epoch {i}: expected {exp}, got {actual}"
    
    print(f"  ✓ LambdaLR works (LRs: {[f'{lr:.4f}' for lr in lrs]})")


def test_scheduler_with_training():
    """Test scheduler in actual training loop."""
    print("Testing scheduler with training...")
    
    # Simple model
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=0.1)
    scheduler = optim.StepLR(optimizer, step_size=5, gamma=0.5)
    
    x = tensor.randn(10, 3)
    target = tensor.randn(10, 2)
    
    lrs = []
    losses = []
    
    for epoch in range(15):
        # Training step
        optimizer.zero_grad()
        pred = x @ W
        loss = ((pred - target) ** 2).sum()
        loss.backward()
        optimizer.step()
        
        lrs.append(optimizer.lr)
        losses.append(loss.item())
        
        # Update LR
        scheduler.step()
    
    # Check LR schedule was applied
    assert lrs[0] == 0.1, "Initial LR should be 0.1"
    assert abs(lrs[5] - 0.05) < 1e-6, "LR should be 0.05 at epoch 5"
    assert abs(lrs[10] - 0.025) < 1e-6, "LR should be 0.025 at epoch 10"
    
    print(f"  ✓ Scheduler works in training (LRs: {lrs[::5]})")


def test_scheduler_state_dict():
    """Test scheduler state save/load."""
    print("Testing scheduler state_dict...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler1 = optim.StepLR(optimizer, step_size=3, gamma=0.1)
    
    # Run a few steps
    for _ in range(5):
        scheduler1.step()
    
    # Save state
    state = scheduler1.state_dict()
    
    # Create new scheduler and load state
    optimizer2 = optim.SGD([W], lr=1.0)
    scheduler2 = optim.StepLR(optimizer2, step_size=3, gamma=0.1)
    scheduler2.load_state_dict(state)
    
    # Check state restored
    assert scheduler2.last_epoch == scheduler1.last_epoch, "last_epoch should match"
    
    print("  ✓ Scheduler state_dict save/load works")


def test_multiple_schedulers():
    """Test using multiple schedulers together."""
    print("Testing multiple schedulers...")
    
    W1 = tensor.randn(3, 2, requires_grad=True)
    W2 = tensor.randn(2, 1, requires_grad=True)
    
    optimizer1 = optim.SGD([W1], lr=1.0)
    optimizer2 = optim.SGD([W2], lr=0.5)
    
    scheduler1 = optim.StepLR(optimizer1, step_size=2, gamma=0.5)
    scheduler2 = optim.ExponentialLR(optimizer2, gamma=0.9)
    
    for epoch in range(5):
        # Both optimizers step
        scheduler1.step()
        scheduler2.step()
    
    # Check both schedulers worked independently
    assert optimizer1.lr < 1.0, "optimizer1 LR should decrease"
    assert optimizer2.lr < 0.5, "optimizer2 LR should decrease"
    
    print("  ✓ Multiple schedulers work independently")


def test_warmup_then_decay():
    """Test combining warmup and decay."""
    print("Testing warmup then decay pattern...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    
    # Warmup phase
    warmup_scheduler = optim.LinearLR(optimizer, start_factor=0.1, end_factor=1.0, total_iters=5)
    
    lrs = []
    for epoch in range(5):
        lrs.append(optimizer.lr)
        warmup_scheduler.step()
    
    # Then use step decay
    decay_scheduler = optim.StepLR(optimizer, step_size=3, gamma=0.5)
    
    for epoch in range(10):
        lrs.append(optimizer.lr)
        decay_scheduler.step()
    
    # Check pattern
    assert lrs[0] < lrs[4], "Should warmup"
    assert lrs[-1] < lrs[5], "Should decay after warmup"
    
    print(f"  ✓ Warmup then decay works")


def test_reduce_on_plateau_min_lr():
    """Test ReduceLROnPlateau respects min_lr."""
    print("Testing ReduceLROnPlateau min_lr...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = optim.SGD([W], lr=1.0)
    scheduler = optim.ReduceLROnPlateau(optimizer, mode='min', patience=1, 
                                         factor=0.1, min_lr=0.01)
    
    # Force many reductions
    for i in range(20):
        scheduler.step(1.0)  # Constant loss
    
    # LR should not go below min_lr
    assert optimizer.lr >= 0.01, f"LR should not go below min_lr, got {optimizer.lr}"
    
    print(f"  ✓ ReduceLROnPlateau respects min_lr (final LR: {optimizer.lr})")


if __name__ == "__main__":
    print("=" * 60)
    print("Testing Learning Rate Schedulers")
    print("=" * 60)
    
    test_step_lr()
    test_exponential_lr()
    test_cosine_annealing_lr()
    test_cosine_annealing_warm_restarts()
    test_reduce_lr_on_plateau()
    test_linear_lr()
    test_lambda_lr()
    test_scheduler_with_training()
    test_scheduler_state_dict()
    test_multiple_schedulers()
    test_warmup_then_decay()
    test_reduce_on_plateau_min_lr()
    
    print("\n" + "=" * 60)
    print("✅ All scheduler tests passed!")
    print("=" * 60)
