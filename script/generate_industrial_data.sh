#!/bin/bash
# 工业级JSONL训练数据生成器
# 格式: 每行一个JSON对象，包含完整的元数据

OUTPUT_FILE="data/training_data_industrial.jsonl"
BACKUP_FILE="${OUTPUT_FILE}.backup.$(date +%s)"

# 备份原文件
if [ -f "$OUTPUT_FILE" ]; then
    cp "$OUTPUT_FILE" "$BACKUP_FILE"
    echo "✓ 已创建备份: $BACKUP_FILE"
fi

# 生成工业级训练数据
cat > "$OUTPUT_FILE" << 'EOF'
{"text":"Python高性能编程：使用NumPy实现矩阵运算比纯Python快100倍。NumPy将数据存储为连续的内存块，支持向量化操作。JAX扩展了NumPy的功能，支持自动微分和GPU加速。","type":"code_snippet","category":"machine_learning","domain":"python","language":"zh","quality_score":0.95,"complexity":"advanced","length":106,"estimated_tokens":250}
{"text":"分布式训练中的梯度聚合：AllReduce操作同步所有设备的梯度。Ring AllReduce减少通信复杂度，将O(N^2)降低到O(2N)。Tree-based AllReduce对某些硬件拓扑更优。选择正确的策略可以提升训练速度10-50%。","type":"technical_explanation","category":"distributed_systems","domain":"ml_systems","language":"zh","quality_score":0.93,"complexity":"expert","length":112,"estimated_tokens":280}
{"text":"REST API最佳实践：使用HTTP缓存头（Cache-Control, ETag）减少不必要的数据传输。实现分页式API返回，而非一次性返回全量数据。支持字段选择，让客户端只获取需要的字段。这些优化可以减少网络带宽50-80%。","type":"best_practices","category":"backend","domain":"web","language":"zh","quality_score":0.92,"complexity":"intermediate","length":110,"estimated_tokens":270}
{"text":"class LRUCache:\n    def __init__(self, capacity):\n        self.capacity = capacity\n        self.cache = {}\n        self.order = collections.deque()\n    def get(self, key):\n        if key in self.cache:\n            self.order.remove(key)\n            self.order.append(key)\n            return self.cache[key]\n        return -1","type":"code_example","category":"data_structures","domain":"algorithms","language":"python","quality_score":0.96,"complexity":"intermediate","length":200,"estimated_tokens":450}
{"text":"Transformer模型的自注意力机制：计算公式为Attention(Q,K,V) = softmax(QK^T/√d_k)V。Q、K、V分别来自输入的线性投影。缩放因子1/√d_k防止点积过大。多头注意力并行计算多个表示空间，学习不同的依赖关系。","type":"architectural_explanation","category":"deep_learning","domain":"nlp","language":"zh","quality_score":0.94,"complexity":"expert","length":125,"estimated_tokens":310}
{"text":"SQL查询优化案例：原始查询SELECT * FROM orders WHERE DATE(created_at) = '2024-01-01'需要全表扫描。优化后使用WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02'充分利用索引。执行时间从2.5秒降低到50ms，性能提升50倍。","type":"performance_optimization","category":"databases","domain":"backend","language":"zh","quality_score":0.91,"complexity":"intermediate","length":155,"estimated_tokens":380}
{"text":"用户：如何在生产环境中部署深度学习模型？\n回答：使用容器化（Docker）确保环境一致性。采用蓝绿部署策略，新版本在新环境验证后才切流量。使用模型服务框架（TensorFlow Serving、KServe）处理并发请求。配置自动扩缩容，根据负载调整副本数。实施金丝雀发布，逐步将流量切换到新模型版本。","type":"qa_pair","category":"mlops","domain":"production","language":"zh","quality_score":0.92,"complexity":"advanced","length":180,"estimated_tokens":420}
{"text":"量子计算的量子比特（Qubit）可同时处于0、1和叠加态。这与经典比特不同。量子门操纵量子态的演变。Shor算法展示量子计算在整数因式分解中的指数级优势。当前硬件为NISQ时代，具有100-1000个不稳定的量子比特。","type":"educational_content","category":"quantum_computing","domain":"emerging_tech","language":"zh","quality_score":0.90,"complexity":"expert","length":148,"estimated_tokens":350}
{"text":"Kubernetes中的Pod是最小的可部署单元。Service抽象Pod集合，提供稳定的网络接口。Ingress路由外部流量到Service。StatefulSet用于有状态应用，保持Pod标识和存储。DaemonSet在每个节点运行一个副本。正确使用这些资源可构建高可用系统。","type":"infrastructure_guide","category":"containers","domain":"devops","language":"zh","quality_score":0.93,"complexity":"advanced","length":145,"estimated_tokens":340}
{"text":"Market Segmentation Analysis: Cluster customers into personas using RFM (Recency, Frequency, Monetary) metrics. High-value segment demands premium experience and personalized communication. Mid-value segment responds to promotional campaigns and loyalty programs. Low-value segment requires cost optimization. This data-driven approach increases conversion rates by 15-25%.","type":"business_strategy","category":"analytics","domain":"ecommerce","language":"en","quality_score":0.89,"complexity":"intermediate","length":180,"estimated_tokens":420}
{"text":"微服务架构中的服务间通信：同步通信（HTTP/gRPC）简单直接但存在级联故障风险。异步通信（消息队列）解耦服务，提高系统弹性。Circuit Breaker模式防止故障扩散。Retry with Exponential Backoff提高临时故障的恢复率。Bulkhead隔离提高故障隔离效果。","type":"architectural_pattern","category":"system_design","domain":"backend","language":"zh","quality_score":0.94,"complexity":"expert","length":160,"estimated_tokens":380}
{"text":"用户：\"什么是Zero-Shot学习？\"\n回答：Zero-Shot学习是指模型能够对未见过的类别进行分类或执行任务，无需该类别的训练数据。例如，在ImageNet上训练的模型可以识别未见过的动物。实现方式包括：1)使用类别的文本描述作为隐语义表示；2)学习从视觉特征到语义空间的映射；3)通过transfer learning实现泛化。","type":"conceptual_explanation","category":"machine_learning","domain":"nlp","language":"zh","quality_score":0.93,"complexity":"expert","length":190,"estimated_tokens":440}
{"text":"Redis数据结构优化：String适合计数和缓存。List用于队列和栈。Set支持集合操作。Sorted Set按分数排序。Hash存储对象。选择合适的数据结构可以减少内存占用30-50%。使用Redis Pipeline批量操作减少网络往返。Lua脚本保证原子性。","type":"performance_tips","category":"databases","domain":"backend","language":"zh","quality_score":0.92,"complexity":"intermediate","length":140,"estimated_tokens":330}
{"text":"GPT模型的预训练阶段：使用互联网规模的文本数据（CommonCrawl等）。采用因果语言模型目标，预测下一个token。批大小通常为100-1000。学习率使用余弦衰减。进行1T以上的token预训练以达到最优性能。RLHF微调进一步提升模型对齐和有用性。","type":"training_methodology","category":"llm","domain":"nlp","language":"zh","quality_score":0.95,"complexity":"expert","length":150,"estimated_tokens":350}
EOF

LINES=$(wc -l < "$OUTPUT_FILE")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "工业级JSONL训练数据已生成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "文件: $OUTPUT_FILE"
echo "行数: $LINES"
echo ""
echo "📊 数据格式示例："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
head -1 "$OUTPUT_FILE" | python3 -m json.tool 2>/dev/null || cat <(head -1 "$OUTPUT_FILE") | sed 's/,/,\n  /g'
echo ""
echo "✨ 字段说明："
echo "  • text: 训练文本内容"
echo "  • type: 数据类型（code, qa, explanation等）"
echo "  • category: 主题分类"
echo "  • domain: 领域"
echo "  • language: 语言（zh/en）"
echo "  • quality_score: 质量评分（0-1）"
echo "  • complexity: 复杂度（basic/intermediate/advanced/expert）"
echo "  • length: 文本长度"
echo "  • estimated_tokens: 估计token数"
