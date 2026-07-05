package neurx.opt.optimizer

use neurx.tensor.tensor
use neurx.opt.optim
use neurx.opt.scheduler

struct optimizer_param_group {
    []tensor params
    float lr
    float weight_decay
    float beta1
    float beta2
    float eps
    string kind
}

struct optimizer {
    string kind
    int step
    []optimizer_param_group param_groups
    lr_scheduler scheduler
    bool has_scheduler
}

func copy_tensors([]tensor values) []tensor {
    []tensor out = []tensor{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = neurx.tensor.clone(values[i])
        i = i + 1
    }
    return out
}

func copy_float([]float data) []float {
    []float out = []float{cap: len(data)}
    int i = 0
    while i < len(data) {
        out[i] = data[i]
        i = i + 1
    }
    return out
}

func copy_int([]int data) []int {
    []int out = []int{cap: len(data)}
    int i = 0
    while i < len(data) {
        out[i] = data[i]
        i = i + 1
    }
    return out
}

func copy_param_groups([]optimizer_param_group groups) []optimizer_param_group {
    []optimizer_param_group out = []optimizer_param_group{cap: len(groups)}
    int i = 0
    while i < len(groups) {
        out[i] = optimizer_param_group {
            params: copy_tensors(groups[i].params),
            lr: groups[i].lr,
            weight_decay: groups[i].weight_decay,
            beta1: groups[i].beta1,
            beta2: groups[i].beta2,
            eps: groups[i].eps,
            kind: groups[i].kind,
        }
        i = i + 1
    }
    return out
}

func new_optimizer() optimizer {
    return optimizer {
        kind: "none",
        step: 0,
        param_groups: []optimizer_param_group{cap: 0},
        scheduler: new_lr_scheduler(0.0),
        has_scheduler: false,
    }
}

func optimizer_make_group([]tensor params, float lr, float weight_decay, float beta1, float beta2, float eps, string kind) optimizer_param_group {
    return optimizer_param_group {
        params: copy_tensors(params),
        lr: lr,
        weight_decay: weight_decay,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        kind: kind,
    }
}

func optimizer_with_group(optimizer opt, optimizer_param_group group) optimizer {
    optimizer next = optimizer_state_dict(opt)
    next.param_groups.push(group)
    if next.kind == "none" {
        next.kind = group.kind
    }
    return next
}

func optimizer_add_param_group(optimizer opt, []tensor params, float lr, float weight_decay, float beta1, float beta2, float eps, string kind) optimizer {
    return optimizer_with_group(opt, optimizer_make_group(params, lr, weight_decay, beta1, beta2, eps, kind))
}

func optimizer_set_scheduler(optimizer opt, lr_scheduler sched) optimizer {
    optimizer next = optimizer_state_dict(opt)
    next.scheduler = scheduler_state_dict(sched)
    next.has_scheduler = true
    return next
}

func optimizer_step_scheduler(optimizer opt, int epoch) optimizer {
    if !opt.has_scheduler {
        return opt
    }
    optimizer next = optimizer_state_dict(opt)
    next.scheduler = scheduler_step(next.scheduler, epoch)
    float lr = scheduler_current_lr(next.scheduler)
    int i = 0
    while i < len(next.param_groups) {
        next.param_groups[i].lr = lr
        i = i + 1
    }
    return next
}

func optimizer_sync_group_lrs(optimizer opt, float lr) optimizer {
    optimizer next = optimizer_state_dict(opt)
    int i = 0
    while i < len(next.param_groups) {
        next.param_groups[i].lr = lr
        i = i + 1
    }
    return next
}

func optimizer_current_lr(optimizer opt) float {
    if opt.has_scheduler {
        return scheduler_current_lr(opt.scheduler)
    }
    if len(opt.param_groups) > 0 {
        return opt.param_groups[0].lr
    }
    return 0.0
}

func optimizer_zero_grad_tensor(tensor value) tensor {
    return tensor {
        data: copy_float(value.data),
        shape: copy_int(value.shape),
        requires_grad: value.requires_grad,
        grad: none,
    }
}

func optimizer_zero_grad_group(optimizer_param_group group) optimizer_param_group {
    optimizer_param_group next = optimizer_make_group(group.params, group.lr, group.weight_decay, group.beta1, group.beta2, group.eps, group.kind)
    int i = 0
    while i < len(next.params) {
        next.params[i] = optimizer_zero_grad_tensor(next.params[i])
        i = i + 1
    }
    return next
}

func optimizer_zero_grad(optimizer opt) optimizer {
    optimizer next = optimizer_state_dict(opt)
    int i = 0
    while i < len(next.param_groups) {
        next.param_groups[i] = optimizer_zero_grad_group(next.param_groups[i])
        i = i + 1
    }
    return next
}

func optimizer_step_tensor_group(optimizer_param_group group, []tensor grads, float lr_override) optimizer_param_group {
    return optimizer_step_tensor_group_from(group, grads, 0, lr_override)
}

func optimizer_step_tensor_group_from(optimizer_param_group group, []tensor grads, int start, float lr_override) optimizer_param_group {
    optimizer_param_group next = optimizer_make_group(group.params, group.lr, group.weight_decay, group.beta1, group.beta2, group.eps, group.kind)
    int i = 0
    int g = start
    while i < len(next.params) && g < len(grads) {
        tensor param = next.params[i]
        tensor grad = grads[g]
        float lr = group.lr
        if lr_override > 0.0 {
            lr = lr_override
        }
        if group.kind == "adamw" {
            adamw_optimizer opt_state = new_adamw(lr, group.beta1, group.beta2, group.eps, group.weight_decay)
            adamw_step_output step_out = adamw_step_state(opt_state, param, grad)
            next.params[i] = step_out.params
        } else {
            sgd_optimizer sgd = new_sgd(lr)
            next.params[i] = step_tensor(sgd, param, grad)
        }
        i = i + 1
        g = g + 1
    }
    return next
}

func optimizer_step_group(optimizer opt, int group_index, []tensor grads) optimizer {
    if group_index < 0 || group_index >= len(opt.param_groups) {
        return opt
    }
    optimizer next = optimizer_state_dict(opt)
    float lr_override = optimizer_current_lr(next)
    next.param_groups[group_index] = optimizer_step_tensor_group(next.param_groups[group_index], grads, lr_override)
    next.step = next.step + 1
    return next
}

func optimizer_step(optimizer opt, []tensor grads) optimizer {
    optimizer next = optimizer_state_dict(opt)
    float lr_override = optimizer_current_lr(next)
    int offset = 0
    int i = 0
    while i < len(next.param_groups) {
        next.param_groups[i] = optimizer_step_tensor_group_from(next.param_groups[i], grads, offset, lr_override)
        offset = offset + len(next.param_groups[i].params)
        i = i + 1
    }
    next.step = next.step + 1
    return next
}

func optimizer_step_with_scheduler(optimizer opt, int epoch, []tensor grads) optimizer {
    optimizer next = optimizer_step_scheduler(opt, epoch)
    return optimizer_step(next, grads)
}

func optimizer_step_with_scheduler_and_zero_grad(optimizer opt, int epoch, []tensor grads) optimizer {
    optimizer next = optimizer_step_with_scheduler(opt, epoch, grads)
    return optimizer_zero_grad(next)
}

func optimizer_step_group_with_scheduler(optimizer opt, int epoch, int group_index, []tensor grads) optimizer {
    optimizer next = optimizer_step_scheduler(opt, epoch)
    return optimizer_step_group(next, group_index, grads)
}

func optimizer_step_all_groups_with_scheduler(optimizer opt, int epoch) optimizer {
    optimizer next = optimizer_step_scheduler(opt, epoch)
    next.step = next.step + 1
    return next
}

func optimizer_state_dict(optimizer opt) optimizer {
    return optimizer {
        kind: opt.kind,
        step: opt.step,
        param_groups: copy_param_groups(opt.param_groups),
        scheduler: scheduler_state_dict(opt.scheduler),
        has_scheduler: opt.has_scheduler,
    }
}

func optimizer_load_state_dict_from(optimizer opt, optimizer other) optimizer {
    return optimizer {
        kind: other.kind,
        step: other.step,
        param_groups: copy_param_groups(other.param_groups),
        scheduler: scheduler_state_dict(other.scheduler),
        has_scheduler: other.has_scheduler,
    }
}

func optimizer_load_state_dict(optimizer opt, optimizer other) optimizer {
    return optimizer_load_state_dict_from(opt, other)
}

func optimizer_num_groups(optimizer opt) int {
    return len(opt.param_groups)
}

func optimizer_num_parameters(optimizer opt) int {
    int total = 0
    int i = 0
    while i < len(opt.param_groups) {
        total = total + len(opt.param_groups[i].params)
        i = i + 1
    }
    return total
}

func new_sgd_optimizer([]tensor params, float lr) optimizer {
    optimizer opt = new_optimizer()
    opt.kind = "sgd"
    opt = optimizer_add_param_group(opt, params, lr, 0.0, 0.9, 0.999, 1e-8, "sgd")
    return opt
}

func new_adam_optimizer([]tensor params, float lr, float beta1, float beta2, float eps) optimizer {
    optimizer opt = new_optimizer()
    opt.kind = "adam"
    opt = optimizer_add_param_group(opt, params, lr, 0.0, beta1, beta2, eps, "adam")
    return opt
}

func new_adamw_optimizer([]tensor params, float lr, float beta1, float beta2, float eps, float weight_decay) optimizer {
    optimizer opt = new_optimizer()
    opt.kind = "adamw"
    opt = optimizer_add_param_group(opt, params, lr, weight_decay, beta1, beta2, eps, "adamw")
    return opt
}

func optimizer_get_group_lr(optimizer opt, int group_index) float {
    if group_index < 0 || group_index >= len(opt.param_groups) {
        return 0.0
    }
    return opt.param_groups[group_index].lr
}

func optimizer_set_group_lr(optimizer opt, int group_index, float lr) optimizer {
    if group_index < 0 || group_index >= len(opt.param_groups) {
        return opt
    }
    optimizer next = optimizer_state_dict(opt)
    next.param_groups[group_index].lr = lr
    return next
}
