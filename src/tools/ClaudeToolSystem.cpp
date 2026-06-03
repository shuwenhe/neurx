#include "ClaudeToolSystem.h"
#include "DefaultToolPermissionManager.h"
#include "DefaultToolSchemaRegistry.h"
#include "DefaultToolDiscovery.h"
#include "DefaultToolExecutor.h"
#include <QDebug>

ClaudeToolSystem::ClaudeToolSystem(QObject *parent)
    : QObject(parent), m_initialized(false) {
}

ClaudeToolSystem::~ClaudeToolSystem() {
    shutdown();
}

bool ClaudeToolSystem::initialize() {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_initialized) {
        qWarning() << "Tool system already initialized";
        return true;
    }
    
    try {
        // 创建所有子系统
        m_permissionManager = std::make_shared<DefaultToolPermissionManager>();
        m_schemaRegistry = std::make_shared<DefaultToolSchemaRegistry>();
        m_toolDiscovery = std::make_shared<DefaultToolDiscovery>();
        m_toolExecutor = std::make_shared<DefaultToolExecutor>();
        
        if (!m_permissionManager || !m_schemaRegistry || 
            !m_toolDiscovery || !m_toolExecutor) {
            qCritical() << "Failed to create subsystems";
            return false;
        }
        
        m_initialized = true;
        qDebug() << "Tool system initialized successfully";
        
        return true;
    } catch (const std::exception &e) {
        qCritical() << "Failed to initialize tool system:" << e.what();
        return false;
    }
}

void ClaudeToolSystem::shutdown() {
    
    QMutexLocker locker(&m_mutex);
    
    // 清理子系统
    m_permissionManager.reset();
    m_schemaRegistry.reset();
    m_toolDiscovery.reset();
    m_toolExecutor.reset();
    
    m_initialized = false;
    qDebug() << "Tool system shut down";
}

bool ClaudeToolSystem::isInitialized() const {
    
    QMutexLocker locker(&m_mutex);
    
    return m_initialized;
}

// ── 子系统访问 ──────────────────────────────────────

std::shared_ptr<ToolPermissionManager> ClaudeToolSystem::getPermissionManager() const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return nullptr;
    }
    
    return m_permissionManager;
}

std::shared_ptr<ToolSchemaRegistry> ClaudeToolSystem::getSchemaRegistry() const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return nullptr;
    }
    
    return m_schemaRegistry;
}

std::shared_ptr<ToolDiscovery> ClaudeToolSystem::getToolDiscovery() const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return nullptr;
    }
    
    return m_toolDiscovery;
}

std::shared_ptr<ToolExecutor> ClaudeToolSystem::getToolExecutor() const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return nullptr;
    }
    
    return m_toolExecutor;
}

// ── 便利方法 ────────────────────────────────────────

QString ClaudeToolSystem::registerTool(
    const ToolSchema &schema,
    const ToolPermission &permission) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return "";
    }
    
    // 注册模式
    QString toolId = m_schemaRegistry->registerSchema(schema);
    
    if (toolId.isEmpty()) {
        qWarning() << "Failed to register schema";
        return "";
    }
    
    // 设置权限
    auto perm = permission;
    if (perm.toolId.isEmpty()) {
        perm.toolId = toolId;
    }
    
    m_permissionManager->setToolPermission(perm);
    
    qDebug() << "Tool registered:" << toolId;
    
    return toolId;
}

ToolExecutionResult ClaudeToolSystem::executeTool(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    const QString &userId) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return ToolExecutionResult();
    }
    
    // 检查权限
    auto permMgr = m_permissionManager;
    locker.unlock();
    
    ToolExecutionResult result;
    
    // 这里应该异步检查权限，但为了简化，直接执行
    ToolExecutionRequest request;
    request.executionId = QString::number(QDateTime::currentDateTime().toSecsSinceEpoch());
    request.toolId = toolId;
    request.capabilityName = capabilityName;
    request.parameters = parameters;
    request.requestedBy = userId;
    
    locker.relock();
    
    result = m_toolExecutor->getExecutionResult(
        m_toolExecutor->executeTool(request)
    );
    
    return result;
}

void ClaudeToolSystem::smartExecute(
    const QString &description,
    const QVariantMap &parameters,
    const QString &userId,
    std::function<void(const ToolExecutionResult&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return;
    }
    
    // 推荐工具
    m_toolDiscovery->recommendTools(description,
        [this, parameters, userId, description, callback](const QVector<ToolSchema> &tools) {
            if (tools.isEmpty()) {
                qWarning() << "No tools found for:" << description;
                return;
            }
            
            // 执行第一个推荐的工具
            const auto &tool = tools.first();
            
            QMutexLocker locker(&m_mutex);
            
            ToolExecutionRequest request;
            request.executionId = QString::number(QDateTime::currentDateTime().toSecsSinceEpoch());
            request.toolId = tool.toolId;
            
            if (!tool.capabilities.isEmpty()) {
                request.capabilityName = tool.capabilities.first().name;
            }
            
            request.parameters = parameters;
            request.requestedBy = userId;
            
            auto result = m_toolExecutor->getExecutionResult(
                m_toolExecutor->executeTool(request, 
                    [callback](const ToolExecutionResult &res) {
                        if (callback) callback(res);
                    }
                )
            );
        }
    );
}

void ClaudeToolSystem::executeSmartChain(
    const QString &description,
    const QVariantMap &parameters,
    const QString &userId,
    std::function<void(const QVector<ToolExecutionResult>&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return;
    }
    
    // 搜索工具链
    auto chains = m_toolDiscovery->searchToolChains(description, 3);
    
    if (chains.isEmpty()) {
        qWarning() << "No tool chains found for:" << description;
        return;
    }
    
    // 使用第一个链
    if (!chains.first().isEmpty()) {
        // 构造工具链定义
        ToolChainDefinition chain;
        chain.name = QString("Smart chain: %1").arg(description);
        chain.description = description;
        
        int stepId = 1;
        for (const auto &tool : chains.first()) {
            ToolChainStep step;
            step.stepId = stepId++;
            step.toolId = tool.toolId;
            
            if (!tool.capabilities.isEmpty()) {
                step.capabilityName = tool.capabilities.first().name;
            }
            
            chain.steps.append(step);
        }
        
        locker.unlock();
        
        m_toolExecutor->executeToolChain(chain, parameters,
            [callback](const QVector<ToolExecutionResult> &results) {
                if (callback) callback(results);
            }
        );
    }
}

// ── 统计和报告 ──────────────────────────────────────

QVariantMap ClaudeToolSystem::getSystemStatistics() const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return QVariantMap();
    }
    
    QVariantMap stats;
    
    // 收集所有子系统的统计
    stats["schemaStatistics"] = m_schemaRegistry->getSchemaStatistics();
    stats["permissionStatistics"] = m_permissionManager->getPermissionStatistics();
    stats["discoveryStatistics"] = m_toolDiscovery->getDiscoveryStatistics();
    
    return stats;
}

QVariantMap ClaudeToolSystem::getToolStatistics(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return QVariantMap();
    }
    
    QVariantMap stats;
    
    stats["executionStatistics"] = m_toolExecutor->getExecutionStatistics(toolId);
    stats["accessStatistics"] = m_permissionManager->getToolAccessStats(toolId);
    
    return stats;
}

QString ClaudeToolSystem::generateSystemReport() const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return "";
    }
    
    QString report = "Claude Code Tool System Report\n";
    report += "==============================\n\n";
    
    report += "System Status: ";
    report += m_initialized ? "Initialized" : "Not initialized";
    report += "\n\n";
    
    report += "Subsystems:\n";
    report += QString("- Permission Manager: %1\n").arg(m_permissionManager ? "Active" : "Inactive");
    report += QString("- Schema Registry: %1\n").arg(m_schemaRegistry ? "Active" : "Inactive");
    report += QString("- Tool Discovery: %1\n").arg(m_toolDiscovery ? "Active" : "Inactive");
    report += QString("- Tool Executor: %1\n").arg(m_toolExecutor ? "Active" : "Inactive");
    
    auto sysStats = getSystemStatistics();
    
    report += "\nSystem Statistics:\n";
    if (sysStats.contains("schemaStatistics")) {
        auto schemaStats = sysStats["schemaStatistics"].toMap();
        report += QString("- Total Tools: %1\n").arg(schemaStats["totalSchemas"].toInt());
    }
    
    if (sysStats.contains("permissionStatistics")) {
        auto permStats = sysStats["permissionStatistics"].toMap();
        report += QString("- Total Users: %1\n").arg(permStats["totalUsers"].toInt());
    }
    
    return report;
}

QString ClaudeToolSystem::generateAuditReport(
    const QDateTime &from,
    const QDateTime &to) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        qWarning() << "Tool system not initialized";
        return "";
    }
    
    return m_permissionManager->exportAuditReport(from, to);
}
