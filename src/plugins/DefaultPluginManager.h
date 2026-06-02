#pragma once

#include "PluginManager.h"
#include <QPluginLoader>
#include <QLibraryInfo>
#include <QMap>

/**
 * @class DefaultPluginManager
 * @brief Default plugin manager implementation
 * 
 * Features:
 * - Dynamic plugin loading with QLibrary/QPluginLoader
 * - Dependency resolution
 * - Marketplace integration (via HTTP)
 * - Plugin validation and verification
 * - Sandboxing support
 */
class DefaultPluginManager : public PluginManager {
    Q_OBJECT
public:
    explicit DefaultPluginManager(QObject *parent = nullptr);
    ~DefaultPluginManager();
    
    // Discovery
    void scanPlugins(const QStringList &pluginPaths,
                    std::function<void(PluginError, int pluginCount)> callback) override;
    QVector<PluginInstance> listPlugins() const override;
    PluginInstance getPlugin(const QString &pluginId) const override;
    QVector<PluginInstance> searchPlugins(const QVariantMap &criteria) const override;
    
    // Loading/Unloading
    void loadPlugin(const QString &pluginId,
                   PluginCallback callback) override;
    void unloadPlugin(const QString &pluginId,
                     PluginCallback callback) override;
    void loadAll(std::function<void(PluginError)> callback) override;
    void unloadAll(std::function<void(PluginError)> callback) override;
    
    // Activation
    void activatePlugin(const QString &pluginId,
                       PluginCallback callback) override;
    void deactivatePlugin(const QString &pluginId,
                         PluginCallback callback) override;
    
    // Configuration
    QVariantMap getPluginConfig(const QString &pluginId) const override;
    void setPluginConfig(const QString &pluginId,
                        const QVariantMap &config,
                        std::function<void(PluginError)> callback) override;
    void setPluginEnabled(const QString &pluginId,
                         bool enabled,
                         std::function<void(PluginError)> callback) override;
    
    // Dependencies
    bool checkDependencies(const QString &pluginId) const override;
    QStringList getDependents(const QString &pluginId) const override;
    QStringList resolveDependencyChain(const QString &pluginId) const override;
    
    // Capabilities
    PluginCapabilities getCapabilities(const QString &pluginId) const override;
    QStringList getAllTools() const override;
    QStringList getAllModels() const override;
    QStringList getAllSkills() const override;
    
    // Marketplace
    void searchMarketplace(const QString &query,
                          MarketplaceCallback callback) override;
    void getMarketplacePlugin(const QString &marketplaceId,
                             std::function<void(PluginError, MarketplacePlugin)> callback) override;
    void installFromMarketplace(const QString &marketplaceId,
                               PluginCallback callback) override;
    void checkForUpdates(std::function<void(const QStringList &updatablePlugins)> callback) override;
    void updatePlugin(const QString &pluginId,
                     PluginCallback callback) override;
    
    // Installation
    void installPlugin(const QString &pluginPath,
                      PluginCallback callback) override;
    void uninstallPlugin(const QString &pluginId,
                        std::function<void(PluginError)> callback) override;
    
    // Validation
    bool validateManifest(const PluginManifest &manifest,
                         QString &errorMsg) override;
    bool verifyPluginIntegrity(const QString &pluginId) override;
    void healthCheck(const QString &pluginId,
                    std::function<void(bool isHealthy, const QString &message)> callback) override;
    
    // Permissions
    bool hasPermission(const QString &pluginId,
                      const QString &permission) const override;
    void grantPermission(const QString &pluginId,
                        const QString &permission,
                        std::function<void(PluginError)> callback) override;
    void revokePermission(const QString &pluginId,
                         const QString &permission,
                         std::function<void(PluginError)> callback) override;
    
    // Statistics
    QVariantMap getPluginStats(const QString &pluginId) const override;
    QVariantMap getAllStats() const override;
    QVector<PluginRegistryEntry> getRegistry() const override;

private:
    struct PluginEntry {
        PluginInstance instance;
        PluginManifest manifest;
        QStringList permissions;
        QPluginLoader *loader{nullptr};
    };
    
    QMap<QString, PluginEntry> m_plugins;
    QStringList m_pluginPaths;
    QVariantMap m_marketplaceCache;
    mutable QMutex m_mutex;
    
    // Parsing
    PluginManifest parseManifest(const QString &manifestPath, PluginError &error);
    PluginInstance createInstanceFromManifest(const PluginManifest &manifest);
    
    // Loading implementation
    PluginError loadPluginImpl(const QString &pluginId);
    PluginError unloadPluginImpl(const QString &pluginId);
    
    // Validation helpers
    bool validateVersion(const QString &version);
    bool validateDependencyVersion(const QString &required, const QString &actual);
    
    // Marketplace integration
    void fetchFromMarketplace(const QString &endpoint,
                             MarketplaceCallback callback);
    
    // Utilities
    QString findPluginFile(const QString &pluginId, const QStringList &paths);
    QVariantMap loadJsonManifest(const QString &filePath);
};

using DefaultPluginManagerPtr = std::shared_ptr<DefaultPluginManager>;
