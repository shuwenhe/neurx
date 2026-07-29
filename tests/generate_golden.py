#!/usr/bin/env python3
"""
Golden Test Generator for NeurX Training System

Generates reference outputs using NumPy for:
- AdamW optimizer (step-by-step weight updates)
- Math functions (exp, log, sqrt, pow)
- Embedding forward pass
- Cross-Entropy loss

Output format: binary files (.bin) for direct comparison
"""

import numpy as np
import struct
import os

# Try to import PyTorch, fallback to NumPy
try:
    import torch
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False
    print("⚠️  PyTorch not found, using NumPy fallback (limited functionality)\n")

def save_tensor(tensor, filepath):
    """Save tensor to binary file"""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    if isinstance(tensor, np.ndarray):
        data = tensor.astype(np.float32)
    else:
        data = np.array(tensor, dtype=np.float32)
    with open(filepath, 'wb') as f:
        f.write(data.tobytes())
    print(f"✅ Saved: {filepath} (shape={data.shape})")

def save_scalar(value, filepath):
    """Save scalar to binary file"""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'wb') as f:
        f.write(struct.pack('f', float(value)))
    print(f"✅ Saved: {filepath} (value={value:.6f})")

def generate_adamw_golden():
    """Generate AdamW optimizer golden values"""
    print("\n=== Generating AdamW Golden Tests ===\n")
    
    # Configuration
    lr = 0.001
    beta1 = 0.9
    beta2 = 0.999
    eps = 1e-8
    weight_decay = 0.01
    
    # Initial state
    param = np.array([1.0], dtype=np.float32)
    momentum = np.zeros_like(param)
    variance = np.zeros_like(param)
    
    output_dir = "tests/golden/adamw"
    
    # Save initial state
    save_tensor(param, f"{output_dir}/param_step0.bin")
    
    # Run 10 steps with NumPy implementation of AdamW
    for step in range(1, 11):
        # Fixed gradient
        grad = np.array([0.1], dtype=np.float32)
        
        # Update momentum
        momentum = beta1 * momentum + (1 - beta1) * grad
        
        # Update variance
        variance = beta2 * variance + (1 - beta2) * (grad ** 2)
        
        # Bias correction
        bias_correction1 = 1 - (beta1 ** step)
        bias_correction2 = 1 - (beta2 ** step)
        
        m_hat = momentum / bias_correction1
        v_hat = variance / bias_correction2
        
        # AdamW update (weight decay on original param, not gradient)
        update = lr * m_hat / (np.sqrt(v_hat) + eps)
        param = param - update - weight_decay * lr * param
        
        # Save state
        save_tensor(param, f"{output_dir}/param_step{step}.bin")
        
        print(f"  Step {step}: param = {param[0]:.8f}")
    
    # Save config
    with open(f"{output_dir}/config.txt", 'w') as f:
        f.write(f"lr={lr}\n")
        f.write(f"beta1={beta1}\n")
        f.write(f"beta2={beta2}\n")
        f.write(f"eps={eps}\n")
        f.write(f"weight_decay={weight_decay}\n")
        f.write(f"grad=0.1 (constant)\n")
        f.write(f"implementation=numpy\n")
    
    print(f"\n✅ AdamW golden tests generated in {output_dir}/\n")

def generate_math_golden():
    """Generate math functions golden values"""
    print("\n=== Generating Math Functions Golden Tests ===\n")
    
    output_dir = "tests/golden/math"
    os.makedirs(output_dir, exist_ok=True)
    
    # exp tests
    for x in [0.0, 1.0, -1.0, 2.0, -2.0, 5.0, 10.0]:
        result = np.exp(x)
        save_scalar(result, f"{output_dir}/exp_{x:.1f}.bin")
    
    # log tests
    for x in [1.0, 2.718, 10.0, 100.0, 0.5, 0.1]:
        result = np.log(x)
        save_scalar(result, f"{output_dir}/log_{x:.3f}.bin")
    
    # sqrt tests
    for x in [0.0, 1.0, 4.0, 9.0, 2.0, 16.0, 100.0]:
        result = np.sqrt(x)
        save_scalar(result, f"{output_dir}/sqrt_{x:.1f}.bin")
    
    # pow tests
    for base, exp in [(2.0, 3.0), (10.0, 2.0), (3.0, 4.0), (0.5, 2.0)]:
        result = base ** exp
        save_scalar(result, f"{output_dir}/pow_{base:.1f}_{exp:.1f}.bin")
    
    print(f"✅ Math golden tests generated in {output_dir}/\n")

def generate_embedding_golden():
    """Generate embedding lookup golden values"""
    print("\n=== Generating Embedding Golden Tests ===\n")
    
    output_dir = "tests/golden/embedding"
    
    # Small embedding table
    vocab_size = 10
    hidden_dim = 8
    
    # Fixed seed for reproducibility
    np.random.seed(42)
    
    # Create embedding weight (vocab_size x hidden_dim)
    embedding_weight = np.random.randn(vocab_size, hidden_dim).astype(np.float32) * 0.02
    
    # Save embedding weights
    save_tensor(embedding_weight, f"{output_dir}/embedding_weight.bin")
    
    # Test cases
    test_inputs = [
        [0],
        [5],
        [9],
        [0, 1, 2],
        [5, 6, 7, 8, 9],
    ]
    
    for i, input_ids in enumerate(test_inputs):
        # Lookup embeddings
        output = embedding_weight[input_ids]
        
        # Save input and output
        with open(f"{output_dir}/input_{i}.bin", 'wb') as f:
            for idx in input_ids:
                f.write(struct.pack('i', idx))
        
        save_tensor(output, f"{output_dir}/output_{i}.bin")
        
        print(f"  Test {i}: input={input_ids}, output_shape={output.shape}")
    
    # Save config
    with open(f"{output_dir}/config.txt", 'w') as f:
        f.write(f"vocab_size={vocab_size}\n")
        f.write(f"hidden_dim={hidden_dim}\n")
        f.write(f"seed=42\n")
    
    print(f"\n✅ Embedding golden tests generated in {output_dir}/\n")

def generate_cross_entropy_golden():
    """Generate cross-entropy loss golden values"""
    print("\n=== Generating Cross-Entropy Golden Tests ===\n")
    
    output_dir = "tests/golden/loss"
    os.makedirs(output_dir, exist_ok=True)
    
    # Test case 1: Simple 2-class case
    logits = np.array([[2.0, 1.0], [0.5, 2.5]], dtype=np.float32)
    targets = np.array([0, 1], dtype=np.int32)
    
    # Compute softmax
    exp_logits = np.exp(logits - np.max(logits, axis=1, keepdims=True))
    softmax = exp_logits / np.sum(exp_logits, axis=1, keepdims=True)
    
    # Compute cross-entropy
    loss = -np.mean(np.log(softmax[np.arange(len(targets)), targets]))
    
    save_tensor(logits, f"{output_dir}/logits_simple.bin")
    with open(f"{output_dir}/targets_simple.bin", 'wb') as f:
        for t in targets:
            f.write(struct.pack('i', int(t)))
    save_scalar(loss, f"{output_dir}/loss_simple.bin")
    
    print(f"  Simple case: logits={logits.shape}, loss={loss:.6f}")
    
    # Test case 2: Batch of 4, 10 classes
    np.random.seed(42)
    logits = np.random.randn(4, 10).astype(np.float32)
    targets = np.array([0, 3, 7, 9], dtype=np.int32)
    
    # Compute softmax
    exp_logits = np.exp(logits - np.max(logits, axis=1, keepdims=True))
    softmax = exp_logits / np.sum(exp_logits, axis=1, keepdims=True)
    
    # Compute cross-entropy
    loss = -np.mean(np.log(softmax[np.arange(len(targets)), targets]))
    
    save_tensor(logits, f"{output_dir}/logits_batch.bin")
    with open(f"{output_dir}/targets_batch.bin", 'wb') as f:
        for t in targets:
            f.write(struct.pack('i', int(t)))
    save_scalar(loss, f"{output_dir}/loss_batch.bin")
    
    print(f"  Batch case: logits={logits.shape}, loss={loss:.6f}")
    
    print(f"\n✅ Cross-Entropy golden tests generated in {output_dir}/\n")

def main():
    print("=" * 60)
    print("NeurX Golden Test Generator")
    print("=" * 60)
    
    generate_adamw_golden()
    generate_math_golden()
    generate_embedding_golden()
    generate_cross_entropy_golden()
    
    print("=" * 60)
    print("✅ All golden tests generated successfully!")
    print("=" * 60)
    print("\nUsage:")
    print("  1. Run NeurX implementations")
    print("  2. Compare outputs with .bin files in tests/golden/")
    print("  3. Verify max absolute error < 1e-5")
    print("")

if __name__ == "__main__":
    main()
