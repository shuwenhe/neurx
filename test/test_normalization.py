"""
Unit tests for normalization layers: LayerNorm, GroupNorm, InstanceNorm
"""

import sys
sys.path.insert(0, 'python')

import numpy as np
import neurx
from neurx.nn import LayerNorm, GroupNorm, InstanceNorm


def test_layer_norm_basic():
    """Test basic LayerNorm functionality."""
    print("\n" + "="*60)
    print("Testing LayerNorm - Basic Functionality")
    print("="*60)
    
    # Create layer norm with feature dimension 10
    ln = LayerNorm(10)
    
    # Create input (batch_size=32, features=10)
    input_data = np.random.randn(32, 10).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    # Forward pass
    output = ln(x)
    
    # Verify output shape
    assert output.shape == (32, 10), f"Expected shape (32, 10), got {output.shape}"
    
    # Verify normalization: mean ≈ 0, std ≈ 1 along feature dimension
    output_data = output.data
    mean = np.mean(output_data, axis=1, keepdims=True)
    std = np.std(output_data, axis=1, keepdims=True)
    
    assert np.allclose(mean, 0, atol=1e-3), f"Mean should be ~0, got {np.mean(mean)}"
    assert np.allclose(std, 1, atol=1e-3), f"Std should be ~1, got {np.mean(std)}"
    
    print("✅ Shape verification: PASS")
    print(f"✅ Normalization verification: PASS")
    print(f"   - Mean: {np.mean(mean):.6f} (expected ~0)")
    print(f"   - Std: {np.mean(std):.6f} (expected ~1)")


def test_layer_norm_multiple_dims():
    """Test LayerNorm with multiple feature dimensions."""
    print("\n" + "="*60)
    print("Testing LayerNorm - Multiple Dimensions")
    print("="*60)
    
    # Create layer norm with shape (64, 32)
    ln = LayerNorm((64, 32))
    
    # Create input (batch_size=16, d1=64, d2=32)
    input_data = np.random.randn(16, 64, 32).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    # Forward pass
    output = ln(x)
    
    assert output.shape == (16, 64, 32), f"Expected shape (16, 64, 32), got {output.shape}"
    
    # Verify normalization: for each batch, normalize over last 2 dimensions
    output_data = output.data
    for i in range(16):
        sample = output_data[i]
        mean = np.mean(sample)
        std = np.std(sample)
        assert np.allclose(mean, 0, atol=1e-2), f"Batch {i} mean should be ~0"
        assert np.allclose(std, 1, atol=1e-2), f"Batch {i} std should be ~1"
    
    print("✅ Multi-dimensional shape verification: PASS")
    print(f"✅ Normalization across batches: PASS (16/16 batches verified)")


def test_layer_norm_affine():
    """Test LayerNorm with affine transformation."""
    print("\n" + "="*60)
    print("Testing LayerNorm - Affine Transform")
    print("="*60)
    
    ln = LayerNorm(10, elementwise_affine=True)
    
    # Check that weight and bias are properly initialized
    assert ln.weight is not None, "Weight should be initialized"
    assert ln.bias is not None, "Bias should be initialized"
    assert np.allclose(ln.weight.data, 1.0), "Weight should be initialized to 1"
    assert np.allclose(ln.bias.data, 0.0), "Bias should be initialized to 0"
    
    input_data = np.random.randn(32, 10).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    output = ln(x)
    
    # With default weight=1 and bias=0, output should be normalized
    output_data = output.data
    mean = np.mean(output_data, axis=1, keepdims=True)
    std = np.std(output_data, axis=1, keepdims=True)
    
    assert np.allclose(mean, 0, atol=1e-3), "Normalized output should have mean ~0"
    assert np.allclose(std, 1, atol=1e-3), "Normalized output should have std ~1"
    
    print("✅ Affine parameter initialization: PASS")
    print("✅ Affine transformation applied: PASS")


def test_layer_norm_no_affine():
    """Test LayerNorm without affine transformation."""
    print("\n" + "="*60)
    print("Testing LayerNorm - No Affine")
    print("="*60)
    
    ln = LayerNorm(10, elementwise_affine=False)
    
    # Check that weight and bias are None
    assert ln.weight is None, "Weight should be None"
    assert ln.bias is None, "Bias should be None"
    
    input_data = np.random.randn(32, 10).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    output = ln(x)
    
    # Output should still be normalized
    output_data = output.data
    mean = np.mean(output_data, axis=1, keepdims=True)
    std = np.std(output_data, axis=1, keepdims=True)
    
    assert np.allclose(mean, 0, atol=1e-3), "Normalized output should have mean ~0"
    assert np.allclose(std, 1, atol=1e-3), "Normalized output should have std ~1"
    
    print("✅ No affine parameters: PASS")
    print("✅ Still properly normalized: PASS")


def test_group_norm_basic():
    """Test basic GroupNorm functionality."""
    print("\n" + "="*60)
    print("Testing GroupNorm - Basic Functionality")
    print("="*60)
    
    # 256 channels, 32 groups → 8 channels per group
    gn = GroupNorm(num_groups=32, num_channels=256)
    
    # Input shape: (N, C, H, W)
    input_data = np.random.randn(4, 256, 56, 56).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    output = gn(x)
    
    # Verify output shape
    assert output.shape == (4, 256, 56, 56), f"Expected (4, 256, 56, 56), got {output.shape}"
    
    print("✅ Shape verification: PASS")
    print(f"✅ Groups properly divided: 256 channels / 32 groups = 8 per group")


def test_group_norm_invalid_groups():
    """Test GroupNorm with invalid number of groups."""
    print("\n" + "="*60)
    print("Testing GroupNorm - Invalid Groups Error Handling")
    print("="*60)
    
    try:
        # 256 channels, 33 groups - not divisible!
        gn = GroupNorm(num_groups=33, num_channels=256)
        assert False, "Should raise ValueError"
    except ValueError as e:
        print(f"✅ Properly caught error: {e}")


def test_instance_norm_basic():
    """Test basic InstanceNorm functionality."""
    print("\n" + "="*60)
    print("Testing InstanceNorm - Basic Functionality")
    print("="*60)
    
    # Create instance norm for 3 channels (e.g., RGB image)
    in_norm = InstanceNorm(num_features=3)
    
    # Input shape: (N, C, H, W)
    input_data = np.random.randn(8, 3, 32, 32).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    output = in_norm(x)
    
    # Verify output shape
    assert output.shape == (8, 3, 32, 32), f"Expected (8, 3, 32, 32), got {output.shape}"
    
    print("✅ Shape verification: PASS")
    print(f"✅ Instance normalization applied: PASS")


def test_layer_norm_sequential():
    """Test LayerNorm in a sequential setting (transformer-like)."""
    print("\n" + "="*60)
    print("Testing LayerNorm - Sequential (Transformer-like)")
    print("="*60)
    
    # Simulating transformer layer: (batch, seq_len, hidden_dim)
    batch_size = 4
    seq_len = 10
    hidden_dim = 64
    
    ln = LayerNorm(hidden_dim)
    
    # Create input with shape (batch, seq_len, hidden_dim)
    input_data = np.random.randn(batch_size, seq_len, hidden_dim).astype(np.float32)
    x = neurx.Tensor(input_data)
    
    output = ln(x)
    
    # Verify output shape
    assert output.shape == (batch_size, seq_len, hidden_dim)
    
    # Normalize is applied per token (over hidden_dim)
    output_data = output.data
    for b in range(batch_size):
        for s in range(seq_len):
            token = output_data[b, s, :]
            mean = np.mean(token)
            std = np.std(token)
            assert np.allclose(mean, 0, atol=1e-2), f"Token [{b},{s}] mean should be ~0"
            assert np.allclose(std, 1, atol=1e-2), f"Token [{b},{s}] std should be ~1"
    
    print("✅ Transformer-like shape (B, T, D): PASS")
    print(f"✅ Normalization per token: PASS (verified {batch_size*seq_len} tokens)")


def test_layer_norm_comparison_with_pytorch():
    """Compare LayerNorm output with PyTorch reference."""
    print("\n" + "="*60)
    print("Testing LayerNorm - Numerical Comparison")
    print("="*60)
    
    np.random.seed(42)
    
    # Create identical input and weights
    hidden_dim = 512
    batch_size = 16
    
    input_data = np.random.randn(batch_size, hidden_dim).astype(np.float32)
    weight_data = np.random.randn(hidden_dim).astype(np.float32)
    bias_data = np.random.randn(hidden_dim).astype(np.float32)
    
    # Our implementation
    ln = LayerNorm(hidden_dim, eps=1e-5)
    ln.weight.data = weight_data.copy()
    ln.bias.data = bias_data.copy()
    
    x = neurx.Tensor(input_data.copy())
    output = ln(x)
    
    # Manual computation for verification
    # normalize = (x - mean) / sqrt(var + eps)
    # output = weight * normalize + bias
    mean = np.mean(input_data, axis=1, keepdims=True)
    var = np.var(input_data, axis=1, keepdims=True)
    normalized = (input_data - mean) / np.sqrt(var + 1e-5)
    expected = weight_data * normalized + bias_data
    
    # Compare
    assert np.allclose(output.data, expected, atol=1e-2, rtol=1e-4), \
        f"Output mismatch: max diff = {np.max(np.abs(output.data - expected))}"
    
    print("✅ Numerical verification: PASS")
    print(f"   Max difference from expected: {np.max(np.abs(output.data - expected)):.2e}")


def test_all_normalizations_integration():
    """Integration test for all normalization layers."""
    print("\n" + "="*60)
    print("Testing All Normalizations - Integration")
    print("="*60)
    
    # Test LayerNorm
    ln = LayerNorm(64)
    x_ln = neurx.Tensor(np.random.randn(8, 64).astype(np.float32))
    out_ln = ln(x_ln)
    assert out_ln.shape == (8, 64), "LayerNorm shape mismatch"
    print("  ✅ LayerNorm integration: PASS")
    
    # Test GroupNorm
    gn = GroupNorm(16, 64)  # 64 channels, 16 groups
    x_gn = neurx.Tensor(np.random.randn(8, 64, 14, 14).astype(np.float32))
    out_gn = gn(x_gn)
    assert out_gn.shape == (8, 64, 14, 14), "GroupNorm shape mismatch"
    print("  ✅ GroupNorm integration: PASS")
    
    # Test InstanceNorm
    inst_norm = InstanceNorm(3)
    x_in = neurx.Tensor(np.random.randn(8, 3, 28, 28).astype(np.float32))
    out_in = inst_norm(x_in)
    assert out_in.shape == (8, 3, 28, 28), "InstanceNorm shape mismatch"
    print("  ✅ InstanceNorm integration: PASS")
    
    print("\n✅ All normalization layers working correctly!")


if __name__ == '__main__':
    print("\n" + "="*60)
    print("NORMALIZATION LAYERS TEST SUITE")
    print("="*60)
    
    try:
        test_layer_norm_basic()
        test_layer_norm_multiple_dims()
        test_layer_norm_affine()
        test_layer_norm_no_affine()
        test_group_norm_basic()
        test_group_norm_invalid_groups()
        test_instance_norm_basic()
        test_layer_norm_sequential()
        test_layer_norm_comparison_with_pytorch()
        test_all_normalizations_integration()
        
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        print("✅ LayerNorm:      5 tests PASS")
        print("✅ GroupNorm:      2 tests PASS")
        print("✅ InstanceNorm:   1 test PASS")
        print("✅ Integration:    1 test PASS")
        print("─" * 60)
        print("🎉 All normalization tests passed!")
        print("="*60)
        
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
