# NeurX 深度学习框架 - 安装与使用指南

## 📦 包信息

- **包名**: neurx
- **当前版本**: 0.2.0
- **Python 版本**: ✅ 3.10+
- **主要依赖**: numpy

---

## 🚀 安装方式

### 方式 1: 本地开发安装（推荐用于框架开发）

如果你想从源代码安装并在修改后实时生效：

```bash
# 进入 neurx 项目根目录
cd /path/to/neurx

# 可编辑模式安装（修改后无需重新安装）
pip install -e .

# 如果需要开发工具和测试依赖
pip install -e ".[dev]"
```

**优点**：
- ✅ 修改源代码后立即生效（无需重新安装）
- ✅ 适合贡献和修改框架代码
- ✅ 完整的开发环境

---

### 方式 2: 从本地路径安装（项目间依赖）

如果你有其他项目需要使用 neurx，假设项目结构如下：

```
my-projects/
├── neurx/              # neurx 框架目录
│   ├── python/
│   ├── setup.py
│   └── setup.cfg
│
└── my-deep-learning-project/
    ├── main.py
    └── requirements.txt
```

在 `my-deep-learning-project` 的 `requirements.txt` 中添加：

```
# requirements.txt
numpy
# 从本地路径安装 neurx
-e ../neurx
```

然后安装：

```bash
cd my-deep-learning-project
pip install -r requirements.txt
```

或直接命令行安装：

```bash
pip install -e /path/to/neurx
```

---

### 方式 3: 打包为 wheel 分发

如果你想打包发布 neurx 供他人使用：

#### 3.1 创建 wheel 包

```bash
cd /path/to/neurx

# 安装打包工具
pip install build

# 创建 wheel 文件
python -m build

# 会在 dist/ 目录下生成：
# - neurx-0.2.0-py3-none-any.whl     （纯 Python 部分）
# - neurx-0.2.0.tar.gz               （源代码包）
```

#### 3.2 分发 wheel 包

生成的 wheel 文件可以：

**选项 A: 直接共享文件**
```bash
# 将 wheel 文件复制给其他用户
cp dist/neurx-0.2.0-py3-none-any.whl /path/to/share/

# 其他用户可直接安装
pip install /path/to/neurx-0.2.0-py3-none-any.whl
```

**选项 B: 上传到 PyPI 公网**
```bash
# 安装 twine
pip install twine

# 上传到 PyPI 官方
# 首先需要在 https://pypi.org 注册账号
twine upload dist/*

# 之后其他用户可直接安装
pip install neurx
```

**选项 C: 上传到私有 PyPI 服务器**
```bash
# 配置 ~/.pypirc
[distutils]
index-servers =
    private
    
[private]
repository: https://your-private-pypi.com
username: your_username
password: your_password

# 上传
twine upload -r private dist/*

# 用户安装
pip install -i https://your-private-pypi.com neurx
```

---

### 方式 4: Git 仓库安装（如果已 push 到 GitHub）

假设 neurx 已上传到 GitHub：

```bash
# 直接从 Git 安装
pip install git+https://github.com/yourusername/neurx.git

# 安装特定分支
pip install git+https://github.com/yourusername/neurx.git@develop

# 在 requirements.txt 中
git+https://github.com/yourusername/neurx.git@main#egg=neurx
```

---

## 💻 使用示例

安装后，在任何 Python 项目中都可以直接导入和使用 neurx：

### 基础使用

```python
import neurx
import numpy as np

# 创建张量
x = neurx.randn(3, 4, 5)
y = neurx.ones((3, 4, 5))

# 张量操作
z = x + y
result = (z * 2).sum()

# 自动微分
x = neurx.randn(3, 4, requires_grad=True)
y = (x ** 2).sum()
y.backward()
print(x.grad)  # 梯度

# 数据类型转换（新功能）
x_fp16 = x.float16()    # 半精度
x_fp64 = x.float64()    # 双精度
```

### 神经网络模型

```python
import neurx
import neurx.nn as nn

class MyModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 128)
        self.fc2 = nn.Linear(128, 10)
        self.relu = nn.ReLU()
    
    def forward(self, x):
        x = x.reshape(x.shape[0], -1)
        x = self.relu(self.fc1(x))
        x = self.fc2(x)
        return x

# 使用模型
model = MyModel()
x = neurx.randn(32, 1, 28, 28)
output = model(x)

# 损失和优化
loss_fn = nn.CrossEntropyLoss()
optimizer = neurx.optim.Adam(model.parameters(), lr=0.001)

for epoch in range(10):
    output = model(x)
    loss = loss_fn(output, target)
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    print(f"Epoch {epoch}, Loss: {loss.item()}")
```

### 高级特性（优化后）

```python
import neurx as nx

# Scatter/Gather 操作（已完整验证）
t = nx.ones((3, 5))
idx = nx.Tensor([[0, 2], [1, 3], [2, 4]])
src = nx.ones((3, 2)) * 5

# 散射操作 - 带完整边界检查
out = t.scatter(1, idx, src)

# 聚集操作
gathered = out.gather(1, idx)

# 混合精度训练
x = nx.randn(32, 3, 224, 224)
x_fp16 = x.float16()        # 转换为float16节省显存
output = model(x_fp16)
loss = criterion(output.float32(), target)  # 损失用float32计算
```

---

## 🔧 不同项目的依赖指定

### 方式 A: requirements.txt

```txt
# requirements.txt

# 从本地路径
-e /home/user/neurx

# 其他依赖
torch==2.0.0
tensorboard==2.10.0
```

使用：
```bash
pip install -r requirements.txt
```

### 方式 B: setup.py/setup.cfg

在你的项目 `setup.py` 中：

```python
from setuptools import setup

setup(
    name='my-project',
    version='1.0.0',
    install_requires=[
        'neurx>=0.2.0',
        'torch>=2.0.0',
    ],
    # 或者从本地安装
    # install_requires=[
    #     'neurx @ file:///path/to/neurx',
    # ],
)
```

### 方式 C: pyproject.toml (推荐)

```toml
[build-system]
requires = ["setuptools>=61", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "my-project"
version = "1.0.0"
requires-python = ">=3.10"
dependencies = [
    "neurx>=0.2.0",
    "torch>=2.0.0",
    "numpy>=1.22.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "black>=22.0",
]
```

### 方式 D: Poetry (如果使用 Poetry)

```toml
# pyproject.toml (Poetry)

[tool.poetry.dependencies]
python = "^3.10"
neurx = "^0.2.0"

# 或从本地路径
# neurx = { path = "../neurx", develop = true }
```

使用：
```bash
poetry install
```

---

## 🐛 常见问题

### Q1: 导入时出现找不到模块

```python
>>> import neurx
ModuleNotFoundError: No module named 'neurx'
```

**解决方案**：
```bash
# 确保已正确安装
pip install -e /path/to/neurx

# 或检查 Python 路径
python -c "import sys; print(sys.path)"

# 重新安装
pip uninstall neurx
pip install -e /path/to/neurx
```

### Q2: CUDA 编译失败

```
ERROR: CUDA not found. Set CUDA_HOME or CUDA_PATH.
```

**解决方案**（2选1）：

方式 1: 设置 CUDA 环境变量
```bash
export CUDA_HOME=/usr/local/cuda
pip install -e .
```

方式 2: 跳过 CUDA 编译（仅 CPU）
```bash
TENSOR_CUDA=0 pip install -e .
```

### Q3: 检查安装版本

```bash
# 检查安装的 neurx 版本
python -c "import neurx; print(neurx.__version__)"

# 或查看包信息
pip show neurx
```

### Q4: 从项目卸载

```bash
pip uninstall neurx
```

---

## 📊 安装方式对比

| 方式 | 安装时间 | 更新速度 | 分发方便性 | 推荐场景 |
|------|--------|--------|---------|--------|
| 本地可编辑安装 | 快 | 即时 | 否 | **框架开发** |
| 本地路径安装 | 快 | 依赖手动 | 是 | **多项目依赖** |
| Wheel 包 | 中等 | 重新安装 | 是 | **发布分发** |
| PyPI 官方 | 中等 | 自动 | 是 | **公开发布** |
| Git 仓库 | 慢 | 快 | 是 | **开源协作** |

---

## ✨ 最佳实践

### 1. 开发阶段

```bash
cd /path/to/neurx
pip install -e ".[dev]"
python -m pytest tests/     # 运行测试验证
```

### 2. 项目使用

```bash
# requirements.txt
-e /path/to/neurx
torch>=2.0.0
```

### 3. 公开发布

```bash
cd /path/to/neurx
python -m build                     # 创建包
twine upload dist/*                 # 上传 PyPI
# 之后用户可 pip install neurx
```

### 4. 团队协作

```bash
# 上传到私有 PyPI 或使用 Git
git clone https://github.com/your-org/neurx.git
cd your-project
pip install -e ../neurx
```

---

## 🚀 快速开始模板

为了方便，这是一个完整的新项目模板：

```
my-ai-project/
├── neurx/                    # neurx 框架（子模块或复制）
├── my_module/
│   ├── __init__.py
│   ├── model.py              # 模型定义
│   └── train.py              # 训练脚本
├── data/
│   └── dataset.py
├── tests/
│   └── test_model.py
├── requirements.txt
├── setup.py
└── README.md

# requirements.txt
-e ../neurx
numpy>=1.22.0
matplotlib>=3.5.0

# train.py
import neurx
import neurx.nn as nn
from my_module.model import MyModel

model = MyModel()
optimizer = neurx.optim.Adam(model.parameters())
# ... training loop
```

---

## 📞 获取帮助

- 📚 文档: `/docs/` 目录
- 🧪 示例: `tests/` 目录中的测试代码
- 💬 问题: 查看 `README.md` 和现有 issues

---

**现在你可以在任何项目中安装和使用 neurx 框架了！** 🎉
