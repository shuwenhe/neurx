package neurx.checkpoint

use neurx.tensor.tensor

struct checkpoint {
    int step
    float loss
    tensor[] params
}

func save_checkpoint(string path, int step, float loss, tensor[] params) () {
    
}

func load_checkpoint(string path) checkpoint {
    
    checkpoint {
        step: 0,
        loss: 0.0,
        params: [],
    }
}
