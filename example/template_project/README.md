# NeurX 框架模板项目

这是一个展示如何在真实项目中使用 **NeurX 深度学习框架** 的完整示例。

## 📋 项目结构

```
template_project/
├── src/
│   └── my_project/
│       ├── __init__.py           # 包初始化
│       ├── models/
│       │   └── __init__.py       # 模型定义
│       └── train.py              # 训练脚本
├── tests/
│   └── test_models.py            # 单元测试
├── requirements.txt              # 依赖列表
├── setup.py                      # 项目配置（setuptools）
├── pyproject.toml               # 项目配置（现代方式）
└── README.md                    # 本文件
```

## 🚀 快速开始

### 1. 创建虚拟环境

```bash
# 使用 Python venv
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate     # Windows
```

### 2. 安装依赖

#### 方式 A: 使用 requirements.txt（推荐快速开始）

```bash
pip install -r requirements.txt
```

#### 方式 B: 使用 setup.py

```bash
pip install -e .
```

#### 方式 C: 使用 pyproject.toml

```bash
pip install -e ".[dev]"  # 包括开发工具
```

### 3. 运行训练脚本

```bash
python -m my_project.train
```

或者：

```bash
python src/my_project/train.py
```

## 📦 依赖项说明

### 必需依赖

- **neurx** (>=0.2.0): NeurX 深度学习框架
- **numpy** (>=1.22.0): 数值计算库

### 可选依赖

安装可选依赖组：

```bash
# 开发工具（测试、格式化、linting）
pip install -e ".[dev]"

# 可视化工具
pip install -e ".[viz]"

# 数据处理工具
pip install -e ".[data]"

# 所有可选依赖
pip install -e ".[all]"
```

## 💻 代码示例

### 创建和训练模型

```python
import neurx
import neurx.nn as nn
import neurx.optim as optim
from my_project.models import SimpleClassifier

# 创建模型
model = SimpleClassifier(input_dim=784, hidden_dim=128, num_classes=10)

# 优化器和损失函数
optimizer = optim.Adam(model.parameters(), lr=0.001)
loss_fn = nn.CrossEntropyLoss()

# 创建数据
x = neurx.randn(32, 784)
y = neurx.randint(0, 10, (32,))

# 前向传播
logits = model(x)
loss = loss_fn(logits, y)

# 反向传播
optimizer.zero_grad()
loss.backward()
optimizer.step()

print(f"Loss: {loss.item()}")
```

### 使用新功能

#### dtype 转换

```python
import neurx

x = neurx.randn(8, 16)

# 转换为 float16
x_fp16 = x.float16()

# 转换为 double (float64)
x_fp64 = x.double()

# 转换为 int32
x_int = x.int32()
```

#### Scatter 操作

```python
import neurx

# 创建索引和值
indices = neurx.array([[0, 2], [1, 3]])
values = neurx.array([[10.0, 20.0], [30.0, 40.0]])

# Scatter 操作
result = neurx.scatter(values, indices, shape=(4, 2))
print(result)
```

#### 矩阵约简

```python
import neurx

x = neurx.randn(8, 16)

# 保持维度的约简操作
sum_result = x.sum(axis=0, keepdim=True)  # 形状: (1, 16)
mean_result = x.mean(axis=1, keepdim=True)  # 形状: (8, 1)
```

## 🧪 运行测试

### 运行所有测试

```bash
pytest tests/
```

### 运行特定测试

```bash
pytest tests/test_models.py -v
```

### 生成覆盖率报告

```bash
pytest tests/ --cov=my_project --cov-report=html
# 打开 htmlcov/index.html 查看结果
```

## 🔧 开发工具

### 代码格式化

```bash
# 使用 black 格式化代码
black src/ tests/

# 使用 ruff 检查代码质量
ruff check src/ tests/
```

### 类型检查

```bash
# 如果安装了 mypy
mypy src/
```

## 📚 模型定义说明

### SimpleClassifier

一个简单的 2 层全连接分类器：

- 输入层: `input_dim` 维
- 隐藏层: `hidden_dim` 维，ReLU 激活
- 可选 Dropout
- 输出层: `num_classes` 维（logits）

**使用示例**：

```python
model = SimpleClassifier(input_dim=784, hidden_dim=128, num_classes=10)
x = neurx.randn(32, 784)
logits = model(x)  # 输出形状: (32, 10)
```

### ConvNet

卷积神经网络示例（如果 NeurX 支持卷积层）：

- Conv2d 层
- ReLU 激活
- MaxPooling（隐式）
- 全连接分类层

### VisionTransformerBlock

Transformer 注意力块示例：

- Multi-Head 自注意力
- Feed-Forward 网络
- 层归一化（可选）
- 残差连接

## 🐛 常见问题

### 问题：找不到 neurx 模块

**解决方案**：

确保 neurx 已正确安装：

```bash
# 验证安装
python -c "import neurx; print(neurx.__version__)"

# 如果失败，重新安装
pip install -e /path/to/neurx
```

### 问题：数据形状不匹配

**解决方案**：

确保输入形状与模型定义匹配：

```python
model = SimpleClassifier(input_dim=784)  # 期望 784 维输入
x = neurx.randn(32, 784)  # 正确: (batch_size, 784)
# x = neurx.randn(32, 28, 28)  # 错误：形状不对
```

### 问题：CUDA 相关错误

**解决方案**：

- 确保已安装 CUDA（如果使用 GPU）
- 检查 CUDA_HOME 环境变量
- 或禁用 CUDA: `export TENSOR_CUDA=0`

```bash
# 检查 NeurX 的 CUDA 支持
python -c "import neurx; print('CUDA available:', neurx.cuda.is_available())"
```

## 📖 进一步学习

- [NeurX 官方文档](https://github.com/yourusername/neurx)
- [NeurX 快速安装指南](/QUICK_INSTALL.md)
- [NeurX 详细安装指南](/docs/INSTALLATION_AND_USAGE_GUIDE.md)
- [完整的 MNIST 示例](/example/mnist_classifier.py)

## 📝 项目配置文件说明

### requirements.txt

最简单的依赖管理方式，适合小项目和快速开发。

```
numpy>=1.22.0
-e /home/shuwen/neurx  # 本地路径安装
```

### setup.py

使用 setuptools 配置，提供更多功能（入口点、package 发现等）。

```python
setup(
    name='my-neurx-project',
    install_requires=['neurx>=0.2.0', 'numpy>=1.22.0'],
    # ... 其他配置
)
```

### pyproject.toml

现代 Python 项目的标准配置方式，推荐使用。

```toml
[build-system]
requires = ["setuptools>=61", "wheel"]

[project]
name = "my-neurx-project"
dependencies = ["neurx>=0.2.0", "numpy>=1.22.0"]
# ... 其他配置
```

## 🤝 贡献

欢迎提交问题和改进建议！

## 📄 许可证

MIT License

---

**快速命令参考**：

```bash
# 安装
pip install -r requirements.txt

# 运行训练
python -m my_project.train

# 运行测试
pytest tests/ -v

# 代码格式化
black src/ && ruff check src/
```
