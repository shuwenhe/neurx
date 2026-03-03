"""
Test tensor creation functions
"""
import sys
sys.path.insert(0, '/home/shuwen/tensor/python')

import tensor
import numpy as np

def test_zeros():
    print("Testing zeros...")
    t = tensor.zeros(2, 3)
    assert t.shape == (2, 3)
    assert np.all(t.to_numpy() == 0)
    print("  ✓ zeros(2, 3) works")
    
    t2 = tensor.zeros((3, 4), dtype=np.int32)
    assert t2.shape == (3, 4)
    print("  ✓ zeros((3, 4), dtype=int32) works")

def test_ones():
    print("Testing ones...")
    t = tensor.ones(2, 3)
    assert t.shape == (2, 3)
    assert np.all(t.to_numpy() == 1)
    print("  ✓ ones(2, 3) works")

def test_rand():
    print("Testing rand...")
    t = tensor.rand(3, 4)
    assert t.shape == (3, 4)
    assert np.all(t.to_numpy() >= 0) and np.all(t.to_numpy() < 1)
    print("  ✓ rand(3, 4) works")

def test_randn():
    print("Testing randn...")
    t = tensor.randn(2, 3)
    assert t.shape == (2, 3)
    print("  ✓ randn(2, 3) works")

def test_arange():
    print("Testing arange...")
    t = tensor.arange(10)
    assert t.shape == (10,)
    assert np.array_equal(t.to_numpy(), np.arange(10))
    print("  ✓ arange(10) works")
    
    t2 = tensor.arange(2, 10, 2)
    assert np.array_equal(t2.to_numpy(), np.array([2, 4, 6, 8]))
    print("  ✓ arange(2, 10, 2) works")

def test_linspace():
    print("Testing linspace...")
    t = tensor.linspace(0, 1, 5)
    assert t.shape == (5,)
    expected = np.array([0.0, 0.25, 0.5, 0.75, 1.0], dtype=np.float32)
    assert np.allclose(t.to_numpy(), expected)
    print("  ✓ linspace(0, 1, 5) works")

def test_eye():
    print("Testing eye...")
    t = tensor.eye(3)
    assert t.shape == (3, 3)
    assert np.array_equal(t.to_numpy(), np.eye(3, dtype=np.float32))
    print("  ✓ eye(3) works")

def test_full():
    print("Testing full...")
    t = tensor.full((2, 3), 7.5)
    assert t.shape == (2, 3)
    assert np.all(t.to_numpy() == 7.5)
    print("  ✓ full((2, 3), 7.5) works")

def test_zeros_like():
    print("Testing zeros_like...")
    x = tensor.rand(2, 3)
    t = tensor.zeros_like(x)
    assert t.shape == (2, 3)
    assert np.all(t.to_numpy() == 0)
    print("  ✓ zeros_like works")

def test_ones_like():
    print("Testing ones_like...")
    x = tensor.rand(2, 3)
    t = tensor.ones_like(x)
    assert t.shape == (2, 3)
    assert np.all(t.to_numpy() == 1)
    print("  ✓ ones_like works")

def test_randint():
    print("Testing randint...")
    t = tensor.randint(0, 10, (2, 3))
    assert t.shape == (2, 3)
    assert np.all(t.to_numpy() >= 0) and np.all(t.to_numpy() < 10)
    print("  ✓ randint(0, 10, (2, 3)) works")

def test_diag():
    print("Testing diag...")
    t = tensor.diag([1, 2, 3])
    assert t.shape == (3, 3)
    expected = np.diag([1, 2, 3]).astype(np.float32)
    assert np.array_equal(t.to_numpy(), expected)
    print("  ✓ diag([1, 2, 3]) works")

def test_gradient():
    print("Testing gradient with created tensors...")
    x = tensor.randn(3, 4, requires_grad=True)
    y = tensor.ones(4, 2, requires_grad=True)
    z = x @ y
    loss = z.sum()
    loss.backward()
    assert x.grad is not None
    assert y.grad is not None
    print("  ✓ Gradient computation works with created tensors")

if __name__ == "__main__":
    print("=" * 60)
    print("Testing Tensor Creation Functions")
    print("=" * 60)
    
    test_zeros()
    test_ones()
    test_rand()
    test_randn()
    test_arange()
    test_linspace()
    test_eye()
    test_full()
    test_zeros_like()
    test_ones_like()
    test_randint()
    test_diag()
    test_gradient()
    
    print("\n" + "=" * 60)
    print("✅ All tests passed!")
    print("=" * 60)
