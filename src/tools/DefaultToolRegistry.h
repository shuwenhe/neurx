#pragma once

#include "tools/ToolRegistry.h"
#include <QMap>
#include <QMutex>

/**
 * @class DefaultToolRegistry
 * @brief Default tool registry and orchestration implementation
 * 
 * Features:
 * - Dynamic tool loading and management
 * - Tool discovery and search
 * - Tool chain orchestration
 * - Permission management
 * - Execution monitoring
 */
class DefaultToolRegistry : public ToolRegistry {
public:
    explicit DefaultToolRegistry(QObject *parent = nullptr);
    ~DefaultToolRegistry() = default;
    
    // Tool Registration
    QString registerTool(const ToolInstance &tool,
                        std::function<void(bool success)> callback = nullptr);
    void unregisterTool(const QString &toolId,
                       std::function<void(bool success)> callback = nullptr);
    void updateTool(const QString &toolId, const ToolMetadata &metadata,
                   std::function<void(bool success)> callback = nullptr);
    
    // Tool Discovery
    ToolInstance getTool(const QString &toolId) const;
    QVector<ToolInstance> getAllTools() const;
    void searchTools(const ToolQuery &query,
                    ToolSearchCallback callback = nullptr);
    QVector<ToolInstance> getToolsByCategory(ToolCategory category) const;
    QVector<ToolInstance> getToolsByTag(const QString &tag) const;
    QVector<ToolInstance> findToolsByCapability(const QString &capabilityName) const;
    
    // Tool Loading & Activation
    void loadTool(const QString &toolId,
                 std::function<void(bool success, const QString &error)> callback = nullptr);
    void unloadTool(const QString &toolId,
                   std::function<void(bool success)> callback = nullptr);
    void activateTool(const QString &toolId,
                     std::function<void(bool success)> callback = nullptr);
    void deactivateTool(const QString &toolId,
                       std::function<void(bool success)> callback = nullptr);
    bool isToolAvailable(const QString &toolId) const;
    ToolStatus getToolStatus(const QString &toolId) const;
    
    // Tool Execution
    void executeTool(const QString &toolId,
                    const QVariantMap &parameters,
                    ToolCallback callback = nullptr,
                    int timeoutMs = 30000);
    void executeToolCapability(const QString &toolId,
                              const QString &capabilityName,
                              const QVariantMap &parameters,
                              ToolCallback callback = nullptr,
                              int timeoutMs = 30000);
    void cancelExecution(const QString &executionId,
                        std::function<void(bool success)> callback = nullptr);
    ToolExecutionResult getExecutionStatus(const QString &executionId) const;
    
    // Tool Chain Execution
    QString createToolChain(const ToolChain &chain,
                           std::function<void(bool success)> callback = nullptr);
    void executeToolChain(const QString &chainId,
                         const QVariantMap &parameters,
                         std::function<void(const QVector<ToolExecutionResult> &)> callback = nullptr);
    ToolChain getToolChain(const QString &chainId) const;
    QVector<ToolChain> listToolChains() const;
    void deleteToolChain(const QString &chainId,
                        std::function<void(bool success)> callback = nullptr);
    
    // Validation
    bool validateParameters(const QString &toolId,
                           const QVariantMap &parameters,
                           QString &errorMsg);
    bool validateCapabilityParameters(const QString &toolId,
                                     const QString &capabilityName,
                                     const QVariantMap &parameters,
                                     QString &errorMsg);
    bool checkDependencies(const QString &toolId,
                          QString &errorMsg);
    
    // Permissions
    void grantPermission(const QString &toolId,
                        const QString &principalId,
                        Permission permission,
                        std::function<void(bool success)> callback = nullptr);
    void revokePermission(const QString &toolId,
                         const QString &principalId,
                         Permission permission,
                         std::function<void(bool success)> callback = nullptr);
    bool hasPermission(const QString &toolId,
                      const QString &principalId,
                      Permission permission) const;
    QVector<ToolPermission> getPermissions(const QString &toolId) const;
    
    // Tool Hooks
    void registerHook(const ToolHook &hook,
                     std::function<void(bool success)> callback = nullptr);
    void unregisterHook(const QString &hookId,
                       std::function<void(bool success)> callback = nullptr);
    QVector<ToolHook> getHooks(const QString &toolId) const;
    
    // Statistics & Monitoring
    ToolStatistics getToolStatistics(const QString &toolId) const;
    QVariantMap getRegistryStatistics() const;
    QVector<ToolExecutionResult> getExecutionHistory(const QString &toolId,
                                                    int limit = 100) const;
    
    // Configuration
    void setToolConfiguration(const QString &toolId,
                             const QVariantMap &config,
                             std::function<void(bool success)> callback = nullptr);
    QVariantMap getToolConfiguration(const QString &toolId) const;
    void setGlobalConfiguration(const QVariantMap &config);
    QVariantMap getGlobalConfiguration() const;
    
    // Marketplace Integration
    QVector<MarketplaceTool> getMarketplaceTools(const ToolQuery &query) const;
    void installFromMarketplace(const QString &toolId, const QString &version,
                               std::function<void(bool success, const QString &error)> callback = nullptr);
    void updateFromMarketplace(const QString &toolId, const QString &version,
                              std::function<void(bool success, const QString &error)> callback = nullptr);
    
    // Cleanup & Maintenance
    void reloadAllTools(std::function<void(int loaded, int failed)> callback = nullptr);
    void cleanupFailedTools(std::function<void(int removed)> callback = nullptr);
    void clearExecutionHistory(const QString &toolId,
                              std::function<void(bool success)> callback = nullptr);

private:
    QMap<QString, ToolInstance> m_tools;
    QMap<QString, ToolChain> m_chains;
    QMap<QString, ToolExecutionResult> m_executionResults;
    QMap<QString, ToolHook> m_hooks;
    QMap<QString, ToolPermission> m_permissions;
    QMap<QString, ToolStatistics> m_statistics;
    
    QVector<ToolExecutionResult> m_executionHistory;
    
    QVariantMap m_globalConfig;
    
    mutable QMutex m_mutex;
    
    // Helper methods
    bool matchesQuery(const ToolInstance &tool, const ToolQuery &query) const;
    bool validateParameter(const ToolParameter &param, const QVariant &value, QString &error) const;
    void recordExecution(const ToolExecutionResult &result);
    void updateStatistics(const QString &toolId, const ToolExecutionResult &result);
};

using DefaultToolRegistryPtr = std::shared_ptr<DefaultToolRegistry>;
