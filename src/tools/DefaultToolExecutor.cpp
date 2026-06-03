#include "DefaultToolExecutor.h"
#include <QUuid>
#include <QDateTime>
#include <QDebug>
#include <QCryptographicHash>

DefaultToolExecutor::DefaultToolExecutor(QObject *parent)
    : ToolExecutor(parent),
      m_cacheEnabled(true),
      m_cacheExpirySeconds(3600),
      m_maxRetries(3),
      m_retryDelayMs(1000),
      m_backoffMultiplier(2.0f),
      m_executionTimeoutMs(30000),
      m_maxConcurrency(4),
      m_detailedLogging(false),
      m_totalCost(0.0f) {
}

// ── 工具执行 ────────────────────────────────────────

QString DefaultToolExecutor::executeTool(
    const ToolExecutionRequest &request,
    ToolExecutionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    auto result = executeInternal(request);
    
    recordExecution(result);
    updatePerformanceData(request.toolId, result);
    
    if (callback) {
        callback(result);
    }
    
    return result.executionId;
}

void DefaultToolExecutor::executeToolAsync(
    const ToolExecutionRequest &request,
    ToolExecutionCallback callback) {
    
    // 入队执行
    queueExecution(request, callback);
}

QString DefaultToolExecutor::executeCapability(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    ToolExecutionCallback callback) {
    
    ToolExecutionRequest request;
    request.executionId = generateExecutionId();
    request.toolId = toolId;
    request.capabilityName = capabilityName;
    request.parameters = parameters;
    request.timeoutMs = m_executionTimeoutMs;
    
    return executeTool(request, callback);
}

void DefaultToolExecutor::executeToolChain(
    const ToolChainDefinition &chain,
    const QVariantMap &globalParams,
    ToolChainCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolExecutionResult> results;
    QVariantMap contextData = globalParams;
    
    for (const auto &step : chain.steps) {
        ToolExecutionRequest request;
        request.executionId = generateExecutionId();
        request.toolId = step.toolId;
        request.capabilityName = step.capabilityName;
        
        // 合并参数
        auto params = step.parameters;
        for (auto it = globalParams.begin(); it != globalParams.end(); ++it) {
            params[it.key()] = it.value();
        }
        
        // 如果需要从前一个步骤获取输入
        if (!step.inputFromPrevious.isEmpty() && !results.isEmpty()) {
            for (const auto &input : step.inputFromPrevious) {
                if (results.last().result.contains(input)) {
                    params[input] = results.last().result[input];
                }
            }
        }
        
        request.parameters = params;
        
        auto result = executeInternal(request);
        results.append(result);
        
        recordExecution(result);
        updatePerformanceData(request.toolId, result);
        
        if (result.status == ExecutionStatus::Failed) {
            emit chainExecutionCompleted(chain.chainId);
            if (callback) {
                callback(results);
            }
            return;
        }
    }
    
    emit chainExecutionCompleted(chain.chainId);
    if (callback) {
        callback(results);
    }
}

QString DefaultToolExecutor::executeChainStep(
    const QString &chainId,
    int stepId,
    const QVariantMap &parameters,
    ToolExecutionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_chains.contains(chainId)) {
        return "";
    }
    
    const auto &chain = m_chains[chainId];
    
    if (stepId < 0 || stepId >= chain.steps.size()) {
        return "";
    }
    
    const auto &step = chain.steps[stepId];
    
    ToolExecutionRequest request;
    request.executionId = generateExecutionId();
    request.toolId = step.toolId;
    request.capabilityName = step.capabilityName;
    request.parameters = parameters;
    
    return executeTool(request, callback);
}

// ── 执行管理 ────────────────────────────────────────

ExecutionStatus DefaultToolExecutor::getExecutionStatus(
    const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        return m_executions[executionId].status;
    }
    
    return ExecutionStatus::Pending;
}

ToolExecutionResult DefaultToolExecutor::getExecutionResult(
    const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        return m_executions[executionId];
    }
    
    return ToolExecutionResult();
}

int DefaultToolExecutor::getExecutionProgress(const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        const auto &result = m_executions[executionId];
        if (result.status == ExecutionStatus::Running) {
            return 50;  // 简化：运行中50%
        } else if (result.status == ExecutionStatus::Completed) {
            return 100;
        }
    }
    
    return 0;
}

QString DefaultToolExecutor::getExecutionLog(const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executionLogs.contains(executionId)) {
        return m_executionLogs[executionId];
    }
    
    return "";
}

void DefaultToolExecutor::cancelExecution(
    const QString &executionId,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        m_executions[executionId].status = ExecutionStatus::Cancelled;
        emit executionCancelled(executionId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolExecutor::pauseExecution(
    const QString &executionId,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        if (m_executions[executionId].status == ExecutionStatus::Running) {
            if (callback) callback(true);
            return;
        }
    }
    
    if (callback) callback(false);
}

void DefaultToolExecutor::resumeExecution(
    const QString &executionId,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolExecutor::retryExecution(
    const QString &executionId,
    ToolExecutionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_executions.contains(executionId)) {
        return;
    }
    
    auto result = m_executions[executionId];
    result.status = ExecutionStatus::Pending;
    result.retryCount++;
    
    m_executions[executionId] = result;
    
    if (callback) {
        callback(result);
    }
}

// ── 执行历史 ────────────────────────────────────────

QVector<ToolExecutionResult> DefaultToolExecutor::getToolExecutionHistory(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executionHistory.contains(toolId)) {
        const auto &history = m_executionHistory[toolId];
        int start = qMax(0, history.size() - limit);
        return QVector<ToolExecutionResult>(history.begin() + start, history.end());
    }
    
    return QVector<ToolExecutionResult>();
}

QVector<ToolExecutionResult> DefaultToolExecutor::getUserExecutionHistory(
    const QString &userId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolExecutionResult> results;
    int count = 0;
    
    for (const auto &result : m_executions) {
        if (result.startedAt.toString() == userId && count < limit) {
            results.append(result);
            count++;
        }
    }
    
    return results;
}

QVariantMap DefaultToolExecutor::getExecutionStatistics(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    if (m_performanceData.contains(toolId)) {
        const auto &perf = m_performanceData[toolId];
        stats["successCount"] = perf.successCount;
        stats["failureCount"] = perf.failureCount;
        stats["totalExecutions"] = perf.totalExecutions;
        stats["successRate"] = perf.totalExecutions > 0 ? 
            (float)perf.successCount / perf.totalExecutions : 0.0f;
    }
    
    return stats;
}

QVariantMap DefaultToolExecutor::getExecutionTimeStats(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    if (m_performanceData.contains(toolId)) {
        const auto &perf = m_performanceData[toolId];
        stats["avgDuration"] = perf.avgDuration;
    }
    
    return stats;
}

QVariantMap DefaultToolExecutor::getFailureStats(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    if (m_performanceData.contains(toolId)) {
        const auto &perf = m_performanceData[toolId];
        stats["failureCount"] = perf.failureCount;
        stats["failureRate"] = perf.totalExecutions > 0 ? 
            (float)perf.failureCount / perf.totalExecutions : 0.0f;
    }
    
    return stats;
}

// ── 执行缓存 ────────────────────────────────────────

void DefaultToolExecutor::enableCache(bool enable) {
    QMutexLocker locker(&m_mutex);
    m_cacheEnabled = enable;
}

void DefaultToolExecutor::setCacheExpiry(int seconds) {
    QMutexLocker locker(&m_mutex);
    m_cacheExpirySeconds = seconds;
}

QVariantMap DefaultToolExecutor::getCachedResult(
    const QString &toolId,
    const QVariantMap &parameters) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_cacheEnabled) {
        return QVariantMap();
    }
    
    QString cacheKey = generateCacheKey(toolId, parameters);
    
    if (m_cache.contains(cacheKey)) {
        const auto &entry = m_cache[cacheKey];
        
        if (entry.createdAt.addSecs(m_cacheExpirySeconds) > QDateTime::currentDateTime()) {
            return entry.result;
        }
    }
    
    return QVariantMap();
}

void DefaultToolExecutor::clearCache(const QString &toolId) {
    
    QMutexLocker locker(&m_mutex);
    
    if (toolId.isEmpty()) {
        m_cache.clear();
    } else {
        // 清除特定工具的缓存
        auto it = m_cache.begin();
        while (it != m_cache.end()) {
            if (it.key().startsWith(toolId)) {
                it = m_cache.erase(it);
            } else {
                ++it;
            }
        }
    }
}

QVariantMap DefaultToolExecutor::getCacheStatistics() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["cacheSize"] = m_cache.size();
    stats["cacheEnabled"] = m_cacheEnabled;
    stats["expirySeconds"] = m_cacheExpirySeconds;
    
    return stats;
}

// ── 工具链管理 ───────────────────────────────────────

QString DefaultToolExecutor::createToolChain(
    const ToolChainDefinition &chain,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QString chainId = QUuid::createUuid().toString();
    auto mutableChain = chain;
    mutableChain.chainId = chainId;
    mutableChain.createdAt = QDateTime::currentDateTime();
    
    m_chains[chainId] = mutableChain;
    
    if (callback) callback(true);
    
    return chainId;
}

ToolChainDefinition DefaultToolExecutor::getToolChain(const QString &chainId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_chains.contains(chainId)) {
        return m_chains[chainId];
    }
    
    return ToolChainDefinition();
}

QVector<ToolChainDefinition> DefaultToolExecutor::listToolChains() const {
    
    QMutexLocker locker(&m_mutex);
    
    return QVector<ToolChainDefinition>(m_chains.values().begin(), m_chains.values().end());
}

void DefaultToolExecutor::updateToolChain(
    const ToolChainDefinition &chain,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_chains.contains(chain.chainId)) {
        m_chains[chain.chainId] = chain;
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolExecutor::deleteToolChain(
    const QString &chainId,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    bool success = m_chains.remove(chainId) > 0;
    if (callback) callback(success);
}

bool DefaultToolExecutor::validateToolChain(
    const ToolChainDefinition &chain,
    QString &errorMessage) {
    
    if (chain.steps.isEmpty()) {
        errorMessage = "Chain must have at least one step";
        return false;
    }
    
    return true;
}

QVector<QVector<ToolExecutionResult>> DefaultToolExecutor::getChainExecutionHistory(
    const QString &chainId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVector<ToolExecutionResult>> history;
    // 简化实现
    return history;
}

// ── 并发执行 ────────────────────────────────────────

void DefaultToolExecutor::executeToolsInParallel(
    const QVector<ToolExecutionRequest> &requests,
    ToolChainCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolExecutionResult> results;
    
    for (const auto &request : requests) {
        auto result = executeInternal(request);
        results.append(result);
        recordExecution(result);
        updatePerformanceData(request.toolId, result);
    }
    
    if (callback) {
        callback(results);
    }
}

QString DefaultToolExecutor::queueExecution(
    const ToolExecutionRequest &request,
    ToolExecutionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_activeExecutions.size() < m_maxConcurrency) {
        m_activeExecutions.append(request.executionId);
        emit queueChanged();
        
        auto result = executeInternal(request);
        m_activeExecutions.removeAll(request.executionId);
        
        if (callback) callback(result);
        
        emit queueChanged();
        return result.executionId;
    } else {
        m_executionQueue.enqueue(request);
        emit queueChanged();
        return request.executionId;
    }
}

QVector<ToolExecutionRequest> DefaultToolExecutor::getExecutionQueue() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolExecutionRequest> queue;
    for (const auto &request : m_executionQueue) {
        queue.append(request);
    }
    return queue;
}

QVector<QString> DefaultToolExecutor::getActiveExecutions() const {
    
    QMutexLocker locker(&m_mutex);
    
    return m_activeExecutions;
}

int DefaultToolExecutor::getMaxConcurrency() const {
    QMutexLocker locker(&m_mutex);
    return m_maxConcurrency;
}

void DefaultToolExecutor::setMaxConcurrency(int maxConcurrent) {
    QMutexLocker locker(&m_mutex);
    m_maxConcurrency = maxConcurrent;
}

// ── 错误处理和重试 ──────────────────────────────────

void DefaultToolExecutor::setRetryPolicy(
    int maxRetries,
    int delayMs,
    float backoffMultiplier) {
    
    QMutexLocker locker(&m_mutex);
    m_maxRetries = maxRetries;
    m_retryDelayMs = delayMs;
    m_backoffMultiplier = backoffMultiplier;
}

void DefaultToolExecutor::setExecutionTimeout(int timeoutMs) {
    QMutexLocker locker(&m_mutex);
    m_executionTimeoutMs = timeoutMs;
}

QVector<ToolExecutionResult> DefaultToolExecutor::getFailedExecutions(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolExecutionResult> failed;
    int count = 0;
    
    for (const auto &result : m_executions) {
        if (result.status == ExecutionStatus::Failed && count < limit) {
            failed.append(result);
            count++;
        }
    }
    
    return failed;
}

QString DefaultToolExecutor::analyzeFailure(const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        const auto &result = m_executions[executionId];
        return QString("Tool: %1, Error: %2, Retries: %3")
            .arg(result.toolId, result.error, QString::number(result.retryCount));
    }
    
    return "Execution not found";
}

// ── 性能监控 ───────────────────────────────────────

QVariantMap DefaultToolExecutor::getPerformanceMetrics(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap metrics;
    
    if (m_performanceData.contains(toolId)) {
        const auto &perf = m_performanceData[toolId];
        metrics["avgDuration"] = perf.avgDuration;
        metrics["totalCost"] = perf.totalCost;
        metrics["successRate"] = perf.totalExecutions > 0 ? 
            (float)perf.successCount / perf.totalExecutions : 0.0f;
    }
    
    return metrics;
}

QVariantMap DefaultToolExecutor::getResourceUsage(const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap usage;
    usage["executionId"] = executionId;
    usage["memoryUsage"] = 0;  // 简化
    usage["cpuUsage"] = 0;
    
    return usage;
}

float DefaultToolExecutor::getExecutionCost(const ToolExecutionRequest &request) const {
    
    // 简单成本模型
    return 0.01f;  // 每次执行$0.01
}

float DefaultToolExecutor::getTotalExecutionCost() const {
    
    QMutexLocker locker(&m_mutex);
    
    return m_totalCost;
}

// ── 执行日志 ────────────────────────────────────────

void DefaultToolExecutor::enableDetailedLogging(bool enable) {
    QMutexLocker locker(&m_mutex);
    m_detailedLogging = enable;
}

QString DefaultToolExecutor::exportExecutionReport(const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_executions.contains(executionId)) {
        return "";
    }
    
    const auto &result = m_executions[executionId];
    
    QString report = "Execution Report\n";
    report += QString("ID: %1\n").arg(result.executionId);
    report += QString("Tool: %1\n").arg(result.toolId);
    report += QString("Status: %1\n").arg(static_cast<int>(result.status));
    report += QString("Duration: %1ms\n").arg(result.durationMs);
    
    return report;
}

QString DefaultToolExecutor::exportPerformanceReport(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QString report = "Performance Report\n";
    report += QString("Tool: %1\n").arg(toolId);
    
    if (m_performanceData.contains(toolId)) {
        const auto &perf = m_performanceData[toolId];
        report += QString("Executions: %1\n").arg(perf.totalExecutions);
        report += QString("Success Rate: %1%\n").arg(
            (float)perf.successCount / perf.totalExecutions * 100);
    }
    
    return report;
}

// ── 辅助方法 ────────────────────────────────────────

QString DefaultToolExecutor::generateExecutionId() {
    return QUuid::createUuid().toString().remove("{").remove("}");
}

QString DefaultToolExecutor::generateCacheKey(
    const QString &toolId,
    const QVariantMap &parameters) const {
    
    QString key = toolId;
    
    for (auto it = parameters.begin(); it != parameters.end(); ++it) {
        key += "_" + it.key() + ":" + it.value().toString();
    }
    
    QByteArray hash = QCryptographicHash::hash(key.toUtf8(), QCryptographicHash::Md5);
    return hash.toHex();
}

ToolExecutionResult DefaultToolExecutor::executeInternal(
    const ToolExecutionRequest &request) {
    
    ToolExecutionResult result;
    result.executionId = request.executionId;
    result.toolId = request.toolId;
    result.status = ExecutionStatus::Completed;
    result.startedAt = QDateTime::currentDateTime();
    result.completedAt = QDateTime::currentDateTime();
    result.durationMs = 100;  // 模拟100ms执行时间
    result.result = {{"success", true}};
    result.costEstimate = 0.01f;
    result.fromCache = false;
    
    return result;
}

void DefaultToolExecutor::recordExecution(const ToolExecutionResult &result) {
    
    m_executions[result.executionId] = result;
    m_executionHistory[result.toolId].append(result);
}

void DefaultToolExecutor::updatePerformanceData(
    const QString &toolId,
    const ToolExecutionResult &result) {
    
    auto &perf = m_performanceData[toolId];
    perf.totalExecutions++;
    
    if (result.status == ExecutionStatus::Completed) {
        perf.successCount++;
    } else {
        perf.failureCount++;
    }
    
    // 更新平均时间
    perf.avgDuration = (perf.avgDuration * (perf.totalExecutions - 1) + result.durationMs) 
        / perf.totalExecutions;
    
    perf.totalCost += result.costEstimate;
    m_totalCost += result.costEstimate;
}
