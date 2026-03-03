"""
Test Conv2d convolutional layer
"""
import sys
sys.path.insert(0, '/home/shuwen/tensor/python')

import tensor
import tensor.nn as nn
import numpy as np


def test_conv2d_basic():
    """Test basic Conv2d layer."""
    print("Testing Conv2d (basic)...")
    
    conv = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1)
    
    # Input: (batch=1, channels=3, height=32, width=32)
    x = tensor.randn(1, 3, 32, 32)
    out = conv(x)
    
    # Output should be (batch=1, channels=16, height=32, width=32)
    assert out.shape == (1, 16, 32, 32), f"Expected shape (1, 16, 32, 32), got {out.shape}"
    
    print("  ✓ Basic Conv2d works")


def test_conv2d_output_shape():
    """Test Conv2d output shapes with different parameters."""
    print("Testing Conv2d output shapes...")
    
    # Test 1: stride=1, padding=0
    conv = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=0)
    x = tensor.randn(2, 3, 32, 32)
    out = conv(x)
    assert out.shape == (2, 16, 30, 30), f"Expected (2, 16, 30, 30), got {out.shape}"
    
    # Test 2: stride=2, padding=1
    conv = nn.Conv2d(3, 32, kernel_size=3, stride=2, padding=1)
    x = tensor.randn(2, 3, 32, 32)
    out = conv(x)
    assert out.shape == (2, 32, 16, 16), f"Expected (2, 32, 16, 16), got {out.shape}"
    
    # Test 3: kernel_size=5, stride=1, padding=2
    conv = nn.Conv2d(3, 64, kernel_size=5, stride=1, padding=2)
    x = tensor.randn(1, 3, 28, 28)
    out = conv(x)
    assert out.shape == (1, 64, 28, 28), f"Expected (1, 64, 28, 28), got {out.shape}"
    
    print("  ✓ Conv2d output shapes correct")


def test_conv2d_gradient():
    """Test Conv2d gradients flow correctly."""
    print("Testing Conv2d gradients...")
    
    conv = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1)
    x = tensor.randn(2, 3, 32, 32, requires_grad=True)
    out = conv(x)
    loss = out.sum()
    
    # Store initial weight
    W_before = conv.weight.data.copy()
    
    # Backward pass
    loss.backward()
    
    # Check gradients exist
    assert conv.weight.grad is not None, "Weight gradient should exist"
    assert conv.bias.grad is not None, "Bias gradient should exist"
    assert x.grad is not None, "Input gradient should exist"
    
    assert np.any(conv.weight.grad != 0), "Weight gradient should be non-zero"
    assert np.any(conv.bias.grad != 0), "Bias gradient should be non-zero"
    assert np.any(x.grad != 0), "Input gradient should be non-zero"
    
    print("  ✓ Conv2d gradients flow correctly")


def test_conv2d_training():
    """Test Conv2d layer in a simple training loop."""
    print("Testing Conv2d training...")
    
    # Create model
    class SimpleConvNet(nn.Module):
        def __init__(self):
            super().__init__()
            self.conv1 = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1)
            self.conv2 = nn.Conv2d(16, 32, kernel_size=3, stride=1, padding=1)
        
        def forward(self, x):
            x = self.conv1(x)
            x = self.conv2(x)
            return x
    
    model = SimpleConvNet()
    optimizer = tensor.optim.SGD(model.parameters(), lr=0.01)
    
    # Create dummy data
    x = tensor.randn(2, 3, 32, 32)
    target = tensor.randn(2, 32, 32, 32)
    
    initial_loss = None
    for step in range(10):
        optimizer.zero_grad()
        pred = model(x)
        loss = ((pred - target) ** 2).sum()
        
        if step == 0:
            initial_loss = loss.item()
        
        loss.backward()
        optimizer.step()
    
    final_loss = loss.item()
    assert final_loss < initial_loss, f"Loss should decrease: {initial_loss} -> {final_loss}"
    
    print(f"  ✓ Conv2d training works (loss: {initial_loss:.4f} -> {final_loss:.4f})")


def test_conv2d_no_bias():
    """Test Conv2d without bias."""
    print("Testing Conv2d without bias...")
    
    conv = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1, bias=False)
    x = tensor.randn(1, 3, 32, 32)
    out = conv(x)
    
    assert conv.bias is None, "Bias should be None"
    assert out.shape == (1, 16, 32, 32), f"Expected (1, 16, 32, 32), got {out.shape}"
    
    # Test backward
    loss = out.sum()
    loss.backward()
    assert conv.weight.grad is not None, "Weight gradient should exist"
    
    print("  ✓ Conv2d without bias works")


def test_conv2d_1x1():
    """Test 1x1 convolution."""
    print("Testing 1x1 convolution...")
    
    conv = nn.Conv2d(16, 32, kernel_size=1, stride=1, padding=0)
    x = tensor.randn(1, 16, 32, 32)
    out = conv(x)
    
    assert out.shape == (1, 32, 32, 32), f"Expected (1, 32, 32, 32), got {out.shape}"
    
    # 1x1 conv can be seen as channel-wise projection
    loss = out.sum()
    loss.backward()
    assert conv.weight.grad is not None, "Gradient should exist"
    
    print("  ✓ 1x1 convolution works")


def test_conv2d_large_kernel():
    """Test conv with larger kernel."""
    print("Testing conv with large kernel...")
    
    conv = nn.Conv2d(3, 64, kernel_size=5, stride=1, padding=2)
    x = tensor.randn(1, 3, 28, 28)
    out = conv(x)
    
    assert out.shape == (1, 64, 28, 28), f"Expected (1, 64, 28, 28), got {out.shape}"
    
    print("  ✓ Large kernel convolution works")


def test_conv2d_multiple_batches():
    """Test Conv2d with different batch sizes."""
    print("Testing Conv2d with different batch sizes...")
    
    conv = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1)
    
    for batch_size in [1, 2, 4, 8]:
        x = tensor.randn(batch_size, 3, 32, 32)
        out = conv(x)
        assert out.shape == (batch_size, 16, 32, 32), f"Expected ({batch_size}, 16, 32, 32), got {out.shape}"
    
    print("  ✓ Different batch sizes work")


def test_conv2d_sequential_layers():
    """Test multiple conv layers sequentially."""
    print("Testing sequential conv layers...")
    
    conv1 = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1)
    conv2 = nn.Conv2d(16, 32, kernel_size=3, stride=1, padding=1)
    conv3 = nn.Conv2d(32, 64, kernel_size=3, stride=1, padding=1)
    
    x = tensor.randn(2, 3, 32, 32)
    
    x = conv1(x)
    assert x.shape == (2, 16, 32, 32)
    
    x = conv2(x)
    assert x.shape == (2, 32, 32, 32)
    
    x = conv3(x)
    assert x.shape == (2, 64, 32, 32)
    
    # Test backward
    loss = x.sum()
    loss.backward()
    
    assert conv1.weight.grad is not None
    assert conv2.weight.grad is not None
    assert conv3.weight.grad is not None
    
    print("  ✓ Sequential conv layers work")


def test_conv2d_state_dict():
    """Test Conv2d state_dict save/load."""
    print("Testing Conv2d state_dict...")
    
    class ConvNet(nn.Module):
        def __init__(self):
            super().__init__()
            self.conv = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1)
        
        def forward(self, x):
            return self.conv(x)
    
    model1 = ConvNet()
    state = model1.state_dict()
    
    # Create new model and load state
    model2 = ConvNet()
    model2.load_state_dict(state)
    
    # Weights should be identical
    assert np.allclose(model1.conv.weight.data, model2.conv.weight.data), "Weights should match"
    assert np.allclose(model1.conv.bias.data, model2.conv.bias.data), "Biases should match"
    
    print("  ✓ Conv2d state_dict works")


def test_conv2d_with_pooling_pattern():
    """Test typical conv->pool pattern (without actual pooling)."""
    print("Testing conv pattern (simulating conv->pool)...")
    
    class SimpleCNN(nn.Module):
        def __init__(self):
            super().__init__()
            self.conv1 = nn.Conv2d(3, 32, kernel_size=3, stride=1, padding=1)
            self.conv2 = nn.Conv2d(32, 64, kernel_size=3, stride=2, padding=1)
            self.conv3 = nn.Conv2d(64, 128, kernel_size=3, stride=2, padding=1)
        
        def forward(self, x):
            # Input: (batch, 3, 32, 32)
            x = self.conv1(x)  # -> (batch, 32, 32, 32)
            x = self.conv2(x)  # -> (batch, 64, 16, 16)
            x = self.conv3(x)  # -> (batch, 128, 8, 8)
            return x
    
    model = SimpleCNN()
    x = tensor.randn(2, 3, 32, 32)
    out = model(x)
    
    assert out.shape == (2, 128, 8, 8), f"Expected (2, 128, 8, 8), got {out.shape}"
    
    # Test training
    target = tensor.randn(2, 128, 8, 8)
    loss = ((out - target) ** 2).sum()
    loss.backward()
    
    assert model.conv1.weight.grad is not None
    assert model.conv2.weight.grad is not None
    assert model.conv3.weight.grad is not None
    
    print("  ✓ Conv pattern (stride 2) works")


if __name__ == "__main__":
    print("=" * 60)
    print("Testing Conv2d Convolutional Layer")
    print("=" * 60)
    
    test_conv2d_basic()
    test_conv2d_output_shape()
    test_conv2d_gradient()
    test_conv2d_training()
    test_conv2d_no_bias()
    test_conv2d_1x1()
    test_conv2d_large_kernel()
    test_conv2d_multiple_batches()
    test_conv2d_sequential_layers()
    test_conv2d_state_dict()
    test_conv2d_with_pooling_pattern()
    
    print("\n" + "=" * 60)
    print("✅ All Conv2d tests passed!")
    print("=" * 60)
