# 示例项目配置文件

## 项目信息
name = MyAIProject
version = 1.0.0
description = 使用 NeurX 框架的深度学习项目

## 依赖项 - 方式 1: requirements.txt

# 主要依赖
numpy>=1.22.0

# 安装 neurx 框架 - 选择下列一种方式
# 方式1: 从本地路径安装（开发中推荐）
# -e /path/to/neurx

# 方式2: 从 Wheel 文件安装  
# /path/to/neurx-0.2.0-py3-none-any.whl

# 方式3: 从 GitHub 安装（如果已上传）
# git+https://github.com/yourusername/neurx.git@main

# 方式4: 从 PyPI 安装（如果已发布）
# neurx>=0.2.0

# 可选依赖
# torch>=2.0.0           # 如果需要与 PyTorch 互操作
# tensorboard>=2.10.0    # 日志和可视化

## 依赖项 - 方式 2: setup.py

from setuptools import setup, find_packages

setup(
    name='my-ai-project',
    version='1.0.0',
    description='使用 NeurX 框架的深度学习项目',
    author='Your Name',
    author_email='your.email@example.com',
    
    packages=find_packages(),
    python_requires='>=3.10',
    
    install_requires=[
        'neurx>=0.2.0',
        'numpy>=1.22.0',
    ],
    
    extras_require={
        'dev': [
            'pytest>=7.0',
            'black>=22.0',
            'ruff>=0.0.200',
        ],
        'viz': [
            'tensorboard>=2.10.0',
            'matplotlib>=3.5.0',
        ],
    },
    
    entry_points={
        'console_scripts': [
            'train-model=my_project.train:main',
        ],
    },
)

## 依赖项 - 方式 3: pyproject.toml（推荐，现代方式）

[build-system]
requires = ["setuptools>=61", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "my-ai-project"
version = "1.0.0"
description = "使用 NeurX 框架的深度学习项目"
requires-python = ">=3.10"
dependencies = [
    "neurx>=0.2.0",
    "numpy>=1.22.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "black>=22.0",
]
viz = [
    "tensorboard>=2.10.0",
    "matplotlib>=3.5.0",
]

[project.urls]
Homepage = "https://github.com/yourusername/my-ai-project"
Repository = "https://github.com/yourusername/my-ai-project.git"
Issues = "https://github.com/yourusername/my-ai-project/issues"

[tool.pytest.ini_options]
pythonpath = ["src"]
testpaths = ["tests"]

[tool.black]
line-length = 88

[tool.ruff]
line-length = 88

---

## 项目结构建议

my-ai-project/
├── src/
│   └── my_project/
│       ├── __init__.py
│       ├── models/
│       │   ├── __init__.py
│       │   ├── classifier.py       # 分类模型
│       │   └── encoder.py          # 编码器模型
│       ├── data/
│       │   ├── __init__.py
│       │   ├── loader.py           # 数据加载
│       │   └── transforms.py       # 数据预处理
│       ├── train.py                # 训练脚本
│       └── utils.py                # 工具函数
├── tests/
│   ├── __init__.py
│   ├── test_models.py
│   └── test_data.py
├── examples/
│   └── train_example.py            # 使用示例
├── docs/
│   └── README.md
├── requirements.txt                # 方式 1
├── setup.py                        # 方式 2
├── pyproject.toml                  # 方式 3（推荐）
├── setup.cfg                       # 可选元数据
├── README.md
└── LICENSE

---

## 使用 neurx 的代码示例

# src/my_project/models/classifier.py

import neurx
import neurx.nn as nn

class MyClassifier(nn.Module):
    def __init__(self, input_dim, num_classes):
        super().__init__()
        self.fc1 = nn.Linear(input_dim, 128)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(128, num_classes)
    
    def forward(self, x):
        x = self.relu(self.fc1(x))
        return self.fc2(x)

# src/my_project/train.py

import neurx as nx
import neurx.nn as nn
import neurx.optim as optim
from my_project.models import MyClassifier
from my_project.data import load_dataset

def main():
    # 加载数据
    train_loader, val_loader = load_dataset()
    
    # 创建模型
    model = MyClassifier(input_dim=784, num_classes=10)
    
    # 优化器和损失函数
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    loss_fn = nn.CrossEntropyLoss()
    
    # 训练循环
    for epoch in range(10):
        total_loss = 0
        for x, y in train_loader:
            # 前向传播
            logits = model(x)
            loss = loss_fn(logits, y)
            
            # 反向传播
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
        
        print(f"Epoch {epoch}, Loss: {total_loss}")

if __name__ == '__main__':
    main()

---

## 项目创建步骤

1. 创建项目目录结构
   mkdir -p my-ai-project/src/my_project
   mkdir -p my-ai-project/tests

2. 选择依赖管理方式
   # 简单项目: 用 requirements.txt
   # 复杂项目: 用 setup.py 或 pyproject.toml

3. 创建虚拟环境
   python -m venv venv
   source venv/bin/activate  # Linux/Mac
   # 或
   venv\\Scripts\\activate   # Windows

4. 安装依赖
   pip install -r requirements.txt
   # 或
   pip install -e .
   # 或
   pip install -e ".[dev]"  # 包括开发工具

5. 开始开发
   python -m pytest         # 运行测试
   python examples/train_example.py  # 运行示例

---

## 将 neurx 添加到现有项目

# 步骤 1: 添加 neurx 到 requirements.txt
echo "-e /path/to/neurx" >> requirements.txt

# 步骤 2: 重新安装依赖
pip install -r requirements.txt

# 步骤 3: 在代码中导入使用
import neurx
model = neurx.nn.Linear(10, 5)

---

## 快速参考：安装命令

# 从本地路径
pip install -e /home/shuwen/neurx

# 生产环境（打包后）
pip install ./neurx-0.2.0-py3-none-any.whl

# 从 Git（如果上传到 GitHub）
pip install git+https://github.com/your-org/neurx.git

# 验证安装
python -c "import neurx; print(f'neurx {neurx.__version__}')"
