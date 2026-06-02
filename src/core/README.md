# Neurx Core Agent System

The Core Agent System provides a unified interface integrating all 15 neurx subsystems into a single, easy-to-use agent API.

## Overview

The Core Agent integrates:
1. **Memory System** - Knowledge and data storage
2. **Tool Registry** - Tool management and execution
3. **LLM Extensions** - Language model integration
4. **Logging & Analytics** - Event tracking and monitoring
5. **Execution Engine** - Task execution
6. **State Manager** - State management
7. **Goal Manager** - Goal tracking
8. **Skill Manager** - Skill learning
9. **Approval Engine** - Approval workflows
10. **Sandbox Manager** - Safe execution environment
11. **Plugin Manager** - Extension system
12. **Config Manager** - Configuration management
13. **Thread Manager** - Threading and concurrency
14. **Test Framework** - Testing support
15. **Integration Layer** - System orchestration

## Architecture

The Core Agent uses a layered architecture:

```
┌─────────────────────────────────────┐
│      CoreAgent Interface            │
├─────────────────────────────────────┤
│    DefaultCoreAgent Implementation   │
├─────────────────────────────────────┤
│    15 Integrated Subsystems          │
└─────────────────────────────────────┘
```

## Usage Examples

### Initialization

```cpp
#include "DefaultCoreAgent.h"

// Create agent
auto agent = std::make_shared<DefaultCoreAgent>();

// Configure
CoreAgentConfig config;
config.agentId = "agent-001";
config.agentName = "MyAgent";
config.enableMemory = true;
config.enableTools = true;
config.enableLLM = true;

// Initialize
if (agent->initialize(config)) {
    qDebug() << "Agent initialized";
}

// Start
if (agent->start()) {
    qDebug() << "Agent started";
}
```

### Processing Requests

```cpp
// Create request
AgentRequest request;
request.requestId = QUuid::createUuid().toString();
request.userId = "user123";
request.prompt = "What is the capital of France?";
request.maxTokens = 500;

// Process synchronously
AgentResponse response = agent->processRequest(request);

if (response.success) {
    qDebug() << "Result:" << response.result;
    qDebug() << "Processing time:" << response.processingTimeMs << "ms";
} else {
    qDebug() << "Error:" << response.error;
}

// Process asynchronously
auto responseId = agent->processRequestAsync(request,
    [](const AgentResponse &resp) {
        qDebug() << "Async response:" << resp.result;
    });
```

### Memory Management

```cpp
// Store memory
agent->storeMemory("user_preference", "dark_mode");
agent->storeMemory("conversation_context", QVariantMap{
    {"topic", "science"},
    {"level", "advanced"}
});

// Retrieve memory
auto pref = agent->getMemory("user_preference");
qDebug() << "Preference:" << pref;

// Search memories
auto results = agent->searchMemories("conversation");
for (const auto &result : results) {
    qDebug() << "Found:" << result["key"];
}

// Get memory size
int memSize = agent->getMemorySize();
qDebug() << "Memory entries:" << memSize;

// Clear memory
agent->clearMemory("user_preference");
```

### Tool Management

```cpp
// Register tools
agent->registerTool("calculator", "calc-001");
agent->registerTool("weather", "weather-001");
agent->registerTool("translator", "trans-001");

// Get available tools
auto tools = agent->getAvailableTools();
for (const auto &tool : tools) {
    qDebug() << "Tool:" << tool;
}

// Execute tool
QVariantMap params;
params["expression"] = "2 + 2";

auto result = agent->executeTool("calculator", params);
qDebug() << "Calculation result:" << result;

// Get tool info
auto info = agent->getToolInfo("calculator");
qDebug() << "Tool ID:" << info["id"];
```

### Skill Management

```cpp
// Learn skill
agent->learnSkill("cooking", "Recipe preparation and cooking");
agent->learnSkill("programming", "Write and debug code");
agent->learnSkill("writing", "Write articles and essays");

// Get available skills
auto skills = agent->getAvailableSkills();
qDebug() << "Learned skills:" << skills.size();

// Execute skill
QVariantMap skillParams;
skillParams["recipe"] = "pasta";

auto skillResult = agent->executeSkill("cooking", skillParams);
qDebug() << "Skill result:" << skillResult;

// Get skill info
auto skillInfo = agent->getSkillInfo("programming");
qDebug() << "Skill:" << skillInfo["name"];
qDebug() << "Proficiency:" << skillInfo["proficiency"];

// Unlearn skill
agent->unlearnSkill("cooking");
```

### Goal Management

```cpp
// Create goals
auto goalId = agent->createGoal("write_blog", "Write a blog post about AI");
auto goalId2 = agent->createGoal("learn_rust", "Learn Rust programming");

// Get active goals
auto goals = agent->getActiveGoals();
qDebug() << "Active goals:" << goals.size();

// Update goal progress
agent->updateGoal(goalId, QVariantMap{
    {"progress", 0.5},
    {"status", "in_progress"}
});

// Get goal progress
float progress = agent->getGoalProgress(goalId);
qDebug() << "Progress:" << progress * 100 << "%";

// Complete goal
agent->completeGoal(goalId);
qDebug() << "Goal completed";
```

### LLM Integration

```cpp
// Generate completion
QString prompt = "Explain quantum computing in simple terms";
QString completion = agent->generateCompletion(prompt, 200);
qDebug() << "Completion:" << completion;

// Chat interaction
QString message = "What's the weather like?";
QString response = agent->chat(message);
qDebug() << "Chat response:" << response;

// Summarize text
QString article = "Long article text here...";
QString summary = agent->summarizeText(article);
qDebug() << "Summary:" << summary;

// Translate text
QString text = "Hello, world!";
QString translated = agent->translateText(text, "Spanish");
qDebug() << "Translation:" << translated;
```

### Execution History

```cpp
// Get execution history
auto history = agent->getExecutionHistory(50);
for (const auto &exec : history) {
    qDebug() << "Execution:" << exec["timestamp"];
    qDebug() << "Success:" << exec["success"];
    qDebug() << "Time:" << exec["processingTime"] << "ms";
}

// Get execution details
auto details = agent->getExecutionDetails("execution-id");
qDebug() << "Details:" << details;
```

### Approval Workflow

```cpp
// Request approval
auto approvalId = agent->requestApproval(
    "delete_file",
    "User requested file deletion"
);

// Check pending approvals
auto pending = agent->getPendingApprovals();
qDebug() << "Pending approvals:" << pending.size();

// Check if approval pending
if (agent->isApprovalPending(approvalId)) {
    qDebug() << "Awaiting approval";
}
```

### Logging & Analytics

```cpp
// Log custom event
agent->logEvent("custom_event", QVariantMap{
    {"action", "button_clicked"},
    {"button_id", "submit_btn"}
});

// Get logs
auto logs = agent->getLogs(100);
for (const auto &log : logs) {
    qDebug() << "Event:" << log["type"];
    qDebug() << "Time:" << log["timestamp"];
}

// Get analytics
auto analytics = agent->getAnalytics();
qDebug() << "Total requests:" << analytics["total_requests"];
qDebug() << "Success rate:" << analytics["success_rate"];
qDebug() << "Skills learned:" << analytics["skills_learned"];
```

### Configuration

```cpp
// Get current configuration
auto config = agent->getConfiguration();
qDebug() << "Agent name:" << config.agentName;
qDebug() << "Version:" << config.version;

// Update configuration
agent->updateConfiguration("custom_setting", "value");
agent->updateConfiguration("max_retries", 3);

// Get config value
auto setting = agent->getConfigValue("custom_setting");
qDebug() << "Setting:" << setting;
```

### State Management

```cpp
// Get current state
AgentState state = agent->getState();
qDebug() << "State:" << (int)state;

// Check if ready
if (agent->isReady()) {
    qDebug() << "Agent is ready to process requests";
}

// Get statistics
auto stats = agent->getStatistics();
qDebug() << "Total requests:" << stats.totalRequests;
qDebug() << "Success rate:" << stats.successRate;
qDebug() << "Average latency:" << stats.averageLatency << "ms";
```

### Health & Diagnostics

```cpp
// Get health status
auto health = agent->getHealthStatus();
qDebug() << "State:" << health["state"];
qDebug() << "Memory size:" << health["memory_size"];
qDebug() << "Tools:" << health["tools"];

// Run diagnostics
QString diagnostics = agent->runDiagnostics();
qDebug() << diagnostics;

// Get system report
QString report = agent->getSystemReport();
qDebug() << report;

// Get version
qDebug() << "Agent version:" << agent->getVersion();

// Get agent ID
qDebug() << "Agent ID:" << agent->getAgentId();
```

### Signal Connections

```cpp
// State changed
connect(agent.get(), &CoreAgent::stateChanged,
    [](AgentState oldState, AgentState newState) {
        qDebug() << "State changed from" << (int)oldState << "to" << (int)newState;
    });

// Request received
connect(agent.get(), &CoreAgent::requestReceived,
    [](const AgentRequest &request) {
        qDebug() << "Request received:" << request.requestId;
    });

// Response generated
connect(agent.get(), &CoreAgent::responseGenerated,
    [](const AgentResponse &response) {
        qDebug() << "Response:" << response.result;
    });

// Goal completed
connect(agent.get(), &CoreAgent::goalCompleted,
    [](const QString &goalId) {
        qDebug() << "Goal completed:" << goalId;
    });

// Skill learned
connect(agent.get(), &CoreAgent::skillLearned,
    [](const QString &skillName) {
        qDebug() << "Skill learned:" << skillName;
    });

// Error occurred
connect(agent.get(), &CoreAgent::errorOccurred,
    [](int errorCode, const QString &message) {
        qDebug() << "Error:" << errorCode << message;
    });
```

### Shutdown

```cpp
// Shutdown gracefully
if (agent->shutdown()) {
    qDebug() << "Agent shutdown successfully";
}
```

## Best Practices

1. **Initialize once** - Create agent once and reuse
2. **Handle errors** - Check response.success before using results
3. **Use async** - For long-running operations, use async API
4. **Monitor state** - Check agent state before processing
5. **Store context** - Use memory system for conversation context
6. **Register tools** - Register all available tools upfront
7. **Track goals** - Use goals to track multi-step tasks
8. **Log events** - Log custom events for debugging
9. **Check analytics** - Monitor agent performance
10. **Handle signals** - Connect to signals for real-time updates

## Integration Points

- **Memory**: Stores context and knowledge
- **Tools**: Executes external actions
- **LLM**: Generates text and responses
- **Skills**: Executes learned capabilities
- **Goals**: Tracks and manages objectives
- **Logging**: Records all activities
- **Approvals**: Manages request approvals
- **Execution**: Tracks task execution
- **State**: Maintains agent state

## Performance Characteristics

- **Request latency**: ~100-1000ms (simulated)
- **Memory overhead**: ~1-5MB base
- **Concurrent requests**: Configurable (default: 10)
- **Log rotation**: 10,000 entries max
- **History retention**: Configurable limit

## Architecture Benefits

- **Unified interface**: Single API for all features
- **Easy integration**: Include header and use
- **Extensible**: Add new subsystems easily
- **Thread-safe**: Mutex protected operations
- **Signal-based**: React to agent events
- **Async support**: Non-blocking operations
