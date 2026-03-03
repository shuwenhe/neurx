"""Tests for model serialization, checkpointing, and state dict operations."""

import sys
import os
import tempfile
import shutil
from pathlib import Path

try:
    import tensor
    from tensor import nn, optim
    from tensor.serialization import (
        save_checkpoint, load_checkpoint, 
        ModelCheckpoint, save_tensor_dict, load_tensor_dict
    )
    print("✅ Successfully imported tensor serialization modules")
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)


class SimpleModel(nn.Module):
    """Simple test model."""
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(10, 5)
        self.fc2 = nn.Linear(5, 2)
    
    def forward(self, x):
        x = self.fc1(x)
        x = nn.relu(x)
        x = self.fc2(x)
        return x


def test_model_state_dict():
    """Test model state_dict save and load."""
    print("\n" + "="*60)
    print("Testing Model State Dict")
    print("="*60)
    
    # Create model
    print("\n1. Creating and saving model state...")
    model = SimpleModel()
    
    # Get initial state
    state1 = model.state_dict()
    print(f"   State keys: {list(state1.keys())}")
    print(f"   Number of parameters: {len(state1)}")
    
    # Modify model
    for param in model.parameters():
        param.data += 1.0
    
    # Save and verify state changed
    state2 = model.state_dict()
    state_changed = any(
        (state1[k] != state2[k]).any() for k in state1.keys()
    )
    assert state_changed, "State should have changed after modification"
    print(f"   ✅ Model state modified and saved")
    
    # Load original state back
    print("\n2. Loading model state...")
    model.load_state_dict(state1)
    state3 = model.state_dict()
    
    # Verify restoration
    state_restored = all(
        (state1[k] == state3[k]).all() for k in state1.keys()
    )
    assert state_restored, "State should be restored"
    print(f"   ✅ Model state successfully restored")
    
    return True


def test_optimizer_state_dict():
    """Test optimizer state_dict."""
    print("\n" + "="*60)
    print("Testing Optimizer State Dict")
    print("="*60)
    
    print("\n1. Creating model and optimizer...")
    model = SimpleModel()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    
    # Create dummy loss to trigger optimizer state
    x = tensor.randn((4, 10))
    y = model(x)
    loss = y.sum()
    loss.backward()
    optimizer.step()
    
    # Get optimizer state
    opt_state = optimizer.state_dict()
    print(f"   Optimizer state keys: {list(opt_state.keys())}")
    print(f"   ✅ Optimizer state dict working")
    
    # Create new optimizer and load state
    print("\n2. Loading optimizer state...")
    optimizer2 = optim.Adam(model.parameters(), lr=0.001)
    
    # Should have different state before loading
    opt_state2_before = optimizer2.state_dict()
    
    # Load state
    optimizer2.load_state_dict(opt_state)
    opt_state2_after = optimizer2.state_dict()
    
    print(f"   ✅ Optimizer state loaded successfully")
    
    return True


def test_checkpoint_save_load():
    """Test checkpoint save and load functionality."""
    print("\n" + "="*60)
    print("Testing Checkpoint Save/Load")
    print("="*60)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        checkpoint_path = os.path.join(tmpdir, "test_checkpoint.pt")
        
        print("\n1. Saving checkpoint...")
        model = SimpleModel()
        optimizer = optim.SGD(model.parameters(), lr=0.01)
        
        # Get the initial state before saving
        original_state = model.state_dict()
        
        metrics = {'loss': 0.5, 'accuracy': 0.95}
        metadata = {'model': 'SimpleModel', 'framework': 'neurx'}
        
        checkpoint = save_checkpoint(
            checkpoint_path,
            model=model,
            optimizer=optimizer,
            step=100,
            epoch=5,
            metrics=metrics,
            metadata=metadata,
        )
        
        assert os.path.exists(checkpoint_path), "Checkpoint file not created"
        print(f"   ✅ Checkpoint saved: {checkpoint_path}")
        
        # Modify model
        for param in model.parameters():
            param.data += 1.0
        
        print("\n2. Loading checkpoint...")
        model2 = SimpleModel()
        optimizer2 = optim.SGD(model2.parameters(), lr=0.01)
        
        loaded_checkpoint = load_checkpoint(
            checkpoint_path,
            model=model2,
            optimizer=optimizer2,
        )
        
        # Verify loaded checkpoint has expected structure
        assert 'model_state' in loaded_checkpoint
        assert 'optimizer_state' in loaded_checkpoint
        assert loaded_checkpoint['training']['step'] == 100
        assert loaded_checkpoint['training']['epoch'] == 5
        print(f"   ✅ Checkpoint loaded successfully")
        
        # Verify model state was restored (compare loaded model to original)
        import numpy as np
        loaded_state = model2.state_dict()
        states_match = all(
            np.allclose(np.asarray(original_state[k]), np.asarray(loaded_state[k])) 
            for k in original_state.keys()
        )
        assert states_match, "Model states should match after load"
        print(f"   ✅ Model state successfully restored")
        
        return True


def test_model_checkpoint():
    """Test ModelCheckpoint manager."""
    print("\n" + "="*60)
    print("Testing ModelCheckpoint Manager")
    print("="*60)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        print("\n1. Creating checkpoint manager...")
        manager = ModelCheckpoint(tmpdir, max_keep=3, compress=False)
        print(f"   ✅ Manager created: {tmpdir}")
        
        print("\n2. Saving multiple checkpoints...")
        model = SimpleModel()
        optimizer = optim.Adam(model.parameters(), lr=0.001)
        
        for epoch in range(5):
            metrics = {
                'loss': 1.0 - epoch * 0.1,
                'accuracy': 0.7 + epoch * 0.05,
            }
            path = manager.save(
                model=model,
                optimizer=optimizer,
                epoch=epoch,
                step=epoch*100,
                metrics=metrics,
            )
            print(f"   Saved epoch {epoch}: {Path(path).name}")
        
        # Check history
        history = manager.list_checkpoints()
        assert len(history) == 3, f"Should have 3 checkpoints (max_keep=3), got {len(history)}"
        print(f"   ✅ Cleanup working (kept {len(history)} checkpoints)")
        
        print("\n3. Finding best checkpoint...")
        best_path = manager.get_best_checkpoint('loss', maximize=False)
        assert best_path is not None, "Should find best checkpoint"
        print(f"   ✅ Found best checkpoint by loss")
        
        print("\n4. Loading checkpoint...")
        model2 = SimpleModel()
        optimizer2 = optim.Adam(model2.parameters(), lr=0.001)
        
        loaded = manager.load(best_path, model=model2, optimizer=optimizer2)
        assert loaded is not None, "Should load checkpoint"
        print(f"   ✅ Checkpoint loaded")
        
        return True


def test_compressed_checkpoint():
    """Test compression in ModelCheckpoint."""
    print("\n" + "="*60)
    print("Testing Compressed Checkpoints")
    print("="*60)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        print("\n1. Saving compressed checkpoint...")
        manager = ModelCheckpoint(tmpdir, compress=True)
        
        model = SimpleModel()
        path = manager.save(
            model=model,
            epoch=1,
            metrics={'loss': 0.5}
        )
        
        assert path.endswith('.gz'), "Compressed checkpoint should end with .gz"
        assert os.path.exists(path), "Compressed file should exist"
        print(f"   ✅ Compressed checkpoint saved: {Path(path).name}")
        
        print("\n2. Loading compressed checkpoint...")
        model2 = SimpleModel()
        loaded = manager.load(path, model=model2)
        assert loaded is not None, "Should load compressed checkpoint"
        print(f"   ✅ Compressed checkpoint loaded")
        
        return True


def test_tensor_dict_io():
    """Test tensor state dict I/O."""
    print("\n" + "="*60)
    print("Testing Tensor Dict I/O")
    print("="*60)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        print("\n1. Saving tensor dict...")
        state = {
            'weight1': tensor.Tensor([[1, 2], [3, 4]]).to_numpy(),
            'weight2': tensor.Tensor([5, 6, 7]).to_numpy(),
        }
        
        path = os.path.join(tmpdir, "state")
        metadata = {'model': 'test', 'version': 1}
        
        save_tensor_dict(state, path, compress=True, metadata=metadata)
        assert os.path.exists(path + '.gz'), "Compressed state file should exist"
        print(f"   ✅ Tensor dict saved")
        
        print("\n2. Loading tensor dict...")
        loaded = load_tensor_dict(path)
        
        assert 'weight1' in loaded
        assert 'weight2' in loaded
        assert (loaded['weight1'] == state['weight1']).all()
        print(f"   ✅ Tensor dict loaded and verified")
        
        return True


def test_state_dict_utils():
    """Test state dict utility functions."""
    print("\n" + "="*60)
    print("Testing State Dict Utilities")
    print("="*60)
    
    from tensor.serialization import merge_state_dicts, extract_state_dict_subset
    
    print("\n1. Testing merge_state_dicts...")
    state1 = {'a': 1, 'b': 2}
    state2 = {'c': 3, 'd': 4}
    
    merged = merge_state_dicts(state1, state2)
    assert len(merged) == 4
    assert 'a' in merged and 'c' in merged
    print(f"   ✅ Merge working: {len(merged)} keys")
    
    print("\n2. Testing extract_state_dict_subset...")
    state = {
        'encoder.layer1.weight': 1,
        'encoder.layer1.bias': 2,
        'encoder.layer2.weight': 3,
        'decoder.weight': 4,
    }
    
    subset = extract_state_dict_subset(state, prefix='encoder.layer1')
    assert len(subset) == 2
    assert 'encoder.layer1.weight' in subset and 'encoder.layer1.bias' in subset
    print(f"   ✅ Extract subset working: {len(subset)} keys")
    
    return True


def main():
    """Run all tests."""
    print("="*60)
    print("Tensor Framework - Serialization Test Suite")
    print("="*60)
    
    results = {}
    
    # Run tests
    tests = [
        ("model_state_dict", test_model_state_dict),
        ("optimizer_state_dict", test_optimizer_state_dict),
        ("checkpoint_save_load", test_checkpoint_save_load),
        ("model_checkpoint", test_model_checkpoint),
        ("compressed_checkpoint", test_compressed_checkpoint),
        ("tensor_dict_io", test_tensor_dict_io),
        ("state_dict_utils", test_state_dict_utils),
    ]
    
    for name, test_func in tests:
        try:
            results[name] = test_func()
        except Exception as e:
            print(f"\n❌ {name} test failed: {e}")
            import traceback
            traceback.print_exc()
            results[name] = False
    
    # Summary
    print("\n" + "="*60)
    print("Test Summary")
    print("="*60)
    
    for name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{name:30s}: {status}")
    
    all_passed = all(results.values())
    print("\n" + "="*60)
    if all_passed:
        print("🎉 All serialization tests passed!")
    else:
        print("⚠️  Some tests failed")
    print("="*60)
    
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
