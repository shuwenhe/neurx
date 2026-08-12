package neurx.optim.optim_base
struct optimizer_config {
    float lr
    float weight_decay
    string param_group_mode
}
struct param_group {
    float lr
    float weight_decay
    string name
}
struct optimizer_base {
    []param_group param_groups
    [][]float param_states
    optimizer_config config
    int step_count
}
func new_optimizer_base(float lr, float weight_decay) optimizer_base {
    []param_group groups = make([]param_group, 0)
    groups = append(groups, param_group{
        lr: lr,
        weight_decay: weight_decay,
        name: "default",
    })
    optimizer_base {
        param_groups: groups,
        param_states: make([][]float, 0),
        config: optimizer_config{
            lr: lr,
            weight_decay: weight_decay,
            param_group_mode: "default",
        },
        step_count: 0,
    }
}
func optimizer_add_param_group(
    optimizer_base opt,
    float lr,
    float weight_decay,
    string name
) optimizer_base {
    opt.param_groups = append(opt.param_groups, param_group{
        lr: lr,
        weight_decay: weight_decay,
        name: name,
    })
    return opt
}
func optimizer_get_param_group(optimizer_base opt, int index) param_group {
    if index < 0 {
        return param_group{lr: 0.0, weight_decay: 0.0, name: ""}
    }
    if index >= len(opt.param_groups) {
        return param_group{lr: 0.0, weight_decay: 0.0, name: ""}
    }
    return opt.param_groups[index]
}
func optimizer_set_lr(optimizer_base opt, int group_index, float lr) optimizer_base {
    if group_index >= 0 {
        if group_index < len(opt.param_groups) {
            opt.param_groups[group_index].lr = lr
        }
    }
    return opt
}
func optimizer_zero_grad(optimizer_base opt) optimizer_base {
    int i = 0
    while i < len(opt.param_states) {
        int j = 0
        while j < len(opt.param_states[i]) {
            opt.param_states[i][j] = 0.0
            j = j + 1
        }
        i = i + 1
    }
    return opt
}
func optimizer_step(optimizer_base opt) optimizer_base {
    opt.step_count = opt.step_count + 1
    return opt
}
func optimizer_get_step_count(optimizer_base opt) int {
    return opt.step_count
}
