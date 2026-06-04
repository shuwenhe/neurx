#pragma once

#include "ExecutorFileSystem.h"
#include "DirectFileSystem.h"
#include "SandboxedFileSystem.h"
#include <memory>

/**
 * @file LocalFileSystem.h
 * @brief Router between sandboxed and unsandboxed file systems
 * 
 * Inspired by Codex's LocalFileSystem that provides a unified interface
 * for file operations and routes them to either:
 * - DirectFileSystem (unsandboxed)
 * - SandboxedFileSystem (sandboxed)
 * 
 * This is the main entry point for all file system operations in the system.
 */
class LocalFileSystem : public ExecutorFileSystem {
    Q_OBJECT

public:
    /**
     * @brief Create local file system instance
     * @param workspaceRoot Root directory for all operations
     * @param parent Parent QObject
     */
    explicit LocalFileSystem(const QString& workspaceRoot, QObject* parent = nullptr);
    ~LocalFileSystem() override;

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
    DirectFileSystemPtr directFileSystem() const { return m_directFs; }
    SandboxedFileSystemPtr sandboxedFileSystem() const { return m_sandboxedFs; }

    void setSandboxManager(SandboxManager* manager);

private:
    /**
     * @brief Select appropriate file system based on sandbox context
     * @return Tuple of (ExecutorFileSystem*, SandboxContext*)
     */
    std::pair<ExecutorFileSystem*, const FileSystemSandboxContext*>
    fileSystemFor(const FileSystemSandboxContext* sandbox) const;

    DirectFileSystemPtr m_directFs;
    SandboxedFileSystemPtr m_sandboxedFs;
};

using LocalFileSystemPtr = std::shared_ptr<LocalFileSystem>;
