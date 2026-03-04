# Model Serialization Guide

Comprehensive guide to saving and loading models, optimizers, checkpoints, and state dicts in the neurx framework.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Model State Dict](#model-state-dict)
3. [Checkpoints](#checkpoints)
4. [ModelCheckpoint Manager](#modelcheckpoint-manager)
5. [Advanced Features](#advanced-features)
6. [Best Practices](#best-practices)
7. [API Reference](#api-reference)

---

## Quick Start

### Save and Load a Model

```python
import neurx
from neurx import nn
from neurx.serialization import save_checkpoint, load_checkpoint

# Create model
class MyModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(10, 5)
        self.fc2 = nn.Linear(5, 2)
    
    def forward(self, x):
        x = self.fc1(x)
        x = nn.relu(x)
        return self.fc2(x)

model = MyModel()
optimizer = neurx.optim.Adam(model.parameters())

# Save checkpoint with metrics
save_checkpoint(
    'model_checkpoint.pt',
    model=model,
    optimizer=optimizer,
    epoch=10,
    step=1000,
    metrics={'loss': 0.25, 'accuracy': 0.95}
)

# Load checkpoint
model2 = MyModel()
optimizer2 = neurx.optim.Adam(model2.parameters())

checkpoint = load_checkpoint(
    'model_checkpoint.pt',
    model=model2,
    optimizer=optimizer2
)

print(f"Loaded epoch {checkpoint['training']['epoch']}")
print(f"Metrics: {checkpoint['metrics']}")
```

---

## Model State Dict

### Understanding State Dict

State dict contains model parameters and buffers as a dictionary:

```python
# Get state dict
state = model.state_dict()
# Returns: {'fc1.weight': array(...), 'fc1.bias': array(...), ...}

# Save state dict
state = model.state_dict()
neurx.serialization.save(state, 'model_state.pkl')

# Load state dict
state = neurx.serialization.load('model_state.pkl')
model.load_state_dict(state)
```

### State Dict Keys

For a simple model:
```python
state = model.state_dict()
print(state.keys())
# ['fc1.weight', 'fc1.bias', 'fc2.weight', 'fc2.bias']

# Access individual parameters
print(state['fc1.weight'].shape)  # (input_size, output_size)
print(state['fc1.bias'].shape)    # (output_size,)
```

### Strict Loading

```python
# Strict mode (default) - all keys must match
try:
    model.load_state_dict(new_state, strict=True)
except ValueError as e:
    print(f"Mismatch: {e}")

# Non-strict mode - allows missing/extra keys
model.load_state_dict(partial_state, strict=False)
```

---

## Checkpoints

### Basic Checkpoint Operations

A checkpoint is a complete snapshot including model, optimizer, metrics, and metadata:

```python
from neurx.serialization import save_checkpoint, load_checkpoint

# Save everything
save_checkpoint(
    'checkpoint.pt',
    model=model,
    optimizer=optimizer,
    scaler=scaler,  # For AMP
    epoch=5,
    step=100,
    metrics={'loss': 0.5, 'acc': 0.9},
    metadata={'model_name': 'ResNet18'},
    include_rng_state=True,
)

# Load everything
checkpoint = load_checkpoint(
    'checkpoint.pt',
    model=model,
    optimizer=optimizer,
    scaler=scaler,
    restore_rng_state=True,
)

# Access checkpoint data
print(f"Epoch: {checkpoint['training']['epoch']}")
print(f"Step: {checkpoint['training']['step']}")
print(f"Metrics: {checkpoint['metrics']}")
print(f"Metadata: {checkpoint['metadata']}")
```

### Checkpoint Structure

```python
checkpoint = {
    'format': 'neurx.checkpoint',
    'version': 1,
    'training': {
        'step': 1000,
        'epoch': 10,
    },
    'metrics': {'loss': 0.25, 'accuracy': 0.95},
    'model_state': {...},           # model.state_dict()
    'optimizer_state': {...},       # optimizer.state_dict()
    'scaler_state': {...},          # scaler.state_dict() (if AMP)
    'metadata': {...},              # Custom metadata
    'extra_state': {...},           # Any extra data
    'rng_state': {...},             # Random state (reproducibility)
}
```

---

## ModelCheckpoint Manager

### Creating a Checkpoint Manager

```python
from neurx.serialization import ModelCheckpoint

# Initialize manager
manager = ModelCheckpoint(
    './checkpoints',
    max_keep=5,         # Keep only 5 newest checkpoints
    compress=False,     # Save without compression
)
```

### Saving Checkpoints

```python
# Save with automatic naming
path = manager.save(
    model=model,
    optimizer=optimizer,
    epoch=5,
    step=100,
    metrics={'loss': 0.5, 'accuracy': 0.95},
)
print(f"Saved to: {path}")

# Save with custom name
path = manager.save(
    model=model,
    epoch=5,
    name='model_best',
)
```

### Loading Checkpoints

```python
# Load latest checkpoint
checkpoint = manager.load(model=model, optimizer=optimizer)

# Load specific checkpoint
checkpoint = manager.load(
    checkpoint_path='./checkpoints/checkpoint_ep5_step100.pt',
    model=model,
    optimizer=optimizer,
)

# Load best checkpoint by metric
best_path = manager.get_best_checkpoint(
    metric_key='loss',
    maximize=False,  # Minimize loss
)
checkpoint = manager.load(best_path, model=model)
```

### Finding Best Checkpoint

```python
# Find checkpoint with best loss (minimize)
best_path = manager.get_best_checkpoint('loss', maximize=False)

# Find checkpoint with best accuracy (maximize)
best_path = manager.get_best_checkpoint('accuracy', maximize=True)

# Can use any metric that was saved in metrics dict
```

### Listing Checkpoints

```python
history = manager.list_checkpoints()
for entry in history:
    print(f"Epoch {entry['epoch']}: loss={entry['metrics']['loss']}")
```

---

## Advanced Features

### Compression

Save space by compressing checkpoints:

```python
# Create manager with compression
manager = ModelCheckpoint('./checkpoints', compress=True)

# Checkpoints saved as .pt.gz
checkpoint = manager.save(model=model, epoch=5)
# File: ./checkpoints/checkpoint_ep5_step0.pt.gz
```

### Extracting State Dict Subsets

```python
from neurx.serialization import extract_state_dict_subset

state = model.state_dict()

# Get only encoder parameters
encoder_state = extract_state_dict_subset(
    state,
    prefix='encoder',
    remove_prefix=False,
)

# Get only specific layer (remove prefix)
layer1_state = extract_state_dict_subset(
    state,
    prefix='fc1',
    remove_prefix=True,
)
```

### Merging State Dicts

```python
from neurx.serialization import merge_state_dicts

# Combine multiple state dicts
merged = merge_state_dicts(
    encoder_state,
    decoder_state,
    head_state,
)
```

### Tensor Dict I/O

For saving just tensors without model class:

```python
from neurx.serialization import save_tensor_dict, load_tensor_dict

state = {
    'weight1': model.fc1.weight.data,
    'bias1': model.fc1.bias.data,
}

# Save
save_tensor_dict(state, 'state.pkl', compress=True)

# Load
loaded = load_tensor_dict('state.pkl')
```

---

## Best Practices

### 1. Save Frequently During Training

```python
def train():
    manager = ModelCheckpoint('./checkpoints', max_keep=5)
    
    for epoch in range(max_epochs):
        for batch in dataloader:
            # Training code
            loss = train_step(batch)
            step += 1
        
        # Save checkpoint every epoch
        metrics = {
            'loss': loss.item(),
            'val_loss': evaluate(),
        }
        
        manager.save(
            model=model,
            optimizer=optimizer,
            epoch=epoch,
            step=step,
            metrics=metrics,
        )
```

### 2. Save Best Model

```python
best_loss = float('inf')
manager = ModelCheckpoint('./checkpoints')

for epoch in range(max_epochs):
    train()
    val_loss = evaluate()
    
    metrics = {'val_loss': val_loss}
    manager.save(model=model, epoch=epoch, metrics=metrics)
    
    # Keep track for manual best model saving
    if val_loss < best_loss:
        best_loss = val_loss
        manager.save(
            model=model,
            epoch=epoch,
            metrics=metrics,
            name='model_best',
        )
```

### 3. Resume Training from Checkpoint

```python
def resume_training(checkpoint_path):
    model = MyModel()
    optimizer = neurx.optim.Adam(model.parameters())
    manager = ModelCheckpoint('./checkpoints')
    
    # Load checkpoint
    checkpoint = manager.load(
        checkpoint_path,
        model=model,
        optimizer=optimizer,
        restore_rng_state=True,
    )
    
    start_epoch = checkpoint['training']['epoch'] + 1
    start_step = checkpoint['training']['step']
    
    # Continue training
    for epoch in range(start_epoch, max_epochs):
        # Training code continues from where it left off
        pass
```

### 4. Working with State Dict Prefixes

For multi-device or distributed training:

```python
# If model is wrapped with DataParallel, state has 'module.' prefix
# Remove it for compatibility:
state = model.state_dict()
if all(k.startswith('module.') for k in state.keys()):
    state = {k.replace('module.', '', 1): v for k, v in state.items()}

# Save cleaned state
save_checkpoint('checkpoint.pt', model_state=state)
```

### 5. Model Surgery and Transfer Learning

```python
# Load full checkpoint
checkpoint = load_checkpoint('pretrained.pt', model=model)

# Or load partial state for transfer learning
partial_state = extract_state_dict_subset(
    checkpoint['model_state'],
    prefix='encoder',
)
model.encoder.load_state_dict(partial_state, strict=False)
```

---

## API Reference

### save_checkpoint(path, *, model=None, optimizer=None, scaler=None, ...)

Save complete training checkpoint.

**Parameters:**
- `path`: Save location
- `model`: Model with state_dict()
- `optimizer`: Optimizer with state_dict()
- `scaler`: AMP scaler with state_dict()
- `step`: Training step (int)
- `epoch`: Training epoch (int)
- `metrics`: Metrics dict
- `metadata`: Custom metadata dict
- `extra_state`: Any extra data
- `include_rng_state`: Save random state

**Returns:** Checkpoint dict

---

### load_checkpoint(path, *, model=None, optimizer=None, scaler=None, ...)

Load training checkpoint.

**Parameters:**
- `path`: Checkpoint file path
- `model`: Model to load into
- `optimizer`: Optimizer to load into
- `scaler`: Scaler to load into
- `strict`: Strict mode for state dict
- `restore_rng_state`: Restore random state

**Returns:** Checkpoint dict

---

### ModelCheckpoint Manager

```python
manager = ModelCheckpoint(
    path='./checkpoints',
    max_keep=5,
    compress=False,
)

# Methods:
checkpoint = manager.save(model=None, optimizer=None, ...)
checkpoint = manager.load(checkpoint_path=None, model=None, ...)
best_path = manager.get_best_checkpoint(metric_key, maximize)
history = manager.list_checkpoints()
```

---

### Utility Functions

```python
from neurx.serialization import (
    save_tensor_dict,      # Save state dict to file
    load_tensor_dict,      # Load state dict from file
    merge_state_dicts,     # Combine multiple state dicts
    extract_state_dict_subset,  # Get subset by prefix
)
```

---

## Troubleshooting

### "Missing keys in state_dict"

**Problem:**
```python
RuntimeError: Error(s) in loading state_dict for MyModel:
  Missing keys: ['fc1.weight', 'fc1.bias']
```

**Solution:**
```python
# Use strict=False
model.load_state_dict(state, strict=False)

# Or check model and checkpoint are compatible
print(model.state_dict().keys())
print(checkpoint['model_state'].keys())
```

### "Unexpected keys in state_dict"

**Problem:** Checkpoint has extra keys not in current model

**Solution:**
```python
# Extract only needed keys
needed_state = {
    k: v for k, v in checkpoint_state.items()
    if k in model.state_dict()
}
model.load_state_dict(needed_state, strict=False)
```

### Checkpoints Too Large

**Solution:** Enable compression
```python
manager = ModelCheckpoint('./checkpoints', compress=True)
# Saves as .pt.gz instead of .pt
```

### RNG State Not Restored

**Solution:** Ensure flag is set
```python
save_checkpoint(path, ..., include_rng_state=True)
load_checkpoint(path, ..., restore_rng_state=True)
```

---

## Summary

| Task | Code |
|------|------|
| Save model | `save_checkpoint('path', model=model)` |
| Load model | `load_checkpoint('path', model=model)` |
| Get state dict | `state = model.state_dict()` |
| Load state dict | `model.load_state_dict(state)` |
| Checkpoint manager | `mgr = ModelCheckpoint('./ckpts')` |
| Save with manager | `mgr.save(model=model, epoch=e)` |
| Load latest | `mgr.load(model=model)` |
| Find best | `path = mgr.get_best_checkpoint('loss')` |

All serialization operations work seamlessly with gradient tracking, distributed training, and AMP (Automatic Mixed Precision)!
