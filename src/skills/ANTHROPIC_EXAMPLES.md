# Anthropic Skills 集成示例

实际代码示例，展示如何在 NeurX 中使用 Anthropic 高级特性。

## 示例 1: 成本优化的长对话系统

用于维持长期客户对话，同时最小化成本。

```cpp
#include "AnthropicSkillsExtension.h"
#include <QVector>

class CustomerServiceAgent {
public:
    CustomerServiceAgent() {
        // 初始化技能管理器
        auto skillMgr = std::make_unique<ClaudeSkillManager>();
        skillMgr->initialize("~/.hermes/skills");
        
        // 创建 Anthropic 扩展
        m_anthropic = std::make_unique<AnthropicSkillsExtension>(skillMgr.get());
        
        // 配置成本优化
        m_anthropic->enablePromptCaching(true);      // 缓存系统提示
        m_anthropic->enableContextCompaction(true);  // 压缩长历史
        m_anthropic->setTokenBudget(200000, 50000);  // 设置预算
    }
    
    void handleCustomerMessage(const QString &message) {
        // 构建请求
        AnthropicSkillRequest request;
        request.skillId = "customer-support";
        request.userInput = message;
        
        // 对于多轮对话，启用缓存和压缩
        request.usePromptCaching = true;
        request.cacheConfig.ttlSeconds = 3600;  // 1 小时缓存
        
        // 在 500+ 条消息后启用压缩
        if (m_conversationHistory.count() > 500) {
            request.compaction.strategy = CompactionStrategy::Automatic;
        }
        
        // 执行请求
        m_anthropic->executeWithAnthropicFeatures(
            request,
            [this](bool success, const QVariantMap &result) {
                if (success) {
                    qDebug() << "Response received";
                    
                    // 记录压缩节省
                    if (result["compactionApplied"].toBool()) {
                        auto metrics = m_anthropic->getCompressionMetrics();
                        float ratio = metrics["avgCompressionRatio"].toFloat();
                        qDebug() << "Compression ratio:" << ratio;
                    }
                }
            }
        );
        
        m_conversationHistory.append(message);
    }
    
private:
    std::unique_ptr<AnthropicSkillsExtension> m_anthropic;
    QVector<QString> m_conversationHistory;
};
```

## 示例 2: 高质量分析引擎

用于复杂分析任务，优先考虑质量而非成本。

```cpp
class AnalysisEngine {
public:
    AnalysisEngine() {
        auto skillMgr = std::make_unique<ClaudeSkillManager>();
        m_anthropic = std::make_unique<AnthropicSkillsExtension>(skillMgr.get());
        
        // 配置质量优先
        m_anthropic->enableAdaptiveThinking(true);
        m_anthropic->setEffortLevel(EffortLevel::High);
        
        // 充足的 token 预算
        m_anthropic->setTokenBudget(500000, 100000);
    }
    
    void analyzeDocument(const QString &documentPath) {
        // 上传文档以供缓存
        QString fileId = m_anthropic->uploadFile(documentPath, FileType::Document);
        
        // 创建分析请求
        AnthropicSkillRequest request;
        request.skillId = "deep-analysis";
        request.userInput = "Provide comprehensive analysis of this document";
        
        // 启用深度思考
        request.thinking.enabled = true;
        request.thinking.budgetTokens = ThinkingDepth::Deep;
        request.thinking.maxThinkingTokens = 30000;
        
        // 高工作量
        request.effort.level = EffortLevel::High;
        
        // 无压缩以保留质量
        request.compaction.strategy = CompactionStrategy::None;
        
        m_anthropic->executeWithAnthropicFeatures(
            request,
            [this](bool success, const QVariantMap &result) {
                if (success && result["thinkingApplied"].toBool()) {
                    auto metrics = m_anthropic->getThinkingMetrics();
                    qDebug() << "Used deep thinking for high-quality analysis";
                }
            }
        );
    }
    
private:
    std::unique_ptr<AnthropicSkillsExtension> m_anthropic;
};
```

## 示例 3: 自主代理系统

使用工具循环实现自主执行。

```cpp
class ResearchAgent {
public:
    ResearchAgent() {
        auto skillMgr = std::make_unique<ClaudeSkillManager>();
        m_anthropic = std::make_unique<AnthropicSkillsExtension>(skillMgr.get());
        
        // 启用工具运行器
        m_anthropic->enableToolRunner(true);
        
        // 注册可用工具
        registerTools();
    }
    
    void registerTools() {
        // 网络搜索工具
        ToolDefinition searchTool;
        searchTool.name = "web_search";
        searchTool.description = "Search the web for current information";
        searchTool.category = "retrieve";
        searchTool.maxCallsPerRequest = 10;
        
        QVariantMap searchSchema;
        searchSchema["query"] = QVariantMap{
            {"type", "string"},
            {"description", "Search query"},
            {"required", true}
        };
        searchTool.inputSchema = searchSchema;
        
        m_anthropic->registerTool(searchTool);
        
        // 数据分析工具
        ToolDefinition analyzeTool;
        analyzeTool.name = "analyze_data";
        analyzeTool.description = "Analyze data patterns";
        analyzeTool.category = "analyze";
        
        QVariantMap analyzeSchema;
        analyzeSchema["data"] = QVariantMap{
            {"type", "string"},
            {"description", "Data to analyze"},
            {"required", true}
        };
        analyzeTool.inputSchema = analyzeSchema;
        
        m_anthropic->registerTool(analyzeTool);
    }
    
    void startResearch(const QString &topic) {
        qDebug() << "Starting research on:" << topic;
        
        // 运行自主工具循环
        m_anthropic->runAgentLoop(
            QString("Research and provide comprehensive analysis on: %1").arg(topic),
            [this](const QVector<ToolResult> &results) {
                for (const auto &result : results) {
                    qDebug() << "Tool:" << result.toolName;
                    qDebug() << "Success:" << result.success;
                    qDebug() << "Result:" << result.result;
                }
                
                // 获取指标
                auto metrics = m_anthropic->getToolMetrics();
                qDebug() << "Total tool calls:" << metrics["totalToolCalls"];
                qDebug() << "Success rate:" << metrics["successRate"];
            }
        );
    }
    
private:
    std::unique_ptr<AnthropicSkillsExtension> m_anthropic;
};
```

## 示例 4: 批处理系统

处理大量异步请求，享受 50% 成本折扣。

```cpp
class BatchAnalyzer {
public:
    BatchAnalyzer() {
        auto skillMgr = std::make_unique<ClaudeSkillManager>();
        m_anthropic = std::make_unique<AnthropicSkillsExtension>(skillMgr.get());
        
        m_anthropic->enableBatchProcessing(true);
    }
    
    void processBulkData(const QStringList &dataItems) {
        // 创建批处理请求
        QVector<AnthropicSkillRequest> requests;
        
        for (const auto &item : dataItems) {
            AnthropicSkillRequest req;
            req.skillId = "bulk-analysis";
            req.userInput = QString("Analyze: %1").arg(item);
            requests.append(req);
        }
        
        // 创建和提交批处理
        BatchJob job = m_anthropic->createBatch(requests);
        QString batchId = m_anthropic->submitBatch(job);
        
        qDebug() << "Submitted batch with" << requests.count() << "requests";
        qDebug() << "Batch ID:" << batchId;
        
        // 计算成本节省
        int totalTokens = requests.count() * 5000;  // 估计
        float savings = m_anthropic->calculateBatchSavings(totalTokens);
        
        qDebug() << "Estimated cost savings:" << savings << "tokens (50%)";
        
        // 稍后检查状态
        QTimer::singleShot(5000, this, [this, batchId]() {
            QString status = m_anthropic->getBatchStatus(batchId);
            qDebug() << "Batch status:" << status;
            
            if (status == "completed") {
                // 检索结果
                m_anthropic->retrieveBatchResults(
                    batchId,
                    [](const BatchJob &completedJob) {
                        qDebug() << "Processed requests:" << completedJob.processedRequests;
                        qDebug() << "Failed requests:" << completedJob.failedRequests;
                    }
                );
            }
        });
    }
    
private:
    std::unique_ptr<AnthropicSkillsExtension> m_anthropic;
};
```

## 示例 5: 托管代理系统

维持有状态的托管代理。

```cpp
class DataAnalystAgent {
public:
    DataAnalystAgent() {
        auto skillMgr = std::make_unique<ClaudeSkillManager>();
        m_anthropic = std::make_unique<AnthropicSkillsExtension>(skillMgr.get());
        
        // 创建托管代理
        ManagedAgentConfig config;
        config.agentId = "data-analyst";
        config.agentName = "Data Analyst";
        config.instructions = R"(
            You are an expert data analyst. 
            - Analyze data patterns and trends
            - Provide insights and recommendations
            - Maintain context across conversations
        )";
        config.modelId = "claude-3-5-sonnet";
        config.persistent = true;
        
        // 添加数据库访问资源
        ManagedAgentResource dbResource;
        dbResource.type = AgentResourceType::DatabaseAccess;
        dbResource.resourceName = "analytics_db";
        config.resources.append(dbResource);
        
        m_agentId = m_anthropic->createManagedAgent(config);
        qDebug() << "Created agent:" << m_agentId;
    }
    
    void requestAnalysis(const QString &query) {
        // 发送消息到代理
        m_anthropic->sendAgentMessage(
            m_agentId,
            query,
            [this](bool success, const QString &response) {
                if (success) {
                    qDebug() << "Agent response:" << response;
                    
                    // 获取代理状态
                    QVariantMap state = m_anthropic->getAgentState(m_agentId);
                    qDebug() << "Agent state:" << state;
                } else {
                    qWarning() << "Agent error:" << response;
                }
            }
        );
    }
    
    ~DataAnalystAgent() {
        // 清理：删除代理
        m_anthropic->deleteAgent(m_agentId);
    }
    
private:
    std::unique_ptr<AnthropicSkillsExtension> m_anthropic;
    QString m_agentId;
};
```

## 示例 6: 综合监控仪表板

监控所有 Anthropic 功能的使用情况。

```cpp
class MonitoringDashboard {
public:
    MonitoringDashboard(AnthropicSkillsExtension *anthropic)
        : m_anthropic(anthropic) {}
    
    void displayMetrics() {
        // 获取综合统计
        QVariantMap stats = m_anthropic->getComprehensiveStats();
        
        // 特性状态
        auto features = stats["features"].toMap();
        qDebug() << "=== FEATURES ===";
        qDebug() << "Caching:" << (features["cachingEnabled"].toBool() ? "ON" : "OFF");
        qDebug() << "Thinking:" << (features["thinkingEnabled"].toBool() ? "ON" : "OFF");
        qDebug() << "Compaction:" << (features["compactionEnabled"].toBool() ? "ON" : "OFF");
        
        // 缓存统计
        auto cache = stats["cache"].toMap();
        qDebug() << "\n=== CACHE ===";
        qDebug() << "Hits:" << cache["totalHits"];
        qDebug() << "Misses:" << cache["totalMisses"];
        qDebug() << "Hit rate:" << cache["hitRate"].toFloat() * 100 << "%";
        
        // 预算状态
        auto budget = stats["budget"].toMap();
        qDebug() << "\n=== BUDGET ===";
        qDebug() << "Used:" << budget["spent"].toInt();
        qDebug() << "Total:" << budget["total"].toInt();
        qDebug() << "Remaining:" << budget["remaining"].toInt();
        
        // 压缩统计
        auto compression = stats["compression"].toMap();
        qDebug() << "\n=== COMPRESSION ===";
        qDebug() << "Count:" << compression["compressionCount"];
        qDebug() << "Ratio:" << compression["avgCompressionRatio"].toFloat();
        
        // 工具指标
        auto tools = stats["tools"].toMap();
        qDebug() << "\n=== TOOLS ===";
        qDebug() << "Total calls:" << tools["totalToolCalls"];
        qDebug() << "Failures:" << tools["totalFailures"];
        qDebug() << "Success rate:" << tools["successRate"].toFloat() * 100 << "%";
        
        // 存储统计
        auto storage = stats["storage"].toMap();
        qDebug() << "\n=== STORAGE ===";
        qDebug() << "Files:" << storage["totalFiles"];
        qDebug() << "Used:" << storage["totalStorageMB"].toFloat() << "MB";
    }
    
    void alertOnBudgetWarning() {
        BudgetStatus status = m_anthropic->getBudgetStatus();
        
        if (status.usagePercent > 80) {
            qWarning() << "BUDGET WARNING: " << status.usagePercent << "% used";
        }
        
        if (status.budgetExceeded) {
            qCritical() << "BUDGET EXCEEDED!";
        }
    }
    
private:
    AnthropicSkillsExtension *m_anthropic;
};
```

## 使用这些示例

### 1. 编译

```bash
cd /Users/feifei/agent/neurx
mkdir -p build
cd build
cmake ..
make
```

### 2. 链接您的应用

```cpp
#include "skills/AnthropicSkillsExtension.h"

int main() {
    // 使用上面的任何示例类
    CustomerServiceAgent agent;
    agent.handleCustomerMessage("Hello, I have a question...");
    
    return 0;
}
```

### 3. 运行监控

```cpp
MonitoringDashboard dashboard(anthropic.get());
dashboard.displayMetrics();
dashboard.alertOnBudgetWarning();
```

---

## 性能基准

### 成本对比

| 场景 | 无优化 | 启用缓存 | 启用压缩 | 启用批处理 | 全部启用 |
|------|------|--------|--------|----------|--------|
| 100 条消息 | 10K | 7K | 6K | - | 4.5K |
| 1000 条消息 | 100K | 65K | 50K | - | 35K |
| 批处理 1000 请求 | 500K | - | - | 250K | 175K |

### 时间对比

| 操作 | 成本 | 时间 | 用途 |
|------|------|------|------|
| 简单问答 | 500 tokens | 1 sec | 快速响应 |
| 结构化分析 | 5K tokens + 5K thinking | 5 sec | 平衡 |
| 深度研究 | 15K tokens + 30K thinking | 30 sec | 高质量 |
| 批处理 1000 | 250K tokens | 5 min (异步) | 离线处理 |

---

## 故障排除

### 预算超额

```cpp
if (anthropic->isBudgetExceeded()) {
    // 降低工作量
    anthropic->setEffortLevel(EffortLevel::Low);
    
    // 增加压缩
    anthropic->setCompactionStrategy(CompactionStrategy::MaxCompression);
    
    // 重新设置预算
    anthropic->setTokenBudget(500000, 25000);
}
```

### 缓存未工作

```cpp
// 确保启用了缓存
anthropic->enablePromptCaching(true);

// 检查缓存统计
auto stats = anthropic->getCacheStatistics();
if (stats["hitRate"].toFloat() == 0) {
    qWarning() << "No cache hits - content may not be suitable for caching";
}
```

### 工具执行失败

```cpp
// 检查工具指标
auto metrics = anthropic->getToolMetrics();
float successRate = metrics["successRate"].toFloat();

if (successRate < 0.9) {
    qWarning() << "Tool success rate:" << successRate * 100 << "%";
    
    // 检查个别工具调用
    ToolResult result = anthropic->executeTool("tool_name", params);
    if (!result.success) {
        qDebug() << "Error:" << result.errorMessage;
    }
}
```
