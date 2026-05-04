# WEEK 6 QUICK REFERENCE CARD

## Activation Functions Quick Lookup

### Basic Activations
```python
from neurx.nn import relu, sigmoid, tanh, softmax

# ReLU: max(0, x) - standard hidden layer
y = relu(x)

# Sigmoid: 1/(1+e^-x) - binary classification  
y = sigmoid(x)  # Output: [0, 1]

# Tanh: zero-centered, output [-1, 1]
y = tanh(x)

# Softmax: probability distribution
y = softmax(x, axis=-1)  # Sum = 1.0
```

### Advanced Activations
```python
from neurx.nn import gelu, swish, mish, elu, selu

# GELU: Gaussian Error Linear Unit (transformers)
y = gelu(x, approximate=False)

# Swish: x * sigmoid(x) - self-gating
y = swish(x, beta=1.0)

# Mish: x * tanh(softplus(x)) - smooth
y = mish(x)

# ELU: smooth negative branch
y = elu(x, alpha=1.0)

# SELU: self-normalizing with fixed constants
y = selu(x)
```

### Parametric Activations
```python
from neurx.nn import leaky_relu, prelu, rrelu

# Leaky ReLU: allows small negative slope
y = leaky_relu(x, negative_slope=0.01)

# PReLU: learnable negative slope
y = prelu(x, weight=w)

# RReLU: randomized negative slope
y = rrelu(x, lower=0.125, upper=0.333, training=True)
```

### Thresholding Activations
```python
from neurx.nn import hardshrink, softshrink, hardtanh, threshold

# Hard Shrink: |x| > λ ? x : 0
y = hardshrink(x, lambd=0.5)

# Soft Shrink: like soft thresholding
y = softshrink(x, lambd=0.5)

# Hard Tanh: clip to [min, max]
y = hardtanh(x, min_val=-1.0, max_val=1.0)

# Threshold: simple gating
y = threshold(x, threshold=0.5, value=0)
```

### Module Classes
```python
from neurx.nn import ReLU, Sigmoid, GELU, Swish, Softmax

# Use as layer in model
class MyModel:
    def __init__(self):
        self.relu = ReLU()
        self.gelu = GELU()
        self.softmax = Softmax(axis=-1)
    
    def forward(self, x):
        x = self.relu(x)
        x = self.gelu(x)
        return self.softmax(x)
```

---

## Loss Functions Quick Lookup

### Focal Loss (Class Imbalance)
```python
from neurx.nn import focal_loss, focal_loss_multi

# Binary classification with class imbalance
loss = focal_loss(predictions, targets, alpha=0.25, gamma=2.0)

# Multi-class with imbalance
loss = focal_loss_multi(predictions, targets, alpha=0.25, gamma=2.0)
# Focus factor: (1 - p_t)^γ down-weights easy examples
```

### Margin-based Losses
```python
from neurx.nn import hinge_loss, smooth_l1_loss, triplet_loss

# SVM loss for ranking
loss = hinge_loss(predictions, targets, margin=1.0)

# Robust regression (less sensitive to outliers)
loss = smooth_l1_loss(predictions, targets, beta=1.0)

# Siamese networks: pull anchor-positive, push anchor-negative
loss = triplet_loss(anchor, positive, negative, margin=1.0)
```

### Contrastive Learning Losses
```python
from neurx.nn import contrastive_loss, ntxent_loss, center_loss

# Pairwise similarity learning
loss = contrastive_loss(emb1, emb2, labels, margin=1.0)
# label=1: similar (pull closer), label=0: dissimilar (push apart)

# NT-Xent from SimCLR (most popular)
loss = ntxent_loss(embeddings, labels, temperature=0.07)
# Standard for contrastive learning

# Reduce intra-class variance (usually added to classification loss)
loss = center_loss(embeddings, labels, centers, alpha=0.5)
```

### Distribution Matching Losses
```python
from neurx.nn import kullback_leibler_divergence, wasserstein_loss

# KL divergence: KL(P || Q)
kl = kullback_leibler_divergence(predictions, targets)

# Wasserstein distance: optimal transport
loss = wasserstein_loss(predictions, targets)
```

### Specialized Losses
```python
from neurx.nn import arcface_loss

# Face recognition with angular margin
loss = arcface_loss(embeddings, labels, weights, s=64.0, m=0.5)
# s: scale factor, m: additive angular margin
```

---

## Learning Rate Schedules Quick Lookup

### Basic Schedules
```python
from neurx.nn import constant_lr, step_lr, exponential_lr

# Fixed learning rate
schedule = constant_lr(0.001)
lr = schedule(step)  # Always 0.001

# Decay every N steps
schedule = step_lr(0.1, step_size=30, gamma=0.1)
# Step 0-29: 0.1, Step 30-59: 0.01, Step 60+: 0.001

# Exponential decay per step
schedule = exponential_lr(0.1, gamma=0.99)
# lr(t) = 0.1 * 0.99^t
```

### Advanced Schedules
```python
from neurx.nn import polynomial_lr, cosine_lr, one_cycle_lr

# Polynomial decay (linear when power=1)
schedule = polynomial_lr(0.1, total_steps=100, end_lr=0.0, power=2.0)

# Cosine annealing (warm restarts)
schedule = cosine_lr(0.1, total_steps=100, min_lr=0.0)

# One-Cycle: increase then decrease (fast convergence)
schedule = one_cycle_lr(0.01, 0.1, total_steps=1000, pct_start=0.3)
```

### Warmup Schedules
```python
from neurx.nn import linear_warmup_lr, linear_warmup_cosine_lr

# Linear warmup to target LR
schedule = linear_warmup_lr(0.1, warmup_steps=1000)
# Step 0-999: linear from 0 to 0.1
# Step 1000+: stays at 0.1

# Warmup + Cosine (very common in transformers)
schedule = linear_warmup_cosine_lr(
    initial_lr=0.1,
    warmup_steps=1000,
    total_steps=10000,
    min_lr=0.0
)
```

### Using Schedules in Training
```python
schedule = cosine_lr(0.1, total_steps=100)

for epoch in range(100):
    lr = schedule(epoch)
    optimizer.set_learning_rate(lr)
    # ... training code
```

---

## Optimizer Utilities Quick Lookup

### Gradient Operations
```python
from neurx.nn import compute_grad_norm, clip_grad_norm, apply_weight_decay

# Compute L2 norm of gradients
grad_list = [grad1, grad2, grad3]
norm = compute_grad_norm(grad_list)

# Clip gradients by norm (prevent explosion)
clipped = clip_grad_norm(grad_list, max_norm=1.0)

# Weight decay (AdamW style)
updated_params = apply_weight_decay(params, weight_decay=0.01, lr=0.001)
```

### Advanced Utilities
```python
from neurx.nn import adam_momentum_update, sgd_momentum_update

# Single Adam step (manually)
m, v = adam_momentum_update(
    gradients, m, v, 
    beta1=0.9, beta2=0.999, lr=0.001
)

# Single SGD+momentum step (manually)
velocity = sgd_momentum_update(
    gradients, velocity,
    momentum=0.9, lr=0.01
)
```

### Scheduler Classes
```python
from neurx.nn import LRScheduler, WarmupScheduler, GradientAccumulator

# Wrap a schedule function
schedule_fn = cosine_lr(0.1, total_steps=100)
scheduler = LRScheduler(schedule_fn)
current_lr = scheduler.get_lr()  # Get current LR
scheduler.step()  # Advance to next step

# Add warmup to any scheduler
base_scheduler = LRScheduler(cosine_lr(0.1, 100))
warmup_scheduler = WarmupScheduler(
    base_scheduler, 
    warmup_steps=10,
    warmup_method='linear'
)

# Accumulate gradients over N steps
accumulator = GradientAccumulator(num_accumulation_steps=4)
for batch in dataloader:
    grads = compute_gradients(batch)
    accumulator.add_grads(grads)
    
    if accumulator.should_update():
        accumulated = accumulator.get_accumulated_grads()
        optimizer.step(accumulated)
        accumulator.reset()
```

---

## Common Usage Patterns

### Training Loop with Activation + Loss + Schedule
```python
from neurx.nn import relu, sigmoid, softmax, focal_loss, cosine_lr

# Setup
schedule = cosine_lr(0.1, total_steps=1000)
relu_layer = relu
sigmoid_layer = sigmoid

for epoch in range(1000):
    # Get learning rate
    lr = schedule(epoch)
    
    for batch in dataloader:
        # Forward pass
        x = relu_layer(x)  # Hidden layer
        x = sigmoid_layer(x)  # Output (binary)
        
        # Loss with focal loss for imbalance
        loss = focal_loss(x, targets, alpha=0.25, gamma=2.0)
        
        # Backward & update with current LR
        loss.backward()
        optimizer.step(lr)
        optimizer.zero_grad()
```

### Metric Learning with Contrastive Loss
```python
from neurx.nn import ntxent_loss, linear_warmup_cosine_lr

schedule = linear_warmup_cosine_lr(
    initial_lr=0.1, warmup_steps=500, total_steps=5000
)

for step in range(5000):
    lr = schedule(step)
    
    # Get embeddings
    embeddings = encoder(images)  # Shape: (batch, embed_dim)
    
    # Contrastive loss (SimCLR)
    loss = ntxent_loss(embeddings, labels, temperature=0.07)
    
    loss.backward()
    optimizer.step(lr)
```

### Face Recognition Training
```python
from neurx.nn import arcface_loss, linear_warmup_cosine_lr

schedule = linear_warmup_cosine_lr(0.1, 1000, 10000)

for step in range(10000):
    # Get embeddings
    embeddings = face_encoder(images)
    
    # ArcFace loss
    loss = arcface_loss(
        embeddings, labels, 
        weights=classifier_weights,
        s=64.0,  # Scale
        m=0.5    # Angular margin
    )
    
    lr = schedule(step)
    loss.backward()
    optimizer.step(lr)
```

---

## Performance Tips

### Activation Functions
- **ReLU**: Fastest, good for most cases
- **GELU**: Slightly slower, better for transformers
- **Sigmoid/Tanh**: Slowest, use only when needed
- **Mish/Swish**: Middle ground, good smoothness

### Loss Functions
- **Focal Loss**: When classes imbalanced (use γ=2-3)
- **Triplet Loss**: For embedding spaces, needs careful mining
- **NT-Xent**: Popular for self-supervised, set temperature ≈ 0.07
- **ArcFace**: Best for face recognition

### Learning Rates
- **Warmup**: Essential for transformers (1-5% of total steps)
- **Cosine**: Works best overall
- **One-Cycle**: Fast convergence, good for CNNs
- **Step Decay**: Simple, works reliably

### Gradient Clipping
```python
# Apply when training unstable
norm = compute_grad_norm(grads)
if norm > max_norm:
    grads = [g * (max_norm / norm) for g in grads]
```

---

**Last Updated**: Week 6 Completion  
**Framework Version**: 95% complete (147 APIs)  
**Cheat Sheet Version**: 1.0
