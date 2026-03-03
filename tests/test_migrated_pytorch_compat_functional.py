import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor
from tensor.nn import functional as F
from tensor.pytorch_compat import functional as PF


def test_embedding_backward_with_padding_idx():
    weight = Tensor(np.random.randn(8, 4).astype(np.float64), requires_grad=True)
    ids = np.array([[0, 1, 2], [3, 0, 4]], dtype=np.int64)

    out = F.embedding(ids, weight, padding_idx=0)
    loss = out.sum()
    loss.backward()

    # padding_idx=0 不应产生梯度
    assert np.allclose(weight.grad[0], 0.0)
    # 至少有其他 id 被更新
    assert np.linalg.norm(weight.grad[1:]) > 0


def test_cross_entropy_reduction_modes():
    x = Tensor(np.array([[2.0, 0.5, -1.0], [0.2, 1.5, -0.3]], dtype=np.float64), requires_grad=True)
    target = np.array([0, 1], dtype=np.int64)

    loss_mean = F.cross_entropy(x, target, reduction="mean")
    loss_sum = F.cross_entropy(x, target, reduction="sum")
    loss_none = F.cross_entropy(x, target, reduction="none")

    assert np.isscalar(loss_mean.item())
    assert np.isscalar(loss_sum.item())
    assert loss_none.shape == (2,)


def test_compat_softmax_delegates_to_nn_functional():
    x_np = np.random.randn(3, 5).astype(np.float64)
    x1 = Tensor(x_np.copy(), requires_grad=True)
    x2 = Tensor(x_np.copy(), requires_grad=True)

    y_nn = F.softmax(x1, dim=-1)
    y_pc = PF.softmax(x2, dim=-1)

    assert np.allclose(y_nn.to_numpy(), y_pc.to_numpy(), atol=1e-8)


def test_compat_linear_uses_torch_weight_layout():
    x = Tensor(np.random.randn(2, 3).astype(np.float64), requires_grad=True)
    # PyTorch 语义: (out_features, in_features)
    w_torch = Tensor(np.random.randn(4, 3).astype(np.float64), requires_grad=True)
    b = Tensor(np.random.randn(4).astype(np.float64), requires_grad=True)

    y = PF.linear(x, w_torch, b)
    expected = x.to_numpy() @ w_torch.to_numpy().T + b.to_numpy()
    assert np.allclose(y.to_numpy(), expected, atol=1e-8)
