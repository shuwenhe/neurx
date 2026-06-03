# Anthropic Advanced Skills Features in NeurX

完整的 Anthropic 高级特性实现，提供成本优化、灵活推理、自主执行等功能。

## 📦 实现概览

### 核心功能模块

1. **Prompt Caching** - 缓存策略优化
2. **Adaptive Thinking** - 自适应思考深度
3. **Effort Control** - 工作量和 Token 预算
4. **Context Compaction** - 长对话压缩
5. **Tool Runner** - 自主工具执行循环
6. **File API** - 跨请求文件管理
7. **Batch Processing** - 批处理（50% 折扣）
8. **Managed Agents** - 服务器托管代理

### 文件结构

```
src/skills/
├── AnthropicSkillsTypes.h           # Anthropic 类型定义
├── AnthropicManagers.h              # 管理器接口
├── DefaultAnthropicManagers.h       # 具体实现声明
├── DefaultAnthropicManagers.cpp     # 具体实现
├── AnthropicSkillsExtension.h       # 主扩展类
├── AnthropicSkillsExtension.cpp     # 主扩展实现
└── ANTHROPIC_FEATURES.md            # 本文档
```

---

## 🚀 快速开始

### 1. 初始化扩展

```cpp
#include "skills/ClaudeSkillManager.h"
#include "skills/AnthropicSkillsExtension.h"

// 创建技能管理器
auto skillManager = std::make_unique<ClaudeSkillManager>();
skillManager->initialize("~/.hermes/skills");

// 添加 Anthropic 扩展
auto anthropic = std::make_unique<AnthropicSkillsExtension>(skillManager.get());
```

### 2. 启用单个特性

```cpp
// 启用缓存
anthropic->enablePromptCaching(true);

// 启用自适应思考
anthropic->enableAdaptiveThinking(true);

// 启用上下文压缩
anthropic->enableContextCompaction(true);

// 启用工具执行器
anthropic->enableToolRunner(true);
```

### 3. 配置参数

```cpp
// 设置工作量级别
anthropic->setEffortLevel(EffortLevel::High);

// 设置 Token 预算
anthropic->setTokenBudget(100000, 50000);  // 总预算, 单请求最大

// 设置压缩策略
anthropic->setCompactionStrategy(CompactionStrategy::MinQualityLoss);
```

---

## 💰 1. Prompt Caching (缓存优化)

### 什么是 Prompt Caching?

缓存系统提示和重复内容，减少 Token 消耗：
- **缓存写入**: 25% 的输入 Token 成本
- **缓存读取**: 10% 的输入 Token 成本
- **第一次使用**: 完整成本
- **后续使用**: 仅 10% 成本（节省 90%！）

### 使用示例

```cpp
// 启用缓存
anthropic->enablePromptCaching(true);

// 分析内容是否适合缓存
QString systemPrompt = "You are a helpful assistant...";  // ~5K tokens
float estimatedSavings;

if (anthropic->shouldCacheContent(systemPrompt, estimatedSavings)) {
    qDebug() << "Caching enabled - estimated savings:" << estimatedSavings << "tokens";
}

// 查看缓存统计
QVariantMap cacheStats = anthropic->getCacheStatistics();
qDebug() << "Cache hit rate:" << cacheStats["hitRate"];
```

### 成本计算

```
示例: 系统提示 5000 tokens，使用 10 次

无缓存: 5000 * 10 = 50,000 tokens

有缓存:
- 第 1 次: 5000 (完整) + 1250 (缓存写入) = 6,250
- 第 2-10 次: 500 (缓存读取) × 9 = 4,500
- 总计: 10,750 tokens

节省: 50,000 - 10,750 = 39,250 tokens (78% 节省！)
```

### 最佳实践

1. **缓存稳定内容**: 系统提示、文档、参考资料
2. **避免缓存动态内容**: 用户输入、实时数据
3. **批量操作**: 当需要多次使用相同的大型提示时效果最佳

---

## 🧠 2. Adaptive Thinking (自适应思考)

### 什么是 Adaptive Thinking?

Claude 在响应前进行思考，提高复杂任务的准确性：
- **Shallow**: ~5K tokens（简单任务）
- **Standard**: ~15K tokens（平衡）
- **Deep**: ~30K tokens（复杂分析）

### 使用示例

```cpp
// 启用自适应思考
anthropic->enableAdaptiveThinking(true);

// 自动评估任务复杂性
QString task = "Analyze and optimize this quantum algorithm...";
AdaptiveThinkingConfig config = anthropic->assessTask(task);

qDebug() << "Recommended thinking depth:" << static_cast<int>(config.budgetTokens);
qDebug() << "Max thinking tokens:" << config.maxThinkingTokens;

// 或者手动设置
anthropic->setThinkingDepth(ThinkingDepth::Deep);
```

### 复杂性评估

系统根据以下因素自动评估：

```cpp
// 关键词检测
"analyze", "design", "create"     // → Standard
"optimize", "architecture"         // → Deep
"simple", "quick"                 // → Shallow

// 内容长度
< 1000 chars → Shallow
< 2000 chars → Standard
> 2000 chars → Deep
```

### 成本/效益

```
简单问题: 问题 "什么是 Python?"
- Thinking: Shallow (5K tokens)
- 无 Thinking: 500 tokens
- 额外成本: 4.5K tokens（通常不值得）

复杂问题: "设计分布式系统架构"
- Thinking: Deep (30K tokens)  
- 更好的质量: 显著改进
- 值得额外成本 ✓
```

---

## ⚙️ 3. Effort Control (工作量控制)

### 工作量级别

| 级别 | Token 预算 | 用途 |
|------|----------|------|
| **Low** | ~1K | 快速响应、简单任务 |
| **Medium** | ~5K | 平衡质量和速度 |
| **High** | ~15K | 详细分析 |
| **Max** | ~30K | 全面研究 |
| **XHigh** | ~50K | 最大努力 |

### 使用示例

```cpp
// 设置工作量级别
anthropic->setEffortLevel(EffortLevel::High);

// 根据预算自动推荐
int availableTokens = 20000;
EffortLevel recommended = anthropic->getRecommendedEffort(
    "complex analysis",
    availableTokens
);

qDebug() << "Recommended effort:" << static_cast<int>(recommended);
```

### Token 预算管理

```cpp
// 设置预算
anthropic->setTokenBudget(100000, 50000);  // 总预算 100K, 单请求 50K

// 检查预算状态
BudgetStatus status = anthropic->getBudgetStatus();
qDebug() << "Used:" << status.used << "/ Total:" << status.totalBudget;
qDebug() << "Usage percent:" << status.usagePercent << "%";

// 检查是否超预算
if (anthropic->isBudgetExceeded()) {
    qWarning() << "Budget exceeded! Consider reducing effort level.";
}
```

---

## 📦 4. Context Compaction (上下文压缩)

### 什么是 Context Compaction?

长对话中，Claude 自动压缩早期消息，保留最新的对话：

### 压缩策略

```cpp
enum class CompactionStrategy {
    None,              // 不压缩
    Automatic,         // 自动（50% 压缩）
    MaxCompression,    // 最大压缩（70%）
    MinQualityLoss     // 最小质量损失（40%）
};
```

### 使用示例

```cpp
// 启用压缩
anthropic->enableContextCompaction(true);

// 设置策略
anthropic->setCompactionStrategy(CompactionStrategy::MinQualityLoss);

// 压缩长对话历史
QVector<QString> messages = /* 从某处获得消息 */;
CompactedContext compact = anthropic->compactHistory(messages);

qDebug() << "Original tokens:" << compact.originalTokens;
qDebug() << "Compacted tokens:" << compact.compactedTokens;
qDebug() << "Compression ratio:" << compact.compressionRatio;
```

### 压缩指标

```
原始: 500 条消息, 200K tokens
策略: MinQualityLoss (40% 压缩)

结果:
- 保留最后 20 条消息不压缩
- 压缩前 480 条为 60% 大小
- 新总大小: 20 条 * 400 + 480 * 0.6 * 400 = 123.2K tokens
- 节省: 76.8K tokens (38%)
```

---

## 🤖 5. Tool Runner (自主执行)

### 什么是 Tool Runner?

自主执行循环，让 Claude 自动调用工具、处理结果、循环迭代：

```
LLM 分析任务
    ↓
[决定] 需要哪些工具
    ↓
[执行] 工具 1, 2, 3（并行）
    ↓
[处理] 结果
    ↓
[决定] 是否需要更多工具
    ↓
循环或完成
```

### 注册工具

```cpp
// 启用工具执行器
anthropic->enableToolRunner(true);

// 定义工具
ToolDefinition searchTool;
searchTool.name = "web_search";
searchTool.description = "Search the web for information";
searchTool.category = "retrieve";
searchTool.maxCallsPerRequest = 5;

// 定义输入模式
QVariantMap schema;
schema["query"] = QVariantMap{{"type", "string"}, {"required", true}};
searchTool.inputSchema = schema;

// 注册工具
anthropic->registerTool(searchTool);
```

### 执行单个工具

```cpp
// 执行单个工具
QVariantMap params;
params["query"] = "latest AI developments";

ToolResult result = anthropic->executeTool("web_search", params);

if (result.success) {
    qDebug() << "Search results:" << result.result;
} else {
    qWarning() << "Tool failed:" << result.errorMessage;
}
```

### 运行完整的工具循环

```cpp
// 运行自主工具循环
anthropic->runAgentLoop(
    "Find information about Anthropic and analyze their recent products",
    [](const QVector<ToolResult> &results) {
        for (const auto &result : results) {
            qDebug() << "Tool:" << result.toolName;
            qDebug() << "Success:" << result.success;
            qDebug() << "Output:" << result.result;
        }
    }
);
```

### 工具性能指标

```cpp
QVariantMap metrics = anthropic->getToolMetrics();
qDebug() << "Total calls:" << metrics["totalToolCalls"];
qDebug() << "Failures:" << metrics["totalFailures"];
qDebug() << "Success rate:" << metrics["successRate"];
```

---

## 📄 6. File API (文件管理)

### 上传文件

```cpp
// 上传文件进行跨请求访问
QString fileId = anthropic->uploadFile(
    "/path/to/document.pdf",
    FileType::Document
);

qDebug() << "Uploaded as:" << fileId;
```

### 创建文件引用

```cpp
// 创建带缓存的文件引用
FileReference ref = anthropic->createFileReference(fileId);

// 用于 LLM 请求
// Claude 会缓存此文件以供后续请求使用
```

### 管理文件

```cpp
// 列出所有上传的文件
QVector<FileMetadata> files = anthropic->listUploadedFiles();

for (const auto &file : files) {
    qDebug() << "File:" << file.fileName;
    qDebug() << "Size:" << file.fileSizeBytes << "bytes";
    qDebug() << "Uploaded:" << file.uploadedAt.toString();
}

// 获取存储统计
QVariantMap stats = anthropic->getFileStorageStats();
qDebug() << "Total files:" << stats["totalFiles"];
qDebug() << "Storage used:" << stats["totalStorageMB"] << "MB";
```

---

## 🚀 7. Batch Processing (批处理)

### 为什么使用批处理?

- **50% 成本折扣**: 批量请求享受 50% 的 Token 价格折扣
- **异步处理**: 离线处理，不需要立即响应
- **规模化**: 处理数千个请求

### 创建批处理作业

```cpp
// 启用批处理
anthropic->enableBatchProcessing(true);

// 创建多个请求
QVector<AnthropicSkillRequest> requests;

for (int i = 0; i < 100; ++i) {
    AnthropicSkillRequest req;
    req.skillId = "analysis";
    req.userInput = QString("Analyze data %1").arg(i);
    requests.append(req);
}

// 创建批处理作业
BatchJob job = anthropic->createBatch(requests);

qDebug() << "Batch created with" << job.requests.count() << "requests";
```

### 提交和跟踪

```cpp
// 提交批处理
QString batchId = anthropic->submitBatch(job);

qDebug() << "Submitted batch:" << batchId;

// 稍后检查状态
QString status = anthropic->getBatchStatus(batchId);
qDebug() << "Status:" << status;  // "processing", "completed", "failed"

// 计算成本节省
float savings = anthropic->calculateBatchSavings(100000);  // 100K tokens
qDebug() << "Cost savings:" << savings << "tokens (50% discount)";
```

### 检索结果

```cpp
// 等待批处理完成后，检索结果
anthropic->retrieveBatchResults(batchId, 
    [](const BatchJob &job) {
        qDebug() << "Processed:" << job.processedRequests;
        qDebug() << "Failed:" << job.failedRequests;
        
        // 访问结果 URL
        qDebug() << "Results at:" << job.resultUrl;
    }
);
```

---

## 🤖 8. Managed Agents (托管代理)

### 什么是 Managed Agents?

Anthropic 托管的有状态代理，可以跨多个请求维持状态：

### 创建代理

```cpp
// 定义代理配置
ManagedAgentConfig config;
config.agentId = "analysis-agent";
config.agentName = "Data Analysis Agent";
config.instructions = "You are a data analysis expert...";
config.modelId = "claude-opus-4-8";
config.persistent = true;  // 保留状态

// 添加资源
ManagedAgentResource resource;
resource.type = AgentResourceType::FileStorage;
resource.resourceName = "analysis-data";
config.resources.append(resource);

// 创建代理
QString agentId = anthropic->createManagedAgent(config);
qDebug() << "Agent created:" << agentId;
```

### 与代理通信

```cpp
// 发送消息
anthropic->sendAgentMessage(
    agentId,
    "Analyze the uploaded sales data and provide insights",
    [](bool success, const QString &response) {
        if (success) {
            qDebug() << "Agent response:" << response;
        } else {
            qWarning() << "Agent error:" << response;
        }
    }
);
```

### 管理代理状态

```cpp
// 获取代理状态
QVariantMap state = anthropic->getAgentState(agentId);
qDebug() << "Current state:" << state;

// 添加资源
ManagedAgentResource dbResource;
dbResource.type = AgentResourceType::DatabaseAccess;
dbResource.resourceName = "production-db";

anthropic->addAgentResource(agentId, dbResource);

// 删除代理
anthropic->deleteAgent(agentId);
```

---

## 🔗 9. 集成请求执行

### 完整示例：组合使用所有功能

```cpp
// 准备请求，启用所有 Anthropic 功能
AnthropicSkillRequest request;
request.skillId = "complex-analysis";
request.userInput = "Analyze quarterly earnings report";

// 启用缓存
request.usePromptCaching = true;
request.cacheConfig.type = CacheControlType::StandardCache;

// 启用自适应思考
request.thinking.enabled = true;
request.thinking.budgetTokens = ThinkingDepth::Deep;

// 设置工作量
request.effort.level = EffortLevel::High;

// 启用压缩
request.compaction.strategy = CompactionStrategy::MinQualityLoss;

// 设置预算
request.budget.totalTokenBudget = 100000;
request.budget.maxTokensPerRequest = 50000;

// 执行带所有功能的请求
anthropic->executeWithAnthropicFeatures(
    request,
    [anthropic](bool success, const QVariantMap &result) {
        if (success) {
            qDebug() << "Execution successful";
            
            // 检查应用的功能
            qDebug() << "Caching applied:" << result["cachingApplied"];
            qDebug() << "Thinking applied:" << result["thinkingApplied"];
            qDebug() << "Effort level:" << result["effortLevel"];
        }
    }
);
```

---

## 📊 10. 监控和统计

### 获取特性状态

```cpp
QVariantMap features = anthropic->getFeatureStatus();

qDebug() << "Caching enabled:" << features["cachingEnabled"];
qDebug() << "Thinking enabled:" << features["thinkingEnabled"];
qDebug() << "Compaction enabled:" << features["compactionEnabled"];
qDebug() << "Tool runner enabled:" << features["toolRunnerEnabled"];
```

### 获取综合统计

```cpp
QVariantMap stats = anthropic->getComprehensiveStats();

// 特性状态
qDebug() << "Features:" << stats["features"];

// 缓存统计
qDebug() << "Cache hits:" << stats["cache"]["totalHits"];

// 预算状态
QVariantMap budget = stats["budget"].toMap();
qDebug() << "Budget usage:" << budget["spent"] << "/" << budget["total"];

// 压缩指标
qDebug() << "Compression ratio:" << stats["compression"]["avgCompressionRatio"];

// 工具执行
qDebug() << "Tool calls:" << stats["tools"]["totalToolCalls"];

// 存储
qDebug() << "Files stored:" << stats["storage"]["totalFiles"];
```

---

## 💡 最佳实践

### 1. 成本优化
```cpp
// 对频繁使用的系统提示启用缓存
anthropic->enablePromptCaching(true);

// 对大批量请求使用批处理（50% 折扣）
anthropic->enableBatchProcessing(true);

// 对长对话启用压缩
anthropic->enableContextCompaction(true);
```

### 2. 质量优化
```cpp
// 对复杂任务启用自适应思考
anthropic->enableAdaptiveThinking(true);

// 设置合适的工作量级别
anthropic->setEffortLevel(EffortLevel::High);

// 对分析使用非损质量压缩
anthropic->setCompactionStrategy(CompactionStrategy::MinQualityLoss);
```

### 3. 自主执行
```cpp
// 对需要多步骤的任务启用工具执行器
anthropic->enableToolRunner(true);

// 注册所有必需的工具
for (const auto &tool : availableTools) {
    anthropic->registerTool(tool);
}

// 让 Claude 自主决定工具使用
anthropic->runAgentLoop(query, callback);
```

### 4. 监控
```cpp
// 定期检查统计信息
QVariantMap stats = anthropic->getComprehensiveStats();

// 监控预算
if (anthropic->isBudgetExceeded()) {
    qWarning() << "Budget exceeded - reducing effort level";
    anthropic->setEffortLevel(EffortLevel::Medium);
}
```

---

## 🔧 Configuration 合并

### 在 CMakeLists.txt 中添加源文件

```cmake
add_library(neurx_core STATIC
    # ... existing files ...
    
    # Anthropic Skills
    src/skills/DefaultAnthropicManagers.cpp
    src/skills/AnthropicSkillsExtension.cpp
)
```

---

## 📚 参考资源

- 官方文档: https://docs.anthropic.com
- Claude API: https://console.anthropic.com
- Token 定价: https://www.anthropic.com/pricing
- Prompt Caching: https://docs.anthropic.com/en/docs/build-a-bot/prompts
- Tool Use: https://docs.anthropic.com/en/docs/build-a-bot/tool-use
- Managed Agents: https://docs.anthropic.com/en/docs/agents

---

## 🎓 完整示例

见本目录下的 `ANTHROPIC_EXAMPLES.md` 文件。
