#include "PluginMetadata.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>

PluginMetadata::PluginMetadata()
    : m_version(0, 0, 1), m_loadPriority(0), m_autoLoad(false)
{
}

PluginMetadata::PluginMetadata(const QJsonObject &manifest)
    : m_version(0, 0, 1), m_loadPriority(0), m_autoLoad(false)
{
    fromJson(manifest);
}

PluginMetadata::~PluginMetadata()
{
}

QJsonObject PluginMetadata::toJson() const
{
    QJsonObject json;

    // Basic info
    json["id"] = m_id;
    json["name"] = m_name;
    json["description"] = m_description;
    json["author"] = m_author;
    json["license"] = m_license;
    json["version"] = m_version.toString();

    // Paths
    json["pluginPath"] = m_pluginPath;
    json["mainLibraryPath"] = m_mainLibraryPath;
    json["configPath"] = m_configPath;

    // Type and platform
    json["type"] = m_pluginType;
    json["platform"] = m_targetPlatform;

    // Lifecycle
    json["autoLoad"] = m_autoLoad;
    json["loadPriority"] = m_loadPriority;
    json["minAppVersion"] = m_minAppVersion;
    json["maxAppVersion"] = m_maxAppVersion;

    // Dependencies
    QJsonArray depsArray;
    for (const auto &dep : m_dependencies) {
        QJsonObject depObj;
        depObj["pluginId"] = dep.pluginId;
        depObj["minVersion"] = dep.minimumVersion.toString();
        depObj["maxVersion"] = dep.maximumVersion.toString();
        depObj["optional"] = dep.optional;
        depsArray.append(depObj);
    }
    json["dependencies"] = depsArray;

    // Capabilities
    QJsonArray capsArray;
    for (const auto &cap : m_capabilities) {
        QJsonObject capObj;
        capObj["name"] = cap.name;
        capObj["description"] = cap.description;
        capObj["version"] = cap.version;
        capsArray.append(capObj);
    }
    json["capabilities"] = capsArray;

    // Permissions
    QJsonArray permsArray;
    for (const auto &perm : m_permissions) {
        QJsonObject permObj;
        permObj["name"] = perm.name;
        permObj["description"] = perm.description;
        permObj["granted"] = perm.granted;
        permsArray.append(permObj);
    }
    json["permissions"] = permsArray;

    // Configuration
    json["config"] = m_configuration;

    return json;
}

bool PluginMetadata::fromJson(const QJsonObject &json)
{
    m_id = json.value("id").toString();
    m_name = json.value("name").toString();
    m_description = json.value("description").toString();
    m_author = json.value("author").toString();
    m_license = json.value("license").toString("MIT");

    // Parse version
    QString versionStr = json.value("version").toString("0.0.1");
    m_version = QVersionNumber::fromString(versionStr);

    // Paths
    m_pluginPath = json.value("pluginPath").toString();
    m_mainLibraryPath = json.value("mainLibraryPath").toString();
    m_configPath = json.value("configPath").toString();

    // Type and platform
    m_pluginType = json.value("type").toString("tool");
    m_targetPlatform = json.value("platform").toString();

    // Lifecycle
    m_autoLoad = json.value("autoLoad").toBool(false);
    m_loadPriority = json.value("loadPriority").toInt(0);
    m_minAppVersion = json.value("minAppVersion").toString();
    m_maxAppVersion = json.value("maxAppVersion").toString();

    // Dependencies
    m_dependencies.clear();
    QJsonArray depsArray = json.value("dependencies").toArray();
    for (const auto &depValue : depsArray) {
        if (!depValue.isObject()) continue;
        QJsonObject depObj = depValue.toObject();
        Dependency dep;
        dep.pluginId = depObj.value("pluginId").toString();
        dep.minimumVersion = QVersionNumber::fromString(depObj.value("minVersion").toString());
        dep.maximumVersion = QVersionNumber::fromString(depObj.value("maxVersion").toString());
        dep.optional = depObj.value("optional").toBool(false);
        m_dependencies.append(dep);
    }

    // Capabilities
    m_capabilities.clear();
    QJsonArray capsArray = json.value("capabilities").toArray();
    for (const auto &capValue : capsArray) {
        if (!capValue.isObject()) continue;
        QJsonObject capObj = capValue.toObject();
        Capability cap;
        cap.name = capObj.value("name").toString();
        cap.description = capObj.value("description").toString();
        cap.version = capObj.value("version").toString();
        m_capabilities.append(cap);
    }

    // Permissions
    m_permissions.clear();
    QJsonArray permsArray = json.value("permissions").toArray();
    for (const auto &permValue : permsArray) {
        if (!permValue.isObject()) continue;
        QJsonObject permObj = permValue.toObject();
        Permission perm;
        perm.name = permObj.value("name").toString();
        perm.description = permObj.value("description").toString();
        perm.granted = permObj.value("granted").toBool(false);
        m_permissions.append(perm);
    }

    // Configuration
    m_configuration = json.value("config").toObject();

    validate();
    return isValid();
}

bool PluginMetadata::validateDependency(const QString &pluginId, const QVersionNumber &version)
{
    for (const auto &dep : m_dependencies) {
        if (dep.pluginId == pluginId) {
            // Check version compatibility
            if (!dep.minimumVersion.isNull() && version < dep.minimumVersion) {
                return false;
            }
            if (!dep.maximumVersion.isNull() && version > dep.maximumVersion) {
                return false;
            }
            return true;
        }
    }
    return false;  // Dependency not found
}

bool PluginMetadata::hasPermission(const QString &permission) const
{
    for (const auto &perm : m_permissions) {
        if (perm.name == permission && perm.granted) {
            return true;
        }
    }
    return false;
}

QString PluginMetadata::summary() const
{
    return QString("[%1] %2 v%3 - %4")
        .arg(m_id, m_name, m_version.toString(), m_description);
}

void PluginMetadata::validate()
{
    m_validationError.clear();

    if (m_id.isEmpty()) {
        m_validationError = "Plugin ID is required";
        return;
    }

    if (m_name.isEmpty()) {
        m_validationError = "Plugin name is required";
        return;
    }

    if (m_version.isNull()) {
        m_validationError = "Plugin version is invalid";
        return;
    }
}
