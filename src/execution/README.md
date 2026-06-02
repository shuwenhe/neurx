# Neurx Execution Engine

The Execution Engine orchestrates the execution of tasks, tools, skills, and goals within the Neurx agent framework.

## Overview

The execution engine provides:
- Sequential and parallel task execution
- Tool and skill invocation
- Approval workflow integration
- Sandboxed execution
- Error recovery and rollback
- Complete audit trail

## Core Components

### ExecutionAction
Defines what to execute:
```cpp
ExecutionAction action;
action.id = QUuid::createUuid().toString();
action.name = "Code Review";
action.type = ExecutionType::Tool;
action.target = "code-review";
action.parameters["code"] = sourceCode;
action.timeoutMs = 30000;
```

### ExecutionTask
Represents a complete task with multiple actions:
```cpp
ExecutionTask task;
task.threadId = "thread-123";
task.goalId = "goal-456";
task.actions << action1 << action2;
task.context.variables["userQuery"] = "Review this code";
```

### ExecutionResult
Contains the result of execution:
```cpp
ExecutionResult result;
result.success = true;
result.output = /* action output */;
result.tokensUsed = 42;
result.durationMs = 1500;
```

## Usage Examples

### Execute a Single Action
```cpp
ExecutionAction action;
action.target = "read_file";
action.parameters["path"] = "/path/to/file.cpp";

engine->executeAction(action, context, [](const ExecutionResult &result) {
    if (result.success) {
        qDebug() << "File contents:" << result.output;
    }
});
```

### Execute a Task
```cpp
ExecutionTask task;
task.actions << action1 << action2 << action3;

engine->executeTask(task,
    // Progress callback
    [](const ExecutionEvent &event) {
        qDebug() << "Progress:" << event.message;
    },
    // Completion callback
    [](const ExecutionResult &result) {
        qDebug() << "Task completed:" << result.success;
    }
);
```

### Execute a Plan
```cpp
ExecutionPlan plan;
plan.actions << toolAction << skillAction << approvalAction;
plan.strategy = "sequential";

engine->executePlan(plan, context, 
    [](const ExecutionEvent &event) { /* ... */ },
    [](bool success) { 
        qDebug() << "Plan execution:" << (success ? "success" : "failed");
    }
);
```

## Tool Execution

Execute available tools:
```cpp
engine->executeTool("read_file", 
    QVariantMap{{"path", "/file.txt"}},
    context,
    [](const ExecutionResult &result) {
        qDebug() << "Tool result:" << result.output;
    }
);

// List available tools
auto tools = engine->getAvailableTools();
// Output: ["read_file", "write_file", "run_command", ...]
```

## Skill Execution

Execute skills with parameters:
```cpp
engine->executeSkill("org.neurx.skill.analysis.code-review",
    QVariantMap{{"code", sourceCode}},
    context,
    [](const ExecutionResult &result) {
        qDebug() << "Skill executed, tokens used:" << result.tokensUsed;
    }
);

// Get relevant skills for context
auto skills = engine->getAvailableSkills(context);
```

## Approval Workflow

Request approval for sensitive actions:
```cpp
engine->requestApproval(task,
    [engine](const ExecutionTask &task, auto callback) {
        // Present approval request to user
        // User decides...
        engine->approveAction(task.taskId, "Approved", 
            [callback](bool success) {
                callback(true);  // approved
            });
    }
);
```

## Conditional Execution

Execute actions conditionally:
```cpp
ExecutionAction action;
action.condition = "userConfirmed";
action.target = "destructive_operation";

// Action will be skipped if condition is false
auto result = engine->evaluateCondition("userConfirmed", context);
```

## Error Recovery

Retry failed actions:
```cpp
engine->retryAction(taskId, actionId,
    [](const ExecutionResult &result) {
        qDebug() << "Retry result:" << result.success;
    }
);

// Rollback all changes
engine->rollback(taskId, [](bool success) {
    qDebug() << "Rollback:" << (success ? "complete" : "failed");
});
```

## Execution History

Track all executions:
```cpp
// Get history for specific task
auto history = engine->getExecutionHistory(taskId, 100);
for (const auto &entry : history) {
    qDebug() << "Action:" << entry.actionId 
             << "Success:" << entry.result.success;
}

// Get all execution history
auto allHistory = engine->getAllExecutionHistory(100);

// Get specific result
auto result = engine->getTaskResult(taskId);
```

## Task Management

Query execution state:
```cpp
// Get running tasks
auto running = engine->getRunningTasks();

// Get completed tasks
auto completed = engine->getCompletedTasks(10);

// Get failed tasks
auto failed = engine->getFailedTasks(10);

// Search tasks
QVariantMap criteria;
criteria["status"] = "completed";
auto tasks = engine->searchTasks(threadId, criteria);

// Get task status
auto task = engine->getTaskStatus(taskId);
qDebug() << "Progress:" << task.progressPercentage << "%";
```

## Monitoring and Statistics

Track execution performance:
```cpp
// Overall statistics
auto stats = engine->getExecutionStats();
qDebug() << "Success rate:" << stats.successRate << "%";
qDebug() << "Average duration:" << stats.averageDurationMs << "ms";
qDebug() << "Total tokens:" << stats.totalTokensUsed;

// Per-thread statistics
auto threadStats = engine->getThreadExecutionStats(threadId);
qDebug() << "Thread tasks:" << threadStats.totalTasks;
```

## Control Flow

Pause, resume, and cancel execution:
```cpp
// Pause a running task
engine->pauseTask(taskId, [](bool success) {
    qDebug() << "Paused:" << success;
});

// Resume paused task
engine->resumeTask(taskId, [](bool success) {
    qDebug() << "Resumed:" << success;
});

// Cancel execution
engine->cancelTask(taskId, [](bool success) {
    qDebug() << "Cancelled:" << success;
});
```

## Configuration

Configure engine behavior:
```cpp
// Set default timeout for all actions
engine->setDefaultTimeout(60000);  // 60 seconds

// Set maximum retry attempts
engine->setMaxRetries(3);

// Enable dry run mode (simulate without executing)
engine->setDryRun(true);

// Actions will be simulated but not actually executed
```

## Integration Points

The execution engine integrates with:
- **ToolRegistry**: For available tools
- **SkillManager**: For available skills
- **ApprovalManager**: For approval workflows
- **SandboxManager**: For isolated execution
- **GoalManager**: For goal-based execution
- **ThreadStore**: For thread context

## Signals and Events

Connect to execution events:
```cpp
connect(engine.get(), &ExecutionEngine::taskStarted,
    [](const QString &taskId) {
        qDebug() << "Task started:" << taskId;
    });

connect(engine.get(), &ExecutionEngine::executionProgress,
    [](const ExecutionEvent &event) {
        qDebug() << "Progress:" << event.message;
    });

connect(engine.get(), &ExecutionEngine::taskCompleted,
    [](const QString &taskId, bool success) {
        qDebug() << "Task completed:" << (success ? "success" : "failed");
    });

connect(engine.get(), &ExecutionEngine::approvalRequired,
    [](const QString &taskId, const ExecutionTask &task) {
        qDebug() << "Approval needed for task:" << taskId;
    });

connect(engine.get(), &ExecutionEngine::executionError,
    [](const QString &taskId, const ExecutionResult &result) {
        qDebug() << "Error:" << result.errorMessage;
    });
```

## Best Practices

1. **Always set timeouts** - Prevent hanging operations
2. **Use continue-on-error** - For resilient workflows
3. **Check approvals early** - Request approval before expensive operations
4. **Monitor history** - Track what was executed and why
5. **Use sandboxing** - For untrusted or risky operations
6. **Handle errors gracefully** - Plan rollback strategies
7. **Track tokens** - Monitor resource usage

## Architecture

The execution engine uses:
- **Asynchronous callbacks** for non-blocking operation
- **Queue-based task scheduling** for ordering
- **State machines** for execution flow
- **Audit trails** for complete traceability
- **Rollback capability** for error recovery
