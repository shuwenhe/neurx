package neurx.opt.losses

use neurx.tensor.tensor
use neurx.tensor.new

struct loss {
}

func _loss_tensor() tensor {
    new([0.0], [1], false)
}

func new_loss() loss {
    loss {}
}

func cross_entropy_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func bce_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func bce_with_logits_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func l1_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func mse_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func smooth_l1_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func kl_div_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func nll_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func huber_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func poisson_nll_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func ctc_loss(tensor input, tensor target) tensor {
    del input
    del target
    _loss_tensor()
}

func margin_ranking_loss(tensor input1, tensor input2, tensor target) tensor {
    del input1
    del input2
    del target
    _loss_tensor()
}

func triplet_margin_loss(tensor anchor, tensor positive, tensor negative) tensor {
    del anchor
    del positive
    del negative
    _loss_tensor()
}
