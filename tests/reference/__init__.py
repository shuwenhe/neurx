"""
Reference Test Framework for Phase 2A

This module compares NeurX implementations against Hugging Face reference models.
Each layer has a golden output that is compared during testing.

Philosophy:
- Fixed input (deterministic)
- Per-layer testing (fast debugging)
- Regression detection (which layer broke?)
"""

import os
import json

# Test configuration
REFERENCE_MODEL_PATH = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
TEST_TEXT = "What is the treatment for chronic urinary tract infection?"
TOLERANCE_L2 = 0.1  # L2 distance tolerance for float comparisons
TOLERANCE_LOGITS = 0.05  # More strict for final logits

# Golden data storage
GOLDEN_DIR = os.path.dirname(__file__)

def load_golden(component_name):
    """Load golden output from reference model"""
    path = os.path.join(GOLDEN_DIR, component_name, "golden_output.json")
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    else:
        print(f"⚠️  Golden data not found: {path}")
        print(f"   Run generate_reference.py to create it")
        return None

def save_golden(component_name, data):
    """Save golden output for future comparisons"""
    directory = os.path.join(GOLDEN_DIR, component_name)
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, "golden_output.json")
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"✓ Saved golden data: {path}")

# Utilities
def compute_l2_distance(array1, array2):
    """Compute L2 distance between two arrays"""
    import numpy as np
    arr1 = np.array(array1).flatten()
    arr2 = np.array(array2).flatten()
    return float(np.sqrt(np.sum((arr1 - arr2) ** 2)))

def allclose(array1, array2, atol=1e-6):
    """Check if arrays are approximately equal"""
    import numpy as np
    return np.allclose(array1, array2, atol=atol)
