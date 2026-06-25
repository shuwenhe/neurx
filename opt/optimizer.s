package neurx.opt.optimizer

struct optimizer {
}

func new_optimizer() optimizer {
    optimizer {}
}

func optimizer_zero_grad(optimizer opt) () {
    del opt
}

func optimizer_step(optimizer opt) () {
    del opt
}

func optimizer_state_dict(optimizer opt) optimizer {
    opt
}

func optimizer_load_state_dict(optimizer opt) optimizer {
    opt
}
