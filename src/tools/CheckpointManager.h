#pragma once
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantMap>

// ── CheckpointManager ────────────────────────────────────────────────────────
//  Transparent filesystem snapshots via a shadow git repository.
//  NOT a BaseTool — the LLM never sees this directly. It is called by
//  FileSystemTool (write_file, create_file, delete_file, move_file) and
//  PatchTool (apply_diff) before any mutating operation.
//
//  Shadow repo lives at: <workspaceRoot>/.neurx/checkpoints/
//  Uses GIT_DIR + GIT_WORK_TREE so no .git state leaks into the user's project.
//
//  Usage:
//    1. Call checkpoint(filePaths) before a write; returns an opaque ID string.
//    2. Call rollback(id) to restore all files that were snapshotted under id.
//    3. Call listCheckpoints() to enumerate saved snapshots.

class CheckpointManager {
public:
    explicit CheckpointManager(const QString &workspaceRoot);

    // Snapshot the given workspace-relative paths.  Creates a git commit in the
    // shadow repo and returns a short hex ID, or empty string on failure.
    QString checkpoint(const QStringList &relPaths, const QString &description = {});

    // Restore all files captured under the given checkpoint ID.
    // Returns true on success; fills error on failure.
    bool rollback(const QString &checkpointId, QString &error);

    // Returns a list of { id, description, timestamp } maps, newest first.
    QList<QVariantMap> listCheckpoints() const;
    QStringList filesForCheckpoint(const QString &checkpointId, QString *error = nullptr) const;

    bool isAvailable() const;   // returns false if git is not installed

private:
    bool ensureRepo();
    bool gitRun(const QStringList &args, QString *output = nullptr) const;

    QString m_workspaceRoot;
    QString m_gitDir;     // .neurx/checkpoints/git
    bool    m_repoReady{false};
};
