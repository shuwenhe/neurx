#ifndef PLUGINSANDBOX_H
#define PLUGINSANDBOX_H

#include "PluginInterface.h"
#include "PluginMetadata.h"
#include <QString>
#include <QList>
#include <QJsonObject>
#include <QSet>

/**
 * @class PluginSandbox
 * @brief Plugin security and resource isolation
 * 
 * Features:
 * - Permission-based access control
 * - Resource limits (memory, CPU, disk I/O)
 * - API whitelisting/blacklisting
 * - Environment isolation
 * - Audit logging
 */

class PluginSandbox
{
public:
    enum Permission {
        // File system
        PermFilesystemRead      = 0x0001,
        PermFilesystemWrite     = 0x0002,
        PermFilesystemDelete    = 0x0004,
        PermFilesystemExecute   = 0x0008,

        // Network
        PermNetworkHTTP         = 0x0010,
        PermNetworkHTTPS        = 0x0020,
        PermNetworkWebSocket    = 0x0040,
        PermNetworkDNS          = 0x0080,

        // System
        PermSystemEnv           = 0x0100,
        PermSystemProc          = 0x0200,
        PermSystemSignal        = 0x0400,

        // Other
        PermLoggingAccess       = 0x0800,
        PermDebugAccess         = 0x1000,
    };
    Q_DECLARE_FLAGS(Permissions, Permission)

    struct ResourceLimits {
        qint64 maxMemoryMB = 512;           // Maximum memory usage
        int maxCPUPercent = 50;              // Maximum CPU usage
        int maxFileHandles = 100;            // Maximum open files
        qint64 maxDiskIOBytesPerSec = 10 * 1024 * 1024;  // 10 MB/s
        int maxNetworkConnections = 10;     // Maximum concurrent connections
        int timeoutSeconds = 300;            // Operation timeout
    };

    struct SandboxPolicy {
        QString pluginId;
        Permissions allowedPermissions;
        ResourceLimits limits;
        QSet<QString> whitelistedAPIs;
        QSet<QString> blacklistedAPIs;
        bool enabled = true;
        QString reason;  // Why this policy was set
    };

    explicit PluginSandbox();
    ~PluginSandbox();

    // Policy management
    void setPolicyForPlugin(const QString &pluginId, const SandboxPolicy &policy);
    SandboxPolicy getPolicyForPlugin(const QString &pluginId);
    bool removePolicyForPlugin(const QString &pluginId);

    // Permission checking
    bool hasPermission(const QString &pluginId, Permission perm) const;
    bool hasPermissions(const QString &pluginId, Permissions perms) const;
    void grantPermission(const QString &pluginId, Permission perm);
    void revokePermission(const QString &pluginId, Permission perm);

    // API Access Control
    bool isAPIAllowed(const QString &pluginId, const QString &apiName) const;
    void whitelistAPI(const QString &pluginId, const QString &apiName);
    void blacklistAPI(const QString &pluginId, const QString &apiName);

    // Resource monitoring
    qint64 getPluginMemoryUsage(const QString &pluginId) const;
    double getPluginCPUUsage(const QString &pluginId) const;
    int getPluginFileHandleCount(const QString &pluginId) const;

    // Enforcement
    bool checkResourceLimits(const QString &pluginId);
    bool enforcePolicy(PluginInterface *plugin);

    // Audit logging
    void logAccess(const QString &pluginId, const QString &resource, bool allowed);
    QList<QString> getAuditLog(const QString &pluginId = "", int maxEntries = 100);
    void clearAuditLog(const QString &pluginId = "");

    // Policy import/export
    QJsonObject exportPolicy(const QString &pluginId);
    bool importPolicy(const QJsonObject &policyJson);
    QJsonObject exportAllPolicies();
    bool importPolicies(const QJsonArray &policiesJson);

    // Defaults
    void createDefaultPolicy(const QString &pluginId, const PluginMetadata &metadata);
    static SandboxPolicy getRestrictivePolicy(const QString &pluginId);
    static SandboxPolicy getPermissivePolicy(const QString &pluginId);

    // Violation reporting
    bool checkViolation(const QString &pluginId) const;
    QString getLastViolation(const QString &pluginId) const;

private:
    struct PluginSandboxState {
        SandboxPolicy policy;
        qint64 memoryUsageMB = 0;
        double cpuUsagePercent = 0.0;
        int fileHandleCount = 0;
        int networkConnectionCount = 0;
        QString lastViolation;
        QList<QString> auditLog;
    };

    QMap<QString, PluginSandboxState> m_sandboxes;

    // Helpers
    Permissions parsePermissions(const QJsonArray &permsArray) const;
    QJsonArray exportPermissions(Permissions perms) const;
    Permission permissionFromString(const QString &str) const;
    QString permissionToString(Permission perm) const;
};

Q_DECLARE_OPERATORS_FOR_FLAGS(PluginSandbox::Permissions)

#endif // PLUGINSANDBOX_H
