package neurx.trainer

use neurx.multimodal.multimodal_batch
use neurx.optim_mvp.{sgd_optimizer, adam_optimizer, rmsprop_optimizer, new_sgd, new_adam, new_rmsprop, step_tensor, adam_step, rmsprop_step}
use neurx.tensor.tensor
use neurx.transformer.{transformer_config, transformer_init, transformer_forward}
use neurx.checkpoint.{save_checkpoint, load_checkpoint}
func train_transformer(trainer_config config, tensor[] train_data, tensor[] train_labels) () {
    let model_cfg = transformer_config{
        num_layers: 2,
        num_heads: 2,
        d_model: 4,
        d_ff: 8,
        dropout: 0.1,
    }
    let mut model = transformer_init(model_cfg)
    let mut state = init_state(config)
    let mut step = 0
    let mut best_loss = 1e9
    let max_steps = config.epochs * len(train_data)
    while step < max_steps {
        let x = train_data[step % len(train_data)]
        let y = train_labels[step % len(train_labels)]
        let out = transformer_forward(model, x)
        if step % 100 == 0 {
            save_checkpoint("checkpoint.s", step, 0.0, [])
        }
        step = step + 1
    }
}

struct trainer_config {
    int epochs
    int batch_size
    float learning_rate
    float grad_clip
}

struct trainer_state {
    int step
    float last_loss
    sgd_optimizer optimizer
    adam_optimizer adam
    rmsprop_optimizer rmsprop
}

struct trainer_step_output {
    trainer_state state
    tensor params
}

func new_config(int epochs, int batch_size, float learning_rate, float grad_clip) trainer_config {
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
        adam: new_adam(0.001, 0.9, 0.999, 1e-8),
        rmsprop: new_rmsprop(0.001, 0.99, 1e-8),
    }
}

func init_state(trainer_config config) trainer_state {
    trainer_state {
        step: 0,
        last_loss: 0.0,
        optimizer: new_sgd(config.learning_rate),
        adam: new_adam(config.learning_rate, 0.9, 0.999, 1e-8),
        rmsprop: new_rmsprop(config.learning_rate, 0.99, 1e-8),
    }
}

func train_step(trainer_state state, multimodal_batch batch) trainer_state {
    let next_step = state.step + 1
    let denom = len(batch.token_ids)
    let mut loss = state.last_loss
    if denom > 0 {
        loss = 1.0 / (denom as float)
    }

    trainer_state {
        step: next_step,
        last_loss: loss,
        optimizer: state.optimizer,
        adam: state.adam,
        rmsprop: state.rmsprop,
    }
}

func apply_sgd(trainer_state state, tensor params, tensor grads) trainer_step_output {
    let updated_params = step_tensor(state.optimizer, params, grads)
    trainer_step_output {
        state: state,
        params: updated_params,
    }
}

func apply_adam(trainer_state state, tensor params, tensor grads) trainer_step_output {
    let step_output = adam_step(state.adam, params, grads)
    let next_state = trainer_state {
        step: state.step,
        last_loss: state.last_loss,
        optimizer: state.optimizer,
        adam: step_output.optimizer,
        rmsprop: state.rmsprop,
    }

    trainer_step_output {
        state: next_state,
        params: step_output.params,
    }
}

func apply_rmsprop(trainer_state state, tensor params, tensor grads) trainer_step_output {
    let step_output = rmsprop_step(state.rmsprop, params, grads)
    let next_state = trainer_state {
        step: state.step,
        last_loss: state.last_loss,
        optimizer: state.optimizer,
        adam: state.adam,
        rmsprop: step_output.optimizer,
    }

    trainer_step_output {
        state: next_state,
        params: step_output.params,
    }
}
