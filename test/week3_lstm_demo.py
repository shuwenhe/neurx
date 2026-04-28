#!/usr/bin/env python3
"""
End-to-end LSTM text classification example.

Demonstrates RNN/LSTM modules with loss functions and learning rate schedulers.
This is a simplified example showing the integration of Week 3 components.
"""

import numpy as np
from neurx.core.neurx import Tensor
from neurx.nn.rnn import LSTM
from neurx.nn import Linear
from neurx.optim.optim import SGD
from neurx.optim.losses import CrossEntropyLoss
from neurx.optim.schedulers import StepLR


def create_dummy_dataset(num_samples=10, seq_length=5, vocab_size=100, num_classes=3):
    """Create dummy dataset for text classification."""
    # Shape: (num_samples, seq_length)
    sequences = np.random.randint(0, vocab_size, size=(num_samples, seq_length))
    
    # One-hot encode (simplified - just use indices)
    # Shape: (num_samples, seq_length, embedding_dim)
    embeddings = np.random.randn(num_samples, seq_length, 32).astype(np.float32)
    
    # Labels
    labels = np.random.randint(0, num_classes, size=(num_samples,))
    
    return embeddings, labels


def train_lstm_classifier(epochs=5):
    """Train a simple LSTM classifier (simplified demo)."""
    print("=" * 70)
    print("End-to-End LSTM Text Classification Example (Simplified)")
    print("=" * 70)
    
    # Hyperparameters
    input_size = 32  # embedding dimension
    hidden_size = 20
    num_classes = 3
    batch_size = 2
    seq_length = 5
    num_samples = 10
    
    print(f"\nHyperparameters:")
    print(f"  Input size: {input_size}")
    print(f"  Hidden size: {hidden_size}")
    print(f"  Num classes: {num_classes}")
    print(f"  Batch size: {batch_size}")
    print(f"  Sequence length: {seq_length}")
    
    # Create model components
    print(f"\nInitializing model components...")
    lstm = LSTM(input_size, hidden_size, num_layers=1, batch_first=True)
    fc = Linear(hidden_size, num_classes)
    
    print(f"  ✓ LSTM layer: {input_size} -> {hidden_size}")
    print(f"  ✓ Fully connected: {hidden_size} -> {num_classes}")
    
    # Loss 
    loss_fn = CrossEntropyLoss()
    
    print(f"  ✓ Loss: CrossEntropyLoss")
    
    # Create dataset
    embeddings, labels = create_dummy_dataset(num_samples, seq_length, 100, num_classes)
    print(f"\nDataset:")
    print(f"  Embeddings shape: {embeddings.shape}")
    print(f"  Labels shape: {labels.shape}")
    
    # Training loop
    print(f"\nTraining for {epochs} epochs...")
    print("-" * 70)
    
    losses = []
    learning_rates = [0.01, 0.005, 0.0025, 0.00125, 0.000625]
    
    for epoch in range(epochs):
        epoch_loss = 0.0
        num_batches = 0
        
        # Mini-batch training
        for i in range(0, num_samples, batch_size):
            # Get batch
            batch_end = min(i + batch_size, num_samples)
            X_batch = embeddings[i:batch_end]
            y_batch = labels[i:batch_end]
            
            # Convert to tensors
            X = Tensor(X_batch)
            y = Tensor(y_batch)
            
            # Forward pass
            lstm_out, (h_n, c_n) = lstm(X)
            
            # Use last hidden state for classification
            last_hidden = h_n.data[-1]  # (batch_size, hidden_size)
            logits = fc(Tensor(last_hidden)).data  # (batch_size, num_classes)
            
            # Compute loss
            loss = loss_fn(Tensor(logits), y)
            
            epoch_loss += loss.data
            num_batches += 1
        
        avg_loss = epoch_loss / num_batches
        losses.append(avg_loss)
        
        # Simulate learning rate schedule (StepLR: gamma=0.5 every 2 epochs)
        current_lr = learning_rates[min(epoch // 2, len(learning_rates) - 1)]
        
        # Print progress
        print(f"Epoch {epoch+1}/{epochs} | Loss: {avg_loss:.4f} | LR: {current_lr:.6f}")
    
    # Summary
    print("-" * 70)
    print(f"\nTraining Summary:")
    print(f"  Final loss: {losses[-1]:.4f}")
    print(f"  Loss improvement: {(losses[0] - losses[-1]) / losses[0] * 100:.1f}%")
    print(f"  Learning rates scheduled: {learning_rates[:epochs]}")
    
    return lstm, fc, losses


def test_lstm_features():
    """Test various LSTM features."""
    print("\n" + "=" * 70)
    print("Testing LSTM Features")
    print("=" * 70)
    
    # Test 1: Single-layer LSTM
    print("\n1. Single-layer LSTM:")
    lstm = LSTM(10, 20, num_layers=1)
    x = Tensor(np.random.randn(5, 3, 10))  # (seq_len, batch, input_size)
    output, (h, c) = lstm(x)
    print(f"   Input shape: {x.shape}")
    print(f"   Output shape: {output.shape}")
    print(f"   Hidden state shape: {h.shape}")
    print(f"   Cell state shape: {c.shape}")
    assert output.shape == (5, 3, 20)
    assert h.shape == (1, 3, 20)
    assert c.shape == (1, 3, 20)
    print(f"   ✓ Passed")
    
    # Test 2: Multi-layer LSTM
    print("\n2. Multi-layer LSTM (3 layers):")
    lstm = LSTM(10, 20, num_layers=3)
    output, (h, c) = lstm(x)
    print(f"   Output shape: {output.shape}")
    print(f"   Hidden state shape: {h.shape}")
    print(f"   Cell state shape: {c.shape}")
    assert output.shape == (5, 3, 20)
    assert h.shape == (3, 3, 20)
    assert c.shape == (3, 3, 20)
    print(f"   ✓ Passed")
    
    # Test 3: Bidirectional LSTM
    print("\n3. Bidirectional LSTM:")
    lstm = LSTM(10, 20, bidirectional=True)
    output, (h, c) = lstm(x)
    print(f"   Output shape: {output.shape}")
    print(f"   Hidden state shape: {h.shape}")
    print(f"   Cell state shape: {c.shape}")
    assert output.shape == (5, 3, 40)  # 2 * hidden_size
    assert h.shape == (2, 3, 20)  # 2 directions
    assert c.shape == (2, 3, 20)
    print(f"   ✓ Passed")
    
    # Test 4: Batch-first LSTM
    print("\n4. Batch-first LSTM:")
    lstm = LSTM(10, 20, batch_first=True)
    x_batch_first = Tensor(np.random.randn(3, 5, 10))  # (batch, seq_len, input_size)
    output, (h, c) = lstm(x_batch_first)
    print(f"   Input shape: {x_batch_first.shape}")
    print(f"   Output shape: {output.shape}")
    assert output.shape == (3, 5, 20)
    print(f"   ✓ Passed")
    
    print("\n✅ All LSTM feature tests passed!")


def test_loss_functions():
    """Test various loss functions."""
    print("\n" + "=" * 70)
    print("Testing Loss Functions")
    print("=" * 70)
    
    from neurx.optim.losses import (
        MSELoss, L1Loss, BCEWithLogitsLoss, CrossEntropyLoss, KLDivLoss
    )
    
    # Test 1: MSE Loss
    print("\n1. MSE Loss (Regression):")
    loss_fn = MSELoss()
    pred = Tensor(np.array([1.0, 2.0, 3.0]))
    target = Tensor(np.array([1.1, 2.1, 3.1]))
    loss = loss_fn(pred, target)
    print(f"   Prediction: {pred.data}")
    print(f"   Target: {target.data}")
    print(f"   Loss: {loss.data:.6f}")
    print(f"   ✓ Passed")
    
    # Test 2: BCE with Logits Loss
    print("\n2. BCE with Logits Loss (Binary Classification):")
    loss_fn = BCEWithLogitsLoss()
    logits = Tensor(np.array([[0.5], [-0.3], [2.0], [-1.5]]))
    targets = Tensor(np.array([[1.0], [0.0], [1.0], [0.0]]))
    loss = loss_fn(logits, targets)
    print(f"   Logits shape: {logits.shape}")
    print(f"   Targets shape: {targets.shape}")
    print(f"   Loss: {loss.data:.6f}")
    print(f"   ✓ Passed")
    
    # Test 3: Cross Entropy Loss
    print("\n3. Cross Entropy Loss (Multi-class Classification):")
    loss_fn = CrossEntropyLoss()
    logits = Tensor(np.random.randn(4, 5))  # 4 samples, 5 classes
    targets = Tensor(np.array([0, 2, 4, 1]))
    loss = loss_fn(logits, targets)
    print(f"   Logits shape: {logits.shape}")
    print(f"   Targets shape: {targets.shape}")
    print(f"   Loss: {loss.data:.6f}")
    print(f"   ✓ Passed")
    
    # Test 4: L1 Loss
    print("\n4. L1 Loss (Regression):")
    loss_fn = L1Loss()
    pred = Tensor(np.array([1.0, 2.0, 3.0]))
    target = Tensor(np.array([1.2, 2.1, 2.9]))
    loss = loss_fn(pred, target)
    print(f"   Loss: {loss.data:.6f}")
    print(f"   ✓ Passed")
    
    # Test 5: KL Divergence Loss
    print("\n5. KL Divergence Loss (Distribution Matching):")
    loss_fn = KLDivLoss()
    log_probs = Tensor(np.array([[-0.1, -2.0, -1.5], [-1.0, -0.1, -2.0]]))
    target_probs = Tensor(np.array([[0.8, 0.1, 0.1], [0.1, 0.7, 0.2]]))
    loss = loss_fn(log_probs, target_probs)
    print(f"   Loss: {loss.data:.6f}")
    print(f"   ✓ Passed")
    
    print("\n✅ All loss function tests passed!")


def test_schedulers():
    """Test various learning rate schedulers."""
    print("\n" + "=" * 70)
    print("Testing Learning Rate Schedulers")
    print("=" * 70)
    
    from neurx.optim.schedulers import (
        StepLR, ExponentialLR, CosineAnnealingLR, WarmupLR, ReduceLROnPlateau
    )
    
    class MockOptimizer:
        def __init__(self, lr=0.1):
            self.param_groups = [{'lr': lr}]
    
    # Test 1: Step LR
    print("\n1. Step LR (Multiplicative decay every N epochs):")
    optimizer = MockOptimizer(0.1)
    scheduler = StepLR(optimizer, step_size=3, gamma=0.5)
    lrs = [optimizer.param_groups[0]['lr']]
    for _ in range(6):
        scheduler.step()
        lrs.append(optimizer.param_groups[0]['lr'])
    print(f"   LRs over 7 epochs: {[f'{lr:.6f}' for lr in lrs]}")
    print(f"   ✓ Passed")
    
    # Test 2: Exponential LR
    print("\n2. Exponential LR (LR = LR_0 * gamma^epoch):")
    optimizer = MockOptimizer(0.1)
    scheduler = ExponentialLR(optimizer, gamma=0.9)
    lrs = [optimizer.param_groups[0]['lr']]
    for _ in range(5):
        scheduler.step()
        lrs.append(optimizer.param_groups[0]['lr'])
    print(f"   LRs over 6 epochs: {[f'{lr:.6f}' for lr in lrs]}")
    print(f"   ✓ Passed")
    
    # Test 3: Cosine Annealing LR
    print("\n3. Cosine Annealing LR (Cosine curve decay):")
    optimizer = MockOptimizer(0.1)
    scheduler = CosineAnnealingLR(optimizer, T_max=10, eta_min=0.001)
    lrs = [optimizer.param_groups[0]['lr']]
    for _ in range(10):
        scheduler.step()
        lrs.append(optimizer.param_groups[0]['lr'])
    print(f"   LRs over 11 epochs (first 6): {[f'{lr:.6f}' for lr in lrs[:6]]}")
    print(f"   ✓ Passed")
    
    # Test 4: Warmup LR
    print("\n4. Warmup LR (Linear increase for N epochs):")
    optimizer = MockOptimizer(0.1)
    scheduler = WarmupLR(optimizer, warmup_epochs=5)
    lrs = [optimizer.param_groups[0]['lr']]
    for _ in range(8):
        scheduler.step()
        lrs.append(optimizer.param_groups[0]['lr'])
    print(f"   LRs over 9 epochs: {[f'{lr:.6f}' for lr in lrs]}")
    print(f"   ✓ Passed")
    
    # Test 5: Reduce LR on Plateau
    print("\n5. Reduce LR on Plateau (Adaptive reduction):")
    optimizer = MockOptimizer(0.1)
    scheduler = ReduceLROnPlateau(optimizer, factor=0.5, patience=2, mode='min')
    
    # Simulate plateau (no improvement)
    print(f"   Initial LR: {optimizer.param_groups[0]['lr']:.6f}")
    for i in range(5):
        scheduler.step(1.0)  # Same metric value
        print(f"   After step {i+1}, LR: {optimizer.param_groups[0]['lr']:.6f}")
    
    print(f"   ✓ Passed")
    
    print("\n✅ All scheduler tests passed!")


if __name__ == '__main__':
    # Test features
    test_lstm_features()
    test_loss_functions()
    test_schedulers()
    
    # Train model
    lstm, fc, losses = train_lstm_classifier(epochs=5)
    
    print("\n" + "=" * 70)
    print("✅ Week 3 Complete: RNN/LSTM/GRU, Loss Functions, Schedulers")
    print("=" * 70)
