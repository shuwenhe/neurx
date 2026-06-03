#pragma once
#include "agent/AgentToolRegistry.h"
#include "sandbox/SandboxManager.h"
#include "tools/CheckpointManager.h"
#include <QDir>
#include <memory>

// ── PatchTool ────────────────────────────────────────────────────────────────
//  Applies unified diffs inside the workspace and keeps local backups for rollback.

class PatchTool : public BaseTool {
    Q_OBJECT
public:
    explicit PatchTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name()        const override { return "patch"; }
    QString description() const override {
        return "Preview and apply unified diffs within the workspace. "
               "Operations: preview_diff, apply_diff, revert_last.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    void setSandboxManager(SandboxManager *manager) { m_sandboxManager = manager; }

private:
    struct BackupEntry {
        QString relPath;
        QString backupPath;
        bool existed{false};
    };

    ToolResult previewDiff(const QString &callId, const QJsonObject &args) const;
    ToolResult applyDiff(const QString &callId, const QJsonObject &args);
    ToolResult revertLast(const QString &callId);

    QString safePath(const QString &relOrAbsPath) const;
    QString backupRoot() const;
    QString lastBackupManifestPath() const;
    bool isGitRepo() const;

    static QString normalizePatchPath(QString rawPath);
    static QStringList parseTouchedPaths(const QString &patchText);

    bool ensureBackup(const QStringList &touchedPaths, QString &backupId, QString &error);
    bool restoreBackup(const QString &manifestPath, QString &error);
    bool runGitApply(const QStringList &args, const QString &patchPath, QString &output) const;
    QString createCheckpoint(const QStringList &touchedPaths) const;
    bool canAccessTouchedPaths(const QStringList &paths, FileSystemAccessMode mode) const;

    QString m_workspaceRoot;
    QString m_lastBackupId;
    std::unique_ptr<CheckpointManager> m_checkpointManager;
    SandboxManager *m_sandboxManager{nullptr};
};
