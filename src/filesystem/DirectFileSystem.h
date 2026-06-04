#pragma once

#include "ExecutorFileSystem.h"
#include <QDir>
#include <memory>

class SandboxManager;

/**
 * @file DirectFileSystem.h
 * @brief Qt-based unsandboxed file system implementation
 * 
 * Mirrors Codex's DirectFileSystem with full file access.
 * Performs actual I/O using Qt's QFile, QDir, etc.
 * 
 * Features:
 * - Atomic write operations via temp + rename
 * - Line ending detection and normalization
 * - UTF-8 BOM preservation
 * - File permission copying
 * - Metadata preservation
 * - Comprehensive error handling
 */
class DirectFileSystem : public ExecutorFileSystem {
    Q_OBJECT

public:
    explicit DirectFileSystem(const QString& workspaceRoot, QObject* parent = nullptr);
    ~DirectFileSystem() override;

    // ExecutorFileSystem implementation
    FileSystemResult writeFile(
        const QString& path,
        const QByteArray& contents,
        const WriteFileOptions& options = WriteFileOptions(),
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    FileSystemResult readFile(
        const QString& path,
        QByteArray& outContents,
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    FileSystemResult createDirectory(
        const QString& path,
        const CreateDirectoryOptions& options = CreateDirectoryOptions(),
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    FileSystemResult deleteFile(
        const QString& path,
        bool recursive = false,
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    bool exists(
        const QString& path,
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    QJsonObject getMetadata(
        const QString& path,
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    FileSystemResult writeFileBatch(
        const QList<QPair<QString, QByteArray>>& files,
        const WriteFileOptions& options = WriteFileOptions(),
        const FileSystemSandboxContext* sandbox = nullptr
    ) override;

    // Configuration
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    // Core write implementation (atomic)
    FileSystemResult writeFileAtomic(
        const QString& path,
        const QByteArray& contents,
        const WriteFileOptions& options
    );

    // Metadata operations
    QString detectLineEnding(const QString& path);
    bool detectBOM(const QString& path);
    QString normalizeLineEndings(
        const QString& content,
        const QString& currentEnding,
        const QString& targetEnding
    );
    bool copyFilePermissions(const QString& from, const QString& to);
    QByteArray readExistingContent(const QString& path);

    // Path safety
    QString safePath(const QString& path) const;
    bool isValidPath(const QString& path) const;
    bool isSensitivePath(const QString& path) const;

    // Utility
    QJsonObject collectMetadata(const QString& path);
    QString getFileExtension(const QString& path) const;

    QDir m_workspaceRoot;
    SandboxManager* m_sandboxManager{nullptr};
    QSet<QString> m_protectedPaths;

    static constexpr const char* TEMP_FILE_SUFFIX = ".neurx-tmp";
    static constexpr int MAX_FILE_SIZE = 50 * 1024 * 1024;  // 50MB
};

using DirectFileSystemPtr = std::shared_ptr<DirectFileSystem>;
