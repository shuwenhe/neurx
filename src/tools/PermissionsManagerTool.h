#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QFile>
#include <QJsonObject>

/**
 * @class PermissionsManagerTool
 * @brief 权限管理工具 - 修改文件/目录权限、所有者等
 * 
 * 从 claude-code 适配：
 * - chmod: 修改文件权限
 * - chown: 修改文件所有者
 * - 权限检查
 * - 递归权限修改
 */
class PermissionsManagerTool : public BaseTool {
    Q_OBJECT
public:
    explicit PermissionsManagerTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "permissions"; }
    QString description() const override {
        return "Manage file permissions: chmod, chown, check permissions, "
               "and recursive permission changes.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct PermissionOp {
        QString type;  // "chmod", "chown", "check", "make_readonly", "make_writable"
        QString path;
        QString mode;   // for chmod
        QString owner;  // for chown
        bool recursive;
    };

    PermissionOp parseOp(const QJsonObject &args);
    
    ToolResult opChmod(const QString &callId, const PermissionOp &op);
    ToolResult opChown(const QString &callId, const PermissionOp &op);
    ToolResult opCheck(const QString &callId, const PermissionOp &op);
    ToolResult opMakeReadOnly(const QString &callId, const PermissionOp &op);
    ToolResult opMakeWritable(const QString &callId, const PermissionOp &op);

    QString safePath(const QString &relPath) const;
    QString permissionsToString(const QFile::Permissions &perms);

    QString m_workspaceRoot;
};
