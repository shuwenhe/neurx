#include "tools/CheckpointManager.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QVariantMap>

// ── ctor ─────────────────────────────────────────────────────────────────────
CheckpointManager::CheckpointManager(const QString &workspaceRoot)
    : m_workspaceRoot(workspaceRoot)
    , m_gitDir(workspaceRoot + QStringLiteral("/.neurx/checkpoints/git"))
{
    ensureRepo();
}

// ── ensureRepo ────────────────────────────────────────────────────────────────
bool CheckpointManager::ensureRepo()
{
    if (m_repoReady) return true;
    QDir d;
    if (!d.mkpath(m_gitDir)) return false;

    // Check if already initialised.
    if (QDir(m_gitDir + "/objects").exists()) {
        m_repoReady = true;
        return true;
    }

    // git init --bare <gitDir>
    if (!gitRun({"init", "--bare", m_gitDir})) return false;

    // Write the NEURX_WORKDIR breadcrumb.
    QFile f(m_gitDir + "/NEURX_WORKDIR");
    if (f.open(QIODevice::WriteOnly | QIODevice::Text))
        f.write(m_workspaceRoot.toUtf8());

    m_repoReady = true;
    return true;
}

// ── checkpoint ────────────────────────────────────────────────────────────────
QString CheckpointManager::checkpoint(const QStringList &relPaths,
                                       const QString &description)
{
    if (!m_repoReady && !ensureRepo()) return {};
    if (relPaths.isEmpty()) return {};

    // Stage the requested files.
    for (const QString &rel : relPaths) {
        const QString abs = m_workspaceRoot + "/" + rel;
        if (!QFile::exists(abs)) continue;
        if (!gitRun({"--git-dir=" + m_gitDir,
                     "--work-tree=" + m_workspaceRoot,
                     "add", "--force", abs}))
            return {};
    }

    const QString msg = description.isEmpty()
        ? QStringLiteral("checkpoint %1").arg(
              QDateTime::currentDateTimeUtc().toString(Qt::ISODate))
        : description;

    QString output;
    if (!gitRun({"--git-dir=" + m_gitDir,
                 "--work-tree=" + m_workspaceRoot,
                 "-c", "user.name=neurx",
                 "-c", "user.email=neurx@local",
                 "commit", "--allow-empty", "-m", msg},
                &output))
        return {};

    // Extract the short commit hash.
    QString hash;
    if (!gitRun({"--git-dir=" + m_gitDir, "rev-parse", "--short", "HEAD"}, &hash))
        return {};
    return hash.trimmed();
}

// ── rollback ─────────────────────────────────────────────────────────────────
bool CheckpointManager::rollback(const QString &checkpointId, QString &error)
{
    if (!m_repoReady) { error = "Checkpoint repo not available."; return false; }

    // List files in that commit and restore each one.
    QString fileList;
    if (!gitRun({"--git-dir=" + m_gitDir,
                 "diff-tree", "--no-commit-id", "-r", "--name-only", checkpointId},
                &fileList)) {
        error = "Could not list files for checkpoint " + checkpointId;
        return false;
    }

    for (const QString &rel : fileList.split('\n', Qt::SkipEmptyParts)) {
        if (!gitRun({"--git-dir=" + m_gitDir,
                     "--work-tree=" + m_workspaceRoot,
                     "checkout", checkpointId, "--", rel})) {
            error = "Failed to restore: " + rel;
            return false;
        }
    }
    return true;
}

// ── listCheckpoints ───────────────────────────────────────────────────────────
QList<QVariantMap> CheckpointManager::listCheckpoints() const
{
    QList<QVariantMap> result;
    QString log;
    if (!const_cast<CheckpointManager *>(this)->gitRun(
            {"--git-dir=" + m_gitDir,
             "log", "--format=%h|%ai|%s", "--max-count=50"},
            &log))
        return result;

    for (const QString &line : log.split('\n', Qt::SkipEmptyParts)) {
        const QStringList parts = line.split('|');
        if (parts.size() < 3) continue;
        result.append(QVariantMap{
            {"id",          parts[0].trimmed()},
            {"timestamp",   parts[1].trimmed()},
            {"description", parts.mid(2).join('|').trimmed()},
        });
    }
    return result;
}

QStringList CheckpointManager::filesForCheckpoint(const QString &checkpointId, QString *error) const
{
    QString output;
    if (!const_cast<CheckpointManager *>(this)->gitRun(
            {"--git-dir=" + m_gitDir,
             "diff-tree", "--no-commit-id", "-r", "--name-only", checkpointId},
            &output)) {
        if (error)
            *error = "Could not list files for checkpoint " + checkpointId;
        return {};
    }

    return output.split('\n', Qt::SkipEmptyParts);
}

// ── isAvailable ──────────────────────────────────────────────────────────────
bool CheckpointManager::isAvailable() const
{
    QProcess p;
    p.start("git", {"--version"});
    return p.waitForFinished(3000) && p.exitCode() == 0;
}

// ── gitRun ───────────────────────────────────────────────────────────────────
bool CheckpointManager::gitRun(const QStringList &args, QString *output) const
{
    QProcess p;
    p.setWorkingDirectory(m_workspaceRoot);
    p.start("git", args);
    if (!p.waitForFinished(15000)) return false;
    if (output)
        *output = QString::fromUtf8(p.readAllStandardOutput());
    return p.exitCode() == 0;
}
