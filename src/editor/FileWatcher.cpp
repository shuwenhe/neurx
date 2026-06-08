#include "FileWatcher.h"
#include <QFileInfo>
#include <QDir>
#include <QDebug>

FileWatcher::FileWatcher(QObject *parent)
    : QObject(parent),
      m_watcher(new QFileSystemWatcher(this))
{
    // Setup debounce timer
    m_debounceTimer.setInterval(m_debounceInterval);
    m_debounceTimer.setSingleShot(true);
    connect(&m_debounceTimer, &QTimer::timeout, this, &FileWatcher::onDebounceTimeout);

    // Connect filesystem watcher signals
    connect(m_watcher, QOverload<const QString &>::of(&QFileSystemWatcher::fileChanged),
            this, &FileWatcher::onFileChanged);
    connect(m_watcher, QOverload<const QString &>::of(&QFileSystemWatcher::directoryChanged),
            this, &FileWatcher::onDirectoryChanged);
}

FileWatcher::~FileWatcher()
{
    clear();
}

void FileWatcher::watchFile(const QString &filePath)
{
    if (filePath.isEmpty()) {
        emit watchError("Empty file path provided");
        return;
    }

    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        qWarning() << "FileWatcher: File does not exist:" << filePath;
        emit watchError(QString("File does not exist: %1").arg(filePath));
        return;
    }

    if (m_watchedFiles.contains(filePath)) {
        return;  // Already watching
    }

    try {
        m_watcher->addPath(filePath);
        m_watchedFiles.insert(filePath);
        m_lastModTimes[filePath] = getFileModTime(filePath);
        qDebug() << "[FileWatcher] Now watching file:" << filePath;
    } catch (const std::exception &e) {
        emit watchError(QString("Failed to watch file %1: %2").arg(filePath, e.what()));
    }
}

void FileWatcher::unwatchFile(const QString &filePath)
{
    if (m_watchedFiles.contains(filePath)) {
        m_watcher->removePath(filePath);
        m_watchedFiles.remove(filePath);
        m_lastModTimes.remove(filePath);
        qDebug() << "[FileWatcher] Stopped watching file:" << filePath;
    }
}

void FileWatcher::watchDirectory(const QString &dirPath, bool recursive)
{
    if (dirPath.isEmpty()) {
        emit watchError("Empty directory path provided");
        return;
    }

    QDir dir(dirPath);
    if (!dir.exists()) {
        emit watchError(QString("Directory does not exist: %1").arg(dirPath));
        return;
    }

    if (m_watchedDirs.contains(dirPath)) {
        return;  // Already watching
    }

    try {
        m_watcher->addPath(dirPath);
        m_watchedDirs.insert(dirPath);
        qDebug() << "[FileWatcher] Now watching directory:" << dirPath;

        // Recursively watch subdirectories if requested
        if (recursive) {
            const auto subdirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &subdir : subdirs) {
                watchDirectory(dir.filePath(subdir), recursive);
            }
        }
    } catch (const std::exception &e) {
        emit watchError(QString("Failed to watch directory %1: %2").arg(dirPath, e.what()));
    }
}

void FileWatcher::unwatchDirectory(const QString &dirPath)
{
    if (m_watchedDirs.contains(dirPath)) {
        m_watcher->removePath(dirPath);
        m_watchedDirs.remove(dirPath);
        qDebug() << "[FileWatcher] Stopped watching directory:" << dirPath;
    }
}

void FileWatcher::clear()
{
    m_watcher->removePaths(m_watcher->files());
    m_watcher->removePaths(m_watcher->directories());
    m_watchedFiles.clear();
    m_watchedDirs.clear();
    m_lastModTimes.clear();
    m_pendingChanges.clear();
}

QDateTime FileWatcher::getFileModTime(const QString &filePath)
{
    QFileInfo info(filePath);
    return info.lastModified();
}

bool FileWatcher::fileExists(const QString &filePath)
{
    return QFileInfo::exists(filePath);
}

void FileWatcher::onFileChanged(const QString &path)
{
    qDebug() << "[FileWatcher] File changed detected:" << path;
    handleFileChange(path);
}

void FileWatcher::onDirectoryChanged(const QString &path)
{
    qDebug() << "[FileWatcher] Directory changed detected:" << path;
    handleFileChange(path);
}

void FileWatcher::handleFileChange(const QString &path)
{
    // Check if it's a file we're specifically watching
    if (m_watchedFiles.contains(path)) {
        if (!fileExists(path)) {
            // File was deleted
            emit fileDeleted(path);
            m_watchedFiles.remove(path);
            m_lastModTimes.remove(path);
        } else {
            // File was modified
            m_pendingChanges.insert(path);
            m_debounceTimer.stop();
            m_debounceTimer.start();
        }
    }
    // Check if it's a directory we're watching
    else if (m_watchedDirs.contains(path)) {
        m_pendingChanges.insert(path);
        m_debounceTimer.stop();
        m_debounceTimer.start();
    }
}

void FileWatcher::onDebounceTimeout()
{
    // Process all pending changes
    for (const QString &path : m_pendingChanges) {
        if (m_watchedFiles.contains(path)) {
            emit fileModified(path);
        } else if (m_watchedDirs.contains(path)) {
            emit directoryModified(path);
        }
    }
    m_pendingChanges.clear();
}
