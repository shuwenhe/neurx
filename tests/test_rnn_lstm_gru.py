import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor
import tensor.nn as nn
from tensor.nn import functional as F


def _numeric_grad(f, x, eps=1e-4):
    grad = np.zeros_like(x)
    it = np.nditer(x, flags=["multi_index"], op_flags=["readwrite"])
    while not it.finished:
        idx = it.multi_index
        old = x[idx]
        x[idx] = old + eps
        f1 = f(x)
        x[idx] = old - eps
        f2 = f(x)
        x[idx] = old
        grad[idx] = (f1 - f2) / (2 * eps)
        it.iternext()
    return grad


def test_functional_rnn_one_step_matches_numpy():
    x_np = np.array([[[0.2, -0.1, 0.3], [0.4, 0.0, -0.2]]], dtype=np.float64)  # (seq=1, batch=2, in=3)
    w_ih_np = np.array([[0.1, -0.3], [0.2, 0.5], [-0.4, 0.2]], dtype=np.float64)
    w_hh_np = np.array([[0.7, -0.1], [0.2, 0.6]], dtype=np.float64)
    b_ih_np = np.array([0.05, -0.02], dtype=np.float64)
    b_hh_np = np.array([0.03, 0.01], dtype=np.float64)
    h0_np = np.zeros((2, 2), dtype=np.float64)

    out, h_n = F.rnn(
        Tensor(x_np),
        Tensor(w_ih_np),
        Tensor(w_hh_np),
        Tensor(b_ih_np),
        Tensor(b_hh_np),
        hx=Tensor(h0_np),
    )

    expected = np.tanh(x_np[0] @ w_ih_np + h0_np @ w_hh_np + b_ih_np + b_hh_np)
    assert out.shape == (1, 2, 2)
    assert h_n.shape == (1, 2, 2)
    assert np.allclose(out.to_numpy()[0], expected, atol=1e-8)
    assert np.allclose(h_n.to_numpy()[0], expected, atol=1e-8)


def test_functional_lstm_input_grad_matches_numeric():
    x_np = np.random.randn(2, 1, 2).astype(np.float64)
    w_ih_np = np.random.randn(2, 8).astype(np.float64)
    w_hh_np = np.random.randn(2, 8).astype(np.float64)
    b_ih_np = np.random.randn(8).astype(np.float64)
    b_hh_np = np.random.randn(8).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    out, (h_n, c_n) = F.lstm(
        x,
        Tensor(w_ih_np, requires_grad=True),
        Tensor(w_hh_np, requires_grad=True),
        Tensor(b_ih_np, requires_grad=True),
        Tensor(b_hh_np, requires_grad=True),
    )
    loss = out.sum() + h_n.sum() + c_n.sum()
    loss.backward()

    def f_x(v):
        y, (h_last, c_last) = F.lstm(
            Tensor(v),
            Tensor(w_ih_np),
            Tensor(w_hh_np),
            Tensor(b_ih_np),
            Tensor(b_hh_np),
        )
        return (y.sum() + h_last.sum() + c_last.sum()).item()

    num_x = _numeric_grad(f_x, x_np.copy())
    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)


def test_functional_gru_backward_shapes():
    x = Tensor(np.random.randn(3, 2, 4).astype(np.float64), requires_grad=True)
    w_ih = Tensor(np.random.randn(4, 15).astype(np.float64), requires_grad=True)
    w_hh = Tensor(np.random.randn(5, 15).astype(np.float64), requires_grad=True)
    b_ih = Tensor(np.random.randn(15).astype(np.float64), requires_grad=True)
    b_hh = Tensor(np.random.randn(15).astype(np.float64), requires_grad=True)

    y, h_n = F.gru(x, w_ih, w_hh, b_ih, b_hh)
    loss = y.sum() + h_n.sum()
    loss.backward()

    assert y.shape == (3, 2, 5)
    assert h_n.shape == (1, 2, 5)
    assert x.grad.shape == x.shape
    assert w_ih.grad.shape == w_ih.shape
    assert w_hh.grad.shape == w_hh.shape
    assert b_ih.grad.shape == b_ih.shape
    assert b_hh.grad.shape == b_hh.shape


def test_rnn_lstm_gru_modules_multilayer_batch_first_backward():
    x = Tensor(np.random.randn(3, 4, 6).astype(np.float64), requires_grad=True)

    rnn = nn.RNN(6, 5, num_layers=2, nonlinearity="tanh", batch_first=True, dropout=0.2)
    lstm = nn.LSTM(6, 5, num_layers=2, batch_first=True, dropout=0.2)
    gru = nn.GRU(6, 5, num_layers=2, batch_first=True, dropout=0.2)

    y_rnn, h_rnn = rnn(x)
    y_lstm, (h_lstm, c_lstm) = lstm(x)
    y_gru, h_gru = gru(x)

    assert y_rnn.shape == (3, 4, 5)
    assert h_rnn.shape == (2, 3, 5)
    assert y_lstm.shape == (3, 4, 5)
    assert h_lstm.shape == (2, 3, 5)
    assert c_lstm.shape == (2, 3, 5)
    assert y_gru.shape == (3, 4, 5)
    assert h_gru.shape == (2, 3, 5)

    loss = y_rnn.sum() + h_rnn.sum() + y_lstm.sum() + h_lstm.sum() + c_lstm.sum() + y_gru.sum() + h_gru.sum()
    loss.backward()

    assert rnn.weight_ih_l0.grad is not None
    assert lstm.weight_ih_l0.grad is not None
    assert gru.weight_ih_l0.grad is not None


def test_bidirectional_modules_forward_and_backward():
    x = Tensor(np.random.randn(2, 5, 4).astype(np.float64), requires_grad=True)

    rnn = nn.RNN(4, 3, num_layers=2, batch_first=True, bidirectional=True, dropout=0.1)
    lstm = nn.LSTM(4, 3, num_layers=2, batch_first=True, bidirectional=True, dropout=0.1)
    gru = nn.GRU(4, 3, num_layers=2, batch_first=True, bidirectional=True, dropout=0.1)

    y_rnn, h_rnn = rnn(x)
    y_lstm, (h_lstm, c_lstm) = lstm(x)
    y_gru, h_gru = gru(x)

    assert y_rnn.shape == (2, 5, 6)
    assert y_lstm.shape == (2, 5, 6)
    assert y_gru.shape == (2, 5, 6)
    assert h_rnn.shape == (4, 2, 3)
    assert h_lstm.shape == (4, 2, 3)
    assert c_lstm.shape == (4, 2, 3)
    assert h_gru.shape == (4, 2, 3)

    loss = y_rnn.sum() + h_rnn.sum() + y_lstm.sum() + h_lstm.sum() + c_lstm.sum() + y_gru.sum() + h_gru.sum()
    loss.backward()

    assert rnn.weight_ih_l0_reverse.grad is not None
    assert lstm.weight_ih_l0_reverse.grad is not None
    assert gru.weight_ih_l0_reverse.grad is not None


def test_bidirectional_hx_cx_shapes():
    x = Tensor(np.random.randn(5, 2, 4).astype(np.float64), requires_grad=True)

    rnn = nn.RNN(4, 3, num_layers=2, bidirectional=True)
    h0 = Tensor(np.random.randn(4, 2, 3).astype(np.float64), requires_grad=True)
    y_rnn, h_rnn = rnn(x, h0)
    assert y_rnn.shape == (5, 2, 6)
    assert h_rnn.shape == (4, 2, 3)

    lstm = nn.LSTM(4, 3, num_layers=2, bidirectional=True)
    h0_l = Tensor(np.random.randn(4, 2, 3).astype(np.float64), requires_grad=True)
    c0_l = Tensor(np.random.randn(4, 2, 3).astype(np.float64), requires_grad=True)
    y_lstm, (h_lstm, c_lstm) = lstm(x, (h0_l, c0_l))
    assert y_lstm.shape == (5, 2, 6)
    assert h_lstm.shape == (4, 2, 3)
    assert c_lstm.shape == (4, 2, 3)

    gru = nn.GRU(4, 3, num_layers=2, bidirectional=True)
    h0_g = Tensor(np.random.randn(4, 2, 3).astype(np.float64), requires_grad=True)
    y_gru, h_gru = gru(x, h0_g)
    assert y_gru.shape == (5, 2, 6)
    assert h_gru.shape == (4, 2, 3)

    loss = y_rnn.sum() + h_rnn.sum() + y_lstm.sum() + h_lstm.sum() + c_lstm.sum() + y_gru.sum() + h_gru.sum()
    loss.backward()
    assert h0.grad is not None
    assert h0_l.grad is not None
    assert c0_l.grad is not None
    assert h0_g.grad is not None
