package neurx.ad.engine

use neurx.tensor.tensor

func backward(tensor t) () {
    if !t.requires_grad {
        return
    }
    if len(t.shape) == 0 {
        return
    }
}
