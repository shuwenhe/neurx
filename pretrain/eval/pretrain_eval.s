package neurx.pretrain.eval

struct pretrain_eval_state {
    int last_eval_step
    float val_loss
    float ppl
    bool has_result
}

func new_pretrain_eval_state() pretrain_eval_state {
    pretrain_eval_state {
        last_eval_step: -1,
        val_loss: 0.0,
        ppl: 0.0,
        has_result: false,
    }
}

func update_pretrain_eval(pretrain_eval_state state, int step, float val_loss, float ppl) pretrain_eval_state {
    pretrain_eval_state {
        last_eval_step: step,
        val_loss: val_loss,
        ppl: ppl,
        has_result: true,
    }
}

func pretrain_eval_state_dict(pretrain_eval_state state) pretrain_eval_state {
    state
}

func pretrain_eval_load_state_dict(pretrain_eval_state state, pretrain_eval_state other) pretrain_eval_state {
    other
}
