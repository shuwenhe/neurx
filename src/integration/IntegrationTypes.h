#pragma once

#include <QString>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * Integration layer types for system orchestration
 */

// ── System State ────────────────────────────────────

enum class SystemState {
    Initializing,      // System starting up
    Ready,             // Ready to accept commands
    Processing,        // Processing commands
    Paused,            // Paused
    Shutdown,          // Shutting down
    Error,             // Error state
    Maintenance        // Maintenance mode
};

// ── System Health ───────────────────────────────────

enum class HealthStatus {
    Healthy,           // All systems functioning
    Degraded,          // Some components degraded
    Warning,           // Warning state
    Critical,          // Critical state
    Offline            // System offline
};

// ── Integration Modes ───────────────────────────────

enum class IntegrationMode {
    Standalone,        // Single agent instance
    Distributed,       // Multiple agent instances
    Collaborative,     // Agents collaborate
    Federated          // Federated learning mode
};

// ── Subsystem Types ────────────────────────────────

enum class SubsystemType {
    Execution,         // ExecutionEngine
    LLM,               // LLMExtensions
    Memory,            // MemoryManager
    Tools,             // ToolRegistry
    Skills,            // SkillManager
    State,             // StateManager
    Plugins,           // PluginManager
    Logging,           // LoggingManager
    Approval,          // ApprovalEngine
    Config,            // ConfigManager
    Thread,            // ThreadManager
    Sandbox,           // SandboxManager
    Goals,             // GoalManager
    Test,              // TestFramework
    Custom             // Custom subsystem
};

// ── Subsystem Health ────────────────────────────────

struct SubsystemHealth {
    SubsystemType type;
    QString name;
    HealthStatus status;
    
    bool operational = true;
    int errorCount = 0;
    QString lastError;
    
    float cpuUsage = 0.0f;
    int memoryUsage = 0;
    
    int requestsProcessed = 0;
    float averageLatency = 0.0f;
    
    QDateTime lastChecked;
};

// ── System Metrics ──────────────────────────────────

struct SystemMetrics {
    SystemState state;
    HealthStatus health;
    
    // Overall metrics
    int totalRequests = 0;
    int successfulRequests = 0;
    int failedRequests = 0;
    float successRate = 0.0f;
    
    // Performance
    float totalLatency = 0.0f;
    float averageLatency = 0.0f;
    float peakLatency = 0.0f;
    
    // Resource usage
    int peakMemory = 0;
    float averageCpu = 0.0f;
    
    // Subsystem metrics
    QVector<SubsystemHealth> subsystemHealth;
    
    // Time tracking
    QDateTime startedAt;
    QDateTime lastStatusCheck;
    qint64 uptime = 0;
};

// ── Configuration ───────────────────────────────────

struct IntegrationConfiguration {
    IntegrationMode mode = IntegrationMode::Standalone;
    
    bool autoRecovery = true;
    bool healthChecking = true;
    bool loadBalancing = false;
    
    int healthCheckInterval = 5000;  // ms
    int statusReportInterval = 10000; // ms
    
    float cpuThreshold = 80.0f;      // %
    int memoryThreshold = 1000000;   // bytes
    float latencyThreshold = 5000.0f; // ms
    
    QStringList enabledSubsystems;
    QStringList disabledSubsystems;
};

// ── Request Context ────────────────────────────────

struct RequestContext {
    QString requestId;
    QString userId;
    QString sessionId;
    
    QString priority = "normal";  // low, normal, high, critical
    
    int timeoutMs = 30000;
    bool requiresApproval = false;
    
    QVariantMap metadata;
    
    QDateTime createdAt;
    QString source;               // Which subsystem initiated
};

// ── Workflow Definition ────────────────────────────

struct WorkflowStep {
    QString stepId;
    QString name;
    QString description;
    
    SubsystemType targetSubsystem;
    QString operation;             // Operation to perform
    
    QVariantMap parameters;
    
    QString nextStepOnSuccess;
    QString nextStepOnFailure;
    
    int retryCount = 0;
    int maxRetries = 3;
    
    bool skipOnError = false;
};

struct Workflow {
    QString workflowId;
    QString name;
    QString description;
    
    QVector<WorkflowStep> steps;
    
    QString entryPoint;            // First step
    QString exitPoint;             // Final step
    
    bool async = true;
    
    QDateTime createdAt;
    QDateTime lastModified;
};

// ── Workflow Execution ──────────────────────────────

struct WorkflowExecution {
    QString executionId;
    QString workflowId;
    
    RequestContext context;
    
    QMap<QString, QVariantMap> stepResults;  // Results per step
    
    QString currentStep;
    QString status;                // running, completed, failed, cancelled
    
    QVector<QString> executedSteps;
    QVector<QString> failedSteps;
    
    QDateTime startedAt;
    QDateTime completedAt;
    qint64 duration = 0;           // ms
    
    QString errorMessage;
    int errorCode = 0;
};

// ── Circuit Breaker ────────────────────────────────

struct CircuitBreaker {
    QString id;
    SubsystemType subsystem;
    
    enum State {
        Closed,      // Normal operation
        Open,        // Circuit open, reject requests
        HalfOpen     // Testing if service recovered
    };
    
    State state = Closed;
    
    int failureThreshold = 5;
    int successThreshold = 2;
    int failureCount = 0;
    int successCount = 0;
    
    qint64 timeout = 30000;        // ms
    QDateTime lastFailure;
    
    float errorRate = 0.0f;
};

// ── Message/Event ──────────────────────────────────

struct SystemMessage {
    QString messageId;
    QString messageType;           // "event", "request", "response", "error"
    
    SubsystemType fromSubsystem;
    SubsystemType toSubsystem;
    
    QString action;
    QVariantMap payload;
    
    QString replyTo;               // For responses
    
    int priority = 0;              // 0-100, higher is more important
    
    QDateTime timestamp;
    bool processed = false;
};

// ── Dependency ──────────────────────────────────────

struct Dependency {
    SubsystemType dependent;       // Depends on
    SubsystemType dependency;      // The subsystem it depends on
    
    QString reason;
    bool critical = false;         // Is it critical?
    
    enum Type {
        DataFlow,      // Data dependency
        Execution,     // Execution ordering
        Configuration, // Config dependency
        Event          // Event dependency
    };
    
    Type type = DataFlow;
};

// ── Startup Sequence ────────────────────────────────

struct StartupSequence {
    QVector<SubsystemType> initOrder;  // Order to initialize subsystems
    int maxParallel = 3;           // Max parallel initializations
    int timeoutPerSystem = 10000;  // ms per system
};

// ── Shutdown Sequence ───────────────────────────────

struct ShutdownSequence {
    QVector<SubsystemType> shutdownOrder;  // Order to shutdown
    bool graceful = true;          // Graceful shutdown?
    int timeoutPerSystem = 5000;   // ms per system
};

// ── Callbacks ───────────────────────────────────────

using SystemStateChangeCallback = std::function<void(SystemState oldState, SystemState newState)>;
using HealthChangeCallback = std::function<void(const SubsystemHealth &)>;
using WorkflowCallback = std::function<void(const WorkflowExecution &)>;
using MessageCallback = std::function<void(const SystemMessage &)>;
using ErrorCallback = std::function<void(int errorCode, const QString &message)>;
