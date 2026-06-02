# Neurx Tool Registry System

The Tool Registry System manages tool registration, discovery, execution, and orchestration for agent capabilities.

## Overview

The tool registry provides:
- Dynamic tool registration and loading
- Tool discovery and search
- Tool execution with parameters
- Tool chaining and workflows
- Permission management
- Execution monitoring and statistics

## Core Components

### Tool Categories

```cpp
enum class ToolCategory {
    FileSystem,     // File operations
    DataProcessing, // Data transformation
    Computation,    // Calculations
    Communication,  // API calls, messaging
    Database,       // Database operations
    DevOps,         // Deployment, infrastructure
    CodeAnalysis,   // Code inspection
    Integration,    // Third-party integrations
    Custom          // Custom user tools
};
```

### Tool Status

```cpp
enum class ToolStatus {
    Available,    // Ready to use
    Loading,      // Being loaded
    Loaded,       // Loaded
    Active,       // Active
    Disabled,     // Disabled
    Failed,       // Failed to load
    Deprecated    // Deprecated version
};
```

### Tool Parameters

```cpp
struct ToolParameter {
    QString name;
    ParameterType type;           // String, Integer, Float, etc.
    QString description;
    QVariant defaultValue;
    bool required = true;
    QVector<QVariant> enumValues; // Valid values if enum
    QString pattern;              // Regex validation
};
```

### Tool Metadata

```cpp
struct ToolMetadata {
    QString toolId;               // Unique ID
    QString name;                 // Display name
    QString version;              // Semantic version
    QString description;          // What it does
    QString category;             // Tool category
    
    QString author;               // Creator
    QString license;              // License type
    QStringList tags;             // Search tags
    float rating;                 // User rating
};
```

### Tool Instance

```cpp
struct ToolInstance {
    QString toolId;
    ToolStatus status;
    
    ToolMetadata metadata;
    QVector<ToolCapability> capabilities;  // What it can do
    
    QVariantMap config;           // Configuration
    int executionCount = 0;       // Usage count
    float averageExecutionTime;   // Performance
};
```

## Usage Examples

### Tool Registration

```cpp
// Create tool instance
ToolInstance tool;
tool.metadata.name = "Python Executor";
tool.metadata.description = "Execute Python code";
tool.metadata.version = "1.0.0";
tool.metadata.tags = {"python", "code", "execution"};

// Define capabilities
ToolCapability capability;
capability.name = "execute_code";
capability.description = "Execute Python code";

ToolParameter codeParam;
codeParam.name = "code";
codeParam.type = ParameterType::String;
codeParam.description = "Python code to execute";
codeParam.required = true;

capability.parameters.append(codeParam);
capability.returnType.type = ParameterType::String;

tool.capabilities.append(capability);

// Register tool
auto toolId = registry->registerTool(tool, [](bool success) {
    qDebug() << "Tool registered:" << success;
});
```

### Tool Discovery

```cpp
// Get all tools
auto tools = registry->getAllTools();

// Get specific tool
auto tool = registry->getTool(toolId);

// Get tools by category
auto fsTools = registry->getToolsByCategory(ToolCategory::FileSystem);

// Get tools by tag
auto pythonTools = registry->getToolsByTag("python");

// Find tools with capability
auto executors = registry->findToolsByCapability("execute_code");

// Search tools
ToolQuery query;
query.searchText = "Python";
query.onlyAvailable = true;

registry->searchTools(query, [](const QVector<ToolSearchResult> &results) {
    for (const auto &result : results) {
        qDebug() << "Found:" << result.tool.metadata.name
                 << "Relevance:" << result.relevanceScore;
    }
});
```

### Tool Loading

```cpp
// Load tool
registry->loadTool(toolId, [](bool success, const QString &error) {
    if (success) {
        qDebug() << "Tool loaded";
    } else {
        qDebug() << "Load error:" << error;
    }
});

// Activate tool
registry->activateTool(toolId, [](bool success) {
    qDebug() << "Tool activated:" << success;
});

// Check status
if (registry->isToolAvailable(toolId)) {
    qDebug() << "Tool is ready to use";
}

auto status = registry->getToolStatus(toolId);
```

### Tool Execution

```cpp
// Simple execution
QVariantMap params;
params["code"] = "print('Hello, World!')";

registry->executeTool(toolId, params, 
    [](const ToolExecutionResult &result) {
        if (result.success) {
            qDebug() << "Output:" << result.result;
            qDebug() << "Time:" << result.executionTime << "ms";
        } else {
            qDebug() << "Error:" << result.errorMessage;
        }
    });

// Execute specific capability
registry->executeToolCapability(toolId, "execute_code", params,
    [](const ToolExecutionResult &result) {
        qDebug() << "Capability execution:" << result.success;
    },
    5000);  // 5 second timeout

// Cancel execution
registry->cancelExecution(executionId, [](bool success) {
    qDebug() << "Execution cancelled";
});

// Get execution status
auto result = registry->getExecutionStatus(executionId);
qDebug() << "Status:" << result.success;
```

### Parameter Validation

```cpp
// Validate parameters
QString error;
if (!registry->validateParameters(toolId, params, error)) {
    qDebug() << "Validation error:" << error;
}

// Validate capability parameters
if (!registry->validateCapabilityParameters(toolId, "execute_code", params, error)) {
    qDebug() << "Invalid parameters:" << error;
}

// Check dependencies
if (!registry->checkDependencies(toolId, error)) {
    qDebug() << "Dependency error:" << error;
}
```

### Tool Chains

```cpp
// Create a chain
ToolChain chain;
chain.name = "Data Pipeline";
chain.strategy = ChainStrategy::Sequential;

// Add steps
ToolChainStep step1;
step1.toolId = extractToolId;
step1.stepNumber = 1;
step1.parameters["format"] = "csv";

ToolChainStep step2;
step2.toolId = transformToolId;
step2.stepNumber = 2;
step2.parameters["operation"] = "normalize";

chain.steps.append(step1);
chain.steps.append(step2);

// Create chain
auto chainId = registry->createToolChain(chain, [](bool success) {
    qDebug() << "Chain created";
});

// Execute chain
QVariantMap chainParams;
registry->executeToolChain(chainId, chainParams,
    [](const QVector<ToolExecutionResult> &results) {
        for (const auto &result : results) {
            qDebug() << "Step result:" << result.success;
        }
    });

// Get chain
auto chain = registry->getToolChain(chainId);

// List chains
auto chains = registry->listToolChains();

// Delete chain
registry->deleteToolChain(chainId, [](bool success) {
    qDebug() << "Chain deleted";
});
```

### Permissions

```cpp
// Grant permission
registry->grantPermission(toolId, userId, Permission::Execute, 
    [](bool success) {
        qDebug() << "Permission granted";
    });

// Check permission
if (registry->hasPermission(toolId, userId, Permission::Execute)) {
    qDebug() << "User can execute tool";
}

// Get permissions
auto perms = registry->getPermissions(toolId);
for (const auto &perm : perms) {
    qDebug() << "Principal:" << perm.principalId;
}

// Revoke permission
registry->revokePermission(toolId, userId, Permission::Execute,
    [](bool success) {
        qDebug() << "Permission revoked";
    });
```

### Tool Hooks

```cpp
// Register hook
ToolHook hook;
hook.toolId = toolId;
hook.type = ToolHookType::BeforeExecution;
hook.scriptLanguage = "python";
hook.scriptPath = "/hooks/validate.py";

registry->registerHook(hook, [](bool success) {
    qDebug() << "Hook registered";
});

// Get hooks
auto hooks = registry->getHooks(toolId);
for (const auto &h : hooks) {
    qDebug() << "Hook:" << h.hookId << "Type:" << static_cast<int>(h.type);
}

// Unregister hook
registry->unregisterHook(hookId, [](bool success) {
    qDebug() << "Hook unregistered";
});
```

### Configuration

```cpp
// Set tool configuration
QVariantMap toolConfig;
toolConfig["timeout"] = 30000;
toolConfig["maxRetries"] = 3;

registry->setToolConfiguration(toolId, toolConfig, [](bool success) {
    qDebug() << "Config set";
});

// Get configuration
auto config = registry->getToolConfiguration(toolId);

// Global configuration
QVariantMap globalConfig;
globalConfig["apiKey"] = "secret";
registry->setGlobalConfiguration(globalConfig);

auto gConfig = registry->getGlobalConfiguration();
```

### Statistics and Monitoring

```cpp
// Get tool statistics
auto stats = registry->getToolStatistics(toolId);
qDebug() << "Total executions:" << stats.totalExecutions;
qDebug() << "Success rate:" << stats.successRate;
qDebug() << "Avg time:" << stats.averageExecutionTime << "ms";

// Get registry statistics
auto regStats = registry->getRegistryStatistics();
qDebug() << "Total tools:" << regStats["totalTools"];
qDebug() << "Active tools:" << regStats["activeTools"];

// Get execution history
auto history = registry->getExecutionHistory(toolId, 50);
for (const auto &result : history) {
    qDebug() << "Execution:" << result.executionTime << "ms";
}

// Clear history
registry->clearExecutionHistory(toolId, [](bool success) {
    qDebug() << "History cleared";
});
```

### Maintenance

```cpp
// Load all tools
registry->reloadAllTools([](int loaded, int failed) {
    qDebug() << "Loaded:" << loaded << "Failed:" << failed;
});

// Clean up failed tools
registry->cleanupFailedTools([](int removed) {
    qDebug() << "Removed" << removed << "failed tools";
});

// Deactivate tool
registry->deactivateTool(toolId, [](bool success) {
    qDebug() << "Tool deactivated";
});

// Unload tool
registry->unloadTool(toolId, [](bool success) {
    qDebug() << "Tool unloaded";
});

// Unregister tool
registry->unregisterTool(toolId, [](bool success) {
    qDebug() << "Tool unregistered";
});
```

## Signals and Events

```cpp
connect(registry.get(), &ToolRegistry::toolRegistered,
    [](const QString &toolId) {
        qDebug() << "Tool registered:" << toolId;
    });

connect(registry.get(), &ToolRegistry::toolLoaded,
    [](const QString &toolId) {
        qDebug() << "Tool loaded:" << toolId;
    });

connect(registry.get(), &ToolRegistry::executionStarted,
    [](const QString &toolId, const QString &executionId) {
        qDebug() << "Execution started";
    });

connect(registry.get(), &ToolRegistry::executionCompleted,
    [](const QString &executionId, bool success) {
        qDebug() << "Execution completed:" << success;
    });

connect(registry.get(), &ToolRegistry::chainExecuted,
    [](const QString &chainId) {
        qDebug() << "Chain executed:" << chainId;
    });
```

## Best Practices

1. **Validate parameters** - Check parameters before execution
2. **Check dependencies** - Ensure tool dependencies are available
3. **Monitor execution** - Track execution times and success rates
4. **Use chains** - Group related tool calls together
5. **Manage permissions** - Grant minimum necessary permissions
6. **Clean up history** - Clear old execution history
7. **Handle errors** - Properly handle execution errors
8. **Use hooks** - Add validation or post-processing hooks
9. **Cache tools** - Load frequently used tools once
10. **Document tools** - Provide clear descriptions and examples

## Architecture

The tool registry uses:
- **Registry pattern** - Central registry for tool management
- **Factory pattern** - Tool instance creation
- **Chain pattern** - Sequential/parallel tool execution
- **Permission pattern** - Role-based access control
- **Hook pattern** - Event-based customization
- **Async callbacks** - Non-blocking execution
- **Statistics tracking** - Performance monitoring
- **Mutex protection** - Thread-safe operations
- **Signal/slot events** - Observer pattern
