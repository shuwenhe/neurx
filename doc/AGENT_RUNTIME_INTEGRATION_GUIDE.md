# Agent Runtime Integration Guide

## 📋 Overview

This guide explains how to integrate and use the new Agent Runtime Enhancement components in the neurx-code architecture.

---

## 🏗️ Architecture

### Component Relationships

```
AgentEngine (Main coordinator)
├── SlashCommandManager     → Handles /command syntax
├── EventBus               → Central event hub
├── RuleEngine             → Validates operations
├── MCPManager             → External tools (MCP)
├── ContextManager         → Multi-source context
└── ExecutionStrategyManager → Risk assessment & approval
```

### Component Initialization

All 6 managers are automatically initialized in `AgentEngine::AgentEngine()`:

```cpp
AgentEngine::AgentEngine(QObject *parent) : QObject(parent) {
    m_eventBus = std::make_unique<EventBus>(this);
    m_slashCommandManager = std::make_unique<SlashCommandManager>(this);
    m_ruleEngine = std::make_unique<RuleEngine>(this);
    m_mcpManager = std::make_unique<MCPManager>(this);
    m_contextManager = std::make_unique<ContextManager>(this);
    m_strategyManager = std::make_unique<ExecutionStrategyManager>(this);
}
```

---

## 🔌 Access Pattern

From any QObject in the codebase, you can access the managers through AgentEngine:

```cpp
// Example: Getting access to managers
AgentEngine *engine = /* ... get engine instance ... */;

SlashCommandManager *cmdMgr = engine->slashCommandManager();
EventBus *events = engine->eventBus();
RuleEngine *rules = engine->ruleEngine();
MCPManager *mcp = engine->mcpManager();
ContextManager *ctx = engine->contextManager();
ExecutionStrategyManager *strategy = engine->strategyManager();
```

---

## 💡 Common Integration Patterns

### Pattern 1: User Input via Slash Command

```cpp
// In your UI handler (e.g., CommandPalette):
void MyUI::onUserSubmitCommand(const QString &input) {
    // Parse as slash command
    if (input.startsWith("/")) {
        auto result = engine->slashCommandManager()->executeCommand(input, context);
        if (result.success) {
            showResult(result.output);
        } else {
            showError(result.errorMessage);
        }
    }
}
```

### Pattern 2: Safe Tool Execution Workflow

```cpp
// In your tool execution handler:
void ToolExecutor::executeToolSafely(const ToolCall &call) {
    // 1. Evaluate rules
    RuleEvaluationContext ruleCtx;
    ruleCtx.source = call.toolName;
    auto results = engine->ruleEngine()->evaluateRules(ruleCtx);
    
    bool allowed = true;
    for (const auto &result : results) {
        if (!result.allowed) {
            allowed = false;
            qWarning() << "Rule blocked:" << result.reason;
            break;
        }
    }
    
    if (!allowed) return;
    
    // 2. Assess risk
    auto risk = engine->strategyManager()->assessToolRisk(call.toolName, 
                    QJsonObject::fromVariantMap(call.parameters));
    
    // 3. Add context
    engine->contextManager()->addNote(
        QString("Executing: %1").arg(call.toolName)
    );
    
    // 4. Capture state (for rollback)
    auto stateId = engine->strategyManager()->captureState();
    
    // 5. Check if approval needed
    auto strategy = engine->strategyManager()->getStrategyForTool(call.toolName);
    if (engine->strategyManager()->needsApproval(risk, strategy)) {
        engine->eventBus()->publishEvent(
            AgentEvent::Type::ToolApprovalRequired,
            call.toolName
        );
        // Wait for user approval...
        return;
    }
    
    // 6. Execute
    executeTool(call);
}
```

### Pattern 3: Event-Driven Monitoring

```cpp
// Subscribe to all tool calls
engine->eventBus()->subscribe(
    AgentEvent::Type::ToolCalled,
    [](const AgentEvent &event) {
        qDebug() << "Tool called:" << event.source;
        qDebug() << "Parameters:" << event.data;
    },
    10  // high priority
);

// Subscribe to execution completion
engine->eventBus()->subscribeOnce(
    AgentEvent::Type::ExecutionCompleted,
    [](const AgentEvent &event) {
        qDebug() << "Execution completed!";
    }
);
```

### Pattern 4: Multi-Source Context Collection

```cpp
// Collect context from multiple sources
void WorkflowOptimizer::prepareContext() {
    auto ctx = engine->contextManager();
    
    // Add current file
    ctx->addFileContext("/path/to/file.ts", 1, 50);
    
    // Add user selection
    ctx->addSelectionContext(selectedCode, "editor");
    
    // Add user note
    ctx->addNote("Focus on performance optimization");
    
    // Create snapshot before operation
    auto snapshot = ctx->createSnapshot();
    
    // Use context
    auto contextJSON = ctx->getContextAsJSON();
    sendToLLM(contextJSON);
    
    // If something goes wrong, restore
    if (operationFailed) {
        ctx->restoreSnapshot(snapshot);
    }
}
```

---

## 🔄 Event System Integration

### Available Events

```cpp
// Execution lifecycle
AgentEvent::Type::ExecutionStarted
AgentEvent::Type::ExecutionCompleted
AgentEvent::Type::ExecutionFailed

// Tool lifecycle
AgentEvent::Type::ToolCalled
AgentEvent::Type::ToolCompleted
AgentEvent::Type::ToolFailed
AgentEvent::Type::ToolApprovalRequired

// Agent thinking
AgentEvent::Type::AgentThinking
AgentEvent::Type::AgentPlanning
AgentEvent::Type::AgentExecuting

// Context management
AgentEvent::Type::ContextAdded
AgentEvent::Type::ContextCleared

// Hooks and plugins
AgentEvent::Type::HookExecuting
AgentEvent::Type::HookCompleted
AgentEvent::Type::PluginLoaded
AgentEvent::Type::PluginUnloaded
```

### Event Publishing

```cpp
// Publish custom event
engine->eventBus()->publishEvent(
    AgentEvent::Type::ToolCalled,
    "my_tool",
    QJsonObject{
        {"param1", "value1"},
        {"param2", 42}
    }
);
```

### Event Subscription with Priority

```cpp
// Priority: 0-100 (higher = earlier execution)
// Critical listeners: 90-100
// Normal listeners: 50-89
// Low priority: 0-49

engine->eventBus()->subscribe(
    AgentEvent::Type::ToolFailed,
    [](const AgentEvent &event) {
        // Rollback on tool failure
        engine->strategyManager()->rollback(event.data["callId"].toString());
    },
    95  // Execute before other handlers
);
```

---

## 🛡️ Rule Engine Integration

### Creating Custom Rules

```cpp
// Create a rule to prevent destructive operations
Rule safetyRule;
safetyRule.id = "prevent-destructive";
safetyRule.name = "Prevent Destructive Operations";
safetyRule.priority = 100;
safetyRule.applicableTools = {"shell_tool", "file_tool"};
safetyRule.condition = "contains(operation, 'delete') || contains(operation, 'remove')";

engine->ruleEngine()->registerRule(safetyRule, 
    [](const RuleEvaluationContext &ctx) -> RuleResult {
        RuleResult result;
        result.matched = ctx.event.data["operation"].toString().contains("delete");
        result.allowed = false;  // Block deletion
        result.reason = "Destructive operations are blocked";
        return result;
    }
);
```

### Checking Operation Safety

```cpp
bool ToolExecutor::isSafeToExecute(const ToolCall &call) {
    RuleEvaluationContext ctx;
    ctx.source = call.toolName;
    ctx.event.data = QJsonObject::fromVariantMap(call.parameters);
    
    QString blockReason;
    return engine->ruleEngine()->isOperationAllowed(ctx, blockReason);
}
```

---

## 🌐 MCP Integration

### Registering MCP Servers

```cpp
// Register a local MCP server
MCPServer server;
server.id = "my-analyzer";
server.name = "Code Analyzer";
server.type = MCPServer::Type::StdIO;
server.command = "/usr/local/bin/analyzer";
server.autoStart = true;

engine->mcpManager()->registerServer(server);
```

### Calling MCP Tools

```cpp
// List available tools
auto tools = engine->mcpManager()->getAllTools();
for (const auto &tool : tools) {
    qDebug() << "Tool:" << tool.name 
             << "Server:" << tool.serverId;
}

// Call a tool
MCPToolCall call;
call.serverId = "my-analyzer";
call.toolName = "analyze_code";
call.arguments = QJsonObject{{"code", sourceCode}};

auto result = engine->mcpManager()->callTool(call);
if (result.success) {
    qDebug() << "Result:" << result.result;
}
```

---

## 🎮 Execution Strategy Integration

### Risk-Based Approval

```cpp
void DecisionMaker::handleToolCall(const ToolCall &call) {
    // Assess risk
    auto risk = engine->strategyManager()->assessToolRisk(
        call.toolName,
        QJsonObject::fromVariantMap(call.parameters)
    );
    
    // Log risk assessment
    qDebug() << "Risk level:" << risk.level
             << "Score:" << risk.score
             << "Reason:" << risk.reason;
    
    // Get strategy
    auto strategy = engine->strategyManager()->getStrategyForTool(call.toolName);
    
    // Make decision
    if (engine->strategyManager()->needsApproval(risk, strategy)) {
        requestUserApproval(call, risk.reason);
    } else {
        executeTool(call);
    }
}
```

### State Rollback

```cpp
void ToolExecutor::executeWithRollback(const ToolCall &call) {
    // Capture state before execution
    auto stateId = engine->strategyManager()->captureState();
    
    try {
        executeTool(call);
        // Success - don't rollback
    } catch (const std::exception &e) {
        // Failure - rollback state
        qWarning() << "Execution failed, rolling back:" << e.what();
        engine->strategyManager()->rollback(stateId);
    }
}
```

---

## 🧪 Testing Integration

### Unit Test Pattern

```cpp
// In your test file
void TestToolExecution::testSafeExecution() {
    AgentEngine engine;
    
    // Set up restrictive strategy
    auto restrictedStrategy = engine.strategyManager()->getRestrictedStrategy();
    
    // Try to execute dangerous command
    ToolCall call;
    call.toolName = "shell_tool";
    call.parameters["command"] = "rm -rf /";
    
    auto risk = engine.strategyManager()->assessToolRisk(
        call.toolName,
        QJsonObject::fromVariantMap(call.parameters)
    );
    
    ASSERT_EQ(risk.level, "critical");
    ASSERT_TRUE(engine.strategyManager()->needsApproval(risk, restrictedStrategy));
}
```

---

## 📊 Monitoring Integration

### Getting Statistics

```cpp
// Event statistics
auto eventStats = engine->eventBus()->getStatistics();
qDebug() << "Total events:" << eventStats["totalEvents"];
qDebug() << "Events by type:" << eventStats["eventsByType"];

// Rule statistics
auto ruleStats = engine->ruleEngine()->getStatistics();
qDebug() << "Rules triggered:" << ruleStats["triggers"];
qDebug() << "Operations blocked:" << ruleStats["blocked"];

// Context statistics
auto ctxStats = engine->contextManager()->getStatistics();
qDebug() << "Context items:" << ctxStats["totalItems"];
qDebug() << "Context size (tokens):" << ctxStats["contextSize"];

// MCP statistics
auto mcpStats = engine->mcpManager()->getToolStatistics();
qDebug() << "Tool calls:" << mcpStats["calls"];
qDebug() << "Failed calls:" << mcpStats["failures"];
```

---

## 🔗 Integration Checklist

- [ ] CMakeLists.txt includes all 6 new .cpp files ✅ DONE
- [ ] AgentEngine.h has forward declarations ✅ DONE
- [ ] AgentEngine.h has member variables ✅ DONE
- [ ] AgentEngine.h has getter methods ✅ DONE
- [ ] AgentEngine.cpp includes all headers ✅ DONE
- [ ] AgentEngine constructor initializes all managers ✅ DONE
- [ ] EventBus connections are set up in constructor ✅ DONE
- [ ] Your UI components use the managers
- [ ] Your tool execution uses rule engine
- [ ] Your approval system uses strategy manager
- [ ] Your logging uses event bus

---

## 🚀 Next Steps

1. **Compile**: Run `cmake` and `make` to build the project
2. **Test**: Run unit tests to verify integration
3. **UI Integration**: Connect UI components to slash command manager
4. **Tool Integration**: Update tool execution to use rule engine
5. **Approval Integration**: Update approval system to use strategy manager
6. **Monitoring**: Set up logging for events

---

## 🐛 Troubleshooting

### Managers not accessible
**Problem**: `engine->slashCommandManager()` returns nullptr
**Solution**: Ensure AgentEngine was properly initialized in your controller

### Events not being published
**Problem**: Subscribe handlers are not being called
**Solution**: Check that event.publishEvent() is called with correct event type

### Rules not blocking operations
**Problem**: Operations execute despite blocking rules
**Solution**: Verify isOperationAllowed() is called before execution

### MCP servers not connecting
**Problem**: MCP tools are not available
**Solution**: Check server command path and permissions, verify log output

---

## 📚 Related Files

- [AGENT_RUNTIME_IMPLEMENTATION.md](AGENT_RUNTIME_IMPLEMENTATION.md) - Detailed component documentation
- [AGENT_RUNTIME_QUICK_REFERENCE.md](AGENT_RUNTIME_QUICK_REFERENCE.md) - Code examples and patterns
- [AGENT_RUNTIME_ENHANCED.md](AGENT_RUNTIME_ENHANCED.md) - Project completion summary

---

**Document Date**: 2026-06-09  
**Status**: ✅ Integration Complete  
**Next Phase**: Unit Tests & UI Integration
