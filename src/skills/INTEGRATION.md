# Anthropic Skills 与 Claude Skills 集成指南

如何将 Anthropic 高级特性与现有的 Claude Skills 系统集成。

## 🏗️ 架构概览

### 组件关系

```
ClaudeSkillManager (现有)
        ↓
AnthropicSkillsExtension (新增)
        ├── PromptCachingManager
        ├── AdaptiveThinkingManager  
        ├── EffortControlManager
        ├── ContextCompactionManager
        ├── ToolRunnerFramework
        ├── FileAPIManager
        ├── BatchProcessingManager
        └── ManagedAgentOrchestrator
```

### 特性层次

```
Layer 1: 基础技能执行 (ClaudeSkillManager)
         ├─ 技能发现
         ├─ 环境变量管理
         └─ Tier 1/2/3 上下文

Layer 2: Anthropic 优化 (AnthropicSkillsExtension)
         ├─ 成本优化 (缓存, 压缩, 批处理)
         ├─ 质量提升 (自适应思考, 工作量控制)
         └─ 自主执行 (工具循环, 托管代理)

Layer 3: LLM API 调用 (AnthropicProvider)
         ├─ 请求格式化
         ├─ 流处理
         └─ 错误处理
```

---

## 🚀 集成步骤

### 步骤 1: 初始化

```cpp
#include "skills/ClaudeSkillManager.h"
#include "skills/AnthropicSkillsExtension.h"
#include <memory>

// 创建技能管理器
auto skillManager = std::make_unique<ClaudeSkillManager>();
skillManager->initialize("~/.hermes/skills");
skillManager->setPlatform(Platform::MacOS);

// 包装为 Anthropic 扩展
auto anthropicExt = std::make_unique<AnthropicSkillsExtension>(
    skillManager.get()
);

// 现在可以使用所有功能
anthropicExt->enablePromptCaching(true);
anthropicExt->enableAdaptiveThinking(true);
```

### 步骤 2: 在 AgentEngine 中集成

```cpp
// 在 src/agent/AgentEngine.h 中添加
class AgentEngine {
private:
    std::unique_ptr<ClaudeSkillManager> m_skillManager;
    std::unique_ptr<AnthropicSkillsExtension> m_anthropicExt;
    
public:
    void initialize() {
        m_skillManager = std::make_unique<ClaudeSkillManager>();
        m_skillManager->initialize("~/.hermes/skills");
        
        // 添加 Anthropic 扩展
        m_anthropicExt = std::make_unique<AnthropicSkillsExtension>(
            m_skillManager.get()
        );
        
        // 启用功能
        m_anthropicExt->enablePromptCaching(true);
        m_anthropicExt->enableAdaptiveThinking(true);
    }
    
    AnthropicSkillsExtension* getAnthropicExtension() {
        return m_anthropicExt.get();
    }
};
```

### 步骤 3: 在执行流程中使用

```cpp
// 在 Executor::execute() 中
void Executor::execute(const Task &task) {
    // 获取 Anthropic 扩展
    auto anthropic = engine->getAnthropicExtension();
    
    // 构建请求
    AnthropicSkillRequest request;
    request.skillId = task.skillId;
    request.userInput = task.input;
    
    // 根据任务类型应用特性
    if (task.type == TaskType::Analysis) {
        request.thinking.enabled = true;
        request.thinking.budgetTokens = ThinkingDepth::Deep;
    } else if (task.type == TaskType::QuickResponse) {
        request.usePromptCaching = true;  // 使用缓存加速
    }
    
    // 执行
    anthropic->executeWithAnthropicFeatures(
        request,
        [this, task](bool success, const QVariantMap &result) {
            handleTaskResult(task, success, result);
        }
    );
}
```

---

## 💡 使用场景

### 场景 1: 长期对话系统

**需求**: 维持多轮对话，同时控制成本

**解决方案**:

```cpp
class ConversationManager {
private:
    AnthropicSkillsExtension *m_anthropic;
    QVector<QString> m_history;
    
public:
    void addMessage(const QString &message) {
        m_history.append(message);
        
        // 在 500+ 条消息后启用压缩
        if (m_history.count() > 500) {
            // 自动压缩早期消息
            CompactedContext compact = m_anthropic->compactHistory(
                m_history
            );
            
            // 记录节省
            qDebug() << "Compression saved" 
                    << (compact.originalTokens - compact.compactedTokens) 
                    << "tokens";
        }
        
        // 系统提示缓存
        QString sysPrompt = getSystemPrompt();
        float savings;
        
        if (m_anthropic->shouldCacheContent(sysPrompt, savings)) {
            // 第一次调用: 建立缓存
            // 后续调用: 享受 90% 节省
        }
        
        // 执行对话
        processMessage(message);
    }
};
```

### 场景 2: 批量数据分析

**需求**: 处理大量数据，成本敏感

**解决方案**:

```cpp
class BulkAnalyzer {
private:
    AnthropicSkillsExtension *m_anthropic;
    
public:
    void analyzeBulkData(const QStringList &dataItems) {
        // 创建批处理请求
        QVector<AnthropicSkillRequest> requests;
        
        for (const auto &item : dataItems) {
            AnthropicSkillRequest req;
            req.skillId = "analyze";
            req.userInput = item;
            requests.append(req);
        }
        
        // 使用批处理 (50% 折扣)
        BatchJob job = m_anthropic->createBatch(requests);
        QString batchId = m_anthropic->submitBatch(job);
        
        // 计算节省
        float savings = m_anthropic->calculateBatchSavings(
            requests.count() * 5000  // 估计每个请求 5K tokens
        );
        
        qDebug() << "Batch submitted - cost savings:" << savings << "tokens";
        
        // 异步等待结果
        scheduleStatusCheck(batchId);
    }
};
```

### 场景 3: 复杂问题解决

**需求**: 高质量分析，预算充足

**解决方案**:

```cpp
class ComplexProblemSolver {
private:
    AnthropicSkillsExtension *m_anthropic;
    
public:
    void solve(const QString &problem) {
        // 启用所有质量特性
        m_anthropic->enableAdaptiveThinking(true);
        m_anthropic->setEffortLevel(EffortLevel::High);
        
        // 自动评估任务复杂性
        AdaptiveThinkingConfig config = m_anthropic->assessTask(problem);
        
        // 构建请求
        AnthropicSkillRequest request;
        request.skillId = "complex-analysis";
        request.userInput = problem;
        request.thinking = config;
        request.effort.level = EffortLevel::High;
        
        // 执行 - Claude 会花时间进行深思
        m_anthropic->executeWithAnthropicFeatures(
            request,
            [](bool success, const QVariantMap &result) {
                if (success && result["thinkingApplied"].toBool()) {
                    qDebug() << "Deep thinking analysis completed";
                }
            }
        );
    }
};
```

### 场景 4: 自主研究代理

**需求**: 让 Claude 自主执行多步骤任务

**解决方案**:

```cpp
class ResearchAgent {
private:
    AnthropicSkillsExtension *m_anthropic;
    
public:
    void startResearch(const QString &topic) {
        // 启用工具执行器
        m_anthropic->enableToolRunner(true);
        
        // 注册工具
        registerSearchTool();
        registerAnalysisTool();
        registerReportTool();
        
        // 让 Claude 自主运行
        m_anthropic->runAgentLoop(
            QString("Research and create comprehensive report on: %1")
                .arg(topic),
            [this](const QVector<ToolResult> &results) {
                onAgentLoopComplete(results);
            }
        );
    }
    
private:
    void registerSearchTool() {
        ToolDefinition tool;
        tool.name = "web_search";
        tool.description = "Search the web";
        // ... 详细配置
        m_anthropic->registerTool(tool);
    }
};
```

---

## 📊 性能对比

### 不同配置下的成本/质量权衡

| 配置 | 用例 | 成本 | 质量 | 延迟 |
|------|------|------|------|------|
| **基础** | 简单问答 | ✓ | ✓ | ✓ |
| **+ 缓存** | 重复问题 | ✓✓✓ | ✓ | ✓✓✓ |
| **+ 压缩** | 长对话 | ✓✓ | ✓ | ✓ |
| **+ 思考** | 复杂分析 | ✓ | ✓✓✓ | ✓✓ |
| **批处理** | 批量操作 | ✓✓✓ | ✓ | 异步 |
| **全部启用** | 优化系统 | ✓✓ | ✓✓ | ✓ |

---

## 🔧 配置模板

### 成本优先

```cpp
anthropic->enablePromptCaching(true);
anthropic->enableContextCompaction(true);
anthropic->setCompactionStrategy(CompactionStrategy::MaxCompression);
anthropic->setEffortLevel(EffortLevel::Low);
anthropic->enableBatchProcessing(true);

// 估计: 50-70% 成本减少
```

### 质量优先

```cpp
anthropic->enableAdaptiveThinking(true);
anthropic->setEffortLevel(EffortLevel::High);
anthropic->setThinkingDepth(ThinkingDepth::Deep);
anthropic->setCompactionStrategy(CompactionStrategy::MinQualityLoss);

// 估计: 30-50% 成本增加，但质量显著提升
```

### 平衡

```cpp
anthropic->enablePromptCaching(true);
anthropic->enableAdaptiveThinking(true);
anthropic->setEffortLevel(EffortLevel::Medium);
anthropic->enableContextCompaction(true);
anthropic->setCompactionStrategy(CompactionStrategy::Automatic);

// 估计: 20-30% 成本减少，同时保持良好质量
```

---

## 🎯 迁移清单

若要在现有的 NeurX 系统中启用 Anthropic 功能：

- [ ] **阅读文档**
  - [ ] [ANTHROPIC_FEATURES.md](ANTHROPIC_FEATURES.md) - 功能详解
  - [ ] [ANTHROPIC_EXAMPLES.md](ANTHROPIC_EXAMPLES.md) - 代码示例
  - [ ] [INTEGRATION.md](INTEGRATION.md) - 本文件

- [ ] **更新代码**
  - [ ] 在 `AgentEngine` 中添加 `AnthropicSkillsExtension` 成员
  - [ ] 在 `Executor` 中集成 Anthropic 请求格式
  - [ ] 在 `Verifier` 中添加成本/质量检查

- [ ] **配置系统**
  - [ ] 更新 `CMakeLists.txt`（已完成 ✓）
  - [ ] 配置环境变量（Token 预算等）
  - [ ] 设置日志级别进行监控

- [ ] **测试**
  - [ ] 单元测试: 每个管理器的基本功能
  - [ ] 集成测试: 多个功能的组合
  - [ ] 性能测试: 成本和延迟测量

- [ ] **部署**
  - [ ] 在开发环境中验证
  - [ ] 在测试环境中进行负载测试
  - [ ] 逐步推出到生产环境

- [ ] **监控**
  - [ ] 启用指标收集 (getComprehensiveStats)
  - [ ] 设置预算警告
  - [ ] 创建使用仪表板

---

## 🐛 故障排除

### 问题 1: 缓存不工作

**症状**: hitRate = 0

**检查**:
```cpp
// 1. 确保启用了缓存
if (!anthropic->getCacheStatistics()["hitRate"].toFloat() > 0) {
    qWarning() << "Cache not working";
}

// 2. 缓存需要多个相同请求
for (int i = 0; i < 5; ++i) {
    anthropic->shouldCacheContent(sameContent, savings);
}

// 3. 检查内容大小 (需要 > 1024 tokens)
```

### 问题 2: 预算不足

**症状**: 请求被拒绝，原因: 预算超额

**解决**:
```cpp
// 1. 检查当前使用情况
auto status = anthropic->getBudgetStatus();
qDebug() << "Usage:" << status.usagePercent << "%";

// 2. 选择更低的工作量
anthropic->setEffortLevel(EffortLevel::Low);

// 3. 增加预算
anthropic->setTokenBudget(500000, 50000);

// 4. 或使用批处理 (50% 折扣)
anthropic->enableBatchProcessing(true);
```

### 问题 3: 工具循环不执行

**症状**: runAgentLoop 回调收到空结果

**检查**:
```cpp
// 1. 确保已注册工具
anthropic->registerTool(toolDef);

// 2. 确保启用了工具执行器
if (!anthropic->getFeatureStatus()["toolRunnerEnabled"].toBool()) {
    qWarning() << "Tool runner not enabled";
}

// 3. 检查工具指标
auto metrics = anthropic->getToolMetrics();
qDebug() << "Tool calls:" << metrics["totalToolCalls"];
```

---

## 📞 支持

- 查看 [ANTHROPIC_FEATURES.md](ANTHROPIC_FEATURES.md) 获取完整 API 文档
- 查看 [ANTHROPIC_EXAMPLES.md](ANTHROPIC_EXAMPLES.md) 获取更多代码示例
- 查看 [CLAUDE_SKILLS_SYSTEM.md](../../../hermes-agent/docs/CLAUDE_SKILLS_SYSTEM.md) 获取底层技能系统文档

---

## 📝 更新日志

### v1.0.0 (2024-01)

**新增**:
- 8 个 Anthropic 管理器的完整实现
- AnthropicSkillsExtension 整合层
- 综合示例和文档

**改进**:
- 性能: 缓存和压缩实现
- 成本: 批处理支持
- 质量: 自适应思考

**破坏性变更**: 无

---

## 🙏 致谢

感谢 Anthropic 提供这些强大的 API 特性。
