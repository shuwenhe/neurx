# Advanced RL Algorithms in neurx

This document describes the 7 advanced reinforcement learning algorithms implemented in neurx for post-training optimization.

## Overview

All algorithms are located in `/app/shuwen/neurx/posttrain/alignment/` and written in s language. These algorithms extend beyond standard PPO with specialized objectives, trust regions, and variance reduction techniques.

---

## 1. GMPO (Geometric-Mean Policy Optimization)

**Location**: `neurx/posttrain/alignment/gmpo/gmpo.s`

**Purpose**: Multi-reward optimization using geometric mean aggregation for better stability and robustness.

**Key Features**:
- Geometric mean of multiple reward signals prevents reward hacking
- Automatic reward normalization (running mean/std)
- Multi-reward GAE computation
- Numerical stability handling for log transformations

**Configuration**:
```s
struct GMPOConfig {
    learning_rate: f32
    num_epochs: i32
    num_rewards: i32              // Number of reward components
    reward_weights: []f32          // Optional weights for each reward
    use_geometric_mean: bool       // Use geometric vs arithmetic mean
    reward_normalization: bool     // Normalize each reward component
    epsilon: f32                   // Numerical stability constant
}
```

**When to Use**:
- Training with multiple reward signals (e.g., helpfulness + safety + coherence)
- When you need balanced optimization across all objectives
- Preventing reward hacking on single objectives

---

## 2. SAPO (Smooth Advantage Policy Optimization)

**Location**: `neurx/posttrain/alignment/sapo/sapo.s`

**Purpose**: PPO with smooth clipping using tau-parameterized surrogate objective.

**Key Features**:
- Smooth clipping function using sigmoid: `smooth_clip(x) = 1 + tau * sigmoid((x - 1) / tau)`
- Tau-weighted interpolation between clipped and unclipped objectives
- Gentler trust region enforcement than hard clipping
- Advantage normalization

**Configuration**:
```s
struct SAPOConfig {
    learning_rate: f32
    num_epochs: i32
    clip_epsilon: f32        // Standard clip range
    tau: f32                 // Smoothing temperature (0.1 - 0.5)
    smooth_weight: f32       // Weight for smooth term (0.0 - 1.0)
}
```

**When to Use**:
- When hard PPO clipping causes training instability
- Need smoother gradient flow during policy updates
- Fine-tuning on sensitive tasks

---

## 3. DPPO (Divergence PPO)

**Location**: `neurx/posttrain/alignment/dppo/dppo.s`

**Purpose**: PPO with theoretically grounded trust regions using Binary-KL or Binary-TV divergences.

**Key Features**:
- **Binary-KL variant**: `π log(π/π_old) + (1-π) log((1-π)/(1-π_old))`
- **Binary-TV variant**: `|π - π_old|`
- Adaptive epsilon based on KL divergence history
- Automatic learning rate adaptation

**Configuration**:
```s
struct DPPOConfig {
    learning_rate: f32
    divergence_type: string         // "binary_kl" or "binary_tv"
    epsilon: f32                    // Trust region constraint
    use_adaptive_epsilon: bool      // Adapt epsilon based on KL
    target_kl: f32                  // Target KL for adaptation
    epsilon_decay: f32              // Decay rate
}
```

**When to Use**:
- Need principled trust region with theoretical guarantees
- Binary-KL for softer constraints, Binary-TV for harder constraints
- Large-scale training where adaptive trust regions help stability

---

## 4. CISPO (Clipped IS-weight Policy Optimization)

**Location**: `neurx/posttrain/alignment/cispo/cispo.s`

**Purpose**: Decoupled clip ratios with importance sampling weights.

**Key Features**:
- Separate clip ranges for positive/negative advantages
- Importance sampling weights for off-policy correction
- IS weight clipping for stability
- Decoupled clipping encourages exploration on good trajectories

**Configuration**:
```s
struct CISPOConfig {
    learning_rate: f32
    clip_epsilon_positive: f32   // Clip for positive advantages
    clip_epsilon_negative: f32   // Clip for negative advantages (usually smaller)
    is_clip_lower: f32           // IS weight lower bound (e.g., 0.5)
    is_clip_upper: f32           // IS weight upper bound (e.g., 2.0)
    use_is_weights: bool         // Enable IS weighting
}
```

**When to Use**:
- Off-policy or replay buffer scenarios
- Want more aggressive exploration on positive advantages
- Need to reuse old trajectories with importance sampling

---

## 5. GPG (Group Policy Gradient)

**Location**: `neurx/posttrain/alignment/gpg/gpg.s`

**Purpose**: Minimalist policy gradient without critic, reference model, or KL penalties.

**Key Features**:
- No value function or reference model required
- Group-based sampling (multiple responses per prompt)
- Baseline options: group mean, EMA, or none
- Extremely simple and lightweight

**Configuration**:
```s
struct GPGConfig {
    learning_rate: f32
    group_size: i32              // Samples per prompt (e.g., 4-16)
    use_baseline: bool
    baseline_type: string        // "group_mean", "ema", "none"
    advantage_normalization: bool
    entropy_coeff: f32
}
```

**When to Use**:
- Simple tasks where PPO is overkill
- Limited compute budget (no value network)
- Exploration-heavy scenarios with high sample efficiency

---

## 6. OPO (Optimal Policy Optimization)

**Location**: `neurx/posttrain/alignment/opo/opo.s`

**Purpose**: Policy optimization with optimal trust region and advantage weighting.

**Key Features**:
- Adaptive learning rate based on KL divergence
- Multiple advantage weighting schemes: optimal, softmax, exp, linear
- Target KL with tolerance-based LR adjustment
- Automatic LR growth/decay

**Configuration**:
```s
struct OPOConfig {
    learning_rate: f32
    target_kl: f32               // Target KL (e.g., 0.01)
    kl_tolerance: f32            // Tolerance (e.g., 0.2)
    use_adaptive_lr: bool
    advantage_weighting: string  // "optimal", "softmax", "exp", "linear"
    temperature: f32             // Temperature for weighting
}
```

**When to Use**:
- Need automatic LR tuning during training
- Want sophisticated advantage weighting
- Large-scale training with varying KL dynamics

---

## 7. OTB (Optimal Token Baseline)

**Location**: `neurx/posttrain/alignment/otb/otb.s`

**Purpose**: Token-wise optimal variance-reduction baseline for policy gradients.

**Key Features**:
- Token-specific baselines (optimal variance reduction)
- Position-wise or token-ID-wise EMA tracking
- Optional learned baseline (value network)
- Variance tracking and reporting

**Configuration**:
```s
struct OTBConfig {
    learning_rate: f32
    baseline_type: string          // "optimal", "mean", "ema", "learned"
    use_token_wise_baseline: bool  // Per-token vs global
    use_learned_baseline: bool     // Use value network
    compute_variance: bool         // Track variance reduction
    use_whitening: bool            // Normalize advantages
}
```

**When to Use**:
- High-variance policy gradients
- Token-level tasks (generation, translation)
- Want maximum variance reduction for stable training

---

## Comparison Table

| Algorithm | Complexity | Trust Region | Baseline | Multi-Reward | Best For |
|-----------|------------|--------------|----------|--------------|----------|
| **GMPO** | Medium | PPO-style | GAE | ✅ Yes | Multi-objective training |
| **SAPO** | Medium | Smooth clip | GAE | ❌ No | Unstable PPO scenarios |
| **DPPO** | Medium | Divergence | GAE | ❌ No | Theoretical guarantees |
| **CISPO** | High | Decoupled clip | GAE | ❌ No | Off-policy/replay |
| **GPG** | Low | None | Group/EMA | ❌ No | Simple tasks |
| **OPO** | Medium | Adaptive LR | GAE | ❌ No | Large-scale training |
| **OTB** | Medium | Optional | Token-wise | ❌ No | High variance tasks |

---

## Usage Example

### GMPO for Multi-Reward Training

```s
import "posttrain/alignment/gmpo/gmpo.s"

let config = GMPOConfig{
    learning_rate: 1e-5,
    num_epochs: 4,
    max_grad_norm: 1.0,
    gamma: 0.99,
    gae_lambda: 0.95,
    num_rewards: 3,
    reward_weights: [1.0, 1.0, 1.0],
    use_geometric_mean: true,
    reward_normalization: true,
    epsilon: 1e-8,
}

let trainer = new_gmpo_trainer(config, policy, value, reference)
let losses, _ = trainer.train(train_data)
```

### SAPO for Smooth Training

```s
import "posttrain/alignment/sapo/sapo.s"

let config = SAPOConfig{
    learning_rate: 3e-6,
    num_epochs: 3,
    clip_epsilon: 0.2,
    tau: 0.3,
    smooth_weight: 0.5,
    use_value_loss: true,
}

let trainer = new_sapo_trainer(config, policy, value, reference)
let losses, _ = trainer.train(train_data)
```

### GPG for Lightweight Training

```s
import "posttrain/alignment/gpg/gpg.s"

let config = GPGConfig{
    learning_rate: 1e-4,
    num_epochs: 2,
    group_size: 8,
    baseline_type: "group_mean",
    advantage_normalization: true,
    entropy_coeff: 0.01,
}

let trainer = new_gpg_trainer(config, policy)
let losses = trainer.train(train_data)
```

---

## Implementation Notes

### Common Pattern

All trainers follow this structure:
1. **Config struct**: Parameters and hyperparameters
2. **Trainer struct**: Models, optimizer, statistics
3. **Constructor**: `new_<algo>_trainer()`
4. **Training methods**: `train_step()`, `train()`
5. **Helper methods**: Algorithm-specific logic

### Dependencies

All algorithms import:
- `tensor/tensor.s`: Tensor operations
- `optimizer/optimizer.s`: AdamW optimizer
- `posttrain/alignment/ppo/ppo.s`: Base PPO utilities (except GPG)

### Advantages Over verl

1. **Type safety**: s language provides compile-time type checking
2. **Performance**: Lower-level control, potential for better optimization
3. **Modularity**: Clear separation of concerns
4. **Simplicity**: No Python/PyTorch overhead

---

## Future Extensions

Potential additions:
- **RLOO** (REINFORCE Leave-One-Out): Specialized for LLM alignment
- **ExPO** (Exploratory Policy Optimization): Enhanced exploration
- **REBEL** (Reward-Based Exploration): Curiosity-driven RL
- **SPIN** (Self-Play Fine-tuning): Self-improvement without external rewards

---

## References

- GMPO: Geometric mean for multi-objective RL
- SAPO: Smooth policy optimization techniques
- DPPO: Divergence-based trust regions (Binary KL/TV)
- CISPO: Importance sampling with clipped weights
- GPG: Minimalist policy gradients
- OPO: Optimal advantage weighting and adaptive LR
- OTB: Token-wise baselines for variance reduction

For base PPO implementation, see `neurx/posttrain/alignment/ppo/ppo.s`.
