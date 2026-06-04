#include "filesystem/LocalFileSystem.h"
#include "sandbox/SandboxManager.h"
#include <QDebug>

LocalFileSystem::LocalFileSystem(const QString& workspaceRoot, QObject* parent)
    : ExecutorFileSystem(parent)
{
    // Create direct file system
    m_directFs = std::make_shared<DirectFileSystem>(workspaceRoot, parent);

    // Create sandboxed wrapper
    m_sandboxedFs = std::make_shared<SandboxedFileSystem>(m_directFs, parent);

    // Connect signals
    connect(m_directFs.get(), &ExecutorFileSystem::fileWritten,
            this, &ExecutorFileSystem::fileWritten);
    connect(m_directFs.get(), &ExecutorFileSystem::error,
            this, &ExecutorFileSystem::error);
    connect(m_sandboxedFs.get(), &ExecutorFileSystem::fileWritten,
            this, &ExecutorFileSystem::fileWritten);
    connect(m_sandboxedFs.get(), &ExecutorFileSystem::error,
            this, &ExecutorFileSystem::error);
}

LocalFileSystem::~LocalFileSystem() = default;

FileSystemResult LocalFileSystem::writeFile(
    const QString& path,
    const QByteArray& contents,
    const WriteFileOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->writeFile(path, contents, options, ctx);
}

FileSystemResult LocalFileSystem::readFile(
    const QString& path,
    QByteArray& outContents,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->readFile(path, outContents, ctx);
}

FileSystemResult LocalFileSystem::createDirectory(
    const QString& path,
    const CreateDirectoryOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->createDirectory(path, options, ctx);
}

FileSystemResult LocalFileSystem::deleteFile(
    const QString& path,
    bool recursive,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->deleteFile(path, recursive, ctx);
}

bool LocalFileSystem::exists(
    const QString& path,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->exists(path, ctx);
}

QJsonObject LocalFileSystem::getMetadata(
    const QString& path,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->getMetadata(path, ctx);
}

FileSystemResult LocalFileSystem::writeFileBatch(
    const QList<QPair<QString, QByteArray>>& files,
    const WriteFileOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    auto [fs, ctx] = fileSystemFor(sandbox);
    return fs->writeFileBatch(files, options, ctx);
}

void LocalFileSystem::setSandboxManager(SandboxManager* manager)
{
    if (m_directFs) {
        m_directFs->setSandboxManager(manager);
    }
}

std::pair<ExecutorFileSystem*, const FileSystemSandboxContext*>
LocalFileSystem::fileSystemFor(const FileSystemSandboxContext* sandbox) const
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return {m_sandboxedFs.get(), sandbox};
    } else {
        return {m_directFs.get(), nullptr};
    }
}
