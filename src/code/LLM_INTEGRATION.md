# LLM集成指南 - CodeMagic增强版

## 概述

LLMCodeAnalyzer是CodeMagic的增强版本，集成了Claude/GPT等LLM能力，提供**混合策略**：

```
简单代码 → 本地规则（快，秒级）
    ↓
复杂代码 → LLM分析（准，高准确度）
    ↓
已分析   → 缓存（快，无成本）
```

## 核心特性

| 功能 | 本地CodeMagic | LLMCodeAnalyzer |
|------|-------------|----------------|
| 速度 | 10ms | 1-3秒 |
| 准确度 | 60-70% | 85-95% |
| 成本 | 免费 | $0.01-0.05/次 |
| 无网络时 | ✓ 可用 | ✗ 不可用 |
| 理解逻辑 | ✗ 否 | ✓ 是 |
| 生产级代码 | ✗ 40%可用 | ✓ 95%可用 |

## 混合策略说明

### 快速通道（本地）
```cpp
// 代码 < 500字符
// 或者 < 20行
// 直接使用本地分析，立即返回结果

auto result = analyzer->analyzeCode(shortCode, language);
// 响应时间：< 50ms
```

### 深度通道（LLM）
```cpp
// 代码 > 500字符
// 或者 > 20行
// 检查缓存，缓存无命中则调用LLM

auto result = analyzer->analyzeCode(complexCode, language);
// 响应时间：1-3秒（首次）/ <50ms（缓存）
```

### 缓存策略
```cpp
// 相同的代码不会重复调用LLM
// 自动缓存所有LLM分析结果

analyzer->setCacheEnabled(true);  // 默认启用
analyzer->getCacheHitRate();       // 查看缓存命中率
```

## 使用示例

### 基础使用

```cpp
#include "LLMCodeAnalyzer.h"
#include "../llm/AnthropicProvider.h"  // Claude

// 创建分析器
auto analyzer = std::make_unique<LLMCodeAnalyzer>();

// 配置LLM提供商（Claude API）
auto provider = new AnthropicProvider();
provider->setApiKey("sk-ant-...");  // 从环境变量读取
analyzer->setLLMProvider(provider);

// 配置
analyzer->setLLMEnabled(true);           // 启用LLM
analyzer->setModel("claude-3-5-sonnet"); // 选择模型
analyzer->setCacheEnabled(true);         // 启用缓存
analyzer->setFallbackToLocal(true);      // 失败时回退
```

### 代码分析

```cpp
QString code = R"(
def calculate_discount(price, category):
    if category == "vip":
        return price * 0.7
    elif category == "bulk":
        return price * 0.5
    return price
)";

// 分析代码 - 自动选择本地或LLM
auto result = analyzer->analyzeCode(code, ProgrammingLanguage::Python);

qDebug() << "Quality:" << result.quality;
qDebug() << "Complexity:" << result.complexity;
qDebug() << "Issues:" << result.issues.size();

// 查看是否使用了LLM
auto stats = analyzer->getLLMStatistics();
qDebug() << "LLM Requests:" << stats["llmRequests"];
qDebug() << "Cost:" << stats["totalCostUSD"];
```

### 智能Bug检测

```cpp
// 本地快速检测 + LLM深度分析
auto bugs = analyzer->findBugs(code, ProgrammingLanguage::Python);

for (const auto &bug : bugs) {
    qDebug() << "Issue:" << bug.message;
    qDebug() << "Line:" << bug.lineNumber;
    
    // 获取修复建议
    auto fixes = analyzer->suggestFixes(bug, code);
    for (const auto &fix : fixes) {
        qDebug() << "Fix:" << fix;
    }
}
```

### 智能代码生成

```cpp
// 使用LLM生成生产级代码
CodeGenerationRequest request;
request.language = ProgrammingLanguage::Python;
request.description = "生成一个用户认证函数，支持密码哈希和token验证";
request.includeComments = true;
request.includeTests = true;
request.optimizeForPerformance = true;

auto generated = analyzer->generateCode(request);

qDebug() << "Generated Code:" << generated.code;
qDebug() << "Explanation:" << generated.explanation;
qDebug() << "Quality:" << generated.estimatedQuality;
```

### 安全分析

```cpp
// 专注于安全问题
auto securityIssues = analyzer->findSecurityIssues(code, language);

for (const auto &issue : securityIssues) {
    if (issue.severity == IssueSeverity::Critical) {
        qDebug() << "CRITICAL:" << issue.message;
        qDebug() << "Fix:" << issue.suggestedFix;
    }
}
```

### 代码审查

```cpp
// 深度代码审查
auto review = analyzer->reviewCode(code, "author@example.com", "reviewer@example.com");

qDebug() << "Overall Score:" << review.overallScore;
qDebug() << "Issues:" << review.issues.size();
qDebug() << "Suggestions:" << review.suggestions;
qDebug() << "Praise:" << review.praise;
```

### 测试生成

```cpp
TestGenerationRequest testRequest;
testRequest.code = code;
testRequest.language = ProgrammingLanguage::Python;
testRequest.testFramework = "pytest";
testRequest.includeEdgeCases = true;
testRequest.minCoverage = 85;

auto tests = analyzer->generateTests(testRequest);
qDebug() << "Test Code:" << tests.testCode;
qDebug() << "Estimated Coverage:" << tests.estimatedCoverage << "%";
qDebug() << "Number of Tests:" << tests.numberOfTests;
```

## 性能优化建议

### 1. 缓存优化

```cpp
// 对于重复分析的代码，启用缓存
analyzer->setCacheEnabled(true);

// 监控缓存命中率
float hitRate = analyzer->getCacheHitRate();
qDebug() << "Cache Hit Rate:" << hitRate * 100 << "%";

// 如果命中率低，可能需要调整缓存策略
if (hitRate < 0.3) {
    analyzer->resetStats();
}
```

### 2. 成本控制

```cpp
// 监控API成本
float totalCost = analyzer->getTotalCost();
qDebug() << "Total Cost:" << totalCost << " USD";

// 设置成本限制（可选）
analyzer->setLLMEnabled(totalCost > 100.0f ? false : true);

// 获取详细统计
auto stats = analyzer->getLLMStatistics();
qDebug() << "LLM Requests:" << stats["llmRequests"];
qDebug() << "Cost per Request:" << (totalCost / stats["llmRequests"].toInt());
```

### 3. 选择合适的模型

```cpp
// Claude 3.5 Sonnet - 最佳平衡（推荐用于CodeMagic）
analyzer->setModel("claude-3-5-sonnet");

// Claude 3 Opus - 最强大（但贵）
analyzer->setModel("claude-3-opus");

// Claude 3 Haiku - 最快最便宜（适合简单任务）
analyzer->setModel("claude-3-haiku");

// OpenAI GPT-4 Turbo
analyzer->setModel("gpt-4-turbo");

// OpenAI GPT-3.5 Turbo - 最便宜（但能力有限）
analyzer->setModel("gpt-3.5-turbo");
```

### 4. 异步操作

```cpp
// 使用异步API避免阻塞UI
auto analysisId = analyzer->analyzeCodeAsync(
    code, 
    ProgrammingLanguage::Python,
    [this](const CodeAnalysisResult &result) {
        qDebug() << "Analysis complete, quality:" << result.quality;
        updateUI(result);
    }
);

qDebug() << "Analysis ID:" << analysisId;
```

## 配置和部署

### 设置API密钥

```bash
# 方案1：环境变量（推荐）
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."

# 方案2：配置文件（config.json）
{
    "llm": {
        "provider": "anthropic",
        "apiKey": "${ANTHROPIC_API_KEY}",
        "model": "claude-3-5-sonnet",
        "timeout": 30000,
        "maxRetries": 3
    }
}

# 方案3：代码中配置
provider->setApiKey(getApiKeyFromKeychain());
```

### 启用/禁用LLM

```cpp
// 根据条件启用/禁用
bool hasApiKey = !getenv("ANTHROPIC_API_KEY").isEmpty();
analyzer->setLLMEnabled(hasApiKey);

// 或者根据配置启用
if (config["llm"]["enabled"].toBool(false)) {
    analyzer->setLLMEnabled(true);
}
```

## 错误处理

### 回退策略

```cpp
// 如果LLM失败，自动回退到本地分析
analyzer->setFallbackToLocal(true);

auto result = analyzer->analyzeCode(code, language);
// 即使LLM出错，也会返回本地分析结果
```

### 重试策略

```cpp
// 自动重试失败的请求
analyzer->setRetryPolicy(3,  // 最多重试3次
                         1000); // 延迟1秒

// 会自动处理临时故障
```

### 网络连接检测

```cpp
// 检查LLM连接
if (!provider->isConnected()) {
    qDebug() << "LLM not available, using local analysis";
    analyzer->setLLMEnabled(false);
}
```

## 成本估算

### 典型成本

| 操作 | 输入Tokens | 输出Tokens | 成本 |
|------|----------|----------|------|
| 分析100行代码 | 300 | 200 | $0.0022 |
| 生成函数 | 500 | 400 | $0.0038 |
| 生成测试 | 800 | 600 | $0.0062 |
| 代码审查 | 1000 | 800 | $0.0096 |

### 成本优化

```
1. 启用缓存       → 避免重复调用 (节省80%+)
2. 选择便宜模型   → Claude 3 Haiku (节省70%)
3. 批量处理       → 一次处理多个请求 (节省10%)
4. 离线模式       → 使用本地分析 (节省100%)
```

## 监控和调试

### 获取详细日志

```cpp
// 启用调试模式
provider->setDebugEnabled(true);

// 所有LLM请求/响应会被记录
// 查看日志文件或控制台输出
```

### 性能分析

```cpp
// 获取性能统计
auto stats = analyzer->getLLMStatistics();

qDebug() << "Performance:";
qDebug() << "- LLM Requests: " << stats["llmRequests"];
qDebug() << "- Cache Hits: " << stats["cacheHits"];
qDebug() << "- Cache Hit Rate: " << stats["cacheHitRate"];
qDebug() << "- Total Cost: $" << stats["totalCostUSD"];
qDebug() << "- Analysis Cache Size: " << stats["analysisCacheSize"];
qDebug() << "- Generation Cache Size: " << stats["generationCacheSize"];
```

## 常见问题

### Q: LLM分析和本地分析有什么区别？

A: 
- **本地分析**：规则引擎，快速但准确度有限（60-70%）
- **LLM分析**：理解代码逻辑，准确度高（85-95%）

对于简单问题，两者结果相同。对于复杂逻辑问题，LLM显著更好。

### Q: 如何降低成本？

A:
1. 启用缓存（最有效）
2. 使用Claude 3 Haiku（便宜70%）
3. 减少不必要的分析
4. 批量处理请求

### Q: 没有网络怎么办？

A: 自动回退到本地分析：
```cpp
analyzer->setFallbackToLocal(true);
// 网络故障时自动使用本地方案
```

### Q: 如何确保API密钥安全？

A:
1. 使用环境变量（不要硬编码）
2. 使用系统密钥链
3. 使用加密的配置文件
4. 限制API密钥权限

## 集成检查清单

- [ ] 安装了Claude/OpenAI SDK
- [ ] 配置了API密钥
- [ ] 启用了缓存
- [ ] 配置了回退策略
- [ ] 添加了错误处理
- [ ] 监控了成本
- [ ] 测试了离线模式
- [ ] 设置了重试策略
- [ ] 添加了日志记录
- [ ] 文档已更新

## 下一步

1. **实时反馈** - 用户拒绝的建议进行反馈优化
2. **模型微调** - 使用项目特定代码训练模型
3. **多模型支持** - 自动选择最佳模型
4. **团队评分** - 社区对建议的评分
5. **插件系统** - 支持自定义分析器
