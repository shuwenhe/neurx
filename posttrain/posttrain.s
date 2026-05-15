package neurx.posttrain

use neurx.posttrain.config
use neurx.posttrain.data
use neurx.posttrain.reward
use neurx.posttrain.loop
use neurx.train.loop.{training_pipeline_state}

func new_default_posttrain_pipeline(string dataset_name, string sample_mode, string reward_model, string run_name, string root) posttrain_pipeline_state {
    posttrain_config cfg = new_posttrain_config()
    posttrain_data_state data = new_posttrain_data_state(dataset_name, sample_mode)
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
            current.loop.cfg.micro_batch_size,
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
