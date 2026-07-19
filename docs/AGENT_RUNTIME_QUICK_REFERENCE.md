# Agent Runtime Quick Reference Guide

## 📦 English text

```
SlashCommandManager    → /commands (like /code-review, /new-sdk-app)
EventBus             → Central event pub/sub system
RuleEngine           → Validation and filtering rules
MCPManager           → External tool integration (MCP)
ContextManager       → Multi-source context management
ExecutionStrategyManager → Risk assessment and approval workflow
```

## 🚀 quickstart

### 1. SlashEnglish text
```cpp
// English textslashEnglish text
auto result = slashCommandManager->executeCommand("/code-review file.ts", context);
if (result.success) {
    qDebug() << "Result:" << result.output;
}

// English text
SlashCommand cmd;
cmd.name = "my-command";
cmd.description = "My custom command";
slashCommandManager->registerCommand(cmd, [](const QStringList &args, const QJsonObject &ctx) {
    SlashCommandResult result;
    result.success = true;
    return result;
});
```

### 2. English textsystem
```cpp
// English text
eventBus->publishEvent(
    AgentEvent::Type::ToolCalled,
    "shell_tool",
    QJsonObject{{"command", "ls"}}
);

// English text
auto listenerId = eventBus->subscribe(
    AgentEvent::Type::ToolCompleted,
    [](const AgentEvent &event) {
        qDebug() << "Tool completed:" << event.source;
    },
    10  // priority
);

// English text
eventBus->subscribeOnce(AgentEvent::Type::ExecutionCompleted,
    [](const AgentEvent &event) { /* ... */ });

// English text
auto events = eventBus->eventHistory(100);
```

### 3. English textsystem
```cpp
// English text
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

// evaluationEnglish text
RuleEvaluationContext context;
context.source = "shell_tool";
auto results = ruleEngine->evaluateRules(context);

// English text
QString blockReason;
if (!ruleEngine->isOperationAllowed(context, blockReason)) {
    qDebug() << "Blocked:" << blockReason;
}
```

### 4. English textmanagement
```cpp
// English textfileEnglish text
contextManager->addFileContext("/path/to/file.ts", 10, 50);

// English text
contextManager->addSelectionContext(selectedCode, "editor");

// English text
contextManager->addNote("Important: Fix memory leak in this function");

// English text
QString contextText = contextManager->getContextAsText();
QJsonArray contextJSON = contextManager->getContextAsJSON();

// English text
auto snapshotId = contextManager->createSnapshot();

// recoverEnglish text
contextManager->restoreSnapshot(snapshotId);

// English text
contextManager->clearTransientContext();
```

### 5. English textevaluation
```cpp
// evaluationtoolEnglish text
auto risk = strategyManager->assessToolRisk("shell_tool", params);
qDebug() << "Risk level:" << risk.level;
qDebug() << "Risk score:" << risk.score;

// evaluationEnglish text
auto cmdRisk = strategyManager->assessCommandRisk("rm", {"-rf", "/"});

// English text
auto strategy = strategyManager->getStrategyForTool("shell_tool");

// English textRequiredEnglish text
if (strategyManager->needsApproval(risk, strategy)) {
    // requestEnglish text
    QString reason = strategyManager->getApprovalReason(risk);
    showApprovalDialog(reason);
}

// English textstateEnglish text
auto stateId = strategyManager->captureState();

// English textfailure,AllowedEnglish text
if (operationFailed) {
    strategyManager->rollback(operationId);
}
```

### 6. MCPEnglish text
```cpp
// English textMCPEnglish text
MCPServer server;
server.id = "my-mcp";
server.name = "My MCP Server";
server.type = MCPServer::Type::StdIO;
server.command = "/path/to/mcp-server";
mcpManager->registerServer(server);

// startEnglish text
mcpManager->startServer("my-mcp");

// English texttool
MCPToolCall call;
call.serverId = "my-mcp";
call.toolName = "analyze_code";
call.arguments = QJsonObject{{"code", sourceCode}};

auto result = mcpManager->callTool(call);
if (result.success) {
    qDebug() << "Tool result:" << result.result;
}

// English texttool
auto tools = mcpManager->getAllTools();

// English textstate
auto health = mcpManager->getAllServersHealth();
```

## 📊 English text

### Pattern 1: English text
```cpp
// 1. English textinputEnglish text
auto result = slashCommandManager->executeCommand("/code-review file.ts", context);

// 2. English text
eventBus->publishEvent(AgentEvent::Type::CommandExecuting, "code-review");

// 3. English text
QString blockReason;
if (!ruleEngine->isOperationAllowed(evalContext, blockReason)) {
    return;  // English text
}

// 4. English text
contextManager->addFileContext("file.ts");

// 5. evaluationEnglish text
auto risk = strategyManager->assessCommandRisk("code-review", {});

// 6. RequiredEnglish text?
if (strategyManager->needsApproval(risk, strategy)) {
    // English text...
}

// 7. English text
// ... execution ...

// 8. English text
eventBus->publishEvent(AgentEvent::Type::CommandCompleted, "code-review");
```

### Pattern 2: toolEnglish textsafetypipeline
```cpp
// 1. English texttoolEnglish textrequest
QString toolName = "shell_tool";
QJsonObject params = {{"command", "ls -la"}};

// 2. evaluationEnglish text
auto risk = strategyManager->assessToolRisk(toolName, params);

// 3. English text
RuleEvaluationContext ruleCtx;
ruleCtx.source = toolName;
auto ruleResults = ruleEngine->evaluateRules(ruleCtx);
if (std::any_of(ruleResults.begin(), ruleResults.end(),
                [](const RuleResult &r) { return !r.allowed; })) {
    eventBus->publishEvent(AgentEvent::Type::ToolFailed, toolName,
                          {{"reason", "Rule denied"}});
    return;
}

// 4. English textstate
auto stateId = strategyManager->captureState();

// 5. English text(English textRequired)
auto strategy = strategyManager->getStrategyForTool(toolName);
if (strategyManager->needsApproval(risk, strategy)) {
    // requestEnglish text...
}

// 6. English textstartEnglish text
eventBus->publishEvent(AgentEvent::Type::ToolCalled, toolName, params);

// 7. English texttool
// ... execute tool ...

// 8. English text
eventBus->publishEvent(AgentEvent::Type::ToolCompleted, toolName, results);
```

### Pattern 3: English text
```cpp
// 1. English text
contextManager->addFileContext("main.ts", 1, 100);           // file
contextManager->addSelectionContext(userSelection);         // English text
contextManager->addNote("User said: Fix the bug");          // English text

// 2. English text
contextManager->setItemPriority(noteId, 80);    // English text
contextManager->setItemPriority(fileId, 50);    // fileEnglish text

// 3. English textrankingEnglish text
auto priorityItems = contextManager->getContextByPriority();

// 4. English textLLM
auto contextJSON = contextManager->getContextAsJSON();
llmProvider->callWithContext(userMessage, contextJSON);

// 5. English text
contextManager->clearTransientContext();
```

## 🔧 configurationEnglish text

### English text
```cpp
// English text
auto strictStrategy = strategyManager->createSafeStrategy("StrictMode");

// English text
ExecutionStrategy custom;
custom.approvalMode = ExecutionStrategy::ApprovalMode::RiskBased;
custom.highRiskThreshold = 50;  // 50English textRequiredEnglish text
custom.enableRollback = true;
strategyManager->registerStrategy(custom);
```

### English text
```cpp
// English texttoolEnglish text
auto rule = ruleEngine->createToolValidationRule(
    "shell_tool",
    "command.startsWith('rm')"
);
```

## 📈 monitoringEnglish textstatistics

```cpp
// English textstatistics
auto eventStats = eventBus->getStatistics();
qDebug() << "Total events:" << eventStats["totalEvents"];

// English textstatistics
auto ruleStats = ruleEngine->getStatistics();
qDebug() << "Triggered rules:" << ruleStats["triggers"];

// English text
auto riskDist = strategyManager->getRiskDistribution();
qDebug() << "High risk ops:" << riskDist["high"];

// toolstatistics
auto toolStats = mcpManager->getToolStatistics();
qDebug() << "Tool calls:" << toolStats["calls"];

// English textstatistics
auto ctxStats = contextManager->getStatistics();
qDebug() << "Context items:" << ctxStats["totalItems"];
qDebug() << "Context size:" << ctxStats["contextSize"];
```

## 🔗 English textfile

- mainimplementationEnglish text: `AGENT_RUNTIME_IMPLEMENTATION.md`
- English textfile: `src/agent/` directory
- English textHookManager: `src/agent/HookManager.h`
- English textPluginManager: `src/plugins/PluginManager.h`

## 💡 English text

1. **English text** - English textfailure
2. **useEnglish text** - English text
3. **English text** - English text
4. **monitoringEnglish text** - English text
5. **English text** - English text
6. **testEnglish text** - English textRequiredEnglish texttest
7. **errorEnglish text** - English texterrorEnglish text

## ⚠️ English text

1. English text
2. English text
3. English textsafetyEnglish text
4. English text
5. English textMCPEnglish textfailure

---

**English text:** 2026-06-09
**English text:** ~3600English text
**English textclaude-codeEnglish text:** pluginsystem, Hooks, English textsystem, MCPEnglish text, English text
