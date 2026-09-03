package neurx.optimizer.swa_utils
use neurx.tensor.tensor
use neurx.tensor.new
struct averaged_model_state {
    tensor averaged_params
    int num_averaged
    string avg_mode
    float ema_decay
}

func new_averaged_model(tensor initial_params, string avg_mode, float ema_decay) averaged_model_state {
    averaged_model_state {
        averaged_params: initial_params,
        num_averaged: 0,
        avg_mode: avg_mode,
        ema_decay: ema_decay,
    }
}

func update_averaged_model(averaged_model_state state, tensor model_params) averaged_model_state {
    int n = len(model_params.data)
    []float out = make([]float, n)
    if state.num_averaged == 0 {
        int i0 = 0
        for i0 < n {
            out[i0] = model_params.data[i0]
            i0 = i0 + 1
        }
        state.averaged_params = new(out, model_params.shape, false)
        state.num_averaged = 1
        return state
    }
    if state.avg_mode == "ema" {
        float d = state.ema_decay
        int i1 = 0
        for i1 < n {
            out[i1] = state.averaged_params.data[i1] * d + model_params.data[i1] * (1.0 - d)
            i1 = i1 + 1
        }
    } else {
        float t = float(state.num_averaged)
        int i2 = 0
        for i2 < n {
            out[i2] = (state.averaged_params.data[i2] * t + model_params.data[i2]) / (t + 1.0)
            i2 = i2 + 1
        }
    }
    state.averaged_params = new(out, model_params.shape, false)
    state.num_averaged = state.num_averaged + 1
    return state
}

func averaged_model_parameters(averaged_model_state state) tensor {
    return state.averaged_params
}
