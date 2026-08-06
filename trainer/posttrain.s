package neurx.trainer.posttrain
use neurx.posttrain.loop.{posttrain_loop_state, posttrain_step, posttrain_loop_state_dict, posttrain_loop_load_state_dict}

struct posttrain_trainer_ref {
    posttrain_loop_state loop
}

func new_posttrain_trainer_ref(posttrain_loop_state loop) posttrain_trainer_ref {
    posttrain_trainer_ref {
        loop: loop,
    }
}

func posttrain_trainer_step(posttrain_trainer_ref trainer, float objective, float policy_loss, float value_loss, int samples) posttrain_trainer_ref {
    posttrain_trainer_ref {
        loop: posttrain_step(trainer.loop, objective, policy_loss, value_loss, samples),
    }
}

func posttrain_trainer_state_dict(posttrain_trainer_ref trainer) posttrain_trainer_ref {
    posttrain_trainer_ref {
        loop: posttrain_loop_state_dict(trainer.loop),
    }
}

func posttrain_trainer_load_state_dict(posttrain_trainer_ref trainer, posttrain_trainer_ref other) posttrain_trainer_ref {
    posttrain_trainer_ref {
        loop: posttrain_loop_load_state_dict(trainer.loop, other.loop),
    }
}

