package neurx.posttrain
use neurx.reasoning.data
use neurx.posttrain.config
use neurx.posttrain.data
use neurx.posttrain.reward
use neurx.posttrain.loop
use neurx.posttrain.rlhf.ppo
use neurx.posttrain.dpo.dpo_state
use neurx.posttrain.dpo.dpo_step
use neurx.train.loop.{training_pipeline_state}
func new_default_posttrain_pipeline(string dataset_name, string sample_mode, string reward_model, string run_name, string root) posttrain_pipeline_state {
    posttrain_config cfg = new_posttrain_config()
    posttrain_data_state data = new_posttrain_data_state(dataset_name, sample_mode)
    reward_state reward = new_reward_state(reward_model)
    new_posttrain_pipeline_state(cfg, data, reward, run_name, root)
}
func reasoning_sample_mode_to_stage(string sample_mode) string {
    if sample_mode == "preference" {
        return "dpo"
    }
    if sample_mode == "ppo" {
        return "ppo"
    }
    "sft"
}
func reasoning_trace_to_posttrain_data(reasoning_trace_dataset_state traces, string sample_mode) posttrain_data_state {
    int source_size = reasoning_trace_dataset_count(traces)
    posttrain_data_state data = new_reasoning_posttrain_data_state(traces.source, sample_mode, source_size)
    posttrain_data_mark_source(data, "reasoning_trace", source_size)
}
func new_reasoning_posttrain_pipeline(reasoning_trace_dataset_state traces, string sample_mode, string reward_model, string run_name, string root) posttrain_pipeline_state {
    posttrain_config cfg = with_stage(new_posttrain_config(), reasoning_sample_mode_to_stage(sample_mode))
    posttrain_data_state data = reasoning_trace_to_posttrain_data(traces, sample_mode)
    reward_state reward = new_reward_state(reward_model)
    new_posttrain_pipeline_state(cfg, data, reward, run_name, root)
}
func posttrain_step_from_inputs(posttrain_pipeline_state state, float reward_value, float kl_value, float margin, float policy_loss, float value_loss, int samples) posttrain_pipeline_state {
    int effective_samples = samples
    if effective_samples <= 0 {
        effective_samples = state.loop.cfg.micro_batch_size
    }
    posttrain_pipeline_step(state, reward_value, kl_value, margin, policy_loss, value_loss, effective_samples)
}
func posttrain_step_from_train(posttrain_pipeline_state state, training_pipeline_state train_state, float reward_scale, float kl_value, float margin) posttrain_pipeline_state {
    float policy_loss = train_state.last_loss
    float value_loss = train_state.last_loss * 0.5
    float reward_value = train_state.metrics.score * reward_scale
    int samples = train_state.metrics.valid_tokens
    if samples <= 0 {
        samples = state.loop.cfg.micro_batch_size
    }
    posttrain_pipeline_step(state, reward_value, kl_value, margin, policy_loss, value_loss, samples)
}
func posttrain_step_with_ppo(posttrain_pipeline_state state, ppo_state ppo, float old_logp, float new_logp, float reward_value, float value_pred, float value_target, float margin, int samples) posttrain_pipeline_state {
    ppo_step_result ppo_result = ppo_step(
        ppo,
        old_logp,
        new_logp,
        reward_value,
        value_pred,
        value_target,
        ppo.kl_coef
    )
    int effective_samples = samples
    if effective_samples <= 0 {
        effective_samples = state.loop.cfg.micro_batch_size
    }
    posttrain_pipeline_step(
        state,
        reward_value,
        ppo_result.state.last_kl,
        margin,
        ppo_result.policy_loss,
        ppo_result.value_loss,
        effective_samples
    )
}
func posttrain_step_with_dpo(posttrain_pipeline_state state, dpo_state dpo, float chosen_logp, float rejected_logp, float ref_chosen_logp, float ref_rejected_logp, int samples) posttrain_pipeline_state {
    dpo_step_result dpo_result = dpo_step(
        dpo,
        chosen_logp,
        rejected_logp,
        ref_chosen_logp,
        ref_rejected_logp
    )
    int effective_samples = samples
    if effective_samples <= 0 {
        effective_samples = state.loop.cfg.micro_batch_size
    }
    posttrain_pipeline_step(
        state,
        dpo_result.reward_margin,
        0.0,
        dpo_result.reward_margin,
        dpo_result.loss,
        0.0,
        effective_samples
    )
}
func run_posttrain_steps(posttrain_pipeline_state state, int steps) posttrain_pipeline_state {
    int total = steps
    if total < 0 {
        total = 0
    }
    posttrain_pipeline_state current = state
    int i = 0
    while i < total {
        current = posttrain_step_from_inputs(
            current,
            current.metrics.reward,
            current.loop.cfg.kl_coef,
            0.0,
            current.metrics.policy_loss,
            current.metrics.value_loss,
            current.loop.cfg.micro_batch_size
        )
        if current.loop.finished {
            return current
        }
        i = i + 1
    }
    current
}
func posttrain_pipeline_finished(posttrain_pipeline_state state) bool {
    state.loop.finished
}
func posttrain_pipeline_step_count(posttrain_pipeline_state state) int {
    state.loop.global_step
}
func posttrain_pipeline_last_objective(posttrain_pipeline_state state) float {
    state.metrics.objective
}
func posttrain_pipeline_last_reward(posttrain_pipeline_state state) float {
    state.metrics.reward
}
func posttrain_pipeline_last_policy_loss(posttrain_pipeline_state state) float {
    state.metrics.policy_loss
}
func posttrain_pipeline_last_value_loss(posttrain_pipeline_state state) float {
    state.metrics.value_loss
}
func posttrain_pipeline_state_dict(posttrain_pipeline_state state) posttrain_pipeline_state {
    state
}
func posttrain_pipeline_load_state_dict(posttrain_pipeline_state state, posttrain_pipeline_state other) posttrain_pipeline_state {
    other
}
