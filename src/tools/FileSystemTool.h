#pragma once
#include "agent/AgentToolRegistry.h"
#include "sandbox/SandboxManager.h"
#include "tools/CheckpointManager.h"
#include <QDir>
#include <memory>

// ── FileSystemTool ────────────────────────────────────────────────────────────
//  Provides read_file, write_file, list_directory, create_file, delete_file.
//  Operations are sandboxed to the configured workspace root.

class FileSystemTool : public BaseTool {
    Q_OBJECT
public:
    explicit FileSystemTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name()        const override { return "file_system"; }
    QString description() const override {
        return "Read, write, list, and manage files within the workspace. "
               "Operations: read_file, write_file, list_directory, create_file, "
               "delete_file, move_file.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    void setSandboxManager(SandboxManager *manager) { m_sandboxManager = manager; }

private:
    bool isWriteOperation(const QString &operation) const;
    ToolResult opReadFile(const QString &callId, const QJsonObject &args);
    ToolResult opWriteFile(const QString &callId, const QJsonObject &args);
    ToolResult opListDir(const QString &callId, const QJsonObject &args);
    ToolResult opCreateFile(const QString &callId, const QJsonObject &args);
    ToolResult opDeleteFile(const QString &callId, const QJsonObject &args);
    ToolResult opMoveFile(const QString &callId, const QJsonObject &args);

    // Resolve a user-supplied path against workspaceRoot; returns empty on traversal attack.
    QString safePath(const QString &relOrAbsPath) const;
    QString workspaceRelativePath(const QString &relOrAbsPath) const;
    QString checkpointPaths(const QStringList &paths, const QString &description) const;

    QDir m_root;
    std::unique_ptr<CheckpointManager> m_checkpointManager;
    SandboxManager *m_sandboxManager{nullptr};
};
