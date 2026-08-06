package main
use neurx.tensor.core
use neurx.autograd.tensor
use neurx.tensor.reduce

func assert_true(bool value, string name) {
    if value {
        println("PASS " + name)
    } else {
        println("FAIL " + name)
    }
}

func assert_close(float actual, float expected, string name) {
    float diff = actual - expected
    if diff < 0.0 {
        diff = -diff
    }
    assert_true(diff < 0.0001, name)
}

func test_descriptor() {
    tensor t = neurx.tensor.core.ones([2, 3], "bf16", "cpu", true)
    assert_true(t.desc.numel == 6, "numel")
    assert_true(t.desc.strides[0] == 3, "stride0")
    assert_true(t.desc.strides[1] == 1, "stride1")
    assert_true(neurx.tensor.core.tensor_nbytes(t) == 12, "bf16 nbytes")
}

func test_view_contiguous() {
    tensor t = neurx.tensor.core.from_data([1.0, 2.0, 3.0, 4.0], [2, 2], "fp32", "cpu", false)
    tensor v = neurx.tensor.core.view(t, [4])
    assert_true(v.desc.is_view, "view flag")
    assert_true(v.desc.numel == 4, "view numel")
    assert_close(neurx.tensor.core.get(v, 2), 3.0, "view get")
}

func test_math() {
    tensor a = neurx.tensor.core.from_data([1.0, 2.0, 3.0, 4.0], [2, 2], "fp32", "cpu", true)
    tensor b = neurx.tensor.core.from_data([5.0, 6.0, 7.0, 8.0], [2, 2], "fp32", "cpu", true)
    tensor c = neurx.tensor.core.add(a, b)
    tensor d = neurx.tensor.core.mul(a, b)
    assert_close(c.storage[0], 6.0, "add 0")
    assert_close(c.storage[3], 12.0, "add 3")
    assert_close(d.storage[1], 12.0, "mul 1")
    assert_true(c.desc.requires_grad, "requires grad propagation")
}

func test_matmul_reduce() {
    tensor a = neurx.tensor.core.from_data([1.0, 2.0, 3.0, 4.0], [2, 2], "fp32", "cpu", false)
    tensor b = neurx.tensor.core.from_data([5.0, 6.0, 7.0, 8.0], [2, 2], "fp32", "cpu", false)
    tensor c = neurx.tensor.core.matmul2d(a, b)
    tensor s = neurx.tensor.core.sum_all(c)
    tensor m = neurx.tensor.core.mean_all(c)
    assert_close(c.storage[0], 19.0, "matmul 00")
    assert_close(c.storage[1], 22.0, "matmul 01")
    assert_close(c.storage[2], 43.0, "matmul 10")
    assert_close(c.storage[3], 50.0, "matmul 11")
    assert_close(s.storage[0], 134.0, "sum all")
    assert_close(m.storage[0], 33.5, "mean all")
}

func test_broadcast_and_shape_ops() {
    tensor a = neurx.tensor.core.from_data([1.0, 2.0, 3.0], [3], "fp32", "cpu", true)
    tensor b = neurx.tensor.core.from_data([10.0], [1], "fp32", "cpu", false)
    tensor c = neurx.tensor.core.add(a, b)
    tensor d = neurx.tensor.core.reshape(a, [1, 3])
    tensor e = neurx.tensor.core.transpose2d(d)
    tensor f = neurx.tensor.core.sum_dim(c, 0, false)
    tensor g = neurx.tensor.core.mean_dim(c, 0, false)
    tensor h = neurx.tensor.core.broadcast_to(a, [2, 3])
    tensor i = neurx.tensor.core.sum_to_shape(h, [3])
    tensor j = neurx.tensor.core.tensor_materialize(e)
    bool k = neurx.tensor.core.broadcastable_shape([2, 3], [1, 3])
    bool l = neurx.tensor.core.broadcastable_shape([2, 3], [2, 2])
    tensor m = neurx.tensor.core.tensor_clone_storage(e)
    assert_close(c.storage[0], 11.0, "broadcast add 0")
    assert_close(c.storage[2], 13.0, "broadcast add 2")
    assert_true(d.desc.numel == 3, "reshape numel")
    assert_true(e.desc.shape[0] == 3, "transpose rows")
    assert_true(e.desc.shape[1] == 1, "transpose cols")
    assert_close(f.storage[0], 36.0, "sum dim")
    assert_close(g.storage[0], 12.0, "mean dim")
    assert_close(h.storage[4], 2.0, "broadcast to")
    assert_close(i.storage[0], 2.0, "sum to shape 0")
    assert_close(i.storage[1], 4.0, "sum to shape 1")
    assert_close(i.storage[2], 6.0, "sum to shape 2")
    assert_true(j.desc.is_contiguous, "materialize contiguous")
    assert_true(k, "broadcastable true")
    assert_true(!l, "broadcastable false")
    assert_true(!m.desc.is_view, "clone storage not view")
}

func test_broadcast_backward_rules() {
    tensor a = neurx.tensor.core.from_data([1.0, 2.0, 3.0], [3], "fp32", "cpu", true)
    tensor b = neurx.tensor.core.from_data([10.0], [1], "fp32", "cpu", true)
    tensor upstream = neurx.tensor.core.from_data([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], [2, 3], "fp32", "cpu", false)
    tensor reduced = neurx.tensor.core.sum_dim(upstream, 0, false)
    tensor mean_reduced = neurx.tensor.core.mean_dim(upstream, 1, true)
    backward_rule add_rule = neurx.autograd.tensor.tensor_backward_rule_add(a, b, upstream)
    backward_rule mul_rule = neurx.autograd.tensor.tensor_backward_rule_mul(a, b, upstream)
    backward_rule sub_rule = neurx.autograd.tensor.tensor_backward_rule_sub(a, b, upstream)
    tensor div_b = neurx.tensor.core.from_data([2.0], [1], "fp32", "cpu", true)
    backward_rule div_rule = neurx.autograd.tensor.tensor_backward_rule_div(a, div_b, neurx.tensor.core.from_data([1.0, 1.0, 1.0, 1.0, 1.0, 1.0], [2, 3], "fp32", "cpu", false))
    assert_close(add_rule.grad_a.storage[0], 5.0, "add grad a 0")
    assert_close(add_rule.grad_a.storage[1], 7.0, "add grad a 1")
    assert_close(add_rule.grad_a.storage[2], 9.0, "add grad a 2")
    assert_close(add_rule.grad_b.storage[0], 21.0, "add grad b 0")
    assert_close(mul_rule.grad_a.storage[0], 50.0, "mul grad a 0")
    assert_close(mul_rule.grad_a.storage[1], 70.0, "mul grad a 1")
    assert_close(mul_rule.grad_a.storage[2], 90.0, "mul grad a 2")
    assert_close(mul_rule.grad_b.storage[0], 46.0, "mul grad b 0")
    assert_close(sub_rule.grad_a.storage[0], 5.0, "sub grad a 0")
    assert_close(sub_rule.grad_b.storage[0], -21.0, "sub grad b 0")
    assert_close(div_rule.grad_a.storage[0], 1.0, "div grad a 0")
    assert_close(div_rule.grad_a.storage[1], 1.0, "div grad a 1")
    assert_close(div_rule.grad_a.storage[2], 1.0, "div grad a 2")
    assert_close(div_rule.grad_b.storage[0], -3.0, "div grad b 0")
    assert_close(reduced.storage[0], 5.0, "sum dim backward prep 0")
    assert_close(reduced.storage[1], 7.0, "sum dim backward prep 1")
    assert_close(reduced.storage[2], 9.0, "sum dim backward prep 2")
    assert_close(mean_reduced.storage[0], 2.0, "mean dim keepdim 0")
    assert_close(mean_reduced.storage[1], 5.0, "mean dim keepdim 1")
    tensor red_input = neurx.tensor.core.from_data([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], [2, 3], "fp32", "cpu", true)
    tensor sum_dim_upstream = neurx.tensor.core.from_data([10.0, 20.0, 30.0], [3], "fp32", "cpu", false)
    tensor mean_dim_upstream = neurx.tensor.core.from_data([10.0, 20.0, 30.0], [1, 3], "fp32", "cpu", false)
    backward_rule sum_dim_rule = neurx.autograd.tensor.tensor_backward_rule_sum_dim(red_input, sum_dim_upstream, 0, false)
    backward_rule mean_dim_rule = neurx.autograd.tensor.tensor_backward_rule_mean_dim(red_input, mean_dim_upstream, 0, true)
    assert_close(sum_dim_rule.grad_a.storage[0], 10.0, "sum_dim grad a 0")
    assert_close(sum_dim_rule.grad_a.storage[1], 20.0, "sum_dim grad a 1")
    assert_close(sum_dim_rule.grad_a.storage[2], 30.0, "sum_dim grad a 2")
    assert_close(sum_dim_rule.grad_a.storage[3], 10.0, "sum_dim grad a 3")
    assert_close(sum_dim_rule.grad_a.storage[4], 20.0, "sum_dim grad a 4")
    assert_close(sum_dim_rule.grad_a.storage[5], 30.0, "sum_dim grad a 5")
    assert_close(mean_dim_rule.grad_a.storage[0], 5.0, "mean_dim grad a 0")
    assert_close(mean_dim_rule.grad_a.storage[1], 10.0, "mean_dim grad a 1")
    assert_close(mean_dim_rule.grad_a.storage[2], 15.0, "mean_dim grad a 2")
    assert_close(mean_dim_rule.grad_a.storage[3], 5.0, "mean_dim grad a 3")
    assert_close(mean_dim_rule.grad_a.storage[4], 10.0, "mean_dim grad a 4")
    assert_close(mean_dim_rule.grad_a.storage[5], 15.0, "mean_dim grad a 5")
}

func test_reduce_package() {
    tensor a = neurx.tensor.core.from_data([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], [2, 3], "fp32", "cpu", false)
    tensor sum_rows = neurx.tensor.reduce.reduce_sum_dim(a, 1, false)
    tensor sum_alias = neurx.tensor.reduce.sum_dim(a, 1, false)
    tensor mean_rows = neurx.tensor.reduce.reduce_mean_dim(a, 1, true)
    tensor max_cols = neurx.tensor.reduce.reduce_max_dim(a, 0, false)
    tensor argmax_all = neurx.tensor.reduce.reduce_argmax(a)
    tensor argmax_alias = neurx.tensor.reduce.argmax(a)
    tensor argmax_cols = neurx.tensor.reduce.reduce_argmax_dim(a, 0, false)
    tensor argmin_rows = neurx.tensor.reduce.reduce_argmin_dim(a, 1, false)
    assert_close(sum_rows.storage[0], 6.0, "reduce sum row 0")
    assert_close(sum_rows.storage[1], 15.0, "reduce sum row 1")
    assert_close(sum_alias.storage[0], 6.0, "reduce sum alias row 0")
    assert_close(sum_alias.storage[1], 15.0, "reduce sum alias row 1")
    assert_close(mean_rows.storage[0], 2.0, "reduce mean keepdim 0")
    assert_close(mean_rows.storage[1], 5.0, "reduce mean keepdim 1")
    assert_close(max_cols.storage[0], 4.0, "reduce max col 0")
    assert_close(max_cols.storage[1], 5.0, "reduce max col 1")
    assert_close(max_cols.storage[2], 6.0, "reduce max col 2")
    assert_close(argmax_all.storage[0], 5.0, "reduce argmax all")
    assert_close(argmax_alias.storage[0], 5.0, "reduce argmax alias all")
    assert_close(argmax_cols.storage[0], 1.0, "reduce argmax col 0")
    assert_close(argmax_cols.storage[1], 1.0, "reduce argmax col 1")
    assert_close(argmax_cols.storage[2], 1.0, "reduce argmax col 2")
    assert_close(argmin_rows.storage[0], 0.0, "reduce argmin row 0")
    assert_close(argmin_rows.storage[1], 0.0, "reduce argmin row 1")
}

func main() {
    println("NeurX tensor core tests")
    test_descriptor()
    test_view_contiguous()
    test_math()
    test_matmul_reduce()
    test_broadcast_and_shape_ops()
    test_broadcast_backward_rules()
    test_reduce_package()
}

