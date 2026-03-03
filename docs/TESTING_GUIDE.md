# 测试命令使用指南

## 快速开始

```bash
# 查看所有可用命令
make help

# 运行所有测试
make test

# 运行新功能的完整测试套件
make test-new-features
```

## 新增测试命令

### 1. Einstein Summation 测试

```bash
make test-einsum
```

测试内容：
- ✅ 矩阵乘法 (`'ij,jk->ik'`)
- ✅ 批量矩阵乘法 (`'bij,bjk->bik'`)
- ✅ 矩阵转置 (`'ij->ji'`)
- ✅ 矩阵的迹 (`'ii'`)
- ✅ 批量点积 (`'bi,bi->b'`)

**示例输出：**
```
Testing Einstein summation (einsum)...
============================================================
Testing einsum operations
============================================================

1. Matrix multiplication: 'ij,jk->ik'
   Shape: (3, 4) @ (4, 5) = (3, 5)
   Max diff vs matmul: 1.490116e-07
   ✅ PASS

...

✅ All einsum tests passed!
```

---

### 2. Vision Transforms 测试

```bash
make test-vision
```

测试内容：
- ✅ `ToTensor` - PIL Image转换为Tensor
- ✅ `Resize` - 图像缩放
- ✅ `Normalize` - 标准化
- ✅ `Compose` - 多变换组合
- ✅ `RandomHorizontalFlip` - 随机水平翻转

**前置条件：** 需要安装 Pillow
```bash
pip install Pillow
```

**示例输出：**
```
Testing vision transforms...
============================================================
Testing vision transforms
============================================================

1. ToTensor transform
   Input shape: (256, 256, 3)
   Output shape: (3, 256, 256)
   Output range: [0.00, 1.00]
   ✅ PASS

...

✅ All vision transform tests passed!
```

---

### 3. ResNet Models 测试

```bash
make test-resnet
```

测试内容：
- ✅ ResNet-18 实例化
- ✅ ResNet-34 实例化
- ✅ ResNet-50 实例化
- ✅ 前向传播验证

**示例输出：**
```
Testing ResNet models...
============================================================
Testing ResNet models
============================================================

1. ResNet-18 instantiation
   Model created successfully
   Number of parameters: 62
   Testing forward pass with input shape: (2, 3, 224, 224)
   Output shape: (2, 10)
   ✅ PASS

...

✅ All ResNet model tests passed!
```

---

### 4. 所有新功能测试

```bash
make test-new-features
```

运行完整的测试套件，包括：
- Einstein summation
- Vision transforms
- ResNet models

**示例输出：**
```
Running comprehensive tests for all new features...
============================================================
Tensor Framework - New Features Test Suite
============================================================

[测试详情...]

============================================================
Test Summary
============================================================
einsum              : ✅ PASS
vision_transforms   : ✅ PASS
resnet_models       : ✅ PASS

============================================================
🎉 All tests passed!
============================================================
```

---

## 其他测试命令

### 现有的测试命令

```bash
# 张量创建函数测试
make test-creation

# SGD优化器测试
make test-sgd

# 学习率调度器测试
make test-schedulers

# Adam和RMSprop优化器测试
make test-optimizers

# Conv2d层测试
make test-conv2d

# CUDA相关测试（需要CUDA支持）
make cuda-test
```

---

## 单独运行测试文件

如果你想直接运行测试文件：

```bash
cd /home/shuwen/neurx
PYTHONPATH=python python tests/test_new_features.py
```

---

## API级别测试

```bash
# 列出所有可测试的API
make list

# 测试特定API
make api API=tensor.einsum
make api API=tensor.vision.transforms.ToTensor
make api API=tensor.vision.models.resnet18

# 运行所有API测试
make api-all
```

---

## 故障排查

### 问题：ImportError: No module named 'PIL'

**解决方案：**
```bash
pip install Pillow
```

### 问题：测试失败

1. **检查安装：**
   ```bash
   cd /home/shuwen/neurx
   make dev
   ```

2. **运行诊断：**
   ```bash
   make doctor
   ```

3. **查看详细错误：**
   ```bash
   PYTHONPATH=python python tests/test_new_features.py
   ```

---

## 持续集成

在CI/CD流水线中使用：

```yaml
# .github/workflows/test.yml
- name: Test new features
  run: |
    make test-einsum
    make test-vision
    make test-resnet
    make test-new-features
```

或简化为：
```yaml
- name: Test all
  run: make test
```

---

## 性能基准测试

对于性能敏感的操作（如einsum），可以添加benchmark：

```bash
# 未来可能添加
make benchmark-einsum
make benchmark-resnet
```

---

## 快速参考

| 命令 | 功能 | 耗时 |
|------|------|------|
| `make test-einsum` | 测试Einstein summation | ~2s |
| `make test-vision` | 测试图像变换 | ~3s |
| `make test-resnet` | 测试ResNet模型 | ~5s |
| `make test-new-features` | 完整新功能测试 | ~10s |
| `make test` | 所有测试 | ~30s |

---

**最后更新：** 2026-03-03  
**测试框架：** Python unittest / pytest兼容
