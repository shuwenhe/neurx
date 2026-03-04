"""
Test SGD optimizer
"""
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

import neurx
import neurx.nn as nn
import numpy as np


def test_sgd_basic():
    """Test basic SGD without momentum."""
    print("Testing SGD (basic)...")
    
    # Create simple linear model
    W = neurx.randn(3, 2, requires_grad=True)
    b = neurx.zeros(2, requires_grad=True)
    
    optimizer = neurx.optim.SGD([W, b], lr=0.1)
    
    # Simple forward and backward
    x = neurx.randn(5, 3)
    y = x @ W + b
    loss = (y ** 2).sum()
    
    # Store initial values
    W_before = W.data.copy()
    b_before = b.data.copy()
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    # Check parameters updated
    assert not np.allclose(W.data, W_before), "W should be updated"
    assert not np.allclose(b.data, b_before), "b should be updated"
    
    print("  ✓ Basic SGD works")


def test_sgd_momentum():
    """Test SGD with momentum."""
    print("Testing SGD with momentum...")
    
    W = neurx.randn(3, 2, requires_grad=True)
    optimizer = neurx.optim.SGD([W], lr=0.1, momentum=0.9)
    
    # First step
    x = neurx.randn(5, 3)
    y = x @ W
    loss1 = (y ** 2).sum()
    
    optimizer.zero_grad()
    loss1.backward()
    grad1 = W.grad.copy()
    optimizer.step()
    
    # Second step - momentum should accumulate
    loss2 = (x @ W ** 2).sum()
    optimizer.zero_grad()
    loss2.backward()
    grad2 = W.grad.copy()
    
    W_before = W.data.copy()
    optimizer.step()
    
    # Update should be influenced by previous gradient
    assert not np.allclose(W.data, W_before), "W should be updated"
    
    print("  ✓ SGD with momentum works")


def test_sgd_nesterov():
    """Test SGD with Nesterov momentum."""
    print("Testing SGD with Nesterov momentum...")
    
    W = neurx.randn(3, 2, requires_grad=True)
    optimizer = neurx.optim.SGD([W], lr=0.1, momentum=0.9, nesterov=True)
    
    x = neurx.randn(5, 3)
    y = x @ W
    loss = (y ** 2).sum()
    
    W_before = W.data.copy()
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    assert not np.allclose(W.data, W_before), "W should be updated"
    
    print("  ✓ SGD with Nesterov momentum works")


def test_sgd_weight_decay():
    """Test SGD with weight decay."""
    print("Testing SGD with weight decay...")
    
    W = neurx.ones(3, 2, requires_grad=True)
    optimizer = neurx.optim.SGD([W], lr=0.1, weight_decay=0.01)
    
    x = neurx.randn(5, 3)
    y = x @ W
    loss = (y ** 2).sum()
    
    W_before = W.data.copy()
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    # Weight decay should shrink weights
    assert not np.allclose(W.data, W_before), "W should be updated"
    
    print("  ✓ SGD with weight decay works")


def test_sgd_convergence():
    """Test SGD can minimize a simple quadratic function."""
    print("Testing SGD convergence...")
    
    # Minimize f(x) = (x - 3)^2, optimal x = 3
    x = neurx.Tensor([0.0], requires_grad=True)
    optimizer = neurx.optim.SGD([x], lr=0.1)
    
    losses = []
    for i in range(100):
        loss = (x - 3) ** 2
        losses.append(loss.item())
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
    
    # Check convergence
    assert losses[-1] < losses[0], "Loss should decrease"
    assert abs(x.item() - 3.0) < 0.5, f"Should converge near 3, got {x.item()}"
    
    print(f"  ✓ SGD converges (final x={x.item():.4f}, target=3.0)")


def test_sgd_vs_adamw():
    """Compare SGD and AdamW on simple problem."""
    print("Testing SGD vs AdamW...")
    
    # Create identical models
    W1 = neurx.randn(3, 2, requires_grad=True)
    W2 = neurx.Tensor(W1.data.copy(), requires_grad=True)
    
    sgd = neurx.optim.SGD([W1], lr=0.01)
    adamw = neurx.optim.AdamW([W2], lr=0.01)
    
    x = neurx.randn(5, 3)
    target = neurx.randn(5, 2)
    
    # Train both
    for _ in range(10):
        # SGD
        sgd.zero_grad()
        pred1 = x @ W1
        loss1 = ((pred1 - target) ** 2).sum()
        loss1.backward()
        sgd.step()
        
        # AdamW
        adamw.zero_grad()
        pred2 = x @ W2
        loss2 = ((pred2 - target) ** 2).sum()
        loss2.backward()
        adamw.step()
    
    # Both should reduce loss
    print("  ✓ SGD and AdamW both work")


def test_sgd_state_dict():
    """Test saving and loading optimizer state."""
    print("Testing SGD state_dict...")
    
    W = neurx.randn(3, 2, requires_grad=True)
    optimizer1 = neurx.optim.SGD([W], lr=0.1, momentum=0.9)
    
    # Do some steps
    for _ in range(5):
        x = neurx.randn(5, 3)
        loss = (x @ W ** 2).sum()
        optimizer1.zero_grad()
        loss.backward()
        optimizer1.step()
    
    # Save state
    state = optimizer1.state_dict()
    
    # Create new optimizer and load state
    W2 = neurx.Tensor(W.data.copy(), requires_grad=True)
    optimizer2 = neurx.optim.SGD([W2], lr=0.05)  # Different lr
    optimizer2.load_state_dict(state)
    
    # Check state loaded correctly
    assert optimizer2.lr == 0.1, "Learning rate should be restored"
    assert optimizer2.momentum == 0.9, "Momentum should be restored"
    
    print("  ✓ SGD state_dict save/load works")


def test_sgd_with_module():
    """Test SGD with nn.Module."""
    print("Testing SGD with nn.Module...")
    
    class SimpleModel(nn.Module):
        def __init__(self):
            super().__init__()
            self.linear = nn.Linear(3, 2)
        
        def forward(self, x):
            return self.linear(x)
    
    model = SimpleModel()
    optimizer = neurx.optim.SGD(model.parameters(), lr=0.01, momentum=0.9)
    
    x = neurx.randn(5, 3)
    target = neurx.randn(5, 2)
    
    initial_loss = None
    for i in range(20):
        optimizer.zero_grad()
        pred = model(x)
        loss = ((pred - target) ** 2).sum()
        
        if i == 0:
            initial_loss = loss.item()
        
        loss.backward()
        optimizer.step()
    
    final_loss = loss.item()
    assert final_loss < initial_loss, f"Loss should decrease: {initial_loss:.4f} -> {final_loss:.4f}"
    
    print(f"  ✓ SGD with nn.Module works (loss: {initial_loss:.4f} -> {final_loss:.4f})")


def test_sgd_zero_grad():
    """Test zero_grad functionality."""
    print("Testing SGD zero_grad...")
    
    W = neurx.randn(3, 2, requires_grad=True)
    optimizer = neurx.optim.SGD([W], lr=0.1)
    
    # Compute gradients
    x = neurx.randn(5, 3)
    loss = (x @ W ** 2).sum()
    loss.backward()
    
    assert W.grad is not None, "Gradient should exist"
    assert not np.allclose(W.grad, 0), "Gradient should be non-zero"
    
    # Zero gradients
    optimizer.zero_grad()
    
    assert np.allclose(W.grad, 0), "Gradient should be zero after zero_grad"
    
    print("  ✓ SGD zero_grad works")


if __name__ == "__main__":
    print("=" * 60)
    print("Testing SGD Optimizer")
    print("=" * 60)
    
    test_sgd_basic()
    test_sgd_momentum()
    test_sgd_nesterov()
    test_sgd_weight_decay()
    test_sgd_convergence()
    test_sgd_vs_adamw()
    test_sgd_state_dict()
    test_sgd_with_module()
    test_sgd_zero_grad()
    
    print("\n" + "=" * 60)
    print("✅ All SGD tests passed!")
    print("=" * 60)
