package neurx.checkpoint
use neurx.tensor.tensor
struct checkpoint {
    int step
    float loss
    []tensor params
    string path
}


struct checkpoint_ref {
    string path
    int step
    string kind
    bool resumable
}


func new_checkpoint(int step, float loss, []tensor params) checkpoint {
    checkpoint {
        step: step,
        loss: loss,
        params: params,
        path: "",
    }
}


func save_checkpoint(checkpoint ckpt, string path) checkpoint {
    checkpoint {
        step: ckpt.step,
        loss: ckpt.loss,
        params: ckpt.params,
        path: path,
    }
}


func load_checkpoint(checkpoint ckpt, string path) checkpoint {
    checkpoint {
        step: ckpt.step,
        loss: ckpt.loss,
        params: ckpt.params,
        path: path,
    }
}


func checkpoint_state_dict(checkpoint ckpt) checkpoint {
    ckpt
}


func checkpoint_load_state_dict(checkpoint ckpt, checkpoint other) checkpoint {
    other
}


func checkpoint_params(checkpoint ckpt) []tensor {
    ckpt.params
}


func checkpoint_step(checkpoint ckpt) int {
    ckpt.step
}


func checkpoint_loss(checkpoint ckpt) float {
    ckpt.loss
}


func checkpoint_param_count(checkpoint ckpt) int {
    len(ckpt.params)
}


func new_checkpoint_ref(string path, int step, string kind) checkpoint_ref {
    checkpoint_ref {
        path: path,
        step: step,
        kind: kind,
        resumable: true,
    }
}


func checkpoint_ref_state_dict(checkpoint_ref ref) checkpoint_ref {
    ref
}


func checkpoint_ref_load_state_dict(checkpoint_ref ref, checkpoint_ref other) checkpoint_ref {
    other
}

