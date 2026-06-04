#pragma once

#include "ExecutorFileSystem.h"
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>

/**
 * @file SandboxedFileSystem.h
 * @brief Sandboxed file system wrapper with access restrictions
 * 
 * Wraps DirectFileSystem and enforces access controls based on
 * FileSystemSandboxContext. Inspired by Codex's SandboxedFileSystem.
 * 
 * Features:
 * - Path whitelisting/blacklisting
 * - Directory confinement
 * - Permission enforcement
 * - Access logging
 * - Sandbox context validation
 */

class FileSystemSandboxContext {
public:
    explicit FileSystemSandboxContext(const QString& workspaceId = "")
        : m_workspaceId(workspaceId) {}

    // Access control
    const QStringList& allowedPaths() const { return m_allowedPaths; }
    const QStringList& deniedPaths() const { return m_deniedPaths; }
    const QString& confineDir() const { return m_confineDir; }

    void addAllowedPath(const QString& path) { m_allowedPaths.append(path); }
    void addDeniedPath(const QString& path) { m_deniedPaths.append(path); }
    void setConfineDir(const QString& dir) { m_confineDir = dir; }

    // Permissions
    bool canRead() const { return m_canRead; }
    bool canWrite() const { return m_canWrite; }
    bool canDelete() const { return m_canDelete; }
    bool canCreateDirs() const { return m_canCreateDirs; }

    void setCanRead(bool v) { m_canRead = v; }
    void setCanWrite(bool v) { m_canWrite = v; }
    void setCanDelete(bool v) { m_canDelete = v; }
    void setCanCreateDirs(bool v) { m_canCreateDirs = v; }

    // Utility
    QString workspaceId() const { return m_workspaceId; }
    bool shouldRunInSandbox() const { 
        return !m_confineDir.isEmpty() || !m_allowedPaths.isEmpty() || !m_deniedPaths.isEmpty();
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["workspaceId"] = m_workspaceId;
        obj["confineDir"] = m_confineDir;
        obj["canRead"] = m_canRead;
        obj["canWrite"] = m_canWrite;
        obj["canDelete"] = m_canDelete;
        obj["canCreateDirs"] = m_canCreateDirs;
        
        QJsonArray allowed;
        for (const auto& path : m_allowedPaths) {
            allowed.append(path);
        }
        obj["allowedPaths"] = allowed;
        
        QJsonArray denied;
        for (const auto& path : m_deniedPaths) {
            denied.append(path);
        }
        obj["deniedPaths"] = denied;
        
        return obj;
    }

private:
    QString m_workspaceId;
    QStringList m_allowedPaths;
    QStringList m_deniedPaths;
    QString m_confineDir;
    
    bool m_canRead{true};
    bool m_canWrite{true};
    bool m_canDelete{true};
    bool m_canCreateDirs{true};
};

/**
 * @class SandboxedFileSystem
 * @brief Wraps DirectFileSystem with access control
 */

class DirectFileSystem;  // Forward declaration

class SandboxedFileSystem : public ExecutorFileSystem {
    Q_OBJECT

public:
    explicit SandboxedFileSystem(
        std::shared_ptr<DirectFileSystem> directFs,
        QObject* parent = nullptr
    );

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

private:
    // Access control validation
    bool isPathAllowed(const QString& path, const FileSystemSandboxContext* sandbox) const;
    bool isPathDenied(const QString& path, const FileSystemSandboxContext* sandbox) const;
    bool isConfinedPath(const QString& path, const FileSystemSandboxContext* sandbox) const;

    // Permission checks
    bool checkPermission(
        const QString& operation,
        const FileSystemSandboxContext* sandbox
    ) const;

    std::shared_ptr<DirectFileSystem> m_directFs;
};

using SandboxedFileSystemPtr = std::shared_ptr<SandboxedFileSystem>;
