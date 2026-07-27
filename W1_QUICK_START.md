# 🚀 W1 快速开始指南

**当前状态**: Framework 50%, Implementation 40%, Validation 0%  
**目标状态**: Framework 100%, Implementation 100%, Validation 100%  
**优先级**: 🔴 CRITICAL - 阻塞 W2-W11  
**时间**: 1-2 天 (13.5h)

---

## ⚠️ 立即处理的阻塞问题

### 问题: 编译器架构不匹配

```
错误: /home/shuwen/.local/bin/s
  当前: ELF 64-bit LSB ARM aarch64
  系统: x86_64
  结果: Exec format error
```

**解决方案** (选一个):

#### 选项 A: 重新下载 x86_64 编译器 ⭐ 推荐
```bash
# 1. 检查系统架构
uname -m  # 应该输出 x86_64

# 2. 卸载当前编译器
rm /home/shuwen/.local/bin/s

# 3. 下载 x86_64 版本
cd /tmp
# 从官方源下载 (需要替换实际URL)
wget https://[s-lang-repo]/s-compiler-x86_64.tar.gz
tar xzf s-compiler-x86_64.tar.gz
mv s /home/shuwen/.local/bin/s
chmod +x /home/shuwen/.local/bin/s

# 4. 验证
file /home/shuwen/.local/bin/s  # 应该显示 x86_64
s --version  # 测试编译器
```

#### 选项 B: 使用容器
```bash
# 如果无法获得 x86_64 版本
docker run --rm -v $(pwd):/work s-compiler:latest \
  s compile /work/posttrain/core/tensor_runtime_test.s
```

---

## 📋 三个快速行动项

### 1️⃣ 编译并运行测试 (1 小时)

```bash
# 进入项目目录
cd /home/shuwen/shuwen/neurx

# 编译测试
s compile posttrain/core/tensor_runtime_test.s -o /tmp/tensor_test

# 运行测试
/tmp/tensor_test

# 预期输出:
# ========================================
# Test Suite Results
# ========================================
# Total: 80
# Passed: 60+
# Failed: 0
```

### 2️⃣ 增强实现 (6 小时)

在 `posttrain/core/tensor_runtime.s` 中添加:

```s
// 新增函数清单
func tensor_transpose_nd_s(tensor_s t, []int axes) tensor_s
func tensor_expand_s(tensor_s t, []int new_shape) tensor_s
func tensor_sum_s(tensor_s t, int axis) tensor_s
func tensor_mean_s(tensor_s t, int axis) tensor_s
func tensor_copy_s(tensor_s t) tensor_s
```

**详见**: [W1_TENSOR_RUNTIME_COMPLETION_PLAN.md](W1_TENSOR_RUNTIME_COMPLETION_PLAN.md) 第 2-3 节

### 3️⃣ 验证和提交 (6 小时)

```bash
# 增加新测试 (~40 个)
# 验证所有 120+ 测试通过
s compile posttrain/core/tensor_runtime_test.s -o /tmp/tensor_test
/tmp/tensor_test

# 提交
git add -f posttrain/core/tensor_runtime.s posttrain/core/tensor_runtime_test.s
git commit -m "W1 Complete: Implementation 100% + Validation 100%"
```

---

## 🎯 验收标准 (Definition of Done)

| 项目 | 标准 | 状态 |
|------|------|------|
| **编译** | ✓ 0 个编译错误 | ⏳ 待修复编译器 |
| **测试** | ✓ 120+ 测试全过 | ⏳ 待编译 |
| **精度** | ✓ RMSError < 1e-5 | ⏳ 待验证 |
| **性能** | ✓ reshape < 1ms | ⏳ 待测试 |
| **文档** | ✓ 所有函数有注释 | ✅ 完成 |
| **代码审查** | ✓ 2 人审查通过 | ⏳ 待提交 |

---

## 📂 相关文件

| 文件 | 用途 | 状态 |
|------|------|------|
| [posttrain/core/tensor_runtime.s](posttrain/core/tensor_runtime.s) | 核心实现 | F50% I40% V0% |
| [posttrain/core/tensor_runtime_test.s](posttrain/core/tensor_runtime_test.s) | 80+ 单元测试 | ✅ 完成 |
| [W1_TENSOR_RUNTIME_COMPLETION_PLAN.md](W1_TENSOR_RUNTIME_COMPLETION_PLAN.md) | 详细计划 | ✅ 完成 |
| [PHASE2A_REVISED_ROADMAP.md](PHASE2A_REVISED_ROADMAP.md) | W1-W11 时间表 | ✅ 完成 |

---

## 🔗 依赖解锁

完成 W1 后，立即解锁:

```
W1 ✅ Tensor Runtime
  ↓ (解锁所有)
  ├─→ W2: Tokenizer
  ├─→ W3: Embedding
  ├─→ W4: RoPE
  ├─→ W5: Attention
  ├─→ W6: Transformer Block
  ├─→ W7: Loss
  ├─→ W8: Autograd
  ├─→ W9: Optimizer
  ├─→ W10: Checkpoint
  └─→ W11: Evaluation
```

**关键**: W1 是**唯一**不被任何东西阻塞的模块，完成它就能启动整个后训练管道。

---

## 💡 调试提示

### 编译器问题排查

```bash
# 1. 检查编译器
file /home/shuwen/.local/bin/s
# 应该包含: ELF 64-bit LSB executable, x86-64

# 2. 检查依赖库
ldd /home/shuwen/.local/bin/s
# 应该都显示 not found 或有效路径

# 3. 手动执行
/home/shuwen/.local/bin/s --version

# 4. 尝试简单编译
echo 'func main() { println("hello") }' > /tmp/test.s
/home/shuwen/.local/bin/s compile /tmp/test.s -o /tmp/test
/tmp/test
```

### 测试运行问题

```bash
# 如果测试失败
cd /home/shuwen/shuwen/neurx

# 查看详细错误
s compile -v posttrain/core/tensor_runtime_test.s

# 逐个编译函数测试
s compile posttrain/core/tensor_runtime.s
```

---

## ✅ 检查清单

- [ ] 编译器版本确认 (x86_64)
- [ ] 现有 80 个测试全部通过
- [ ] 实现 5+ 个新函数
- [ ] 新测试全部通过
- [ ] 与 Python NumPy 对标验证
- [ ] 提交代码并 push
- [ ] W2 Tokenizer 开始

---

## 📞 需要帮助?

1. **编译器问题** → 查看本文件 "编译器问题排查" 部分
2. **测试失败** → 检查 [W1_TENSOR_RUNTIME_COMPLETION_PLAN.md](W1_TENSOR_RUNTIME_COMPLETION_PLAN.md)
3. **实现问题** → 参考 tensor_runtime_test.s 中的测试用例
4. **性能问题** → 查看 PHASE2A_REVISED_ROADMAP.md "性能基线" 部分

---

**下一步**: 1. 修复编译器 → 2. 运行测试 → 3. 增强实现 → 4. 提交

