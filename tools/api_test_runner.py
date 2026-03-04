#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from collections import OrderedDict
from typing import Callable

import numpy as np

from neurx import Tensor, nn, optim
from neurx.nn import functional as F


_API_CASES: "OrderedDict[str, tuple[str, Callable[[], None]]]" = OrderedDict()


def register(api_name: str, group: str):
    def _decorator(fn: Callable[[], None]):
        if api_name in _API_CASES:
            raise ValueError(f"duplicate api case: {api_name}")
        _API_CASES[api_name] = (group, fn)
        return fn

    return _decorator


def _rand(shape, requires_grad=False):
    arr = np.random.randn(*shape).astype(np.float64)
    return Tensor(arr, requires_grad=requires_grad, device="cpu")


@register("neurx.add", "Tensor")
def _case_tensor_add():
    a = _rand((2, 3))
    b = _rand((2, 3))
    out = a + b
    assert out.shape == (2, 3)


@register("neurx.mul", "Tensor")
def _case_tensor_mul():
    a = _rand((2, 3))
    b = _rand((2, 3))
    out = a * b
    assert out.shape == (2, 3)


@register("neurx.matmul", "Tensor")
def _case_tensor_matmul():
    a = _rand((4, 3))
    b = _rand((3, 2))
    out = a @ b
    assert out.shape == (4, 2)


@register("neurx.reshape", "Tensor")
def _case_tensor_reshape():
    x = _rand((2, 3, 4))
    y = x.reshape(6, 4)
    assert y.shape == (6, 4)


@register("neurx.flatten", "Tensor")
def _case_tensor_flatten():
    x = _rand((2, 3, 4))
    y = x.flatten(1, 2)
    assert y.shape == (2, 12)


@register("neurx.transpose", "Tensor")
def _case_tensor_transpose():
    x = _rand((2, 3, 4))
    y = x.transpose(1, 2)
    assert y.shape == (2, 4, 3)


@register("neurx.permute", "Tensor")
def _case_tensor_permute():
    x = _rand((2, 3, 4))
    y = x.permute(2, 0, 1)
    assert y.shape == (4, 2, 3)


@register("neurx.sum", "Tensor")
def _case_tensor_sum():
    x = _rand((2, 3, 4))
    y = x.sum(axis=1)
    assert y.shape == (2, 4)


@register("neurx.mean", "Tensor")
def _case_tensor_mean():
    x = _rand((2, 3, 4))
    y = x.mean(axis=2)
    assert y.shape == (2, 3)


@register("neurx.max", "Tensor")
def _case_tensor_max():
    x = _rand((2, 3, 4))
    v, i = x.max(axis=1)
    assert v.shape == (2, 4)
    assert i.shape == (2, 4)


@register("neurx.min", "Tensor")
def _case_tensor_min():
    x = _rand((2, 3, 4))
    v, i = x.min(axis=1)
    assert v.shape == (2, 4)
    assert i.shape == (2, 4)


@register("neurx.argmax", "Tensor")
def _case_tensor_argmax():
    x = _rand((2, 3, 4))
    i = x.argmax(axis=2)
    assert i.shape == (2, 3)


@register("neurx.argmin", "Tensor")
def _case_tensor_argmin():
    x = _rand((2, 3, 4))
    i = x.argmin(axis=2)
    assert i.shape == (2, 3)


@register("neurx.backward", "Tensor")
def _case_tensor_backward():
    x = _rand((3, 4), requires_grad=True)
    y = (x * x).mean()
    y.backward()
    assert x.grad is not None
    assert x.grad.shape == x.shape


@register("neurx.item", "Tensor")
def _case_tensor_item():
    x = _rand((2, 2))
    y = x.mean().item()
    assert isinstance(y, float)


@register("neurx.clone", "Tensor")
def _case_tensor_clone():
    x = _rand((2, 2), requires_grad=True)
    y = x.clone()
    assert y.shape == x.shape
    assert y.requires_grad == x.requires_grad


@register("neurx.detach", "Tensor")
def _case_tensor_detach():
    x = _rand((2, 2), requires_grad=True)
    y = x.detach()
    assert y.shape == x.shape
    assert y.requires_grad is False


@register("neurx.to", "Tensor")
def _case_tensor_to():
    x = _rand((2, 2))
    y = x.to(dtype=np.float32, device="cpu")
    assert y.shape == x.shape
    assert y.dtype == np.float32


@register("neurx.zero_grad", "Tensor")
def _case_tensor_zero_grad():
    x = _rand((2, 2), requires_grad=True)
    y = (x * x).sum()
    y.backward()
    assert x.grad is not None
    x.zero_grad()
    assert np.allclose(x.grad, 0.0)


@register("nn.Module.parameters", "nn")
def _case_nn_module_parameters():
    m = nn.Linear(4, 2)
    params = list(m.parameters())
    assert len(params) == 2


@register("nn.Module.state_dict", "nn")
def _case_nn_module_state_dict():
    m = nn.Linear(3, 2)
    state = m.state_dict()
    m2 = nn.Linear(3, 2)
    m2.load_state_dict(state)
    for k, v in state.items():
        assert np.allclose(m2.state_dict()[k], v)


@register("nn.Embedding", "nn")
def _case_nn_embedding():
    m = nn.Embedding(16, 8)
    out = m(np.array([[1, 2], [3, 4]], dtype=np.int64))
    assert out.shape == (2, 2, 8)


@register("nn.Linear", "nn")
def _case_nn_linear():
    m = nn.Linear(4, 3)
    out = m(_rand((5, 4)))
    assert out.shape == (5, 3)


@register("nn.LayerNorm", "nn")
def _case_nn_layernorm():
    m = nn.LayerNorm(4)
    out = m(_rand((2, 3, 4)))
    assert out.shape == (2, 3, 4)


@register("nn.RMSNorm", "nn")
def _case_nn_rmsnorm():
    m = nn.RMSNorm(4)
    out = m(_rand((2, 3, 4)))
    assert out.shape == (2, 3, 4)


@register("nn.Dropout", "nn")
def _case_nn_dropout():
    m = nn.Dropout(0.2)
    x = _rand((4, 4))
    out = m(x)
    assert out.shape == x.shape
    m.eval()
    out2 = m(x)
    assert out2.shape == x.shape


@register("nn.Softmax", "nn")
def _case_nn_softmax():
    m = nn.Softmax(axis=-1)
    x = _rand((2, 3, 4))
    out = m(x).to_numpy()
    assert out.shape == (2, 3, 4)
    assert np.allclose(out.sum(axis=-1), 1.0, atol=1e-6)


@register("nn.GELU", "nn")
def _case_nn_gelu():
    m = nn.GELU()
    out = m(_rand((2, 3)))
    assert out.shape == (2, 3)


@register("nn.Sigmoid", "nn")
def _case_nn_sigmoid():
    m = nn.Sigmoid()
    out = m(_rand((2, 3))).to_numpy()
    assert out.shape == (2, 3)
    assert np.all(out >= 0.0) and np.all(out <= 1.0)


@register("nn.SiLU", "nn")
def _case_nn_silu():
    m = nn.SiLU()
    out = m(_rand((2, 3)))
    assert out.shape == (2, 3)


@register("nn.ModuleList", "nn")
def _case_nn_modulelist():
    ml = nn.ModuleList([nn.Linear(4, 4), nn.Linear(4, 4)])
    x = _rand((2, 4))
    for layer in ml:
        x = layer(x)
    assert x.shape == (2, 4)


@register("nn.ModuleDict", "nn")
def _case_nn_moduledict():
    md = nn.ModuleDict({"a": nn.Linear(4, 4), "b": nn.Linear(4, 2)})
    x = _rand((2, 4))
    x = md["a"](x)
    x = md["b"](x)
    assert x.shape == (2, 2)


@register("nn.MultiHeadAttention", "nn")
def _case_nn_mha():
    m = nn.MultiHeadAttention(n_embd=8, n_heads=2, dropout=0.0, max_seq_len=16)
    out = m(_rand((2, 4, 8)))
    assert out.shape == (2, 4, 8)


@register("nn.MLP", "nn")
def _case_nn_mlp():
    m = nn.MLP(n_embd=8, hidden_dim=16, dropout=0.0)
    out = m(_rand((2, 4, 8)))
    assert out.shape == (2, 4, 8)


@register("nn.MoE", "nn")
def _case_nn_moe():
    m = nn.MoE(n_embd=8, num_experts=2, top_k=1, hidden_dim=16, dropout=0.0)
    out = m(_rand((2, 4, 8)))
    assert out.shape == (2, 4, 8)


@register("nn.TransformerBlock", "nn")
def _case_nn_transformer_block():
    m = nn.TransformerBlock(n_embd=8, n_heads=2, dropout=0.0)
    out = m(_rand((2, 4, 8)))
    assert out.shape == (2, 4, 8)


@register("nn.functional.relu", "nn")
def _case_fn_relu():
    out = F.relu(_rand((2, 3)))
    assert out.shape == (2, 3)


@register("nn.functional.sigmoid", "nn")
def _case_fn_sigmoid():
    out = F.sigmoid(_rand((2, 3))).to_numpy()
    assert out.shape == (2, 3)
    assert np.all(out >= 0.0) and np.all(out <= 1.0)


@register("nn.functional.silu", "nn")
def _case_fn_silu():
    out = F.silu(_rand((2, 3)))
    assert out.shape == (2, 3)


@register("nn.functional.gelu", "nn")
def _case_fn_gelu():
    out = F.gelu(_rand((2, 3)))
    assert out.shape == (2, 3)


@register("nn.functional.softmax", "nn")
def _case_fn_softmax():
    out = F.softmax(_rand((2, 3, 4)), axis=-1).to_numpy()
    assert out.shape == (2, 3, 4)
    assert np.allclose(out.sum(axis=-1), 1.0, atol=1e-6)


@register("nn.functional.log_softmax", "nn")
def _case_fn_log_softmax():
    out = F.log_softmax(_rand((2, 3, 4)), axis=-1).to_numpy()
    assert out.shape == (2, 3, 4)


@register("nn.functional.linear", "nn")
def _case_fn_linear():
    x = _rand((4, 3))
    w = _rand((3, 2))
    b = _rand((2,))
    out = F.linear(x, w, b)
    assert out.shape == (4, 2)


@register("nn.functional.layer_norm", "nn")
def _case_fn_layer_norm():
    x = _rand((2, 3, 4))
    w = Tensor(np.ones((4,), dtype=np.float64))
    b = Tensor(np.zeros((4,), dtype=np.float64))
    out = F.layer_norm(x, 4, weight=w, bias=b)
    assert out.shape == (2, 3, 4)


@register("nn.functional.rms_norm", "nn")
def _case_fn_rms_norm():
    x = _rand((2, 3, 4))
    w = Tensor(np.ones((4,), dtype=np.float64))
    out = F.rms_norm(x, 4, weight=w, bias=None)
    assert out.shape == (2, 3, 4)


@register("nn.functional.dropout", "nn")
def _case_fn_dropout():
    x = _rand((3, 3))
    out = F.dropout(x, p=0.2, training=True)
    assert out.shape == x.shape


@register("nn.functional.mse_loss", "nn")
def _case_fn_mse_loss():
    x = _rand((2, 3))
    y = _rand((2, 3))
    out = F.mse_loss(x, y, reduction="mean")
    assert out.shape == ()


@register("nn.functional.nll_loss", "nn")
def _case_fn_nll_loss():
    x = _rand((2, 4))
    target = np.array([1, 3], dtype=np.int64)
    log_probs = F.log_softmax(x, axis=-1)
    out = F.nll_loss(log_probs, target, reduction="mean")
    assert out.shape == ()


@register("nn.functional.cross_entropy", "nn")
def _case_fn_cross_entropy():
    x = _rand((2, 4))
    target = np.array([1, 3], dtype=np.int64)
    out = F.cross_entropy(x, target)
    assert out.shape == ()


@register("optim.AdamW.step", "optim")
def _case_optim_adamw_step():
    m = nn.Linear(3, 2)
    x = _rand((4, 3), requires_grad=False)
    y = m(x).mean()
    opt = optim.AdamW(m.parameters(), lr=1e-3)
    opt.zero_grad()
    y.backward()
    old = m.weight.to_numpy().copy()
    opt.step()
    new = m.weight.to_numpy().copy()
    assert not np.allclose(old, new)


@register("optim.AdamW.state_dict", "optim")
def _case_optim_adamw_state_dict():
    m = nn.Linear(3, 2)
    opt = optim.AdamW(m.parameters(), lr=1e-3)
    state = opt.state_dict()
    opt.load_state_dict(state)
    assert "lr" in state and "m" in state and "v" in state


@register("optim.clip_grad_norm", "optim")
def _case_optim_clip_grad_norm():
    x = _rand((2, 2), requires_grad=True)
    y = (x * x).sum()
    y.backward()
    total = optim.clip_grad_norm([x], max_norm=0.1)
    assert total > 0.0


def _grouped_apis():
    out: "OrderedDict[str, list[str]]" = OrderedDict()
    for api_name, (group, _) in _API_CASES.items():
        out.setdefault(group, []).append(api_name)
    return out


def list_api_commands(make_target: str = "make api API={api}") -> None:
    grouped = _grouped_apis()
    print("API 功能点与单独测试命令")
    print("可直接复制执行以下命令:")
    for group, api_names in grouped.items():
        print(f"\n[{group}]")
        for api_name in api_names:
            print(f"{make_target.format(api=api_name)}")


def run_api_case(api_name: str) -> None:
    if api_name not in _API_CASES:
        available = ", ".join(_API_CASES.keys())
        raise KeyError(f"unknown api: {api_name}\navailable: {available}")
    _, fn = _API_CASES[api_name]
    fn()


def run_all_cases() -> None:
    for api_name in _API_CASES.keys():
        run_api_case(api_name)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run or list per-API tests for neurx project.")
    parser.add_argument("--list", action="store_true", help="List all API test commands.")
    parser.add_argument("--api", type=str, default="", help="Run a single API test by name.")
    parser.add_argument("--all", action="store_true", help="Run all API tests in this runner.")
    return parser


def main() -> int:
    # Keep API runner deterministic across invocations.
    os.environ["TENSOR_DEVICE"] = "cpu"
    np.random.seed(0)

    parser = _build_parser()
    args = parser.parse_args()
    if args.list:
        list_api_commands()
        return 0
    if args.api:
        run_api_case(args.api.strip())
        print(f"[PASS] {args.api.strip()}")
        return 0
    if args.all:
        run_all_cases()
        print(f"[PASS] all {_API_CASES.__len__()} api cases")
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

