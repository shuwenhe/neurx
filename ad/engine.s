package neurx.ad.engine

use neurx.tensor.tensor

func backward(tensor t) tensor {
    if !t.requires_grad {
        return neurx.tensor.zeros_like(t)
    }
    // Minimal backward seed: treat the output as its own upstream gradient.
    neurx.tensor.ones_like(t)
}
