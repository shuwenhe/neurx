package neurx.checkpoint

use neurx.tensor.tensor

struct checkpoint {
    int step
    float loss
    tensor[] params
}

func new_checkpoint(int step, float loss, tensor[] params) checkpoint {
    checkpoint {
        step: step,
        loss: loss,
        params: params,
    }
}

func checkpoint_state_dict(checkpoint state) checkpoint {
    state
}

func checkpoint_load_state_dict(checkpoint state, checkpoint other) checkpoint {
    other
}

func save_checkpoint(string path, int step, float loss, tensor[] params) () {
    new_checkpoint(step, loss, params)
}

func load_checkpoint(string path) checkpoint {
    new_checkpoint(0, 0.0, [])
}
