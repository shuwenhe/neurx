#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>

/**
 * @class FileSyncTool
 * @brief 文件同步和备份工具
 * 
 * 从 claude-code 适配：
 * - 文件同步（源 -> 目标）
 * - 备份管理（自动生成版本）
 * - 差异检测（只同步变更的文件）
 * - 碎片清理
 */
class FileSyncTool : public BaseTool {
    Q_OBJECT
public:
    explicit FileSyncTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "file_sync"; }
    QString description() const override {
        return "Sync files between locations, manage backups, detect differences, "
               "and clean up file fragments.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct SyncOperation {
        QString type;  // "sync", "backup", "diff", "cleanup"
        QString source;
        QString destination;
        bool recursive;
        bool dryRun;
        bool overwrite;
    };

    SyncOperation parseOperation(const QJsonObject &args);
    
    ToolResult opSync(const QString &callId, const SyncOperation &op);
    ToolResult opBackup(const QString &callId, const SyncOperation &op);
    ToolResult opDiff(const QString &callId, const SyncOperation &op);
    ToolResult opCleanup(const QString &callId, const SyncOperation &op);

    QString safePath(const QString &relPath) const;
    QString createBackupDirectory();

    QString m_workspaceRoot;
};
