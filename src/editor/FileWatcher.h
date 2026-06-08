#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QString>
#include <QSet>
#include <QHash>
#include <QDateTime>

/**
 * @class FileWatcher
 * @brief Monitors file system changes and notifies when files are modified externally
 *
 * This class watches files for external modifications and emits signals when:
 * - A file is modified on disk
 * - A file is deleted
 * - A file is renamed
 *
 * Usage:
 *   FileWatcher watcher;
 *   connect(&watcher, &FileWatcher::fileModified, this, &MyClass::onFileModified);
 *   watcher.watchFile("/path/to/file.cpp");
 */
class FileWatcher : public QObject {
    Q_OBJECT

public:
    explicit FileWatcher(QObject *parent = nullptr);
    ~FileWatcher();

    // Add a file to watch
    void watchFile(const QString &filePath);

    // Remove a file from watching
    void unwatchFile(const QString &filePath);

    // Watch all files in a directory recursively
    void watchDirectory(const QString &dirPath, bool recursive = true);

    // Unwatch a directory
    void unwatchDirectory(const QString &dirPath);

    // Clear all watched files and directories
    void clear();

    // Get list of currently watched files
    QStringList watchedFiles() const { return m_watchedFiles.toList(); }

    // Get list of currently watched directories
    QStringList watchedDirectories() const { return m_watchedDirs.toList(); }

    // Check if a file is being watched
    bool isWatching(const QString &filePath) const { return m_watchedFiles.contains(filePath); }

signals:
    // Emitted when a watched file is modified
    void fileModified(const QString &filePath);

    // Emitted when a watched file is deleted
    void fileDeleted(const QString &filePath);

    // Emitted when a watched file is renamed
    void fileRenamed(const QString &oldPath, const QString &newPath);

    // Emitted when a directory is modified
    void directoryModified(const QString &dirPath);

    // Emitted when watch error occurs
    void watchError(const QString &message);

private slots:
    // Called when QFileSystemWatcher detects file change
    void onFileChanged(const QString &path);

    // Called when QFileSystemWatcher detects directory change
    void onDirectoryChanged(const QString &path);

    // Debounce timer to prevent multiple rapid signals
    void onDebounceTimeout();

private:
    // Helper to get file modification time
    QDateTime getFileModTime(const QString &filePath);

    // Helper to check if file exists
    bool fileExists(const QString &filePath);

    // Helper to handle file changes with debouncing
    void handleFileChange(const QString &path);

    QFileSystemWatcher *m_watcher;
    QSet<QString> m_watchedFiles;      // Set of watched file paths
    QSet<QString> m_watchedDirs;       // Set of watched directory paths
    QHash<QString, QDateTime> m_lastModTimes;  // Track last modification times

    // Debounce timer and pending changes
    QTimer m_debounceTimer;
    QSet<QString> m_pendingChanges;
    int m_debounceInterval{500};  // milliseconds
};
