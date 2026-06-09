#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <map>

/**
 * @class AutomationOrchestrator
 * @brief Advanced workflow automation and task scheduling
 * 
 * Features:
 * - Workflow definition and execution
 * - Task scheduling with cron expressions
 * - Event-driven automation
 * - Dependency management
 * - Retry and error handling
 */

class AutomationOrchestrator : public QObject {
    Q_OBJECT

public:
    enum WorkflowStatus {
        Draft,
        Active,
        Paused,
        Completed,
        Failed,
        Cancelled
    };

    enum TriggerType {
        Manual,
        Scheduled,
        EventBased,
        WebhookBased,
        ConditionalBased
    };

    struct WorkflowStep {
        QString id;
        QString name;
        QString action;  // Tool or function name
        QJsonObject parameters;
        int retryCount;
        int timeoutSeconds;
        bool stopOnError;
        QStringList dependencies;  // Other step IDs
    };

    struct WorkflowDefinition {
        QString id;
        QString name;
        QString description;
        WorkflowStatus status;
        QVector<WorkflowStep> steps;
        QDateTime createdAt;
        QDateTime lastModified;
        QString createdBy;
    };

    struct ExecutionContext {
        QString executionId;
        QString workflowId;
        TriggerType triggerType;
        QJsonObject initialInputs;
        QJsonObject currentState;
        QVector<QString> completedSteps;
        QVector<QString> failedSteps;
        QDateTime startTime;
        QDateTime endTime;
        QString status;
    };

    struct ScheduleConfig {
        QString cronExpression;
        bool enabled;
        QDateTime nextExecution;
        QDateTime lastExecution;
        int executionCount;
    };

    explicit AutomationOrchestrator(QObject* parent = nullptr);
    ~AutomationOrchestrator();

    // Workflow management
    void createWorkflow(const WorkflowDefinition& workflow);
    void updateWorkflow(const WorkflowDefinition& workflow);
    void deleteWorkflow(const QString& workflowId);
    WorkflowDefinition getWorkflow(const QString& workflowId);
    QVector<WorkflowDefinition> getAllWorkflows();

    // Execution control
    QString executeWorkflow(const QString& workflowId, const QJsonObject& inputs);
    void pauseExecution(const QString& executionId);
    void resumeExecution(const QString& executionId);
    void cancelExecution(const QString& executionId);
    ExecutionContext getExecutionStatus(const QString& executionId);

    // Step management
    void addStep(const QString& workflowId, const WorkflowStep& step);
    void removeStep(const QString& workflowId, const QString& stepId);
    WorkflowStep getStep(const QString& workflowId, const QString& stepId);

    // Scheduling
    void scheduleWorkflow(const QString& workflowId, const ScheduleConfig& schedule);
    void unscheduleWorkflow(const QString& workflowId);
    ScheduleConfig getScheduleConfig(const QString& workflowId);
    QVector<QString> getScheduledWorkflows();

    // Triggering
    void registerEventTrigger(const QString& workflowId, const QString& eventType);
    void registerConditionalTrigger(const QString& workflowId, const QString& condition);
    void triggerByEvent(const QString& eventType, const QJsonObject& eventData);

    // Dependency resolution
    QStringList resolveDependencies(const QString& workflowId);
    bool validateDependencies(const QString& workflowId);

    // Error handling
    void setErrorHandler(const QString& workflowId, const QString& handler);
    void registerRetryPolicy(const QString& workflowId, int maxRetries, int delayMs);

    // Analytics
    struct WorkflowStats {
        QString workflowId;
        int totalExecutions;
        int successfulExecutions;
        int failedExecutions;
        float avgExecutionTimeMs;
        float successRate;
    };
    WorkflowStats getWorkflowStats(const QString& workflowId);

    // Monitoring
    struct ExecutionMetrics {
        QString executionId;
        QVector<QString> executionOrder;
        QMap<QString, float> stepDurations;
        QVector<QString> errors;
    };
    ExecutionMetrics getExecutionMetrics(const QString& executionId);

signals:
    void workflowCreated(const QString& workflowId);
    void workflowExecutionStarted(const QString& executionId);
    void stepExecutionCompleted(const QString& executionId, const QString& stepId);
    void workflowExecutionCompleted(const QString& executionId, bool success);
    void executionFailed(const QString& executionId, const QString& error);

private:
    QMap<QString, WorkflowDefinition> m_workflows;
    QMap<QString, ExecutionContext> m_executions;
    QMap<QString, ScheduleConfig> m_schedules;
    QMap<QString, WorkflowStats> m_stats;
};
