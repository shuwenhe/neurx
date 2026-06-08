#include "PluginLoader.h"
#include <QLibrary>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QSysInfo>

PluginLoader::PluginLoader()
{
}

PluginLoader::~PluginLoader()
{
    // Cleanup
    for (auto it = m_libraries.begin(); it != m_libraries.end(); ++it) {
        if (it.value()) {
            it.value()->unload();
            delete it.value();
        }
    }
    m_libraries.clear();
    m_loadedPlugins.clear();
}

PluginInterface *PluginLoader::loadPlugin(const QString &pluginPath,
                                         const PluginMetadata &metadata,
                                         QObject *parent)
{
    if (pluginPath.isEmpty()) {
        m_lastError = "Plugin path is empty";
        return nullptr;
    }

    // Check if already loaded
    if (m_loadedPlugins.contains(metadata.id())) {
        m_lastError = QString("Plugin %1 is already loaded").arg(metadata.id());
        return nullptr;
    }

    QFileInfo fileInfo(pluginPath);
    if (!fileInfo.exists()) {
        m_lastError = QString("Plugin file not found: %1").arg(pluginPath);
        return nullptr;
    }

    // Create and load library
    QLibrary *library = new QLibrary(pluginPath);
    if (!library->load()) {
        m_lastError = QString("Failed to load library: %1").arg(library->errorString());
        delete library;
        return nullptr;
    }

    // Create plugin entry
    LoadedPlugin entry;
    entry.library = library;
    entry.metadata = metadata;

    // Resolve symbols
    if (!resolveSymbols(library, entry)) {
        library->unload();
        delete library;
        return nullptr;
    }

    // Create plugin instance
    PluginInterface *plugin = createPluginInstance(entry, parent);
    if (!plugin) {
        library->unload();
        delete library;
        return nullptr;
    }

    // Validate plugin
    if (!validatePlugin(plugin)) {
        m_lastError = "Plugin validation failed";
        delete plugin;
        library->unload();
        delete library;
        return nullptr;
    }

    // Store loaded plugin
    m_loadedPlugins.insert(metadata.id(), entry);
    m_libraries.insert(pluginPath, library);

    qDebug() << "[PluginLoader] Successfully loaded plugin:" << metadata.id();
    return plugin;
}

bool PluginLoader::unloadPlugin(PluginInterface *plugin, const QString &pluginPath)
{
    if (!plugin) {
        m_lastError = "Plugin pointer is null";
        return false;
    }

    // Call plugin shutdown hook
    plugin->shutdown();

    // Find and unload library
    auto it = m_libraries.find(pluginPath);
    if (it != m_libraries.end()) {
        QLibrary *library = it.value();
        
        // Call unloader function if available
        for (auto pit = m_loadedPlugins.begin(); pit != m_loadedPlugins.end(); ++pit) {
            if (pit.value().library == library && pit.value().unloaderFunc) {
                pit.value().unloaderFunc(plugin);
                break;
            }
        }

        library->unload();
        delete library;
        m_libraries.erase(it);
    }

    // Remove from loaded plugins
    QMutableMapIterator<QString, LoadedPlugin> iter(m_loadedPlugins);
    while (iter.hasNext()) {
        iter.next();
        if (iter.value().library && iter.value().library->fileName() == pluginPath) {
            iter.remove();
            break;
        }
    }

    delete plugin;
    return true;
}

bool PluginLoader::reloadPlugin(PluginInterface *&plugin, const QString &pluginPath,
                               const PluginMetadata &metadata, QObject *parent)
{
    if (!plugin) {
        m_lastError = "Plugin pointer is null";
        return false;
    }

    // Save state
    QJsonObject state = savePluginState(plugin);

    // Unload
    if (!unloadPlugin(plugin, pluginPath)) {
        return false;
    }

    // Reload
    plugin = loadPlugin(pluginPath, metadata, parent);
    if (!plugin) {
        return false;
    }

    // Restore state
    if (!state.isEmpty()) {
        restorePluginState(plugin, state);
    }

    qDebug() << "[PluginLoader] Successfully reloaded plugin:" << metadata.id();
    return true;
}

PluginMetadata PluginLoader::loadMetadata(const QString &manifestPath)
{
    PluginMetadata metadata;

    QFile file(manifestPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_lastError = QString("Cannot open manifest: %1").arg(manifestPath);
        return metadata;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        m_lastError = "Invalid manifest JSON format";
        return metadata;
    }

    metadata.fromJson(doc.object());
    metadata.fromJson(QJsonObject{{"pluginPath", QFileInfo(manifestPath).dir().path()}});

    return metadata;
}

bool PluginLoader::validateLibrary(const QString &pluginPath)
{
    QLibrary library(pluginPath);
    
    // Try to load and check for required symbols
    if (!library.load()) {
        m_lastError = QString("Cannot load library: %1").arg(library.errorString());
        return false;
    }

    // Check for required export symbols
    PluginLoaderFunc loaderFunc = reinterpret_cast<PluginLoaderFunc>(
        library.resolve("create_plugin"));

    if (!loaderFunc) {
        m_lastError = "Missing create_plugin symbol";
        library.unload();
        return false;
    }

    library.unload();
    return true;
}

bool PluginLoader::resolveSymbols(QLibrary *library, LoadedPlugin &entry)
{
    if (!library) {
        m_lastError = "Library pointer is null";
        return false;
    }

    // Resolve loader function
    entry.loaderFunc = reinterpret_cast<PluginLoaderFunc>(
        library->resolve("create_plugin"));

    if (!entry.loaderFunc) {
        m_lastError = QString("Cannot resolve create_plugin symbol: %1")
            .arg(library->errorString());
        return false;
    }

    // Try to resolve unloader function (optional)
    entry.unloaderFunc = reinterpret_cast<PluginUnloaderFunc>(
        library->resolve("destroy_plugin"));

    return true;
}

PluginInterface *PluginLoader::createPluginInstance(const LoadedPlugin &entry, QObject *parent)
{
    if (!entry.loaderFunc) {
        m_lastError = "Loader function not set";
        return nullptr;
    }

    try {
        PluginInterface *plugin = entry.loaderFunc(parent);
        if (!plugin) {
            m_lastError = "Plugin loader returned null";
            return nullptr;
        }
        return plugin;
    } catch (const std::exception &e) {
        m_lastError = QString("Exception during plugin creation: %1").arg(e.what());
        return nullptr;
    }
}

bool PluginLoader::validatePlugin(PluginInterface *plugin)
{
    if (!plugin) {
        return false;
    }

    // Check metadata
    PluginMetadata meta = plugin->metadata();
    if (!meta.isValid()) {
        m_lastError = QString("Invalid plugin metadata: %1").arg(meta.validationError());
        return false;
    }

    return true;
}

QString PluginLoader::getPlatformSuffix() const
{
#if defined(Q_OS_WIN)
    return ".dll";
#elif defined(Q_OS_MACOS)
    return ".dylib";
#else
    return ".so";
#endif
}

QString PluginLoader::getPluginPath(const QString &pluginId) const
{
    auto it = m_loadedPlugins.find(pluginId);
    if (it != m_loadedPlugins.end() && it.value().library) {
        return it.value().library->fileName();
    }
    return QString();
}

QJsonObject PluginLoader::savePluginState(PluginInterface *plugin)
{
    if (!plugin) {
        return QJsonObject();
    }

    QJsonObject state;
    state["pluginId"] = plugin->pluginId();
    state["configuration"] = plugin->getConfiguration();
    state["state"] = plugin->stateString();

    return state;
}

bool PluginLoader::restorePluginState(PluginInterface *plugin, const QJsonObject &state)
{
    if (!plugin || state.isEmpty()) {
        return false;
    }

    // Restore configuration
    QJsonObject config = state.value("configuration").toObject();
    if (!config.isEmpty()) {
        plugin->configure(config);
    }

    return true;
}
