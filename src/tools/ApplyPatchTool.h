#pragma once

#include "agent/AgentToolRegistry.h"
#include "sandbox/SandboxManager.h"
#include "tools/CheckpointManager.h"

#include <QDir>
#include <memory>

class ApplyPatchTool : public BaseTool {
    Q_OBJECT
public:
    explicit ApplyPatchTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "apply_patch"; }
    QString description() const override {
        return "Apply Codex-style patches inside the workspace using the "
               "*** Begin Patch / *** End Patch format. Supports add, update, "
               "delete, and move operations.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

    void setSandboxManager(SandboxManager *manager) { m_sandboxManager = manager; }

private:
    struct BackupEntry {
        QString relPath;
        QString backupPath;
        bool existed{false};
    };

    QString safePath(const QString &relPath) const;
    QString backupRoot() const;
    QString lastBackupManifestPath() const;
    bool ensureBackup(const QStringList &touchedPaths, QString &backupId, QString &error);
    bool restoreBackup(const QString &manifestPath, QString &error);
    QString createCheckpoint(const QStringList &touchedPaths) const;
    bool canAccessTouchedPaths(const QStringList &paths) const;

    QString m_workspaceRoot;
    std::unique_ptr<CheckpointManager> m_checkpointManager;
    SandboxManager *m_sandboxManager{nullptr};
};
