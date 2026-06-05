#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QByteArray>

/**
 * @class FileService
 * @brief File operations - VS Code FileService equivalent
 * 
 * Features:
 * - File read/write
 * - File watching
 * - Encoding detection
 * - Atomic file operations
 * - Recent files tracking
 */

struct FileInfo {
    QString path;
    QString name;
    QString extension;
    qint64 size = 0;
    qint64 modified = 0;
    bool isDirectory = false;
    bool isSymlink = false;
    QString encoding;
};

class FileService : public QObject {
    Q_OBJECT

public:
    static FileService* instance();
    
    // File operations
    bool exists(const QString& path) const;
    FileInfo getFileInfo(const QString& path) const;
    
    // File content
    QByteArray readFile(const QString& path);
    bool writeFile(const QString& path, const QByteArray& content);
    bool deleteFile(const QString& path);
    bool moveFile(const QString& source, const QString& destination);
    bool copyFile(const QString& source, const QString& destination);
    
    // Directory operations
    bool createDirectory(const QString& path);
    QList<FileInfo> listDirectory(const QString& path, bool recursive = false);
    QStringList findFiles(const QString& directory, const QString& pattern);
    
    // Encoding
    QString detectEncoding(const QString& path);
    QString readFileAsText(const QString& path, const QString& encoding = "UTF-8");
    bool writeFileAsText(const QString& path, const QString& content,
                        const QString& encoding = "UTF-8");
    
    // Watching
    void watchFile(const QString& path);
    void unwatchFile(const QString& path);
    bool isWatching(const QString& path) const;
    
    // Recent files
    QStringList getRecentFiles(int maxCount = 20);
    void addRecentFile(const QString& path);
    void clearRecentFiles();
    
    // Statistics
    qint64 getFileSize(const QString& path) const;
    QString getFileExtension(const QString& path) const;
    QString getFileName(const QString& path) const;

signals:
    void fileChanged(const QString& path);
    void fileCreated(const QString& path);
    void fileDeleted(const QString& path);
    void directoryChanged(const QString& path);
    void fileWatched(const QString& path);
    void fileUnwatched(const QString& path);

private:
    FileService();
    ~FileService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
