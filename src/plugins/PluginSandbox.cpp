#include "PluginSandbox.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QDebug>

PluginSandbox::PluginSandbox()
{
}

PluginSandbox::~PluginSandbox()
{
}

void PluginSandbox::setPolicyForPlugin(const QString &pluginId, const SandboxPolicy &policy)
{
    if (m_sandboxes.contains(pluginId)) {
        m_sandboxes[pluginId].policy = policy;
    } else {
        PluginSandboxState state;
        state.policy = policy;
        m_sandboxes.insert(pluginId, state);
    }
}

PluginSandbox::SandboxPolicy PluginSandbox::getPolicyForPlugin(const QString &pluginId)
{
    if (m_sandboxes.contains(pluginId)) {
        return m_sandboxes[pluginId].policy;
    }
    return SandboxPolicy();
}

bool PluginSandbox::removePolicyForPlugin(const QString &pluginId)
{
    return m_sandboxes.remove(pluginId) > 0;
}

bool PluginSandbox::hasPermission(const QString &pluginId, Permission perm) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return false;
    }
    return it.value().policy.allowedPermissions & perm;
}

bool PluginSandbox::hasPermissions(const QString &pluginId, Permissions perms) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return false;
    }
    return (it.value().policy.allowedPermissions & perms) == perms;
}

void PluginSandbox::grantPermission(const QString &pluginId, Permission perm)
{
    if (m_sandboxes.contains(pluginId)) {
        m_sandboxes[pluginId].policy.allowedPermissions |= perm;
    }
}

void PluginSandbox::revokePermission(const QString &pluginId, Permission perm)
{
    if (m_sandboxes.contains(pluginId)) {
        m_sandboxes[pluginId].policy.allowedPermissions &= ~perm;
    }
}

bool PluginSandbox::isAPIAllowed(const QString &pluginId, const QString &apiName) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return false;
    }

    const auto &policy = it.value().policy;

    // Check blacklist first
    if (policy.blacklistedAPIs.contains(apiName)) {
        return false;
    }

    // If whitelist is not empty, check if API is in it
    if (!policy.whitelistedAPIs.isEmpty()) {
        return policy.whitelistedAPIs.contains(apiName);
    }

    // If no whitelist, API is allowed (not blacklisted)
    return true;
}

void PluginSandbox::whitelistAPI(const QString &pluginId, const QString &apiName)
{
    if (m_sandboxes.contains(pluginId)) {
        m_sandboxes[pluginId].policy.whitelistedAPIs.insert(apiName);
    }
}

void PluginSandbox::blacklistAPI(const QString &pluginId, const QString &apiName)
{
    if (m_sandboxes.contains(pluginId)) {
        m_sandboxes[pluginId].policy.blacklistedAPIs.insert(apiName);
    }
}

qint64 PluginSandbox::getPluginMemoryUsage(const QString &pluginId) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it != m_sandboxes.end()) {
        return it.value().memoryUsageMB;
    }
    return 0;
}

double PluginSandbox::getPluginCPUUsage(const QString &pluginId) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it != m_sandboxes.end()) {
        return it.value().cpuUsagePercent;
    }
    return 0.0;
}

int PluginSandbox::getPluginFileHandleCount(const QString &pluginId) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it != m_sandboxes.end()) {
        return it.value().fileHandleCount;
    }
    return 0;
}

bool PluginSandbox::checkResourceLimits(const QString &pluginId)
{
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return true;
    }

    auto &state = it.value();
    const auto &limits = state.policy.limits;

    // Check memory limit
    if (state.memoryUsageMB > limits.maxMemoryMB) {
        state.lastViolation = QString("Memory limit exceeded: %1 MB / %2 MB")
            .arg(state.memoryUsageMB).arg(limits.maxMemoryMB);
        return false;
    }

    // Check CPU limit
    if (state.cpuUsagePercent > limits.maxCPUPercent) {
        state.lastViolation = QString("CPU limit exceeded: %1% / %2%")
            .arg(state.cpuUsagePercent).arg(limits.maxCPUPercent);
        return false;
    }

    // Check file handle limit
    if (state.fileHandleCount > limits.maxFileHandles) {
        state.lastViolation = QString("File handle limit exceeded: %1 / %2")
            .arg(state.fileHandleCount).arg(limits.maxFileHandles);
        return false;
    }

    // Check network connections limit
    if (state.networkConnectionCount > limits.maxNetworkConnections) {
        state.lastViolation = QString("Network connection limit exceeded: %1 / %2")
            .arg(state.networkConnectionCount).arg(limits.maxNetworkConnections);
        return false;
    }

    return true;
}

bool PluginSandbox::enforcePolicy(PluginInterface *plugin)
{
    if (!plugin) {
        return false;
    }

    QString pluginId = plugin->pluginId();
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return true;  // No policy, allow
    }

    // Check if policy is enabled
    if (!it.value().policy.enabled) {
        return true;
    }

    // Check resource limits
    return checkResourceLimits(pluginId);
}

void PluginSandbox::logAccess(const QString &pluginId, const QString &resource, bool allowed)
{
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return;
    }

    QString logEntry = QString("%1 [%2] %3: %4")
        .arg(QDateTime::currentDateTime().toString(Qt::ISODate),
             pluginId,
             resource,
             allowed ? "ALLOWED" : "DENIED");

    it.value().auditLog.append(logEntry);

    // Keep audit log size reasonable
    if (it.value().auditLog.size() > 1000) {
        it.value().auditLog = it.value().auditLog.mid(it.value().auditLog.size() - 500);
    }
}

QList<QString> PluginSandbox::getAuditLog(const QString &pluginId, int maxEntries)
{
    QList<QString> result;

    if (pluginId.isEmpty()) {
        // Return entries from all sandboxes
        for (const auto &state : m_sandboxes.values()) {
            result.append(state.auditLog);
        }
    } else {
        auto it = m_sandboxes.find(pluginId);
        if (it != m_sandboxes.end()) {
            result = it.value().auditLog;
        }
    }

    // Return last maxEntries
    if (result.size() > maxEntries) {
        result = result.mid(result.size() - maxEntries);
    }

    return result;
}

void PluginSandbox::clearAuditLog(const QString &pluginId)
{
    if (pluginId.isEmpty()) {
        for (auto &state : m_sandboxes.values()) {
            state.auditLog.clear();
        }
    } else {
        auto it = m_sandboxes.find(pluginId);
        if (it != m_sandboxes.end()) {
            it.value().auditLog.clear();
        }
    }
}

QJsonObject PluginSandbox::exportPolicy(const QString &pluginId)
{
    auto it = m_sandboxes.find(pluginId);
    if (it == m_sandboxes.end()) {
        return QJsonObject();
    }

    const auto &policy = it.value().policy;
    QJsonObject policyJson;

    policyJson["pluginId"] = policy.pluginId;
    policyJson["enabled"] = policy.enabled;
    policyJson["reason"] = policy.reason;

    // Export permissions
    policyJson["permissions"] = exportPermissions(policy.allowedPermissions);

    // Export resource limits
    QJsonObject limitsJson;
    limitsJson["maxMemoryMB"] = static_cast<int>(policy.limits.maxMemoryMB);
    limitsJson["maxCPUPercent"] = policy.limits.maxCPUPercent;
    limitsJson["maxFileHandles"] = policy.limits.maxFileHandles;
    limitsJson["maxDiskIOBytesPerSec"] = static_cast<int>(policy.limits.maxDiskIOBytesPerSec);
    limitsJson["maxNetworkConnections"] = policy.limits.maxNetworkConnections;
    limitsJson["timeoutSeconds"] = policy.limits.timeoutSeconds;
    policyJson["limits"] = limitsJson;

    // Export API lists
    QJsonArray whitelistJson;
    for (const auto &api : policy.whitelistedAPIs) {
        whitelistJson.append(api);
    }
    policyJson["whitelistedAPIs"] = whitelistJson;

    QJsonArray blacklistJson;
    for (const auto &api : policy.blacklistedAPIs) {
        blacklistJson.append(api);
    }
    policyJson["blacklistedAPIs"] = blacklistJson;

    return policyJson;
}

bool PluginSandbox::importPolicy(const QJsonObject &policyJson)
{
    QString pluginId = policyJson.value("pluginId").toString();
    if (pluginId.isEmpty()) {
        return false;
    }

    SandboxPolicy policy;
    policy.pluginId = pluginId;
    policy.enabled = policyJson.value("enabled").toBool(true);
    policy.reason = policyJson.value("reason").toString();

    // Import permissions
    policy.allowedPermissions = parsePermissions(policyJson.value("permissions").toArray());

    // Import resource limits
    QJsonObject limitsJson = policyJson.value("limits").toObject();
    if (!limitsJson.isEmpty()) {
        policy.limits.maxMemoryMB = limitsJson.value("maxMemoryMB").toInt(512);
        policy.limits.maxCPUPercent = limitsJson.value("maxCPUPercent").toInt(50);
        policy.limits.maxFileHandles = limitsJson.value("maxFileHandles").toInt(100);
        policy.limits.maxDiskIOBytesPerSec = limitsJson.value("maxDiskIOBytesPerSec").toInt(10 * 1024 * 1024);
        policy.limits.maxNetworkConnections = limitsJson.value("maxNetworkConnections").toInt(10);
        policy.limits.timeoutSeconds = limitsJson.value("timeoutSeconds").toInt(300);
    }

    // Import API lists
    QJsonArray whitelistJson = policyJson.value("whitelistedAPIs").toArray();
    for (const auto &item : whitelistJson) {
        policy.whitelistedAPIs.insert(item.toString());
    }

    QJsonArray blacklistJson = policyJson.value("blacklistedAPIs").toArray();
    for (const auto &item : blacklistJson) {
        policy.blacklistedAPIs.insert(item.toString());
    }

    setPolicyForPlugin(pluginId, policy);
    return true;
}

QJsonObject PluginSandbox::exportAllPolicies()
{
    QJsonObject allPolicies;
    QJsonArray policiesArray;

    for (auto it = m_sandboxes.begin(); it != m_sandboxes.end(); ++it) {
        policiesArray.append(exportPolicy(it.key()));
    }

    allPolicies["policies"] = policiesArray;
    allPolicies["exportedAt"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    return allPolicies;
}

bool PluginSandbox::importPolicies(const QJsonArray &policiesJson)
{
    for (const auto &item : policiesJson) {
        if (!item.isObject()) {
            continue;
        }
        if (!importPolicy(item.toObject())) {
            return false;
        }
    }
    return true;
}

void PluginSandbox::createDefaultPolicy(const QString &pluginId, const PluginMetadata &metadata)
{
    SandboxPolicy policy;
    policy.pluginId = pluginId;

    // Default: moderate permissions
    policy.allowedPermissions = PermFilesystemRead | PermNetworkHTTP | PermNetworkHTTPS;

    // Default: reasonable limits
    policy.limits.maxMemoryMB = 256;
    policy.limits.maxCPUPercent = 25;

    setPolicyForPlugin(pluginId, policy);
}

PluginSandbox::SandboxPolicy PluginSandbox::getRestrictivePolicy(const QString &pluginId)
{
    SandboxPolicy policy;
    policy.pluginId = pluginId;
    policy.allowedPermissions = Permissions();  // No permissions
    policy.limits.maxMemoryMB = 64;
    policy.limits.maxCPUPercent = 10;
    policy.limits.maxFileHandles = 10;
    return policy;
}

PluginSandbox::SandboxPolicy PluginSandbox::getPermissivePolicy(const QString &pluginId)
{
    SandboxPolicy policy;
    policy.pluginId = pluginId;
    policy.allowedPermissions = Permissions(0xFFFF);  // All permissions
    policy.limits.maxMemoryMB = 1024;
    policy.limits.maxCPUPercent = 100;
    policy.limits.maxFileHandles = 1000;
    return policy;
}

bool PluginSandbox::checkViolation(const QString &pluginId) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it != m_sandboxes.end()) {
        return !it.value().lastViolation.isEmpty();
    }
    return false;
}

QString PluginSandbox::getLastViolation(const QString &pluginId) const
{
    auto it = m_sandboxes.find(pluginId);
    if (it != m_sandboxes.end()) {
        return it.value().lastViolation;
    }
    return QString();
}

PluginSandbox::Permissions PluginSandbox::parsePermissions(const QJsonArray &permsArray) const
{
    Permissions perms;
    for (const auto &item : permsArray) {
        perms |= permissionFromString(item.toString());
    }
    return perms;
}

QJsonArray PluginSandbox::exportPermissions(Permissions perms) const
{
    QJsonArray array;
    if (perms & PermFilesystemRead) array.append("filesystem.read");
    if (perms & PermFilesystemWrite) array.append("filesystem.write");
    if (perms & PermFilesystemDelete) array.append("filesystem.delete");
    if (perms & PermFilesystemExecute) array.append("filesystem.execute");
    if (perms & PermNetworkHTTP) array.append("network.http");
    if (perms & PermNetworkHTTPS) array.append("network.https");
    if (perms & PermNetworkWebSocket) array.append("network.websocket");
    if (perms & PermNetworkDNS) array.append("network.dns");
    if (perms & PermSystemEnv) array.append("system.env");
    if (perms & PermSystemProc) array.append("system.proc");
    if (perms & PermSystemSignal) array.append("system.signal");
    if (perms & PermLoggingAccess) array.append("logging.access");
    if (perms & PermDebugAccess) array.append("debug.access");
    return array;
}

PluginSandbox::Permission PluginSandbox::permissionFromString(const QString &str) const
{
    if (str == "filesystem.read") return PermFilesystemRead;
    if (str == "filesystem.write") return PermFilesystemWrite;
    if (str == "filesystem.delete") return PermFilesystemDelete;
    if (str == "filesystem.execute") return PermFilesystemExecute;
    if (str == "network.http") return PermNetworkHTTP;
    if (str == "network.https") return PermNetworkHTTPS;
    if (str == "network.websocket") return PermNetworkWebSocket;
    if (str == "network.dns") return PermNetworkDNS;
    if (str == "system.env") return PermSystemEnv;
    if (str == "system.proc") return PermSystemProc;
    if (str == "system.signal") return PermSystemSignal;
    if (str == "logging.access") return PermLoggingAccess;
    if (str == "debug.access") return PermDebugAccess;
    return static_cast<Permission>(0);  // Unknown permission
}

QString PluginSandbox::permissionToString(Permission perm) const
{
    switch (perm) {
    case PermFilesystemRead: return "filesystem.read";
    case PermFilesystemWrite: return "filesystem.write";
    case PermFilesystemDelete: return "filesystem.delete";
    case PermFilesystemExecute: return "filesystem.execute";
    case PermNetworkHTTP: return "network.http";
    case PermNetworkHTTPS: return "network.https";
    case PermNetworkWebSocket: return "network.websocket";
    case PermNetworkDNS: return "network.dns";
    case PermSystemEnv: return "system.env";
    case PermSystemProc: return "system.proc";
    case PermSystemSignal: return "system.signal";
    case PermLoggingAccess: return "logging.access";
    case PermDebugAccess: return "debug.access";
    default: return "";
    }
}
