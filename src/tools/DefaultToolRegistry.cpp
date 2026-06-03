#include "DefaultToolRegistry.h"
#include <QDebug>
#include <QUuid>
#include <QDateTime>
#include <QMutexLocker>
#include <algorithm>

DefaultToolRegistry::DefaultToolRegistry(QObject *parent)
    : CoreToolRegistry(parent)
{
}

QString DefaultToolRegistry::registerTool(const ToolInstance &tool,
                                          std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString id = tool.toolId.isEmpty() ? QUuid::createUuid().toString() : tool.toolId;
    
    ToolInstance instance = tool;
    instance.toolId = id;
    instance.instanceId = QUuid::createUuid().toString();
    instance.status = ToolStatus::Available;
    instance.loadedAt = QDateTime::currentDateTime();
    
    m_tools[id] = instance;
    
    // Initialize statistics
    ToolStatistics stats;
    stats.toolId = id;
    stats.collectedAt = QDateTime::currentDateTime();
    m_statistics[id] = stats;
    
    locker.unlock();
    
    emit toolRegistered(id);
    
    if (callback) callback(true);
    
    return id;
}

void DefaultToolRegistry::unregisterTool(const QString &toolId,
                                        std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_tools.remove(toolId) > 0) {
        m_statistics.remove(toolId);
        locker.unlock();
        
        emit toolUnregistered(toolId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultToolRegistry::updateTool(const QString &toolId, const ToolMetadata &metadata,
                                    std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        it->metadata = metadata;
        it->metadata.updatedAt = QDateTime::currentDateTime();
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

ToolInstance DefaultToolRegistry::getTool(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        return *it;
    }
    
    return ToolInstance();
}

QVector<ToolInstance> DefaultToolRegistry::getAllTools() const
{
    QMutexLocker locker(&m_mutex);
    return m_tools.values().toVector();
}

void DefaultToolRegistry::searchTools(const ToolQuery &query,
                                     ToolSearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSearchResult> results;
    
    for (auto it = m_tools.begin(); it != m_tools.end(); ++it) {
        if (matchesQuery(*it, query)) {
            ToolSearchResult result;
            result.tool = *it;
            result.relevanceScore = 1.0f;
            
            results.append(result);
        }
    }
    
    locker.unlock();
    
    if (callback) callback(results);
}

QVector<ToolInstance> DefaultToolRegistry::getToolsByCategory(ToolCategory category) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolInstance> results;
    
    for (auto it = m_tools.begin(); it != m_tools.end(); ++it) {
        // Category matching would depend on metadata category field
        results.append(*it);
    }
    
    return results;
}

QVector<ToolInstance> DefaultToolRegistry::getToolsByTag(const QString &tag) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolInstance> results;
    
    for (auto it = m_tools.begin(); it != m_tools.end(); ++it) {
        if (it->metadata.tags.contains(tag)) {
            results.append(*it);
        }
    }
    
    return results;
}

QVector<ToolInstance> DefaultToolRegistry::findToolsByCapability(const QString &capabilityName) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolInstance> results;
    
    for (auto it = m_tools.begin(); it != m_tools.end(); ++it) {
        for (const auto &cap : it->capabilities) {
            if (cap.name == capabilityName) {
                results.append(*it);
                break;
            }
        }
    }
    
    return results;
}

void DefaultToolRegistry::loadTool(const QString &toolId,
                                  std::function<void(bool success, const QString &error)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        if (it->status == ToolStatus::Available) {
            it->status = ToolStatus::Loading;
            
            locker.unlock();
            
            // Simulate loading
            it->status = ToolStatus::Loaded;
            it->loadedAt = QDateTime::currentDateTime();
            
            emit toolLoaded(toolId);
            if (callback) callback(true, "");
        } else {
            locker.unlock();
            if (callback) callback(false, "Tool already loaded");
        }
    } else {
        locker.unlock();
        if (callback) callback(false, "Tool not found");
    }
}

void DefaultToolRegistry::unloadTool(const QString &toolId,
                                   std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        it->status = ToolStatus::Available;
        locker.unlock();
        
        emit toolUnloaded(toolId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultToolRegistry::activateTool(const QString &toolId,
                                     std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        if (it->status == ToolStatus::Loaded) {
            it->status = ToolStatus::Active;
            locker.unlock();
            
            emit toolActivated(toolId);
            if (callback) callback(true);
        } else {
            locker.unlock();
            if (callback) callback(false);
        }
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultToolRegistry::deactivateTool(const QString &toolId,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        it->status = ToolStatus::Disabled;
        locker.unlock();
        
        emit toolDeactivated(toolId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultToolRegistry::isToolAvailable(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        return it->status == ToolStatus::Active || it->status == ToolStatus::Available;
    }
    
    return false;
}

ToolStatus DefaultToolRegistry::getToolStatus(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        return it->status;
    }
    
    return ToolStatus::Failed;
}

void DefaultToolRegistry::executeTool(const QString &toolId,
                                     const QVariantMap &parameters,
                                     ToolCallback callback,
                                     int timeoutMs)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it == m_tools.end() || it->status != ToolStatus::Active) {
        locker.unlock();
        
        ToolExecutionResult result;
        result.success = false;
        result.errorCode = ToolError::NotFound;
        if (callback) callback(result);
        return;
    }
    
    QString executionId = QUuid::createUuid().toString();
    
    locker.unlock();
    
    ToolExecutionResult result;
    result.toolId = toolId;
    result.executionId = executionId;
    result.success = true;
    result.errorCode = ToolError::Success;
    result.startedAt = QDateTime::currentDateTime();
    result.completedAt = QDateTime::currentDateTime();
    result.executionTime = 100;  // Simulated
    
    emit executionStarted(toolId, executionId);
    emit executionCompleted(executionId, true);
    
    recordExecution(result);
    
    if (callback) callback(result);
}

void DefaultToolRegistry::executeToolCapability(const QString &toolId,
                                               const QString &capabilityName,
                                               const QVariantMap &parameters,
                                               ToolCallback callback,
                                               int timeoutMs)
{
    executeTool(toolId, parameters, callback, timeoutMs);
}

void DefaultToolRegistry::cancelExecution(const QString &executionId,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_executionResults.find(executionId);
    if (it != m_executionResults.end()) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

ToolExecutionResult DefaultToolRegistry::getExecutionStatus(const QString &executionId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_executionResults.find(executionId);
    if (it != m_executionResults.end()) {
        return *it;
    }
    
    return ToolExecutionResult();
}

QString DefaultToolRegistry::createToolChain(const ToolChain &chain,
                                            std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString chainId = QUuid::createUuid().toString();
    
    ToolChain newChain = chain;
    newChain.chainId = chainId;
    newChain.createdAt = QDateTime::currentDateTime();
    
    m_chains[chainId] = newChain;
    
    locker.unlock();
    
    if (callback) callback(true);
    
    return chainId;
}

void DefaultToolRegistry::executeToolChain(const QString &chainId,
                                          const QVariantMap &parameters,
                                          std::function<void(const QVector<ToolExecutionResult> &)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_chains.find(chainId);
    if (it == m_chains.end()) {
        locker.unlock();
        if (callback) callback(QVector<ToolExecutionResult>());
        return;
    }
    
    QVector<ToolExecutionResult> results;
    
    for (const auto &step : it->steps) {
        // Would execute each step
        ToolExecutionResult result;
        result.toolId = step.toolId;
        result.success = true;
        results.append(result);
    }
    
    locker.unlock();
    
    emit chainExecuted(chainId);
    if (callback) callback(results);
}

ToolChain DefaultToolRegistry::getToolChain(const QString &chainId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_chains.find(chainId);
    if (it != m_chains.end()) {
        return *it;
    }
    
    return ToolChain();
}

QVector<ToolChain> DefaultToolRegistry::listToolChains() const
{
    QMutexLocker locker(&m_mutex);
    return m_chains.values().toVector();
}

void DefaultToolRegistry::deleteToolChain(const QString &chainId,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_chains.remove(chainId) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultToolRegistry::validateParameters(const QString &toolId,
                                            const QVariantMap &parameters,
                                            QString &errorMsg)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it == m_tools.end()) {
        errorMsg = "Tool not found";
        return false;
    }
    
    for (const auto &cap : it->capabilities) {
        for (const auto &param : cap.parameters) {
            if (!parameters.contains(param.name) && param.required) {
                errorMsg = QString("Required parameter missing: %1").arg(param.name);
                return false;
            }
        }
    }
    
    return true;
}

bool DefaultToolRegistry::validateCapabilityParameters(const QString &toolId,
                                                     const QString &capabilityName,
                                                     const QVariantMap &parameters,
                                                     QString &errorMsg)
{
    return validateParameters(toolId, parameters, errorMsg);
}

bool DefaultToolRegistry::checkDependencies(const QString &toolId,
                                           QString &errorMsg)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it == m_tools.end()) {
        errorMsg = "Tool not found";
        return false;
    }
    
    return true;
}

void DefaultToolRegistry::grantPermission(const QString &toolId,
                                         const QString &principalId,
                                         Permission permission,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString key = toolId + ":" + principalId;
    
    auto it = m_permissions.find(key);
    if (it == m_permissions.end()) {
        ToolPermission perm;
        perm.toolId = toolId;
        perm.principalId = principalId;
        perm.grantedAt = QDateTime::currentDateTime();
        m_permissions[key] = perm;
    }
    
    m_permissions[key].permissions.append(permission);
    
    locker.unlock();
    
    emit permissionChanged(toolId, principalId);
    if (callback) callback(true);
}

void DefaultToolRegistry::revokePermission(const QString &toolId,
                                          const QString &principalId,
                                          Permission permission,
                                          std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString key = toolId + ":" + principalId;
    
    auto it = m_permissions.find(key);
    if (it != m_permissions.end()) {
        it->permissions.removeAll(permission);
        locker.unlock();
        
        emit permissionChanged(toolId, principalId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultToolRegistry::hasPermission(const QString &toolId,
                                       const QString &principalId,
                                       Permission permission) const
{
    QMutexLocker locker(&m_mutex);
    
    QString key = toolId + ":" + principalId;
    
    auto it = m_permissions.find(key);
    if (it != m_permissions.end()) {
        return it->permissions.contains(permission);
    }
    
    return false;
}

QVector<ToolPermission> DefaultToolRegistry::getPermissions(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolPermission> results;
    
    for (auto it = m_permissions.begin(); it != m_permissions.end(); ++it) {
        if (it->toolId == toolId) {
            results.append(*it);
        }
    }
    
    return results;
}

void DefaultToolRegistry::registerHook(const ToolHook &hook,
                                      std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString hookId = QUuid::createUuid().toString();
    
    ToolHook newHook = hook;
    newHook.hookId = hookId;
    
    m_hooks[hookId] = newHook;
    
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultToolRegistry::unregisterHook(const QString &hookId,
                                        std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_hooks.remove(hookId) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVector<ToolHook> DefaultToolRegistry::getHooks(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolHook> results;
    
    for (auto it = m_hooks.begin(); it != m_hooks.end(); ++it) {
        if (it->toolId == toolId) {
            results.append(*it);
        }
    }
    
    return results;
}

ToolStatistics DefaultToolRegistry::getToolStatistics(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_statistics.find(toolId);
    if (it != m_statistics.end()) {
        return *it;
    }
    
    return ToolStatistics();
}

QVariantMap DefaultToolRegistry::getRegistryStatistics() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalTools"] = m_tools.size();
    stats["activeTools"] = 0;
    stats["totalExecutions"] = m_executionResults.size();
    
    int active = 0;
    for (const auto &tool : m_tools) {
        if (tool.status == ToolStatus::Active) {
            active++;
        }
    }
    stats["activeTools"] = active;
    
    return stats;
}

QVector<ToolExecutionResult> DefaultToolRegistry::getExecutionHistory(const QString &toolId,
                                                                     int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolExecutionResult> results;
    
    for (int i = std::max(0, static_cast<int>(m_executionHistory.size()) - limit);
         i < m_executionHistory.size(); ++i) {
        if (m_executionHistory[i].toolId == toolId) {
            results.append(m_executionHistory[i]);
        }
    }
    
    return results;
}

void DefaultToolRegistry::setToolConfiguration(const QString &toolId,
                                              const QVariantMap &config,
                                              std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        it->config = config;
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVariantMap DefaultToolRegistry::getToolConfiguration(const QString &toolId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_tools.find(toolId);
    if (it != m_tools.end()) {
        return it->config;
    }
    
    return QVariantMap();
}

void DefaultToolRegistry::setGlobalConfiguration(const QVariantMap &config)
{
    QMutexLocker locker(&m_mutex);
    m_globalConfig = config;
}

QVariantMap DefaultToolRegistry::getGlobalConfiguration() const
{
    QMutexLocker locker(&m_mutex);
    return m_globalConfig;
}

QVector<MarketplaceTool> DefaultToolRegistry::getMarketplaceTools(const ToolQuery &query) const
{
    return QVector<MarketplaceTool>();
}

void DefaultToolRegistry::installFromMarketplace(const QString &toolId, const QString &version,
                                                std::function<void(bool success, const QString &error)> callback)
{
    if (callback) callback(true, "");
}

void DefaultToolRegistry::updateFromMarketplace(const QString &toolId, const QString &version,
                                               std::function<void(bool success, const QString &error)> callback)
{
    if (callback) callback(true, "");
}

void DefaultToolRegistry::reloadAllTools(std::function<void(int loaded, int failed)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    int loaded = m_tools.size();
    int failed = 0;
    
    locker.unlock();
    
    if (callback) callback(loaded, failed);
}

void DefaultToolRegistry::cleanupFailedTools(std::function<void(int removed)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    int removed = 0;
    
    for (auto it = m_tools.begin(); it != m_tools.end(); ) {
        if (it->status == ToolStatus::Failed) {
            it = m_tools.erase(it);
            removed++;
        } else {
            ++it;
        }
    }
    
    locker.unlock();
    
    if (callback) callback(removed);
}

void DefaultToolRegistry::clearExecutionHistory(const QString &toolId,
                                               std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    for (int i = m_executionHistory.size() - 1; i >= 0; --i) {
        if (m_executionHistory[i].toolId == toolId) {
            m_executionHistory.removeAt(i);
        }
    }
    
    locker.unlock();
    
    if (callback) callback(true);
}

bool DefaultToolRegistry::matchesQuery(const ToolInstance &tool, const ToolQuery &query) const
{
    if (!query.searchText.isEmpty()) {
        if (!tool.metadata.name.contains(query.searchText, Qt::CaseInsensitive) &&
            !tool.metadata.description.contains(query.searchText, Qt::CaseInsensitive)) {
            return false;
        }
    }
    
    if (query.onlyAvailable && tool.status != ToolStatus::Active) {
        return false;
    }
    
    return true;
}

bool DefaultToolRegistry::validateParameter(const ToolParameter &param, const QVariant &value, QString &error) const
{
    if (param.required && value.isNull()) {
        error = QString("Parameter %1 is required").arg(param.name);
        return false;
    }
    
    return true;
}

void DefaultToolRegistry::recordExecution(const ToolExecutionResult &result)
{
    QMutexLocker locker(&m_mutex);
    
    m_executionResults[result.executionId] = result;
    m_executionHistory.append(result);
    
    updateStatistics(result.toolId, result);
}

void DefaultToolRegistry::updateStatistics(const QString &toolId, const ToolExecutionResult &result)
{
    auto it = m_statistics.find(toolId);
    if (it != m_statistics.end()) {
        it->totalExecutions++;
        if (result.success) {
            it->successfulExecutions++;
        } else {
            it->failedExecutions++;
        }
        
        it->successRate = static_cast<float>(it->successfulExecutions) / it->totalExecutions;
        it->averageExecutionTime = (it->averageExecutionTime + result.executionTime) / 2;
        it->collectedAt = QDateTime::currentDateTime();
    }
}

#include "moc_DefaultToolRegistry.cpp"
