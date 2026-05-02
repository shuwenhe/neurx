import os

import numpy as np

from neurx import Tensor
from neurx.compile import supports_runtime_function, try_invoke_ops_function
from neurx.nn import Embedding, LayerNorm, Linear, MLP, MultiHeadAttention, RMSNorm, TransformerBlock
from neurx.nn.attention import ScaledDotProductAttention
from neurx.nn import functional as F
from neurx.optim import Adam, AdamW, RMSprop, SGD


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


def test_s_runtime_sub_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "sub")
    out = Tensor([10.0, 20.0, 30.0]) - Tensor([1.0, 2.0, 3.0])
    assert np.allclose(out.to_numpy(), [9.0, 18.0, 27.0])
    assert getattr(out, "_runtime_backend", None) == "s"


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


def test_s_runtime_div_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "div")
    out = Tensor([10.0, 20.0, 30.0]) / Tensor([2.0, 4.0, 5.0])
    assert np.allclose(out.to_numpy(), [5.0, 5.0, 6.0])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_pow_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "pow")
    out = Tensor([2.0, 3.0, 4.0]) ** Tensor([3.0, 2.0, 0.5])
    assert np.allclose(out.to_numpy(), [8.0, 9.0, 2.0])
    assert getattr(out, "_runtime_backend", None) == "s"


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


def test_s_runtime_linear_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "linear")
    x = Tensor([[1.0, 2.0], [3.0, 4.0]])
    weight = Tensor([[10.0, 20.0, 30.0], [40.0, 50.0, 60.0]])
    bias = Tensor([1.0, 2.0, 3.0])
    out = F.linear(x, weight, bias)
    assert np.allclose(out.to_numpy(), x.to_numpy() @ weight.to_numpy() + bias.to_numpy())
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_linear_module_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    layer = Linear(2, 3)
    layer.weight.data = np.array([[10.0, 20.0, 30.0], [40.0, 50.0, 60.0]])
    layer.bias.data = np.array([1.0, 2.0, 3.0])
    x = Tensor([[1.0, 2.0], [3.0, 4.0]])
    out = layer(x)
    assert np.allclose(out.to_numpy(), x.to_numpy() @ layer.weight.to_numpy() + layer.bias.to_numpy())
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_layer_norm_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "layer_norm")
    x = Tensor([[1.0, 2.0, 3.0], [2.0, 4.0, 6.0]])
    weight = Tensor([1.0, 1.5, 2.0])
    bias = Tensor([0.5, 0.25, -0.5])
    out = F.layer_norm(x, 3, weight=weight, bias=bias, eps=1e-5)
    mean = x.to_numpy().mean(axis=-1, keepdims=True)
    var = x.to_numpy().var(axis=-1, keepdims=True)
    expected = (x.to_numpy() - mean) / np.sqrt(var + 1e-5) * weight.to_numpy() + bias.to_numpy()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_layer_norm_module_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    layer = LayerNorm(3)
    x = Tensor([[1.0, 2.0, 3.0], [2.0, 4.0, 6.0]])
    out = layer(x)
    mean = x.to_numpy().mean(axis=-1, keepdims=True)
    var = x.to_numpy().var(axis=-1, keepdims=True)
    expected = (x.to_numpy() - mean) / np.sqrt(var + layer.eps)
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_rms_norm_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "rms_norm")
    x = Tensor([[1.0, 2.0, 3.0], [2.0, 4.0, 6.0]])
    weight = Tensor([1.0, 1.5, 2.0])
    bias = Tensor([0.5, 0.25, -0.5])
    out = F.rms_norm(x, 3, weight=weight, bias=bias, eps=1e-6)
    rms = np.sqrt((x.to_numpy() ** 2).mean(axis=-1, keepdims=True) + 1e-6)
    expected = x.to_numpy() / rms * weight.to_numpy() + bias.to_numpy()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_rms_norm_module_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    layer = RMSNorm(3)
    x = Tensor([[1.0, 2.0, 3.0], [2.0, 4.0, 6.0]])
    out = layer(x)
    rms = np.sqrt((x.to_numpy() ** 2).mean(axis=-1, keepdims=True) + layer.eps)
    expected = x.to_numpy() / rms
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_scaled_dot_product_attention_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "scaled_dot_product_attention")
    query = Tensor([[[1.0, 0.0], [0.0, 1.0]]])
    key = Tensor([[[1.0, 0.0], [0.0, 1.0]]])
    value = Tensor([[[10.0, 20.0], [30.0, 40.0]]])
    output, weights = ScaledDotProductAttention(dropout_p=0.0)(query, key, value)
    scores = query.to_numpy() @ np.swapaxes(key.to_numpy(), -2, -1) / np.sqrt(2.0)
    shifted = scores - np.max(scores, axis=-1, keepdims=True)
    expected_weights = np.exp(shifted) / np.exp(shifted).sum(axis=-1, keepdims=True)
    expected_output = expected_weights @ value.to_numpy()
    assert np.allclose(weights.to_numpy(), expected_weights)
    assert np.allclose(output.to_numpy(), expected_output)
    assert getattr(output, "_runtime_backend", None) == "s"
    assert getattr(weights, "_runtime_backend", None) == "s"


def test_s_runtime_causal_attention_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "causal_attention")
    query = Tensor([[[1.0, 0.0], [0.0, 1.0]]])
    key = Tensor([[[1.0, 0.0], [0.0, 1.0]]])
    value = Tensor([[[10.0, 20.0], [30.0, 40.0]]])
    output, weights = ScaledDotProductAttention(dropout_p=0.0)(query, key, value, is_causal=True)
    scores = query.to_numpy() @ np.swapaxes(key.to_numpy(), -2, -1) / np.sqrt(2.0)
    scores[:, 0, 1] = -1.0e9
    shifted = scores - np.max(scores, axis=-1, keepdims=True)
    expected_weights = np.exp(shifted) / np.exp(shifted).sum(axis=-1, keepdims=True)
    expected_output = expected_weights @ value.to_numpy()
    assert np.allclose(weights.to_numpy(), expected_weights)
    assert np.allclose(output.to_numpy(), expected_output)
    assert getattr(output, "_runtime_backend", None) == "s"
    assert getattr(weights, "_runtime_backend", None) == "s"


def test_s_runtime_kv_cache_attention_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "kv_cache_attention")
    query = np.array([[[[0.0, 1.0]]]])
    key = np.array([[[[0.0, 1.0]]]])
    value = np.array([[[[30.0, 40.0]]]])
    past_key = np.array([[[[1.0, 0.0]]]])
    past_value = np.array([[[[10.0, 20.0]]]])
    output, weights, next_key, next_value = try_invoke_ops_function("kv_cache_attention", query, key, value, past_key, past_value, True)
    full_key = np.concatenate([past_key, key], axis=2)
    full_value = np.concatenate([past_value, value], axis=2)
    scores = query @ np.swapaxes(full_key, -2, -1) / np.sqrt(2.0)
    shifted = scores - np.max(scores, axis=-1, keepdims=True)
    expected_weights = np.exp(shifted) / np.exp(shifted).sum(axis=-1, keepdims=True)
    expected_output = expected_weights @ full_value
    assert np.allclose(output, expected_output)
    assert np.allclose(weights, expected_weights)
    assert np.allclose(next_key, full_key)
    assert np.allclose(next_value, full_value)


def test_s_runtime_multihead_attention_cache_selected_for_inference(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    layer = MultiHeadAttention(n_embd=2, n_heads=1, dropout=0.0, max_seq_len=4)
    layer.qkv.weight.requires_grad = False
    layer.qkv.bias.requires_grad = False
    layer.out_proj.weight.requires_grad = False
    layer.out_proj.bias.requires_grad = False
    layer.qkv.weight.data = np.array([[1.0, 0.0, 1.0, 0.0, 1.0, 0.0], [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]])
    layer.qkv.bias.data = np.zeros(6)
    layer.out_proj.weight.data = np.eye(2)
    layer.out_proj.bias.data = np.zeros(2)
    x = Tensor([[[1.0, 0.0], [0.0, 1.0]]], requires_grad=False)
    out, cache = layer.forward_with_cache(x)
    assert out.shape == (1, 2, 2)
    assert cache[0].shape == (1, 1, 2, 2)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_qkv_projection_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "qkv_projection")
    x = np.arange(8, dtype=np.float64).reshape(1, 2, 4) / 10.0
    weight = np.arange(48, dtype=np.float64).reshape(4, 12) / 20.0
    bias = np.arange(12, dtype=np.float64) / 100.0
    q, k, v = try_invoke_ops_function("qkv_projection", x, weight, bias, 2)
    qkv = (x @ weight + bias).reshape(1, 2, 3, 2, 2).transpose(2, 0, 3, 1, 4)
    assert np.allclose(q, qkv[0])
    assert np.allclose(k, qkv[1])
    assert np.allclose(v, qkv[2])


def test_s_runtime_rope_apply_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "rope_apply")
    values = np.arange(8, dtype=np.float64).reshape(1, 1, 2, 4) / 10.0
    cos = np.array([[1.0, 0.5], [0.25, -0.5]])
    sin = np.array([[0.0, 0.5], [0.75, 0.5]])
    out = try_invoke_ops_function("rope_apply", values, cos, sin)
    expected = np.empty_like(values)
    expected[..., ::2] = values[..., ::2] * cos[None, None, :, :] - values[..., 1::2] * sin[None, None, :, :]
    expected[..., 1::2] = values[..., ::2] * sin[None, None, :, :] + values[..., 1::2] * cos[None, None, :, :]
    assert np.allclose(out, expected)


def test_s_runtime_mlp_block_selected_for_inference_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "mlp_block")
    mlp = MLP(2, hidden_dim=3, dropout=0.0)
    mlp.fc1.weight.requires_grad = False
    mlp.fc1.bias.requires_grad = False
    mlp.fc2.weight.requires_grad = False
    mlp.fc2.bias.requires_grad = False
    mlp.fc1.weight.data = np.array([[0.2, -0.1, 0.3], [0.4, 0.5, -0.2]])
    mlp.fc1.bias.data = np.array([0.01, -0.02, 0.03])
    mlp.fc2.weight.data = np.array([[0.3, -0.4], [0.2, 0.1], [-0.5, 0.6]])
    mlp.fc2.bias.data = np.array([0.05, -0.06])
    x = Tensor([[[0.5, -0.25], [0.1, 0.2]]], requires_grad=False)
    out = mlp(x)
    hidden = x.to_numpy() @ mlp.fc1.weight.to_numpy() + mlp.fc1.bias.to_numpy()
    hidden = hidden * (1.0 / (1.0 + np.exp(-1.702 * hidden)))
    expected = hidden @ mlp.fc2.weight.to_numpy() + mlp.fc2.bias.to_numpy()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_transformer_block_forward_intrinsic(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "transformer_block_forward")
    x = np.array([[[0.2, -0.1], [0.4, 0.3]]], dtype=np.float64)
    ln1_weight = np.array([1.0, 1.5])
    ln1_bias = np.array([0.01, -0.02])
    qkv_weight = np.arange(12, dtype=np.float64).reshape(2, 6) / 10.0
    qkv_bias = np.arange(6, dtype=np.float64) / 100.0
    out_weight = np.array([[0.2, -0.1], [0.3, 0.4]])
    out_bias = np.array([0.05, -0.03])
    ln2_weight = np.array([0.8, 1.2])
    ln2_bias = np.array([-0.01, 0.02])
    fc1_weight = np.array([[0.2, -0.1, 0.3], [0.4, 0.5, -0.2]])
    fc1_bias = np.array([0.01, -0.02, 0.03])
    fc2_weight = np.array([[0.3, -0.4], [0.2, 0.1], [-0.5, 0.6]])
    fc2_bias = np.array([0.05, -0.06])
    out = try_invoke_ops_function(
        "transformer_block_forward",
        x,
        ln1_weight,
        ln1_bias,
        qkv_weight,
        qkv_bias,
        out_weight,
        out_bias,
        ln2_weight,
        ln2_bias,
        fc1_weight,
        fc1_bias,
        fc2_weight,
        fc2_bias,
        1e-5,
        1,
    )
    mean = x.mean(axis=-1, keepdims=True)
    var = x.var(axis=-1, keepdims=True)
    norm1 = (x - mean) / np.sqrt(var + 1e-5) * ln1_weight + ln1_bias
    qkv = (norm1 @ qkv_weight + qkv_bias).reshape(1, 2, 3, 1, 2).transpose(2, 0, 3, 1, 4)
    q, k, v = qkv[0], qkv[1], qkv[2]
    scores = q @ np.swapaxes(k, -2, -1) / np.sqrt(2.0)
    scores[..., 0, 1] = -1.0e9
    shifted = scores - scores.max(axis=-1, keepdims=True)
    weights = np.exp(shifted) / np.exp(shifted).sum(axis=-1, keepdims=True)
    attn = (weights @ v).transpose(0, 2, 1, 3).reshape(1, 2, 2)
    residual = x + attn @ out_weight + out_bias
    mean = residual.mean(axis=-1, keepdims=True)
    var = residual.var(axis=-1, keepdims=True)
    norm2 = (residual - mean) / np.sqrt(var + 1e-5) * ln2_weight + ln2_bias
    hidden = norm2 @ fc1_weight + fc1_bias
    hidden = hidden * (1.0 / (1.0 + np.exp(-1.702 * hidden)))
    expected = residual + hidden @ fc2_weight + fc2_bias
    assert np.allclose(out, expected)


def test_s_runtime_transformer_block_module_selected_for_inference(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    block = TransformerBlock(n_embd=2, n_heads=1, dropout=0.0)
    for param in block.parameters():
        param.requires_grad = False
    x = Tensor([[[0.2, -0.1], [0.4, 0.3]]], requires_grad=False)
    out = block(x)
    expected = try_invoke_ops_function(
        "transformer_block_forward",
        x.data,
        block.ln1.weight.data,
        block.ln1.bias.data,
        block.attn.qkv.weight.data,
        block.attn.qkv.bias.data,
        block.attn.out_proj.weight.data,
        block.attn.out_proj.bias.data,
        block.ln2.weight.data,
        block.ln2.bias.data,
        block.mlp.fc1.weight.data,
        block.mlp.fc1.bias.data,
        block.mlp.fc2.weight.data,
        block.mlp.fc2.bias.data,
        block.ln1.eps,
        block.attn.n_heads,
    )
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_lm_head_logits_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "lm_head_logits")
    hidden = np.array([[[0.2, -0.1], [0.4, 0.3]]], dtype=np.float64)
    weight = np.array([[0.5, -0.2, 0.1], [0.3, 0.4, -0.6]], dtype=np.float64)
    bias = np.array([0.01, -0.02, 0.03], dtype=np.float64)
    out = try_invoke_ops_function("lm_head_logits", hidden, weight, bias)
    assert np.allclose(out, hidden @ weight + bias)


def test_s_runtime_sampling_top_k_top_p_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "sampling_top_k_top_p")
    logits = np.array([0.1, 1.0, 0.2, 0.9], dtype=np.float64)
    token_ids = np.array([1], dtype=np.int64)
    out = try_invoke_ops_function("sampling_top_k_top_p", logits, token_ids, 0.5, 2, 1.0, 2.0)
    expected = logits.copy()
    expected[1] /= 2.0
    filtered = np.full_like(expected, -np.inf)
    top_idx = np.argpartition(expected, -2)[-2:]
    filtered[top_idx] = expected[top_idx]
    expected = filtered / 0.5
    assert np.allclose(out[np.isfinite(out)], expected[np.isfinite(expected)])
    assert np.array_equal(np.isfinite(out), np.isfinite(expected))


def test_s_runtime_generation_step_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "generation_step")
    logits = np.array([0.1, 1.0, 0.2, 0.9], dtype=np.float64)
    token_ids = np.array([1], dtype=np.int64)
    next_id = try_invoke_ops_function("generation_step", logits, token_ids, 0.0, 2, 1.0, 2.0)
    assert next_id == 3


def test_s_runtime_embedding_lookup_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "embedding_lookup")
    weight = Tensor([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], requires_grad=True)
    out = F.embedding(np.array([[0, 2], [1, 0]]), weight)
    assert np.allclose(out.to_numpy(), [[[1.0, 2.0], [5.0, 6.0]], [[3.0, 4.0], [1.0, 2.0]]])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_embedding_module_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    layer = Embedding(3, 2)
    layer.weight.data = np.array([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
    out = layer(np.array([2, 0, 1]))
    assert np.allclose(out.to_numpy(), [[5.0, 6.0], [1.0, 2.0], [3.0, 4.0]])
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_unary_math_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    for name in ("exp", "log", "sqrt"):
        assert supports_runtime_function("ops", name)
    values = Tensor([1.0, 4.0, 9.0])
    exp_out = values.exp()
    log_out = values.log()
    sqrt_out = values.sqrt()
    assert np.allclose(exp_out.to_numpy(), np.exp([1.0, 4.0, 9.0]))
    assert np.allclose(log_out.to_numpy(), np.log([1.0, 4.0, 9.0]))
    assert np.allclose(sqrt_out.to_numpy(), [1.0, 2.0, 3.0])
    assert getattr(exp_out, "_runtime_backend", None) == "s"
    assert getattr(log_out, "_runtime_backend", None) == "s"
    assert getattr(sqrt_out, "_runtime_backend", None) == "s"


def test_s_runtime_reductions_selected_for_int_dim(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "sum")
    assert supports_runtime_function("ops", "mean")
    values = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    sum_out = values.sum(dim=1)
    mean_out = values.mean(dim=0, keepdim=True)
    assert np.allclose(sum_out.to_numpy(), [6.0, 15.0])
    assert np.allclose(mean_out.to_numpy(), [[2.5, 3.5, 4.5]])
    assert getattr(sum_out, "_runtime_backend", None) == "s"
    assert getattr(mean_out, "_runtime_backend", None) == "s"


def test_s_runtime_mse_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "mse_loss")
    out = F.mse_loss(Tensor([1.0, 2.0, 3.0]), Tensor([1.0, 1.0, 5.0]), reduction="mean")
    assert np.allclose(out.to_numpy(), np.array(5.0 / 3.0))
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_bce_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "bce_loss")
    x = Tensor(np.array([0.2, 0.7, 0.9], dtype=np.float64))
    target = np.array([0.0, 1.0, 1.0], dtype=np.float64)
    out = F.bce_loss(x, target, reduction="mean")
    clipped = np.clip(x.to_numpy(), 1e-7, 1 - 1e-7)
    expected = -(target * np.log(clipped) + (1.0 - target) * np.log(1.0 - clipped)).mean()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_bce_with_logits_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "bce_with_logits_loss")
    logits = Tensor(np.array([0.5, -1.2, 2.0], dtype=np.float64))
    target = np.array([1.0, 0.0, 1.0], dtype=np.float64)
    out = F.bce_with_logits_loss(logits, target, reduction="mean")
    x = logits.to_numpy()
    expected = (np.maximum(x, 0.0) - x * target + np.log1p(np.exp(-np.abs(x)))).mean()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_l1_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "l1_loss")
    out = F.l1_loss(Tensor([1.0, 2.0, 3.0]), Tensor([1.0, 1.0, 5.0]), reduction="sum")
    assert np.allclose(out.to_numpy(), np.array(3.0))
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_smooth_l1_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "smooth_l1_loss")
    pred = Tensor(np.array([0.0, 2.0, -3.0], dtype=np.float64))
    target = np.array([0.0, 0.0, -1.0], dtype=np.float64)
    out = F.smooth_l1_loss(pred, target, reduction="mean", beta=1.0)
    diff = pred.to_numpy() - target
    expected = np.where(np.abs(diff) < 1.0, 0.5 * diff * diff, np.abs(diff) - 0.5).mean()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_kl_div_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "kl_div_loss")
    inp = Tensor(np.log(np.array([[0.2, 0.8], [0.6, 0.4]], dtype=np.float64)))
    target = np.array([[0.3, 0.7], [0.5, 0.5]], dtype=np.float64)
    out = F.kl_div_loss(inp, target, reduction="batchmean", log_target=False)
    expected = (target * (np.log(np.clip(target, 1e-10, None)) - inp.to_numpy())).sum() / inp.shape[0]
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_mse_loss_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = F.mse_loss(Tensor([1.0, 2.0, 3.0]), Tensor([1.0, 1.0, 5.0]), reduction="sum")
    assert np.allclose(out.to_numpy(), np.array(5.0))
    assert getattr(out, "_runtime_backend", None) != "s"


def test_s_runtime_nll_loss_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "nll_loss")
    log_probs = Tensor(np.log(np.array([[0.7, 0.2, 0.1], [0.1, 0.8, 0.1]])))
    out = F.nll_loss(log_probs, np.array([0, 1]), reduction="mean")
    expected = -np.log(np.array([0.7, 0.8])).mean()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_cross_entropy_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "cross_entropy")
    logits = Tensor([[2.0, 0.0, -1.0], [0.0, 3.0, 1.0]])
    out = F.cross_entropy(logits, np.array([0, 1]), reduction="mean")
    shifted = logits.to_numpy() - np.max(logits.to_numpy(), axis=1, keepdims=True)
    log_probs = shifted - np.log(np.exp(shifted).sum(axis=1, keepdims=True))
    expected = -np.array([log_probs[0, 0], log_probs[1, 1]]).mean()
    assert np.allclose(out.to_numpy(), expected)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_sgd_step_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "sgd_step")
    param = Tensor([1.0, 2.0, 3.0], requires_grad=True)
    param.grad = np.array([0.1, 0.2, 0.3])
    optimizer = SGD([param], lr=0.5)
    optimizer.step()
    assert np.allclose(param.to_numpy(), [0.95, 1.9, 2.85])
    assert getattr(optimizer, "_runtime_backend", None) == "s"


def test_s_runtime_adam_step_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "adam_step")
    param = Tensor([1.0, 2.0], requires_grad=True)
    param.grad = np.array([0.1, -0.2])
    optimizer = Adam([param], lr=0.1, betas=(0.9, 0.999), eps=1e-8)
    optimizer.step()
    assert np.allclose(param.to_numpy(), [0.9, 2.1], atol=1e-6)
    assert getattr(optimizer, "_runtime_backend", None) == "s"


def test_s_runtime_adamw_step_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "adamw_step")
    param = Tensor([1.0, 2.0], requires_grad=True)
    param.grad = np.array([0.1, -0.2])
    optimizer = AdamW([param], lr=0.1, betas=(0.9, 0.999), eps=1e-8, weight_decay=0.0)
    optimizer.step()
    assert np.allclose(param.to_numpy(), [0.9, 2.1], atol=1e-6)
    assert getattr(optimizer, "_runtime_backend", None) == "s"


def test_s_runtime_rmsprop_step_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "rmsprop_step")
    param = Tensor([1.0, 2.0], requires_grad=True)
    param.grad = np.array([0.1, -0.2])
    optimizer = RMSprop([param], lr=0.1, alpha=0.99, eps=1e-8, weight_decay=0.0)
    optimizer.step()
    expected_square_avg = 0.01 * (param.grad ** 2)
    expected = np.array([1.0, 2.0]) - 0.1 * param.grad / (np.sqrt(expected_square_avg) + 1e-8)
    assert np.allclose(param.to_numpy(), expected, atol=1e-6)
    assert getattr(optimizer, "_runtime_backend", None) == "s"


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


def test_s_runtime_softplus_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "softplus")
    out = Tensor([-1.0, 0.0, 1.0]).softplus(beta=1.0)
    expected = np.log1p(np.exp(np.array([-1.0, 0.0, 1.0])))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_softplus_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-1.0, 0.0, 1.0]).softplus(beta=1.0)
    expected = np.log1p(np.exp(np.array([-1.0, 0.0, 1.0])))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_softplus_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.softplus(Tensor([-1.0, 1.0]), beta=1.0)
    expected = np.log1p(np.exp(np.array([-1.0, 1.0])))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_softsign_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "softsign")
    out = Tensor([-2.0, 0.0, 2.0]).softsign()
    expected = np.array([-2.0, 0.0, 2.0]) / (1.0 + np.abs(np.array([-2.0, 0.0, 2.0])))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_softsign_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.0, 2.0]).softsign()
    expected = np.array([-2.0, 0.0, 2.0]) / (1.0 + np.abs(np.array([-2.0, 0.0, 2.0])))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_softsign_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.softsign(Tensor([-2.0, 2.0]))
    expected = np.array([-2.0, 2.0]) / (1.0 + np.abs(np.array([-2.0, 2.0])))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_swish_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "swish")
    values = np.array([-1.0, 0.0, 1.0])
    out = Tensor(values).swish(beta=1.0)
    expected = values / (1.0 + np.exp(-values))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_swish_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    values = np.array([-1.0, 0.0, 1.0])
    out = Tensor(values).swish(beta=1.0)
    expected = values / (1.0 + np.exp(-values))
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_swish_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    values = np.array([-1.0, 1.0])
    out = F.swish(Tensor(values), beta=1.0)
    expected = values / (1.0 + np.exp(-values))
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


def test_s_runtime_prelu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "prelu")
    out = Tensor([-2.0, 0.5, 3.0]).prelu(Tensor(0.25))
    expected = np.array([-0.5, 0.5, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_prelu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.5, 3.0]).prelu(Tensor(0.25))
    expected = np.array([-0.5, 0.5, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_prelu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.prelu(Tensor([-2.0, 3.0]), Tensor(0.25))
    expected = np.array([-0.5, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_s_runtime_rrelu_selected_for_cpu_tensors(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    assert supports_runtime_function("ops", "rrelu")
    out = Tensor([-2.0, 0.5, 3.0]).rrelu(lower=0.1, upper=0.3, training=False)
    expected = np.array([-0.4, 0.5, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"


def test_python_fallback_rrelu_when_s_ops_disabled(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "python")
    out = Tensor([-2.0, 0.5, 3.0]).rrelu(lower=0.1, upper=0.3, training=False)
    expected = np.array([-0.4, 0.5, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "python"


def test_functional_rrelu_reuses_tensor_dispatch(monkeypatch):
    monkeypatch.setenv("NEURX_S_OPS_BACKEND", "auto")
    out = F.rrelu(Tensor([-2.0, 3.0]), lower=0.1, upper=0.3, training=False)
    expected = np.array([-0.4, 3.0])
    assert np.allclose(out.to_numpy(), expected, atol=1e-7)
    assert getattr(out, "_runtime_backend", None) == "s"
