#include "DefaultToolPermissionManager.h"
#include <QUuid>
#include <QDebug>

DefaultToolPermissionManager::DefaultToolPermissionManager(QObject *parent)
    : ToolPermissionManager(parent) {
    // 初始化管理员用户
    m_adminUsers.insert("admin");
}

// ── 权限管理 ────────────────────────────────────────

void DefaultToolPermissionManager::setToolPermission(
    const ToolPermission &permission,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    try {
        PermissionEntry entry;
        entry.permission = permission;
        entry.createdAt = QDateTime::currentDateTime();
        entry.modifiedAt = QDateTime::currentDateTime();
        if (!permission.expiresAt.isNull()) {
            entry.expiresAt = permission.expiresAt;
        }
        
        m_permissions[permission.toolId] = entry;
        
        logAudit(permission.toolId, "system", "SET_PERMISSION",
                QString("Level: %1, Scope: %2")
                .arg(static_cast<int>(permission.level))
                .arg(static_cast<int>(permission.scope)));
        
        emit permissionChanged(permission.toolId);
        
        if (callback) callback(true);
    } catch (const std::exception &e) {
        qWarning() << "Failed to set permission:" << e.what();
        if (callback) callback(false);
    }
}

ToolPermission DefaultToolPermissionManager::getToolPermission(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        return m_permissions[toolId].permission;
    }
    
    // 返回默认权限
    ToolPermission defaultPerm;
    defaultPerm.toolId = toolId;
    defaultPerm.level = PermissionLevel::Public;
    defaultPerm.scope = PermissionScope::Global;
    return defaultPerm;
}

void DefaultToolPermissionManager::removeToolPermission(
    const QString &toolId,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    bool success = m_permissions.remove(toolId) > 0;
    
    if (success) {
        logAudit(toolId, "system", "REMOVE_PERMISSION", "");
        emit permissionChanged(toolId);
    }
    
    if (callback) callback(success);
}

void DefaultToolPermissionManager::updatePermissionLevel(
    const QString &toolId,
    PermissionLevel level,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        m_permissions[toolId].permission.level = level;
        m_permissions[toolId].modifiedAt = QDateTime::currentDateTime();
        
        logAudit(toolId, "system", "UPDATE_LEVEL",
                QString("New level: %1").arg(static_cast<int>(level)));
        
        emit permissionChanged(toolId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::setPermissionExpiry(
    const QString &toolId,
    const QDateTime &expiryTime,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        m_permissions[toolId].expiresAt = expiryTime;
        m_permissions[toolId].permission.expiresAt = expiryTime;
        
        logAudit(toolId, "system", "SET_EXPIRY",
                QString("Expires at: %1").arg(expiryTime.toString()));
        
        emit permissionExpired(toolId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

// ── 访问控制 ────────────────────────────────────────

void DefaultToolPermissionManager::checkToolAccess(
    const QString &toolId,
    const QString &userId,
    ToolPermissionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    // 检查权限是否过期
    if (isPermissionExpired(toolId)) {
        logAudit(toolId, userId, "ACCESS_DENIED", "Permission expired");
        if (callback) callback(false, "Permission has expired");
        return;
    }
    
    // 获取权限
    if (!m_permissions.contains(toolId)) {
        if (callback) callback(true, "");  // 默认允许
        return;
    }
    
    const auto &perm = m_permissions[toolId];
    
    // 检查权限级别
    if (perm.permission.level == PermissionLevel::Public) {
        m_toolAccessCount[toolId]++;
        m_userAccessCount[userId]++;
        if (callback) callback(true, "");
        return;
    }
    
    if (perm.permission.level == PermissionLevel::Internal) {
        // 认证用户 - 简单检查：userId不为空
        if (!userId.isEmpty()) {
            m_toolAccessCount[toolId]++;
            m_userAccessCount[userId]++;
            if (callback) callback(true, "");
            return;
        }
        logAudit(toolId, userId, "ACCESS_DENIED", "Not authenticated");
        if (callback) callback(false, "Authentication required");
        return;
    }
    
    // Private 或 Restricted
    if (checkUserPermission(toolId, userId) || 
        checkRolePermission(toolId, userId)) {
        m_toolAccessCount[toolId]++;
        m_userAccessCount[userId]++;
        if (callback) callback(true, "");
        return;
    }
    
    logAudit(toolId, userId, "ACCESS_DENIED", "No permission");
    if (callback) callback(false, "Access denied");
}

void DefaultToolPermissionManager::checkExecutionPermission(
    const QString &toolId,
    const QString &userId,
    ToolPermissionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    // 先检查基本访问权限
    if (!m_permissions.contains(toolId)) {
        if (callback) callback(true, "");
        return;
    }
    
    const auto &perm = m_permissions[toolId];
    
    // 检查是否需要审批
    if (perm.permission.requiresApproval) {
        // 检查是否已批准
        for (const auto &approval : m_approvals) {
            if (approval.toolId == toolId && 
                approval.userId == userId &&
                approval.status == "Approved") {
                m_toolAccessCount[toolId]++;
                if (callback) callback(true, "");
                return;
            }
        }
        
        logAudit(toolId, userId, "EXECUTION_PENDING", "Approval required");
        if (callback) callback(false, "Approval required");
        return;
    }
    
    // 检查认证要求
    if (perm.permission.requiresAuthentication) {
        if (userId.isEmpty()) {
            logAudit(toolId, userId, "EXECUTION_DENIED", "Authentication required");
            if (callback) callback(false, "Authentication required");
            return;
        }
    }
    
    if (callback) callback(true, "");
}

void DefaultToolPermissionManager::checkCapabilityPermission(
    const QString &toolId,
    const QString &capabilityName,
    const QString &userId,
    ToolPermissionCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    // 首先检查工具访问权限
    if (!m_permissions.contains(toolId)) {
        if (callback) callback(true, "");
        return;
    }
    
    const auto &perm = m_permissions[toolId];
    
    // 通过工具访问检查
    checkToolAccess(toolId, userId, callback);
}

bool DefaultToolPermissionManager::validateExecutionRequest(
    const ToolExecutionRequest &request,
    const QString &userId) {
    
    QMutexLocker locker(&m_mutex);
    
    // 检查用户
    if (userId.isEmpty()) {
        return false;
    }
    
    // 检查工具权限
    if (m_permissions.contains(request.toolId)) {
        const auto &perm = m_permissions[request.toolId];
        
        if (perm.permission.requiresApproval && request.requiresApproval) {
            return false;
        }
    }
    
    return true;
}

// ── 用户/角色管理 ───────────────────────────────────

void DefaultToolPermissionManager::addAllowedUser(
    const QString &toolId,
    const QString &userId,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        auto &entry = m_permissions[toolId];
        if (!entry.allowedUsers.contains(userId)) {
            entry.allowedUsers.append(userId);
            entry.permission.allowedUsers.append(userId);
            
            logAudit(toolId, userId, "ADD_ALLOWED_USER", "");
            emit permissionChanged(toolId);
        }
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::removeAllowedUser(
    const QString &toolId,
    const QString &userId,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        auto &entry = m_permissions[toolId];
        int removed = entry.allowedUsers.removeAll(userId);
        entry.permission.allowedUsers.removeAll(userId);
        
        if (removed > 0) {
            logAudit(toolId, userId, "REMOVE_ALLOWED_USER", "");
            emit permissionChanged(toolId);
        }
        
        if (callback) callback(removed > 0);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::addAllowedRole(
    const QString &toolId,
    const QString &role,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        auto &entry = m_permissions[toolId];
        if (!entry.permission.allowedRoles.contains(role)) {
            entry.permission.allowedRoles.append(role);
            
            logAudit(toolId, "system", "ADD_ALLOWED_ROLE",
                    QString("Role: %1").arg(role));
            emit permissionChanged(toolId);
        }
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::removeAllowedRole(
    const QString &toolId,
    const QString &role,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        auto &entry = m_permissions[toolId];
        int removed = entry.permission.allowedRoles.removeAll(role);
        
        if (removed > 0) {
            logAudit(toolId, "system", "REMOVE_ALLOWED_ROLE",
                    QString("Role: %1").arg(role));
            emit permissionChanged(toolId);
        }
        
        if (callback) callback(removed > 0);
    } else {
        if (callback) callback(false);
    }
}

QVector<QString> DefaultToolPermissionManager::getAllowedUsers(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        return QVector<QString>(m_permissions[toolId].allowedUsers.begin(),
                               m_permissions[toolId].allowedUsers.end());
    }
    return QVector<QString>();
}

QVector<QString> DefaultToolPermissionManager::getAllowedRoles(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        return m_permissions[toolId].permission.allowedRoles;
    }
    return QVector<QString>();
}

void DefaultToolPermissionManager::setUserRole(
    const QString &userId,
    const QString &role,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    UserEntry entry;
    entry.userId = userId;
    entry.role = role;
    entry.createdAt = QDateTime::currentDateTime();
    
    m_users[userId] = entry;
    
    logAudit("system", userId, "SET_ROLE", QString("Role: %1").arg(role));
    
    if (callback) callback(true);
}

QString DefaultToolPermissionManager::getUserRole(const QString &userId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_users.contains(userId)) {
        return m_users[userId].role;
    }
    return "user";
}

// ── 审批工作流 ───────────────────────────────────────

void DefaultToolPermissionManager::setRequiresApproval(
    const QString &toolId,
    bool requires,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        m_permissions[toolId].permission.requiresApproval = requires;
        
        logAudit(toolId, "system", "SET_REQUIRES_APPROVAL",
                QString("Requires: %1").arg(requires ? "true" : "false"));
        
        emit permissionChanged(toolId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::setRequiresAuthentication(
    const QString &toolId,
    bool requires,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        m_permissions[toolId].permission.requiresAuthentication = requires;
        
        logAudit(toolId, "system", "SET_REQUIRES_AUTH",
                QString("Requires: %1").arg(requires ? "true" : "false"));
        
        emit permissionChanged(toolId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::setAuditExecutions(
    const QString &toolId,
    bool audit,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_permissions.contains(toolId)) {
        m_permissions[toolId].permission.auditExecutions = audit;
        
        logAudit(toolId, "system", "SET_AUDIT_EXECUTIONS",
                QString("Audit: %1").arg(audit ? "true" : "false"));
        
        emit permissionChanged(toolId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::approveExecution(
    const QString &executionId,
    const QString &approverId,
    const QString &reason,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_approvals.contains(executionId)) {
        auto &approval = m_approvals[executionId];
        approval.status = "Approved";
        approval.approverId = approverId;
        approval.approvalReason = reason;
        approval.approvalTime = QDateTime::currentDateTime();
        
        logAudit(approval.toolId, approverId, "APPROVAL_GRANTED",
                QString("Execution: %1, Reason: %2").arg(executionId, reason));
        
        emit executionApproved(executionId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolPermissionManager::rejectExecution(
    const QString &executionId,
    const QString &rejectorId,
    const QString &reason,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_approvals.contains(executionId)) {
        auto &approval = m_approvals[executionId];
        approval.status = "Rejected";
        approval.approverId = rejectorId;
        approval.approvalReason = reason;
        approval.approvalTime = QDateTime::currentDateTime();
        
        logAudit(approval.toolId, rejectorId, "APPROVAL_REJECTED",
                QString("Execution: %1, Reason: %2").arg(executionId, reason));
        
        emit executionRejected(executionId);
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

QVector<QVariantMap> DefaultToolPermissionManager::getPendingApprovals(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> pending;
    int count = 0;
    
    for (const auto &approval : m_approvals) {
        if (approval.status == "Pending" && count < limit) {
            QVariantMap map;
            map["executionId"] = approval.executionId;
            map["toolId"] = approval.toolId;
            map["userId"] = approval.userId;
            map["requestedAt"] = approval.requestedAt;
            pending.append(map);
            count++;
        }
    }
    
    return pending;
}

QVector<QVariantMap> DefaultToolPermissionManager::getApprovalHistory(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> history;
    int count = 0;
    
    for (const auto &approval : m_approvals) {
        if (approval.toolId == toolId && count < limit) {
            QVariantMap map;
            map["executionId"] = approval.executionId;
            map["status"] = approval.status;
            map["approverId"] = approval.approverId;
            map["approvalTime"] = approval.approvalTime.toString();
            map["reason"] = approval.approvalReason;
            history.append(map);
            count++;
        }
    }
    
    return history;
}

// ── 审计日志 ────────────────────────────────────────

QVector<QVariantMap> DefaultToolPermissionManager::getToolAuditLog(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> logs;
    int count = 0;
    
    // 反向迭代以获取最新的日志
    for (int i = m_auditLog.size() - 1; i >= 0 && count < limit; --i) {
        const auto &entry = m_auditLog[i];
        if (entry.toolId == toolId) {
            QVariantMap map;
            map["id"] = entry.id;
            map["userId"] = entry.userId;
            map["action"] = entry.action;
            map["details"] = entry.details;
            map["timestamp"] = entry.timestamp.toString();
            logs.append(map);
            count++;
        }
    }
    
    return logs;
}

QVector<QVariantMap> DefaultToolPermissionManager::getUserAuditLog(
    const QString &userId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> logs;
    int count = 0;
    
    for (int i = m_auditLog.size() - 1; i >= 0 && count < limit; --i) {
        const auto &entry = m_auditLog[i];
        if (entry.userId == userId) {
            QVariantMap map;
            map["id"] = entry.id;
            map["toolId"] = entry.toolId;
            map["action"] = entry.action;
            map["details"] = entry.details;
            map["timestamp"] = entry.timestamp.toString();
            logs.append(map);
            count++;
        }
    }
    
    return logs;
}

QVector<QVariantMap> DefaultToolPermissionManager::getPermissionChangeLog(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> logs;
    int count = 0;
    
    QStringList changeActions = {"SET_PERMISSION", "UPDATE_LEVEL", "ADD_ALLOWED_USER",
                                "REMOVE_ALLOWED_USER", "ADD_ALLOWED_ROLE",
                                "REMOVE_ALLOWED_ROLE", "SET_REQUIRES_APPROVAL"};
    
    for (int i = m_auditLog.size() - 1; i >= 0 && count < limit; --i) {
        const auto &entry = m_auditLog[i];
        if (entry.toolId == toolId && changeActions.contains(entry.action)) {
            QVariantMap map;
            map["action"] = entry.action;
            map["timestamp"] = entry.timestamp.toString();
            map["details"] = entry.details;
            logs.append(map);
            count++;
        }
    }
    
    return logs;
}

QString DefaultToolPermissionManager::exportAuditReport(
    const QDateTime &from,
    const QDateTime &to) const {
    
    QMutexLocker locker(&m_mutex);
    
    QString report = "Audit Report\n";
    report += "=============\n";
    report += QString("From: %1\n").arg(from.toString());
    report += QString("To: %1\n").arg(to.toString());
    report += "\nAudit Entries:\n";
    
    for (const auto &entry : m_auditLog) {
        if (entry.timestamp >= from && entry.timestamp <= to) {
            report += QString("[%1] Tool: %2, User: %3, Action: %4\n")
                .arg(entry.timestamp.toString(),
                     entry.toolId,
                     entry.userId,
                     entry.action);
        }
    }
    
    return report;
}

// ── 统计 ────────────────────────────────────────────

QVariantMap DefaultToolPermissionManager::getPermissionStatistics() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalTools"] = m_permissions.size();
    stats["totalUsers"] = m_users.size();
    stats["auditLogSize"] = m_auditLog.size();
    stats["pendingApprovals"] = 0;
    
    int pending = 0;
    for (const auto &approval : m_approvals) {
        if (approval.status == "Pending") pending++;
    }
    stats["pendingApprovals"] = pending;
    
    return stats;
}

QVariantMap DefaultToolPermissionManager::getToolAccessStats(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["accessCount"] = m_toolAccessCount.value(toolId, 0);
    stats["deniedCount"] = 0;  // 可以额外跟踪
    
    if (m_permissions.contains(toolId)) {
        const auto &perm = m_permissions[toolId];
        stats["allowedUsers"] = perm.allowedUsers.size();
        stats["allowedRoles"] = perm.permission.allowedRoles.size();
    }
    
    return stats;
}

QVariantMap DefaultToolPermissionManager::getUserPermissionSummary(
    const QString &userId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap summary;
    summary["userId"] = userId;
    
    if (m_users.contains(userId)) {
        summary["role"] = m_users[userId].role;
    } else {
        summary["role"] = "user";
    }
    
    summary["accessCount"] = m_userAccessCount.value(userId, 0);
    summary["isAdmin"] = m_adminUsers.contains(userId);
    
    return summary;
}

// ── 辅助方法 ────────────────────────────────────────

bool DefaultToolPermissionManager::checkUserPermission(
    const QString &toolId,
    const QString &userId) const {
    
    if (m_permissions.contains(toolId)) {
        return m_permissions[toolId].allowedUsers.contains(userId);
    }
    return false;
}

bool DefaultToolPermissionManager::checkRolePermission(
    const QString &toolId,
    const QString &userId) const {
    
    if (!m_users.contains(userId)) {
        return false;
    }
    
    QString userRole = m_users[userId].role;
    
    if (m_permissions.contains(toolId)) {
        return m_permissions[toolId].permission.allowedRoles.contains(userRole);
    }
    
    return false;
}

bool DefaultToolPermissionManager::isPermissionExpired(const QString &toolId) const {
    
    if (m_permissions.contains(toolId)) {
        const auto &entry = m_permissions[toolId];
        if (!entry.expiresAt.isNull()) {
            return QDateTime::currentDateTime() > entry.expiresAt;
        }
    }
    return false;
}

void DefaultToolPermissionManager::logAudit(
    const QString &toolId,
    const QString &userId,
    const QString &action,
    const QString &details) {
    
    AuditEntry entry;
    entry.id = generateAuditId();
    entry.toolId = toolId;
    entry.userId = userId;
    entry.action = action;
    entry.details = details;
    entry.timestamp = QDateTime::currentDateTime();
    
    m_auditLog.append(entry);
    
    // 限制审计日志大小
    if (m_auditLog.size() > 10000) {
        m_auditLog.removeFirst();
    }
}

QString DefaultToolPermissionManager::generateAuditId() {
    return QUuid::createUuid().toString().remove("{").remove("}");
}
