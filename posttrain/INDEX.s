package neurx.posttrain.index

// neurx RLHF 完整实现索引
// 这个文件提供所有模块的快速引用

// ============================================
// 1. RL 算法模块
// ============================================

// DAPO - Directed Aligned Policy Optimization
// 用途: 数学推理，SOTA on AIME 2024
// 文件: neurx/posttrain/alignment/dapo/dapo.s
//      neurx/posttrain/alignment/dapo/dapo_trainer.s
use neurx.posttrain.alignment.dapo.{
    dapo_config, dapo_state, dapo_step,
    dapo_trainer, new_dapo_config
}

// ReMax - Relax and Maximize
// 用途: 更好的探索，放松 PPO 约束
// 文件: neurx/posttrain/alignment/remax/remax.s
use neurx.posttrain.alignment.remax.{
    remax_config, remax_state, remax_step,
    new_remax_config
}

// RLOO - REINFORCE Leave One Out
// 用途: 方差减少，多样本策略梯度
// 文件: neurx/posttrain/alignment/rloo/rloo.s
use neurx.posttrain.alignment.rloo.{
    rloo_config, rloo_state, rloo_step,
    new_rloo_config
}

// REINFORCE++
// 用途: 增强版 REINFORCE，多种方差减少
// 文件: neurx/posttrain/alignment/reinforce_pp/reinforce_pp.s
use neurx.posttrain.alignment.reinforce_pp.{
    reinforce_pp_config, reinforce_pp_state,
    reinforce_pp_step, new_reinforce_pp_config
}

// PRIME - PRocess-supervised reward Model
// 用途: 多步推理的密集中间奖励
// 文件: neurx/posttrain/alignment/prime/prime.s
use neurx.posttrain.alignment.prime.{
    prime_config, prime_state, prime_step,
    process_reward_model, new_prime_config
}

// DrGRPO - Divergence-Regularized GRPO
// 用途: 稳定的组相对策略优化
// 文件: neurx/posttrain/alignment/drgrpo/drgrpo.s
use neurx.posttrain.alignment.drgrpo.{
    drgrpo_config, drgrpo_state, drgrpo_step,
    new_drgrpo_config
}

// VAPO - Value-based Augmented Policy Optimization
// 用途: 处理噪声奖励信号，推理任务
// 文件: neurx/posttrain/alignment/vapo/vapo.s
use neurx.posttrain.alignment.vapo.{
    vapo_config, vapo_state, vapo_step,
    new_vapo_config
}

// ============================================
// 2. 训练后端模块
// ============================================

// FSDP - Fully Sharded Data Parallel
// 用途: 大规模分布式训练，全参数分片
// 文件: neurx/posttrain/backend/fsdp/fsdp.s
use neurx.posttrain.backend.fsdp.{
    fsdp_config, fsdp_module, fsdp_state,
    new_fsdp_module, fsdp_forward, fsdp_backward,
    new_fsdp_config
}

// Megatron-LM
// 用途: 超大模型训练，张量并行，流水线并行
// 文件: neurx/posttrain/backend/megatron/megatron.s
use neurx.posttrain.backend.megatron.{
    megatron_config, megatron_module,
    tensor_parallel_state, pipeline_parallel_state,
    new_megatron_module, megatron_pipeline_forward,
    new_megatron_config
}

// ============================================
// 3. 推理引擎模块
// ============================================

// vLLM
// 用途: 快速推理，PagedAttention，连续批处理
// 文件: neurx/posttrain/inference/vllm/vllm.s
use neurx.posttrain.inference.vllm.{
    vllm_config, vllm_engine, vllm_sequence,
    vllm_generate, vllm_paged_attention,
    new_vllm_engine, new_vllm_config
}

// SGLang
// 用途: 结构化生成，RadixAttention，前缀缓存
// 文件: neurx/posttrain/inference/sglang/sglang.s
use neurx.posttrain.inference.sglang.{
    sglang_config, sglang_engine, radix_tree,
    sglang_generate, sglang_radix_attention,
    new_sglang_engine, new_sglang_config
}

// ============================================
// 4. 奖励模型模块
// ============================================

// 可验证奖励
// 用途: 数学和代码任务的自动验证
// 文件: neurx/posttrain/reward/verifiable/verifiable_rewards.s
use neurx.posttrain.reward.verifiable.{
    math_problem, code_problem, verification_result,
    verify_math_solution, verify_code_solution
}

// ============================================
// 5. 多模态模块
// ============================================

// VLM RL - 视觉语言模型强化学习
// 用途: Qwen2.5-VL, Kimi-VL 等多模态模型训练
// 文件: neurx/posttrain/multimodal/vlm_rl/vlm_rl.s
use neurx.posttrain.multimodal.vlm_rl.{
    vlm_config, multimodal_input, vlm_output,
    vlm_forward, vlm_grpo_step,
    new_vlm_config
}

// ============================================
// 6. 高级特性模块
// ============================================

// 3D-HybridEngine
// 用途: 训练-生成高效切换，减少通信开销
// 文件: neurx/posttrain/advanced/hybrid_engine/hybrid_engine.s
use neurx.posttrain.advanced.hybrid_engine.{
    hybrid_engine_config, hybrid_engine,
    hybrid_engine_switch_to_generation,
    hybrid_engine_switch_to_training,
    new_hybrid_engine, new_hybrid_engine_config
}

// ============================================
// 7. 工具模块
// ============================================

// 模型合并
// 用途: 合并多个微调模型
// 文件: neurx/posttrain/tools/model_merger/model_merger.s
use neurx.posttrain.tools.model_merger.{
    merge_config, model_delta,
    merge_models_average, merge_task_arithmetic,
    merge_ties, merge_dare,
    new_merge_config
}

// 数据预处理
// 用途: RL 训练数据准备
// 文件: neurx/posttrain/tools/data_preprocess/data_preprocess.s
use neurx.posttrain.tools.data_preprocess.{
    conversation, rl_sample, preference_pair,
    convert_conversation_to_prompt,
    create_grpo_groups,
    create_preference_pairs_from_rankings,
    format_prompt_with_examples,
    extract_code_from_response
}

// ============================================
// 8. 使用示例
// ============================================

/*
// 示例 1: 使用 DAPO 训练数学推理模型
func train_math_model() {
    dapo_config cfg = new_dapo_config()
    cfg.top_k_trajectories = 64
    cfg.use_self_improvement = true
    
    // 创建训练器
    dapo_trainer trainer = new_dapo_trainer(
        policy,
        value_model,
        reward_model,
        policy_optimizer,
        value_optimizer
    )
    
    // 训练
    (trainer, []dapo_train_result results) = dapo_trainer_train(
        trainer,
        100  // iterations
    )
}

// 示例 2: 使用 vLLM 进行快速推理
func fast_inference() {
    vllm_config cfg = new_vllm_config()
    cfg.max_num_seqs = 256
    cfg.gpu_memory_utilization = 0.9
    
    vllm_engine engine = new_vllm_engine(model, cfg)
    
    [][]int outputs = vllm_generate(
        engine,
        prompts,
        max_tokens,
        temperature,
        top_p
    )
}

// 示例 3: 使用 FSDP 分布式训练
func distributed_training() {
    fsdp_config cfg = new_fsdp_config()
    cfg.sharding_strategy = "full_shard"
    cfg.use_mixed_precision = true
    
    fsdp_module fsdp_model = new_fsdp_module(
        base_model,
        cfg,
        distributed_ctx
    )
    
    tensor output = fsdp_forward(fsdp_model, input)
}

// 示例 4: 多模态 VLM 训练
func train_vlm() {
    vlm_config cfg = new_vlm_config()
    cfg.vision_encoder_dim = 1024
    cfg.freeze_vision_encoder = true
    
    multimodal_input input = multimodal_input {
        image: image_tensor,
        text_tokens: text_ids,
        attention_mask: mask,
        image_positions: [5, 10, 15],
    }
    
    tensor loss = vlm_grpo_step(
        policy,
        reference_policy,
        inputs,
        actions,
        rewards,
        group_size,
        kl_coef
    )
}

// 示例 5: 验证数学解答
func verify_solution() {
    math_problem problem = math_problem {
        question: "What is 2 + 2?",
        answer: "4",
        problem_type: "arithmetic",
    }
    
    verification_result result = verify_math_solution(
        problem,
        "The answer is 4"
    )
    
    if result.correct {
        // Award reward
    }
}
*/

// ============================================
// 9. 算法选择指南
// ============================================

/*
任务类型                    推荐算法
---------------------------------------
数学推理                    DAPO, PRIME, VAPO
代码生成                    RLOO, 可验证奖励
通用对话                    PPO, GRPO, REINFORCE++
多模态理解                  VLM-RL + GRPO
稳定训练                    DrGRPO, VAPO
探索优化                    ReMax
少样本场景                  REINFORCE++
多步推理                    PRIME

模型规模                    后端选择
---------------------------------------
< 10B                      FSDP
10B - 100B                 FSDP + Tensor Parallel
> 100B                     Megatron-LM (TP + PP)
MoE (> 500B)              Megatron-LM

推理需求                    引擎选择
---------------------------------------
高吞吐                      vLLM
前缀复用                    SGLang
结构化生成                  SGLang
通用推理                    vLLM
*/
