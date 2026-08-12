package neurx.posttrain.dpo.dpo_step
use neurx.posttrain.dpo.dpo_state
use neurx.loss.dpo_loss
struct dpo_step_result {
    dpo_state state
    float loss
    float reward_margin
    float chosen_reward
    float rejected_reward
}

func dpo_step(dpo_state state, float chosen_logp, float rejected_logp, float ref_chosen_logp, float ref_rejected_logp) dpo_step_result {
    float chosen_reward = state.beta * (chosen_logp - ref_chosen_logp)
    float rejected_reward = state.beta * (rejected_logp - ref_rejected_logp)
    float reward_margin = chosen_reward - rejected_reward
    float loss = dpo_loss_from_margin(reward_margin, state.label_smoothing)
    dpo_step_result {
        state: dpo_state {
            beta: state.beta,
            label_smoothing: state.label_smoothing,
            last_margin: reward_margin,
            last_loss: loss,
            ready: true,
        },
        loss: loss,
        reward_margin: reward_margin,
        chosen_reward: chosen_reward,
        rejected_reward: rejected_reward,
    }
}

func dpo_step_result_state_dict(dpo_step_result result) dpo_step_result {
    result
}

func dpo_step_result_load_state_dict(dpo_step_result result, dpo_step_result other) dpo_step_result {
    other
}

