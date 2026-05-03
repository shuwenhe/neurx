package neurx.tensor.autograd

use neurx.tensor.tensor
use neurx.ad.function

func tensor_backward_rule_add(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_add(a, b, upstream)
}

func tensor_backward_rule_mul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_mul(a, b, upstream)
}

func tensor_backward_rule_matmul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_matmul(a, b, upstream)
}

func tensor_backward_rule_sum(tensor a, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_sum(a, upstream)
}

func tensor_backward_rule_mean(tensor a, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_mean(a, upstream)
}

func tensor_transform_chain_from_op(string op) transform_chain {
    transform_chain chain = neurx.ad.function.new_transform_chain()
    neurx.ad.function.transform_chain_add_step(chain, op)
}

func tensor_transform_chain_add() transform_chain {
    tensor_transform_chain_from_op("add")
}

func tensor_transform_chain_mul() transform_chain {
    tensor_transform_chain_from_op("mul")
}

func tensor_transform_chain_matmul() transform_chain {
    tensor_transform_chain_from_op("matmul")
}

func tensor_transform_chain_sum() transform_chain {
    tensor_transform_chain_from_op("sum")
}

func tensor_transform_chain_mean() transform_chain {
    tensor_transform_chain_from_op("mean")
}
