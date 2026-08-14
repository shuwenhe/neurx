package neurx.posttrain.alignment.dapo.trainer
use neurx.posttrain.alignment.dapo.{
    dapo_config, dapo_state, dapo_rollout_result,
    dapo_step, dapo_select_top_k_trajectories, new_dapo_config
}
use neurx.nn.{module, optimizer}
use neurx.tensor.{tensor}
struct dapo_trainer {
    module policy
    module value_model
    module reward_model
    optimizer policy_optimizer
    optimizer value_optimizer
    dapo_config config
    int global_step
    []dapo_state history
}

struct dapo_train_result {
    dapo_state state
    float avg_reward
    float max_reward
    float policy_loss
    float value_loss
    float kl_divergence
    int num_correct
}

func new_dapo_trainer(
    module policy,
    module value_model,
    module reward_model,
    optimizer policy_opt,
    optimizer value_opt
) dapo_trainer {
    dapo_trainer {
        policy: policy,
        value_model: value_model,
        reward_model: reward_model,
        policy_optimizer: policy_opt,
        value_optimizer: value_opt,
        config: new_dapo_config(),
        global_step: 0,
        history: []dapo_state{cap: 1000},
    }
}

func dapo_trainer_with_config(
    module policy,
    module value_model,
    module reward_model,
    optimizer policy_opt,
    optimizer value_opt,
    dapo_config cfg
) dapo_trainer {
    dapo_trainer {
        policy: policy,
        value_model: value_model,
        reward_model: reward_model,
        policy_optimizer: policy_opt,
        value_optimizer: value_opt,
        config: cfg,
        global_step: 0,
        history: []dapo_state{cap: 1000},
    }
}

func dapo_trainer_train_step(
    dapo_trainer trainer,
    dapo_rollout_result rollouts
) (dapo_trainer, dapo_train_result) {
    dapo_rollout_result selected_rollouts = rollouts
    if trainer.config.use_self_improvement {
        selected_rollouts = dapo_select_top_k_trajectories(
            rollouts,
            trainer.config.top_k_trajectories
        )
    }
    int epoch = 0
    dapo_state final_state = dapo_state{}
    while epoch < trainer.config.num_epochs {
        dapo_state state = dapo_step(
            trainer.policy,
            trainer.value_model,
            selected_rollouts,
            trainer.config
        )
        state.iteration = trainer.global_step
        tensor total_loss_tensor = tensor{
            data: [state.total_loss],
            shape: [1],
            dtype: "float32",
        }
        trainer.policy_optimizer.zero_grad()
        total_loss_tensor.backward()
        trainer.policy_optimizer.clip_grad_norm(trainer.config.max_grad_norm)
        trainer.policy_optimizer.step()
        trainer.value_optimizer.zero_grad()
        tensor value_loss_tensor = tensor{
            data: [state.value_loss],
            shape: [1],
            dtype: "float32",
        }
        value_loss_tensor.backward()
        trainer.value_optimizer.clip_grad_norm(trainer.config.max_grad_norm)
        trainer.value_optimizer.step()
        final_state = state
        trainer.global_step = trainer.global_step + 1
        epoch = epoch + 1
    }
    trainer.history[trainer.global_step % 1000] = final_state
    dapo_train_result result = dapo_train_result {
        state: final_state,
        avg_reward: selected_rollouts.avg_reward,
        max_reward: selected_rollouts.max_reward,
        policy_loss: final_state.policy_loss,
        value_loss: final_state.value_loss,
        kl_divergence: final_state.kl_divergence,
        num_correct: selected_rollouts.num_correct,
    }
    (trainer, result)
}

func dapo_trainer_train(
    dapo_trainer trainer,
    int num_iterations
) (dapo_trainer, []dapo_train_result) {
    []dapo_train_result results = []dapo_train_result{cap: num_iterations}
    int iteration = 0
    while iteration < num_iterations {
        dapo_rollout_result rollouts = dapo_rollout_result {
            states: []tensor{},
            actions: []tensor{},
            rewards: []tensor{},
            log_probs: []tensor{},
            values: []tensor{},
            dones: []bool{},
            avg_reward: 0.0,
            max_reward: 0.0,
            num_correct: 0,
        }
        (trainer, dapo_train_result result) = dapo_trainer_train_step(
            trainer,
            rollouts
        )
        results[iteration] = result
        iteration = iteration + 1
    }
    (trainer, results)
}
