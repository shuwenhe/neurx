# neurx RLHF 快速开始指南

本指南帮助您快速上手 neurx 的 RLHF 功能。

## 目录
1. [基础训练流程](#基础训练流程)
2. [算法选择](#算法选择)
3. [分布式训练](#分布式训练)
4. [推理优化](#推理优化)
5. [常见场景](#常见场景)

## 基础训练流程

### 1. GRPO 训练（最简单）

GRPO 是最容易上手的算法，不需要价值模型：

```s
package main

use neurx.posttrain.alignment.grpo.{grpo_trainer, new_grpo_config}
use neurx.nn.{module, optimizer}

func main() {
    // 1. 配置
    grpo_config cfg = new_grpo_config()
    cfg.group_size = 4
    cfg.batch_size = 32
    
    // 2. 加载模型
    module policy = load_model("Qwen2.5-7B")
    module ref_policy = load_model("Qwen2.5-7B")
    
    // 3. 创建优化器
    optimizer opt = create_adamw(policy, cfg.learning_rate)
    
    // 4. 训练
    grpo_trainer trainer = new_grpo_trainer(policy, ref_policy, opt)
    
    int epoch = 0
    while epoch < 10 {
        // 生成样本
        []string prompts = load_prompts()
        
        // 训练一步
        (trainer, grpo_train_result result) = grpo_trainer_train_step(
            trainer,
            prompts
        )
        
        print("Epoch: ", epoch, " Loss: ", result.total_loss)
        epoch = epoch + 1
    }
}
```

### 2. DAPO 训练（数学推理）

DAPO 适合数学和推理任务，使用 top-k 选择：

```s
use neurx.posttrain.alignment.dapo.{dapo_trainer, new_dapo_config}

func train_math_reasoning() {
    // 配置
    dapo_config cfg = new_dapo_config()
    cfg.top_k_trajectories = 64
    cfg.use_self_improvement = true
    cfg.num_iterations = 100
    
    // 模型
    module policy = load_model("Qwen2.5-32B")
    module value_model = create_value_head(policy)
    module reward_model = load_reward_model("math-rm")
    
    // 优化器
    optimizer policy_opt = create_adamw(policy, 1e-5)
    optimizer value_opt = create_adamw(value_model, 3e-5)
    
    // 训练器
    dapo_trainer trainer = dapo_trainer_with_config(
        policy,
        value_model,
        reward_model,
        policy_opt,
        value_opt,
        cfg
    )
    
    // 训练循环
    (trainer, []dapo_train_result results) = dapo_trainer_train(
        trainer,
        cfg.num_iterations
    )
}
```

### 3. PPO 训练（完整版）

PPO 是最经典的算法，需要价值模型：

```s
use neurx.posttrain.alignment.ppo.{ppo_trainer, new_ppo_config}

func train_with_ppo() {
    ppo_config cfg = new_ppo_config()
    cfg.clip_range = 0.2
    cfg.num_epochs = 4
    
    module policy = load_model("Llama-3.1-8B")
    module value_model = create_value_head(policy)
    module ref_policy = load_model("Llama-3.1-8B")
    
    optimizer policy_opt = create_adamw(policy, 1e-5)
    optimizer value_opt = create_adamw(value_model, 3e-5)
    
    ppo_trainer trainer = new_ppo_trainer(
        policy,
        value_model,
        ref_policy,
        policy_opt,
        value_opt
    )
    
    // 训练
    int step = 0
    while step < 1000 {
        (trainer, ppo_train_result result) = ppo_trainer_train_step(trainer)
        step = step + 1
    }
}
```

## 算法选择

### 按任务类型选择

```s
// 数学推理
use neurx.posttrain.alignment.dapo.{dapo_trainer}
use neurx.posttrain.alignment.prime.{prime_step}
use neurx.posttrain.alignment.vapo.{vapo_step}

// 代码生成
use neurx.posttrain.alignment.rloo.{rloo_step}
use neurx.posttrain.reward.verifiable.{verify_code_solution}

// 通用对话
use neurx.posttrain.alignment.grpo.{grpo_trainer}
use neurx.posttrain.alignment.ppo.{ppo_trainer}

// 多模态
use neurx.posttrain.multimodal.vlm_rl.{vlm_grpo_step}
```

### 简单对比

| 算法 | 需要价值模型 | 训练难度 | 性能 | 适用场景 |
|-----|------------|---------|------|---------|
| GRPO | ❌ | 简单 | 中等 | 通用对话 |
| PPO | ✅ | 中等 | 好 | 通用任务 |
| DAPO | ✅ | 中等 | 最好 | 数学推理 |
| RLOO | ❌ | 简单 | 好 | 代码生成 |
| REINFORCE++ | ❌ | 简单 | 中等 | 少样本 |
| PRIME | ✅ | 复杂 | 最好 | 多步推理 |

## 分布式训练

### FSDP 训练（单机多卡）

```s
use neurx.posttrain.backend.fsdp.{new_fsdp_module, new_fsdp_config}
use neurx.distributed.{init_distributed}

func train_with_fsdp() {
    // 初始化分布式
    distributed_context ctx = init_distributed()
    
    // FSDP 配置
    fsdp_config cfg = new_fsdp_config()
    cfg.sharding_strategy = "full_shard"
    cfg.use_mixed_precision = true
    cfg.cpu_offload = false
    
    // 创建模型
    module base_model = load_model("Qwen2.5-14B")
    
    // 包装为 FSDP
    fsdp_module model = new_fsdp_module(base_model, cfg, ctx)
    
    // 训练
    tensor input = load_batch()
    tensor output = fsdp_forward(model, input)
    fsdp_backward(model, output.grad)
}
```

### Megatron 训练（多机多卡）

```s
use neurx.posttrain.backend.megatron.{new_megatron_module, new_megatron_config}

func train_with_megatron() {
    distributed_context ctx = init_distributed()
    
    // Megatron 配置
    megatron_config cfg = new_megatron_config()
    cfg.tensor_parallel_size = 8
    cfg.pipeline_parallel_size = 4
    cfg.use_sequence_parallel = true
    
    // 创建模型
    module base_model = load_model("DeepSeek-V3-671B")
    megatron_module model = new_megatron_module(base_model, cfg, ctx)
    
    // 训练
    tensor output = megatron_pipeline_forward(model, input)
}
```

## 推理优化

### vLLM 推理

```s
use neurx.posttrain.inference.vllm.{new_vllm_engine, vllm_generate}

func inference_with_vllm() {
    // 配置
    vllm_config cfg = new_vllm_config()
    cfg.max_num_seqs = 256
    cfg.gpu_memory_utilization = 0.9
    cfg.block_size = 16
    
    // 创建引擎
    module model = load_model("Qwen2.5-7B")
    vllm_engine engine = new_vllm_engine(model, cfg)
    
    // 批量生成
    [][]int prompts = [
        [1, 2, 3],  // prompt 1
        [4, 5, 6],  // prompt 2
    ]
    
    [][]int outputs = vllm_generate(
        engine,
        prompts,
        max_tokens: 512,
        temperature: 0.7,
        top_p: 0.9
    )
}
```

### SGLang 推理（带缓存）

```s
use neurx.posttrain.inference.sglang.{new_sglang_engine, sglang_generate}

func inference_with_sglang() {
    // 配置
    sglang_config cfg = new_sglang_config()
    cfg.disable_radix_cache = false
    cfg.enable_flashinfer = true
    
    // 创建引擎
    module model = load_model("Qwen2.5-7B")
    sglang_engine engine = new_sglang_engine(model, cfg)
    
    // 生成（自动使用 RadixAttention 缓存）
    [][]int outputs = sglang_generate(
        engine,
        prompts,
        max_tokens: 512,
        temperature: 0.7,
        top_p: 0.9
    )
}
```

## 常见场景

### 场景 1: 数学推理模型训练

```s
use neurx.posttrain.alignment.dapo.{dapo_trainer}
use neurx.posttrain.reward.verifiable.{verify_math_solution}
use neurx.posttrain.tools.data_preprocess.{create_grpo_groups}

func train_math_model() {
    // 1. 准备数据
    []string prompts = load_math_problems()
    
    // 2. 配置 DAPO
    dapo_config cfg = new_dapo_config()
    cfg.top_k_trajectories = 64
    cfg.use_self_improvement = true
    
    // 3. 训练
    dapo_trainer trainer = setup_dapo_trainer(cfg)
    
    int iteration = 0
    while iteration < 100 {
        // 生成多个解答
        [][]string completions = generate_solutions(prompts, num_per_prompt: 8)
        
        // 验证并获得奖励
        [][]float rewards = [][]float{}
        int i = 0
        while i < prompts.len {
            []float rewards_i = []float{}
            int j = 0
            while j < completions[i].len {
                verification_result result = verify_math_solution(
                    problems[i],
                    completions[i][j]
                )
                rewards_i[j] = result.reward
                j = j + 1
            }
            rewards[i] = rewards_i
            i = i + 1
        }
        
        // 训练
        (trainer, dapo_train_result result) = dapo_trainer_train_step(
            trainer,
            create_rollouts(prompts, completions, rewards)
        )
        
        iteration = iteration + 1
    }
}
```

### 场景 2: 代码生成模型训练

```s
use neurx.posttrain.alignment.rloo.{rloo_step}
use neurx.posttrain.reward.verifiable.{verify_code_solution}

func train_code_model() {
    // 准备代码问题
    []code_problem problems = load_code_problems()
    
    int epoch = 0
    while epoch < 50 {
        // 为每个问题生成多个解答
        [][]string solutions = generate_code_solutions(problems, num_samples: 8)
        
        // 验证代码
        [][]float rewards = [][]float{}
        int i = 0
        while i < problems.len {
            []float rewards_i = []float{}
            int j = 0
            while j < solutions[i].len {
                verification_result result = verify_code_solution(
                    problems[i],
                    solutions[i][j]
                )
                rewards_i[j] = result.reward
                j = j + 1
            }
            rewards[i] = rewards_i
            i = i + 1
        }
        
        // RLOO 训练
        rloo_state state = rloo_step(
            policy,
            reference_policy,
            states,
            actions,
            rewards,
            old_log_probs,
            rloo_config
        )
        
        epoch = epoch + 1
    }
}
```

### 场景 3: 多模态模型训练

```s
use neurx.posttrain.multimodal.vlm_rl.{vlm_grpo_step, new_vlm_config}

func train_vision_language_model() {
    // VLM 配置
    vlm_config cfg = new_vlm_config()
    cfg.vision_encoder_dim = 1024
    cfg.freeze_vision_encoder = true
    
    // 准备多模态数据
    []multimodal_input inputs = load_vlm_data()
    
    int step = 0
    while step < 1000 {
        // 生成多个回答（每组4个）
        [][]int actions = generate_vlm_responses(inputs, group_size: 4)
        
        // 获取奖励
        []tensor rewards = evaluate_vlm_responses(inputs, actions)
        
        // VLM-GRPO 训练
        tensor loss = vlm_grpo_step(
            policy,
            reference_policy,
            inputs,
            actions,
            rewards,
            group_size: 4,
            kl_coef: 0.1
        )
        
        // 优化
        loss.backward()
        optimizer.step()
        
        step = step + 1
    }
}
```

### 场景 4: 3D-HybridEngine 训练+推理

```s
use neurx.posttrain.advanced.hybrid_engine.{
    new_hybrid_engine,
    hybrid_engine_switch_to_generation,
    hybrid_engine_switch_to_training
}

func train_with_hybrid_engine() {
    distributed_context ctx = init_distributed()
    
    // Hybrid Engine 配置
    hybrid_engine_config cfg = new_hybrid_engine_config()
    cfg.tensor_parallel_size_train = 8
    cfg.tensor_parallel_size_gen = 4
    
    // 创建引擎
    module model = load_model("Qwen2.5-72B")
    hybrid_engine engine = new_hybrid_engine(model, cfg, ctx)
    
    int iteration = 0
    while iteration < 100 {
        // 切换到生成模式
        hybrid_engine_switch_to_generation(engine)
        
        // 生成样本
        [][]int samples = generate_samples(engine)
        
        // 切换到训练模式
        hybrid_engine_switch_to_training(engine)
        
        // 训练
        train_one_step(engine, samples)
        
        iteration = iteration + 1
    }
}
```

## 最佳实践

### 1. 选择合适的批处理大小

```s
// 小模型（< 10B）
cfg.batch_size = 32
cfg.micro_batch_size = 4

// 中等模型（10B - 70B）
cfg.batch_size = 16
cfg.micro_batch_size = 2

// 大模型（> 70B）
cfg.batch_size = 8
cfg.micro_batch_size = 1
```

### 2. 学习率设置

```s
// 全参数微调
cfg.learning_rate = 1e-5

// LoRA 微调
cfg.learning_rate = 3e-4

// 价值模型
cfg.value_lr = 3e-5
```

### 3. KL 惩罚

```s
// 开始时较小
cfg.kl_coef = 0.02

// 逐渐增加
if avg_kl > target_kl {
    cfg.kl_coef = cfg.kl_coef * 1.5
}
```

## 调试技巧

### 1. 检查奖励分布

```s
func check_rewards([]float rewards) {
    float mean = compute_mean(rewards)
    float std = compute_std(rewards)
    float min_r = compute_min(rewards)
    float max_r = compute_max(rewards)
    
    print("Reward stats:")
    print("  Mean: ", mean)
    print("  Std: ", std)
    print("  Min: ", min_r)
    print("  Max: ", max_r)
}
```

### 2. 监控 KL 散度

```s
if kl_divergence > 0.1 {
    print("Warning: KL divergence too high!")
    // 降低学习率或增加 KL 惩罚
}
```

### 3. 验证梯度

```s
func check_gradients(module model) {
    []tensor grads = model.get_gradients()
    int i = 0
    while i < grads.len {
        float grad_norm = compute_norm(grads[i])
        if grad_norm > 100.0 {
            print("Warning: Large gradient at layer ", i)
        }
        i = i + 1
    }
}
```

## 下一步

- 查看 [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) 了解所有功能
- 查看 [INDEX.s](INDEX.s) 查找具体模块
- 阅读各算法文件了解详细实现
