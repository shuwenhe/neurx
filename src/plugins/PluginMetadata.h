#ifndef PLUGINMETADATA_H
#define PLUGINMETADATA_H

#include <QString>
#include <QList>
#include <QJsonObject>
#include <QJsonArray>
#include <QVersionNumber>

/**
 * @class PluginMetadata
 * @brief Plugin metadata and manifest information
 * 
 * Represents plugin descriptors including version, dependencies, capabilities
 */

class PluginMetadata
{
public:
    struct Dependency {
        QString pluginId;
        QVersionNumber minimumVersion;
        QVersionNumber maximumVersion;
        bool optional = false;
    };

    struct Permission {
        QString name;        // e.g., "filesystem.read", "network.http"
        QString description;
        bool granted = false;
    };

    struct Capability {
        QString name;
        QString description;
        QString version;
    };

    explicit PluginMetadata();
    explicit PluginMetadata(const QJsonObject &manifest);
    ~PluginMetadata();

    // Basic properties
    QString id() const { return m_id; }
    QString name() const { return m_name; }
    QString description() const { return m_description; }
    QString author() const { return m_author; }
    QString license() const { return m_license; }
    
    QVersionNumber version() const { return m_version; }
    QString versionString() const { return m_version.toString(); }
    
    // Paths
    QString pluginPath() const { return m_pluginPath; }
    QString mainLibraryPath() const { return m_mainLibraryPath; }
    QString configPath() const { return m_configPath; }

    // Dependencies and capabilities
    QList<Dependency> dependencies() const { return m_dependencies; }
    QList<Capability> capabilities() const { return m_capabilities; }
    QList<Permission> permissions() const { return m_permissions; }

    // Plugin type and platform
    QString pluginType() const { return m_pluginType; }  // "tool", "provider", "service"
    QString targetPlatform() const { return m_targetPlatform; }
    
    // Status
    bool isValid() const { return !m_id.isEmpty() && !m_name.isEmpty(); }
    QString validationError() const { return m_validationError; }

    // Lifecycle
    bool autoLoad() const { return m_autoLoad; }
    int loadPriority() const { return m_loadPriority; }
    QString minAppVersion() const { return m_minAppVersion; }
    QString maxAppVersion() const { return m_maxAppVersion; }

    // Configuration
    QJsonObject configuration() const { return m_configuration; }
    void setConfiguration(const QJsonObject &config) { m_configuration = config; }

    // JSON conversion
    QJsonObject toJson() const;
    bool fromJson(const QJsonObject &json);

    // Validation
    bool validateDependency(const QString &pluginId, const QVersionNumber &version);
    bool hasPermission(const QString &permission) const;

    // Debug
    QString summary() const;

private:
    // Basic info
    QString m_id;
    QString m_name;
    QString m_description;
    QString m_author;
    QString m_license;
    QVersionNumber m_version;

    // Paths
    QString m_pluginPath;
    QString m_mainLibraryPath;
    QString m_configPath;

    // Dependencies and capabilities
    QList<Dependency> m_dependencies;
    QList<Capability> m_capabilities;
    QList<Permission> m_permissions;

    // Plugin classification
    QString m_pluginType;
    QString m_targetPlatform;

    // Lifecycle settings
    bool m_autoLoad = false;
    int m_loadPriority = 0;
    QString m_minAppVersion;
    QString m_maxAppVersion;

    // Configuration
    QJsonObject m_configuration;

    // Validation state
    QString m_validationError;

    void validate();
};

#endif // PLUGINMETADATA_H
