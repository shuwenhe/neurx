#pragma once

#include "ToolTypes.h"
#include <QObject>
#include <memory>

/**
 * @class ToolRegistry
 * @brief Tool registration and orchestration
 * 
 * Handles:
 * - Tool registration and discovery
 * - Tool execution
 * - Tool chain management
 * - Permission management
 * - Tool lifecycle
 */
class ToolRegistry : public QObject {
    Q_OBJECT
public:
    virtual ~ToolRegistry() = default;
    
    // ── Tool Registration ───────────────────────────────
    
    /// Register a new tool
    virtual QString registerTool(const ToolInstance &tool,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Unregister tool
    virtual void unregisterTool(const QString &toolId,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Update tool metadata
    virtual void updateTool(const QString &toolId, const ToolMetadata &metadata,
                           std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Tool Discovery ──────────────────────────────────
    
    /// Get tool by ID
    virtual ToolInstance getTool(const QString &toolId) const = 0;
    
    /// Get all tools
    virtual QVector<ToolInstance> getAllTools() const = 0;
    
    /// Search tools
    virtual void searchTools(const ToolQuery &query,
                            ToolSearchCallback callback = nullptr) = 0;
    
    /// Get tools by category
    virtual QVector<ToolInstance> getToolsByCategory(ToolCategory category) const = 0;
    
    /// Get tools by tag
    virtual QVector<ToolInstance> getToolsByTag(const QString &tag) const = 0;
    
    /// Find tools matching capability
    virtual QVector<ToolInstance> findToolsByCapability(const QString &capabilityName) const = 0;
    
    // ── Tool Loading & Activation ───────────────────────
    
    /// Load tool
    virtual void loadTool(const QString &toolId,
                         std::function<void(bool success, const QString &error)> callback = nullptr) = 0;
    
    /// Unload tool
    virtual void unloadTool(const QString &toolId,
                           std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Activate tool
    virtual void activateTool(const QString &toolId,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Deactivate tool
    virtual void deactivateTool(const QString &toolId,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Check tool availability
    virtual bool isToolAvailable(const QString &toolId) const = 0;
    
    /// Get tool status
    virtual ToolStatus getToolStatus(const QString &toolId) const = 0;
    
    // ── Tool Execution ──────────────────────────────────
    
    /// Execute tool
    virtual void executeTool(const QString &toolId,
                            const QVariantMap &parameters,
                            ToolCallback callback = nullptr,
                            int timeoutMs = 30000) = 0;
    
    /// Execute tool with specific capability
    virtual void executeToolCapability(const QString &toolId,
                                      const QString &capabilityName,
                                      const QVariantMap &parameters,
                                      ToolCallback callback = nullptr,
                                      int timeoutMs = 30000) = 0;
    
    /// Cancel execution
    virtual void cancelExecution(const QString &executionId,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get execution status
    virtual ToolExecutionResult getExecutionStatus(const QString &executionId) const = 0;
    
    // ── Tool Chain Execution ────────────────────────────
    
    /// Create tool chain
    virtual QString createToolChain(const ToolChain &chain,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Execute tool chain
    virtual void executeToolChain(const QString &chainId,
                                 const QVariantMap &parameters,
                                 std::function<void(const QVector<ToolExecutionResult> &)> callback = nullptr) = 0;
    
    /// Get chain
    virtual ToolChain getToolChain(const QString &chainId) const = 0;
    
    /// List chains
    virtual QVector<ToolChain> listToolChains() const = 0;
    
    /// Delete chain
    virtual void deleteToolChain(const QString &chainId,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Validation ──────────────────────────────────────
    
    /// Validate parameters for tool
    virtual bool validateParameters(const QString &toolId,
                                   const QVariantMap &parameters,
                                   QString &errorMsg) = 0;
    
    /// Validate parameters for capability
    virtual bool validateCapabilityParameters(const QString &toolId,
                                             const QString &capabilityName,
                                             const QVariantMap &parameters,
                                             QString &errorMsg) = 0;
    
    /// Check dependencies
    virtual bool checkDependencies(const QString &toolId,
                                  QString &errorMsg) = 0;
    
    // ── Permissions ─────────────────────────────────────
    
    /// Grant permission
    virtual void grantPermission(const QString &toolId,
                                const QString &principalId,
                                Permission permission,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Revoke permission
    virtual void revokePermission(const QString &toolId,
                                 const QString &principalId,
                                 Permission permission,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Check permission
    virtual bool hasPermission(const QString &toolId,
                              const QString &principalId,
                              Permission permission) const = 0;
    
    /// Get permissions
    virtual QVector<ToolPermission> getPermissions(const QString &toolId) const = 0;
    
    // ── Tool Hooks ──────────────────────────────────────
    
    /// Register hook
    virtual void registerHook(const ToolHook &hook,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Unregister hook
    virtual void unregisterHook(const QString &hookId,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get hooks for tool
    virtual QVector<ToolHook> getHooks(const QString &toolId) const = 0;
    
    // ── Statistics & Monitoring ────────────────────────
    
    /// Get tool statistics
    virtual ToolStatistics getToolStatistics(const QString &toolId) const = 0;
    
    /// Get registry statistics
    virtual QVariantMap getRegistryStatistics() const = 0;
    
    /// Get execution history
    virtual QVector<ToolExecutionResult> getExecutionHistory(const QString &toolId,
                                                            int limit = 100) const = 0;
    
    // ── Configuration ───────────────────────────────────
    
    /// Set tool configuration
    virtual void setToolConfiguration(const QString &toolId,
                                     const QVariantMap &config,
                                     std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get tool configuration
    virtual QVariantMap getToolConfiguration(const QString &toolId) const = 0;
    
    /// Set global configuration
    virtual void setGlobalConfiguration(const QVariantMap &config) = 0;
    
    /// Get global configuration
    virtual QVariantMap getGlobalConfiguration() const = 0;
    
    // ── Marketplace Integration ─────────────────────────
    
    /// Get marketplace tools
    virtual QVector<MarketplaceTool> getMarketplaceTools(const ToolQuery &query) const = 0;
    
    /// Install from marketplace
    virtual void installFromMarketplace(const QString &toolId, const QString &version,
                                       std::function<void(bool success, const QString &error)> callback = nullptr) = 0;
    
    /// Update tool from marketplace
    virtual void updateFromMarketplace(const QString &toolId, const QString &version,
                                      std::function<void(bool success, const QString &error)> callback = nullptr) = 0;
    
    // ── Cleanup & Maintenance ───────────────────────────
    
    /// Reload all tools
    virtual void reloadAllTools(std::function<void(int loaded, int failed)> callback = nullptr) = 0;
    
    /// Cleanup failed tools
    virtual void cleanupFailedTools(std::function<void(int removed)> callback = nullptr) = 0;
    
    /// Clear execution history
    virtual void clearExecutionHistory(const QString &toolId,
                                      std::function<void(bool success)> callback = nullptr) = 0;

signals:
    /// Tool registered signal
    void toolRegistered(const QString &toolId);
    
    /// Tool unregistered signal
    void toolUnregistered(const QString &toolId);
    
    /// Tool loaded signal
    void toolLoaded(const QString &toolId);
    
    /// Tool unloaded signal
    void toolUnloaded(const QString &toolId);
    
    /// Tool activated signal
    void toolActivated(const QString &toolId);
    
    /// Tool deactivated signal
    void toolDeactivated(const QString &toolId);
    
    /// Execution started signal
    void executionStarted(const QString &toolId, const QString &executionId);
    
    /// Execution completed signal
    void executionCompleted(const QString &executionId, bool success);
    
    /// Tool error signal
    void toolError(const QString &toolId, const QString &error);
    
    /// Chain executed signal
    void chainExecuted(const QString &chainId);
    
    /// Permission changed signal
    void permissionChanged(const QString &toolId, const QString &principalId);
};

using ToolRegistryPtr = std::shared_ptr<ToolRegistry>;
