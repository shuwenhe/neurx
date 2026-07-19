# Agent Runtime English textimplementationEnglish text (2026-06-09)

## English textimplementationEnglish text

### 1. **SlashCommandManager** (src/agent/SlashCommandManager.h/.cpp)
SlashEnglish textsystem,supportClaude CodeEnglish text

**English text:**
- English text
- English text
- English text: /code-review, /new-sdk-app, /feature-dev, /plugin-create, /help, /commit
- English text
- English textparameterEnglish text
- English text

**English text:** ~700 English text

**English text:**
```cpp
// English text
registerCommand(cmd, handler);

// English text
executeCommand("/code-review file.ts", context);

// English text
getCompletions("/code");
```

---

### 2. **EventBus** (src/agent/EventBus.h/.cpp)
English text,supportEnglish text

**English text:**
- English text(English textstepEnglish textstep)
- English text
- English text
- English textstatistics
- English text(English text)
- English text

**English text:**
- ExecutionStarted, ExecutionCompleted, ExecutionFailed
- ToolCalled, ToolCompleted, ToolFailed
- AgentThinking, AgentPlanning, AgentExecuting
- ContextAdded, ContextCleared
- HookExecuting, HookCompleted
- PluginLoaded, PluginUnloaded, PluginActivated, PluginDeactivated
- Custom events

**English text:** ~600 English text

**English text:**
```cpp
// English text
publishEvent(AgentEvent::Type::ExecutionStarted, "executor", data);

// English text
subscribe(AgentEvent::Type::ToolCalled, [](const AgentEvent &e) { ... });

// English textstatistics
getStatistics();
eventHistory(100);
```

---

### 3. **RuleEngine** (src/agent/RuleEngine.h/.cpp)
English text,English text

**English text:**
- English textmanagement
- English text
- English textevaluation
- English text: English textrm -rf, English textfileEnglish text
- English text/English text
- English textstatistics

**English text:**
- Validation (English text)
- Action (English text)
- Transform (English text)

**English text:**
- OnToolCall, OnCommandExecution
- OnContextChange, OnEventPublished
- Custom

**English text:** ~600 English text

**English text:**
```cpp
// English text
registerRule(rule, evaluator);

// evaluationEnglish text
evaluateRules(context);

// English text
isOperationAllowed(context, reason);
```

---

### 4. **MCPManager** (src/agent/MCPManager.h/.cpp)
Model Context Protocol English text

**English text:**
- MCPEnglish textmanagement
- English text: StdIO, SSE, HTTP, WebSocket
- toolEnglish text
- English textmanagement
- English text
- toolstatistics

**toolEnglish text:**
- toolEnglish text
- toolparameterEnglish text
- English textmanagement

**English text:** ~550 English text

**English text:**
```cpp
// English text
registerServer(server);

// English texttool
callTool(mcpToolCall);

// English texttool
getAllTools();

// English text
getAllServersHealth();
```

---

### 5. **ContextManager** (src/agent/ContextManager.h/.cpp)
English textmanagementsystem

**English text:**
- English text(file, English text, English text)
- English textranking
- English textmanagement
- English textrecover
- English textsearch
- English text

**English text:**
- file: filecontent
- selection: English text
- note: English text
- custom: English text

**English text:** ~500 English text

**English text:**
```cpp
// English textfileEnglish text
addFileContext("/path/file.ts", 10, 50);

// English text
addSelectionContext(code, "editor");

// English text
getContextAsText();

// English text
createSnapshot();
```

---

### 6. **ExecutionStrategyManager** (src/agent/ExecutionStrategyManager.h/.cpp)
English textmanagement

**English text:**
- English textmanagement
- English textevaluation(0-100English text)
- English text
- stateEnglish textrecover
- English textsupport
- English text: Safe, Normal, Permissive, Restricted

**English text:**
- toolEnglish text(shell, delete, writeEnglish text)
- parametercontent(rm -rf, DROP TABLEEnglish text)
- English text
- English text

**English text:** ~550 English text

**English text:**
```cpp
// English text
registerStrategy(strategy);

// English textevaluation
assessToolRisk(toolName, parameters);

// English text
needsApproval(risk, strategy);

// statemanagement
captureState();
rollback(operationId);
```

---

## English text

### English text
- ✅ **HookManager** - English texthooks (PreToolUse, PostToolUseEnglish text)
- ✅ **CommandManager** - English textsystem
- ✅ **SkillManager** - English textsystem
- ✅ **AgentEngine** - English text
- ✅ **ExecutionEngine** - English text
- ✅ **ApprovalManager** - English textmanagement
- ✅ **PluginManager** - pluginsystem

---

## English text

### 1. AgentEngineEnglish text
```cpp
class AgentEngine {
    // English text
    std::unique_ptr<SlashCommandManager> m_slashCommands;
    std::unique_ptr<EventBus> m_eventBus;
    std::unique_ptr<RuleEngine> m_ruleEngine;
    std::unique_ptr<MCPManager> m_mcpManager;
    std::unique_ptr<ContextManager> m_contextManager;
    std::unique_ptr<ExecutionStrategyManager> m_strategyManager;
};
```

### 2. English textpipeline
```
English textinput
  ↓
SlashCommandManager (English text/commands)
  ↓
EventBus (English text)
  ↓
RuleEngine (English text)
  ↓
ContextManager (English text)
  ↓
ExecutionStrategyManager (evaluationEnglish text, English text)
  ↓
MCPManager (English texttool)
  ↓
HookManager (English texthooks)
  ↓
Executor (English texttool)
```

---

## useexample

### 1. Slash Command
```cpp
// English textinput: /code-review file.ts
auto result = slashCommandManager->executeCommand("/code-review file.ts", context);
```

### 2. Event System
```cpp
// English texttoolEnglish text
eventBus->publishEvent(AgentEvent::Type::ToolCalled, "shell_tool", data);

// English text
auto listenerId = eventBus->subscribe(
    AgentEvent::Type::ToolCompleted,
    [](const AgentEvent &e) { qDebug() << "Tool completed"; }
);
```

### 3. Rule Engine
```cpp
// evaluationEnglish text
QString blockReason;
if (!ruleEngine->isOperationAllowed(context, blockReason)) {
    qDebug() << "Operation blocked:" << blockReason;
    return;
}
```

### 4. Context Management
```cpp
// English text
contextManager->addSelectionContext(selectedCode, "editor");
contextManager->addNote("Fix the memory leak in this function");

// English textLLM
auto contextJSON = contextManager->getContextAsJSON();
```

### 5. Risk Assessment
```cpp
// evaluationEnglish text
auto risk = strategyManager->assessToolRisk("shell_tool", params);

// English textRequiredEnglish text
auto strategy = strategyManager->getStrategyForTool("shell_tool");
if (strategyManager->needsApproval(risk, strategy)) {
    // requestEnglish text
}
```

---

## fileEnglish text

| file | English text | Description |
|------|------|------|
| src/agent/SlashCommandManager.h | 280 | SlashEnglish textsystemEnglish textfile |
| src/agent/SlashCommandManager.cpp | 420 | SlashEnglish textsystemimplementation |
| src/agent/EventBus.h | 340 | English textfile |
| src/agent/EventBus.cpp | 330 | English textimplementation |
| src/agent/RuleEngine.h | 280 | English textfile |
| src/agent/RuleEngine.cpp | 350 | English textimplementation |
| src/agent/MCPManager.h | 310 | MCPmanagementEnglish textfile |
| src/agent/MCPManager.cpp | 300 | MCPmanagementEnglish textimplementation |
| src/agent/ContextManager.h | 250 | English textmanagementEnglish textfile |
| src/agent/ContextManager.cpp | 300 | English textmanagementEnglish textimplementation |
| src/agent/ExecutionStrategyManager.h | 280 | English textmanagementEnglish textfile |
| src/agent/ExecutionStrategyManager.cpp | 350 | English textmanagementEnglish textimplementation |
| **English text** | **~3600** | **English text** |

---

## English text

### ✅ English textimplementationEnglish text

1. **Slash Commands** - English textClaude CodeEnglish text /command support
2. **Event Bus** - English text/English textsystem
3. **Rule Engine** - English text
4. **MCP Integration** - English texttoolEnglish text
5. **Context Management** - English textmanagement
6. **Execution Strategies** - English textevaluationEnglish text
7. **Built-in Commands** - code-review, new-sdk-app, feature-devEnglish text
8. **State Management** - English textsupport
9. **Event History** - English textstatistics
10. **Tool Integration** - MCPtoolEnglish text

### 📝 English textimplementationEnglish text

1. **WebSocket MCP** - English textsupport
2. **Advanced Context Compression** - English textoptimize
3. **ML-based Risk Assessment** - English textevaluation
4. **Distributed Execution** - English text
5. **Advanced Rollback** - English text

---

## compileEnglish text

### CMakeLists.txt English text

```cmake
target_sources(neurx_ui PRIVATE
    src/agent/SlashCommandManager.cpp
    src/agent/EventBus.cpp
    src/agent/RuleEngine.cpp
    src/agent/MCPManager.cpp
    src/agent/ContextManager.cpp
    src/agent/ExecutionStrategyManager.cpp
)
```

---

## English textstep

1. **English textAgentEngine** - English textmanagementEnglish textmainagentEnglish text
2. **QMLEnglish text** - English textQMLEnglish textUI
3. **English textoptimize** - English textdataEnglish textoptimize
4. **English text** - APIEnglish text
5. **testEnglish text** - English texttestEnglish texttest
