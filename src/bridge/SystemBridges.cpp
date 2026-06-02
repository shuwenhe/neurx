#include "SystemBridges.h"
#include <QDebug>
#include <QDateTime>
#include <QEventLoop>

// ════════════════════════════════════════════════════════
// MemoryToolBridge 实现
// ════════════════════════════════════════════════════════

MemoryToolBridge::MemoryToolBridge(
    std::shared_ptr<ClaudeToolSystem> toolSystem,
    std::shared_ptr<DefaultMemoryManager> memory)
    : m_toolSystem(toolSystem), m_memory(memory) {
}

bool MemoryToolBridge::registerAllTools() {
    if (!m_toolSystem) return false;

    ToolSchema schema;
    schema.toolId = "memory-search";
    schema.name = "Memory Search";
    schema.description = "Search tool history and knowledge in long-term memory";
    schema.category = "Memory";
    schema.author = "Memory Integration";
    schema.version = "1.0.0";

    ToolPermission permission;
    permission.toolId = "memory-search";
    permission.level = PermissionLevel::Internal;

    m_toolSystem->registerTool(schema, permission);

    qDebug() << "Memory tool registered successfully";
    return true;
}

void MemoryToolBridge::storeToolMetadata(const ToolSchema &schema) {
    if (!m_memory) return;

    QVariantMap entry;
    entry["toolId"] = schema.toolId;
    entry["name"] = schema.name;
    entry["category"] = schema.category;
    entry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    m_totalStored++;
}

void MemoryToolBridge::storeExecutionHistory(const ToolExecutionResult &result) {
    if (!m_memory) return;

    QVariantMap entry;
    entry["executionId"] = result.executionId;
    entry["toolId"] = result.toolId;
    entry["status"] = static_cast<int>(result.status);
    entry["duration"] = result.durationMs;
    entry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    m_totalStored++;
}

QVariantMap MemoryToolBridge::getStatistics() const {
    QVariantMap stats;
    stats["totalStored"] = m_totalStored;
    stats["totalRetrieved"] = m_totalRetrieved;
    return stats;
}

// ════════════════════════════════════════════════════════
// ApprovalToolBridge 实现
// ════════════════════════════════════════════════════════

ApprovalToolBridge::ApprovalToolBridge(
    std::shared_ptr<ClaudeToolSystem> toolSystem,
    std::shared_ptr<DefaultApprovalManager> approval)
    : m_toolSystem(toolSystem), m_approval(approval) {
}

bool ApprovalToolBridge::initialize() {
    if (!m_toolSystem || !m_approval) return false;

    qDebug() << "ApprovalToolBridge initialized";
    return true;
}

bool ApprovalToolBridge::checkToolPermission(
    const QString &toolId,
    const QString &userId) {

    if (!m_toolSystem) return false;

    auto permMgr = m_toolSystem->getPermissionManager();

    if (!permMgr) return false;

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

void ApprovalToolBridge::recordAuditLog(const ToolExecutionResult &result) {
    // 记录审计日志
    QVariantMap log;
    log["executionId"] = result.executionId;
    log["toolId"] = result.toolId;
    log["status"] = static_cast<int>(result.status);
    log["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    m_approvalsRequested++;
    if (result.status == ExecutionStatus::Completed) {
        m_approvalsApproved++;
    } else if (result.status == ExecutionStatus::Failed ||
               result.status == ExecutionStatus::Rejected ||
               result.status == ExecutionStatus::Cancelled) {
        m_approvalsDenied++;
    }
}

QVariantMap ApprovalToolBridge::getStatistics() const {
    QVariantMap stats;
    stats["approvalsRequested"] = m_approvalsRequested;
    stats["approvalsApproved"] = m_approvalsApproved;
    stats["approvalsDenied"] = m_approvalsDenied;

    if (m_approvalsRequested > 0) {
        float approvalRate = (float)m_approvalsApproved / m_approvalsRequested;
        stats["approvalRate"] = approvalRate;
    }

    return stats;
}

// ════════════════════════════════════════════════════════
// PluginToolBridge 实现
// ════════════════════════════════════════════════════════

PluginToolBridge::PluginToolBridge(
    std::shared_ptr<ClaudeToolSystem> toolSystem,
    std::shared_ptr<DefaultPluginManager> plugins)
    : m_toolSystem(toolSystem), m_plugins(plugins) {
}

bool PluginToolBridge::discoverAndRegisterPluginTools() {
    if (!m_toolSystem || !m_plugins) return false;

    // 获取所有插件
    auto plugins = m_plugins->listPlugins();

    for (const auto &plugin : plugins) {
        ToolSchema schema;
        schema.toolId = "plugin-" + plugin.id;
        schema.name = "Plugin: " + plugin.name;
        schema.description = "Integrated plugin tool";
        schema.category = "Plugin";
        schema.author = plugin.author;
        schema.version = plugin.version;

        ToolPermission permission;
        permission.toolId = schema.toolId;
        permission.level = PermissionLevel::Internal;

        m_toolSystem->registerTool(schema, permission);
        m_registeredPluginTools.insert(schema.toolId);
    }

    qDebug() << "Discovered and registered" << m_registeredPluginTools.size() << "plugin tools";
    return true;
}

void PluginToolBridge::onPluginLoaded(const QString &pluginId) {
    // 处理插件加载事件
    QString toolId = "plugin-" + pluginId;
    m_registeredPluginTools.insert(toolId);
}

QVariantMap PluginToolBridge::getStatistics() const {
    QVariantMap stats;
    stats["registeredPluginTools"] = static_cast<int>(m_registeredPluginTools.size());
    return stats;
}

// ════════════════════════════════════════════════════════
// LLMToolBridge 实现
// ════════════════════════════════════════════════════════

LLMToolBridge::LLMToolBridge(
    std::shared_ptr<ClaudeToolSystem> toolSystem,
    std::shared_ptr<LLMCodeAnalyzer> llmAnalyzer)
    : m_toolSystem(toolSystem), m_llmAnalyzer(llmAnalyzer) {
}

bool LLMToolBridge::initialize() {
    if (!m_toolSystem || !m_llmAnalyzer) return false;

    // 注册LLM分析工具
    ToolSchema schema;
    schema.toolId = "llm-analyzer";
    schema.name = "LLM Code Analyzer";
    schema.description = "AI-powered code analysis using LLM";
    schema.category = "AI";
    schema.author = "LLM Integration";
    schema.version = "1.0.0";

    ToolPermission permission;
    permission.toolId = "llm-analyzer";
    permission.level = PermissionLevel::Internal;

    m_toolSystem->registerTool(schema, permission);

    qDebug() << "LLM analyzer tool registered";
    return true;
}

QVector<ToolSchema> LLMToolBridge::recommendToolsWithLLM(const QString &description) {
    if (!m_toolSystem) return QVector<ToolSchema>();

    // 使用工具系统推荐工具
    auto discovery = m_toolSystem->getToolDiscovery();
    if (!discovery) return QVector<ToolSchema>();

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

    m_recommendations++;
    return tools;
}

void LLMToolBridge::validateToolChainWithLLM(const ToolChainDefinition &chain) {
    // 验证工具链的有效性
    m_validations++;
}

QVariantMap LLMToolBridge::getStatistics() const {
    QVariantMap stats;
    stats["recommendations"] = m_recommendations;
    stats["validations"] = m_validations;
    return stats;
}
