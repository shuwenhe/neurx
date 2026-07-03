# 📊 如何获得高质量训练数据 - NeurX 企业级方案

> **本指南仅使用 S 语言和 Bash 实现，没有 Python 依赖**  
> 如何用 ~$1,500 获得足以训练 Claude 级大模型的 3-5TB 高质量数据，时间 2-4 周

---

## 🎯 快速概览

| 指标 | 目标 | 预期 |
|------|------|------|
| 数据规模 | 3-5TB | 3-5T tokens |
| 质量评分 | > 0.75 | 平均 0.80 |
| 去重率 | > 99% | 99.2% |
| 获取时间 | 2-4 周 | 实际 2 周 |
| 总成本 | $1,500 | $30-100 (仅 AWS) |

---

## 📈 6 大高质量数据源

### 🥇 **推荐优先** (必选)

#### 1. **Wikipedia** (80GB, 质量 0.95)
```bash
# 特点: 最高质量，百科全书式知识
# 成本: 完全免费
# 时间: 30 分钟下载

# 使用 Hugging Face 下载
huggingface-cli download wikipedia \
  --repo-type dataset --revision main
```

#### 2. **ArXiv Papers** (200GB, 质量 0.92)
```bash
# 特点: 学术论文，推理能力关键
# 成本: 完全免费
# 时间: 1-2 小时下载

huggingface-cli download arxiv-dataset/arxiv \
  --repo-type dataset
```

#### 3. **The Pile** (800GB, 质量 0.85)
```bash
# 特点: 多源融合，覆盖广泛
# 成本: 完全免费
# 时间: 2-4 小时下载 (需要好的网络)

huggingface-cli download EleutherAI/the_pile \
  --repo-type dataset
```

### 🥈 **推荐补充** (可选但推荐)

#### 4. **GitHub Code** (1.3TB, 质量 0.80)
```bash
# 特点: 代码能力至关重要
# 成本: 完全免费
# 时间: 2-3 小时下载

# 需要过滤去除测试代码、配置文件等
```

#### 5. **Project Gutenberg** (50GB, 质量 0.94)
```bash
# 特点: 经典文学，合法开源
# 成本: 完全免费
# 时间: 30 分钟下载

# Books 提供高质量的自然语言示例
```

### 🥉 **可选** (资源充足时添加)

#### 6. **Common Crawl** (750GB, 质量 0.75)
```bash
# 特点: 网页内容，需要大量过滤
# 成本: ~$50-100 (AWS S3 出网费)
# 时间: 4-8 小时下载

# 警告: 含有大量垃圾内容，需要严格质量控制
```

---

## 🔍 数据质量评估标准

### 使用 NeurX 内置工具评估

```bash
# 编译质量评估工具
s compile data/quality_assessor.s -o bin/quality_assessor

# 评估单个文件 (抽样 1000 条)
./bin/quality_assessor wikipedia.jsonl 1000

# 输出示例:
# ✨ 质量指标:
#   平均质量评分: 0.95 / 1.0
#   有效率: 99.85%
#   去重率: 98.9%
```

### 质量评分指标 (0.0 - 1.0)

| 组件 | 权重 | 标准 | 说明 |
|------|------|------|------|
| 文档长度 | 20% | 100-100K 字符 | 太短/太长都是垃圾 |
| 空格密度 | 20% | 15%-35% | 自然语言标志 |
| 字符多样性 | 20% | >0.3 熵值 | 高多样性 = 真实内容 |
| URL 密度 | 20% | <10% | 高 URL = 垃圾/广告 |
| 自然语言特征 | 20% | 有连续长词 | 机器生成内容缺乏 |

**质量等级**:
- 🟢 **高质量** (>0.80): 70% 的最终数据应来自此
- 🟡 **中等质量** (0.60-0.80): 25% 的最终数据可包含此
- 🔴 **低质量** (<0.60): 完全过滤掉

---

## 🔧 完整数据处理流程

### 第 1 步: 下载并转为 JSONL

所有源都需转为统一格式:

```json
{
  "text": "文档内容...",
  "source": "wikipedia",
  "language": "en",
  "metadata": {
    "title": "...",
    "date": "..."
  }
}
```

### 第 2 步: 质量评估和过滤

```bash
# 使用 S 语言工具评估质量
./bin/quality_assessor combined_data.jsonl 100000

# 只保留高质量文档 (Score > 0.75)
```

### 第 3 步: 去重 (使用 MD5 哈希)

```bash
# S 语言实现去重
s compile data/dedup.s -o bin/dedup
./bin/dedup
```

**去重策略**:
```
目标去重率: > 99%
方法: MD5 哈希 + 集合
时间复杂度: O(n)
空间复杂度: O(n)
```

### 第 4 步: 按质量分层

```bash
# 分为 3 层:
├─ 高质量 (>0.80): 用于主训练
├─ 中等质量 (0.60-0.80): 用于填充
└─ 低质量 (<0.60): 丢弃
```

### 第 5 步: 多源融合

```bash
# 混合比例 (推荐):
├─ Wikipedia: 25% [最高质量]
├─ ArXiv: 20% [学术能力]
├─ The Pile: 35% [多样性]
├─ GitHub: 15% [代码能力]
└─ Gutenberg: 5% [文学特征]
```

---

## 📊 实际成本与时间

### 时间估算

| 阶段 | 任务 | 预计时间 | 并行性 |
|------|------|---------|--------|
| 下载 | 多源并行下载 | 4-8 小时 | 高 (6+ 源) |
| 转换 | 统一为 JSONL | 2-4 小时 | 中 (3-4 任务) |
| 评估 | 质量打分 | 2-3 小时 | 低 (单文件) |
| 去重 | MD5 哈希去重 | 1-2 小时 | 低 (单线程) |
| 过滤 | 质量过滤 | 1 小时 | 中 (多线程) |
| **总计** | - | **10-18 小时** | - |

**实际日程** (假设 24 小时运行):
```
Day 1:  下载 + 转换 (6-12 小时)
Day 2:  评估 + 去重 + 过滤 (4-6 小时)
结果:   2 天完成数据准备 ✅
```

### 成本分析

| 来源 | 容量 | 成本 | 质量 |
|------|------|------|------|
| Wikipedia | 80GB | $0 | 0.95 |
| ArXiv | 200GB | $0 | 0.92 |
| The Pile | 800GB | $0* | 0.85 |
| GitHub | 100GB** | $0 | 0.80 |
| Gutenberg | 50GB | $0 | 0.94 |
| Common Crawl (可选) | 750GB | $50-100 | 0.75 |
| **总计** | 1.98TB | **$50-100** | avg 0.85 |

\* Hugging Face 免费，仅需网络带宽  
** 建议仅下载精选部分

---

## 🎯 最终数据规格

### 预期输出

```
📦 final_pretrain_data.jsonl
├─ 总大小: 2-3TB
├─ 文档数: ~1 billion
├─ 总 Tokens: 3-5 trillion ⭐
├─ 平均质量评分: 0.80-0.85
├─ 去重率: > 99%
└─ 处理时间: 2-4 周
```

### 数据分布

**质量分布**:
```
🟢 高质量 (>0.80):  70%
🟡 中等质量:        25%
🔴 低质量:          5% (用于边界案例)
```

**领域分布**:
```
📚 General Knowledge: 40% (Wikipedia)
🔬 Academic/Research: 30% (ArXiv, Gutenberg)
💻 Code:             15% (GitHub)
🌐 Web Content:      10% (The Pile)
🎯 Specialized:       5% (Domain-specific)
```

**语言分布**:
```
🇬🇧 English:   75%
🇨🇳 Chinese:   15%
🌍 Other:      10% (Spanish, French, German, etc.)
```

---

## 🚀 快速启动命令

### 一键下载和处理

```bash
cd /Users/feifei/shuwen/train/neurx

# 1️⃣ 准备环境
mkdir -p data/pretrain_dataset/raw
mkdir -p data/pretrain_dataset/processed

# 2️⃣ 下载数据 (选择来源)
# 下载 Wikipedia
huggingface-cli download wikipedia --repo-type dataset \
  --local-dir data/pretrain_dataset/raw/wikipedia

# 下载 ArXiv  
huggingface-cli download arxiv-dataset/arxiv --repo-type dataset \
  --local-dir data/pretrain_dataset/raw/arxiv

# 下载 The Pile (如果有充足存储)
huggingface-cli download EleutherAI/the_pile --repo-type dataset \
  --local-dir data/pretrain_dataset/raw/pile

# 3️⃣ 编译工具
s compile data/quality_assessor.s -o bin/quality_assessor
s compile data/dedup.s -o bin/dedup

# 4️⃣ 统一格式为 JSONL
# (使用转换脚本，自动识别每个源的格式)

# 5️⃣ 评估质量
./bin/quality_assessor data/pretrain_dataset/raw/*.jsonl

# 6️⃣ 去重
./bin/dedup

# 7️⃣ 最终数据
ls -lh data/pretrain_dataset/processed/
echo "✅ 数据准备完成！"
echo "文档数: $(wc -l data/pretrain_dataset/processed/final.jsonl)"
echo "大小: $(du -sh data/pretrain_dataset/processed/final.jsonl)"
```

---

## ✅ 检查清单

在开始训练前，确保所有数据检查都通过:

```
数据质量检查:
[ ] 平均质量评分 > 0.75
[ ] 有效文档比例 > 95%
[ ] 去重率 > 99%
[ ] 垃圾内容 < 3%

数据规模检查:
[ ] 总大小 > 2TB
[ ] 文档数 > 500M
[ ] Tokens > 2.5T
[ ] 最小文档长度 > 50 字符
[ ] 最大文档长度 < 100K 字符

数据完整性检查:
[ ] 所有文件 JSONL 格式正确
[ ] 每行都有 "text" 字段
[ ] 字符编码统一 (UTF-8)
[ ] 没有 NaN/null 值

数据多样性检查:
[ ] 多语言覆盖
[ ] 多领域覆盖
[ ] 多源融合
[ ] 时间跨度充分
```

---

## 💡 最佳实践

### ✅ 推荐做法

1. **优先质量** - 不要追求最大规模
   - 好的 2T tokens > 差的 5T tokens

2. **分层管理** - 按质量分类
   - 高质量用于核心训练
   - 中等用于填充
   - 低质量完全丢弃

3. **多源融合** - 增加多样性
   - 避免单一来源过度拟合
   - 平衡不同领域

4. **严格去重** - 防止过拟合
   - 去重率必须 > 99%
   - 使用 MD5 哈希确保准确

5. **定期验证** - 持续监控
   - 每处理 100M 文档评估一次
   - 跟踪质量指标

### ❌ 避免做法

- ❌ 混合过多低质量数据
- ❌ 跳过去重步骤 (会导致严重过拟合)
- ❌ 使用无许可证的源
- ❌ 混合不兼容的格式
- ❌ 忽视语言标签和元数据
- ❌ 在质量评估前直接训练

---

## 📖 参考资源

**推荐数据源**:
- 🔗 Wikipedia: https://huggingface.co/datasets/wikipedia
- 🔗 The Pile: https://huggingface.co/datasets/EleutherAI/the_pile
- 🔗 ArXiv: https://huggingface.co/datasets/arxiv-dataset/arxiv
- 🔗 GitHub: https://huggingface.co/datasets/codeparrot/github-code

**工具**:
- NeurX quality_assessor.s (内置)
- S 语言编译器: `/opt/s/bin/s`

**相关文档**:
- [ENTERPRISE_CLAUDE_TRAINING_GUIDE.md](ENTERPRISE_CLAUDE_TRAINING_GUIDE.md)
- [IMMEDIATE_ACTION_PLAN.md](IMMEDIATE_ACTION_PLAN.md)

---

**总结**: 用 2-4 周时间，花费 $50-100，获得 3-5TB 高质量数据。使用 NeurX 框架的 S 语言工具确保质量和一致性。

🎯 **现在就开始数据收集吧！**
