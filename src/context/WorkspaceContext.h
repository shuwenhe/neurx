#pragma once
#include <QObject>
#include <QString>
#include <QStringList>

// ── WorkspaceContext ──────────────────────────────────────────────────────────
//  Manages the open workspace: path, git status, recent files.
//  The index layer is handled by WorkspaceIndex.

class WorkspaceContext : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString      rootPath    READ rootPath    WRITE setRootPath    NOTIFY rootPathChanged)
    Q_PROPERTY(QStringList  recentFiles READ recentFiles NOTIFY recentFilesChanged)
    Q_PROPERTY(QString      gitBranch   READ gitBranch   NOTIFY gitBranchChanged)

public:
    explicit WorkspaceContext(QObject *parent = nullptr);

    QString     rootPath()    const { return m_rootPath; }
    QStringList recentFiles() const { return m_recentFiles; }
    QString     gitBranch()   const { return m_gitBranch; }

    void setRootPath(const QString &path);
    void recordFileAccess(const QString &filePath);

    // Build a concise workspace summary for injection into the system prompt.
    QString buildContextSummary() const;

signals:
    void rootPathChanged();
    void recentFilesChanged();
    void gitBranchChanged();

private:
    void detectGitBranch();

    QString     m_rootPath;
    QStringList m_recentFiles;
    QString     m_gitBranch;
};
