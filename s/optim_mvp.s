package neurx.optim_mvp

use neurx.tensor.tensor
use neurx.tensor.new

struct sgd_optimizer {
    f32 lr
}

func new_sgd(f32 lr) sgd_optimizer {
    sgd_optimizer {
        lr: lr,
    }
}

func step_tensor(sgd_optimizer optimizer, tensor params, tensor grads) tensor {
    let n = len(params.data)
    let mut out = []f32{cap: n}

    for i in 0..n {
        out.push(params.data[i] - optimizer.lr * grads.data[i])
    }

    new(out, params.shape, params.requires_grad)
}
