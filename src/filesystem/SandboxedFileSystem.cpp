#include "filesystem/SandboxedFileSystem.h"
#include "filesystem/DirectFileSystem.h"
#include <QDebug>

SandboxedFileSystem::SandboxedFileSystem(
    DirectFileSystemPtr directFs,
    QObject* parent)
    : ExecutorFileSystem(parent)
    , m_directFs(directFs)
{
}

FileSystemResult SandboxedFileSystem::writeFile(
    const QString& path,
    const QByteArray& contents,
    const WriteFileOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox == nullptr) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "SandboxedFileSystem requires a sandbox context"
        );
    }

    if (!isPathAllowed(path, sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            QString("Path not allowed in sandbox: %1").arg(path)
        );
    }

    if (isPathDenied(path, sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            QString("Path denied in sandbox: %1").arg(path)
        );
    }

    if (!checkPermission("write", sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            "Write permission denied in sandbox"
        );
    }

    return m_directFs->writeFile(path, contents, options);
}

FileSystemResult SandboxedFileSystem::readFile(
    const QString& path,
    QByteArray& outContents,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox == nullptr) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "SandboxedFileSystem requires a sandbox context"
        );
    }

    if (!isPathAllowed(path, sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            QString("Path not allowed in sandbox: %1").arg(path)
        );
    }

    if (!checkPermission("read", sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            "Read permission denied in sandbox"
        );
    }

    return m_directFs->readFile(path, outContents);
}

FileSystemResult SandboxedFileSystem::createDirectory(
    const QString& path,
    const CreateDirectoryOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox == nullptr) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "SandboxedFileSystem requires a sandbox context"
        );
    }

    if (!isPathAllowed(path, sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            QString("Path not allowed in sandbox: %1").arg(path)
        );
    }

    if (!checkPermission("createDirs", sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            "Create directory permission denied in sandbox"
        );
    }

    return m_directFs->createDirectory(path, options);
}

FileSystemResult SandboxedFileSystem::deleteFile(
    const QString& path,
    bool recursive,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox == nullptr) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "SandboxedFileSystem requires a sandbox context"
        );
    }

    if (!isPathAllowed(path, sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            QString("Path not allowed in sandbox: %1").arg(path)
        );
    }

    if (!checkPermission("delete", sandbox)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            "Delete permission denied in sandbox"
        );
    }

    return m_directFs->deleteFile(path, recursive);
}

bool SandboxedFileSystem::exists(
    const QString& path,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox == nullptr) {
        return false;
    }

    if (!isPathAllowed(path, sandbox)) {
        return false;
    }

    return m_directFs->exists(path);
}

QJsonObject SandboxedFileSystem::getMetadata(
    const QString& path,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox == nullptr) {
        QJsonObject err;
        err["error"] = "Sandbox context required";
        return err;
    }

    if (!isPathAllowed(path, sandbox)) {
        QJsonObject err;
        err["error"] = "Path not allowed in sandbox";
        return err;
    }

    return m_directFs->getMetadata(path);
}

FileSystemResult SandboxedFileSystem::writeFileBatch(
    const QList<QPair<QString, QByteArray>>& files,
    const WriteFileOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    for (const auto& pair : files) {
        auto result = writeFile(pair.first, pair.second, options, sandbox);
        if (result.isErr()) {
            return result;
        }
    }

    return FileSystemResult();
}

// Private implementation

bool SandboxedFileSystem::isPathAllowed(
    const QString& path,
    const FileSystemSandboxContext* sandbox) const
{
    if (sandbox == nullptr) {
        return false;
    }

    // Check confined directory
    if (!sandbox->confineDir().isEmpty()) {
        if (!path.startsWith(sandbox->confineDir())) {
            return false;
        }
    }

    // Check allowed paths whitelist
    if (!sandbox->allowedPaths().isEmpty()) {
        bool found = false;
        for (const auto& allowed : sandbox->allowedPaths()) {
            if (path.startsWith(allowed)) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
    }

    return true;
}

bool SandboxedFileSystem::isPathDenied(
    const QString& path,
    const FileSystemSandboxContext* sandbox) const
{
    if (sandbox == nullptr) {
        return false;
    }

    for (const auto& denied : sandbox->deniedPaths()) {
        if (path.startsWith(denied)) {
            return true;
        }
    }

    return false;
}

bool SandboxedFileSystem::isConfinedPath(
    const QString& path,
    const FileSystemSandboxContext* sandbox) const
{
    if (sandbox == nullptr || sandbox->confineDir().isEmpty()) {
        return false;
    }

    return path.startsWith(sandbox->confineDir());
}

bool SandboxedFileSystem::checkPermission(
    const QString& operation,
    const FileSystemSandboxContext* sandbox) const
{
    if (sandbox == nullptr) {
        return false;
    }

    if (operation == "read") {
        return sandbox->canRead();
    } else if (operation == "write") {
        return sandbox->canWrite();
    } else if (operation == "delete") {
        return sandbox->canDelete();
    } else if (operation == "createDirs") {
        return sandbox->canCreateDirs();
    }

    return false;
}
