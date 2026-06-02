#pragma once

#include <QString>
#include <QSet>
#include <QVariantMap>
#include <memory>
#include "tools/ClaudeToolSystem.h"
#include "memory/DefaultMemoryManager.h"
#include "approvals/DefaultApprovalManager.h"
#include "plugins/DefaultPluginManager.h"
#include "code/LLMCodeAnalyzer.h"

/**
 * @brief MemoryToolBridge - 将Memory系统集成到工具系统
 */
class MemoryToolBridge {
public:
    explicit MemoryToolBridge(
        std::shared_ptr<ClaudeToolSystem> toolSystem,
        std::shared_ptr<DefaultMemoryManager> memory);

    bool registerAllTools();
    void storeToolMetadata(const ToolSchema &schema);
    void storeExecutionHistory(const ToolExecutionResult &result);
    QVariantMap getStatistics() const;

private:
    std::shared_ptr<ClaudeToolSystem> m_toolSystem;
    std::shared_ptr<DefaultMemoryManager> m_memory;
    int m_totalStored = 0;
    int m_totalRetrieved = 0;
};

/**
 * @brief ApprovalToolBridge - 将Approval系统集成到工具系统
 */
class ApprovalToolBridge {
public:
    explicit ApprovalToolBridge(
        std::shared_ptr<ClaudeToolSystem> toolSystem,
        std::shared_ptr<DefaultApprovalManager> approval);

    bool initialize();
    bool checkToolPermission(const QString &toolId, const QString &userId);
    void recordAuditLog(const ToolExecutionResult &result);
    QVariantMap getStatistics() const;

private:
    std::shared_ptr<ClaudeToolSystem> m_toolSystem;
    std::shared_ptr<DefaultApprovalManager> m_approval;
    int m_approvalsRequested = 0;
    int m_approvalsApproved = 0;
    int m_approvalsDenied = 0;
};

/**
 * @brief PluginToolBridge - 将Plugin系统集成到工具系统
 */
class PluginToolBridge {
public:
    explicit PluginToolBridge(
        std::shared_ptr<ClaudeToolSystem> toolSystem,
        std::shared_ptr<DefaultPluginManager> plugins);

    bool discoverAndRegisterPluginTools();
    void onPluginLoaded(const QString &pluginId);
    QVariantMap getStatistics() const;

private:
    std::shared_ptr<ClaudeToolSystem> m_toolSystem;
    std::shared_ptr<DefaultPluginManager> m_plugins;
    QSet<QString> m_registeredPluginTools;
};

/**
 * @brief LLMToolBridge - 将LLMCodeAnalyzer集成到工具系统
 */
class LLMToolBridge {
public:
    explicit LLMToolBridge(
        std::shared_ptr<ClaudeToolSystem> toolSystem,
        std::shared_ptr<LLMCodeAnalyzer> llmAnalyzer);

    bool initialize();
    QVector<ToolSchema> recommendToolsWithLLM(const QString &description);
    void validateToolChainWithLLM(const ToolChainDefinition &chain);
    QVariantMap getStatistics() const;

private:
    std::shared_ptr<ClaudeToolSystem> m_toolSystem;
    std::shared_ptr<LLMCodeAnalyzer> m_llmAnalyzer;
    int m_recommendations = 0;
    int m_validations = 0;
};
