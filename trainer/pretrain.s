package neurx.trainer.pretrain
use neurx.pretrain.loop.{pretrain_loop_state, pretrain_step, pretrain_reset_micro_step, pretrain_loop_state_dict, pretrain_loop_load_state_dict}

struct pretrain_trainer_ref {
    pretrain_loop_state loop
}

func new_pretrain_trainer_ref(pretrain_loop_state loop) pretrain_trainer_ref {
    pretrain_trainer_ref {
        loop: loop,
    }
}

func pretrain_trainer_step(pretrain_trainer_ref trainer, float loss, float grad_norm, int new_tokens) pretrain_trainer_ref {
    pretrain_trainer_ref {
        loop: pretrain_step(trainer.loop, loss, grad_norm, new_tokens),
    }
}

func pretrain_trainer_reset_micro_step(pretrain_trainer_ref trainer) pretrain_trainer_ref {
    pretrain_trainer_ref {
        loop: pretrain_reset_micro_step(trainer.loop),
    }
}

func pretrain_trainer_state_dict(pretrain_trainer_ref trainer) pretrain_trainer_ref {
    pretrain_trainer_ref {
        loop: pretrain_loop_state_dict(trainer.loop),
    }
}

func pretrain_trainer_load_state_dict(pretrain_trainer_ref trainer, pretrain_trainer_ref other) pretrain_trainer_ref {
    pretrain_trainer_ref {
        loop: pretrain_loop_load_state_dict(trainer.loop, other.loop),
    }
}
