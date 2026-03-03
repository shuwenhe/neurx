import numpy as np

from tensor import Tensor, bmm, cat, chunk, eig, inverse, matmul, mm, split, stack, svd, where


def test_arithmetic_div_pow_and_backward():
    x = Tensor(np.array([2.0, 4.0, 8.0]), requires_grad=True)
    y = Tensor(np.array([2.0, 2.0, 2.0]), requires_grad=True)
    z = ((x / y) + (x ** y)).sum()
    z.backward()
    assert np.allclose((x / y).to_numpy(), np.array([1.0, 2.0, 4.0]))
    assert np.allclose((x ** y).to_numpy(), np.array([4.0, 16.0, 64.0]))
    assert x.grad.shape == x.shape
    assert y.grad.shape == y.shape


def test_unary_ops_and_relu_inplace():
    x = Tensor(np.array([-1.0, 0.25, 1.0]), requires_grad=True)
    y = x.abs() + x.exp() + x.sin() + x.cos()
    z = y.sum()
    z.backward()
    assert y.shape == x.shape
    t = Tensor(np.array([-2.0, 3.0]))
    t.relu_()
    t.add_(1.0)
    t.mul_(2.0)
    assert np.allclose(t.to_numpy(), np.array([2.0, 8.0]))


def test_log_sqrt_and_comparison_where():
    x = Tensor(np.array([1.0, 4.0, 9.0]), requires_grad=True)
    y = x.sqrt().log().sum()
    y.backward()
    mask = x > 3.0
    out = where(mask, x, Tensor(np.zeros(3)))
    assert np.array_equal(mask.to_numpy(), np.array([False, True, True]))
    assert np.allclose(out.to_numpy(), np.array([0.0, 4.0, 9.0]))


def test_shape_ops_squeeze_unsqueeze_repeat_expand():
    x = Tensor(np.arange(6.0).reshape(1, 2, 3), requires_grad=True)
    y = x.squeeze(0).unsqueeze(1)
    assert y.shape == (2, 1, 3)
    rep = y.repeat(2, 1, 1)
    assert rep.shape == (4, 1, 3)
    z = Tensor(np.array([[1.0], [2.0]], dtype=np.float64), requires_grad=True)
    e = z.expand(2, 3)
    assert e.shape == (2, 3)
    loss = rep.sum() + e.sum()
    loss.backward()
    assert x.grad.shape == x.shape
    assert z.grad.shape == z.shape


def test_indexing_gather_scatter_index_select():
    x = Tensor(np.arange(12.0).reshape(3, 4), requires_grad=True)
    part = x[1:, 1:3]
    assert part.shape == (2, 2)

    idx = Tensor(np.array([[0, 2], [1, 3], [0, 1]], dtype=np.int64))
    g = x.gather(1, idx)
    assert g.shape == (3, 2)

    src = Tensor(np.ones((3, 2)))
    s = x.scatter(1, idx, src)
    assert s.shape == x.shape

    sel = x.index_select(0, Tensor(np.array([2, 0], dtype=np.int64)))
    assert sel.shape == (2, 4)


def test_cat_stack_split_chunk():
    a = Tensor(np.ones((2, 3)), requires_grad=True)
    b = Tensor(np.zeros((1, 3)), requires_grad=True)
    c = cat([a, b], dim=0)
    assert c.shape == (3, 3)
    st = stack([a, a], dim=0)
    assert st.shape == (2, 2, 3)
    x1, x2 = split(c, [1, 2], dim=0)
    assert x1.shape == (1, 3)
    assert x2.shape == (2, 3)
    ch = chunk(c, 2, dim=0)
    assert len(ch) == 2
    (c.sum() + st.sum()).backward()
    assert a.grad is not None
    assert b.grad is not None


def test_reductions_std_norm():
    x = Tensor(np.array([[3.0, 4.0], [0.0, 0.0]]), requires_grad=True)
    n = x.norm(dim=1)
    s = x.std(dim=1, correction=0)
    assert np.allclose(n.to_numpy(), np.array([5.0, 0.0]))
    assert s.shape == (2,)
    (n.sum() + s.sum()).backward()
    assert x.grad.shape == x.shape


def test_linalg_ops():
    a = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]))
    b = Tensor(np.array([[2.0, 0.0], [0.0, 2.0]]))
    assert np.allclose(matmul(a, b).to_numpy(), np.array([[2.0, 4.0], [6.0, 8.0]]))
    assert np.allclose(mm(a, b).to_numpy(), np.array([[2.0, 4.0], [6.0, 8.0]]))

    x3 = Tensor(np.arange(12.0).reshape(2, 2, 3))
    y3 = Tensor(np.arange(12.0).reshape(2, 3, 2))
    assert bmm(x3, y3).shape == (2, 2, 2)

    inv = inverse(a)
    assert inv.shape == (2, 2)
    u, s, vh = svd(a)
    assert u.shape == (2, 2)
    assert s.shape == (2,)
    assert vh.shape == (2, 2)
    w, v = eig(a)
    assert w.shape == (2,)
    assert v.shape == (2, 2)


def test_dtype_and_device_shortcuts_cpu():
    x = Tensor(np.array([1.2, 2.8], dtype=np.float64))
    assert x.float().to_numpy().dtype == np.float32
    assert x.long().to_numpy().dtype == np.int64
    assert x.cpu().device == "cpu"


def test_masked_fill_and_masked_select_with_backward():
    x = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]), requires_grad=True)
    mask = x > 2.0
    y = x.masked_fill(mask, 0.0)
    assert np.allclose(y.to_numpy(), np.array([[1.0, 2.0], [0.0, 0.0]]))

    selected = x.masked_select(mask)
    assert np.allclose(selected.to_numpy(), np.array([3.0, 4.0]))

    loss = y.sum() + selected.sum()
    loss.backward()
    assert np.allclose(x.grad, np.ones_like(x.to_numpy()))


def test_moveaxis_movedim_roundtrip():
    x = Tensor(np.arange(24.0).reshape(2, 3, 4), requires_grad=True)
    y = x.moveaxis(0, 2)
    z = y.movedim(2, 0)
    assert y.shape == (3, 4, 2)
    assert z.shape == x.shape
    assert np.allclose(z.to_numpy(), x.to_numpy())

    y.sum().backward()
    assert np.allclose(x.grad, np.ones_like(x.to_numpy()))


def test_sort_argsort_topk_and_backward():
    x = Tensor(np.array([[3.0, 1.0, 2.0], [0.0, 4.0, 5.0]]), requires_grad=True)

    values, indices = x.sort(dim=1)
    assert np.allclose(values.to_numpy(), np.array([[1.0, 2.0, 3.0], [0.0, 4.0, 5.0]]))
    assert np.array_equal(indices.to_numpy(), np.array([[1, 2, 0], [0, 1, 2]], dtype=np.int64))

    args_desc = x.argsort(dim=1, descending=True)
    assert np.array_equal(args_desc.to_numpy(), np.array([[0, 2, 1], [2, 1, 0]], dtype=np.int64))

    topv, topi = x.topk(2, dim=1, largest=True, sorted=True)
    assert np.allclose(topv.to_numpy(), np.array([[3.0, 2.0], [5.0, 4.0]]))
    assert np.array_equal(topi.to_numpy(), np.array([[0, 2], [2, 1]], dtype=np.int64))

    (values.sum() + topv.sum()).backward()
    assert np.allclose(x.grad, np.array([[2.0, 1.0, 2.0], [1.0, 2.0, 2.0]]))


def test_scatter_add_duplicate_indices_accumulate():
    base = Tensor(np.zeros((1, 5), dtype=np.float64), requires_grad=True)
    index = Tensor(np.array([[1, 1, 3]], dtype=np.int64))
    src = Tensor(np.array([[2.0, 3.0, 4.0]], dtype=np.float64), requires_grad=True)
    out = base.scatter_add(1, index, src)
    assert np.allclose(out.to_numpy(), np.array([[0.0, 5.0, 0.0, 4.0, 0.0]]))

    out.sum().backward()
    assert np.allclose(base.grad, np.ones_like(base.to_numpy()))
    assert np.allclose(src.grad, np.ones_like(src.to_numpy()))
