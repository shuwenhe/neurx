#pragma once

#include "ExecutionEngine.h"
#include <QMap>
#include <QMutex>
#include <QTimer>

/**
 * @class DefaultExecutionEngine
 * @brief Default execution engine implementation
 * 
 * Features:
 * - Sequential and parallel execution
 * - Tool and skill orchestration
 * - Approval workflow integration
 * - Sandboxed execution
 * - Error recovery and rollback
 * - Complete audit trail
 */
class DefaultExecutionEngine : public ExecutionEngine {
    Q_OBJECT
public:
    explicit DefaultExecutionEngine(QObject *parent = nullptr);
    ~DefaultExecutionEngine();
    
    // Initialization
    void initialize(std::function<void(bool success)> callback) override;
    void shutdown(std::function<void(bool success)> callback) override;
    
    // Task Execution
    void executeAction(const ExecutionAction &action,
                      const ExecutionContext &context,
                      ExecutionCallback callback) override;
    void executeTask(const ExecutionTask &task,
                    ExecutionProgressCallback progressCallback,
                    std::function<void(const ExecutionResult &)> completionCallback) override;
    void executePlan(const ExecutionPlan &plan,
                    const ExecutionContext &context,
                    ExecutionProgressCallback progressCallback,
                    std::function<void(bool success)> completionCallback) override;
    
    // Execution Control
    void cancelTask(const QString &taskId,
                   std::function<void(bool success)> callback) override;
    void pauseTask(const QString &taskId,
                  std::function<void(bool success)> callback) override;
    void resumeTask(const QString &taskId,
                   std::function<void(bool success)> callback) override;
    
    // Tool Execution
    void executeTool(const QString &toolName,
                    const QVariantMap &parameters,
                    const ExecutionContext &context,
                    ExecutionCallback callback) override;
    QStringList getAvailableTools() const override;
    bool validateToolExecution(const QString &toolName,
                              const QVariantMap &parameters,
                              QString &errorMsg) override;
    
    // Skill Execution
    void executeSkill(const QString &skillId,
                     const QVariantMap &parameters,
                     const ExecutionContext &context,
                     ExecutionCallback callback) override;
    QStringList getAvailableSkills(const ExecutionContext &context) const override;
    
    // Approval Workflow
    void requestApproval(const ExecutionTask &task,
                        ExecutionApprovalCallback callback) override;
    void approveAction(const QString &taskId,
                      const QString &approverNote,
                      std::function<void(bool success)> callback) override;
    void rejectAction(const QString &taskId,
                     const QString &reason,
                     std::function<void(bool success)> callback) override;
    
    // Conditional Execution
    bool evaluateCondition(const QString &condition,
                          const QVariantMap &context) override;
    QVariantMap getConditionDetails(const QString &condition,
                                   const QVariantMap &context) override;
    
    // Sandboxed Execution
    void executeInSandbox(const ExecutionAction &action,
                         const ExecutionContext &context,
                         ExecutionCallback callback) override;
    bool checkSandboxRequirements(const ExecutionAction &action,
                                 QString &errorMsg) override;
    
    // Retry and Recovery
    void retryAction(const QString &taskId,
                    const QString &actionId,
                    ExecutionCallback callback) override;
    void rollback(const QString &taskId,
                 std::function<void(bool success)> callback) override;
    
    // History & Tracking
    ExecutionTask getTaskStatus(const QString &taskId) const override;
    QVector<ExecutionHistoryEntry> getExecutionHistory(
        const QString &taskId,
        int limit = 100) const override;
    QVector<ExecutionHistoryEntry> getAllExecutionHistory(
        int limit = 100) const override;
    ExecutionResult getTaskResult(const QString &taskId) const override;
    
    // Query & Analysis
    QVector<ExecutionTask> getRunningTasks() const override;
    QVector<ExecutionTask> getCompletedTasks(int limit = 100) const override;
    QVector<ExecutionTask> getFailedTasks(int limit = 100) const override;
    QVector<ExecutionTask> searchTasks(
        const QString &threadId,
        const QVariantMap &criteria) const override;
    
    // Statistics
    ExecutionStats getExecutionStats() const override;
    ExecutionStats getThreadExecutionStats(const QString &threadId) const override;
    
    // Configuration
    void setDefaultTimeout(int timeoutMs) override;
    void setMaxRetries(int maxRetries) override;
    void setDryRun(bool enabled) override;

private:
    struct TaskEntry {
        ExecutionTask task;
        QVector<ExecutionResult> results;
        QVector<ExecutionHistoryEntry> history;
        QTimer *timeoutTimer{nullptr};
        bool isApprovalPending{false};
    };
    
    QMap<QString, TaskEntry> m_tasks;
    QVector<ExecutionHistoryEntry> m_globalHistory;
    
    int m_defaultTimeout{30000};
    int m_maxRetries{0};
    bool m_dryRunMode{false};
    
    mutable QMutex m_mutex;
    
    // Execution
    ExecutionResult executeActionImpl(const ExecutionAction &action,
                                     const ExecutionContext &context);
    ExecutionResult executeToolImpl(const QString &toolName,
                                   const QVariantMap &parameters);
    ExecutionResult executeSkillImpl(const QString &skillId,
                                    const QVariantMap &parameters);
    
    // Condition evaluation
    bool evaluateSimpleCondition(const QString &condition,
                                const QVariantMap &context);
    
    // Helpers
    void recordHistory(const ExecutionHistoryEntry &entry);
    void updateTaskProgress(ExecutionTask &task);
    void emitProgressEvent(const QString &taskId, ExecutionEventType type,
                          const QString &message, const QVariantMap &data = {});
};

using DefaultExecutionEnginePtr = std::shared_ptr<DefaultExecutionEngine>;
