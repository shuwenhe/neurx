#pragma once

#include "ToolSchemaTypes.h"
#include <QObject>
#include <memory>
#include <functional>

/**
 * @class ToolPermissionManager
 * @brief Claude Code工具权限管理系统
 * 
 * 功能：
 * - 工具权限管理
 * - 访问控制
 * - 审计日志
 * - 权限验证
 */
class ToolPermissionManager : public QObject {
    Q_OBJECT
public:
    explicit ToolPermissionManager(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~ToolPermissionManager() = default;
    
public:
    // ── 权限管理 ───────────────────────────────────────
    
    /// 设置工具权限
    virtual void setToolPermission(const ToolPermission &permission,
                                  std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 获取工具权限
    virtual ToolPermission getToolPermission(const QString &toolId) const = 0;
    
    /// 移除工具权限
    virtual void removeToolPermission(const QString &toolId,
                                     std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 更新权限级别
    virtual void updatePermissionLevel(const QString &toolId,
                                      PermissionLevel level,
                                      std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 设置权限过期时间
    virtual void setPermissionExpiry(const QString &toolId,
                                    const QDateTime &expiresAt,
                                    std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── 用户权限检查 ────────────────────────────────────
    
    /// 检查用户是否可以访问工具
    virtual void checkToolAccess(const QString &toolId,
                                const QString &userId,
                                ToolPermissionCallback callback = nullptr) = 0;
    
    /// 检查用户是否可以执行工具
    virtual void checkExecutionPermission(const QString &toolId,
                                         const QString &userId,
                                         ToolPermissionCallback callback = nullptr) = 0;
    
    /// 检查用户是否可以执行特定能力
    virtual void checkCapabilityPermission(const QString &toolId,
                                          const QString &capabilityName,
                                          const QString &userId,
                                          ToolPermissionCallback callback = nullptr) = 0;
    
    /// 验证执行请求
    virtual void validateExecutionRequest(const ToolExecutionRequest &request,
                                         const QString &userId,
                                         std::function<void(bool success, QString error)> callback = nullptr) = 0;
    
    // ── 角色和用户管理 ──────────────────────────────────
    
    /// 添加允许的用户
    virtual void addAllowedUser(const QString &toolId,
                               const QString &userId,
                               std::function<void(bool)> callback = nullptr) = 0;
    
    /// 移除允许的用户
    virtual void removeAllowedUser(const QString &toolId,
                                  const QString &userId,
                                  std::function<void(bool)> callback = nullptr) = 0;
    
    /// 添加允许的角色
    virtual void addAllowedRole(const QString &toolId,
                               const QString &role,
                               std::function<void(bool)> callback = nullptr) = 0;
    
    /// 移除允许的角色
    virtual void removeAllowedRole(const QString &toolId,
                                  const QString &role,
                                  std::function<void(bool)> callback = nullptr) = 0;
    
    /// 获取工具的允许用户列表
    virtual QStringList getAllowedUsers(const QString &toolId) const = 0;
    
    /// 获取工具的允许角色列表
    virtual QStringList getAllowedRoles(const QString &toolId) const = 0;
    
    // ── 审核和审批 ──────────────────────────────────────
    
    /// 标记工具需要审批
    virtual void setRequiresApproval(const QString &toolId,
                                    bool requiresApproval,
                                    std::function<void(bool)> callback = nullptr) = 0;
    
    /// 标记工具需要认证
    virtual void setRequiresAuthentication(const QString &toolId,
                                          bool requiresAuth,
                                          std::function<void(bool)> callback = nullptr) = 0;
    
    /// 标记工具执行需要审计
    virtual void setAuditExecutions(const QString &toolId,
                                   bool audit,
                                   std::function<void(bool)> callback = nullptr) = 0;
    
    /// 批准执行请求
    virtual void approveExecution(const QString &executionId,
                                 const QString &approverId,
                                 const QString &reason = "",
                                 std::function<void(bool)> callback = nullptr) = 0;
    
    /// 拒绝执行请求
    virtual void rejectExecution(const QString &executionId,
                                const QString &rejectorId,
                                const QString &reason = "",
                                std::function<void(bool)> callback = nullptr) = 0;
    
    /// 获取待审批列表
    virtual QVector<QVariantMap> getPendingApprovals(int limit = 100) const = 0;
    
    // ── 审计日志 ────────────────────────────────────────
    
    /// 获取工具执行审计日志
    virtual QVector<QVariantMap> getToolAuditLog(const QString &toolId,
                                                 int limit = 100) const = 0;
    
    /// 获取用户操作日志
    virtual QVector<QVariantMap> getUserAuditLog(const QString &userId,
                                                 int limit = 100) const = 0;
    
    /// 获取权限变更日志
    virtual QVector<QVariantMap> getPermissionChangeLog(const QString &toolId,
                                                        int limit = 100) const = 0;
    
    /// 导出审计报告
    virtual QString exportAuditReport(const QDateTime &fromDate,
                                     const QDateTime &toDate) const = 0;
    
    // ── 权限统计 ────────────────────────────────────────
    
    /// 获取权限统计信息
    virtual QVariantMap getPermissionStatistics() const = 0;
    
    /// 获取工具访问统计
    virtual QVariantMap getToolAccessStats(const QString &toolId) const = 0;
    
    /// 获取用户权限摘要
    virtual QVariantMap getUserPermissionSummary(const QString &userId) const = 0;

// ── 信号 ──────────────────────────────────────────────
signals:
    /// 权限已更改
    void permissionChanged(const QString &toolId);
    
    /// 执行被批准
    void executionApproved(const QString &executionId);
    
    /// 执行被拒绝
    void executionRejected(const QString &executionId);
    
    /// 访问被拒绝
    void accessDenied(const QString &toolId, const QString &userId, const QString &reason);
    
    /// 权限过期
    void permissionExpired(const QString &toolId);
};
