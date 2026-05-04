# NeurX 框架完整部署指南

## 📌 概览

本文档提供 neurx 深度学习框架在不同环境和项目中的完整部署方案。无论你是个人开发者、学术研究者还是企业团队，都能找到合适的安装和使用方法。

## 🎯 快速决策树

```
你想...?
│
├─ 快速体验框架 ────→ [方案 1: 本地可编辑安装]
├─ 在现有项目中使用 ──→ [方案 2: 项目依赖安装]
├─ 打包分发给团队 ────→ [方案 3: Wheel 包分发]
├─ 开源发布 ──────────→ [方案 4: PyPI 发布]
└─ 团队协作开发 ──────→ [方案 5: Git 协作]
```

---

## 方案 1: 本地可编辑安装（开发环境推荐）

### 适用场景
- ✅ 本机快速开发
- ✅ 实时测试框架修改
- ✅ 学习和实验

### 安装步骤

```bash
# 1. 进入 neurx 项目目录
cd /home/shuwen/neurx

# 2. 安装为可编辑本地包
pip install -e .

# 3. 验证安装
python -c "import neurx; print(f'neurx {neurx.__version__}')"

# 4. 运行测试
pytest tests/ -q
```

### 优点
- 🟢 修改后无需重新安装立即生效
- 🟢 完整的包控制和调试
- 🟢 快速迭代开发

### 缺点
- 🔴 仅限本地使用
- 🔴 不适合分发

### 卸载

```bash
pip uninstall neurx
```

---

## 方案 2: 项目依赖安装（最常用）

### 适用场景
- ✅ 在多个项目中使用 neurx
- ✅ 团队项目合作
- ✅ 生产环境部署
- ✅ 明确的版本控制

### 安装方法

#### 方法 A: requirements.txt（推荐）

```bash
# 1. 创建新项目
mkdir my-ai-project
cd my-ai-project

# 2. 创建 requirements.txt
cat > requirements.txt << 'EOF'
numpy>=1.22.0
-e /home/shuwen/neurx
EOF

# 3. 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# 4. 安装依赖
pip install -r requirements.txt

# 5. 验证
python -c "import neurx; print('Success!')"
```

#### 方法 B: setup.py

```python
# setup.py
from setuptools import setup

setup(
    name='my-ai-project',
    version='1.0.0',
    install_requires=[
        'neurx>=0.2.0',
        'numpy>=1.22.0',
    ],
    # ... 其他配置
)

# 安装
pip install -e .
```

#### 方法 C: pyproject.toml（现代推荐）

```toml
[project]
dependencies = [
    "neurx>=0.2.0",
    "numpy>=1.22.0",
]

[project.optional-dependencies]
dev = ["pytest>=7.0", "black>=22.0"]
```

```bash
pip install -e ".[dev]"
```

#### 方法 D: 直接命令行

```bash
pip install -e /home/shuwen/neurx numpy>=1.22.0
```

### 项目结构示例

```
my-ai-project/
├── src/
│   └── my_project/
│       ├── __init__.py
│       ├── models.py
│       └── train.py
├── tests/
│   └── test_models.py
├── requirements.txt
├── setup.py
├── pyproject.toml
└── README.md
```

### 代码示例

```python
# src/my_project/train.py
import neurx
import neurx.nn as nn
import neurx.optim as optim

# 定义模型
model = nn.Sequential([
    nn.Linear(784, 128),
    nn.ReLU(),
    nn.Linear(128, 10),
])

# 优化器
optimizer = optim.Adam(model.parameters())

# 损失函数
loss_fn = nn.CrossEntropyLoss()

# 训练循环...
```

---

## 方案 3: Wheel 包分发（企业环境）

### 适用场景
- ✅ 企业内部分发
- ✅ 离线安装
- ✅ 版本锁定
- ✅ 无需编译环境

### 生成 Wheel 包

```bash
# 1. 进入 neurx 项目
cd /home/shuwen/neurx

# 2. 安装 build 工具
pip install build

# 3. 构建 wheel 包
python -m build

# 输出文件位置
# dist/neurx-0.2.0-py3-none-any.whl
```

### 分发和安装

```bash
# 从 Wheel 包安装
pip install ./neurx-0.2.0-py3-none-any.whl

# 指定本地 wheel 文件路径
pip install -r requirements.txt --find-links=./wheels
```

### 企业 requirements.txt 示例

```
# requirements.txt
numpy>=1.22.0
./wheels/neurx-0.2.0-py3-none-any.whl
```

### 优点
- 🟢 预编译，安装快
- 🟢 版本一致性好
- 🟢 适合离线环境

### 缺点
- 🔴 需要提前构建
- 🔴 针对不同平台可能不同

---

## 方案 4: PyPI 发布（开源）

### 场景：官方发布到 Python Package Index

### 前置准备

```bash
# 1. 注册 PyPI 账号
# https://pypi.org/account/register/

# 2. 创建 ~/.pypirc 配置
cat > ~/.pypirc << 'EOF'
[distutils]
index-servers =
    pypi
    testpypi

[pypi]
repository = https://upload.pypi.org/legacy/
username = __token__
password = pypi-xxx

[testpypi]
repository = https://test.pypi.org/legacy/
username = __token__
password = pypi-xxx
EOF
```

### 发布流程

```bash
# 1. 更新版本号 (setup.cfg)
# version = 0.2.1

# 2. 构建包
python -m build

# 3. 安装 twine（上传工具）
pip install twine

# 4. 测试发布（可选）
twine upload -r testpypi dist/*

# 5. 正式发布
twine upload dist/*
```

### 发布后使用

```bash
# 全球任何地方都可以安装
pip install neurx

# 或指定版本
pip install neurx==0.2.1

# 指定版本范围
pip install "neurx>=0.2.0,<1.0"
```

### PyPI 页面示例

```
https://pypi.org/project/neurx/
- 项目描述
- 安装说明
- 文档链接
- GitHub 链接
```

---

## 方案 5: Git 仓库协作（团队开发）

### 适用场景
- ✅ 开源协作
- ✅ 多人开发
- ✅ 版本控制
- ✅ CI/CD 集成

### 设置 GitHub 仓库

```bash
# 1. 初始化 git 仓库（如未初始化）
cd /home/shuwen/neurx
git init

# 2. 提交现有代码
git add .
git commit -m "Initial commit: NeurX framework v0.2.0"

# 3. 添加远程仓库
git remote add origin https://github.com/yourusername/neurx.git

# 4. 推送到 GitHub
git branch -M main
git push -u origin main
```

### 通过 Git 安装

```bash
# 方式 1: 从 GitHub main 分支安装
pip install git+https://github.com/yourusername/neurx.git

# 方式 2: 指定特定版本/标签
pip install git+https://github.com/yourusername/neurx.git@v0.2.0

# 方式 3: 在 requirements.txt 中
git+https://github.com/yourusername/neurx.git@main
```

### GitHub Actions CI/CD（可选）

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.10', '3.11', '3.12']
    
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: ${{ matrix.python-version }}
      - run: pip install -e ".[dev]"
      - run: pytest tests/
```

---

## 📊 方案对比

| 方案 | 安装速度 | 灵活性 | 团队协作 | 生产应用 |
|------|--------|------|---------|---------|
| 1. 本地可编辑 | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ | ❌ | ❌ |
| 2. 项目依赖 | ⚡⚡ | ⭐⭐⭐⭐ | ✅ | ✅✅ |
| 3. Wheel 包 | ⚡⚡ | ⭐⭐⭐ | ⭐⭐⭐ | ✅✅✅ |
| 4. PyPI 发布 | ⚡ | ⭐⭐ | ✅✅ | ✅✅✅ |
| 5. Git 协作 | ⚡⚡⚡ | ⭐⭐⭐⭐ | ✅✅✅ | ✅ |

---

## 🔧 常见部署场景

### 场景 A: 单机快速原型

```bash
# 1. 快速安装
pip install -e /home/shuwen/neurx

# 2. 编写代码
python train.py

# 3. 测试
pytest tests/
```

### 场景 B: 多项目共享依赖

```bash
# 项目 A
pip install -e /home/shuwen/neurx

# 项目 B
pip install -e /home/shuwen/neurx

# 共享同一份 neurx 代码，减少磁盘占用
```

### 场景 C: 团队项目部署

```bash
# 服务器环境初始化
git clone https://github.com/your-team/neurx.git
cd neurx
python -m build
pip install dist/*.whl

# 或使用 Docker
docker build -t neurx:latest .
docker run -it neurx:latest python
```

### 场景 D: 容器化部署

```dockerfile
# Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 安装 neurx
RUN pip install -e git+https://github.com/yourusername/neurx.git#egg=neurx

# 复制应用
COPY . .
RUN pip install -e ".[dev]"

# 运行
CMD ["python", "train.py"]
```

---

## ✅ 安装验证清单

安装 neurx 后，使用以下命令验证：

```bash
# 1. 检查版本
python -c "import neurx; print(neurx.__version__)"

# 2. 检查核心模块
python -c "import neurx.nn; import neurx.optim; print('OK')"

# 3. 简单功能测试
python -c "
import neurx as nx
x = nx.randn(10, 5)
print(f'Tensor shape: {x.shape}, dtype: {x.dtype}')
"

# 4. CUDA 支持检查（可选）
python -c "
import neurx
if hasattr(neurx, 'cuda'):
    print(f'CUDA available: {neurx.cuda.is_available()}')
"

# 5. 运行完整测试
pytest tests/ -q --tb=short
```

---

## 🐛 故障排除

### 问题 1: ModuleNotFoundError: No module named 'neurx'

**原因**: neurx 未正确安装

**解决方案**:

```bash
# 重新安装
pip install -e /home/shuwen/neurx

# 验证
python -c "import neurx; print('OK')"
```

### 问题 2: Version conflict

**原因**: 多个版本冲突

**解决方案**:

```bash
# 查看已安装版本
pip list | grep neurx

# 卸载所有版本
pip uninstall neurx -y

# 重新安装指定版本
pip install -e /home/shuwen/neurx@0.2.0
```

### 问题 3: CUDA 相关错误

**原因**: CUDA 环境配置问题

**解决方案**:

```bash
# 禁用 CUDA（使用 CPU）
export TENSOR_CUDA=0
python train.py

# 或检查 CUDA
nvcc --version
echo $CUDA_HOME
```

### 问题 4: 虚拟环境问题

**原因**: Python 解释器不匹配

**解决方案**:

```bash
# 确认激活了虚拟环境
which python  # 应该显示 venv/ 路径

# 重新创建虚拟环境
rm -rf venv
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## 📚 进一步阅读

- [NeurX 快速安装指南](/QUICK_INSTALL.md)
- [NeurX 详细使用指南](/docs/INSTALLATION_AND_USAGE_GUIDE.md)
- [模板项目](/examples/template_project/)
- [MNIST 示例](/examples/mnist_classifier.py)
- [项目分析文档](/docs/PROJECT_SETUP_EXAMPLES.md)

---

## 📞 获取帮助

遇到问题？

1. 查看 [常见问题部分](#常见问题)
2. 检查 [故障排除](#故障排除) 章节
3. 查阅 [完整 API 文档](https://github.com/yourusername/neurx/wiki)
4. 提交 [GitHub Issues](https://github.com/yourusername/neurx/issues)

---

**最后更新**: 2025-03-04  
**维护者**: NeurX Team  
**许可证**: MIT
