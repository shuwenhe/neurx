#pragma once

#include "ToolRegistry.h"
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
    Q_OBJECT
public:
    explicit DefaultToolRegistry(QObject *parent = nullptr);
    ~DefaultToolRegistry() = default;
    
    // Tool Registration
    QString registerTool(const ToolInstance &tool,
                        std::function<void(bool success)> callback = nullptr) override;
    void unregisterTool(const QString &toolId,
                       std::function<void(bool success)> callback = nullptr) override;
    void updateTool(const QString &toolId, const ToolMetadata &metadata,
                   std::function<void(bool success)> callback = nullptr) override;
    
    // Tool Discovery
    ToolInstance getTool(const QString &toolId) const override;
    QVector<ToolInstance> getAllTools() const override;
    void searchTools(const ToolQuery &query,
                    ToolSearchCallback callback = nullptr) override;
    QVector<ToolInstance> getToolsByCategory(ToolCategory category) const override;
    QVector<ToolInstance> getToolsByTag(const QString &tag) const override;
    QVector<ToolInstance> findToolsByCapability(const QString &capabilityName) const override;
    
    // Tool Loading & Activation
    void loadTool(const QString &toolId,
                 std::function<void(bool success, const QString &error)> callback = nullptr) override;
    void unloadTool(const QString &toolId,
                   std::function<void(bool success)> callback = nullptr) override;
    void activateTool(const QString &toolId,
                     std::function<void(bool success)> callback = nullptr) override;
    void deactivateTool(const QString &toolId,
                       std::function<void(bool success)> callback = nullptr) override;
    bool isToolAvailable(const QString &toolId) const override;
    ToolStatus getToolStatus(const QString &toolId) const override;
    
    // Tool Execution
    void executeTool(const QString &toolId,
                    const QVariantMap &parameters,
                    ToolCallback callback = nullptr,
                    int timeoutMs = 30000) override;
    void executeToolCapability(const QString &toolId,
                              const QString &capabilityName,
                              const QVariantMap &parameters,
                              ToolCallback callback = nullptr,
                              int timeoutMs = 30000) override;
    void cancelExecution(const QString &executionId,
                        std::function<void(bool success)> callback = nullptr) override;
    ToolExecutionResult getExecutionStatus(const QString &executionId) const override;
    
    // Tool Chain Execution
    QString createToolChain(const ToolChain &chain,
                           std::function<void(bool success)> callback = nullptr) override;
    void executeToolChain(const QString &chainId,
                         const QVariantMap &parameters,
                         std::function<void(const QVector<ToolExecutionResult> &)> callback = nullptr) override;
    ToolChain getToolChain(const QString &chainId) const override;
    QVector<ToolChain> listToolChains() const override;
    void deleteToolChain(const QString &chainId,
                        std::function<void(bool success)> callback = nullptr) override;
    
    // Validation
    bool validateParameters(const QString &toolId,
                           const QVariantMap &parameters,
                           QString &errorMsg) override;
    bool validateCapabilityParameters(const QString &toolId,
                                     const QString &capabilityName,
                                     const QVariantMap &parameters,
                                     QString &errorMsg) override;
    bool checkDependencies(const QString &toolId,
                          QString &errorMsg) override;
    
    // Permissions
    void grantPermission(const QString &toolId,
                        const QString &principalId,
                        Permission permission,
                        std::function<void(bool success)> callback = nullptr) override;
    void revokePermission(const QString &toolId,
                         const QString &principalId,
                         Permission permission,
                         std::function<void(bool success)> callback = nullptr) override;
    bool hasPermission(const QString &toolId,
                      const QString &principalId,
                      Permission permission) const override;
    QVector<ToolPermission> getPermissions(const QString &toolId) const override;
    
    // Tool Hooks
    void registerHook(const ToolHook &hook,
                     std::function<void(bool success)> callback = nullptr) override;
    void unregisterHook(const QString &hookId,
                       std::function<void(bool success)> callback = nullptr) override;
    QVector<ToolHook> getHooks(const QString &toolId) const override;
    
    // Statistics & Monitoring
    ToolStatistics getToolStatistics(const QString &toolId) const override;
    QVariantMap getRegistryStatistics() const override;
    QVector<ToolExecutionResult> getExecutionHistory(const QString &toolId,
                                                    int limit = 100) const override;
    
    // Configuration
    void setToolConfiguration(const QString &toolId,
                             const QVariantMap &config,
                             std::function<void(bool success)> callback = nullptr) override;
    QVariantMap getToolConfiguration(const QString &toolId) const override;
    void setGlobalConfiguration(const QVariantMap &config) override;
    QVariantMap getGlobalConfiguration() const override;
    
    // Marketplace Integration
    QVector<MarketplaceTool> getMarketplaceTools(const ToolQuery &query) const override;
    void installFromMarketplace(const QString &toolId, const QString &version,
                               std::function<void(bool success, const QString &error)> callback = nullptr) override;
    void updateFromMarketplace(const QString &toolId, const QString &version,
                              std::function<void(bool success, const QString &error)> callback = nullptr) override;
    
    // Cleanup & Maintenance
    void reloadAllTools(std::function<void(int loaded, int failed)> callback = nullptr) override;
    void cleanupFailedTools(std::function<void(int removed)> callback = nullptr) override;
    void clearExecutionHistory(const QString &toolId,
                              std::function<void(bool success)> callback = nullptr) override;

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
