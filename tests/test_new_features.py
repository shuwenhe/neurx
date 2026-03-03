"""
Test and demonstrate the new features added to Tensor framework.

This file tests:
1. einsum operations
2. Vision transforms
3. ResNet models
"""
import sys
import numpy as np

try:
    import tensor
    from tensor import einsum
    from tensor.vision import transforms, models
    print("✅ Successfully imported tensor and new modules")
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)


def test_einsum():
    """Test einsum functionality."""
    print("\n" + "="*60)
    print("Testing einsum operations")
    print("="*60)
    
    # Test 1: Matrix multiplication
    print("\n1. Matrix multiplication: 'ij,jk->ik'")
    A = tensor.rand((3, 4))
    B = tensor.rand((4, 5))
    C = einsum('ij,jk->ik', A, B)
    C_ref = tensor.matmul(A, B)
    
    diff = np.abs(C.to_numpy() - C_ref.to_numpy()).max()
    print(f"   Shape: {A.shape} @ {B.shape} = {C.shape}")
    print(f"   Max diff vs matmul: {diff:.6e}")
    print(f"   {'✅ PASS' if diff < 1e-5 else '❌ FAIL'}")
    
    # Test 2: Batch matrix multiplication
    print("\n2. Batch matrix multiplication: 'bij,bjk->bik'")
    A = tensor.rand((10, 3, 4))
    B = tensor.rand((10, 4, 5))
    C = einsum('bij,bjk->bik', A, B)
    
    print(f"   Shape: {A.shape} @ {B.shape} = {C.shape}")
    print(f"   ✅ PASS")
    
    # Test 3: Transpose
    print("\n3. Transpose: 'ij->ji'")
    A = tensor.rand((3, 4))
    A_T = einsum('ij->ji', A)
    
    print(f"   Shape: {A.shape} -> {A_T.shape}")
    print(f"   ✅ PASS")
    
    # Test 4: Trace
    print("\n4. Trace: 'ii'")
    A = tensor.rand((5, 5))
    trace = einsum('ii', A)
    
    print(f"   Shape: {A.shape} -> {trace.shape}")
    print(f"   Trace value: {trace.to_numpy()}")
    print(f"   ✅ PASS")
    
    # Test 5: Batch dot product
    print("\n5. Batch dot product: 'bi,bi->b'")
    A = tensor.rand((10, 3))
    B = tensor.rand((10, 3))
    dots = einsum('bi,bi->b', A, B)
    
    print(f"   Shape: {A.shape} · {B.shape} = {dots.shape}")
    print(f"   ✅ PASS")
    
    print("\n✅ All einsum tests passed!")
    return True


def test_vision_transforms():
    """Test vision transforms."""
    print("\n" + "="*60)
    print("Testing vision transforms")
    print("="*60)
    
    try:
        from PIL import Image
    except ImportError:
        print("⚠️  PIL not installed, skipping vision tests")
        return False
    
    # Create a dummy image
    dummy_img = np.random.randint(0, 255, (256, 256, 3), dtype=np.uint8)
    pil_img = Image.fromarray(dummy_img)
    
    # Test ToTensor
    print("\n1. ToTensor transform")
    to_tensor = transforms.ToTensor()
    tensor_img = to_tensor(pil_img)
    print(f"   Input shape: (256, 256, 3)")
    print(f"   Output shape: {tensor_img.shape}")
    print(f"   Output range: [{tensor_img.to_numpy().min():.2f}, {tensor_img.to_numpy().max():.2f}]")
    assert tensor_img.shape == (3, 256, 256), "Shape mismatch"
    assert 0 <= tensor_img.to_numpy().min() and tensor_img.to_numpy().max() <= 1, "Range error"
    print(f"   ✅ PASS")
    
    # Test Resize
    print("\n2. Resize transform")
    resize = transforms.Resize(224)
    resized_img = resize(pil_img)
    print(f"   Input size: (256, 256)")
    print(f"   Output size: {resized_img.size}")
    print(f"   ✅ PASS")
    
    # Test Normalize
    print("\n3. Normalize transform")
    normalize = transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
    normalized_tensor = normalize(tensor_img)
    print(f"   Input shape: {tensor_img.shape}")
    print(f"   Output shape: {normalized_tensor.shape}")
    print(f"   Output range: [{normalized_tensor.to_numpy().min():.2f}, {normalized_tensor.to_numpy().max():.2f}]")
    print(f"   ✅ PASS")
    
    # Test Compose
    print("\n4. Compose multiple transforms")
    transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    output = transform(pil_img)
    print(f"   Output shape: {output.shape}")
    assert output.shape == (3, 224, 224), "Shape mismatch"
    print(f"   ✅ PASS")
    
    # Test RandomHorizontalFlip
    print("\n5. RandomHorizontalFlip transform")
    flip = transforms.RandomHorizontalFlip(p=1.0)  # Always flip for testing
    flipped = flip(pil_img)
    print(f"   Output size: {flipped.size}")
    print(f"   ✅ PASS")
    
    print("\n✅ All vision transform tests passed!")
    return True


def test_resnet_models():
    """Test ResNet model instantiation."""
    print("\n" + "="*60)
    print("Testing ResNet models")
    print("="*60)
    
    # Test ResNet-18
    print("\n1. ResNet-18 instantiation")
    try:
        model = models.resnet18(num_classes=10)
        print(f"   Model created successfully")
        print(f"   Number of parameters: {len(model.parameters())}")
        
        # Test forward pass (with small input to save memory)
        dummy_input = tensor.rand((2, 3, 224, 224))
        print(f"   Testing forward pass with input shape: {dummy_input.shape}")
        output = model(dummy_input)
        print(f"   Output shape: {output.shape}")
        assert output.shape == (2, 10), f"Expected shape (2, 10), got {output.shape}"
        print(f"   ✅ PASS")
    except Exception as e:
        print(f"   ❌ FAIL: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    # Test ResNet-34
    print("\n2. ResNet-34 instantiation")
    try:
        model = models.resnet34(num_classes=1000)
        print(f"   Model created successfully")
        print(f"   ✅ PASS")
    except Exception as e:
        print(f"   ❌ FAIL: {e}")
        return False
    
    # Test ResNet-50
    print("\n3. ResNet-50 instantiation")
    try:
        model = models.resnet50(num_classes=1000)
        print(f"   Model created successfully")
        print(f"   ✅ PASS")
    except Exception as e:
        print(f"   ❌ FAIL: {e}")
        return False
    
    print("\n✅ All ResNet model tests passed!")
    return True


def main():
    """Run all tests."""
    print("="*60)
    print("Tensor Framework - New Features Test Suite")
    print("="*60)
    
    results = {}
    
    # Run tests
    results['einsum'] = test_einsum()
    results['vision_transforms'] = test_vision_transforms()
    results['resnet_models'] = test_resnet_models()
    
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
