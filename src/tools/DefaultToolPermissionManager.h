#pragma once

#include "ToolPermissionManager.h"
#include <QMap>
#include <QSet>
#include <QDateTime>
#include <QMutex>

/**
 * @class DefaultToolPermissionManager
 * @brief Claude Code权限管理系统默认实现
 * 
 * 功能：
 * - 工具权限定义和检查
 * - 用户和角色管理
 * - 执行审批工作流
 * - 完整审计日志
 */
class DefaultToolPermissionManager : public ToolPermissionManager {
    Q_OBJECT
public:
    explicit DefaultToolPermissionManager(QObject *parent = nullptr);
    ~DefaultToolPermissionManager() = default;
    
    // ── 权限管理 ───────────────────────────────────────
    void setToolPermission(const ToolPermission &permission,
                          std::function<void(bool)> callback = nullptr) override;
    
    ToolPermission getToolPermission(const QString &toolId) const override;
    
    void removeToolPermission(const QString &toolId,
                             std::function<void(bool)> callback = nullptr) override;
    
    void updatePermissionLevel(const QString &toolId,
                              PermissionLevel level,
                              std::function<void(bool)> callback = nullptr) override;
    
    void setPermissionExpiry(const QString &toolId,
                            const QDateTime &expiryTime,
                            std::function<void(bool)> callback = nullptr) override;
    
    // ── 访问控制 ───────────────────────────────────────
    void checkToolAccess(const QString &toolId,
                        const QString &userId,
                        ToolPermissionCallback callback) override;
    
    void checkExecutionPermission(const QString &toolId,
                                 const QString &userId,
                                 ToolPermissionCallback callback) override;
    
    void checkCapabilityPermission(const QString &toolId,
                                  const QString &capabilityName,
                                  const QString &userId,
                                 ToolPermissionCallback callback) override;
    
    void validateExecutionRequest(const ToolExecutionRequest &request,
                                 const QString &userId,
                                 std::function<void(bool, QString)> callback) override;
    
    // ── 用户/角色管理 ───────────────────────────────────
    void addAllowedUser(const QString &toolId,
                       const QString &userId,
                       std::function<void(bool)> callback = nullptr) override;
    
    void removeAllowedUser(const QString &toolId,
                          const QString &userId,
                          std::function<void(bool)> callback = nullptr) override;
    
    void addAllowedRole(const QString &toolId,
                       const QString &role,
                       std::function<void(bool)> callback = nullptr) override;
    
    void removeAllowedRole(const QString &toolId,
                          const QString &role,
                          std::function<void(bool)> callback = nullptr) override;
    
    QVector<QString> getAllowedUsers(const QString &toolId) const override;
    
    QVector<QString> getAllowedRoles(const QString &toolId) const override;
    
    void setUserRole(const QString &userId,
                    const QString &role,
                    std::function<void(bool)> callback = nullptr) override;
    
    QString getUserRole(const QString &userId) const override;
    
    // ── 审批工作流 ───────────────────────────────────────
    void setRequiresApproval(const QString &toolId,
                            bool requires,
                            std::function<void(bool)> callback = nullptr) override;
    
    void setRequiresAuthentication(const QString &toolId,
                                  bool requires,
                                  std::function<void(bool)> callback = nullptr) override;
    
    void setAuditExecutions(const QString &toolId,
                           bool audit,
                           std::function<void(bool)> callback = nullptr) override;
    
    void approveExecution(const QString &executionId,
                         const QString &approverId,
                         const QString &reason = "",
                         std::function<void(bool)> callback = nullptr) override;
    
    void rejectExecution(const QString &executionId,
                        const QString &rejectorId,
                        const QString &reason = "",
                        std::function<void(bool)> callback = nullptr) override;
    
    QVector<QVariantMap> getPendingApprovals(int limit = 100) const override;
    
    QVector<QVariantMap> getApprovalHistory(const QString &toolId,
                                           int limit = 100) const override;
    
    // ── 审计日志 ───────────────────────────────────────
    QVector<QVariantMap> getToolAuditLog(const QString &toolId,
                                        int limit = 100) const override;
    
    QVector<QVariantMap> getUserAuditLog(const QString &userId,
                                        int limit = 100) const override;
    
    QVector<QVariantMap> getPermissionChangeLog(const QString &toolId,
                                               int limit = 100) const override;
    
    QString exportAuditReport(const QDateTime &from,
                             const QDateTime &to) const override;
    
    // ── 统计 ───────────────────────────────────────────
    QVariantMap getPermissionStatistics() const override;
    
    QVariantMap getToolAccessStats(const QString &toolId) const override;
    
    QVariantMap getUserPermissionSummary(const QString &userId) const override;

private:
    struct PermissionEntry {
        ToolPermission permission;
        QVector<QString> allowedUsers;
        QVector<QString> allowedRoles;
        QDateTime createdAt;
        QDateTime modifiedAt;
        QDateTime expiresAt;
    };
    
    struct UserEntry {
        QString userId;
        QString role;
        QDateTime createdAt;
        QVector<QString> assignedTools;
    };
    
    struct AuditEntry {
        QString id;
        QString toolId;
        QString userId;
        QString action;
        QString details;
        QDateTime timestamp;
    };
    
    struct ApprovalEntry {
        QString executionId;
        QString toolId;
        QString userId;
        QString requestedAt;
        QString status;  // Pending, Approved, Rejected
        QString approverId;
        QString approvalReason;
        QDateTime approvalTime;
    };
    
    // 存储
    QMap<QString, PermissionEntry> m_permissions;
    QMap<QString, UserEntry> m_users;
    QList<AuditEntry> m_auditLog;
    QMap<QString, ApprovalEntry> m_approvals;
    QSet<QString> m_adminUsers;
    
    // 统计
    QMap<QString, int> m_toolAccessCount;
    QMap<QString, int> m_userAccessCount;
    
    mutable QMutex m_mutex;
    
    // 辅助方法
    bool checkUserPermission(const QString &toolId,
                            const QString &userId) const;
    
    bool checkRolePermission(const QString &toolId,
                            const QString &userId) const;
    
    bool isPermissionExpired(const QString &toolId) const;
    
    void logAudit(const QString &toolId,
                 const QString &userId,
                 const QString &action,
                 const QString &details = "");
    
    bool requiresApprovalInternal(const QString &toolId) const;
    
    QString generateAuditId();
};

#endif // DEFAULTTOOLPERMISSIONMANAGER_H
