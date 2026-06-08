#ifndef PLUGINLOADER_H
#define PLUGINLOADER_H

#include "PluginInterface.h"
#include "PluginMetadata.h"
#include <QString>
#include <QMap>
#include <QLibrary>
#include <QJsonObject>
#include <functional>

/**
 * @class PluginLoader
 * @brief Dynamic plugin loading and unloading system
 * 
 * Features:
 * - Load plugins from shared libraries (.so, .dylib, .dll)
 * - Hot reload with state preservation
 * - Symbol resolution
 * - Error handling and logging
 */

class PluginLoader
{
public:
    using PluginLoaderFunc = PluginInterface * (*)(QObject *);
    using PluginUnloaderFunc = void (*)(PluginInterface *);

    explicit PluginLoader();
    ~PluginLoader();

    /**
     * Load a plugin from a shared library file
     */
    PluginInterface *loadPlugin(const QString &pluginPath,
                               const PluginMetadata &metadata,
                               QObject *parent = nullptr);

    /**
     * Unload a plugin and free its resources
     */
    bool unloadPlugin(PluginInterface *plugin, const QString &pluginPath);

    /**
     * Reload a plugin (unload and reload)
     */
    bool reloadPlugin(PluginInterface *&plugin, const QString &pluginPath,
                     const PluginMetadata &metadata, QObject *parent = nullptr);

    /**
     * Get metadata from plugin manifest file
     */
    PluginMetadata loadMetadata(const QString &manifestPath);

    /**
     * Check if a library is a valid plugin library
     */
    bool validateLibrary(const QString &pluginPath);

    /**
     * Get the last error message
     */
    QString getLastError() const { return m_lastError; }

    /**
     * Get all loaded plugin libraries
     */
    QMap<QString, QLibrary *> getLoadedLibraries() const { return m_libraries; }

    /**
     * Get plugin path from ID
     */
    QString getPluginPath(const QString &pluginId) const;

    /**
     * Save plugin state before reload
     */
    QJsonObject savePluginState(PluginInterface *plugin);

    /**
     * Restore plugin state after reload
     */
    bool restorePluginState(PluginInterface *plugin, const QJsonObject &state);

private:
    struct LoadedPlugin {
        QLibrary *library = nullptr;
        PluginLoaderFunc loaderFunc = nullptr;
        PluginUnloaderFunc unloaderFunc = nullptr;
        PluginMetadata metadata;
    };

    QMap<QString, LoadedPlugin> m_loadedPlugins;  // pluginId -> LoadedPlugin
    QMap<QString, QLibrary *> m_libraries;         // pluginPath -> QLibrary
    QString m_lastError;

    // Helper methods
    bool resolveSymbols(QLibrary *library, LoadedPlugin &entry);
    PluginInterface *createPluginInstance(const LoadedPlugin &entry, QObject *parent);
    bool validatePlugin(PluginInterface *plugin);
    QString getPlatformSuffix() const;
};

#endif // PLUGINLOADER_H
