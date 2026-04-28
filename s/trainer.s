package neurx.trainer

use neurx.multimodal.multimodal_batch

struct trainer_config {
    int32 epochs
    int32 batch_size
    f32 learning_rate
    f32 grad_clip
}

struct trainer_state {
    int32 step
    f32 last_loss
}

func new_config(int32 epochs, int32 batch_size, f32 learning_rate, f32 grad_clip) trainer_config {
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
    }
}
