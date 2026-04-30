import os

import numpy as np

from neurx import Tensor
from neurx.compile import supports_runtime_function
from neurx.nn import functional as F


def test_s_runtime_add_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "add")
    out = Tensor([1.0, 2.0, 3.0]) + Tensor([10.0, 20.0, 30.0])
    assert np.allclose(out.to_numpy(), [11.0, 22.0, 33.0])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([1.0, 2.0, 3.0]) + Tensor([10.0, 20.0, 30.0])
    assert np.allclose(out.to_numpy(), [11.0, 22.0, 33.0])
    assert getattr(out, "_runtime_backend", None) == "python"


def test_s_runtime_mul_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "mul")
    out = Tensor([1.0, 2.0, 3.0]) * Tensor([10.0, 20.0, 30.0])
    assert np.allclose(out.to_numpy(), [10.0, 40.0, 90.0])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_mul_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([1.0, 2.0, 3.0]) * Tensor([10.0, 20.0, 30.0])
    assert np.allclose(out.to_numpy(), [10.0, 40.0, 90.0])
    assert getattr(out, "_runtime_backend", None) == "python"


def test_s_runtime_matmul_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "matmul")
    a = Tensor([[1.0, 2.0], [3.0, 4.0]])
    b = Tensor([[10.0, 20.0], [30.0, 40.0]])
    out = a @ b
    assert np.allclose(out.to_numpy(), [[70.0, 100.0], [150.0, 220.0]])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_matmul_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    a = Tensor([[1.0, 2.0], [3.0, 4.0]])
    b = Tensor([[10.0, 20.0], [30.0, 40.0]])
    out = a @ b
    assert np.allclose(out.to_numpy(), [[70.0, 100.0], [150.0, 220.0]])
    assert getattr(out, "_runtime_backend", None) == "python"


def test_s_runtime_relu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "relu")
    out = Tensor([-2.0, 0.0, 3.0]).relu()
    assert np.allclose(out.to_numpy(), [0.0, 0.0, 3.0])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_relu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.0, 3.0]).relu()
    assert np.allclose(out.to_numpy(), [0.0, 0.0, 3.0])
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_relu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.relu(Tensor([-1.0, 2.0]))
    assert np.allclose(out.to_numpy(), [0.0, 2.0])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_sigmoid_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "sigmoid")
    out = Tensor([-1.0, 0.0, 1.0]).sigmoid()
    expected = np.array([0.26894142, 0.5, 0.73105858])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_sigmoid_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-1.0, 0.0, 1.0]).sigmoid()
    expected = np.array([0.26894142, 0.5, 0.73105858])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_sigmoid_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.sigmoid(Tensor([-1.0, 1.0]))
    expected = np.array([0.26894142, 0.73105858])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_tanh_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "tanh")
    out = Tensor([-1.0, 0.0, 1.0]).tanh()
    expected = np.array([-0.76159416, 0.0, 0.76159416])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_tanh_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-1.0, 0.0, 1.0]).tanh()
    expected = np.array([-0.76159416, 0.0, 0.76159416])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_tanh_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.tanh(Tensor([-1.0, 1.0]))
    expected = np.array([-0.76159416, 0.76159416])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_softmax_selected_for_dim(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "softmax")
    out = Tensor([[1.0, 2.0, 3.0]]).softmax(dim=1)
    expected = np.array([[0.09003057, 0.24472847, 0.66524096]])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_softmax_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([[1.0, 2.0, 3.0]]).softmax(dim=1)
    expected = np.array([[0.09003057, 0.24472847, 0.66524096]])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_softmax_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.softmax(Tensor([[1.0, 2.0, 3.0]]), dim=1)
    expected = np.array([[0.09003057, 0.24472847, 0.66524096]])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_log_softmax_selected_for_dim(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "log_softmax")
    out = Tensor([[1.0, 2.0, 3.0]]).log_softmax(dim=1)
    expected = np.array([[-2.40760596, -1.40760596, -0.40760596]])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_log_softmax_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([[1.0, 2.0, 3.0]]).log_softmax(dim=1)
    expected = np.array([[-2.40760596, -1.40760596, -0.40760596]])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_log_softmax_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.log_softmax(Tensor([[1.0, 2.0, 3.0]]), dim=1)
    expected = np.array([[-2.40760596, -1.40760596, -0.40760596]])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_leaky_relu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "leaky_relu")
    out = Tensor([-2.0, 0.0, 3.0]).leaky_relu(negative_slope=0.1)
    expected = np.array([-0.2, 0.0, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_leaky_relu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.0, 3.0]).leaky_relu(negative_slope=0.1)
    expected = np.array([-0.2, 0.0, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_leaky_relu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.leaky_relu(Tensor([-2.0, 3.0]), negative_slope=0.1)
    expected = np.array([-0.2, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_elu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "elu")
    out = Tensor([-2.0, 0.0, 3.0]).elu(alpha=1.0)
    expected = np.array([-0.86466472, 0.0, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_elu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.0, 3.0]).elu(alpha=1.0)
    expected = np.array([-0.86466472, 0.0, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_elu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.elu(Tensor([-2.0, 3.0]), alpha=1.0)
    expected = np.array([-0.86466472, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_selu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "selu")
    out = Tensor([-2.0, 0.0, 3.0]).selu()
    expected = np.array([-1.52016647, 0.0, 3.15210296])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_selu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.0, 3.0]).selu()
    expected = np.array([-1.52016647, 0.0, 3.15210296])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_selu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.selu(Tensor([-2.0, 3.0]))
    expected = np.array([-1.52016647, 3.15210296])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_gelu_exact_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "gelu")
    out = Tensor([-1.0, 0.0, 1.0]).gelu(approximate=False)
    expected = np.array([-0.15865525, 0.0, 0.84134475])
    assert np.allclose(out.to_numpy(), expected, atol=1e-6)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_gelu_approx_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = Tensor([-1.0, 0.0, 1.0]).gelu(approximate=True)
    expected = np.array([-0.15880801, 0.0, 0.84119199])
    assert np.allclose(out.to_numpy(), expected, atol=1e-6)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_gelu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-1.0, 0.0, 1.0]).gelu(approximate=False)
    expected = np.array([-0.15865525, 0.0, 0.84134475])
    assert np.allclose(out.to_numpy(), expected, atol=1e-6)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_gelu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.gelu(Tensor([-1.0, 1.0]), approximate=True)
    expected = np.array([-0.15880801, 0.84119199])
    assert np.allclose(out.to_numpy(), expected, atol=1e-6)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_silu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "silu")
    out = Tensor([-1.0, 0.0, 1.0]).silu()
    expected = np.array([-0.26894142, 0.0, 0.73105858])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_silu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-1.0, 0.0, 1.0]).silu()
    expected = np.array([-0.26894142, 0.0, 0.73105858])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_silu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.silu(Tensor([-1.0, 1.0]))
    expected = np.array([-0.26894142, 0.73105858])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_mish_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "mish")
    out = Tensor([-1.0, 0.0, 1.0]).mish()
    expected = np.array([-0.30340146, 0.0, 0.86509839])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_mish_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-1.0, 0.0, 1.0]).mish()
    expected = np.array([-0.30340146, 0.0, 0.86509839])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_mish_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.mish(Tensor([-1.0, 1.0]))
    expected = np.array([-0.30340146, 0.86509839])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_hardtanh_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "hardtanh")
    out = Tensor([-2.0, -0.5, 2.0]).hardtanh(min_val=-1.0, max_val=1.0)
    expected = np.array([-1.0, -0.5, 1.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_hardtanh_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, -0.5, 2.0]).hardtanh(min_val=-1.0, max_val=1.0)
    expected = np.array([-1.0, -0.5, 1.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_hardtanh_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.hardtanh(Tensor([-2.0, 2.0]), min_val=-1.0, max_val=1.0)
    expected = np.array([-1.0, 1.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_hardswish_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "hardswish")
    out = Tensor([-4.0, -1.0, 3.0]).hardswish()
    expected = np.array([0.0, -0.33333333, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_hardswish_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-4.0, -1.0, 3.0]).hardswish()
    expected = np.array([0.0, -0.33333333, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_hardswish_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.hardswish(Tensor([-4.0, 3.0]))
    expected = np.array([0.0, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"
