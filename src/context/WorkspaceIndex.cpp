#include "context/WorkspaceIndex.h"

#include <QDirIterator>
#include <QFileInfo>
#include <algorithm>

WorkspaceIndex::WorkspaceIndex(QObject *parent) : QObject(parent) {}

void WorkspaceIndex::setRootPath(const QString &path)
{
    if (m_rootPath == path) return;
    m_rootPath = path;
    m_recentFiles.clear();
    emit rootPathChanged();
    refresh();
}

void WorkspaceIndex::refresh()
{
    m_fileCount = 0;
    m_extensionCounts.clear();
    m_topExtensions.clear();
    m_filePaths.clear();

    if (m_rootPath.isEmpty()) {
        emit indexChanged();
        return;
    }

    QDirIterator it(m_rootPath,
                    QDir::Files | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);

    while (it.hasNext()) {
        const QString filePath = it.next();
        if (shouldSkipPath(filePath))
            continue;
        ++m_fileCount;
        m_filePaths.append(filePath);
        const QString ext = normalizeExtension(filePath);
        m_extensionCounts[ext] += 1;
    }

    QList<QPair<QString, int>> counts;
    counts.reserve(m_extensionCounts.size());
    for (auto it = m_extensionCounts.cbegin(); it != m_extensionCounts.cend(); ++it)
        counts.append({it.key(), it.value()});

    std::sort(counts.begin(), counts.end(), [](const auto &a, const auto &b) {
        if (a.second != b.second) return a.second > b.second;
        return a.first < b.first;
    });

    for (const auto &item : counts) {
        const QString label = item.first.isEmpty() ? "[no extension]" : item.first;
        m_topExtensions << QString("%1 (%2)").arg(label).arg(item.second);
        if (m_topExtensions.size() >= 8)
            break;
    }

    emit indexChanged();
}

QStringList WorkspaceIndex::searchPaths(const QString &needle) const
{
    const QString query = needle.trimmed().toLower();
    if (query.isEmpty() || m_filePaths.isEmpty())
        return {};

    QStringList matches;
    for (const auto &path : m_filePaths) {
        const QFileInfo info(path);
        const QString fileName = info.fileName().toLower();
        const QString fullPath = path.toLower();
        if (fileName.contains(query) || fullPath.contains(query))
            matches.append(path);
    }
    return matches;
}

void WorkspaceIndex::recordFileAccess(const QString &filePath)
{
    m_recentFiles.removeAll(filePath);
    m_recentFiles.prepend(filePath);
    if (m_recentFiles.size() > 20)
        m_recentFiles = m_recentFiles.mid(0, 20);
    emit indexChanged();
}

QString WorkspaceIndex::buildContextSummary() const
{
    if (m_rootPath.isEmpty()) return {};

    QString summary = QString("Indexed workspace: %1").arg(m_rootPath);
    summary += QString("\nFiles indexed: %1").arg(m_fileCount);

    if (!m_topExtensions.isEmpty())
        summary += "\nTop extensions: " + m_topExtensions.mid(0, 5).join(", ");

    if (!m_recentFiles.isEmpty())
        summary += "\nRecently accessed: " + m_recentFiles.mid(0, 5).join(", ");

    return summary;
}

bool WorkspaceIndex::shouldSkipPath(const QString &path)
{
    static const QStringList kSkipParts = {
        "/.git/",
        "/build/",
        "/node_modules/",
        "/.cache/",
        "/cmake-build-"
    };
    for (const auto &part : kSkipParts) {
        if (path.contains(part))
            return true;
    }
    return false;
}

QString WorkspaceIndex::normalizeExtension(const QString &filePath)
{
    const QString suffix = QFileInfo(filePath).suffix().toLower();
    return suffix.isEmpty() ? QString{} : "." + suffix;
}
