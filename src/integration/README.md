# Neurx Integration Layer

The Integration Layer provides centralized orchestration and management of all agent subsystems, enabling coordinated operation, health monitoring, and workflow execution.

## Overview

The integration layer provides:
- System initialization and lifecycle management
- Subsystem health monitoring
- Workflow orchestration and execution
- Message routing between subsystems
- Resource management
- Circuit breaking and error recovery
- Dependency management

## Core Components

### System States

```cpp
enum class SystemState {
    Initializing,      // System starting up
    Ready,             // Ready to accept commands
    Processing,        // Processing commands
    Paused,            // Paused
    Shutdown,          // Shutting down
    Error,             // Error state
    Maintenance        // Maintenance mode
};
```

### Health Status

```cpp
enum class HealthStatus {
    Healthy,           // All systems functioning
    Degraded,          // Some components degraded
    Warning,           // Warning state
    Critical,          // Critical state
    Offline            // System offline
};
```

### Subsystem Types

```cpp
enum class SubsystemType {
    Execution,    Memory,      Tools,       LLM,
    Skills,       State,       Plugins,     Logging,
    Approval,     Config,      Thread,      Sandbox,
    Goals,        Test,        Custom
};
```

## Usage Examples

### System Lifecycle

```cpp
// Initialize system
IntegrationConfiguration config;
config.mode = IntegrationMode::Standalone;
config.healthChecking = true;
config.healthCheckInterval = 5000;

orchestrator->initialize(config, [](bool success) {
    qDebug() << "System initialized:" << success;
});

// Start system
orchestrator->start([](bool success) {
    qDebug() << "System started";
});

// Pause system
orchestrator->pause([](bool success) {
    qDebug() << "System paused";
});

// Resume system
orchestrator->resume([](bool success) {
    qDebug() << "System resumed";
});

// Shutdown system
orchestrator->shutdown(true, [](bool success) {
    qDebug() << "System shut down";
});
```

### State Management

```cpp
// Get system state
SystemState state = orchestrator->getSystemState();
qDebug() << "System state:" << (int)state;

// Get health status
HealthStatus health = orchestrator->getHealthStatus();
qDebug() << "System health:" << (int)health;

// Get system metrics
SystemMetrics metrics = orchestrator->getSystemMetrics();
qDebug() << "Total requests:" << metrics.totalRequests;
qDebug() << "Success rate:" << metrics.successRate;
qDebug() << "Average latency:" << metrics.averageLatency;

// Set state
orchestrator->setState(SystemState::Ready, [](SystemState old, SystemState newState) {
    qDebug() << "State changed from" << (int)old << "to" << (int)newState;
});
```

### Subsystem Management

```cpp
// Register subsystem
orchestrator->registerSubsystem(SubsystemType::LLM, "LLM Extensions",
    [](bool success) {
        qDebug() << "LLM subsystem registered";
    });

// Enable subsystem
orchestrator->enableSubsystem(SubsystemType::Memory,
    [](bool success) {
        qDebug() << "Memory subsystem enabled";
    });

// Disable subsystem
orchestrator->disableSubsystem(SubsystemType::Tools,
    [](bool success) {
        qDebug() << "Tool subsystem disabled";
    });

// Check availability
if (orchestrator->isSubsystemAvailable(SubsystemType::LLM)) {
    qDebug() << "LLM is available";
}

// Get subsystem health
SubsystemHealth health = orchestrator->getSubsystemHealth(SubsystemType::Execution);
qDebug() << "Execution status:" << (int)health.status;
qDebug() << "Errors:" << health.errorCount;

// Get all subsystems health
auto allHealth = orchestrator->getAllSubsystemHealth();

// Restart subsystem
orchestrator->restartSubsystem(SubsystemType::Logging,
    [](bool success) {
        qDebug() << "Logging subsystem restarted";
    });
```

### Health Monitoring

```cpp
// Start health checking
orchestrator->startHealthChecking(5000);  // Check every 5 seconds

// Perform health check
SystemMetrics metrics = orchestrator->performHealthCheck();

// Check specific subsystem
bool healthy = orchestrator->checkSubsystemHealth(SubsystemType::Memory);

// Get health report
QString report = orchestrator->getHealthReport();
qDebug() << report;

// Stop health checking
orchestrator->stopHealthChecking();
```

### Workflow Definition and Execution

```cpp
// Define workflow
Workflow workflow;
workflow.workflowId = "approve-request";
workflow.name = "Approval Workflow";

WorkflowStep step1;
step1.stepId = "step1";
step1.name = "Get approval";
step1.targetSubsystem = SubsystemType::Approval;
step1.operation = "requestApproval";
step1.nextStepOnSuccess = "step2";
step1.nextStepOnFailure = "fail";

WorkflowStep step2;
step2.stepId = "step2";
step2.name = "Execute";
step2.targetSubsystem = SubsystemType::Execution;
step2.operation = "execute";

workflow.steps.append(step1);
workflow.steps.append(step2);
workflow.entryPoint = "step1";

orchestrator->defineWorkflow(workflow, [](bool success) {
    qDebug() << "Workflow defined";
});

// Execute workflow
RequestContext context;
context.requestId = QUuid::createUuid().toString();
context.userId = "user123";

auto execId = orchestrator->executeWorkflow("approve-request", context,
    [](const WorkflowExecution &exec) {
        qDebug() << "Workflow completed:" << exec.executionId;
        qDebug() << "Status:" << exec.status;
        qDebug() << "Duration:" << exec.duration << "ms";
    });

// Get execution
WorkflowExecution exec = orchestrator->getWorkflowExecution(execId);

// Cancel execution
orchestrator->cancelWorkflowExecution(execId,
    [](bool success) {
        qDebug() << "Execution cancelled";
    });

// List workflows
auto workflows = orchestrator->listWorkflows();
```

### Message Routing

```cpp
// Send message
SystemMessage msg;
msg.messageType = "request";
msg.fromSubsystem = SubsystemType::Execution;
msg.toSubsystem = SubsystemType::Memory;
msg.action = "store";
msg.payload["data"] = "important info";

auto msgId = orchestrator->sendMessage(msg, [](const SystemMessage &m) {
    qDebug() << "Message delivered:" << m.messageId;
});

// Broadcast message
SystemMessage broadcast;
broadcast.messageType = "event";
broadcast.fromSubsystem = SubsystemType::State;
broadcast.action = "stateChanged";

orchestrator->broadcastMessage(broadcast);

// Register message handler
orchestrator->registerMessageHandler("response",
    [](const SystemMessage &msg) {
        qDebug() << "Received response:" << msg.payload;
    });

// Get pending messages
auto pending = orchestrator->getPendingMessages(SubsystemType::Tools);

// Get message
SystemMessage retrieved = orchestrator->getMessage(msgId);
```

### Circuit Breaker

```cpp
// Get circuit breaker
CircuitBreaker cb = orchestrator->getCircuitBreaker(SubsystemType::LLM);
qDebug() << "Circuit state:" << (int)cb.state;

// Open circuit
orchestrator->openCircuit(SubsystemType::Tools,
    [](bool success) {
        qDebug() << "Circuit opened";
    });

// Close circuit
orchestrator->closeCircuit(SubsystemType::Tools,
    [](bool success) {
        qDebug() << "Circuit closed";
    });

// Check circuit state
auto state = orchestrator->getCircuitState(SubsystemType::Memory);
```

### Dependency Management

```cpp
// Register dependency
Dependency dep;
dep.dependent = SubsystemType::Execution;
dep.dependency = SubsystemType::Memory;
dep.critical = true;
dep.reason = "Execution needs memory for state";
dep.type = Dependency::DataFlow;

orchestrator->registerDependency(dep, [](bool success) {
    qDebug() << "Dependency registered";
});

// Get dependencies
auto deps = orchestrator->getDependencies(SubsystemType::Execution);

// Check dependency health
if (orchestrator->checkDependencyHealth(SubsystemType::Execution)) {
    qDebug() << "All dependencies healthy";
}

// Get dependency graph
auto graph = orchestrator->getDependencyGraph();
```

### Resource Management

```cpp
// Set resource limits
orchestrator->setResourceLimits(1000000, 80.0,  // 1MB, 80% CPU
    [](bool success) {
        qDebug() << "Resource limits set";
    });

// Get resource usage
auto usage = orchestrator->getResourceUsage();
qDebug() << "Memory:" << usage["memory"];
qDebug() << "CPU:" << usage["cpu"];

// Check resource availability
if (orchestrator->checkResourceAvailability(100000, 10.0)) {
    qDebug() << "Resources available";
}

// Optimize resources
orchestrator->optimizeResources([](bool success) {
    qDebug() << "Resources optimized";
});
```

### Startup and Shutdown Sequences

```cpp
// Define startup sequence
StartupSequence startup;
startup.initOrder = {
    SubsystemType::Config,
    SubsystemType::Logging,
    SubsystemType::Memory,
    SubsystemType::Tools,
    SubsystemType::LLM,
    SubsystemType::Execution
};
startup.maxParallel = 3;
startup.timeoutPerSystem = 10000;

orchestrator->setStartupSequence(startup, [](bool success) {
    qDebug() << "Startup sequence set";
});

// Execute startup
orchestrator->executeStartupSequence([](bool success) {
    qDebug() << "Startup complete";
});

// Define shutdown sequence
ShutdownSequence shutdown;
shutdown.shutdownOrder = {
    SubsystemType::Execution,
    SubsystemType::LLM,
    SubsystemType::Tools,
    SubsystemType::Memory,
    SubsystemType::Logging,
    SubsystemType::Config
};
shutdown.graceful = true;

orchestrator->setShutdownSequence(shutdown, [](bool success) {
    qDebug() << "Shutdown sequence set";
});

// Execute shutdown
orchestrator->executeShutdownSequence([](bool success) {
    qDebug() << "Shutdown complete";
});
```

### Configuration

```cpp
// Set configuration
IntegrationConfiguration config;
config.mode = IntegrationMode::Standalone;
config.healthChecking = true;
config.autoRecovery = true;
config.healthCheckInterval = 5000;

orchestrator->setConfiguration(config, [](bool success) {
    qDebug() << "Configuration updated";
});

// Get configuration
auto cfg = orchestrator->getConfiguration();

// Update single config property
orchestrator->updateConfiguration("healthCheckInterval", 10000,
    [](bool success) {
        qDebug() << "Config property updated";
    });

// Validate configuration
if (orchestrator->validateConfiguration(config)) {
    qDebug() << "Configuration is valid";
}
```

### Error Recovery

```cpp
// Enable auto-recovery
orchestrator->enableAutoRecovery(true);

// Trigger recovery
orchestrator->triggerRecovery(SubsystemType::Execution,
    [](bool success) {
        qDebug() << "Recovery triggered";
    });

// Get last error
QString lastError = orchestrator->getLastError();
qDebug() << "Last error:" << lastError;

// Get error history
auto errors = orchestrator->getErrorHistory(50);

// Clear error history
orchestrator->clearErrorHistory([](bool success) {
    qDebug() << "Error history cleared";
});
```

### Statistics and Reports

```cpp
// Get system statistics
auto stats = orchestrator->getStatistics();
qDebug() << "Total requests:" << stats["totalRequests"];
qDebug() << "Success rate:" << stats["successRate"];

// Get subsystem statistics
auto subStats = orchestrator->getSubsystemStatistics(SubsystemType::LLM);
qDebug() << "LLM requests:" << subStats["requestsProcessed"];

// Get performance report
QString report = orchestrator->getPerformanceReport();
qDebug() << report;
```

### Testing and Diagnostics

```cpp
// Run diagnostics
QString diagnostics = orchestrator->runDiagnostics();
qDebug() << diagnostics;

// Test subsystem
if (orchestrator->testSubsystem(SubsystemType::Memory)) {
    qDebug() << "Memory subsystem test passed";
}

// Test connectivity
if (orchestrator->testConnectivity(SubsystemType::Execution, SubsystemType::Memory)) {
    qDebug() << "Connectivity test passed";
}
```

## Signals and Events

```cpp
// System state changed
connect(orchestrator.get(), &IntegrationOrchestrator::systemStateChanged,
    [](SystemState old, SystemState newState) {
        qDebug() << "State changed";
    });

// Health status changed
connect(orchestrator.get(), &IntegrationOrchestrator::healthStatusChanged,
    [](HealthStatus status) {
        qDebug() << "Health status changed:" << (int)status;
    });

// Subsystem health changed
connect(orchestrator.get(), &IntegrationOrchestrator::subsystemHealthChanged,
    [](const SubsystemHealth &health) {
        qDebug() << "Subsystem health changed:" << health.name;
    });

// Workflow events
connect(orchestrator.get(), &IntegrationOrchestrator::workflowCompleted,
    [](const WorkflowExecution &exec) {
        qDebug() << "Workflow completed";
    });

// Error events
connect(orchestrator.get(), &IntegrationOrchestrator::errorOccurred,
    [](int code, const QString &msg) {
        qDebug() << "Error:" << code << msg;
    });

// Circuit events
connect(orchestrator.get(), &IntegrationOrchestrator::circuitOpened,
    [](SubsystemType subsystem) {
        qDebug() << "Circuit opened for subsystem";
    });
```

## Best Practices

1. **Define sequences** - Establish startup/shutdown order
2. **Register dependencies** - Track subsystem relationships
3. **Monitor health** - Enable regular health checks
4. **Use workflows** - Coordinate multi-step operations
5. **Handle errors** - Enable auto-recovery
6. **Manage resources** - Set appropriate limits
7. **Track metrics** - Monitor performance
8. **Test connectivity** - Verify subsystem communication
9. **Use circuit breakers** - Prevent cascading failures
10. **Plan scaling** - Design for horizontal/vertical growth

## Architecture

The integration layer uses:
- **Centralized orchestration** - Single point of system control
- **Health monitoring** - Continuous system assessment
- **Workflow engine** - Multi-step operation coordination
- **Message routing** - Decoupled subsystem communication
- **Circuit breaker** - Fault tolerance pattern
- **Dependency management** - System relationship tracking
- **Resource management** - Performance optimization
- **Auto-recovery** - Resilience and healing
- **Async callbacks** - Non-blocking operations
- **Signal/slot events** - Observer pattern
- **Thread safety** - Mutex protection
