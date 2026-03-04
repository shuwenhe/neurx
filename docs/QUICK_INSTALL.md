# 🚀 NeurX 快速安装参考

## ⚡ 5秒快速安装

```bash
# 方式 1: 本地开发安装（推荐）
pip install -e /path/to/neurx

# 方式 2: 从 wheels 安装（最快）
pip install dist/neurx-0.2.0-py3-none-any.whl

# 方式 3: 从 PyPI 安装（如果已发布）
pip install neurx
```

---

## 🛠️ 在你的项目中使用

### 方法A: 添加到 requirements.txt

```txt
# requirements.txt
-e /path/to/neurx  # 或 pip install git+https://github.com/...
numpy>=1.22.0
```

```bash
pip install -r requirements.txt
```

### 方法B: setup.py 依赖

```python
setup(
    name='your-project',
    install_requires=[
        'neurx>=0.2.0',
    ],
)
```

### 方法C: pyproject.toml (最现代)

```toml
[project]
dependencies = [
    "neurx>=0.2.0",
]
```

---

## 📝 使用示例

```python
import neurx as nx
import neurx.nn as nn

# 张量操作
x = nx.randn(32, 784)
y = nx.ones(32, 10)

# 神经网络
model = nn.Sequential([
    nn.Linear(784, 128),
    nn.ReLU(),
    nn.Linear(128, 10),
])

# 前向传播
output = model(x)
loss = nn.CrossEntropyLoss()(output, y)

# 反向传播
loss.backward()

# 优化
optimizer = nx.optim.Adam(model.parameters(), lr=0.001)
optimizer.step()
```

---

## ✅ 验证安装

```bash
# 测试导入
python -c "import neurx; print(f'neurx {neurx.__version__}')"

# 查看包信息
pip show neurx

# 运行测试
python -m pytest tests/ -q
```

---

## 📦 包信息

- **名称**: neurx
- **版本**: 0.2.0  
- **Python**: ≥3.10
- **依赖**: numpy
- **可选**: CUDA 支持（自动检测）

---

## 🎯 常见场景

| 场景 | 命令 |
|-----|------|
| **开发框架** | `pip install -e .` |
| **其他项目使用** | `pip install -e /path/to/neurx` |
| **打包分发** | `python -m build && twine upload dist/*` |
| **卸载** | `pip uninstall neurx` |
| **更新** | `pip install --upgrade neurx` |

---

## 🐛 故障排除

| 问题 | 解决方案 |
|-----|--------|
| ModuleNotFoundError | 运行 `pip install -e /path/to/neurx` |
| CUDA 编译失败 | 运行 `TENSOR_CUDA=0 pip install -e .` |
| 版本冲突 | 运行 `pip list \| grep neurx` |

---

📖 **详细指南**: 看 [INSTALLATION_AND_USAGE_GUIDE.md](INSTALLATION_AND_USAGE_GUIDE.md)
