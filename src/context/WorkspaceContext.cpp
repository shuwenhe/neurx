#include "context/WorkspaceContext.h"
#include <QDir>
#include <QProcess>

WorkspaceContext::WorkspaceContext(QObject *parent) : QObject(parent) {}

void WorkspaceContext::setRootPath(const QString &path)
{
    if (m_rootPath == path) return;
    m_rootPath = path;
    emit rootPathChanged();
    detectGitBranch();
}

void WorkspaceContext::recordFileAccess(const QString &filePath)
{
    m_recentFiles.removeAll(filePath);
    m_recentFiles.prepend(filePath);
    if (m_recentFiles.size() > 20)
        m_recentFiles = m_recentFiles.mid(0, 20);
    emit recentFilesChanged();
}

void WorkspaceContext::detectGitBranch()
{
    if (m_rootPath.isEmpty()) return;

    QProcess proc;
    proc.setWorkingDirectory(m_rootPath);
    proc.start("git", {"rev-parse", "--abbrev-ref", "HEAD"});
    if (proc.waitForFinished(3000)) {
        m_gitBranch = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        emit gitBranchChanged();
    }
}

QString WorkspaceContext::buildContextSummary() const
{
    if (m_rootPath.isEmpty()) return {};
    QString summary = "Workspace: " + m_rootPath;
    if (!m_gitBranch.isEmpty())
        summary += "  (git branch: " + m_gitBranch + ")";
    if (!m_recentFiles.isEmpty())
        summary += "\nRecently accessed: " + m_recentFiles.mid(0, 5).join(", ");
    return summary;
}
