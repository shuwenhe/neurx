# Scatter/Gather/Meshgrid Quick Reference

A practical guide to using scatter, gather, scatter_add, and meshgrid operations in the neurx framework.

## Table of Contents
1. [Overview](#overview)
2. [Gather Operation](#gather-operation)
3. [Scatter Operation](#scatter-operation)
4. [Scatter Add Operation](#scatter-add-operation)
5. [Meshgrid Operation](#meshgrid-operation)
6. [Common Use Cases](#common-use-cases)
7. [Tips and Best Practices](#tips-and-best-practices)

---

## Overview

These operations provide advanced indexing capabilities essential for:
- **Attention mechanisms** (gather top-k values)
- **Embedding tables** (scatter gradients)
- **Sparse operations** (accumulate at specific indices)
- **Spatial transformations** (coordinate grids)

### Quick Comparison

| Operation | Purpose | In-place | Accumulates |
|-----------|---------|----------|-------------|
| `gather` | Collect values at indices | No | N/A |
| `scatter` | Replace values at indices | No | No |
| `scatter_add` | Add values at indices | No | Yes |
| `meshgrid` | Create coordinate grids | N/A | N/A |

---

## Gather Operation

**Purpose**: Select values from a neurx along a dimension using an index neurx.

### Basic Usage
```python
import neurx
import numpy as np

# Source neurx
data = neurx.Tensor([[1, 2, 3], 
                       [4, 5, 6], 
                       [7, 8, 9]])

# Indices to gather (same shape as output)
index = neurx.Tensor(np.array([[0, 2],   # From row 0, get columns 0 and 2
                                 [1, 0],   # From row 1, get columns 1 and 0
                                 [2, 1]],  # From row 2, get columns 2 and 1
                                dtype=np.int64))

# Gather along dimension 1 (columns)
result = data.gather(1, index)
# Result: [[1, 3],
#          [5, 4],
#          [9, 8]]
```

### Parameters
- `dim` (int): Dimension along which to gather
- `index` (Tensor): Index neurx (int64), same ndim as self
- Returns: Tensor with same shape as index

### Gradient Behavior
- Gradients flow back to the source neurx at the gathered positions
- Index neurx doesn't receive gradients (not differentiable)

---

## Scatter Operation

**Purpose**: Write values from a source neurx into self at positions specified by indices.

### Basic Usage
```python
# Target neurx (will be modified)
target = neurx.zeros((3, 5))

# Indices where to scatter
index = neurx.Tensor(np.array([[0, 2],   # Row 0: write to columns 0 and 2
                                 [1, 3],   # Row 1: write to columns 1 and 3
                                 [0, 4]],  # Row 2: write to columns 0 and 4
                                dtype=np.int64))

# Values to scatter
source = neurx.ones((3, 2))

# Scatter along dimension 1
result = target.scatter(1, index, source)
# Result: [[1, 0, 1, 0, 0],
#          [0, 1, 0, 1, 0],
#          [1, 0, 0, 0, 1]]
```

### Important Notes
- **Replaces** values at indexed positions (not accumulative)
- If same index appears multiple times, last write wins
- Index and source must have the same shape

---

## Scatter Add Operation

**Purpose**: **Accumulate** values into self at positions specified by indices.

### Basic Usage
```python
# Starting neurx (with existing values)
target = neurx.ones((3, 5))

# Indices
index = neurx.Tensor(np.array([[0, 2],
                                 [1, 3],
                                 [0, 4]],
                                dtype=np.int64))

# Values to add (multiply by 2 for clarity)
source = neurx.ones((3, 2)) * 2

# Scatter-add along dimension 1
result = target.scatter_add(1, index, source)
# Result: [[3, 1, 3, 1, 1],  # Added 2 to positions 0 and 2
#          [1, 3, 1, 3, 1],  # Added 2 to positions 1 and 3
#          [3, 1, 1, 1, 3]]  # Added 2 to positions 0 and 4
```

### Key Difference from Scatter
```python
# scatter: target[i] = source[j]      (replace)
# scatter_add: target[i] += source[j]  (accumulate)
```

### Use Case: Gradient Accumulation
```python
# Embedding gradient accumulation
embedding = neurx.zeros((vocab_size, embed_dim), requires_grad=True)
token_ids = get_batch_tokens()  # [batch, seq_len, 1]
gradients = compute_gradients()  # [batch, seq_len, embed_dim]

# Accumulate gradients for each token (handles duplicates correctly)
embedding = embedding.scatter_add(0, token_ids, gradients)
```

---

## Meshgrid Operation

**Purpose**: Create coordinate grids from 1-D coordinate tensors.

### Basic 2D Grid
```python
# Create coordinate vectors
x = neurx.arange(3)  # [0, 1, 2]
y = neurx.arange(4)  # [0, 1, 2, 3]

# Cartesian indexing (xy) - default for plotting
X, Y = neurx.meshgrid(x, y, indexing='xy')

# X (4x3):              Y (4x3):
# [[0, 1, 2],           [[0, 0, 0],
#  [0, 1, 2],            [1, 1, 1],
#  [0, 1, 2],            [2, 2, 2],
#  [0, 1, 2]]            [3, 3, 3]]

# Matrix indexing (ij) - natural array order
X, Y = neurx.meshgrid(x, y, indexing='ij')

# X (3x4):              Y (3x4):
# [[0, 0, 0, 0],        [[0, 1, 2, 3],
#  [1, 1, 1, 1],         [0, 1, 2, 3],
#  [2, 2, 2, 2]]         [0, 1, 2, 3]]
```

### Indexing Modes

#### 'xy' (Cartesian)
- First two dimensions are swapped
- Matches matplotlib plotting conventions
- X varies along columns, Y varies along rows
- Output shape: `(len(y), len(x), ...)` for first two dims

#### 'ij' (Matrix)
- Natural array indexing order
- X varies along rows, Y varies along columns
- Output shape: `(len(x), len(y), ...)`

### 3D and Higher
```python
x = neurx.arange(2)
y = neurx.arange(3)
z = neurx.arange(4)

X, Y, Z = neurx.meshgrid(x, y, z, indexing='ij')
# X.shape = Y.shape = Z.shape = (2, 3, 4)
```

---

## Common Use Cases

### 1. Top-K Attention Selection
```python
# Compute attention scores
scores = model.compute_attention(query, key)  # [batch, heads, seq_len]

# Get top-k indices
topk_values, topk_indices = scores.topk(k=5, dim=-1)

# Gather top-k keys and values
topk_keys = key.gather(1, topk_indices.expand(-1, -1, -1, key.shape[-1]))
topk_values = value.gather(1, topk_indices.expand(-1, -1, -1, value.shape[-1]))

# Compute attention only on top-k
attention_output = compute_attention(query, topk_keys, topk_values)
```

### 2. Sparse Gradient Updates
```python
# Update only specific embedding rows
embedding_table = neurx.zeros((vocab_size, embed_dim))

# Batch of token IDs [batch_size, seq_len]
token_ids = tokenizer.encode(text)

# Compute updates for these specific tokens
updates = model.compute_embedding_updates(token_ids)

# Accumulate gradients (handles duplicate IDs correctly)
embedding_table = embedding_table.scatter_add(
    dim=0,
    index=token_ids.view(-1, 1).expand(-1, embed_dim),
    src=updates.view(-1, embed_dim)
)
```

### 3. Spatial Transformer Networks
```python
def create_sampling_grid(H, W):
    """Create normalized coordinate grid [-1, 1] for image sampling."""
    y = neurx.linspace(-1, 1, H)
    x = neurx.linspace(-1, 1, W)
    grid_y, grid_x = neurx.meshgrid(y, x, indexing='ij')
    
    # Stack to [H, W, 2] for x,y coordinates
    grid = neurx.stack([grid_x, grid_y], dim=-1)
    return grid

def apply_affine_transform(image, theta):
    """Apply affine transformation to image."""
    batch, C, H, W = image.shape
    
    # Create base sampling grid
    grid = create_sampling_grid(H, W)  # [H, W, 2]
    
    # Apply transformation
    grid_flat = grid.view(-1, 2)  # [H*W, 2]
    grid_transformed = neurx.matmul(grid_flat, theta.T)  # [H*W, 2]
    grid_transformed = grid_transformed.view(H, W, 2)
    
    # Sample from image using transformed coordinates
    sampled = grid_sample(image, grid_transformed)
    return sampled
```

### 4. Optical Flow Visualization
```python
def visualize_flow(flow):
    """Convert optical flow to RGB color wheel visualization."""
    # flow: [H, W, 2] - displacement in x,y
    H, W = flow.shape[:2]
    
    # Create coordinate grid
    y = neurx.arange(H, dtype=flow.dtype)
    x = neurx.arange(W, dtype=flow.dtype)
    grid_y, grid_x = neurx.meshgrid(y, x, indexing='ij')
    
    # Compute flow magnitude and angle
    flow_x = flow[:, :, 0]
    flow_y = flow[:, :, 1]
    magnitude = neurx.sqrt(flow_x**2 + flow_y**2)
    angle = neurx.atan2(flow_y, flow_x)
    
    # Convert to HSV (H=angle, S=1, V=magnitude)
    # ... color conversion code ...
    
    return rgb_image
```

### 5. Positional Encoding (Transformers)
```python
def create_2d_positional_encoding(H, W, d_model):
    """Create 2D positional encoding for vision transformers."""
    # Create position grids
    y_pos = neurx.arange(H)
    x_pos = neurx.arange(W)
    grid_y, grid_x = neurx.meshgrid(y_pos, x_pos, indexing='ij')
    
    # Flatten positions
    positions = neurx.stack([
        grid_y.flatten(),
        grid_x.flatten()
    ], dim=-1)  # [H*W, 2]
    
    # Generate sinusoidal encodings
    pe = generate_positional_encoding(positions, d_model)
    return pe.view(H, W, d_model)
```

---

## Tips and Best Practices

### Index Tensor Types
```python
# ✅ CORRECT: Use int64 dtype for indices
index = neurx.Tensor(np.array([[0, 1, 2]], dtype=np.int64))

# ❌ WRONG: Float indices will cause errors
index = neurx.Tensor([[0.0, 1.0, 2.0]])  # Error!
```

### Scatter vs Scatter-Add
```python
# Use scatter when you want to REPLACE values
target.scatter(dim, index, source)

# Use scatter_add when you want to ACCUMULATE (common in gradients)
target.scatter_add(dim, index, source)

# Example: If index has duplicates
index = neurx.Tensor(np.array([[0, 0]], dtype=np.int64))  # Same index twice
source = neurx.ones((1, 2))

# scatter: Only last write survives
result1 = neurx.zeros(1, 5).scatter(1, index, source)
# result1[0, 0] = 1.0 (last write)

# scatter_add: Both additions happen
result2 = neurx.zeros(1, 5).scatter_add(1, index, source)
# result2[0, 0] = 2.0 (1.0 + 1.0)
```

### Meshgrid Indexing Choice
```python
# Use 'xy' when:
# - Creating grids for matplotlib plotting
# - Working with x,y coordinate systems
# - Matching OpenCV/PIL conventions

# Use 'ij' when:
# - Working with array indices directly
# - Processing images as numpy arrays
# - Natural row-column indexing
```

### Memory Considerations
```python
# Meshgrid can create large tensors
H, W = 4096, 4096
y = neurx.arange(H)
x = neurx.arange(W)
Y, X = neurx.meshgrid(y, x)  # 2 × 4096² × 8 bytes = ~256 MB

# Consider chunking for very large grids
for y_chunk in range(0, H, chunk_size):
    for x_chunk in range(0, W, chunk_size):
        # Process smaller grid chunks
        pass
```

### Gradient Flow
```python
# Gather and scatter support gradients
x = neurx.randn((3, 5), requires_grad=True)
index = neurx.Tensor(np.array([[0, 2]], dtype=np.int64))
y = x.gather(1, index)
loss = y.sum()
loss.backward()
# x.grad will have non-zero values at gathered positions

# Meshgrid does not require gradients (coordinate generation)
y = neurx.arange(100)
x = neurx.arange(100)
Y, X = neurx.meshgrid(y, x)
# No gradient tracking needed
```

---

## Performance Notes

### Scatter Operations
- Time: O(N × M) where N is batch size, M is number of indices
- Space: O(output_size) - creates copy of data
- Optimization: Consider batching multiple scatter operations

### Meshgrid
- Time: O(∏ sizes) - proportional to output size
- Space: O(∏ sizes) per output grid
- Optimization: Uses broadcasting, minimal memory until materialized

### CUDA Acceleration
Current implementation is CPU-only. CUDA kernels planned for:
- 10-100x speedup for scatter operations
- Efficient kernel fusion for grid operations
- In-place variants for memory efficiency

---

## Additional Resources

- **Full API Documentation**: See `neurx.Tensor.gather`, `scatter`, `scatter_add`
- **Test Suite**: `tests/test_scatter_gather.py` for comprehensive examples
- **PyTorch Comparison**: `docs/pytorch_comparison_analysis.md`

---

## Summary

| When to Use | Operation |
|-------------|-----------|
| Select specific values | `gather` |
| Replace values at indices | `scatter` |
| Accumulate at indices | `scatter_add` |
| Create coordinate grids | `meshgrid` |

These operations enable advanced neurx manipulations essential for modern deep learning architectures!
