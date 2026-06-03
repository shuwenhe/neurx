#pragma once

#include "PluginTypes.h"
#include <QObject>
#include <memory>

/**
 * @class PluginManager
 * @brief Abstract plugin management interface
 * 
 * Handles:
 * - Plugin loading and unloading
 * - Lifecycle management
 * - Dependency resolution
 * - Marketplace integration
 * - Permission enforcement
 */
class PluginManager : public QObject {
    Q_OBJECT
public:
    virtual ~PluginManager() = default;

protected:
    explicit PluginManager(QObject *parent = nullptr) : QObject(parent) {}
    
    // ── Discovery ──────────────────────────────────────────────
    
    /// Scan for plugins in specified directories
    virtual void scanPlugins(const QStringList &pluginPaths,
                            std::function<void(PluginError, int pluginCount)> callback) = 0;
    
    /// List all discovered plugins
    virtual QVector<PluginInstance> listPlugins() const = 0;
    
    /// Get plugin by ID
    virtual PluginInstance getPlugin(const QString &pluginId) const = 0;
    
    /// Search plugins by criteria
    virtual QVector<PluginInstance> searchPlugins(const QVariantMap &criteria) const = 0;
    
    // ── Loading & Unloading ────────────────────────────────────
    
    /// Load plugin (without activating)
    virtual void loadPlugin(const QString &pluginId,
                           PluginCallback callback) = 0;
    
    /// Unload plugin
    virtual void unloadPlugin(const QString &pluginId,
                             PluginCallback callback) = 0;
    
    /// Load all enabled plugins
    virtual void loadAll(std::function<void(PluginError)> callback) = 0;
    
    /// Unload all plugins
    virtual void unloadAll(std::function<void(PluginError)> callback) = 0;
    
    // ── Activation ─────────────────────────────────────────────
    
    /// Activate loaded plugin
    virtual void activatePlugin(const QString &pluginId,
                               PluginCallback callback) = 0;
    
    /// Deactivate plugin
    virtual void deactivatePlugin(const QString &pluginId,
                                 PluginCallback callback) = 0;
    
    // ── Configuration ──────────────────────────────────────────
    
    /// Get plugin configuration
    virtual QVariantMap getPluginConfig(const QString &pluginId) const = 0;
    
    /// Set plugin configuration
    virtual void setPluginConfig(const QString &pluginId,
                                const QVariantMap &config,
                                std::function<void(PluginError)> callback) = 0;
    
    /// Enable/disable plugin
    virtual void setPluginEnabled(const QString &pluginId,
                                 bool enabled,
                                 std::function<void(PluginError)> callback) = 0;
    
    // ── Dependencies ────────────────────────────────────────────
    
    /// Check if dependencies are met
    virtual bool checkDependencies(const QString &pluginId) const = 0;
    
    /// Get list of dependent plugins
    virtual QStringList getDependents(const QString &pluginId) const = 0;
    
    /// Resolve dependency chain
    virtual QStringList resolveDependencyChain(const QString &pluginId) const = 0;
    
    // ── Capabilities ────────────────────────────────────────────
    
    /// Get plugin capabilities
    virtual PluginCapabilities getCapabilities(const QString &pluginId) const = 0;
    
    /// Get all available tools from plugins
    virtual QStringList getAllTools() const = 0;
    
    /// Get all available models from plugins
    virtual QStringList getAllModels() const = 0;
    
    /// Get all available skills from plugins
    virtual QStringList getAllSkills() const = 0;
    
    // ── Marketplace ────────────────────────────────────────────
    
    /// Search marketplace
    virtual void searchMarketplace(const QString &query,
                                  MarketplaceCallback callback) = 0;
    
    /// Get marketplace plugin details
    virtual void getMarketplacePlugin(const QString &marketplaceId,
                                     std::function<void(PluginError, MarketplacePlugin)> callback) = 0;
    
    /// Install plugin from marketplace
    virtual void installFromMarketplace(const QString &marketplaceId,
                                       PluginCallback callback) = 0;
    
    /// Check for plugin updates
    virtual void checkForUpdates(std::function<void(const QStringList &updatablePlugins)> callback) = 0;
    
    /// Update plugin
    virtual void updatePlugin(const QString &pluginId,
                             PluginCallback callback) = 0;
    
    // ── Installation ────────────────────────────────────────────
    
    /// Install plugin from file
    virtual void installPlugin(const QString &pluginPath,
                              PluginCallback callback) = 0;
    
    /// Uninstall plugin
    virtual void uninstallPlugin(const QString &pluginId,
                                std::function<void(PluginError)> callback) = 0;
    
    // ── Validation & Health ────────────────────────────────────
    
    /// Validate plugin manifest
    virtual bool validateManifest(const PluginManifest &manifest,
                                 QString &errorMsg) = 0;
    
    /// Verify plugin integrity (checksum)
    virtual bool verifyPluginIntegrity(const QString &pluginId) = 0;
    
    /// Health check on plugin
    virtual void healthCheck(const QString &pluginId,
                            std::function<void(bool isHealthy, const QString &message)> callback) = 0;
    
    // ── Permissions ────────────────────────────────────────────
    
    /// Check if plugin has permission
    virtual bool hasPermission(const QString &pluginId,
                              const QString &permission) const = 0;
    
    /// Grant permission to plugin
    virtual void grantPermission(const QString &pluginId,
                               const QString &permission,
                               std::function<void(PluginError)> callback) = 0;
    
    /// Revoke permission from plugin
    virtual void revokePermission(const QString &pluginId,
                                 const QString &permission,
                                 std::function<void(PluginError)> callback) = 0;
    
    // ── Statistics & Monitoring ────────────────────────────────
    
    /// Get plugin statistics
    virtual QVariantMap getPluginStats(const QString &pluginId) const = 0;
    
    /// Get all statistics
    virtual QVariantMap getAllStats() const = 0;
    
    /// Get registry
    virtual QVector<PluginRegistryEntry> getRegistry() const = 0;

signals:
    /// Plugin loaded signal
    void pluginLoaded(const QString &pluginId);
    
    /// Plugin unloaded signal
    void pluginUnloaded(const QString &pluginId);
    
    /// Plugin activated signal
    void pluginActivated(const QString &pluginId);
    
    /// Plugin deactivated signal
    void pluginDeactivated(const QString &pluginId);
    
    /// Plugin event signal
    void pluginEvent(const PluginEvent &event);
    
    /// Plugin error signal
    void pluginError(const QString &pluginId, PluginError error, const QString &message);
};

using PluginManagerPtr = std::shared_ptr<PluginManager>;
