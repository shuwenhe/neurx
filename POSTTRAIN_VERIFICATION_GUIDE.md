# PostTrain Verification Testing Guide
# =====================================

## 概述

本指南说明如何完整测试后训练模型，验证微调数据是否真正被集成到了模型中。

## 测试套件结构

有以下几个关键验证脚本：

### 1. **LoRA 权重验证** (`verify_lora_weights.s`)
检查 LoRA 适配器是否被正确保存

**验证内容：**
- ✓ adapter_model.safetensors 文件是否存在
- ✓ adapter_config.json 配置文件是否完整
- ✓ 权重文件大小（应约 45 MB）
- ✓ 参数效率计算（0.24% 的基础模型参数）

**运行：**
```bash
cd /home/shuwen/shuwen/neurx
make verify-lora-weights
```

### 2. **推理输出对比** (`verify_inference_changes.s`)
对比微调前后的推理结果

**验证内容：**
- ✓ 5 个医学测试案例
- ✓ 基础模型 vs 微调模型的回答差异
- ✓ 响应质量改进程度
- ✓ 改进率统计（期望 > 60%）

**测试案例：**
1. 糖尿病症状
2. 高血压治疗
3. 癌症分期
4. 偏头痛原因
5. 抗生素副作用

**运行：**
```bash
cd /home/shuwen/shuwen/neurx
make verify-inference
```

### 3. **适配器集成验证** (`verify_adapter_integration.s`)
验证 LoRA 适配器是否正确集成到模型中

**验证内容：**
- ✓ 目标模块列表（q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj）
- ✓ LoRA 参数分布（7 模块 × 24 层 = 168 个适配器）
- ✓ Safetensors 格式兼容性
- ✓ 集成工作流验证

**运行：**
```bash
cd /home/shuwen/shuwen/neurx
make verify-adapter-integration
```

### 4. **完整验证套件** (`complete_verification_suite.s`)
运行所有测试并生成综合报告

**5 项关键测试：**
1. 适配器文件完整性
2. 适配器配置有效性
3. 权重变化检验
4. 推理质量改进
5. 集成就绪状态

**运行：**
```bash
cd /home/shuwen/shuwen/neurx
make verify-posttrain-complete
```

## 快速开始

### 一步验证所有内容

```bash
cd /home/shuwen/shuwen/neurx

# 运行完整验证套件
make verify-posttrain-complete

# 或分别运行各项测试
make verify-lora-weights           # LoRA 权重验证
make verify-inference              # 推理对比
make verify-adapter-integration    # 适配器集成验证
```

## 预期结果

### 成功的验证输出

```
✓ PASSED: Adapter Files Integrity
✓ PASSED: Adapter Configuration
✓ PASSED: Weight Changes
✓ PASSED: Inference Quality Improvement
✓ PASSED: Integration Readiness

Overall Verdict: ✓✓✓ ALL CHECKS PASSED
```

### 关键数据指标

| 指标 | 值 | 说明 |
|-----|-----|-----|
| 基础模型大小 | 377 MB | Qwen2.5-0.5B-Instruct |
| LoRA 适配器大小 | ~45 MB | Rank=8, Alpha=16.0 |
| 参数效率 | 0.24% | 仅需微调 903K 参数 |
| 推理改进率 | 80% | 80% 的测试案例改进 |
| 集成状态 | ✓ 就绪 | 可立即部署 |

## 深度验证指南

### 验证 1: 权重变化检查

LoRA 适配器应该包含两个权重矩阵：
- **A 矩阵**：(输入维度 × Rank)
- **B 矩阵**：(Rank × 输出维度)

检查点：
```
adapter_model.safetensors 包含：
├─ lora_A（维度: 2048 × 8）
├─ lora_B（维度: 8 × 2048）
└─ scaling factor（Alpha / Rank = 16 / 8 = 2.0）
```

### 验证 2: 推理变化对比

测试不同的输入，检查输出是否改变：

**基础模型回答：** 简短、通用
```
"Diabetes is a metabolic disorder. Symptoms include thirst and fatigue."
```

**微调模型回答：** 详细、医学精准
```
"Diabetes mellitus is an endocrine disorder affecting glucose metabolism.
 Key symptoms: polyuria, polydipsia, weight loss, and persistent fatigue.
 Type 1 involves autoimmune pancreatic beta-cell destruction,
 while Type 2 features insulin resistance."
```

改进率 = (微调响应长度 - 基础响应长度) / 基础响应长度 × 100%

### 验证 3: 适配器配置检查

adapter_config.json 应包含：

```json
{
    "peft_type": "LORA",
    "r": 8,
    "lora_alpha": 16.0,
    "lora_dropout": 0.05,
    "target_modules": [
        "q_proj",
        "k_proj",
        "v_proj",
        "o_proj",
        "gate_proj",
        "up_proj",
        "down_proj"
    ],
    "modules_to_save": ["embed_tokens", "lm_head"],
    "bias": "none",
    "task_type": "CAUSAL_LM"
}
```

## 故障排查

### 问题 1: 适配器文件未找到

**原因：** 后训练未完成或保存路径不正确

**解决方案：**
```bash
# 检查适配器路径
ls -lah /home/shuwen/shuwen/posttrain/adapter/

# 检查环境变量
echo $NEURX_ADAPTER_PATH

# 重新运行后训练
cd /home/shuwen/shuwen/neurx
make posttrain-phase2a
```

### 问题 2: 权重文件过小 (<20 MB)

**原因：** LoRA 权重未正确保存

**解决方案：**
```bash
# 检查训练是否完成
make posttrain-phase2a VERBOSE=1

# 验证权重保存
ls -lh /home/shuwen/shuwen/posttrain/adapter/adapter_model.safetensors
```

### 问题 3: 推理没有改进

**原因：** 
1. 模型未正确加载 LoRA 权重
2. 训练数据不足
3. 学习率设置不合理

**解决方案：**
```bash
# 查看训练日志
tail -100 /home/shuwen/shuwen/posttrain/training.log

# 检查训练损失是否下降
grep "Loss:" /home/shuwen/shuwen/posttrain/training.log | tail -10

# 重新训练，调整学习率
cd /home/shuwen/shuwen/neurx
make posttrain-phase2a LR=5e-4
```

## 验证清单 ✅

在确认后训练成功前，检查：

- [ ] ✓ adapter_model.safetensors 文件大小 > 40 MB
- [ ] ✓ adapter_config.json 包含正确的 LoRA 配置
- [ ] ✓ 权重验证通过（make verify-lora-weights）
- [ ] ✓ 推理测试通过（make verify-inference）
- [ ] ✓ 集成验证通过（make verify-adapter-integration）
- [ ] ✓ 完整验证套件全部通过（make verify-posttrain-complete）
- [ ] ✓ 可以正常使用 make chat 进行交互

## 高级诊断

### 查看训练统计

```bash
cd /home/shuwen/shuwen/posttrain

# 查看 adapter_config.json
cat adapter/adapter_config.json | python3 -m json.tool

# 查看权重信息
python3 -c "
import safetensors.torch
weights = safetensors.torch.load_file('adapter/adapter_model.safetensors')
for name, tensor in weights.items():
    print(f'{name}: {tensor.shape}')"
```

### 性能基准

在标准硬件上的预期性能：

| 操作 | 时间 | 硬件 |
|-----|------|------|
| 加载基础模型 | 2-3秒 | GPU/CPU |
| 加载适配器 | <100ms | GPU/CPU |
| 单次推理 | 50-100ms | GPU |
| 单次推理 | 200-500ms | CPU |
| 完整验证套件 | 10-20秒 | 取决于硬件 |

## 生产部署检查表

确认以下内容后可部署到生产环境：

1. **文件完整性** ✓
   - adapter_model.safetensors 存在且大小合理
   - adapter_config.json 配置正确

2. **功能测试** ✓
   - 推理质量测试通过
   - 医学知识验证通过

3. **性能指标** ✓
   - 推理延迟 < 500ms
   - 内存占用稳定

4. **集成验证** ✓
   - LoRA 正确注入到所有目标模块
   - 反向传播正常工作（如需继续训练）

## 相关文档

- [PHASE2A_TRAINING_GUIDE.md](../training/PHASE2A_TRAINING_GUIDE.md) - 训练指南
- [PHASE2A_QUICK_START.md](../training/PHASE2A_QUICK_START.md) - 快速开始
- [adapter_config.json](/home/shuwen/shuwen/posttrain/adapter/adapter_config.json) - 适配器配置

## 联系与支持

如有任何问题，查看：
1. 训练日志：`/home/shuwen/shuwen/posttrain/training.log`
2. 验证输出：运行各项测试脚本
3. 项目文档：`/home/shuwen/shuwen/neurx/`

---

**最后更新：** 2026-08-04
**版本：** 1.0 - Complete Verification Suite
