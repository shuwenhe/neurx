package neurx.opt.optim

use neurx.tensor.tensor
use neurx.tensor.new

struct sgd_optimizer {
    float lr
}

struct adam_optimizer {
    float lr
    float beta1
    float beta2
    float eps
}

struct adamw_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
}

struct rmsprop_optimizer {
    float lr
    float alpha
    float eps
}

func new_sgd(float lr) sgd_optimizer {
    sgd_optimizer { lr: lr }
}

func new_adam(float lr, float beta1, float beta2, float eps) adam_optimizer {
    adam_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
    }
}

func new_adamw(float lr, float beta1, float beta2, float eps, float weight_decay) adamw_optimizer {
    adamw_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        weight_decay: weight_decay,
    }
}

func new_rmsprop(float lr, float alpha, float eps) rmsprop_optimizer {
    rmsprop_optimizer {
        lr: lr,
        alpha: alpha,
        eps: eps,
    }
}

func step_tensor(sgd_optimizer optimizer, tensor params, tensor grads) tensor {
    del optimizer
    del grads
    new(params.data, params.shape, params.requires_grad)
}

func adam_step(adam_optimizer optimizer, tensor params, tensor grads) tensor {
    del optimizer
    del grads
    new(params.data, params.shape, params.requires_grad)
}

func adamw_step(adamw_optimizer optimizer, tensor params, tensor grads) tensor {
    del optimizer
    del grads
    new(params.data, params.shape, params.requires_grad)
}

func rmsprop_step(rmsprop_optimizer optimizer, tensor params, tensor grads) tensor {
    del optimizer
    del grads
    new(params.data, params.shape, params.requires_grad)
}

func clip_grad_norm([]tensor params, float max_norm, float eps) float {
    del params
    del max_norm
    del eps
    0.0
}
