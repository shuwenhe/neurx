# 工业级JSONL训练数据格式说明

## 📋 文件位置
```
data/training_data_industrial_complete.jsonl
```

## 🔧 数据格式

每行是一个完整的JSON对象，包含以下字段：

```json
{
  "text": "Python高性能编程：使用NumPy实现矩阵运算比纯Python快100倍...",
  "type": "code_snippet",
  "category": "machine_learning",
  "domain": "python",
  "language": "zh",
  "quality_score": 0.95,
  "complexity": "advanced",
  "length": 106,
  "estimated_tokens": 250
}
```

## 📚 字段说明

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| **text** | string | 核心训练内容 | 技术文档、代码、讲解等 |
| **type** | string | 数据类型 | code_example, qa_pair, explanation等 |
| **category** | string | 主题分类 | machine_learning, backend等 |
| **domain** | string | 应用领域 | python, nlp, devops等 |
| **language** | string | 语言 | zh(中文), en(英文) |
| **quality_score** | float | 质量评分 | 0.0-1.0, 值越高质量越好 |
| **complexity** | string | 复杂度 | basic, intermediate, advanced, expert |
| **length** | integer | 文本长度(字符) | 数值 |
| **estimated_tokens** | integer | 估计token数 | 用于计算训练成本 |

## 🏷️ 数据类型 (type) 枚举

### 代码相关
- **code_example**: 完整代码示例
- **code_snippet**: 代码片段
- **architecture_component**: 架构组件说明

### 知识内容
- **technical_explanation**: 技术原理解释
- **best_practices**: 最佳实践指南
- **educational_content**: 教育性内容
- **conceptual_explanation**: 概念解释

### 应用实践
- **qa_pair**: 问答对
- **problem_solution**: 问题-解决方案
- **performance_optimization**: 性能优化案例
- **technique_guide**: 技术指南

### 架构设计
- **architectural_pattern**: 架构模式
- **system_design**: 系统设计
- **infrastructure_guide**: 基础设施指南

### 模型相关
- **model_architecture**: 模型架构说明
- **model_variant**: 模型变体
- **training_methodology**: 训练方法论

### 其他
- **business_strategy**: 业务策略
- **methodology**: 方法论
- **learning_strategy**: 学习策略

## 📊 分类 (category) 枚举

```
machine_learning    - 机器学习
deep_learning       - 深度学习
nlp                 - 自然语言处理
computer_vision     - 计算机视觉
backend             - 后端开发
frontend            - 前端开发
devops              - DevOps
databases           - 数据库
algorithms          - 算法
data_structures     - 数据结构
distributed_systems - 分布式系统
system_design       - 系统设计
recommender_systems - 推荐系统
llm                 - 大语言模型
quantum_computing   - 量子计算
security            - 安全
analytics           - 数据分析
mlops               - ML运维
containers          - 容器化
...等等
```

## 🌍 复杂度等级 (complexity)

| 等级 | 说明 | 使用场景 |
|------|------|---------|
| **basic** | 基础概念，适合初学者 | 简单教程、基础知识 |
| **intermediate** | 中等难度，需要基础知识 | 实践指南、最佳实践 |
| **advanced** | 高级内容，需要专业知识 | 优化、深度特性 |
| **expert** | 专家级，最前沿技术 | 研究论文、突破性方法 |

## 🎯 使用场景

### 1. 模型预训练
```python
# 数据加载
with open('training_data_industrial_complete.jsonl', 'r') as f:
    for line in f:
        sample = json.loads(line)
        text = sample['text']
        # 将text送入模型预训练
        
# 按质量筛选
quality_threshold = 0.9
high_quality_samples = [
    sample for line in f
    if (sample := json.loads(line))['quality_score'] > quality_threshold
]
```

### 2. 微调任务
```python
# 按类型筛选特定任务的数据
qa_data = [
    sample for line in f
    if (sample := json.loads(line))['type'] == 'qa_pair'
]

code_data = [
    sample for line in f
    if (sample := json.loads(line))['type'] in ['code_example', 'code_snippet']
]
```

### 3. 课程设计
```python
# 按复杂度组织学习路径
for line in f:
    sample = json.loads(line)
    if sample['complexity'] == 'basic':
        # 初学者课程
    elif sample['complexity'] == 'intermediate':
        # 中级课程
    elif sample['complexity'] == 'advanced':
        # 高级课程
```

### 4. 数据集构建
```python
# 构建多语言数据集
zh_data = [s for line in f if (s:=json.loads(line))['language']=='zh']
en_data = [s for line in f if (s:=json.loads(line))['language']=='en']

# 构建特定领域数据集
nlp_data = [s for line in f if (s:=json.loads(line))['domain']=='nlp']
```

## 💾 数据处理最佳实践

### 1. 流式处理
```bash
# 逐行处理，节省内存
while IFS= read -r line; do
    # 处理每一行
done < data/training_data_industrial_complete.jsonl
```

### 2. 按字段索引
```bash
# 提取所有质量评分
grep -o '"quality_score":[0-9.]*' data/training_data_industrial_complete.jsonl

# 统计数据类型
grep -o '"type":"[^"]*"' data/training_data_industrial_complete.jsonl | cut -d'"' -f4 | sort | uniq -c
```

### 3. 数据分片
```bash
# 将数据分成10个分片用于分布式训练
split -l $(($(wc -l < data/training_data_industrial_complete.jsonl) / 10)) \
       data/training_data_industrial_complete.jsonl \
       data/shard-
```

## 🔍 质量指标说明

| 评分 | 质量等级 | 说明 |
|------|---------|------|
| 0.95-1.0 | 优秀 | 专业内容，准确无误 |
| 0.90-0.95 | 很好 | 高质量内容，小有瑕疵 |
| 0.85-0.90 | 良好 | 可用内容，需要审查 |
| 0.80-0.85 | 一般 | 基本可用，需要改进 |
| <0.80 | 低质量 | 建议排除或重新处理 |

## 📈 数据统计

当前数据集包含：
- **总样本数**: 21
- **平均质量分**: ~0.92
- **数据类型**: 21种
- **覆盖领域**: 12个
- **语言支持**: 中文、英文
- **平均token数**: 348

## 🚀 下一步

### 扩展数据集
- 在实际使用中，应该扩展至数百万条样本
- 保持数据类型和领域的多样性
- 定期审查并更新质量评分

### 持续优化
- 根据模型反馈调整质量评分
- 增加新的数据类型和领域
- 改进token计算准确度

### 集成训练流程
```bash
# 与make train命令集成
make train DATASET=industrial

# 使用特定质量阈值
QUALITY_THRESHOLD=0.90 make train
```

## 📝 许可和使用

这些训练数据用于内部模型开发和研究。
遵守所有适用的数据保护法规和许可协议。

---

**生成时间**: 2026-07-01  
**版本**: 1.0  
**维护者**: NeurX团队
