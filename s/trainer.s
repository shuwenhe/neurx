package neurx.trainer

use neurx.multimodal.multimodal_batch
use neurx.optim_mvp.{sgd_optimizer, new_sgd, step_tensor}
use neurx.tensor.tensor

struct trainer_config {
    int epochs
    int batch_size
    f32 learning_rate
    f32 grad_clip
}

struct trainer_state {
    int step
    f32 last_loss
    sgd_optimizer optimizer
}

struct trainer_step_output {
    trainer_state state
    tensor params
}

func new_config(int epochs, int batch_size, f32 learning_rate, f32 grad_clip) trainer_config {
    trainer_config {
        epochs: epochs,
        batch_size: batch_size,
        learning_rate: learning_rate,
        grad_clip: grad_clip,
    }
}

func new_state() trainer_state {
    trainer_state {
        step: 0,
        last_loss: 0.0,
        optimizer: new_sgd(0.001),
    }
}

func init_state(trainer_config config) trainer_state {
    trainer_state {
        step: 0,
        last_loss: 0.0,
        optimizer: new_sgd(config.learning_rate),
    }
}

func train_step(trainer_state state, multimodal_batch batch) trainer_state {
    let next_step = state.step + 1
    let denom = len(batch.token_ids)
    let mut loss = state.last_loss
    if denom > 0 {
        loss = 1.0 / (denom as f32)
    }

    trainer_state {
        step: next_step,
        last_loss: loss,
        optimizer: state.optimizer,
    }
}

func apply_sgd(trainer_state state, tensor params, tensor grads) trainer_step_output {
    let updated_params = step_tensor(state.optimizer, params, grads)
    trainer_step_output {
        state: state,
        params: updated_params,
    }
}
