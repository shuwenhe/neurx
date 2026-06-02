#include "ToolBridge.h"
#include "AgentController.h"
#include <QDebug>
#include <QDateTime>
#include <QEventLoop>
#include <QJsonDocument>
#include <QJsonObject>

ToolBridge::ToolBridge(QObject *parent)
    : QObject(parent) {
}

ToolBridge::~ToolBridge() {
    shutdown();
}

// ── 初始化 ────────────────────────────────────────

bool ToolBridge::initialize(AgentController *controller) {
    QMutexLocker locker(&m_mutex);

    if (m_initialized) {
        qWarning() << "ToolBridge already initialized";
        return true;
    }

    if (!controller) {
        qCritical() << "AgentController is nullptr";
        return false;
    }

    m_controller = controller;

    try {
        // 创建并初始化Claude工具系统
        m_toolSystem = std::make_shared<ClaudeToolSystem>();
        if (!m_toolSystem->initialize()) {
            qCritical() << "Failed to initialize ClaudeToolSystem";
            return false;
        }

        // 获取AgentController中的系统指针
        // 注：这些将通过AgentController::getTool*方法获取
        // 这里简化为直接创建新实例
        m_codeMagic = std::make_shared<DefaultCodeMagic>();
        m_memory = std::make_shared<DefaultMemoryManager>();
        m_approval = std::make_shared<DefaultApprovalManager>();
        m_plugins = std::make_shared<DefaultPluginManager>();

        // 初始化各个子系统
        if (!m_codeMagic || !m_memory || !m_approval || !m_plugins) {
            qCritical() << "Failed to create subsystem managers";
            return false;
        }

        // 连接信号-槽
        connect(m_toolSystem.get(), &ClaudeToolSystem::toolExecutionCompleted,
                this, &ToolBridge::onToolExecutionCompleted);

        m_initialized = true;
        qDebug() << "ToolBridge initialized successfully";

        emit systemStatusChanged();
        return true;

    } catch (const std::exception &e) {
        qCritical() << "Exception during ToolBridge initialization:" << e.what();
        return false;
    }
}

bool ToolBridge::isInitialized() const {
    QMutexLocker locker(&m_mutex);
    return m_initialized;
}

void ToolBridge::shutdown() {
    QMutexLocker locker(&m_mutex);

    if (m_toolSystem) {
        m_toolSystem->shutdown();
    }

    m_toolSystem.reset();
    m_codeMagic.reset();
    m_memory.reset();
    m_approval.reset();
    m_plugins.reset();

    m_initialized = false;
    qDebug() << "ToolBridge shut down";
}

// ── 系统访问 ────────────────────────────────────────

std::shared_ptr<ClaudeToolSystem> ToolBridge::getToolSystem() const {
    QMutexLocker locker(&m_mutex);
    return m_toolSystem;
}

std::shared_ptr<DefaultCodeMagic> ToolBridge::getCodeMagic() const {
    QMutexLocker locker(&m_mutex);
    return m_codeMagic;
}

std::shared_ptr<DefaultMemoryManager> ToolBridge::getMemory() const {
    QMutexLocker locker(&m_mutex);
    return m_memory;
}

std::shared_ptr<DefaultApprovalManager> ToolBridge::getApproval() const {
    QMutexLocker locker(&m_mutex);
    return m_approval;
}

std::shared_ptr<DefaultPluginManager> ToolBridge::getPlugins() const {
    QMutexLocker locker(&m_mutex);
    return m_plugins;
}

// ── 工具执行 ────────────────────────────────────────

QString ToolBridge::executeTool(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    const QString &userId) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        qWarning() << "ToolBridge not initialized";
        return "";
    }

    // 检查权限
    if (!checkToolAccess(toolId, userId)) {
        qWarning() << "Access denied for tool" << toolId;
        logAuditEntry("ACCESS_DENIED", toolId, userId, "Permission check failed");
        return "";
    }

    // 创建执行请求
    ToolExecutionRequest request;
    request.executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    request.toolId = toolId;
    request.capabilityName = capabilityName;
    request.parameters = parameters;
    request.requestedBy = userId;
    request.timeoutMs = 30000;

    // 执行工具
    locker.unlock();
    QString executionId = m_toolSystem->getToolExecutor()->executeTool(request);

    // 记录到Memory系统
    logExecutionToMemory(m_toolSystem->getToolExecutor()->getExecutionResult(executionId));

    // 记录审计日志
    logAuditEntry("TOOL_EXECUTED", toolId, userId, QString("Execution: %1").arg(executionId));

    emit toolExecutionStarted(executionId);
    return executionId;
}

QString ToolBridge::executeToolAsync(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    std::function<void(const ToolExecutionResult&)> callback) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        qWarning() << "ToolBridge not initialized";
        return "";
    }

    ToolExecutionRequest request;
    request.executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    request.toolId = toolId;
    request.capabilityName = capabilityName;
    request.parameters = parameters;

    // 加入队列
    m_taskQueue.enqueue({request, callback});
    locker.unlock();

    processQueue();
    emit queueChanged();

    return request.executionId;
}

void ToolBridge::executeToolChain(
    const QString &chainId,
    const QVariantMap &parameters,
    std::function<void(const QVector<ToolExecutionResult>&)> callback) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        qWarning() << "ToolBridge not initialized";
        return;
    }

    // 从工具系统获取链定义
    auto executor = m_toolSystem->getToolExecutor();
    locker.unlock();

    ToolChainDefinition chain = executor->getToolChain(chainId);

    if (chain.steps.isEmpty()) {
        qWarning() << "Tool chain not found:" << chainId;
        return;
    }

    // 执行链
    executor->executeToolChain(chain, parameters, callback);
}

ExecutionStatus ToolBridge::getExecutionStatus(const QString &executionId) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return ExecutionStatus::Pending;
    }

    return m_toolSystem->getToolExecutor()->getExecutionStatus(executionId);
}

ToolExecutionResult ToolBridge::getExecutionResult(const QString &executionId) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return ToolExecutionResult();
    }

    return m_toolSystem->getToolExecutor()->getExecutionResult(executionId);
}

void ToolBridge::cancelExecution(const QString &executionId) {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return;
    }

    m_toolSystem->getToolExecutor()->cancelExecution(executionId);
    emit toolExecutionCancelled(executionId);
}

// ── 工具发现和推荐 ────────────────────────────────────────

QVector<ToolSchema> ToolBridge::searchTools(
    const QString &keywords,
    const QString &category) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVector<ToolSchema>();
    }

    auto discovery = m_toolSystem->getToolDiscovery();
    locker.unlock();

    QVector<ToolSchema> results;
    bool completed = false;
    QEventLoop loop;

    ToolDiscoveryQuery query;
    query.keyword = keywords;
    query.category = category;
    query.limit = 10;

    discovery->searchTools(query, [&](const QVector<ToolSchema> &tools) {
        results = tools;
        completed = true;
        if (loop.isRunning()) {
            loop.quit();
        }
    });

    if (!completed) {
        loop.exec();
    }

    return results;
}

QVector<ToolSchema> ToolBridge::recommendTools(const QString &description) {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVector<ToolSchema>();
    }

    auto discovery = m_toolSystem->getToolDiscovery();
    locker.unlock();

    QVector<ToolSchema> results;
    bool completed = false;
    QEventLoop loop;

    discovery->recommendTools(description, [&](const QVector<ToolSchema> &tools) {
        results = tools;
        completed = true;
        if (loop.isRunning()) {
            loop.quit();
        }
    });

    if (!completed) {
        loop.exec();
    }

    return results;
}

void ToolBridge::recommendToolsAsync(
    const QString &description,
    std::function<void(const QVector<ToolSchema>&)> callback) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        if (callback) callback(QVector<ToolSchema>());
        return;
    }

    auto discovery = m_toolSystem->getToolDiscovery();
    locker.unlock();

    discovery->recommendTools(description, [this, callback](const QVector<ToolSchema> &tools) {
        emit toolsRecommended(tools);
        if (callback) callback(tools);
    });
}

ToolSchema ToolBridge::getToolDetails(const QString &toolId) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return ToolSchema();
    }

    auto registry = m_toolSystem->getSchemaRegistry();
    locker.unlock();

    return registry->getSchema(toolId);
}

QVector<QVector<ToolSchema>> ToolBridge::getCompatibleChains(const QString &toolId) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVector<QVector<ToolSchema>>();
    }

    auto discovery = m_toolSystem->getToolDiscovery();
    locker.unlock();

    return discovery->searchToolChains(toolId, 5);
}

// ── 统计和监控 ────────────────────────────────────────

QVariantMap ToolBridge::getToolStatistics(const QString &toolId) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVariantMap();
    }

    auto executor = m_toolSystem->getToolExecutor();
    locker.unlock();

    return executor->getExecutionStatistics(toolId);
}

QVariantMap ToolBridge::getSystemStatistics() const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVariantMap();
    }

    return m_toolSystem->getSystemStatistics();
}

QVector<ToolExecutionResult> ToolBridge::getExecutionHistory(
    const QString &toolId,
    int limit) const {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVector<ToolExecutionResult>();
    }

    auto executor = m_toolSystem->getToolExecutor();
    locker.unlock();

    return executor->getToolExecutionHistory(toolId, limit);
}

QVector<ToolExecutionResult> ToolBridge::getFailedExecutions(int limit) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVector<ToolExecutionResult>();
    }

    auto executor = m_toolSystem->getToolExecutor();
    locker.unlock();

    return executor->getFailedExecutions(limit);
}

QVariantMap ToolBridge::getPerformanceMetrics(const QString &toolId) const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVariantMap();
    }

    auto executor = m_toolSystem->getToolExecutor();
    locker.unlock();

    if (toolId.isEmpty()) {
        QVariantMap metrics;
        metrics["totalExecutions"] = m_totalExecutions;
        metrics["successfulExecutions"] = m_successfulExecutions;
        metrics["failedExecutions"] = m_failedExecutions;
        metrics["successRate"] = m_totalExecutions > 0 ?
            (float)m_successfulExecutions / m_totalExecutions : 0.0f;
        return metrics;
    }

    return executor->getPerformanceMetrics(toolId);
}

// ── 权限和审批 ────────────────────────────────────────

bool ToolBridge::checkToolAccess(
    const QString &toolId,
    const QString &userId) const {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return false;
    }

    auto permMgr = m_toolSystem->getPermissionManager();
    locker.unlock();

    bool allowed = false;
    bool completed = false;
    QEventLoop loop;
    permMgr->checkToolAccess(toolId, userId, [&](bool granted, const QString &) {
        allowed = granted;
        completed = true;
        if (loop.isRunning()) {
            loop.quit();
        }
    });

    if (!completed) {
        loop.exec();
    }

    return allowed;
}

bool ToolBridge::checkExecutionPermission(
    const ToolExecutionRequest &request,
    const QString &userId) const {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return false;
    }

    auto permMgr = m_toolSystem->getPermissionManager();
    locker.unlock();

    bool allowed = false;
    bool completed = false;
    QEventLoop loop;
    permMgr->checkExecutionPermission(request.toolId, userId, [&](bool granted, const QString &) {
        allowed = granted;
        completed = true;
        if (loop.isRunning()) {
            loop.quit();
        }
    });

    if (!completed) {
        loop.exec();
    }

    return allowed;
}

void ToolBridge::requestExecutionApproval(
    const ToolExecutionRequest &request,
    std::function<void(bool approved)> callback) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        if (callback) callback(false);
        return;
    }

    auto approvalMgr = m_approval;
    locker.unlock();

    if (!approvalMgr) {
        if (callback) callback(false);
        return;
    }

    ExecApprovalRequestEvent approvalRequest;
    approvalRequest.approvalId = request.executionId.isEmpty()
        ? QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch())
        : request.executionId;
    approvalRequest.commandLine = request.parameters.value("commandLine").toString();
    approvalRequest.toolName = request.toolId;
    approvalRequest.reason = QString("ToolBridge approval request for %1").arg(request.toolId);
    approvalRequest.policy = approvalMgr->getPolicyFor(request.toolId, request.capabilityName);
    approvalRequest.requestedAt = QDateTime::currentDateTime();
    approvalRequest.context = request.context;

    approvalMgr->requestExecApproval(approvalRequest, [this, approvalId = approvalRequest.approvalId, callback](bool approved, ApprovalDecision) {
        if (approved) {
            emit approvalApproved(approvalId);
        } else {
            emit approvalRejected(approvalId);
        }
        if (callback) callback(approved);
    });
}

QVector<QVariantMap> ToolBridge::getAuditLog(
    const QString &toolId,
    int limit) const {

    QMutexLocker locker(&m_mutex);

    // 返回内部审计日志
    int start = qMax(0, m_auditLog.size() - limit);
    return QVector<QVariantMap>(m_auditLog.begin() + start, m_auditLog.end());
}

// ── 队列管理 ────────────────────────────────────────

QVector<ToolExecutionRequest> ToolBridge::getExecutionQueue() const {
    QMutexLocker locker(&m_mutex);

    QVector<ToolExecutionRequest> result;
    for (const auto &pair : m_taskQueue) {
        result.append(pair.first);
    }
    return result;
}

QVector<QString> ToolBridge::getActiveExecutions() const {
    QMutexLocker locker(&m_mutex);
    return m_activeExecutions;
}

int ToolBridge::getMaxConcurrency() const {
    QMutexLocker locker(&m_mutex);
    return m_maxConcurrency;
}

void ToolBridge::setMaxConcurrency(int maxConcurrent) {
    QMutexLocker locker(&m_mutex);
    m_maxConcurrency = maxConcurrent;
}

int ToolBridge::getQueueSize() const {
    QMutexLocker locker(&m_mutex);
    return m_taskQueue.size();
}

void ToolBridge::clearQueue() {
    QMutexLocker locker(&m_mutex);
    m_taskQueue.clear();
    emit queueChanged();
}

// ── 缓存管理 ────────────────────────────────────────

void ToolBridge::enableCache(bool enable) {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return;
    }

    m_cacheEnabled = enable;
    m_toolSystem->getToolExecutor()->enableCache(enable);
}

void ToolBridge::setCacheExpiry(int seconds) {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return;
    }

    m_cacheExpirySeconds = seconds;
    m_toolSystem->getToolExecutor()->setCacheExpiry(seconds);
}

void ToolBridge::clearCache(const QString &toolId) {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return;
    }

    m_toolSystem->getToolExecutor()->clearCache(toolId);
    emit cacheCleared();
}

QVariantMap ToolBridge::getCacheStatistics() const {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return QVariantMap();
    }

    return m_toolSystem->getToolExecutor()->getCacheStatistics();
}

// ── 复合操作 ────────────────────────────────────────

QString ToolBridge::smartExecute(
    const QString &description,
    const QVariantMap &parameters,
    const QString &userId) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        return "";
    }

    // 推荐工具
    auto discovery = m_toolSystem->getToolDiscovery();
    QVector<ToolSchema> tools;
    bool completed = false;
    QEventLoop loop;
    discovery->recommendTools(description, [&](const QVector<ToolSchema> &result) {
        tools = result;
        completed = true;
        if (loop.isRunning()) {
            loop.quit();
        }
    });

    if (!completed) {
        loop.exec();
    }

    locker.unlock();

    if (tools.isEmpty()) {
        emit recommendationError("No tools found for: " + description);
        return "";
    }

    // 执行第一个推荐的工具
    const auto &tool = tools.first();

    return executeTool(tool.toolId, 
                      tool.capabilities.isEmpty() ? "" : tool.capabilities.first().name,
                      parameters,
                      userId);
}

void ToolBridge::smartWorkflow(
    const QString &description,
    const QVariantMap &parameters,
    std::function<void(const QVector<ToolExecutionResult>&)> callback) {

    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        if (callback) callback(QVector<ToolExecutionResult>());
        return;
    }

    m_toolSystem->executeSmartChain(description, parameters, "", callback);
}

QVariantMap ToolBridge::getSystemHealth() const {
    QMutexLocker locker(&m_mutex);

    QVariantMap health;
    health["initialized"] = m_initialized;
    health["queueSize"] = m_taskQueue.size();
    health["activeExecutions"] = m_activeExecutions.size();
    health["totalExecutions"] = m_totalExecutions;
    health["successRate"] = m_totalExecutions > 0 ?
        (float)m_successfulExecutions / m_totalExecutions : 0.0f;

    return health;
}

// ── 私有方法 ────────────────────────────────────────

void ToolBridge::processQueue() {
    QMutexLocker locker(&m_mutex);

    if (!m_initialized || m_taskQueue.isEmpty()) {
        return;
    }

    if (m_activeExecutions.size() >= m_maxConcurrency) {
        return;
    }

    auto [request, callback] = m_taskQueue.dequeue();
    m_activeExecutions.append(request.executionId);

    locker.unlock();

    m_toolSystem->getToolExecutor()->executeTool(request, [this, callback](const ToolExecutionResult &result) {
        {
            QMutexLocker resultLocker(&m_mutex);
            m_activeExecutions.removeAll(result.executionId);
        }

        if (callback) callback(result);

        emit toolExecutionCompleted(result.executionId, result);
        processQueue();  // 处理下一个任务
    });
}

void ToolBridge::logExecutionToMemory(const ToolExecutionResult &result) {
    if (!m_memory) return;

    QVariantMap entry;
    entry["executionId"] = result.executionId;
    entry["toolId"] = result.toolId;
    entry["status"] = static_cast<int>(result.status);
    entry["durationMs"] = result.durationMs;
    entry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    // 存储到Memory系统（简化实现）
    // m_memory->storeEpisodicMemory(...);
}

void ToolBridge::logAuditEntry(
    const QString &action,
    const QString &toolId,
    const QString &userId,
    const QString &details) {

    QMutexLocker locker(&m_mutex);

    QVariantMap entry;
    entry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    entry["action"] = action;
    entry["toolId"] = toolId;
    entry["userId"] = userId;
    entry["details"] = details;

    m_auditLog.append(entry);

    // 限制审计日志大小
    if (m_auditLog.size() > MAX_AUDIT_LOG_SIZE) {
        m_auditLog.removeFirst();
    }
}

ExecApprovalRequestEvent ToolBridge::createApprovalRequest(
    const ToolExecutionRequest &toolRequest) {

    ExecApprovalRequestEvent request;
    request.toolName = toolRequest.toolId;
    request.commandLine = toolRequest.parameters.value("commandLine").toString();
    request.reason = toolRequest.context.value("reason").toString();
    request.requestedAt = QDateTime::currentDateTime();
    request.context = toolRequest.context;

    return request;
}

bool ToolBridge::toolRequiresApproval(const ToolSchema &schema) const {
    QMutexLocker locker(&m_mutex);

    if (!m_approval) {
        return false;
    }

    const auto policy = m_approval->getPolicyFor(schema.toolId, schema.category);
    return policy != AskForApproval::Never;
}

// ── 槽 ────────────────────────────────────────

void ToolBridge::onToolExecutionCompleted(const QString &executionId) {
    QMutexLocker locker(&m_mutex);
    m_successfulExecutions++;
    m_totalExecutions++;
}

void ToolBridge::onToolExecutionFailed(const QString &executionId) {
    QMutexLocker locker(&m_mutex);
    m_failedExecutions++;
    m_totalExecutions++;
}

void ToolBridge::onPermissionChanged() {
    emit systemStatusChanged();
}

void ToolBridge::onRecommendationCompleted() {
    // 空实现，由异步回调处理
}
