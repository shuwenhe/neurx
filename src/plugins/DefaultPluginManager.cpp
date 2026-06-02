#include "DefaultPluginManager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QUrl>

DefaultPluginManager::DefaultPluginManager(QObject *parent)
    : PluginManager(parent)
{
}

DefaultPluginManager::~DefaultPluginManager()
{
    unloadAll([](auto err) {
        if (err != PluginError::Success) {
            qWarning() << "Error unloading plugins on shutdown";
        }
    });
}

void DefaultPluginManager::scanPlugins(const QStringList &pluginPaths,
                                      std::function<void(PluginError, int pluginCount)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_pluginPaths = pluginPaths;
    int count = 0;
    
    for (const auto &path : pluginPaths) {
        QDir dir(path);
        if (!dir.exists()) {
            qWarning() << "Plugin path does not exist:" << path;
            continue;
        }
        
        // Scan for plugin manifest files (plugin.json)
        QStringList filters;
        filters << "plugin.json" << "manifest.json";
        
        QStringList manifests = dir.entryList(filters, QDir::Files);
        
        for (const auto &manifest : manifests) {
            QString manifestPath = dir.absoluteFilePath(manifest);
            PluginError error;
            
            PluginManifest pluginManifest = parseManifest(manifestPath, error);
            
            if (error == PluginError::Success) {
                PluginInstance instance = createInstanceFromManifest(pluginManifest);
                instance.loadPath = dir.absolutePath();
                
                PluginEntry entry;
                entry.instance = instance;
                entry.manifest = pluginManifest;
                
                m_plugins[instance.id] = entry;
                count++;
            }
        }
    }
    
    locker.unlock();
    
    if (callback) {
        callback(PluginError::Success, count);
    }
}

QVector<PluginInstance> DefaultPluginManager::listPlugins() const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<PluginInstance> instances;
    for (const auto &entry : m_plugins) {
        instances.append(entry.instance);
    }
    
    return instances;
}

PluginInstance DefaultPluginManager::getPlugin(const QString &pluginId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end()) {
        return it->instance;
    }
    
    return PluginInstance();
}

QVector<PluginInstance> DefaultPluginManager::searchPlugins(const QVariantMap &criteria) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<PluginInstance> results;
    
    for (const auto &entry : m_plugins) {
        bool matches = true;
        
        // Check category
        if (criteria.contains("category")) {
            if (entry.instance.metadata.category != criteria["category"].toString()) {
                matches = false;
            }
        }
        
        // Check status
        if (criteria.contains("status")) {
            if (entry.instance.status != static_cast<PluginStatus>(criteria["status"].toInt())) {
                matches = false;
            }
        }
        
        // Check enabled
        if (criteria.contains("enabled")) {
            // Would check against registry
        }
        
        if (matches) {
            results.append(entry.instance);
        }
    }
    
    return results;
}

void DefaultPluginManager::loadPlugin(const QString &pluginId,
                                     PluginCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound, PluginInstance());
        }
        return;
    }
    
    if (it->instance.status == PluginStatus::Loaded || 
        it->instance.status == PluginStatus::Active) {
        locker.unlock();
        if (callback) {
            callback(PluginError::AlreadyLoaded, it->instance);
        }
        return;
    }
    
    // Check dependencies
    if (!checkDependencies(pluginId)) {
        it->instance.status = PluginStatus::Failed;
        it->instance.lastError = "Unmet dependencies";
        locker.unlock();
        if (callback) {
            callback(PluginError::DependencyNotMet, it->instance);
        }
        return;
    }
    
    // Attempt to load
    PluginError error = loadPluginImpl(pluginId);
    
    if (error == PluginError::Success) {
        it->instance.status = PluginStatus::Loaded;
        it->instance.loadedAt = QDateTime::currentDateTime();
    } else {
        it->instance.status = PluginStatus::Failed;
        it->instance.lastError = QString("Failed to load: %1").arg(static_cast<int>(error));
    }
    
    PluginInstance result = it->instance;
    locker.unlock();
    
    if (error == PluginError::Success) {
        emit pluginLoaded(pluginId);
    }
    
    if (callback) {
        callback(error, result);
    }
}

void DefaultPluginManager::unloadPlugin(const QString &pluginId,
                                       PluginCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound, PluginInstance());
        }
        return;
    }
    
    if (it->instance.status == PluginStatus::Available) {
        locker.unlock();
        if (callback) {
            callback(PluginError::Success, it->instance);
        }
        return;
    }
    
    PluginError error = unloadPluginImpl(pluginId);
    
    if (error == PluginError::Success) {
        it->instance.status = PluginStatus::Available;
        it->instance.handle = nullptr;
    }
    
    PluginInstance result = it->instance;
    locker.unlock();
    
    if (error == PluginError::Success) {
        emit pluginUnloaded(pluginId);
    }
    
    if (callback) {
        callback(error, result);
    }
}

void DefaultPluginManager::loadAll(std::function<void(PluginError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    PluginError lastError = PluginError::Success;
    
    for (auto it = m_plugins.begin(); it != m_plugins.end(); ++it) {
        if (it->instance.status == PluginStatus::Available) {
            PluginError error = loadPluginImpl(it.key());
            if (error != PluginError::Success) {
                lastError = error;
            }
        }
    }
    
    locker.unlock();
    
    if (callback) {
        callback(lastError);
    }
}

void DefaultPluginManager::unloadAll(std::function<void(PluginError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    PluginError lastError = PluginError::Success;
    
    for (auto it = m_plugins.begin(); it != m_plugins.end(); ++it) {
        if (it->instance.status != PluginStatus::Available) {
            PluginError error = unloadPluginImpl(it.key());
            if (error != PluginError::Success) {
                lastError = error;
            }
        }
    }
    
    locker.unlock();
    
    if (callback) {
        callback(lastError);
    }
}

void DefaultPluginManager::activatePlugin(const QString &pluginId,
                                         PluginCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound, PluginInstance());
        }
        return;
    }
    
    if (it->instance.status != PluginStatus::Loaded) {
        locker.unlock();
        if (callback) {
            callback(PluginError::FailedToLoad, it->instance);
        }
        return;
    }
    
    it->instance.status = PluginStatus::Active;
    it->instance.activations++;
    
    PluginInstance result = it->instance;
    locker.unlock();
    
    emit pluginActivated(pluginId);
    
    if (callback) {
        callback(PluginError::Success, result);
    }
}

void DefaultPluginManager::deactivatePlugin(const QString &pluginId,
                                           PluginCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound, PluginInstance());
        }
        return;
    }
    
    if (it->instance.status != PluginStatus::Active) {
        locker.unlock();
        if (callback) {
            callback(PluginError::Success, it->instance);
        }
        return;
    }
    
    it->instance.status = PluginStatus::Loaded;
    
    PluginInstance result = it->instance;
    locker.unlock();
    
    emit pluginDeactivated(pluginId);
    
    if (callback) {
        callback(PluginError::Success, result);
    }
}

QVariantMap DefaultPluginManager::getPluginConfig(const QString &pluginId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end()) {
        return it->instance.runtimeConfig;
    }
    
    return QVariantMap();
}

void DefaultPluginManager::setPluginConfig(const QString &pluginId,
                                          const QVariantMap &config,
                                          std::function<void(PluginError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound);
        }
        return;
    }
    
    it->instance.runtimeConfig = config;
    locker.unlock();
    
    if (callback) {
        callback(PluginError::Success);
    }
    
    emit pluginEvent(PluginEvent{
        pluginId,
        PluginEventType::ConfigChanged,
        QDateTime::currentDateTime(),
        config,
        "Configuration updated"
    });
}

void DefaultPluginManager::setPluginEnabled(const QString &pluginId,
                                           bool enabled,
                                           std::function<void(PluginError)> callback)
{
    // This would update the registry/persistent storage
    if (callback) {
        callback(PluginError::Success);
    }
}

bool DefaultPluginManager::checkDependencies(const QString &pluginId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        return false;
    }
    
    for (const auto &dep : it->manifest.dependencies) {
        auto depIt = m_plugins.find(dep.pluginId);
        
        if (depIt == m_plugins.end()) {
            if (!dep.optional) {
                return false;
            }
            continue;
        }
        
        if (depIt->instance.status == PluginStatus::Available) {
            return false;
        }
    }
    
    return true;
}

QStringList DefaultPluginManager::getDependents(const QString &pluginId) const
{
    QMutexLocker locker(&m_mutex);
    
    QStringList dependents;
    
    for (const auto &entry : m_plugins) {
        for (const auto &dep : entry.manifest.dependencies) {
            if (dep.pluginId == pluginId) {
                dependents.append(entry.instance.id);
                break;
            }
        }
    }
    
    return dependents;
}

QStringList DefaultPluginManager::resolveDependencyChain(const QString &pluginId) const
{
    // Simple recursive resolution
    QStringList chain;
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end()) {
        chain.append(pluginId);
        
        for (const auto &dep : it->manifest.dependencies) {
            auto depChain = resolveDependencyChain(dep.pluginId);
            for (const auto &item : depChain) {
                if (!chain.contains(item)) {
                    chain.append(item);
                }
            }
        }
    }
    
    return chain;
}

PluginCapabilities DefaultPluginManager::getCapabilities(const QString &pluginId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end()) {
        return it->manifest.capabilities;
    }
    
    return PluginCapabilities();
}

QStringList DefaultPluginManager::getAllTools() const
{
    QMutexLocker locker(&m_mutex);
    
    QStringList tools;
    
    for (const auto &entry : m_plugins) {
        if (entry.instance.status == PluginStatus::Active) {
            tools.append(entry.manifest.capabilities.tools);
        }
    }
    
    return tools;
}

QStringList DefaultPluginManager::getAllModels() const
{
    QMutexLocker locker(&m_mutex);
    
    QStringList models;
    
    for (const auto &entry : m_plugins) {
        if (entry.instance.status == PluginStatus::Active) {
            models.append(entry.manifest.capabilities.models);
        }
    }
    
    return models;
}

QStringList DefaultPluginManager::getAllSkills() const
{
    QMutexLocker locker(&m_mutex);
    
    QStringList skills;
    
    for (const auto &entry : m_plugins) {
        if (entry.instance.status == PluginStatus::Active) {
            skills.append(entry.manifest.capabilities.skills);
        }
    }
    
    return skills;
}

void DefaultPluginManager::searchMarketplace(const QString &query,
                                            MarketplaceCallback callback)
{
    // This would make HTTP request to marketplace
    // For now, return empty results
    if (callback) {
        callback(PluginError::NetworkError, QVector<MarketplacePlugin>());
    }
}

void DefaultPluginManager::getMarketplacePlugin(const QString &marketplaceId,
                                               std::function<void(PluginError, MarketplacePlugin)> callback)
{
    if (callback) {
        callback(PluginError::NetworkError, MarketplacePlugin());
    }
}

void DefaultPluginManager::installFromMarketplace(const QString &marketplaceId,
                                                 PluginCallback callback)
{
    if (callback) {
        callback(PluginError::NetworkError, PluginInstance());
    }
}

void DefaultPluginManager::checkForUpdates(std::function<void(const QStringList &updatablePlugins)> callback)
{
    if (callback) {
        callback(QStringList());
    }
}

void DefaultPluginManager::updatePlugin(const QString &pluginId,
                                       PluginCallback callback)
{
    if (callback) {
        callback(PluginError::NetworkError, PluginInstance());
    }
}

void DefaultPluginManager::installPlugin(const QString &pluginPath,
                                        PluginCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    PluginError error;
    PluginManifest manifest = parseManifest(pluginPath + "/plugin.json", error);
    
    if (error != PluginError::Success) {
        locker.unlock();
        if (callback) {
            callback(error, PluginInstance());
        }
        return;
    }
    
    PluginInstance instance = createInstanceFromManifest(manifest);
    instance.loadPath = pluginPath;
    
    PluginEntry entry;
    entry.instance = instance;
    entry.manifest = manifest;
    
    m_plugins[instance.id] = entry;
    
    PluginInstance result = instance;
    locker.unlock();
    
    if (callback) {
        callback(PluginError::Success, result);
    }
}

void DefaultPluginManager::uninstallPlugin(const QString &pluginId,
                                          std::function<void(PluginError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound);
        }
        return;
    }
    
    m_plugins.erase(it);
    locker.unlock();
    
    if (callback) {
        callback(PluginError::Success);
    }
}

bool DefaultPluginManager::validateManifest(const PluginManifest &manifest,
                                           QString &errorMsg)
{
    if (manifest.metadata.id.isEmpty()) {
        errorMsg = "Plugin ID is required";
        return false;
    }
    
    if (manifest.metadata.name.isEmpty()) {
        errorMsg = "Plugin name is required";
        return false;
    }
    
    if (manifest.metadata.version.isEmpty()) {
        errorMsg = "Plugin version is required";
        return false;
    }
    
    if (!validateVersion(manifest.metadata.version)) {
        errorMsg = "Invalid version format";
        return false;
    }
    
    return true;
}

bool DefaultPluginManager::verifyPluginIntegrity(const QString &pluginId)
{
    // Would verify checksums
    return true;
}

void DefaultPluginManager::healthCheck(const QString &pluginId,
                                      std::function<void(bool isHealthy, const QString &message)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end() && it->instance.isHealthy) {
        locker.unlock();
        if (callback) {
            callback(true, "Plugin is healthy");
        }
        return;
    }
    
    locker.unlock();
    if (callback) {
        callback(false, "Plugin is not healthy");
    }
}

bool DefaultPluginManager::hasPermission(const QString &pluginId,
                                        const QString &permission) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end()) {
        return it->permissions.contains(permission);
    }
    
    return false;
}

void DefaultPluginManager::grantPermission(const QString &pluginId,
                                          const QString &permission,
                                          std::function<void(PluginError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound);
        }
        return;
    }
    
    if (!it->permissions.contains(permission)) {
        it->permissions.append(permission);
    }
    
    locker.unlock();
    
    if (callback) {
        callback(PluginError::Success);
    }
}

void DefaultPluginManager::revokePermission(const QString &pluginId,
                                           const QString &permission,
                                           std::function<void(PluginError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_plugins.find(pluginId);
    if (it == m_plugins.end()) {
        locker.unlock();
        if (callback) {
            callback(PluginError::NotFound);
        }
        return;
    }
    
    it->permissions.removeAll(permission);
    
    locker.unlock();
    
    if (callback) {
        callback(PluginError::Success);
    }
}

QVariantMap DefaultPluginManager::getPluginStats(const QString &pluginId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    auto it = m_plugins.find(pluginId);
    if (it != m_plugins.end()) {
        stats["id"] = it->instance.id;
        stats["status"] = static_cast<int>(it->instance.status);
        stats["activations"] = it->instance.activations;
        stats["loadedAt"] = it->instance.loadedAt;
        stats["lastActivityAt"] = it->instance.lastActivityAt;
        stats["isHealthy"] = it->instance.isHealthy;
    }
    
    return stats;
}

QVariantMap DefaultPluginManager::getAllStats() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalPlugins"] = m_plugins.size();
    stats["loadedCount"] = 0;
    stats["activeCount"] = 0;
    
    for (const auto &entry : m_plugins) {
        if (entry.instance.status != PluginStatus::Available) {
            stats["loadedCount"] = stats["loadedCount"].toInt() + 1;
        }
        if (entry.instance.status == PluginStatus::Active) {
            stats["activeCount"] = stats["activeCount"].toInt() + 1;
        }
    }
    
    return stats;
}

QVector<PluginRegistryEntry> DefaultPluginManager::getRegistry() const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<PluginRegistryEntry> registry;
    
    for (const auto &entry : m_plugins) {
        PluginRegistryEntry regEntry;
        regEntry.metadata = entry.instance.metadata;
        regEntry.status = entry.instance.status;
        regEntry.installPath = entry.instance.loadPath;
        regEntry.installedAt = entry.instance.loadedAt;
        registry.append(regEntry);
    }
    
    return registry;
}

PluginManifest DefaultPluginManager::parseManifest(const QString &manifestPath, PluginError &error)
{
    QFile file(manifestPath);
    if (!file.open(QIODevice::ReadOnly)) {
        error = PluginError::FileNotFound;
        return PluginManifest();
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        error = PluginError::InvalidManifest;
        return PluginManifest();
    }
    
    // Parse manifest from JSON
    PluginManifest manifest;
    QJsonObject obj = doc.object();
    
    manifest.metadata.id = obj["id"].toString();
    manifest.metadata.name = obj["name"].toString();
    manifest.metadata.version = obj["version"].toString();
    manifest.metadata.description = obj["description"].toString();
    manifest.metadata.author = obj["author"].toString();
    
    error = PluginError::Success;
    return manifest;
}

PluginInstance DefaultPluginManager::createInstanceFromManifest(const PluginManifest &manifest)
{
    PluginInstance instance;
    instance.id = manifest.metadata.id;
    instance.metadata = manifest.metadata;
    instance.status = PluginStatus::Available;
    instance.isHealthy = true;
    return instance;
}

PluginError DefaultPluginManager::loadPluginImpl(const QString &pluginId)
{
    // Implementation would actually load the plugin library
    return PluginError::Success;
}

PluginError DefaultPluginManager::unloadPluginImpl(const QString &pluginId)
{
    return PluginError::Success;
}

bool DefaultPluginManager::validateVersion(const QString &version)
{
    // Simple version validation (semver)
    QStringList parts = version.split('.');
    return parts.size() == 3;
}

bool DefaultPluginManager::validateDependencyVersion(const QString &required, const QString &actual)
{
    // Simple version comparison
    return required == actual;
}

#include "moc_DefaultPluginManager.cpp"
