# Agent Runtime Quick Reference Guide

## 📦 新增组件概览

```
SlashCommandManager    → /commands (like /code-review, /new-sdk-app)
EventBus             → Central event pub/sub system
RuleEngine           → Validation and filtering rules
MCPManager           → External tool integration (MCP)
ContextManager       → Multi-source context management
ExecutionStrategyManager → Risk assessment and approval workflow
```

## 🚀 快速开始

### 1. Slash命令
```cpp
// 执行slash命令
auto result = slashCommandManager->executeCommand("/code-review file.ts", context);
if (result.success) {
    qDebug() << "Result:" << result.output;
}

// 注册自定义命令
SlashCommand cmd;
cmd.name = "my-command";
cmd.description = "My custom command";
slashCommandManager->registerCommand(cmd, [](const QStringList &args, const QJsonObject &ctx) {
    SlashCommandResult result;
    result.success = true;
    return result;
});
```

### 2. 事件系统
```cpp
// 发布事件
eventBus->publishEvent(
    AgentEvent::Type::ToolCalled,
    "shell_tool",
    QJsonObject{{"command", "ls"}}
);

// 订阅事件
auto listenerId = eventBus->subscribe(
    AgentEvent::Type::ToolCompleted,
    [](const AgentEvent &event) {
        qDebug() << "Tool completed:" << event.source;
    },
    10  // priority
);

// 一次性订阅
eventBus->subscribeOnce(AgentEvent::Type::ExecutionCompleted,
    [](const AgentEvent &event) { /* ... */ });

// 获取事件历史
auto events = eventBus->eventHistory(100);
```

### 3. 规则系统
```cpp
// 注册规则
Rule rule;
rule.id = "my-rule";
rule.name = "Prevent dangerous operations";
rule.applicableTools = {"shell_tool"};
rule.condition = "contains(command, 'rm')";

ruleEngine->registerRule(rule, [](const RuleEvaluationContext &ctx) {
    RuleResult result;
    result.matched = true;
    result.allowed = false;
    result.reason = "Dangerous operation blocked";
    return result;
});

// 评估规则
RuleEvaluationContext context;
context.source = "shell_tool";
auto results = ruleEngine->evaluateRules(context);

// 检查操作是否被允许
QString blockReason;
if (!ruleEngine->isOperationAllowed(context, blockReason)) {
    qDebug() << "Blocked:" << blockReason;
}
```

### 4. 上下文管理
```cpp
// 添加文件上下文
contextManager->addFileContext("/path/to/file.ts", 10, 50);

// 添加代码选区
contextManager->addSelectionContext(selectedCode, "editor");

// 添加笔记
contextManager->addNote("Important: Fix memory leak in this function");

// 获取格式化上下文
QString contextText = contextManager->getContextAsText();
QJsonArray contextJSON = contextManager->getContextAsJSON();

// 创建快照
auto snapshotId = contextManager->createSnapshot();

// 恢复快照
contextManager->restoreSnapshot(snapshotId);

// 清理临时上下文
contextManager->clearTransientContext();
```

### 5. 风险评估
```cpp
// 评估工具风险
auto risk = strategyManager->assessToolRisk("shell_tool", params);
qDebug() << "Risk level:" << risk.level;
qDebug() << "Risk score:" << risk.score;

// 评估命令风险
auto cmdRisk = strategyManager->assessCommandRisk("rm", {"-rf", "/"});

// 获取执行策略
auto strategy = strategyManager->getStrategyForTool("shell_tool");

// 决定是否需要批准
if (strategyManager->needsApproval(risk, strategy)) {
    // 请求用户批准
    QString reason = strategyManager->getApprovalReason(risk);
    showApprovalDialog(reason);
}

// 捕获状态以备回滚
auto stateId = strategyManager->captureState();

// 如果失败,可以回滚
if (operationFailed) {
    strategyManager->rollback(operationId);
}
```

### 6. MCP集成
```cpp
// 注册MCP服务器
MCPServer server;
server.id = "my-mcp";
server.name = "My MCP Server";
server.type = MCPServer::Type::StdIO;
server.command = "/path/to/mcp-server";
mcpManager->registerServer(server);

// 启动服务器
mcpManager->startServer("my-mcp");

// 调用工具
MCPToolCall call;
call.serverId = "my-mcp";
call.toolName = "analyze_code";
call.arguments = QJsonObject{{"code", sourceCode}};

auto result = mcpManager->callTool(call);
if (result.success) {
    qDebug() << "Tool result:" << result.result;
}

// 获取所有可用工具
auto tools = mcpManager->getAllTools();

// 检查服务器健康状态
auto health = mcpManager->getAllServersHealth();
```

## 📊 常见操作模式

### Pattern 1: 命令执行工作流
```cpp
// 1. 用户输入命令
auto result = slashCommandManager->executeCommand("/code-review file.ts", context);

// 2. 发布事件
eventBus->publishEvent(AgentEvent::Type::CommandExecuting, "code-review");

// 3. 验证规则
QString blockReason;
if (!ruleEngine->isOperationAllowed(evalContext, blockReason)) {
    return;  // 操作被阻止
}

// 4. 准备上下文
contextManager->addFileContext("file.ts");

// 5. 评估风险
auto risk = strategyManager->assessCommandRisk("code-review", {});

// 6. 需要批准?
if (strategyManager->needsApproval(risk, strategy)) {
    // 等待用户批准...
}

// 7. 执行操作
// ... execution ...

// 8. 发布完成事件
eventBus->publishEvent(AgentEvent::Type::CommandCompleted, "code-review");
```

### Pattern 2: 工具调用安全流程
```cpp
// 1. 接收工具调用请求
QString toolName = "shell_tool";
QJsonObject params = {{"command", "ls -la"}};

// 2. 评估风险
auto risk = strategyManager->assessToolRisk(toolName, params);

// 3. 检查规则
RuleEvaluationContext ruleCtx;
ruleCtx.source = toolName;
auto ruleResults = ruleEngine->evaluateRules(ruleCtx);
if (std::any_of(ruleResults.begin(), ruleResults.end(),
                [](const RuleResult &r) { return !r.allowed; })) {
    eventBus->publishEvent(AgentEvent::Type::ToolFailed, toolName,
                          {{"reason", "Rule denied"}});
    return;
}

// 4. 捕获状态
auto stateId = strategyManager->captureState();

// 5. 获取批准(如需要)
auto strategy = strategyManager->getStrategyForTool(toolName);
if (strategyManager->needsApproval(risk, strategy)) {
    // 请求批准...
}

// 6. 发布开始事件
eventBus->publishEvent(AgentEvent::Type::ToolCalled, toolName, params);

// 7. 执行工具
// ... execute tool ...

// 8. 发布完成事件
eventBus->publishEvent(AgentEvent::Type::ToolCompleted, toolName, results);
```

### Pattern 3: 上下文融合
```cpp
// 1. 收集多个源的上下文
contextManager->addFileContext("main.ts", 1, 100);           // 文件
contextManager->addSelectionContext(userSelection);         // 选区
contextManager->addNote("User said: Fix the bug");          // 笔记

// 2. 设置优先级
contextManager->setItemPriority(noteId, 80);    // 用户笔记优先级最高
contextManager->setItemPriority(fileId, 50);    // 文件中等优先级

// 3. 获取排序后的上下文
auto priorityItems = contextManager->getContextByPriority();

// 4. 发送到LLM
auto contextJSON = contextManager->getContextAsJSON();
llmProvider->callWithContext(userMessage, contextJSON);

// 5. 操作完成后清理临时上下文
contextManager->clearTransientContext();
```

## 🔧 配置和自定义

### 自定义批准策略
```cpp
// 创建严格策略
auto strictStrategy = strategyManager->createSafeStrategy("StrictMode");

// 自定义风险阈值
ExecutionStrategy custom;
custom.approvalMode = ExecutionStrategy::ApprovalMode::RiskBased;
custom.highRiskThreshold = 50;  // 50以上需要批准
custom.enableRollback = true;
strategyManager->registerStrategy(custom);
```

### 自定义规则
```cpp
// 创建工具验证规则
auto rule = ruleEngine->createToolValidationRule(
    "shell_tool",
    "command.startsWith('rm')"
);
```

## 📈 监控和统计

```cpp
// 事件统计
auto eventStats = eventBus->getStatistics();
qDebug() << "Total events:" << eventStats["totalEvents"];

// 规则统计
auto ruleStats = ruleEngine->getStatistics();
qDebug() << "Triggered rules:" << ruleStats["triggers"];

// 风险分布
auto riskDist = strategyManager->getRiskDistribution();
qDebug() << "High risk ops:" << riskDist["high"];

// 工具统计
auto toolStats = mcpManager->getToolStatistics();
qDebug() << "Tool calls:" << toolStats["calls"];

// 上下文统计
auto ctxStats = contextManager->getStatistics();
qDebug() << "Context items:" << ctxStats["totalItems"];
qDebug() << "Context size:" << ctxStats["contextSize"];
```

## 🔗 相关文件

- 主实现文档: `AGENT_RUNTIME_IMPLEMENTATION.md`
- 源文件: `src/agent/` 目录
- 已有HookManager: `src/agent/HookManager.h`
- 已有PluginManager: `src/plugins/PluginManager.h`

## 💡 最佳实践

1. **总是检查返回值** - 操作可能失败
2. **使用优先级** - 在订阅事件时指定优先级
3. **及时清理** - 清理临时上下文和快照
4. **监控风险** - 定期检查风险分布
5. **记录事件** - 用于调试和审计
6. **测试规则** - 新规则需要充分测试
7. **错误处理** - 所有操作都应有错误处理

## ⚠️ 常见陷阱

1. 未订阅关键事件导致操作无法追踪
2. 忘记取消订阅导致内存泄漏
3. 规则过于宽松导致安全问题
4. 上下文过大导致性能问题
5. 未处理MCP连接失败

---

**更新日期:** 2026-06-09
**总代码行数:** ~3600行
**涵盖的claude-code功能:** 插件系统, Hooks, 命令系统, MCP集成, 规则引擎
