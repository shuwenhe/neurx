package neurx.main
use neurx.multimodal.multimodal_batch
use neurx.optimizer.optim_mvp.{sgd_optimizer, adam_optimizer, rmsprop_optimizer, adam_step_output, rmsprop_step_output, new_sgd, new_adam, new_rmsprop, step_tensor, adam_step, rmsprop_step}
use neurx.tensor.tensor
use neurx.transformer.{transformer_config, transformer_init, transformer_forward}
use neurx.checkpoint.{checkpoint, new_checkpoint, checkpoint_state_dict, checkpoint_load_state_dict, save_checkpoint, load_checkpoint}

func copy_float(float[] data) float[] {
    int n = len(data)
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int(int[] data) int[] {
    int n = len(data)
    int[] out = int[]{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
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

struct trainer_session {
    trainer_config config
    trainer_state state
    example sample
}

struct trainer_snapshot {
    trainer_session session
    checkpoint checkpoint_state
}

struct trainer_pipeline {
    trainer_session session
    trainer_snapshot snapshot
}

func new_config(int epochs, int batch_size, float learning_rate, float grad_clip) trainer_config {
    trainer_config {
        epochs: epochs,
        batch_size: batch_size,
        learning_rate: learning_rate,
        grad_clip grad_clip
    }
}

func new_state() trainer_state {
    trainer_state {
        step: 0,
        last_loss: 0.0,
        optimizer: new_sgd(0.001),
        adam: new_adam(0.001, 0.9, 0.999, 0.00000001),
        rmsprop: new_rmsprop(0.001, 0.99, 0.00000001)
    }
}

func init_state(trainer_config config) trainer_state {
    trainer_state {
        step: 0,
        last_loss: 0.0,
        optimizer: new_sgd(config.learning_rate),
        adam: new_adam(config.learning_rate, 0.9, 0.999, 0.00000001),
        rmsprop: new_rmsprop(config.learning_rate, 0.99, 0.00000001)
    }
}

func trainer_state_dict(trainer_state state) trainer_state {
    trainer_state {
        step: state.step,
        last_loss: state.last_loss,
        optimizer: state.optimizer,
        adam: state.adam,
        rmsprop: state.rmsprop,
    }
}

func trainer_load_state_dict(trainer_state state, trainer_state other) trainer_state {
    trainer_state {
        step: other.step,
        last_loss: other.last_loss,
        optimizer: other.optimizer,
        adam: other.adam,
        rmsprop: other.rmsprop,
    }
}

func trainer_step_output_state_dict(trainer_step_output state) trainer_step_output {
    trainer_step_output {
        state: trainer_state_dict(state.state),
        params: state.params,
    }
}

func trainer_step_output_load_state_dict(trainer_step_output state, trainer_step_output other) trainer_step_output {
    trainer_step_output {
        state: trainer_load_state_dict(state.state, other.state),
        params: other.params,
    }
}

func new_trainer_session(trainer_config config, trainer_state state, example sample) trainer_session {
    trainer_session {
        config: config,
        state: state,
        sample: sample,
    }
}

func trainer_session_state_dict(trainer_session session) trainer_session {
    trainer_session {
        config: session.config,
        state: session.state,
        sample: example_state_dict(session.sample),
    }
}

func trainer_session_load_state_dict(trainer_session session, trainer_session other) trainer_session {
    trainer_session {
        config: other.config,
        state: trainer_load_state_dict(session.state, other.state),
        sample: example_load_state_dict(session.sample, other.sample),
    }
}

func empty_tensor_params() []tensor {
    []tensor params = []tensor{cap: 0}
    params
}

func new_trainer_snapshot(trainer_session session) trainer_snapshot {
    trainer_snapshot {
        session: session,
        checkpoint_state: new_checkpoint(session.state.step, session.state.last_loss, empty_tensor_params()),
    }
}

func new_trainer_checkpoint(int step, float loss, []tensor params) checkpoint {
    new_checkpoint(step, loss, params)
}

func save_trainer_checkpoint(string path, int step, float loss, []tensor params) checkpoint {
    save_checkpoint(path, step, loss, params)
}

func load_trainer_checkpoint(string path) checkpoint {
    load_checkpoint(path)
}

func save_trainer_session_checkpoint(string path, trainer_session session) checkpoint {
    save_checkpoint(path, session.state.step, session.state.last_loss, empty_tensor_params())
}

func load_trainer_session_checkpoint(string path) trainer_snapshot {
    checkpoint ckpt = load_checkpoint(path)
    trainer_session session = trainer_session {
        config: new_config(0, 0, 0.0, 0.0),
        state: new_state(),
        sample: example {
            data: float[]{cap: 0},
            shape: int[]{cap: 0},
        },
    }
    trainer_snapshot {
        session: session,
        checkpoint_state: ckpt,
    }
}

func trainer_snapshot_state_dict(trainer_snapshot state) trainer_snapshot {
    trainer_snapshot {
        session: trainer_session_state_dict(state.session),
        checkpoint_state: checkpoint_state_dict(state.checkpoint_state),
    }
}

func trainer_snapshot_load_state_dict(trainer_snapshot state, trainer_snapshot other) trainer_snapshot {
    trainer_snapshot {
        session: trainer_session_load_state_dict(state.session, other.session),
        checkpoint_state: checkpoint_load_state_dict(state.checkpoint_state, other.checkpoint_state),
    }
}

func run_trainer_snapshot(trainer_session session, multimodal_batch batch) trainer_snapshot {
    trainer_state next_state = train_step(session.state, batch)
    trainer_snapshot {
        session: trainer_session {
            config: trainer_config_state_dict(session.config),
            state: next_state,
            sample: process_example(session.sample),
        },
        checkpoint_state: new_checkpoint(next_state.step, next_state.last_loss, empty_tensor_params()),
    }
}

func new_trainer_pipeline(trainer_session session) trainer_pipeline {
    trainer_pipeline {
        session: session,
        snapshot: new_trainer_snapshot(session),
    }
}

func trainer_pipeline_state_dict(trainer_pipeline pipeline) trainer_pipeline {
    trainer_pipeline {
        session: trainer_session_state_dict(pipeline.session),
        snapshot: trainer_snapshot_state_dict(pipeline.snapshot),
    }
}

func trainer_pipeline_load_state_dict(trainer_pipeline pipeline, trainer_pipeline other) trainer_pipeline {
    trainer_pipeline {
        session: trainer_session_load_state_dict(pipeline.session, other.session),
        snapshot: trainer_snapshot_load_state_dict(pipeline.snapshot, other.snapshot),
    }
}

func run_training_pipeline(trainer_pipeline pipeline, multimodal_batch batch) trainer_pipeline {
    trainer_snapshot next_snapshot = run_trainer_snapshot(pipeline.session, batch)
    trainer_pipeline {
        session: next_snapshot.session,
        snapshot: next_snapshot,
    }
}

func stop_trainer_pipeline(trainer_pipeline pipeline) trainer_pipeline {
    trainer_pipeline {
        session: pipeline.session,
        snapshot: pipeline.snapshot,
    }
}

func resume_trainer_pipeline(trainer_pipeline pipeline) trainer_pipeline {
    trainer_pipeline {
        session: pipeline.session,
        snapshot: pipeline.snapshot,
    }
}

func pipeline_checkpoint(trainer_pipeline pipeline) checkpoint {
    checkpoint_state_dict(pipeline.snapshot.checkpoint_state)
}

func save_training_pipeline_checkpoint(string path, trainer_pipeline pipeline) checkpoint {
    save_checkpoint(path, pipeline.snapshot.checkpoint_state.step, pipeline.snapshot.checkpoint_state.loss, empty_tensor_params())
}

func load_training_pipeline_checkpoint(string path) trainer_pipeline {
    trainer_snapshot snapshot = load_trainer_session_checkpoint(path)
    trainer_pipeline {
        session: snapshot.session,
        snapshot: snapshot,
    }
}

func trainer_config_state_dict(trainer_config config) trainer_config {
    trainer_config {
        epochs: config.epochs,
        batch_size: config.batch_size,
        learning_rate: config.learning_rate,
        grad_clip: config.grad_clip,
    }
}

func trainer_config_load_state_dict(trainer_config config, trainer_config other) trainer_config {
    trainer_config {
        epochs: other.epochs,
        batch_size: other.batch_size,
        learning_rate: other.learning_rate,
        grad_clip: other.grad_clip,
    }
}

func train_step(trainer_state state, multimodal_batch batch) trainer_state {
    int next_step = state.step + 1
    int denom = len(batch.token_ids)
    float loss = state.last_loss
    if denom > 0 {
        loss = 1.0 / (denom as float)
    }
    trainer_state {
        step: next_step,
        last_loss: loss,
        optimizer: state.optimizer,
        adam: state.adam,
        rmsprop: state.rmsprop
    }
}

func apply_sgd(trainer_state state, tensor params, tensor grads) trainer_step_output {
    tensor updated_params = step_tensor(state.optimizer, params, grads)
    trainer_step_output {
        state: state,
        updated_params params
    }
}

func apply_adam(trainer_state state, tensor params, tensor grads) trainer_step_output {
    adam_step_output step_output = adam_step(state.adam, params, grads)
    trainer_state next_state = trainer_state {
        step: state.step,
        last_loss: state.last_loss,
        optimizer: state.optimizer,
        adam: step_output.optimizer,
        rmsprop: state.rmsprop
    }
    trainer_step_output {
        state: next_state,
        params: step_output.params
    }
}

func apply_rmsprop(trainer_state state, tensor params, tensor grads) trainer_step_output {
    rmsprop_step_output step_output = rmsprop_step(state.rmsprop, params, grads)
    trainer_state next_state = trainer_state {
        step: state.step,
        last_loss: state.last_loss,
        optimizer: state.optimizer,
        adam: state.adam,
        rmsprop: step_output.optimizer
    }
    trainer_step_output {
        state: next_state,
        params: step_output.params
    }
}

struct example {
    float[] data
    int[] shape
}

func new_example(float[] data, int[] shape) example {
    int n = len(data)
    float[] out = float[]{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    example {
        data: out,
        shape: shape,
    }
}

func process_example(example ex) example {
    int n = len(ex.data)
    float[] processed = float[]{cap: n}
    for i in 0..n {
        processed[i] = ex.data[i] * 2.0
    }
    example {
        data: processed,
        shape: copy_int(ex.shape),
    }
}

func example_state_dict(example ex) example {
    example {
        data: copy_float(ex.data),
        shape: copy_int(ex.shape),
    }
}

func example_load_state_dict(example ex, example other) example {
    example {
        data: copy_float(other.data),
        shape: copy_int(other.shape),
    }
}
