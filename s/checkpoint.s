package neurx.checkpoint

use neurx.tensor.tensor
use neurx.tensor.new

func _copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _copy_tensor(tensor value) tensor {
    new(_copy_float(value.data), _copy_int(value.shape), value.requires_grad)
}

func _copy_params(tensor[] params) tensor[] {
    int n = len(params)
    []tensor out = []tensor{cap: n}
    int i = 0
    while i < n {
        out[i] = _copy_tensor(params[i])
        i = i + 1
    }
    out
}

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
    checkpoint {
        step: state.step,
        loss: state.loss,
        params: _copy_params(state.params),
    }
}

func checkpoint_load_state_dict(checkpoint state, checkpoint other) checkpoint {
    checkpoint {
        step: other.step,
        loss: other.loss,
        params: _copy_params(other.params),
    }
}

func save_checkpoint(string path, int step, float loss, tensor[] params) () {
    del path
    new_checkpoint(step, loss, params)
}

func load_checkpoint(string path) checkpoint {
    del path
    new_checkpoint(0, 0.0, [])
}
