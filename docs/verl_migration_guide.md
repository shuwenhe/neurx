# Migration Guide: verl to neurx

This guide helps developers familiar with verl transition to using the equivalent features in neurx.

## Language Differences

### Python (verl) vs s (neurx)

| Concept | Python (verl) | s (neurx) |
|---------|--------------|-----------|
| Type declaration | Dynamic typing | `let variable: Type` |
| Function definition | `def func():` | `fn func() -> ReturnType {}` |
| Class definition | `class MyClass:` | `struct MyStruct {}` |
| Method definition | `def method(self):` | `fn (s: *MyStruct) method() {}` |
| Imports | `import module` | `import "path/module.s"` |
| Collections | `list = []` | `let list: []Type = []` |
| Dictionary | `dict = {}` | `let map: map[KeyType]ValueType = {}` |
| Iteration | `for item in items:` | `for item in items {}` |
| String formatting | `f"value: {x}"` | `f"value: {x}"` (same!) |

## Algorithm Implementations

### 1. SPPO Migration

**verl (Python):**
```python
from verl.trainer.ppo import SPPOConfig, SPPOTrainer

config = SPPOConfig(
    beta=0.1,
    learning_rate=1e-5,
    num_iterations=1000,
    win_rate_threshold=0.6,
)

trainer = SPPOTrainer(
    config=config,
    policy=policy_model,
    ref_policy=ref_model,
)

losses = trainer.fit(train_dataloader)
```

**neurx (s):**
```s
import "posttrain/alignment/sppo/sppo.s"

let config = SPPOConfig{
    beta: 0.1,
    learning_rate: 1e-5,
    num_iterations: 1000,
    win_rate_threshold: 0.6,
}

let trainer = new_sppo_trainer(config, policy_model, ref_model)

let losses = trainer.train(train_dataloader)
```

**Key Differences:**
- Constructor syntax: `Class()` → `new_class()`
- Named parameters: `param=value` → `param: value`
- Method names: `fit()` → `train()`
- Type hints are mandatory in s

### 2. Checkpoint Engine Migration

**verl (Python):**
```python
from verl.workers.checkpoint import MooncakeCheckpointEngine

engine = MooncakeCheckpointEngine(
    world_size=64,
    rank=dist.get_rank(),
    use_nccl=True,
    ring_topology=True,
)

engine.sync_weights(
    model_state_dict,
    src_ranks=[0, 1, 2, 3],
    dst_ranks=[4, 5, 6, 7],
)
```

**neurx (s):**
```s
import "checkpoint/mooncake_engine.s"

let engine = new_mooncake_engine(MooncakeConfig{
    world_size: 64,
    rank: get_rank(),
    use_nccl: true,
    ring_topology: true,
})

engine.sync_weights(
    model_state_dict,
    source_ranks: [0, 1, 2, 3],
    target_ranks: [4, 5, 6, 7]
)
```

**Key Differences:**
- Config passed to constructor vs struct initialization
- Parameter names: `src_ranks` → `source_ranks`, `dst_ranks` → `target_ranks`
- Boolean: `True` → `true`

### 3. Multi-Teacher Distillation

**verl (Python):**
```python
from verl.trainer.distillation import MultiTeacherDistillation

teachers = [teacher1, teacher2, teacher3]
weights = [0.5, 0.3, 0.2]

distiller = MultiTeacherDistillation(
    student=student_model,
    teachers=teachers,
    teacher_weights=weights,
    temperature=2.0,
    mode="dynamic",
)

distiller.train(train_loader)
```

**neurx (s):**
```s
import "distillation/multi_teacher_distillation.s"

let teachers = [teacher1, teacher2, teacher3]
let config = MultiTeacherConfig{
    num_teachers: 3,
    teacher_weights: [0.5, 0.3, 0.2],
    temperature: 2.0,
    distill_mode: "dynamic",
}

let distiller = new_multi_teacher_distillation(
    config,
    student_model,
    teachers
)

distiller.train(train_loader)
```

**Key Differences:**
- Explicit config struct vs mixed parameters
- `mode` → `distill_mode` for clarity
- Config-first parameter order

## Common Patterns

### Pattern 1: Dataloader Iteration

**verl:**
```python
for batch in dataloader:
    prompts = batch["prompts"]
    responses = batch["responses"]

```

**neurx:**
```s
for batch in dataloader {
    let prompts = batch.prompts
    let responses = batch.responses

}
```

### Pattern 2: Model Forward Pass

**verl:**
```python
logits = model(input_ids, attention_mask=mask)
loss = criterion(logits, targets)
loss.backward()
optimizer.step()
```

**neurx:**
```s
let logits = model.forward(input_ids, attention_mask: mask)
let loss = criterion(logits, targets)
loss.backward()
optimizer.step()
```

### Pattern 3: Conditional Configuration

**verl:**
```python
config = {
    "learning_rate": 1e-5,
    "use_feature": True if condition else False,
}
```

**neurx:**
```s
let config = Config{
    learning_rate: 1e-5,
    use_feature: if condition { true } else { false },
}
```

### Pattern 4: List Comprehension

**verl:**
```python
rewards = [compute_reward(p, r) for p, r in zip(prompts, responses)]
```

**neurx:**
```s
let rewards: []f32 = []
for i in 0..prompts.len() {
    rewards.push(compute_reward(prompts[i], responses[i]))
}
```

## Feature Mapping Table

| verl Feature | verl Module | neurx Module | Status |
|--------------|-------------|--------------|--------|
| SPPO | `verl.trainer.ppo.sppo` | `posttrain/alignment/sppo/sppo.s` | ✅ |
| GSPO | `verl.trainer.ppo.gspo` | `posttrain/alignment/gspo/gspo.s` | ✅ |
| GDPO | `verl.trainer.dpo.gdpo` | `posttrain/alignment/gdpo/gdpo.s` | ✅ |
| PF-PPO | `verl.trainer.ppo.pf_ppo` | `posttrain/alignment/pfppo/pfppo.s` | ✅ |
| Mooncake Checkpoint | `verl.workers.checkpoint.mooncake` | `checkpoint/mooncake_engine.s` | ✅ |
| TensorRT-LLM | `verl.workers.rollout.tensorrt_llm` | `posttrain/inference/tensorrt/tensorrt_llm.s` | ✅ |
| HF Transformers | `verl.workers.rollout.hf_rollout` | `posttrain/inference/hf_transformers/hf_rollout.s` | ✅ |
| Multi-Teacher | `verl.trainer.distillation.multi_teacher` | `distillation/multi_teacher_distillation.s` | ✅ |
| Batch Reward | `verl.reward.batch_manager` | `posttrain/reward/reward_managers.s` | ✅ |
| Rate Limited | `verl.reward.rate_limiter` | `posttrain/reward/reward_managers.s` | ✅ |
| DAPO Reward | `verl.reward.dapo_manager` | `posttrain/reward/reward_managers.s` | ✅ |
| PRIME Reward | `verl.reward.prime_manager` | `posttrain/reward/reward_managers.s` | ✅ |

## Complete Example: PPO Training

### verl Version
```python
from verl.trainer.ppo import PPOConfig, PPOTrainer
from verl.workers.rollout import vLLMRollout
from verl.workers.checkpoint import MooncakeCheckpointEngine
from verl.reward import BatchRewardManager

config = PPOConfig(
    learning_rate=1e-5,
    clip_epsilon=0.2,
    num_epochs=4,
)

rollout = vLLMRollout(
    model_path="meta-llama/Llama-3.1-8B",
    tensor_parallel_size=2,
)

checkpoint_engine = MooncakeCheckpointEngine(
    world_size=32,
    rank=dist.get_rank(),
)

reward_manager = BatchRewardManager(
    reward_model=reward_model,
    batch_size=32,
)

trainer = PPOTrainer(
    config=config,
    actor=actor_model,
    critic=critic_model,
    rollout=rollout,
    checkpoint_engine=checkpoint_engine,
    reward_manager=reward_manager,
)

trainer.fit(train_dataloader)
```

### neurx Version
```s
import "posttrain/alignment/ppo/ppo.s"
import "posttrain/inference/vllm/vllm.s"
import "checkpoint/mooncake_engine.s"
import "posttrain/reward/reward_managers.s"

let config = PPOConfig{
    learning_rate: 1e-5,
    clip_epsilon: 0.2,
    num_epochs: 4,
}

let rollout = new_vllm_rollout(VLLMConfig{
    model_path: "meta-llama/Llama-3.1-8B",
    tensor_parallel_size: 2,
})

let checkpoint_engine = new_mooncake_engine(MooncakeConfig{
    world_size: 32,
    rank: get_rank(),
})

let reward_manager = new_batch_reward_manager(
    BatchRewardManagerConfig{
        batch_size: 32,
    },
    reward_model
)

let trainer = new_ppo_trainer(
    config,
    actor_model,
    critic_model,
    rollout,
    checkpoint_engine,
    reward_manager
)

trainer.train(train_dataloader)
```

## Tips for Migration

1. **Type Safety**: s requires explicit types, which catches errors early
2. **Null Safety**: Use explicit null checks in s
3. **Memory Management**: s has different memory semantics (references vs values)
4. **Error Handling**: s uses explicit error types, not exceptions
5. **Concurrency**: s has different concurrency primitives

## Common Gotchas

### 1. Mutable vs Immutable

**verl (Python):**
```python

data = []
data.append(item)
```

**neurx (s):**
```s

let data: []Item = []
data.push(item)  // Works because of let (mutable binding)
```

### 2. Dictionary Access

**verl (Python):**
```python
value = dict.get("key", default_value)
```

**neurx (s):**
```s
let value = if "key" in dict {
    dict["key"]
} else {
    default_value
}
```

### 3. Method Chaining

**verl (Python):**
```python
result = model.forward(x).softmax(dim=-1).argmax(dim=-1)
```

**neurx (s):**
```s
let logits = model.forward(x)
let probs = softmax(logits, dim: -1)
let result = argmax(probs, dim: -1)
```

### 4. None/Null Handling

**verl (Python):**
```python
if value is not None:
    process(value)
```

**neurx (s):**
```s
if value != null {
    process(value)
}
```

## Performance Considerations

1. **s is Compiled**: Faster execution than Python
2. **Static Typing**: Better optimization opportunities
3. **Memory Layout**: More control over memory layout
4. **CUDA Integration**: Direct CUDA kernel calls
5. **Zero-Copy**: Better tensor sharing

## Getting Help

- Check existing neurx implementations in `/app/shuwen/neurx/`
- Refer to s language documentation
- Compare verl examples with neurx equivalents
- Test incrementally when migrating complex code

## Conclusion

The neurx implementations provide feature parity with verl while leveraging the performance and safety benefits of the s language. The API design is intentionally similar to ease migration while following s language conventions.
