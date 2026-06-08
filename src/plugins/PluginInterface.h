#ifndef PLUGININTERFACE_H
#define PLUGININTERFACE_H

#include "PluginMetadata.h"
#include <QObject>
#include <QJsonObject>
#include <QString>

/**
 * @class PluginInterface
 * @brief Base interface for all plugins
 * 
 * All plugins must inherit from this interface and implement the required methods.
 * Provides lifecycle hooks, configuration, and capability exposure.
 */

class PluginInterface : public QObject
{
    Q_OBJECT

public:
    /**
     * Plugin lifecycle states
     */
    enum PluginState {
        Unloaded,      // Not loaded
        Loaded,        // Loaded but not initialized
        Initializing,  // Initialization in progress
        Initialized,   // Initialized and ready
        Running,       // Active and running
        Paused,        // Paused (not running)
        Unloading,     // Unloading in progress
        Failed,        // Failed state
        Disabled       // Disabled by policy
    };

    explicit PluginInterface(QObject *parent = nullptr);
    virtual ~PluginInterface() = default;

    // Metadata
    virtual PluginMetadata metadata() const = 0;
    QString pluginId() const { return metadata().id(); }

    // Lifecycle methods
    /**
     * Called when plugin is loaded into memory
     */
    virtual bool initialize() { return true; }

    /**
     * Called when plugin is about to be activated/started
     */
    virtual bool activate() { return true; }

    /**
     * Called when plugin is being paused
     */
    virtual void pause() {}

    /**
     * Called when plugin is being resumed
     */
    virtual void resume() {}

    /**
     * Called when plugin is being unloaded
     */
    virtual void shutdown() {}

    // Configuration
    /**
     * Get plugin configuration schema (for validation)
     */
    virtual QJsonObject configurationSchema() const
    {
        return QJsonObject();
    }

    /**
     * Called to configure the plugin
     */
    virtual bool configure(const QJsonObject &config)
    {
        return true;
    }

    /**
     * Get current configuration
     */
    virtual QJsonObject getConfiguration() const
    {
        return QJsonObject();
    }

    // Capabilities
    /**
     * Get list of features/capabilities exposed by this plugin
     */
    virtual QStringList getCapabilities() const
    {
        return QStringList();
    }

    /**
     * Check if plugin has specific capability
     */
    virtual bool hasCapability(const QString &capability) const
    {
        return getCapabilities().contains(capability);
    }

    // Status
    virtual PluginState state() const { return m_state; }
    virtual QString stateString() const;
    virtual QString getStatusMessage() const { return QString(); }
    virtual int getProgress() const { return 0; }  // 0-100

    // Error handling
    virtual QString getLastError() const { return m_lastError; }
    virtual void clearError() { m_lastError.clear(); }

    // Dependency resolution
    virtual QStringList getDependencies() const
    {
        return metadata().dependencies().length() > 0 ?
            [this]() {
                QStringList deps;
                for (const auto &dep : metadata().dependencies()) {
                    deps.append(dep.pluginId);
                }
                return deps;
            }() : QStringList();
    }

    // Validation
    /**
     * Check if plugin is in valid/operable state
     */
    virtual bool isValid() const
    {
        return m_state == Initialized || m_state == Running || m_state == Paused;
    }

    /**
     * Perform self-tests
     */
    virtual bool runSelfTests()
    {
        return true;
    }

signals:
    /**
     * Emitted when plugin state changes
     */
    void stateChanged(PluginState oldState, PluginState newState);

    /**
     * Emitted when an error occurs
     */
    void error(const QString &message);

    /**
     * Emitted when plugin is initialized
     */
    void initialized();

    /**
     * Emitted when plugin is about to shutdown
     */
    void aboutToShutdown();

    /**
     * Emitted when progress is made (useful for long operations)
     */
    void progressChanged(int progress);

    /**
     * Emitted for plugin-specific events
     */
    void eventOccurred(const QString &eventName, const QJsonObject &data);

protected:
    /**
     * Helper to change state
     */
    void setState(PluginState newState)
    {
        if (m_state != newState) {
            auto oldState = m_state;
            m_state = newState;
            emit stateChanged(oldState, newState);
        }
    }

    /**
     * Helper to record error
     */
    void setError(const QString &errorMsg)
    {
        m_lastError = errorMsg;
        emit error(errorMsg);
    }

private:
    PluginState m_state = Unloaded;
    QString m_lastError;
};

Q_DECLARE_INTERFACE(PluginInterface, "org.neurx.PluginInterface/1.0")

#endif // PLUGININTERFACE_H
