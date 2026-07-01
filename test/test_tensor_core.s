package main

use neurx.tensor.core

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
    assert_close(c.storage[0], 11.0, "broadcast add 0")
    assert_close(c.storage[2], 13.0, "broadcast add 2")
    assert_true(d.desc.numel == 3, "reshape numel")
    assert_true(e.desc.shape[0] == 3, "transpose rows")
    assert_true(e.desc.shape[1] == 1, "transpose cols")
    assert_close(f.storage[0], 36.0, "sum dim")
    assert_close(g.storage[0], 12.0, "mean dim")
}

func main() {
    println("NeurX tensor core tests")
    test_descriptor()
    test_view_contiguous()
    test_math()
    test_matmul_reduce()
    test_broadcast_and_shape_ops()
}
