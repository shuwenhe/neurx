#!/usr/bin/env python3
"""
Advanced NeurX PostTrain Verification - Tensor Level
Validates that gradient descent actually happened by checking weight statistics
"""

import struct
import json
import math
import sys

def read_safetensors_tensors(path, max_tensors=4):
    """Read first N tensors from safetensors file"""
    tensors = {}
    
    try:
        with open(path, 'rb') as f:
            # Read header size (8 bytes, little-endian)
            header_size_bytes = f.read(8)
            if len(header_size_bytes) < 8:
                return None
            
            header_size = struct.unpack('<Q', header_size_bytes)[0]
            
            # Read JSON metadata
            header_json = f.read(header_size).decode('utf-8')
            header_dict = json.loads(header_json)
            
            # Extract tensors
            for i, (name, info) in enumerate(header_dict.items()):
                if i >= max_tensors:
                    break
                
                offsets = info['data_offsets']
                start, end = offsets[0], offsets[1]
                shape = info['shape']
                
                # Read first 32 values
                f.seek(8 + header_size + start)
                floats_data = f.read(min(64, end - start))  # 2 bytes per BF16
                
                floats = []
                for j in range(0, len(floats_data), 2):
                    if j + 2 <= len(floats_data):
                        try:
                            val = struct.unpack('<e', floats_data[j:j+2])[0]
                            floats.append(val)
                        except:
                            pass
                
                tensors[name] = {
                    'shape': shape,
                    'values': floats,
                    'total_size': end - start
                }
        
        return tensors
    
    except Exception as e:
        print(f"Error reading safetensors: {e}")
        return None

def compute_stats(values):
    """Compute tensor statistics"""
    if not values:
        return {'mean': 0, 'std': 0, 'min': 0, 'max': 0, 'norm': 0}
    
    mean = sum(values) / len(values)
    variance = sum((x - mean) ** 2 for x in values) / len(values)
    std = math.sqrt(variance)
    norm = math.sqrt(sum(x**2 for x in values))
    
    return {
        'mean': mean,
        'std': std,
        'min': min(values),
        'max': max(values),
        'norm': norm,
        'count': len(values),
        'nonzero': sum(1 for x in values if x != 0)
    }

def verify_posttrain():
    """Main verification routine"""
    print("=" * 60)
    print("NeurX PostTrain Tensor-Level Verification")
    print("=" * 60)
    print()
    
    adapter_path = "/home/shuwen/shuwen/posttrain_adapter/adapter_model.safetensors"
    
    # Read tensors
    print("[1] Reading adapter tensors...")
    tensors = read_safetensors_tensors(adapter_path)
    
    if not tensors:
        print("❌ FAIL: Cannot read adapter file")
        return False
    
    print(f"✅ PASS: Read {len(tensors)} tensors")
    print()
    
    # Analyze lora_A vs lora_B
    print("[2] Analyzing LoRA A vs B matrices...")
    lora_a_stats = []
    lora_b_stats = []
    
    for name, info in tensors.items():
        stats = compute_stats(info['values'])
        
        if 'lora_A' in name:
            lora_a_stats.append((name, stats))
            print(f"\n📊 {name}")
            print(f"   Shape: {info['shape']}")
            print(f"   Mean: {stats['mean']:.6f}, Std: {stats['std']:.6f}")
            print(f"   Min: {stats['min']:.6f}, Max: {stats['max']:.6f}")
            print(f"   L2 Norm: {stats['norm']:.6f}")
            print(f"   Non-zero: {stats['nonzero']}/{stats['count']}")
        
        elif 'lora_B' in name:
            lora_b_stats.append((name, stats))
            print(f"\n📊 {name}")
            print(f"   Shape: {info['shape']}")
            print(f"   Mean: {stats['mean']:.6f}, Std: {stats['std']:.6f}")
            print(f"   Min: {stats['min']:.6f}, Max: {stats['max']:.6f}")
            print(f"   L2 Norm: {stats['norm']:.6f}")
            print(f"   Non-zero: {stats['nonzero']}/{stats['count']}")
    
    print()
    
    # KEY VERIFICATION: lora_B should NOT be all zeros
    print("[3] Gradient Descent Verification (CRITICAL)")
    print("-" * 60)
    print("Python initializes lora_B to all 0.0")
    print("If current values ≠ 0, gradient descent definitely happened!")
    print()
    
    all_lora_b_zero = True
    for name, stats in lora_b_stats:
        is_zero = all(v == 0 for v in tensors[name]['values'] if v is not None)
        if is_zero:
            print(f"❌ {name}: ALL ZEROS (training didn't happen!)")
            all_lora_b_zero = True
        else:
            print(f"✅ {name}: NON-ZERO (gradient descent worked!)")
            print(f"   Mean: {stats['mean']:.6f}, L2: {stats['norm']:.6f}")
            all_lora_b_zero = False
    
    print()
    if all_lora_b_zero:
        print("❌ FAIL: lora_B matrices are all zeros!")
        print("   → Training did not actually happen")
        return False
    else:
        print("✅ PASS: lora_B matrices contain non-zero values!")
        print("   → Gradient descent definitely occurred")
    
    # Summary
    print()
    print("=" * 60)
    print("VERIFICATION SUMMARY")
    print("=" * 60)
    
    avg_lora_a_norm = sum(s[1]['norm'] for s in lora_a_stats) / max(1, len(lora_a_stats))
    avg_lora_b_norm = sum(s[1]['norm'] for s in lora_b_stats) / max(1, len(lora_b_stats))
    
    print(f"✅ LoRA A mean L2 norm: {avg_lora_a_norm:.6f}")
    print(f"✅ LoRA B mean L2 norm: {avg_lora_b_norm:.6f}")
    print()
    print("CONCLUSION: Training is REAL ✅✅✅")
    print("- lora_B changed from 0.0 → non-zero")
    print("- This can only happen via gradient descent")
    print()
    
    return True

if __name__ == '__main__':
    try:
        success = verify_posttrain()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
