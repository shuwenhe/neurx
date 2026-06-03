#include "DefaultExecutionEngine.h"
#include <QDebug>
#include <QUuid>
#include <QDateTime>
#include <QElapsedTimer>
#include <algorithm>

DefaultExecutionEngine::DefaultExecutionEngine(QObject *parent)
    : ExecutionEngine(parent)
{
}

DefaultExecutionEngine::~DefaultExecutionEngine()
{
}

void DefaultExecutionEngine::initialize(std::function<void(bool success)> callback)
{
    // Initialize engine components
    if (callback) callback(true);
}

void DefaultExecutionEngine::shutdown(std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    // Cancel all running tasks
    for (auto &entry : m_tasks) {
        if (entry.timeoutTimer) {
            entry.timeoutTimer->stop();
            delete entry.timeoutTimer;
            entry.timeoutTimer = nullptr;
        }
    }
    
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultExecutionEngine::executeAction(const ExecutionAction &action,
                                          const ExecutionContext &context,
                                          ExecutionCallback callback)
{
    QElapsedTimer timer;
    timer.start();
    
    ExecutionResult result;
    result.actionId = action.id;
    
    if (m_dryRunMode) {
        result.success = true;
        result.output = "Dry run: would execute " + action.target;
        result.durationMs = timer.elapsed();
        
        if (callback) callback(result);
        return;
    }
    
    // Validate action
    QString errorMsg;
    if (action.type == ExecutionType::Tool) {
        if (!validateToolExecution(action.target, action.parameters, errorMsg)) {
            result.errorType = ExecutionErrorType::InvalidParameters;
            result.errorMessage = "Tool validation failed: " + errorMsg;
            result.durationMs = timer.elapsed();
            
            if (callback) callback(result);
            return;
        }
        
        // Execute tool
        result = executeToolImpl(action.target, action.parameters);
    }
    else if (action.type == ExecutionType::Skill) {
        // Execute skill
        result = executeSkillImpl(action.target, action.parameters);
    }
    else if (action.type == ExecutionType::Script) {
        result.success = true;
        result.output = "Script execution: " + action.target;
    }
    
    result.durationMs = timer.elapsed();
    result.completedAt = QDateTime::currentDateTime();
    
    if (callback) callback(result);
}

void DefaultExecutionEngine::executeTask(const ExecutionTask &task,
                                        ExecutionProgressCallback progressCallback,
                                        std::function<void(const ExecutionResult &)> completionCallback)
{
    QMutexLocker locker(&m_mutex);
    
    QString taskId = QUuid::createUuid().toString();
    ExecutionTask workingTask = task;
    workingTask.taskId = taskId;
    workingTask.startedAt = QDateTime::currentDateTime();
    
    TaskEntry entry;
    entry.task = workingTask;
    m_tasks[taskId] = entry;
    
    locker.unlock();
    
    emit taskStarted(taskId);
    
    if (progressCallback) {
        ExecutionEvent event;
        event.taskId = taskId;
        event.type = ExecutionEventType::Started;
        event.message = "Task started";
        progressCallback(event);
    }
    
    ExecutionResult overallResult;
    overallResult.taskId = taskId;
    overallResult.success = true;
    
    // Execute actions
    for (int i = 0; i < workingTask.actions.size(); ++i) {
        const auto &action = workingTask.actions[i];
        
        // Check if we should skip
        if (!action.condition.isEmpty()) {
            if (!evaluateCondition(action.condition, workingTask.context.variables)) {
                if (progressCallback) {
                    ExecutionEvent event;
                    event.taskId = taskId;
                    event.actionId = action.id;
                    event.type = ExecutionEventType::ActionStarted;
                    event.message = "Skipping action due to condition";
                    progressCallback(event);
                }
                continue;
            }
        }
        
        // Notify action starting
        if (progressCallback) {
            ExecutionEvent event;
            event.taskId = taskId;
            event.actionId = action.id;
            event.type = ExecutionEventType::ActionStarted;
            event.message = "Executing action: " + action.name;
            progressCallback(event);
        }
        
        // Execute action
        ExecutionResult result;
        result.taskId = taskId;
        result.actionId = action.id;
        
        executeAction(action, workingTask.context, [&result](const ExecutionResult &r) {
            result = r;
        });
        
        // Record result
        QMutexLocker locker2(&m_mutex);
        auto it = m_tasks.find(taskId);
        if (it != m_tasks.end()) {
            it->results.append(result);
        }
        locker2.unlock();
        
        // Notify completion
        if (progressCallback) {
            ExecutionEvent event;
            event.taskId = taskId;
            event.actionId = action.id;
            event.type = result.success ? ExecutionEventType::ActionCompleted : ExecutionEventType::ActionFailed;
            event.message = result.success ? "Action completed" : "Action failed";
            event.data = result.resultData;
            progressCallback(event);
        }
        
        // Handle errors
        if (!result.success) {
            if (!action.continueOnError) {
                overallResult.success = false;
                overallResult.errorMessage = result.errorMessage;
                overallResult.errorType = result.errorType;
                break;
            }
        }
    }
    
    // Update task
    QMutexLocker locker3(&m_mutex);
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        it->task.completedAt = QDateTime::currentDateTime();
        it->task.durationMs = it->task.startedAt.msecsTo(it->task.completedAt);
    }
    locker3.unlock();
    
    emit taskCompleted(taskId, overallResult.success);
    
    if (completionCallback) {
        completionCallback(overallResult);
    }
}

void DefaultExecutionEngine::executePlan(const ExecutionPlan &plan,
                                        const ExecutionContext &context,
                                        ExecutionProgressCallback progressCallback,
                                        std::function<void(bool success)> completionCallback)
{
    ExecutionTask task;
    task.actions = plan.actions;
    task.context = context;
    
    executeTask(task, progressCallback, [completionCallback](const ExecutionResult &result) {
        if (completionCallback) {
            completionCallback(result.success);
        }
    });
}

void DefaultExecutionEngine::cancelTask(const QString &taskId,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        it->task.status_str = "cancelled";
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultExecutionEngine::pauseTask(const QString &taskId,
                                      std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        it->task.status_str = "paused";
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultExecutionEngine::resumeTask(const QString &taskId,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        it->task.status_str = "running";
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultExecutionEngine::executeTool(const QString &toolName,
                                        const QVariantMap &parameters,
                                        const ExecutionContext &context,
                                        ExecutionCallback callback)
{
    ExecutionResult result;
    result = executeToolImpl(toolName, parameters);
    
    if (callback) callback(result);
}

QStringList DefaultExecutionEngine::getAvailableTools() const
{
    // Would be populated from ToolRegistry
    return QStringList{
        "read_file",
        "write_file",
        "run_command",
        "create_file",
        "delete_file",
        "list_directory",
        "grep_search"
    };
}

bool DefaultExecutionEngine::validateToolExecution(const QString &toolName,
                                                  const QVariantMap &parameters,
                                                  QString &errorMsg)
{
    if (toolName.isEmpty()) {
        errorMsg = "Tool name cannot be empty";
        return false;
    }
    
    if (!getAvailableTools().contains(toolName)) {
        errorMsg = "Tool not found: " + toolName;
        return false;
    }
    
    return true;
}

void DefaultExecutionEngine::executeSkill(const QString &skillId,
                                         const QVariantMap &parameters,
                                         const ExecutionContext &context,
                                         ExecutionCallback callback)
{
    ExecutionResult result;
    result = executeSkillImpl(skillId, parameters);
    
    if (callback) callback(result);
}

QStringList DefaultExecutionEngine::getAvailableSkills(const ExecutionContext &context) const
{
    // Would be populated from SkillManager
    return QStringList{
        "org.neurx.skill.analysis.code-review",
        "org.neurx.skill.writing.document-writer",
        "org.neurx.skill.coding.code-generator"
    };
}

void DefaultExecutionEngine::requestApproval(const ExecutionTask &task,
                                            ExecutionApprovalCallback callback)
{
    emit approvalRequired(task.taskId, task);
    
    if (callback) {
        // Callback will be invoked when approval is given
        callback(task, [this, taskId = task.taskId](bool approved) {
            if (approved) {
                approveAction(taskId, "", [](bool) {});
            } else {
                rejectAction(taskId, "User rejected", [](bool) {});
            }
        });
    }
}

void DefaultExecutionEngine::approveAction(const QString &taskId,
                                          const QString &approverNote,
                                          std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        it->isApprovalPending = false;
        locker.unlock();
        
        emit approvalRequired(taskId, it->task);
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultExecutionEngine::rejectAction(const QString &taskId,
                                         const QString &reason,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        it->task.status_str = "rejected";
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultExecutionEngine::evaluateCondition(const QString &condition,
                                              const QVariantMap &context)
{
    return evaluateSimpleCondition(condition, context);
}

QVariantMap DefaultExecutionEngine::getConditionDetails(const QString &condition,
                                                       const QVariantMap &context)
{
    QVariantMap details;
    details["condition"] = condition;
    details["result"] = evaluateCondition(condition, context);
    details["context"] = context;
    return details;
}

void DefaultExecutionEngine::executeInSandbox(const ExecutionAction &action,
                                             const ExecutionContext &context,
                                             ExecutionCallback callback)
{
    // Would use SandboxManager to execute in sandbox
    ExecutionResult result;
    result = executeActionImpl(action, context);
    
    if (callback) callback(result);
}

bool DefaultExecutionEngine::checkSandboxRequirements(const ExecutionAction &action,
                                                     QString &errorMsg)
{
    // Check if sandbox is available for the action
    return true;
}

void DefaultExecutionEngine::retryAction(const QString &taskId,
                                        const QString &actionId,
                                        ExecutionCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        // Find and retry the action
        for (const auto &action : it->task.actions) {
            if (action.id == actionId) {
                locker.unlock();
                
                ExecutionResult result;
                result = executeActionImpl(action, it->task.context);
                
                if (callback) callback(result);
                return;
            }
        }
    }
    
    locker.unlock();
    if (callback) {
        ExecutionResult error;
        error.success = false;
        error.errorMessage = "Action not found";
        callback(error);
    }
}

void DefaultExecutionEngine::rollback(const QString &taskId,
                                     std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end() && !it->history.isEmpty()) {
        // Rollback would reverse the actions in reverse order
        it->history.clear();
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

ExecutionTask DefaultExecutionEngine::getTaskStatus(const QString &taskId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        return it->task;
    }
    
    return ExecutionTask();
}

QVector<ExecutionHistoryEntry> DefaultExecutionEngine::getExecutionHistory(
    const QString &taskId,
    int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        QVector<ExecutionHistoryEntry> result;
        qsizetype totalSize = it->history.size();
        qsizetype start = std::max(static_cast<qsizetype>(0), totalSize - static_cast<qsizetype>(limit));
        for (qsizetype i = start; i < totalSize; ++i) {
            result.append(it->history[i]);
        }
        return result;
    }
    
    return QVector<ExecutionHistoryEntry>();
}

QVector<ExecutionHistoryEntry> DefaultExecutionEngine::getAllExecutionHistory(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionHistoryEntry> result;
    qsizetype totalSize = m_globalHistory.size();
    qsizetype start = std::max(static_cast<qsizetype>(0), totalSize - static_cast<qsizetype>(limit));
    for (qsizetype i = start; i < totalSize; ++i) {
        result.append(m_globalHistory[i]);
    }
    
    return result;
}

ExecutionResult DefaultExecutionEngine::getTaskResult(const QString &taskId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end() && !it->results.isEmpty()) {
        return it->results.last();
    }
    
    return ExecutionResult();
}

QVector<ExecutionTask> DefaultExecutionEngine::getRunningTasks() const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionTask> running;
    for (const auto &entry : m_tasks) {
        if (entry.task.status_str == "running") {
            running.append(entry.task);
        }
    }
    
    return running;
}

QVector<ExecutionTask> DefaultExecutionEngine::getCompletedTasks(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionTask> completed;
    int count = 0;
    
    QVector<TaskEntry> allTasks = m_tasks.values().toVector();
    std::reverse(allTasks.begin(), allTasks.end());
    
    for (const auto &entry : allTasks) {
        if (count >= limit) break;
        if (entry.task.status_str == "completed") {
            completed.append(entry.task);
            count++;
        }
    }
    
    return completed;
}

QVector<ExecutionTask> DefaultExecutionEngine::getFailedTasks(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionTask> failed;
    int count = 0;
    
    QVector<TaskEntry> allTasks = m_tasks.values().toVector();
    std::reverse(allTasks.begin(), allTasks.end());
    
    for (const auto &entry : allTasks) {
        if (count >= limit) break;
        if (entry.task.status_str == "failed") {
            failed.append(entry.task);
            count++;
        }
    }
    
    return failed;
}

QVector<ExecutionTask> DefaultExecutionEngine::searchTasks(
    const QString &threadId,
    const QVariantMap &criteria) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionTask> results;
    
    for (const auto &entry : m_tasks) {
        if (entry.task.threadId == threadId) {
            bool matches = true;
            
            if (criteria.contains("status")) {
                if (entry.task.status_str != criteria["status"].toString()) {
                    matches = false;
                }
            }
            
            if (matches) {
                results.append(entry.task);
            }
        }
    }
    
    return results;
}

ExecutionStats DefaultExecutionEngine::getExecutionStats() const
{
    QMutexLocker locker(&m_mutex);
    
    ExecutionStats stats;
    
    for (const auto &entry : m_tasks) {
        stats.totalTasks++;
        
        if (entry.task.status_str == "completed") {
            stats.completedTasks++;
        } else if (entry.task.status_str == "failed") {
            stats.failedTasks++;
        }
        
        stats.totalActions += entry.task.actions.size();
        stats.totalDurationMs += entry.task.durationMs;
    }
    
    if (stats.totalTasks > 0) {
        stats.successRate = (stats.completedTasks * 100.0) / stats.totalTasks;
        stats.averageDurationMs = stats.totalDurationMs / stats.totalTasks;
    }
    
    return stats;
}

ExecutionStats DefaultExecutionEngine::getThreadExecutionStats(const QString &threadId) const
{
    QMutexLocker locker(&m_mutex);
    
    ExecutionStats stats;
    
    for (const auto &entry : m_tasks) {
        if (entry.task.threadId == threadId) {
            stats.totalTasks++;
            
            if (entry.task.status_str == "completed") {
                stats.completedTasks++;
            } else if (entry.task.status_str == "failed") {
                stats.failedTasks++;
            }
            
            stats.totalActions += entry.task.actions.size();
            stats.totalDurationMs += entry.task.durationMs;
        }
    }
    
    if (stats.totalTasks > 0) {
        stats.successRate = (stats.completedTasks * 100.0) / stats.totalTasks;
        stats.averageDurationMs = stats.totalDurationMs / stats.totalTasks;
    }
    
    return stats;
}

void DefaultExecutionEngine::setDefaultTimeout(int timeoutMs)
{
    m_defaultTimeout = timeoutMs;
}

void DefaultExecutionEngine::setMaxRetries(int maxRetries)
{
    m_maxRetries = maxRetries;
}

void DefaultExecutionEngine::setDryRun(bool enabled)
{
    m_dryRunMode = enabled;
}

// Private implementation methods

ExecutionResult DefaultExecutionEngine::executeActionImpl(const ExecutionAction &action,
                                                        const ExecutionContext &context)
{
    ExecutionResult result;
    result.actionId = action.id;
    result.success = true;
    result.output = "Action executed: " + action.name;
    return result;
}

ExecutionResult DefaultExecutionEngine::executeToolImpl(const QString &toolName,
                                                       const QVariantMap &parameters)
{
    ExecutionResult result;
    result.success = true;
    result.output = QString("Tool %1 executed with params: %2")
        .arg(toolName, QString::number(parameters.size()));
    result.tokensUsed = 10;
    return result;
}

ExecutionResult DefaultExecutionEngine::executeSkillImpl(const QString &skillId,
                                                        const QVariantMap &parameters)
{
    ExecutionResult result;
    result.success = true;
    result.output = QString("Skill %1 executed").arg(skillId);
    result.tokensUsed = 15;
    return result;
}

bool DefaultExecutionEngine::evaluateSimpleCondition(const QString &condition,
                                                     const QVariantMap &context)
{
    // Simple condition evaluation
    if (condition == "true" || condition.isEmpty()) {
        return true;
    }
    if (condition == "false") {
        return false;
    }
    
    // Could implement expression evaluator
    return true;
}

void DefaultExecutionEngine::recordHistory(const ExecutionHistoryEntry &entry)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tasks.find(entry.taskId);
    if (it != m_tasks.end()) {
        it->history.append(entry);
    }
    
    m_globalHistory.append(entry);
}

void DefaultExecutionEngine::updateTaskProgress(ExecutionTask &task)
{
    if (task.actions.isEmpty()) return;
    
    // Calculate progress based on completed actions
    int completed = 0;
    for (const auto &action : task.actions) {
        if (action.type != ExecutionType::Tool) {
            completed++;
        }
    }
    
    task.progressPercentage = (completed * 100.0) / task.actions.size();
}

void DefaultExecutionEngine::emitProgressEvent(const QString &taskId,
                                              ExecutionEventType type,
                                              const QString &message,
                                              const QVariantMap &data)
{
    ExecutionEvent event;
    event.taskId = taskId;
    event.type = type;
    event.message = message;
    event.data = data;
    
    emit executionProgress(event);
}

#include "moc_DefaultExecutionEngine.cpp"
