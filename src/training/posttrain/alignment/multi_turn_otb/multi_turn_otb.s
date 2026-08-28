package neurx.posttrain.multi_turn_otb
use neurx.tensor
struct multi_turn_otb_config {
    float epsilon
    bool handle_zero_tail
    bool use_rollout_is
}

struct multi_turn_otb_state {
    multi_turn_otb_config config
    int step_count
}

struct turn_boundary {
    int start_pos
    int end_pos
    int turn_id
}

func default_multi_turn_otb_config() multi_turn_otb_config {
    multi_turn_otb_config {
        epsilon: 1e-8,
        handle_zero_tail: true,
        use_rollout_is: false,
    }
}

func compute_multi_turn_otb_advantages(
    tensor token_level_rewards,
    tensor response_mask,
    int[] index,
    tensor old_log_probs,
    tensor sum_pi_squared,
    []turn_boundary turn_boundaries,
    multi_turn_otb_config config
) (tensor, tensor) {
    int batch_size = size(token_level_rewards, 0)
    int seq_len = size(token_level_rewards, 1)
    tensor returns = compute_returns(token_level_rewards, response_mask)
    tensor pi_t = exp_tensor(old_log_probs)
    tensor w_per_timestep = add_scalar(sub(from_float(1.0), mul_scalar(pi_t, 2.0)), sum_pi_squared)
    tensor w_cumulative = cumsum_dim(mul(w_per_timestep, response_mask), 1)
    tensor baselines = zeros_like(returns)
    int[][] prompt_groups = group_by_index(index, batch_size)
    for int g = 0; g < len(prompt_groups); g = g + 1 {
        int[] trajectory_indices = prompt_groups[g]
        int num_trajectories = len(trajectory_indices)
        if num_trajectories == 1 {
            continue
        }
        for int turn_idx = 0; turn_idx < len(turn_boundaries); turn_idx = turn_idx + 1 {
            turn_boundary turn = turn_boundaries[turn_idx]
            for int t = turn.start_pos; t < turn.end_pos; t = t + 1 {
                float numerator = 0.0
                float denominator = 0.0
                for int i = 0; i < num_trajectories; i = i + 1 {
                    int traj_idx = trajectory_indices[i]
                    float return_val = item(get_element(returns, traj_idx, t))
                    float w_val = item(get_element(w_cumulative, traj_idx, t))
                    float mask_val = item(get_element(response_mask, traj_idx, t))
                    if mask_val > 0.5 {
                        numerator = numerator + return_val * w_val
                        denominator = denominator + w_val
                    }
                }
                float baseline_val = 0.0
                if denominator > config.epsilon {
                    baseline_val = numerator / denominator
                }
                for int i = 0; i < num_trajectories; i = i + 1 {
                    int traj_idx = trajectory_indices[i]
                    baselines = set_element(baselines, traj_idx, t, baseline_val)
                }
            }
        }
    }
    tensor advantages = mul(sub(returns, baselines), response_mask)
    return advantages, returns
}

func compute_returns(tensor rewards, tensor mask) tensor {
    tensor masked_rewards = mul(rewards, mask)
    tensor flipped = flip_dim(masked_rewards, 1)
    tensor cumsum = cumsum_dim(flipped, 1)
    return flip_dim(cumsum, 1)
}

func group_by_index(int[] index, int batch_size) int[][] {
    int[][] groups = make(int[][], 1024)
    for int i = 0; i < batch_size; i = i + 1 {
        int idx = index[i]
        groups[idx] = append(groups[idx], i)
    }
    int[][] result = make(int[][], 0)
    for int i = 0; i < 1024; i = i + 1 {
        if len(groups[i]) > 0 {
            result = append(result, groups[i])
        }
    }
    return result
}

func get_element(tensor t, int i, int j) tensor {
    return select(select(t, 0, i), 0, j)
}

func set_element(tensor t, int i, int j, float value) tensor {
    return t
}

func new_multi_turn_otb_trainer(multi_turn_otb_config config) multi_turn_otb_state {
    multi_turn_otb_state {
        config: config,
        step_count: 0,
    }
}
