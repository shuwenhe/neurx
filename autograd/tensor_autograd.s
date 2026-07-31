package neurx.autograd.tensor
use neurx.tensor.tensor
use neurx.autograd.function
func tensor_backward_rule_add(tensor a, tensor b, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_add_grad_a(a, upstream)
    tensor grad_b = neurx.tensor.tensor.tensor_backward_add_grad_b(b, upstream)
    backward_rule {
        op: "add",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: grad_a,
        grad_b: grad_b,
        ready: true,
    }
}

func tensor_backward_rule_mul(tensor a, tensor b, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_mul_grad_a(a, b, upstream)
    tensor grad_b = neurx.tensor.tensor.tensor_backward_mul_grad_b(a, b, upstream)
    backward_rule {
        op: "mul",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: grad_a,
        grad_b: grad_b,
        ready: true,
    }
}

func tensor_backward_rule_sub(tensor a, tensor b, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_sub_grad_a(a, upstream)
    tensor grad_b = neurx.tensor.tensor.tensor_backward_sub_grad_b(b, upstream)
    backward_rule {
        op: "sub",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: grad_a,
        grad_b: grad_b,
        ready: true,
    }
}

func tensor_backward_rule_div(tensor a, tensor b, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_div_grad_a(a, b, upstream)
    tensor grad_b = neurx.tensor.tensor.tensor_backward_div_grad_b(a, b, upstream)
    backward_rule {
        op: "div",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: grad_a,
        grad_b: grad_b,
        ready: true,
    }
}

func tensor_backward_rule_matmul(tensor a, tensor b, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_matmul_grad_a(a, b, upstream)
    tensor grad_b = neurx.tensor.tensor.tensor_backward_matmul_grad_b(a, b, upstream)
    backward_rule {
        op: "matmul",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: grad_a,
        grad_b: grad_b,
        ready: true,
    }
}

func tensor_backward_rule_sum_dim(tensor a, tensor upstream, int dim, bool keepdim) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_sum_dim_grad(a, upstream, dim, keepdim)
    backward_rule {
        op: "sum_dim",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_mean_dim(tensor a, tensor upstream, int dim, bool keepdim) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_mean_dim_grad(a, upstream, dim, keepdim)
    backward_rule {
        op: "mean_dim",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_sum(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_sum_grad(a, upstream)
    backward_rule {
        op: "sum",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_mean(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_mean_grad(a, upstream)
    backward_rule {
        op: "mean",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_relu(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_relu_grad(a, upstream)
    backward_rule {
        op: "relu",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_exp(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_exp_grad(a, upstream)
    backward_rule {
        op: "exp",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_log(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_log_grad(a, upstream)
    backward_rule {
        op: "log",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_sqrt(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_sqrt_grad(a, upstream)
    backward_rule {
        op: "sqrt",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_tanh(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_tanh_grad(a, upstream)
    backward_rule {
        op: "tanh",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_backward_rule_sigmoid(tensor a, tensor upstream) backward_rule {
    tensor grad_a = neurx.tensor.tensor.tensor_backward_sigmoid_grad(a, upstream)
    backward_rule {
        op: "sigmoid",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: grad_a,
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: true,
    }
}

func tensor_transform_chain_from_op(string op) transform_chain {
    transform_chain chain = neurx.autograd.function.new_transform_chain()
    neurx.autograd.function.transform_chain_add_step(chain, op)
}

func tensor_transform_chain_add() transform_chain {
    tensor_transform_chain_from_op("add")
}

func tensor_transform_chain_mul() transform_chain {
    tensor_transform_chain_from_op("mul")
}

func tensor_transform_chain_sub() transform_chain {
    tensor_transform_chain_from_op("sub")
}

func tensor_transform_chain_div() transform_chain {
    tensor_transform_chain_from_op("div")
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

func tensor_transform_chain_sum_dim() transform_chain {
    tensor_transform_chain_from_op("sum_dim")
}

func tensor_transform_chain_mean_dim() transform_chain {
    tensor_transform_chain_from_op("mean_dim")
}

func tensor_transform_chain_relu() transform_chain {
    tensor_transform_chain_from_op("relu")
}

func tensor_transform_chain_exp() transform_chain {
    tensor_transform_chain_from_op("exp")
}

func tensor_transform_chain_log() transform_chain {
    tensor_transform_chain_from_op("log")
}

func tensor_transform_chain_sqrt() transform_chain {
    tensor_transform_chain_from_op("sqrt")
}

func tensor_transform_chain_tanh() transform_chain {
    tensor_transform_chain_from_op("tanh")
}

func tensor_transform_chain_sigmoid() transform_chain {
    tensor_transform_chain_from_op("sigmoid")
}
