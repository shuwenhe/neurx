#pragma once

#include "ExecutionTypes.h"
#include <QObject>
#include <memory>

// Forward declarations
class ToolRegistry;
class SkillManager;
class GoalManager;
class ApprovalManager;
class SandboxManager;

/**
 * @class ExecutionEngine
 * @brief Task and action execution orchestration
 * 
 * Handles:
 * - Task and action execution
 * - Tool, skill, and goal orchestration
 * - Approval workflow
 * - Sandboxed execution
 * - Error recovery and rollback
 * - Execution history and audit
 */
class ExecutionEngine : public QObject {
    Q_OBJECT
public:
    explicit ExecutionEngine(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~ExecutionEngine() = default;
    
    // ── Initialization ─────────────────────────────────────────
    
    /// Initialize with dependencies
    virtual void initialize(std::function<void(bool success)> callback) = 0;
    
    /// Shutdown
    virtual void shutdown(std::function<void(bool success)> callback) = 0;
    
    // ── Task Execution ────────────────────────────────────────
    
    /// Execute single action
    virtual void executeAction(const ExecutionAction &action,
                              const ExecutionContext &context,
                              ExecutionCallback callback) = 0;
    
    /// Execute task with multiple actions
    virtual void executeTask(const ExecutionTask &task,
                            ExecutionProgressCallback progressCallback,
                            std::function<void(const ExecutionResult &)> completionCallback) = 0;
    
    /// Execute plan
    virtual void executePlan(const ExecutionPlan &plan,
                            const ExecutionContext &context,
                            ExecutionProgressCallback progressCallback,
                            std::function<void(bool success)> completionCallback) = 0;
    
    // ── Execution Control ──────────────────────────────────────
    
    /// Cancel execution
    virtual void cancelTask(const QString &taskId,
                           std::function<void(bool success)> callback) = 0;
    
    /// Pause execution
    virtual void pauseTask(const QString &taskId,
                         std::function<void(bool success)> callback) = 0;
    
    /// Resume execution
    virtual void resumeTask(const QString &taskId,
                           std::function<void(bool success)> callback) = 0;
    
    // ── Tool Execution ────────────────────────────────────────
    
    /// Execute tool
    virtual void executeTool(const QString &toolName,
                            const QVariantMap &parameters,
                            const ExecutionContext &context,
                            ExecutionCallback callback) = 0;
    
    /// Get available tools
    virtual QStringList getAvailableTools() const = 0;
    
    /// Validate tool execution
    virtual bool validateToolExecution(const QString &toolName,
                                      const QVariantMap &parameters,
                                      QString &errorMsg) = 0;
    
    // ── Skill Execution ───────────────────────────────────────
    
    /// Execute skill
    virtual void executeSkill(const QString &skillId,
                             const QVariantMap &parameters,
                             const ExecutionContext &context,
                             ExecutionCallback callback) = 0;
    
    /// Get available skills
    virtual QStringList getAvailableSkills(const ExecutionContext &context) const = 0;
    
    // ── Approval Workflow ──────────────────────────────────────
    
    /// Request approval for action
    virtual void requestApproval(const ExecutionTask &task,
                                ExecutionApprovalCallback callback) = 0;
    
    /// Approve action
    virtual void approveAction(const QString &taskId,
                              const QString &approverNote,
                              std::function<void(bool success)> callback) = 0;
    
    /// Reject action
    virtual void rejectAction(const QString &taskId,
                             const QString &reason,
                             std::function<void(bool success)> callback) = 0;
    
    // ── Conditional Execution ─────────────────────────────────
    
    /// Evaluate condition
    virtual bool evaluateCondition(const QString &condition,
                                  const QVariantMap &context) = 0;
    
    /// Get condition evaluation details
    virtual QVariantMap getConditionDetails(const QString &condition,
                                           const QVariantMap &context) = 0;
    
    // ── Sandboxed Execution ────────────────────────────────────
    
    /// Execute in sandbox
    virtual void executeInSandbox(const ExecutionAction &action,
                                 const ExecutionContext &context,
                                 ExecutionCallback callback) = 0;
    
    /// Check sandbox requirements
    virtual bool checkSandboxRequirements(const ExecutionAction &action,
                                         QString &errorMsg) = 0;
    
    // ── Retry and Recovery ─────────────────────────────────────
    
    /// Retry failed action
    virtual void retryAction(const QString &taskId,
                            const QString &actionId,
                            ExecutionCallback callback) = 0;
    
    /// Rollback execution
    virtual void rollback(const QString &taskId,
                         std::function<void(bool success)> callback) = 0;
    
    // ── History & Tracking ────────────────────────────────────
    
    /// Get task status
    virtual ExecutionTask getTaskStatus(const QString &taskId) const = 0;
    
    /// Get execution history
    virtual QVector<ExecutionHistoryEntry> getExecutionHistory(
        const QString &taskId,
        int limit = 100) const = 0;
    
    /// Get all execution history
    virtual QVector<ExecutionHistoryEntry> getAllExecutionHistory(
        int limit = 100) const = 0;
    
    /// Get task result
    virtual ExecutionResult getTaskResult(const QString &taskId) const = 0;
    
    // ── Query & Analysis ──────────────────────────────────────
    
    /// Get running tasks
    virtual QVector<ExecutionTask> getRunningTasks() const = 0;
    
    /// Get completed tasks
    virtual QVector<ExecutionTask> getCompletedTasks(int limit = 100) const = 0;
    
    /// Get failed tasks
    virtual QVector<ExecutionTask> getFailedTasks(int limit = 100) const = 0;
    
    /// Search tasks
    virtual QVector<ExecutionTask> searchTasks(
        const QString &threadId,
        const QVariantMap &criteria) const = 0;
    
    // ── Statistics ─────────────────────────────────────────────
    
    /// Get execution statistics
    virtual ExecutionStats getExecutionStats() const = 0;
    
    /// Get thread execution statistics
    virtual ExecutionStats getThreadExecutionStats(const QString &threadId) const = 0;
    
    // ── Configuration ──────────────────────────────────────────
    
    /// Set default timeout
    virtual void setDefaultTimeout(int timeoutMs) = 0;
    
    /// Set max retries
    virtual void setMaxRetries(int maxRetries) = 0;
    
    /// Enable/disable dry run
    virtual void setDryRun(bool enabled) = 0;

signals:
    /// Task started signal
    void taskStarted(const QString &taskId);
    
    /// Task completed signal
    void taskCompleted(const QString &taskId, bool success);
    
    /// Execution progress signal
    void executionProgress(const ExecutionEvent &event);
    
    /// Action result signal
    void actionCompleted(const QString &actionId, const ExecutionResult &result);
    
    /// Approval required signal
    void approvalRequired(const QString &taskId, const ExecutionTask &task);
    
    /// Execution error signal
    void executionError(const QString &taskId, const ExecutionResult &result);
};

using ExecutionEnginePtr = std::shared_ptr<ExecutionEngine>;
