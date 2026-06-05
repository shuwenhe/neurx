#include "WorkspaceService.h"
#include <QDir>
#include <QDirIterator>
#include <QFileSystemWatcher>
#include <QRegularExpression>
#include <QJsonObject>
#include <algorithm>

namespace {

QJsonObject setJsonPathValue(QJsonObject object, const QStringList& parts, const QVariant& value, int index = 0) {
    if (parts.isEmpty() || index >= parts.size()) {
        return object;
    }

    const QString& key = parts[index];
    if (index == parts.size() - 1) {
        object.insert(key, QJsonValue::fromVariant(value));
        return object;
    }

    QJsonObject child = object.value(key).toObject();
    child = setJsonPathValue(child, parts, value, index + 1);
    object.insert(key, child);
    return object;
}

}  // namespace

class WorkspaceService::Impl {
public:
    QList<WorkspaceFolder> folders;
    QStringList exclusionPatterns;
    QJsonObject configuration;
    QFileSystemWatcher watcher;
    int folderCounter = 0;
    
    bool matchesPattern(const QString& path, const QString& pattern) {
        QRegularExpression regex(QRegularExpression::wildcardToRegularExpression(pattern));
        return regex.match(path).hasMatch();
    }
    
    bool isExcludedInternal(const QString& path) {
        for (const auto& pattern : exclusionPatterns) {
            if (matchesPattern(path, pattern)) {
                return true;
            }
        }
        return false;
    }
};

WorkspaceService* WorkspaceService::instance() {
    static WorkspaceService s_instance;
    return &s_instance;
}

WorkspaceService::WorkspaceService()
    : m_impl(std::make_unique<Impl>()) {
    // Default exclusion patterns
    m_impl->exclusionPatterns << "node_modules" << ".git" << ".vscode"
                              << "build" << "dist" << ".o" << ".a";
}

WorkspaceService::~WorkspaceService() = default;

void WorkspaceService::addFolder(const QString& path) {
    QDir dir(path);
    if (!dir.exists()) {
        return;
    }
    
    // Check if already exists
    for (const auto& folder : m_impl->folders) {
        if (folder.path == path) {
            return;
        }
    }
    
    WorkspaceFolder folder;
    folder.path = dir.absolutePath();
    folder.name = dir.dirName();
    folder.index = m_impl->folderCounter++;
    
    m_impl->folders.append(folder);
    m_impl->watcher.addPath(folder.path);
    
    emit folderAdded(folder);
}

void WorkspaceService::removeFolder(const QString& path) {
    for (int i = 0; i < m_impl->folders.size(); ++i) {
        if (m_impl->folders[i].path == path) {
            auto folder = m_impl->folders[i];
            m_impl->folders.removeAt(i);
            m_impl->watcher.removePath(path);
            emit folderRemoved(folder);
            return;
        }
    }
}

void WorkspaceService::removeAll() {
    auto folders = m_impl->folders;
    m_impl->folders.clear();
    for (const auto& folder : folders) {
        m_impl->watcher.removePath(folder.path);
        emit folderRemoved(folder);
    }
}

QList<WorkspaceFolder> WorkspaceService::getFolders() const {
    return m_impl->folders;
}

WorkspaceFolder WorkspaceService::getRootFolder() const {
    if (m_impl->folders.isEmpty()) {
        return WorkspaceFolder();
    }
    return m_impl->folders.first();
}

QString WorkspaceService::getWorkspaceName() const {
    if (m_impl->folders.isEmpty()) {
        return QString();
    }
    
    if (m_impl->folders.size() == 1) {
        return m_impl->folders.first().name;
    }
    
    return "Multi-folder Workspace";
}

int WorkspaceService::getFolderCount() const {
    return m_impl->folders.size();
}

QStringList WorkspaceService::findFiles(const QString& pattern, int maxResults) {
    QStringList results;
    int count = 0;
    
    for (const auto& folder : m_impl->folders) {
        QDir dir(folder.path);
        
        QDirIterator it(folder.path,
                       QStringList(pattern),
                       QDir::Files,
                       QDirIterator::Subdirectories);
        
        while (it.hasNext() && count < maxResults) {
            QString filePath = it.next();
            
            if (!m_impl->isExcludedInternal(filePath)) {
                results.append(filePath);
                count++;
            }
        }
    }
    
    return results;
}

QString WorkspaceService::getRelativePath(const QString& absolutePath) {
    for (const auto& folder : m_impl->folders) {
        if (absolutePath.startsWith(folder.path)) {
            return absolutePath.mid(folder.path.length() + 1);
        }
    }
    return absolutePath;
}

QString WorkspaceService::getAbsolutePath(const QString& relativePath) {
    if (m_impl->folders.isEmpty()) {
        return relativePath;
    }
    
    return m_impl->folders.first().path + "/" + relativePath;
}

void WorkspaceService::addExclusionPattern(const QString& pattern) {
    if (!m_impl->exclusionPatterns.contains(pattern)) {
        m_impl->exclusionPatterns.append(pattern);
    }
}

void WorkspaceService::removeExclusionPattern(const QString& pattern) {
    m_impl->exclusionPatterns.removeAll(pattern);
}

QStringList WorkspaceService::getExclusionPatterns() const {
    return m_impl->exclusionPatterns;
}

bool WorkspaceService::isExcluded(const QString& path) const {
    return m_impl->isExcludedInternal(path);
}

QVariantMap WorkspaceService::getConfiguration(const QString& section) {
    if (section.isEmpty()) {
        return m_impl->configuration.toVariantMap();
    }
    
    return m_impl->configuration.value(section).toObject().toVariantMap();
}

void WorkspaceService::setConfiguration(const QString& key, const QVariant& value) {
    auto parts = key.split('.');
    if (parts.isEmpty()) {
        return;
    }

    m_impl->configuration = setJsonPathValue(m_impl->configuration, parts, value);
    emit configurationChanged();
}

void WorkspaceService::watchPath(const QString& path) {
    if (!m_impl->watcher.directories().contains(path) &&
        !m_impl->watcher.files().contains(path)) {
        m_impl->watcher.addPath(path);
    }
}

void WorkspaceService::unwatchPath(const QString& path) {
    if (m_impl->watcher.directories().contains(path) ||
        m_impl->watcher.files().contains(path)) {
        m_impl->watcher.removePath(path);
    }
}

bool WorkspaceService::isPathWatched(const QString& path) const {
    return m_impl->watcher.directories().contains(path) ||
           m_impl->watcher.files().contains(path);
}
