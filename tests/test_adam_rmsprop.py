"""
Test Adam and RMSprop optimizers
"""
import sys
sys.path.insert(0, '/home/shuwen/tensor/python')

import tensor
import tensor.nn as nn
import numpy as np


def test_adam_basic():
    """Test basic Adam optimizer."""
    print("Testing Adam (basic)...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    b = tensor.zeros(2, requires_grad=True)
    
    optimizer = tensor.optim.Adam([W, b], lr=0.01)
    
    x = tensor.randn(5, 3)
    y = x @ W + b
    loss = (y ** 2).sum()
    
    W_before = W.data.copy()
    b_before = b.data.copy()
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    assert not np.allclose(W.data, W_before), "W should be updated"
    assert not np.allclose(b.data, b_before), "b should be updated"
    
    print("  ✓ Basic Adam works")


def test_adam_convergence():
    """Test Adam can converge on simple function."""
    print("Testing Adam convergence...")
    
    # Minimize f(x) = (x - 5)^2
    x = tensor.Tensor([0.0], requires_grad=True)
    optimizer = tensor.optim.Adam([x], lr=0.1)
    
    losses = []
    for i in range(100):
        loss = (x - 5) ** 2
        losses.append(loss.item())
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
    
    assert losses[-1] < losses[0], "Loss should decrease"
    assert abs(x.item() - 5.0) < 1.0, f"Should converge near 5, got {x.item()}"
    
    print(f"  ✓ Adam converges (final x={x.item():.4f}, target=5.0)")


def test_adam_vs_adamw():
    """Compare Adam and AdamW."""
    print("Testing Adam vs AdamW...")
    
    # Create identical models
    W1 = tensor.randn(3, 2, requires_grad=True)
    W2 = tensor.Tensor(W1.data.copy(), requires_grad=True)
    
    adam = tensor.optim.Adam([W1], lr=0.01, weight_decay=0.1)
    adamw = tensor.optim.AdamW([W2], lr=0.01, weight_decay=0.1)
    
    x = tensor.randn(5, 3)
    target = tensor.randn(5, 2)
    
    initial_loss1 = None
    initial_loss2 = None
    
    # Train both
    for i in range(50):
        # Adam
        adam.zero_grad()
        pred1 = x @ W1
        loss1 = ((pred1 - target) ** 2).sum()
        if i == 0:
            initial_loss1 = loss1.item()
        loss1.backward()
        adam.step()
        
        # AdamW
        adamw.zero_grad()
        pred2 = x @ W2
        loss2 = ((pred2 - target) ** 2).sum()
        if i == 0:
            initial_loss2 = loss2.item()
        loss2.backward()
        adamw.step()
    
    # Both should reduce loss
    final_loss1 = loss1.item()
    final_loss2 = loss2.item()
    assert final_loss1 < initial_loss1, "Adam should reduce loss"
    assert final_loss2 < initial_loss2, "AdamW should reduce loss"
    
    print(f"  ✓ Both Adam and AdamW converge (Adam: {initial_loss1:.2f}→{final_loss1:.2f}, AdamW: {initial_loss2:.2f}→{final_loss2:.2f})")


def test_adam_state_dict():
    """Test Adam state save/load."""
    print("Testing Adam state_dict...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer1 = tensor.optim.Adam([W], lr=0.01)
    
    # Do some steps
    for _ in range(5):
        x = tensor.randn(5, 3)
        loss = (x @ W ** 2).sum()
        optimizer1.zero_grad()
        loss.backward()
        optimizer1.step()
    
    # Save state
    state = optimizer1.state_dict()
    
    # Create new optimizer and load state
    W2 = tensor.Tensor(W.data.copy(), requires_grad=True)
    optimizer2 = tensor.optim.Adam([W2], lr=0.05)
    optimizer2.load_state_dict(state)
    
    assert optimizer2.lr == 0.01, "Learning rate should be restored"
    assert optimizer2.step_count == 5, "Step count should be restored"
    
    print("  ✓ Adam state_dict save/load works")


def test_rmsprop_basic():
    """Test basic RMSprop optimizer."""
    print("Testing RMSprop (basic)...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    b = tensor.zeros(2, requires_grad=True)
    
    optimizer = tensor.optim.RMSprop([W, b], lr=0.01)
    
    x = tensor.randn(5, 3)
    y = x @ W + b
    loss = (y ** 2).sum()
    
    W_before = W.data.copy()
    b_before = b.data.copy()
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    assert not np.allclose(W.data, W_before), "W should be updated"
    assert not np.allclose(b.data, b_before), "b should be updated"
    
    print("  ✓ Basic RMSprop works")


def test_rmsprop_momentum():
    """Test RMSprop with momentum."""
    print("Testing RMSprop with momentum...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = tensor.optim.RMSprop([W], lr=0.01, momentum=0.9)
    
    x = tensor.randn(5, 3)
    
    # First step
    loss1 = (x @ W ** 2).sum()
    optimizer.zero_grad()
    loss1.backward()
    optimizer.step()
    
    # Second step
    loss2 = (x @ W ** 2).sum()
    optimizer.zero_grad()
    loss2.backward()
    W_before = W.data.copy()
    optimizer.step()
    
    assert not np.allclose(W.data, W_before), "W should be updated"
    
    print("  ✓ RMSprop with momentum works")


def test_rmsprop_centered():
    """Test centered RMSprop."""
    print("Testing RMSprop centered...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer = tensor.optim.RMSprop([W], lr=0.01, centered=True)
    
    x = tensor.randn(5, 3)
    loss = (x @ W ** 2).sum()
    
    W_before = W.data.copy()
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    assert not np.allclose(W.data, W_before), "W should be updated"
    
    print("  ✓ RMSprop centered works")


def test_rmsprop_convergence():
    """Test RMSprop can converge."""
    print("Testing RMSprop convergence...")
    
    # Minimize f(x) = (x - 3)^2
    x = tensor.Tensor([0.0], requires_grad=True)
    optimizer = tensor.optim.RMSprop([x], lr=0.1)
    
    losses = []
    for i in range(100):
        loss = (x - 3) ** 2
        losses.append(loss.item())
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
    
    assert losses[-1] < losses[0], "Loss should decrease"
    assert abs(x.item() - 3.0) < 0.5, f"Should converge near 3, got {x.item()}"
    
    print(f"  ✓ RMSprop converges (final x={x.item():.4f}, target=3.0)")


def test_rmsprop_state_dict():
    """Test RMSprop state save/load."""
    print("Testing RMSprop state_dict...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    optimizer1 = tensor.optim.RMSprop([W], lr=0.01, momentum=0.9)
    
    # Do some steps
    for _ in range(5):
        x = tensor.randn(5, 3)
        loss = (x @ W ** 2).sum()
        optimizer1.zero_grad()
        loss.backward()
        optimizer1.step()
    
    # Save state
    state = optimizer1.state_dict()
    
    # Create new optimizer and load state
    W2 = tensor.Tensor(W.data.copy(), requires_grad=True)
    optimizer2 = tensor.optim.RMSprop([W2], lr=0.05)
    optimizer2.load_state_dict(state)
    
    assert optimizer2.lr == 0.01, "Learning rate should be restored"
    assert optimizer2.momentum == 0.9, "Momentum should be restored"
    
    print("  ✓ RMSprop state_dict save/load works")


def test_all_optimizers_comparison():
    """Compare all optimizers on same problem."""
    print("Testing all optimizers comparison...")
    
    # Create identical starting points
    W_init = tensor.randn(10, 5)
    
    optimizers = {
        'SGD': tensor.optim.SGD([tensor.Tensor(W_init.data.copy(), requires_grad=True)], lr=0.01),
        'Adam': tensor.optim.Adam([tensor.Tensor(W_init.data.copy(), requires_grad=True)], lr=0.01),
        'AdamW': tensor.optim.AdamW([tensor.Tensor(W_init.data.copy(), requires_grad=True)], lr=0.01),
        'RMSprop': tensor.optim.RMSprop([tensor.Tensor(W_init.data.copy(), requires_grad=True)], lr=0.01),
    }
    
    x = tensor.randn(20, 10)
    target = tensor.randn(20, 5)
    
    final_losses = {}
    
    for name, opt in optimizers.items():
        W = opt.params[0]
        for _ in range(50):
            opt.zero_grad()
            pred = x @ W
            loss = ((pred - target) ** 2).sum()
            loss.backward()
            opt.step()
        
        final_losses[name] = loss.item()
    
    # All should reduce loss
    for name, loss in final_losses.items():
        assert loss < 1000, f"{name} should reduce loss significantly"
    
    print(f"  ✓ All optimizers work (final losses: {', '.join(f'{k}={v:.2f}' for k, v in final_losses.items())})")


def test_optimizers_with_module():
    """Test optimizers with nn.Module."""
    print("Testing optimizers with nn.Module...")
    
    class SimpleModel(nn.Module):
        def __init__(self):
            super().__init__()
            self.linear = nn.Linear(3, 2)
        
        def forward(self, x):
            return self.linear(x)
    
    x = tensor.randn(10, 3)
    target = tensor.randn(10, 2)
    
    optimizers_to_test = [
        ('Adam', tensor.optim.Adam),
        ('RMSprop', tensor.optim.RMSprop),
    ]
    
    for name, opt_class in optimizers_to_test:
        model = SimpleModel()
        optimizer = opt_class(model.parameters(), lr=0.01)
        
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
        assert final_loss < initial_loss, f"{name} should reduce loss"
    
    print("  ✓ Optimizers work with nn.Module")


def test_optimizers_with_scheduler():
    """Test optimizers work with schedulers."""
    print("Testing optimizers with schedulers...")
    
    W = tensor.randn(3, 2, requires_grad=True)
    
    optimizers_to_test = [
        ('Adam', tensor.optim.Adam([W], lr=0.1)),
        ('RMSprop', tensor.optim.RMSprop([W], lr=0.1)),
    ]
    
    for name, optimizer in optimizers_to_test:
        scheduler = tensor.optim.StepLR(optimizer, step_size=5, gamma=0.5)
        
        initial_lr = optimizer.lr
        
        for epoch in range(11):
            x = tensor.randn(5, 3)
            loss = (x @ W ** 2).sum()
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            scheduler.step()
        
        # LR should have decreased
        assert optimizer.lr < initial_lr, f"{name} LR should decrease with scheduler"
    
    print("  ✓ Optimizers work with schedulers")


if __name__ == "__main__":
    print("=" * 60)
    print("Testing Adam and RMSprop Optimizers")
    print("=" * 60)
    
    test_adam_basic()
    test_adam_convergence()
    test_adam_vs_adamw()
    test_adam_state_dict()
    test_rmsprop_basic()
    test_rmsprop_momentum()
    test_rmsprop_centered()
    test_rmsprop_convergence()
    test_rmsprop_state_dict()
    test_all_optimizers_comparison()
    test_optimizers_with_module()
    test_optimizers_with_scheduler()
    
    print("\n" + "=" * 60)
    print("✅ All optimizer tests passed!")
    print("=" * 60)
