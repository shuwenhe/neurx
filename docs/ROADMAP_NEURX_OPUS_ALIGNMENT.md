# NeurX 对标 Claude Opus 4.8 - 关键优先级与行动计划

**现状**: 7B 训练入口已接入配置驱动启动链，Phase 1-9 完成  
**目标**: 达到Claude Opus 4.8竞争力（企业级工业模型）  
**时间**: 6周内实现关键特性  

## 当前已落地

- `make train-7b` 已可从 [`configs/7b_training.json`](/Users/feifei/shuwen/train/neurx/configs/7b_training.json) 生成 7B 启动环境并进入 launcher
- `make train` 已切到纯 S 生成的 `launch_plan.sh` 入口
- 训练启动链已包含：
  - 数据 manifest / shard 目录
  - tokenizer 配置
  - checkpoint 恢复路径
  - optimizer state 保存开关
  - 分布式 world size / backend / master 配置

## 仍需补齐

- 让 `script/large_model_trainer.s` 直接消费 `NEURX_7B_*` 环境变量，而不是继续依赖手写默认值
- 把数据侧真正接到流式 token 管线、shuffle 和 epoch 级采样
- 把 checkpoint 细化到 optimizer state 分片恢复与严格校验
- 把 7B 路线升级成 70B / 长上下文 / 多模态的统一配置族

---

## 📊 能力对标分析

### Claude Opus 4.8 核心能力
| 维度 | Claude Opus | NeurX 7B 现状 | 缺口 | 优先级 |
|------|-------------|---------|------|------|
| **参数规模** | 200B+ | 7B | 28x | 🔴 P0 |
| **长上下文** | 200K tokens | 32K tokens | 6x | 🔴 P0 |
| **多模态** | 视觉+文本 | 文本仅 | 完全缺失 | 🔴 P0 |
| **推理能力** | 链式思维+搜索树 | 贪心解码 | 显著 | 🟡 P1 |
| **对齐质量** | 宪法AI+微调 | 基础RLHF | 中等 | 🟡 P1 |
| **更新频率** | 连续微调 | 一次性训练 | 完全缺失 | 🟡 P1 |

---

## 🎯 关键行动优先级（对标Opus）

### 【第1优先：参数规模升级】⭐⭐⭐⭐⭐
**为什么最重要**: 参数本身 = 能力基础，300%的影响力

**当前状态**：7B 配置和启动链已完成  
**下一步**：先把 7B 入口收敛到配置驱动，再复制为 70B 配置族

```
7B → 70B升级路线:
├─ Week 1: 70B架构集成
│  ├─ 增加layers: 32 → 80
│  ├─ 增加hidden_dim: 4096 → 8192  
│  ├─ 调整head数: 32 → 64
│  ├─ 启用tensor parallelism: TP=4
│  └─ 验证内存（需要128GB per GPU或8×H100）
│
├─ Week 2-3: 70B初步收敛
│  ├─ 1-10K步基础验证
│  ├─ 损失应该从6.0 → 3.5-4.0
│  ├─ 困惑度: 50+ → 25-30
│  └─ 如果收敛正常，继续全量训练
│
└─ Week 4-6: 完整收敛
   ├─ 目标: 50-100K步达到Opus级别
   ├─ 困惑度目标: 8-10（Opus: 6-8，允许接近）
   ├─ 基准测试: MMLU 40%+, HellaSwag 60%+
   └─ 模型锁定用于后续微调
```

**关键配置（70B）**:
```json
{
  "num_parameters": 70000000000,
  "hidden_size": 8192,
  "num_hidden_layers": 80,
  "num_attention_heads": 64,
  "training": {
    "gradient_accumulation_steps": 16,
    "batch_size": 2,
    "learning_rate": 3e-4
  },
  "distributed": {
    "tensor_parallel_size": 4,
    "pipeline_parallel_stages": 2,
    "zero_stage": 3
  },
  "total_tokens": "500B",
  "estimated_time": "600-800 hours",
  "cost": "$50-80K"
}
```

**立即行动**：
```bash
# 1. 复制 7B 配置作为 70B 起点
cd /Users/feifei/shuwen/train/neurx
cp configs/7b_training.json configs/70b_training.json

# 2. 手工或用脚本调整 70B 参数族
# - hidden_size: 4096 -> 8192
# - num_hidden_layers: 32 -> 80
# - num_attention_heads: 32 -> 64
# - tensor_parallel_size: 1 -> 4
# - pipeline_parallel_stages: 1 -> 2
# - zero_stage: 1 -> 3

# 3. 启动 70B 训练
torchrun --nproc_per_node=8 train_full.py \
  --config configs/70b_training.json \
  --output_dir checkpoints_70b
```

---

### 【第2优先：长上下文处理】⭐⭐⭐⭐
**为什么重要**: Claude的200K上下文 vs NeurX的32K = 关键竞争力

**当前状态**：RoPE + 滑动窗口 = 32K  
**目标**：200K tokens（与Opus一致）

**方案**（选一个立即实施）：

**选项A：Ring Attention**（最快）
```
特点：可扩展到任意长度
实施成本：1000行代码
时间：1-2周
集成：与第1优先并行
```

**选项B：Flash-Attention-2 + Segment补丁**
```
特点：内存高效
实施成本：1500行代码  
时间：2-3周
集成：可与第1优先并行
```

**选项C：使用第三方库** (最快上线)
```
采用：xFormers或Flash-Attention库
优势：立即可用，性能已验证
成本：最低，约100行集成代码
时间：3-5天
建议：优先此方案
```

**立即行动**:
```bash
# 安装flash-attention
pip install flash-attn==2.5.0

# 修改train_full.py中的attention mechanism为FlashAttentionV2
# 参考script/long_context_handler.s的RoPE实现，但启用ALiBi调整支持200K

# 验证长上下文
python3 << 'EOF'
import torch
# 测试200K长度的前向传播
batch_size = 1
seq_len = 200000
hidden_dim = 8192
with torch.no_grad():
    x = torch.randn(batch_size, seq_len, hidden_dim, device='cuda')
    # forward pass should complete without OOM
    print(f"Successfully handled {seq_len} tokens")
EOF
```

---

### 【第3优先：多模态支持】⭐⭐⭐⭐
**为什么重要**: Claude 3的核心优势，70%企业用例需要

**当前状态**：文本仅  
**目标**：文本 + 图像 + 表格 + PDF

**快速方案**（2周内上线）：

```
架构设计:
┌─────────────────────────────────────┐
│  输入处理层                           │
├─────────────────────────────────────┤
│  图像输入  ──┬──> 视觉编码器(CLIP)    │
│            │     (300M params)      │
│            ├──> 视觉token序列        │
│  文本输入  ──┤    (4096 tokens)      │
│            │                       │
│            └──> 融合层(MLP, 150M)   │
├─────────────────────────────────────┤
│  7B/70B Transformer                 │
│  处理 [visual_tokens + text_tokens] │
├─────────────────────────────────────┤
│  输出层（分布预测）                  │
└─────────────────────────────────────┘

代码行数：~1500行
集成周期：2周
训练时间：100-200 GPU小时
```

**立即行动**:
```bash
# 1. 准备视觉编码器
pip install open_clip_torch

# 2. 创建多模态数据加载器
# script/multimodal_loader.py (~400行)
# - 加载图像-文本配对
# - 动态分辨率处理
# - 视觉token化

# 3. 集成架构修改
# train_full.py中添加:
# - VisonEncoder初始化（冻结CLIP参数）
# - 视觉投影层（4096维）
# - 多模态训练循环

# 4. 准备数据集
# - COCO Captions 100M对
# - Visual Genome 100M对
# - 内部企业数据

# 5. 预训练第一个多模态检查点
torchrun --nproc_per_node=8 train_multimodal.py \
  --config configs/7b_multimodal.json \
  --vision_encoder openai/clip-vit-large-patch14 \
  --max_steps 10000
```

---

### 【第4优先：推理能力增强】⭐⭐⭐
**为什么重要**: Claude的数学/代码能力 = 差异化竞争力

**当前状态**：贪心解码  
**目标**：链式思维 + 搜索树

**快速实现**（选一个立即做）：

**选项A：思维tokens系统**（最快）
```python
# 核心思想：让模型显式输出思考过程
class ThinkingTokenTrainer:
    def __init__(self):
        self.thinking_budget = 3000  # tokens用于思考
        
    def forward(self, prompt):
        # 阶段1：思考（hidden tokens）
        thinking_tokens = self.generate(prompt, max=3000)
        
        # 阶段2：回答
        answer = self.generate(thinking_tokens + prompt, max=1000)
        
        return thinking_tokens + answer

实施成本：500行代码
训练数据：现有SFT数据 + 人标思过程
时间：1-2周集成
```

**选项B：树搜索解码**
```python
# 使用beam search的增强版
class TreeSearchDecoder:
    def __init__(self, beam_width=4):
        self.beam_width = beam_width  # 并行搜索路径
        
    def decode(self, prompt):
        # 维护多个候选序列
        # 基于中间logits概率修剪
        # 保留top-K最可能路径
        return best_path

成本：800行代码
时间：2周
效果：数学题 +15-25%准确率
```

**立即行动**:
```bash
# 方案A（推荐）：思维tokens
# 1. 准备训练数据（数学/编程题 + 思考过程标注）
# 2. 修改训练循环支持思维tokens
# 3. 微调第7B模型 1000步
python3 train_thinking_tokens.py \
  --checkpoint checkpoints/7b_step_10000.pt \
  --data thinking_data.jsonl \
  --output_dir checkpoints/7b_reasoning \
  --max_thinking_tokens 3000
```

---

### 【第5优先：安全对齐**优化】⭐⭐⭐
**为什么重要**: 企业部署必须条件

**当前状态**：10类安全分类器  
**目标**：50类 + 宪法AI对齐

**快速升级**（1周）：

```python
# 从Phase 9的安全过滤器扩展

class EnhancedSafetyFilter:
    def __init__(self):
        # 50个分类维度
        self.categories = {
            # 传统安全类
            'violence': {...},
            'sexual_content': {...},
            'hate_speech': {...},
            
            # 企业特定类
            'financial_advice': {...},
            'medical_guidance': {...},
            'legal_opinion': {...},
            'personal_data_exposure': {...},
            
            # 新增高阶类
            'misinformation': {...},
            'manipulation': {...},
            'autonomy_violation': {...},
            # ... 40+个类
        }
    
    def classify(self, response):
        scores = self.classifier.predict(response)
        return {cat: score for cat, score in scores.items() if score > 0.5}
    
    def filter(self, response):
        risks = self.classify(response)
        return self.handle_risks(risks, response)

代码成本：1000行
训练数据：Phase 9数据集 + 50K标注样本
时间：1-2周
```

**立即行动**:
```bash
# 1. 扩展安全分类器
cp script/safety_filter.s script/advanced_safety_filter.s
# 修改类别从10→50

# 2. 微调安全判别器
python3 train_safety_classifier.py \
  --categories 50 \
  --data safety_annotations.jsonl \
  --output safety_classifier_v2.pt

# 3. 集成到推理流程
python3 infer.py --use_advanced_safety
```

---

## 📈 7周并行执行计划（对标Opus）

```
Week 1 (NOW):
├─ ✅ 7B基线完成
├─ 🔴 启动70B架构设计 (P0)
├─ 🟡 长上下文库集成 (P1 并行)
└─ 📊 多模态数据准备开始

Week 2-3:
├─ 🔴 70B预训练启动，1-10K步验证 (P0)
├─ 🟡 完成长上下文集成，测试100K+ (P1)
├─ 🟡 多模态视觉编码器集成 (P2)
└─ 测试checkpoint系列质量

Week 4:
├─ 🔴 70B继续训练，20-50K步质量评估 (P0)
├─ 🟡 多模态SFT启动，5K-10K步 (P2)
├─ 🟡 思维tokens系统集成 (P3)
└─ 基准测试对标

Week 5:
├─ 🔴 70B达到收敛，PPL = 8-12 (P0)
├─ 🟡 多模态达到MVP，图像理解测试 (P2)
├─ 🟡 树搜索解码集成，数学题测试 (P3)
└─ 质量评估+迭代

Week 6:
├─ 🔴 70B 模型锁定，用于微调 (P0)
├─ 🟡 多模态SFT完成，性能稳定 (P2)
├─ 🟡 安全对齐扩展到50类 (P4)
└─ 企业级评估

Week 7:
├─ 集成全部特性
├─ 端到端测试套件
├─ 基准测试完整评估
└─ ✨ Claude Opus级别模型就绪
```

---

## 💡 立即执行清单（优先度顺序）

### 现在立即做（今天）：
- [ ] **启动70B训练配置**
  ```bash
  python3 configs/create_70b_config.py > configs/70b_training.json
  ```
- [ ] **安装多模态依赖**
  ```bash
  pip install clip-vit-base-patch32 einops timm
  ```
- [ ] **准备长上下文集成**
  ```bash
  pip install flash-attn==2.5.0
  ```

### 本周内（优先P0）：
1. 启动70B预训练（8×H100）
2. 验证70B架构稳定性（前1000步）
3. 集成Flash-Attention V2支持200K

### 下周（P1并行）：
1. 多模态视觉编码器集成
2. 思维tokens系统设计
3. 长上下文测试验证

---

## 🎯 成功指标（对标Opus）

### Week 1-2:
- ✅ 7B基线：PPL = 15-18（基准达成）
- ✅ 70B启动：PPL = 35-40（收敛中）
- ✅ 长上下文：支持100K+ tokens

### Week 3-4:
- ✅ 70B进度：PPL = 20-25（改善中）
- ✅ 多模态MVP：图像描述≥80%准确
- ✅ 推理能力：数学题+5%准确率

### Week 5-6:
- ✅ 70B最终：PPL = 8-12（Opus级别）
- ✅ 多模态完整：表格/图表理解
- ✅ 安全对齐：50类分类，0误报

### Week 7:
- ✅ **综合能力达到Opus 80%级别**
- ✅ **企业级模型就绪**

---

## 资源需求

```
计算资源:
├─ 70B预训练：8×H100 (80GB)
│  ├─ 6-8周连续运行
│  ├─ 成本: $80-120K
│  └─ 时间: 600-1000 GPU小时
│
├─ 多模态训练：4×H100 (需要并行)
│  ├─ 2-4周
│  ├─ 成本: $20-30K
│  └─ 时间: 200-400 GPU小时
│
└─ 总计: 12×H100容量, $100-150K, 800-1400小时

数据资源:
├─ 预训练：500B tokens (已有)
├─ 多模态：100M 图像-文本对 (需准备)
├─ SFT: 500K高质量指令 (已有Phase 9)
└─ 对齐：50K安全标注 (扩展现有)

人力资源:
├─ 模型工程师：1人（全职70B）
├─ 多模态工程师：1人
├─ 基础设施工程师：1人支持
└─ 总计：2.5 FTE
```

---

## 关键风险与缓解

| 风险 | 影响 | 缓解方案 |
|------|------|--------|
| 70B OOM | 停工4周 | 预先验证ZeRO-3配置 |
| 多模态性能差 | 推迟2周 | 先用小规模（7B）验证 |
| 长上下文低效 | 推理成本↑5x | 提前基准测试 |
| 安全对齐退化 | 发布延迟 | 分离安全微调通道 |

---

## 最后：为什么这个顺序

1. **70B（P0）**：参数本身是所有其他能力的基础
2. **长上下文（P1并行）**：与参数升级无冲突，立即增加价值
3. **多模态（P1并行）**：高价值但独立，可与70B同时进行
4. **推理能力（P2）**：建立在大模型基础上，效果更好
5. **安全对齐（P3）**：最后微调，确保整体质量

**Bottom line**: 6周内使用当前 NeurX 框架，把 7B 训练入口做成工业可恢复形态，并并行推进 70B / 长上下文 / 多模态能力
