# NeurX Tensor 与 PyTorch 差距分析与补齐优化（2026-03-04）

## 1) 当前结论（聚焦 Tensor 核心）

NeurX 已具备较好的基础能力（自动求导、广播、基础线代、创建函数、部分高级索引），但与 PyTorch 在“常用算子覆盖度 + 统一 API 入口 + 数值稳定性细节”上仍有差距。

本次优先补齐了高频、低风险、工程收益高的 Tensor API：

- `clamp` / `clip`
- `sign`
- `flip`
- `roll`
- `tile`（对齐 `torch.tile` 语义入口）

并统一暴露到：

- `neurx.core`
- `neurx`
- `neurx.neurx`

---

## 2) 本次已落地补齐项

### 2.1 Tensor 方法级

在 `python/neurx/core/neurx.py` 中新增：

- `Tensor.sign()`
- `Tensor.clamp(min=None, max=None)`
- `Tensor.clip(min=None, max=None)`
- `Tensor.flip(dims)`
- `Tensor.roll(shifts, dims=None)`
- `Tensor.tile(dims)`

### 2.2 函数式 API 级

在 `python/neurx/core/neurx.py` 中新增函数式入口：

- `clamp(input, min=None, max=None)`
- `clip(input, min=None, max=None)`
- `sign(input)`
- `flip(input, dims)`
- `roll(input, shifts, dims=None)`
- `tile(input, dims)`

### 2.3 包导出级

新增导出，保证用户可从顶层直接调用：

- `python/neurx/core/__init__.py`
- `python/neurx/__init__.py`
- `python/neurx/neurx.py`

---

## 3) 已验证方向

新增/更新测试覆盖：

- `tests/test_tensor_new_features.py`
  - `TestTensorParityOps.test_clamp_and_clip`
  - `TestTensorParityOps.test_sign`
  - `TestTensorParityOps.test_flip`
  - `TestTensorParityOps.test_roll`
  - `TestTensorParityOps.test_tile`

这些测试覆盖了数值正确性与 `clamp` 反向传播梯度掩码行为。

---

## 4) 下一批建议补齐（按优先级）

### P0（推荐马上做）

1. 布尔索引全语义对齐（`x[x > 0]`、多维布尔掩码）
2. `take_along_dim` / `gather` 维度与边界行为统一
3. `softmax` / `log_softmax` 在 Tensor 方法级统一入口（非仅 nn.functional）
4. `dtype` 体系细化（`float16/bfloat16` 路径与 fallback 策略）

### P1（工程质量与性能）

1. GPU 路径一致性：确保新增算子在 CUDA 下行为与梯度一致
2. 算子级基准：和 NumPy/PyTorch 做 micro-benchmark（shape 维度分桶）
3. 错误消息规范化（对齐 PyTorch 风格，提升迁移体验）

### P2（生态兼容）

1. 与 `torch` 常见迁移脚本做 API 兼容 smoke tests
2. 提供 `compat` 文档与自动重写建议（例如简单的 API alias 映射）

---

## 5) 优化原则（建议长期执行）

- 优先补齐“训练主链路高频算子”，避免先做长尾 API。
- 每个新算子必须配对：
  - 正向正确性测试
  - 梯度测试（若可导）
  - CPU/CUDA 一致性测试（若支持 CUDA）
- API 补齐同时更新文档和导出层，避免“实现了但不可用”。

---

## 6) 本次产出摘要

- 补齐 Tensor 与函数式高频缺口：`clamp/clip/sign/flip/roll/tile`
- 接入三层导出（core/顶层/兼容模块）
- 新增对应测试用例，支持持续回归

这批改动可直接提升 NeurX 在 PyTorch 代码迁移场景中的可用性与可预测性。