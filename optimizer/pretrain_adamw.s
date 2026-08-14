package neurx.optimizer.pretrain_adamw
use neurx.optimizer.optim.{adamw_optimizer, adamw_step_output, adamw_step_state, new_adamw, scale_tensor}
use neurx.scheduler.training_scheduler.{lr_scheduler, new_named_lr_scheduler, scheduler_current_lr, scheduler_load_state_dict, scheduler_state_dict, scheduler_step}
use neurx.tensor.tensor
struct pretrain_optimizer_state {
    adamw_optimizer token_embedding_opt
    adamw_optimizer lm_head_weight_opt
    adamw_optimizer lm_head_bias_opt
    lr_scheduler scheduler
    float max_grad_norm
    int step
    float last_lr
    float last_grad_norm
}

struct pretrain_optimizer_step_state {
    pretrain_optimizer_state optimizer
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    float grad_norm
    float lr
}

func new_pretrain_optimizer_state(float lr, float min_lr, int warmup_steps, int max_steps, float weight_decay, float max_grad_norm) pretrain_optimizer_state {
    pretrain_optimizer_state {
        token_embedding_opt: new_adamw(lr, 0.9, 0.95, 0.00000001, weight_decay),
        lm_head_weight_opt: new_adamw(lr, 0.9, 0.95, 0.00000001, weight_decay),
        lm_head_bias_opt: new_adamw(lr, 0.9, 0.95, 0.00000001, weight_decay),
        scheduler: new_named_lr_scheduler(lr, min_lr, warmup_steps, max_steps, "cosine"),
        max_grad_norm: max_grad_norm,
        step: 0,
        last_lr: lr,
        last_grad_norm: 0.0,
    }
}

func pretrain_optimizer_global_norm3(tensor a, tensor b, tensor c) float {
    float total_sq = 0.0
    int i = 0
    while i < len(a.data) {
        float v = a.data[i]
        total_sq = total_sq + v * v
        i = i + 1
    }
    i = 0
    while i < len(b.data) {
        float v = b.data[i]
        total_sq = total_sq + v * v
        i = i + 1
    }
    i = 0
    while i < len(c.data) {
        float v = c.data[i]
        total_sq = total_sq + v * v
        i = i + 1
    }
    if total_sq <= 0.0 {
        return 0.0
    }
    float guess = total_sq
    if guess < 1.0 {
        guess = 1.0
    }
    int j = 0
    while j < 6 {
        guess = 0.5 * (guess + total_sq / guess)
        j = j + 1
    }
    guess
}

func pretrain_optimizer_scale_for_norm(float grad_norm, float max_grad_norm) float {
    if max_grad_norm <= 0.0 {
        return 1.0
    }
    if grad_norm <= max_grad_norm || grad_norm <= 0.0 {
        return 1.0
    }
    max_grad_norm / grad_norm
}

func pretrain_optimizer_step(pretrain_optimizer_state state, tensor token_embedding, tensor token_embedding_grad, tensor lm_head_weight, tensor lm_head_weight_grad, tensor lm_head_bias, tensor lm_head_bias_grad) pretrain_optimizer_step_state {
    lr_scheduler next_scheduler = scheduler_step(state.scheduler, state.step + 1)
    float current_lr = scheduler_current_lr(next_scheduler)
    tensor clipped_token_grad = token_embedding_grad
    tensor clipped_head_weight_grad = lm_head_weight_grad
    tensor clipped_head_bias_grad = lm_head_bias_grad
    float grad_norm = 0.0
    if state.max_grad_norm > 0.0 {
        grad_norm = pretrain_optimizer_global_norm3(token_embedding_grad, lm_head_weight_grad, lm_head_bias_grad)
        float scale = pretrain_optimizer_scale_for_norm(grad_norm, state.max_grad_norm)
        if scale < 1.0 {
            clipped_token_grad = scale_tensor(token_embedding_grad, scale)
            clipped_head_weight_grad = scale_tensor(lm_head_weight_grad, scale)
            clipped_head_bias_grad = scale_tensor(lm_head_bias_grad, scale)
        }
    } else {
        grad_norm = pretrain_optimizer_global_norm3(token_embedding_grad, lm_head_weight_grad, lm_head_bias_grad)
    }
    adamw_optimizer token_opt = state.token_embedding_opt
    token_opt.lr = current_lr
    adamw_step_output token_step = adamw_step_state(token_opt, token_embedding, clipped_token_grad)
    adamw_optimizer head_opt = state.lm_head_weight_opt
    head_opt.lr = current_lr
    adamw_step_output head_step = adamw_step_state(head_opt, lm_head_weight, clipped_head_weight_grad)
    adamw_optimizer bias_opt = state.lm_head_bias_opt
    bias_opt.lr = current_lr
    adamw_step_output bias_step = adamw_step_state(bias_opt, lm_head_bias, clipped_head_bias_grad)
    pretrain_optimizer_step_state {
        optimizer: pretrain_optimizer_state {
            token_embedding_opt: token_step.optimizer,
            lm_head_weight_opt: head_step.optimizer,
            lm_head_bias_opt: bias_step.optimizer,
            scheduler: next_scheduler,
            max_grad_norm: state.max_grad_norm,
            step: state.step + 1,
            last_lr: current_lr,
            last_grad_norm: grad_norm,
        },
        token_embedding: token_step.params,
        lm_head_weight: head_step.params,
        lm_head_bias: bias_step.params,
        grad_norm: grad_norm,
        lr: current_lr,
    }
}

func pretrain_optimizer_state_dict(pretrain_optimizer_state state) pretrain_optimizer_state {
    pretrain_optimizer_state {
        token_embedding_opt: state.token_embedding_opt,
        lm_head_weight_opt: state.lm_head_weight_opt,
        lm_head_bias_opt: state.lm_head_bias_opt,
        scheduler: scheduler_state_dict(state.scheduler),
        max_grad_norm: state.max_grad_norm,
        step: state.step,
        last_lr: state.last_lr,
        last_grad_norm: state.last_grad_norm,
    }
}

func pretrain_optimizer_load_state_dict(pretrain_optimizer_state state, pretrain_optimizer_state other) pretrain_optimizer_state {
    pretrain_optimizer_state {
        token_embedding_opt: other.token_embedding_opt,
        lm_head_weight_opt: other.lm_head_weight_opt,
        lm_head_bias_opt: other.lm_head_bias_opt,
        scheduler: scheduler_load_state_dict(other.scheduler),
        max_grad_norm: other.max_grad_norm,
        step: other.step,
        last_lr: other.last_lr,
        last_grad_norm: other.last_grad_norm,
    }
}
