#pragma once

#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QDateTime>
#include <memory>

/**
 * @class ExecutionTypes
 * @brief Execution engine type definitions
 * 
 * Migrated from Codex execution system:
 * - Task and action execution
 * - Execution state tracking
 * - Error and failure handling
 * - Execution history and rollback
 */

// ── Execution Type ────────────────────────────────────────────

enum class ExecutionType {
    Tool,                               ///< Execute external tool
    Skill,                              ///< Execute skill
    Goal,                               ///< Execute goal/step
    Script,                             ///< Execute code/script
    Approval,                           ///< Require approval
    Conditional,                        ///< Conditional execution
    Parallel,                           ///< Execute in parallel
    Sequential,                         ///< Execute sequentially
    Loop,                               ///< Loop execution
    Fallback                            ///< Fallback/retry execution
};

// ── Execution Status ──────────────────────────────────────────

enum class ExecutionStatus {
    Pending,                            ///< Waiting to execute
    Running,                            ///< Currently executing
    Paused,                             ///< Paused execution
    Suspended,                          ///< Suspended (waiting for approval)
    Completed,                          ///< Completed successfully
    Failed,                             ///< Execution failed
    Cancelled,                          ///< Execution cancelled
    Timeout,                            ///< Execution timed out
    Skipped                             ///< Execution skipped
};

// ── Error Type ────────────────────────────────────────────────

enum class ExecutionErrorType {
    Success = 0,
    NotFound,
    InvalidParameters,
    ExecutionFailed,
    Timeout,
    ResourcesUnavailable,
    PermissionDenied,
    SandboxViolation,
    Cancelled,
    Interrupted,
    UnexpectedError
};

// ── Execution Context ─────────────────────────────────────────

struct ExecutionContext {
    QString threadId;
    QString goalId;                     ///< Associated goal
    QString userId;                     ///< User performing action
    
    QVariantMap variables;              ///< Local variables
    QVariantMap sharedState;            ///< Shared state across executions
    
    QString workingDirectory;           ///< Execution working directory
    QStringList environmentVariables;   ///< Environment variables
    
    bool isDryRun{false};               ///< Dry run mode (don't modify)
    int recursionDepth{0};              ///< Current recursion depth
    int maxRecursionDepth{10};
};

// ── Task/Action Definition ────────────────────────────────────

struct ExecutionAction {
    QString id;                         ///< Unique action ID
    QString name;                       ///< Action name
    ExecutionType type{ExecutionType::Tool};
    
    // What to execute
    QString target;                     ///< Tool/skill/script name
    QVariantMap parameters;             ///< Parameters
    
    // Execution config
    int timeoutMs{30000};
    int maxRetries{0};
    bool continueOnError{false};        ///< Continue if this action fails
    
    // Conditional
    QString condition;                  ///< Condition expression
    
    // Nested actions
    QVector<ExecutionAction> nestedActions;
    
    // Approval required
    bool requiresApproval{false};
    QString approvalReason;
};

// ── Execution Task ────────────────────────────────────────────

struct ExecutionTask {
    QString taskId;
    QString threadId;
    QString goalId;                     ///< Associated goal
    
    QVector<ExecutionAction> actions;
    ExecutionContext context;
    
    QString status_str;                 ///< Current status
    double progressPercentage{0.0};
    
    QDateTime startedAt;
    QDateTime completedAt;
    int durationMs{0};
    
    QStringList executionLog;
};

// ── Execution Result ──────────────────────────────────────────

struct ExecutionResult {
    QString taskId;
    QString actionId;
    bool success{false};
    
    ExecutionErrorType errorType{ExecutionErrorType::Success};
    QString errorMessage;
    int errorCode{0};
    
    QVariant output;                    ///< Execution output
    QVariantMap resultData;
    
    int tokensUsed{0};
    int durationMs{0};
    QDateTime completedAt{QDateTime::currentDateTime()};
    
    // Audit
    QString executor;
    QString approverNote;
};

// ── Execution Event ───────────────────────────────────────────

enum class ExecutionEventType {
    Started,
    ActionStarted,
    ActionCompleted,
    ActionFailed,
    ApprovalRequested,
    ApprovalApproved,
    ApprovalRejected,
    Paused,
    Resumed,
    Cancelled,
    Completed,
    Error
};

struct ExecutionEvent {
    QString taskId;
    ExecutionEventType type;
    QDateTime timestamp{QDateTime::currentDateTime()};
    
    QString actionId;
    QString message;
    QVariantMap data;
};

// ── Execution History Entry ───────────────────────────────────

struct ExecutionHistoryEntry {
    QString taskId;
    QString actionId;
    ExecutionResult result;
    ExecutionContext context;
    
    bool canRollback{false};            ///< Can be rolled back
    QVariantMap rollbackData;           ///< Data for rollback
};

// ── Execution Plan ────────────────────────────────────────────

struct ExecutionPlan {
    QString planId;
    QString name;
    QString description;
    
    QVector<ExecutionAction> actions;
    QString strategy;                   ///< "sequential", "parallel", "conditional"
    
    QDateTime createdAt{QDateTime::currentDateTime()};
    QString createdBy;
};

// ── Execution Statistics ──────────────────────────────────────

struct ExecutionStats {
    int totalTasks{0};
    int completedTasks{0};
    int failedTasks{0};
    
    int totalActions{0};
    int completedActions{0};
    int failedActions{0};
    
    int totalTokensUsed{0};
    int totalDurationMs{0};
    
    double successRate{0.0};
    double averageDurationMs{0.0};
};

// ── Callbacks ─────────────────────────────────────────────────

using ExecutionCallback = std::function<void(const ExecutionResult &result)>;
using ExecutionProgressCallback = std::function<void(const ExecutionEvent &event)>;
using ExecutionApprovalCallback = std::function<void(const ExecutionTask &task, 
                                                     std::function<void(bool approved)> callback)>;
