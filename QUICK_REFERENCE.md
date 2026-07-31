# NeurX 快速参考 - 只记这些！

## 🎯 核心文件（只关注这 2 个）

```
/home/shuwen/shuwen/neurx/
├── posttrain/trainer/posttrain_main.s  ← 训练代码（✅ 已验证工作）
└── Makefile                             ← 运行命令
```

**其他 160+ 个文件暂时忽略！**

---

## ⚡ 常用命令（只需要这 3 个）

```bash
# 1. 运行训练（~8秒）
make posttrain

# 2. 查看结果
grep "loss=" artifacts/logs/*.log | tail -5

# 3. 编辑训练代码
vim posttrain/trainer/posttrain_main.s
```

---

## 🔧 如何修改训练参数？

**只编辑这 1 个文件**：`posttrain/trainer/posttrain_main.s`

### 关键位置：

| 行数 | 内容 | 作用 |
|------|------|------|
| **207-213** | `epochs=1, samples=1` | 训练轮数、样本数 |
| **330** | `init_gaussian(...)` | 训练数据 |
| **398-410** | `loss = diff * diff` | 损失函数 |
| **440** | `grad_a = ...` | 梯度计算 |

### 示例修改：

```s
// 增加训练轮数（Line 209）
int epochs = 3  // 原来是 1

// 增加样本数（Line 210）  
int samples_per_epoch = 5  // 原来是 1
```

---

## 📊 验证训练是否工作

```bash
make posttrain 2>&1 | grep -E "loss=|lora_A|lora_B"
```

**期望看到**：
```
loss=29.414998              ← Loss 有值
lora_A[0] = 0.00001999     ← 权重变化了
lora_B[0] = 0.00001008     ← 权重变化了
```

---

## 🗺️ 目录结构（参考，不用记）

<details>
<summary>点击展开（实际不需要看）</summary>

```
neurx/
├── posttrain/
│   └── trainer/
│       └── posttrain_main.s  ← 你唯一需要的文件
├── model/                     ← 基础模型（不用管）
├── dataset/                   ← 数据集（不用管）
├── artifacts/                 ← 编译输出（不用管）
├── loss/                      ← 损失函数（已有实现，不用管）
├── optimizer/                 ← 优化器（不用管）
└── [其他 50+ 个目录]         ← 全部忽略
```

</details>

---

## 💡 核心原则

### ✅ 做这些：
1. 只编辑 `posttrain_main.s`
2. 运行 `make posttrain`
3. 查看 `loss=` 是否变化

### ❌ 不要做：
1. ~~探索其他目录~~
2. ~~理解整个框架~~
3. ~~创建新文件~~

---

## 🚨 遇到问题？

### 编译错误
```bash
# 清理重新编译
make clean
make posttrain
```

### 找不到文件
```bash
# 确认你在正确的目录
pwd
# 应该显示：/home/shuwen/shuwen/neurx
```

### 训练不工作
```bash
# 查看完整日志
make posttrain 2>&1 | tail -100
```

---

## 📝 今日成就（2026-07-31）

✅ **训练真正工作了**  
✅ **Loss = 29.41**（从 0.0 改进）  
✅ **权重更新了**（lora_A/B 变化）  

**下一步**：在 `posttrain_main.s` 基础上增强，不要创建新文件！

---

**记住：简单 > 复杂。只改 1 个文件，跑 1 个命令。**
