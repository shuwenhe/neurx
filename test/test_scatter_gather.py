"""Test scatter, gather, scatter_add, and meshgrid operations."""
import sys
import numpy as np

try:
    import neurx
    print("✅ Successfully imported neurx")
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)


def test_gather():
    """Test gather operation."""
    print("\n" + "="*60)
    print("Testing gather operation")
    print("="*60)
    
    # Test 1: Basic gather
    print("\n1. Basic gather along dimension 1")
    t = neurx.Tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]], requires_grad=True)
    index = neurx.Tensor(np.array([[0, 2], [1, 0], [2, 1]], dtype=np.int64))
    result = t.gather(1, index)
    
    print(f"   Input shape: {t.shape}")
    print(f"   Index shape: {index.shape}")
    print(f"   Output shape: {result.shape}")
    print(f"   Expected: [[1, 3], [5, 4], [9, 8]]")
    print(f"   Got: {result.to_numpy()}")
    
    expected = np.array([[1, 3], [5, 4], [9, 8]], dtype=np.float64)
    assert np.allclose(result.to_numpy(), expected), "gather result mismatch"
    print(f"   ✅ PASS")
    
    # Test 2: Gather with backward
    print("\n2. Gather backward pass")
    loss = result.sum()
    loss.backward()
    print(f"   Gradient shape: {t.grad.shape}")
    print(f"   Gradient:\n{t.grad}")
    assert t.grad is not None, "gradient not computed"
    print(f"   ✅ PASS")
    
    return None


def test_scatter():
    """Test scatter operation."""
    print("\n" + "="*60)
    print("Testing scatter operation")
    print("="*60)
    
    # Test 1: Basic scatter
    print("\n1. Basic scatter along dimension 1")
    t = neurx.zeros((3, 5))
    index = neurx.Tensor(np.array([[0, 2], [1, 3], [0, 4]], dtype=np.int64))
    src = neurx.ones((3, 2))
    result = t.scatter(1, index, src)
    
    print(f"   Input shape: {t.shape}")
    print(f"   Index shape: {index.shape}")
    print(f"   Source shape: {src.shape}")
    print(f"   Output shape: {result.shape}")
    print(f"   Result:\n{result.to_numpy()}")
    
    # Check that values are scattered correctly
    assert result.to_numpy()[0, 0] == 1.0, "scatter failed at [0, 0]"
    assert result.to_numpy()[0, 2] == 1.0, "scatter failed at [0, 2]"
    assert result.to_numpy()[1, 1] == 1.0, "scatter failed at [1, 1]"
    print(f"   ✅ PASS")
    
    return None


def test_scatter_add():
    """Test scatter_add operation."""
    print("\n" + "="*60)
    print("Testing scatter_add operation")
    print("="*60)
    
    # Test 1: Basic scatter_add
    print("\n1. Basic scatter_add along dimension 1")
    t = neurx.ones((3, 5))
    index = neurx.Tensor(np.array([[0, 2], [1, 3], [0, 4]], dtype=np.int64))
    src = neurx.ones((3, 2)) * 2
    result = t.scatter_add(1, index, src)
    
    print(f"   Input shape: {t.shape}")
    print(f"   Index shape: {index.shape}")
    print(f"   Source shape: {src.shape}")
    print(f"   Output shape: {result.shape}")
    print(f"   Result:\n{result.to_numpy()}")
    
    # Check that values are added correctly
    assert result.to_numpy()[0, 0] == 3.0, f"scatter_add failed at [0, 0]: expected 3.0, got {result.to_numpy()[0, 0]}"
    assert result.to_numpy()[0, 1] == 1.0, f"scatter_add failed at [0, 1]: expected 1.0, got {result.to_numpy()[0, 1]}"
    assert result.to_numpy()[0, 2] == 3.0, f"scatter_add failed at [0, 2]: expected 3.0, got {result.to_numpy()[0, 2]}"
    print(f"   ✅ PASS")
    
    # Test 2: scatter_add with gradients
    print("\n2. scatter_add backward pass")
    t_grad = neurx.Tensor([[1, 2, 3, 4, 5], [6, 7, 8, 9, 10], [11, 12, 13, 14, 15]], requires_grad=True)
    src_grad = neurx.Tensor([[1, 1], [1, 1], [1, 1]], requires_grad=True)
    result_grad = t_grad.scatter_add(1, index, src_grad)
    loss = result_grad.sum()
    loss.backward()
    
    assert t_grad.grad is not None, "gradient not computed for t"
    assert src_grad.grad is not None, "gradient not computed for src"
    print(f"   Input gradient shape: {t_grad.grad.shape}")
    print(f"   Source gradient shape: {src_grad.grad.shape}")
    print(f"   ✅ PASS")
    
    return None


def test_meshgrid():
    """Test meshgrid operation."""
    print("\n" + "="*60)
    print("Testing meshgrid operation")
    print("="*60)
    
    # Test 1: 2D meshgrid with 'xy' indexing
    print("\n1. 2D meshgrid with 'xy' indexing")
    x = neurx.arange(3)
    y = neurx.arange(4)
    X, Y = neurx.meshgrid(x, y, indexing='xy')
    
    print(f"   x shape: {x.shape}")
    print(f"   y shape: {y.shape}")
    print(f"   X shape: {X.shape}")
    print(f"   Y shape: {Y.shape}")
    print(f"   X:\n{X.to_numpy()}")
    print(f"   Y:\n{Y.to_numpy()}")
    
    # With 'xy' indexing, X should have shape (len(y), len(x))
    assert X.shape == (4, 3), f"X shape mismatch: expected (4, 3), got {X.shape}"
    assert Y.shape == (4, 3), f"Y shape mismatch: expected (4, 3), got {Y.shape}"
    
    # Check values
    expected_X = np.array([[0, 1, 2], [0, 1, 2], [0, 1, 2], [0, 1, 2]])
    expected_Y = np.array([[0, 0, 0], [1, 1, 1], [2, 2, 2], [3, 3, 3]])
    
    assert np.allclose(X.to_numpy(), expected_X), "X values mismatch"
    assert np.allclose(Y.to_numpy(), expected_Y), "Y values mismatch"
    print(f"   ✅ PASS")
    
    # Test 2: 2D meshgrid with 'ij' indexing
    print("\n2. 2D meshgrid with 'ij' indexing")
    X_ij, Y_ij = neurx.meshgrid(x, y, indexing='ij')
    
    print(f"   X_ij shape: {X_ij.shape}")
    print(f"   Y_ij shape: {Y_ij.shape}")
    print(f"   X_ij:\n{X_ij.to_numpy()}")
    print(f"   Y_ij:\n{Y_ij.to_numpy()}")
    
    # With 'ij' indexing, shapes should match input order
    assert X_ij.shape == (3, 4), f"X_ij shape mismatch: expected (3, 4), got {X_ij.shape}"
    assert Y_ij.shape == (3, 4), f"Y_ij shape mismatch: expected (3, 4), got {Y_ij.shape}"
    
    expected_X_ij = np.array([[0, 0, 0, 0], [1, 1, 1, 1], [2, 2, 2, 2]])
    expected_Y_ij = np.array([[0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3]])
    
    assert np.allclose(X_ij.to_numpy(), expected_X_ij), "X_ij values mismatch"
    assert np.allclose(Y_ij.to_numpy(), expected_Y_ij), "Y_ij values mismatch"
    print(f"   ✅ PASS")
    
    # Test 3: 3D meshgrid
    print("\n3. 3D meshgrid")
    x = neurx.arange(2)
    y = neurx.arange(3)
    z = neurx.arange(4)
    X, Y, Z = neurx.meshgrid(x, y, z, indexing='xy')
    
    print(f"   X shape: {X.shape}")
    print(f"   Y shape: {Y.shape}")
    print(f"   Z shape: {Z.shape}")
    
    # With 'xy' indexing, first two dims are swapped
    assert X.shape == (3, 2, 4), f"X shape mismatch: expected (3, 2, 4), got {X.shape}"
    assert Y.shape == (3, 2, 4), f"Y shape mismatch"
    assert Z.shape == (3, 2, 4), f"Z shape mismatch"
    print(f"   ✅ PASS")
    
    return None


def test_use_cases():
    """Test practical use cases."""
    print("\n" + "="*60)
    print("Testing practical use cases")
    print("="*60)
    
    # Use case 1: Attention mechanism with gather
    print("\n1. Attention mechanism - selecting top-k values")
    scores = neurx.rand((2, 8, 10))  # (batch, heads, seq_len)
    topk_indices = neurx.Tensor(np.array([[[0, 5, 9]] * 8] * 2, dtype=np.int64))  # Top-3 indices
    topk_scores = scores.gather(2, topk_indices)
    print(f"   Scores shape: {scores.shape}")
    print(f"   Top-k indices shape: {topk_indices.shape}")
    print(f"   Top-k scores shape: {topk_scores.shape}")
    assert topk_scores.shape == (2, 8, 3), "Shape mismatch"
    print(f"   ✅ PASS")
    
    # Use case 2: Coordinate grid for spatial transformations
    print("\n2. Creating coordinate grid for image processing")
    H, W = 224, 224
    y = neurx.linspace(0, 1, H)
    x = neurx.linspace(0, 1, W)
    grid_y, grid_x = neurx.meshgrid(y, x, indexing='ij')
    print(f"   Image size: {H}x{W}")
    print(f"   Grid Y shape: {grid_y.shape}")
    print(f"   Grid X shape: {grid_x.shape}")
    assert grid_y.shape == (H, W), "Grid shape mismatch"
    print(f"   ✅ PASS")
    
    # Use case 3: Scatter for embedding updates
    print("\n3. Embedding table update with scatter_add")
    vocab_size = 1000
    embed_dim = 128
    embedding_table = neurx.zeros((vocab_size, embed_dim))
    
    # Update embeddings for specific tokens
    token_ids = neurx.Tensor(np.array([[10, 20, 30]], dtype=np.int64).T)  # Shape: (3, 1)
    updates = neurx.randn((3, embed_dim))
    
    # This would need proper indexing, but demonstrates the concept
    print(f"   Embedding table shape: {embedding_table.shape}")
    print(f"   Token IDs shape: {token_ids.shape}")
    print(f"   Updates shape: {updates.shape}")
    print(f"   ✅ Concept demonstrated")
    
    return None


def main():
    """Run all tests."""
    print("="*60)
    print("Tensor Framework - Scatter/Gather/Meshgrid Test Suite")
    print("="*60)
    
    results = {}
    
    # Run tests
    try:
        test_gather()
        results['gather'] = True
    except Exception as e:
        print(f"\n❌ Gather test failed: {e}")
        import traceback
        traceback.print_exc()
        results['gather'] = False
    
    try:
        test_scatter()
        results['scatter'] = True
    except Exception as e:
        print(f"\n❌ Scatter test failed: {e}")
        import traceback
        traceback.print_exc()
        results['scatter'] = False
    
    try:
        test_scatter_add()
        results['scatter_add'] = True
    except Exception as e:
        print(f"\n❌ Scatter_add test failed: {e}")
        import traceback
        traceback.print_exc()
        results['scatter_add'] = False
    
    try:
        test_meshgrid()
        results['meshgrid'] = True
    except Exception as e:
        print(f"\n❌ Meshgrid test failed: {e}")
        import traceback
        traceback.print_exc()
        results['meshgrid'] = False
    
    try:
        test_use_cases()
        results['use_cases'] = True
    except Exception as e:
        print(f"\n❌ Use cases test failed: {e}")
        import traceback
        traceback.print_exc()
        results['use_cases'] = False
    
    # Summary
    print("\n" + "="*60)
    print("Test Summary")
    print("="*60)
    
    for name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{name:20s}: {status}")
    
    all_passed = all(results.values())
    print("\n" + "="*60)
    if all_passed:
        print("🎉 All tests passed!")
    else:
        print("⚠️  Some tests failed")
    print("="*60)
    
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
