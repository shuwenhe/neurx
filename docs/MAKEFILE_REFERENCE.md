# Makefile 测试命令快速参考

## 🚀 新功能测试 (2026-03-03)

```bash
# Einstein Summation
make test-einsum

# Vision Transforms (需要Pillow)
make test-vision

# ResNet Models
make test-resnet

# 所有新功能
make test-new-features
```

## 📋 现有功能测试

```bash
# 张量创建
make test-creation

# 优化器
make test-sgd
make test-optimizers      # Adam, RMSprop

# 调度器
make test-schedulers

# 神经网络层
make test-conv2d

# 所有测试
make test
```

## 🔧 CUDA测试

```bash
# 安装CUDA支持
make cuda-install

# 运行CUDA测试
make cuda-test
```

## 🛠️ 其他命令

```bash
# 查看帮助
make help

# 安装开发版本
make dev

# 运行诊断
make doctor

# 清理构建文件
make clean
```

## 💡 API级别测试

```bash
# 列出所有API
make list

# 测试特定API
make api API=tensor.einsum
make api API=tensor.vision.transforms.ToTensor

# 测试所有API
make api-all
```

## 📊 测试时间参考

| 命令 | 耗时 | 说明 |
|------|------|------|
| `make test-einsum` | ~2s | 5个einsum测试用例 |
| `make test-vision` | ~3s | 5个transform测试 |
| `make test-resnet` | ~5s | 3个模型实例化测试 |
| `make test-new-features` | ~10s | 完整新功能测试 |
| `make test` | ~30s | 所有测试 |

## 🐛 故障排查

```bash
# 如果测试失败，先运行诊断
make doctor

# 重新安装
make dev

# 直接运行测试文件查看详细错误
PYTHONPATH=python python tests/test_new_features.py
```

## 📦 依赖要求

- **核心测试**: numpy (必需)
- **Vision测试**: Pillow (可选)
- **CUDA测试**: CUDA toolkit (可选)

安装vision依赖：
```bash
pip install Pillow
```

---

**更新日期**: 2026-03-03  
**文档**: [完整测试指南](TESTING_GUIDE.md)
