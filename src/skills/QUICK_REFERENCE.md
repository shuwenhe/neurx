# Anthropic Skills API 快速参考

一页纸速查表，用于快速查找常用功能。

## 初始化

```cpp
auto anthropic = std::make_unique<AnthropicSkillsExtension>(skillManager.get());
```

---

## 缓存 (Prompt Caching)

```cpp
// 启用
anthropic->enablePromptCaching(true);

// 检查是否适合缓存
float savings;
bool shouldCache = anthropic->shouldCacheContent(content, savings);

// 统计
QVariantMap stats = anthropic->getCacheStatistics();
// → {"totalHits": 5, "totalMisses": 2, "hitRate": 0.714}
```

**成本**: 缓存写入 25% + 读取 10%
**最佳用途**: 系统提示、大型文档、重复场景
**节省**: 第 2+ 次使用时 50-90%

---

## 自适应思考 (Adaptive Thinking)

```cpp
// 启用
anthropic->enableAdaptiveThinking(true);

// 设置深度
anthropic->setThinkingDepth(ThinkingDepth::Deep);

// 自动评估
AdaptiveThinkingConfig cfg = anthropic->assessTask("复杂任务");

// 指标
QVariantMap metrics = anthropic->getThinkingMetrics();
```

**深度选项**:
- `Shallow`: 5K tokens (简单)
- `Standard`: 15K tokens (平衡)
- `Deep`: 30K tokens (复杂)
- `Auto`: 自动选择

**成本**: 额外 5-30K tokens
**最佳用途**: 复杂分析、设计、代码审查
**收益**: 准确性 +30-50%

---

## 工作量控制 (Effort Control)

```cpp
// 设置级别
anthropic->setEffortLevel(EffortLevel::High);

// 设置预算
anthropic->setTokenBudget(100000, 50000);  // 总, 单请求

// 检查状态
BudgetStatus status = anthropic->getBudgetStatus();
// → {total: 100000, used: 45000, remaining: 55000, usagePercent: 45}

// 检查是否超额
if (anthropic->isBudgetExceeded()) { /* 处理 */ }
```

**级别**:
- `Low`: 1K tokens
- `Medium`: 5K tokens
- `High`: 15K tokens
- `Max`: 30K tokens
- `XHigh`: 50K tokens

---

## 上下文压缩 (Context Compaction)

```cpp
// 启用
anthropic->enableContextCompaction(true);

// 设置策略
anthropic->setCompactionStrategy(CompactionStrategy::MinQualityLoss);

// 压缩
CompactedContext result = anthropic->compactHistory(messages);
// → {originalTokens: 200000, compactedTokens: 100000, ratio: 0.5}

// 指标
QVariantMap metrics = anthropic->getCompressionMetrics();
```

**策略**:
- `MaxCompression`: 70% 压缩
- `MinQualityLoss`: 40% 压缩 (推荐)
- `Automatic`: 50% 压缩

**最佳用途**: 长对话 (500+ 消息)
**节省**: 30-70%

---

## 工具执行 (Tool Runner)

```cpp
// 启用
anthropic->enableToolRunner(true);

// 注册工具
ToolDefinition tool;
tool.name = "search";
tool.description = "Search the web";
anthropic->registerTool(tool);

// 执行单个
ToolResult result = anthropic->executeTool("search", params);

// 运行循环 (自主)
anthropic->runAgentLoop(query, [](const QVector<ToolResult> &results) {
    for (const auto &r : results) { /* 处理结果 */ }
});

// 指标
QVariantMap metrics = anthropic->getToolMetrics();
// → {totalToolCalls: 15, totalFailures: 1, successRate: 0.933}
```

---

## 文件 API (File API)

```cpp
// 上传
QString fileId = anthropic->uploadFile("/path/file.pdf", FileType::Document);

// 创建引用
FileReference ref = anthropic->createFileReference(fileId);

// 列表
QVector<FileMetadata> files = anthropic->listUploadedFiles();

// 存储统计
QVariantMap stats = anthropic->getFileStorageStats();
// → {totalFiles: 5, totalStorageBytes: 10485760, totalStorageMB: 10}
```

---

## 批处理 (Batch Processing)

```cpp
// 启用
anthropic->enableBatchProcessing(true);

// 创建
BatchJob job = anthropic->createBatch(requests);

// 提交
QString batchId = anthropic->submitBatch(job);

// 状态
QString status = anthropic->getBatchStatus(batchId);

// 成本节省
float savings = anthropic->calculateBatchSavings(100000);  // 50K tokens (50%)

// 结果
anthropic->retrieveBatchResults(batchId, [](const BatchJob &job) {
    qDebug() << "Processed:" << job.processedRequests;
});
```

**成本**: 50% 折扣
**适合**: 大批量 (100+) 离线任务
**延迟**: 5-30 分钟

---

## 托管代理 (Managed Agents)

```cpp
// 创建
ManagedAgentConfig cfg;
cfg.agentId = "assistant";
cfg.instructions = "You are...";
QString agentId = anthropic->createManagedAgent(cfg);

// 发送消息
anthropic->sendAgentMessage(agentId, "Do something", 
    [](bool success, const QString &response) {
        if (success) { /* 处理响应 */ }
    }
);

// 状态
QVariantMap state = anthropic->getAgentState(agentId);

// 删除
anthropic->deleteAgent(agentId);
```

---

## 配置预设

### 成本优先
```cpp
anthropic->enablePromptCaching(true);
anthropic->enableContextCompaction(true);
anthropic->setCompactionStrategy(CompactionStrategy::MaxCompression);
anthropic->setEffortLevel(EffortLevel::Low);
anthropic->enableBatchProcessing(true);
```

### 质量优先
```cpp
anthropic->enableAdaptiveThinking(true);
anthropic->setEffortLevel(EffortLevel::High);
anthropic->setThinkingDepth(ThinkingDepth::Deep);
anthropic->setCompactionStrategy(CompactionStrategy::MinQualityLoss);
```

### 平衡
```cpp
anthropic->enablePromptCaching(true);
anthropic->enableAdaptiveThinking(true);
anthropic->setEffortLevel(EffortLevel::Medium);
anthropic->enableContextCompaction(true);
```

### 自主研究
```cpp
anthropic->enableToolRunner(true);
anthropic->enableAdaptiveThinking(true);
anthropic->setEffortLevel(EffortLevel::High);
// 注册所有工具...
```

---

## 监控

```cpp
// 功能状态
QVariantMap features = anthropic->getFeatureStatus();

// 完整统计
QVariantMap stats = anthropic->getComprehensiveStats();
// → {
//      features: {...},
//      cache: {totalHits: 5, hitRate: 0.71},
//      thinking: {totalThinkingTokens: 15000},
//      budget: {total: 100K, spent: 45K, remaining: 55K},
//      compression: {compressionCount: 2, ratio: 0.5},
//      tools: {totalCalls: 10, successRate: 0.95},
//      storage: {totalFiles: 3, totalStorageMB: 5}
//    }
```

---

## 完整请求示例

```cpp
AnthropicSkillRequest request;
request.skillId = "analysis";
request.userInput = "Analyze this data";

// 缓存
request.usePromptCaching = true;
request.cacheConfig.type = CacheControlType::StandardCache;

// 思考
request.thinking.enabled = true;
request.thinking.budgetTokens = ThinkingDepth::Deep;

// 工作量
request.effort.level = EffortLevel::High;

// 压缩
request.compaction.strategy = CompactionStrategy::MinQualityLoss;

// 预算
request.budget.totalTokenBudget = 100000;
request.budget.maxTokensPerRequest = 50000;

// 执行
anthropic->executeWithAnthropicFeatures(request, 
    [](bool success, const QVariantMap &result) {
        if (success) {
            qDebug() << "Done - caching:" << result["cachingApplied"];
        }
    }
);
```

---

## 成本对比

| 操作 | 无优化 | 有优化 | 节省 |
|------|------|--------|------|
| 1000 条消息 | 100K | 35K | 65% |
| 100 重复请求 | 500K | 250K | 50% |
| 深度分析 | 20K | 50K | -150% |
| 批处理 1000 | 500K | 250K | 50% |

---

## 错误处理

```cpp
// 检查预算
if (anthropic->isBudgetExceeded()) {
    // 降级到更低的工作量
    anthropic->setEffortLevel(EffortLevel::Low);
}

// 检查工具
auto metrics = anthropic->getToolMetrics();
if (metrics["successRate"].toFloat() < 0.9) {
    qWarning() << "Tool reliability issue";
}

// 检查缓存
auto cache = anthropic->getCacheStatistics();
if (cache["hitRate"].toFloat() == 0) {
    qWarning() << "Cache ineffective";
}
```

---

## 快速链接

- 完整文档: [ANTHROPIC_FEATURES.md](ANTHROPIC_FEATURES.md)
- 代码示例: [ANTHROPIC_EXAMPLES.md](ANTHROPIC_EXAMPLES.md)
- 集成指南: [INTEGRATION.md](INTEGRATION.md)
- Claude Skills: [CLAUDE_SKILLS_SYSTEM.md](../../../hermes-agent/docs/CLAUDE_SKILLS_SYSTEM.md)

---

## 常见问题

**Q: 如何减少成本?**
A: 启用缓存、压缩、批处理。查看成本优先预设。

**Q: 如何提高质量?**
A: 启用自适应思考和高工作量。查看质量优先预设。

**Q: 多少 token 预算够用?**
A: 简单应用: 10K/天, 中等: 100K/天, 复杂: 1M/天

**Q: 批处理需要多长时间?**
A: 通常 5-30 分钟，取决于批大小和当前队列

**Q: 能否同时使用多个特性?**
A: 是的！组合使用会有最佳效果。查看"平衡"预设。

---

## 版本

v1.0.0 - 2024-01
