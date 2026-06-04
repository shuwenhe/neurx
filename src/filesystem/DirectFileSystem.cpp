#include "filesystem/DirectFileSystem.h"
#include "filesystem/SandboxedFileSystem.h"
#include "sandbox/SandboxManager.h"
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QDir>
#include <QDateTime>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonArray>
#include <QProcess>
#include <QDebug>

DirectFileSystem::DirectFileSystem(const QString& workspaceRoot, QObject* parent)
    : ExecutorFileSystem(parent)
    , m_workspaceRoot(workspaceRoot)
{
    // Initialize protected paths
    m_protectedPaths << QDir::home().absolutePath() + "/.ssh"
                     << QDir::home().absolutePath() + "/.gnupg"
                     << QDir::home().absolutePath() + "/.aws"
                     << "/etc/sudoers"
                     << "/etc/passwd"
                     << "/etc/shadow"
                     << "/root";
}

DirectFileSystem::~DirectFileSystem() = default;

FileSystemResult DirectFileSystem::writeFile(
    const QString& path,
    const QByteArray& contents,
    const WriteFileOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    // Reject if sandbox context is passed (use SandboxedFileSystem instead)
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "DirectFileSystem cannot be used with sandbox context. Use SandboxedFileSystem instead."
        );
    }

    // Validate path
    if (!isValidPath(path)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::InvalidPath,
            QString("Invalid path: %1").arg(path)
        );
    }

    // Check protected paths
    if (isSensitivePath(path)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::PermissionDenied,
            QString("Cannot write to protected path: %1").arg(path)
        );
    }

    // Check file size
    if (contents.size() > MAX_FILE_SIZE) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::IOError,
            QString("File too large: %1 bytes (max %2)").arg(contents.size()).arg(MAX_FILE_SIZE)
        );
    }

    // Perform atomic write
    return writeFileAtomic(path, contents, options);
}

FileSystemResult DirectFileSystem::readFile(
    const QString& path,
    QByteArray& outContents,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "DirectFileSystem cannot be used with sandbox context"
        );
    }

    if (!isValidPath(path)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::InvalidPath,
            QString("Invalid path: %1").arg(path)
        );
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::IOError,
            QString("Cannot open file for reading: %1 (%2)").arg(path).arg(file.errorString())
        );
    }

    outContents = file.readAll();
    file.close();

    return FileSystemResult();
}

FileSystemResult DirectFileSystem::createDirectory(
    const QString& path,
    const CreateDirectoryOptions& options,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "DirectFileSystem cannot be used with sandbox context"
        );
    }

    if (!isValidPath(path)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::InvalidPath,
            QString("Invalid path: %1").arg(path)
        );
    }

    QDir dir;
    if (options.recursive) {
        if (!dir.mkpath(path)) {
            return FileSystemResult(
                FileSystemResult::ErrorCode::IOError,
                QString("Failed to create directory: %1").arg(path)
            );
        }
    } else {
        if (!dir.mkdir(path)) {
            return FileSystemResult(
                FileSystemResult::ErrorCode::IOError,
                QString("Failed to create directory: %1").arg(path)
            );
        }
    }

    return FileSystemResult();
}

FileSystemResult DirectFileSystem::deleteFile(
    const QString& path,
    bool recursive,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::SandboxViolation,
            "DirectFileSystem cannot be used with sandbox context"
        );
    }

    if (!isValidPath(path)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::InvalidPath,
            QString("Invalid path: %1").arg(path)
        );
    }

    QFileInfo info(path);
    if (!info.exists()) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::NotFound,
            QString("Path does not exist: %1").arg(path)
        );
    }

    if (info.isDir()) {
        QDir dir(path);
        if (!dir.removeRecursively()) {
            return FileSystemResult(
                FileSystemResult::ErrorCode::IOError,
                QString("Failed to delete directory: %1").arg(path)
            );
        }
    } else {
        QFile file(path);
        if (!file.remove()) {
            return FileSystemResult(
                FileSystemResult::ErrorCode::IOError,
                QString("Failed to delete file: %1").arg(path)
            );
        }
    }

    return FileSystemResult();
}

bool DirectFileSystem::exists(
    const QString& path,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return false;
    }

    if (!isValidPath(path)) {
        return false;
    }

    return QFileInfo::exists(path);
}

QJsonObject DirectFileSystem::getMetadata(
    const QString& path,
    const FileSystemSandboxContext* sandbox)
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        QJsonObject err;
        err["error"] = "Sandbox violation";
        return err;
    }

    if (!isValidPath(path)) {
        QJsonObject err;
        err["error"] = "Invalid path";
        return err;
    }

    return collectMetadata(path);
}

FileSystemResult DirectFileSystem::writeFileBatch(
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

// Private implementation methods

FileSystemResult DirectFileSystem::writeFileAtomic(
    const QString& path,
    const QByteArray& contents,
    const WriteFileOptions& options)
{
    // Ensure parent directory exists
    QFileInfo fileInfo(path);
    QDir parentDir = fileInfo.dir();

    if (options.createDirs && !parentDir.exists()) {
        if (!parentDir.mkpath(".")) {
            return FileSystemResult(
                FileSystemResult::ErrorCode::IOError,
                QString("Failed to create parent directories for: %1").arg(path)
            );
        }
    }

    // Detect existing metadata if file exists
    QString existingLineEnding = "lf";
    bool hadBOM = false;

    if (QFileInfo::exists(path) && options.preserveMetadata) {
        existingLineEnding = detectLineEnding(path);
        hadBOM = detectBOM(path);
    }

    // Determine target line ending
    QString targetEnding = options.lineEnding;
    if (targetEnding == "auto") {
        targetEnding = existingLineEnding;
    }

    // Prepare content
    QString contentStr = QString::fromUtf8(contents);
    QString normalizedContent = normalizeLineEndings(contentStr, "lf", targetEnding);
    QByteArray finalContents = normalizedContent.toUtf8();

    // Add BOM if needed
    if (hadBOM && options.preserveBOM) {
        finalContents.prepend("\xef\xbb\xbf");
    }

    // Write atomically using QSaveFile
    QSaveFile saveFile(path);
    if (!saveFile.open(QIODevice::WriteOnly)) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::IOError,
            QString("Cannot open file for writing: %1").arg(saveFile.errorString())
        );
    }

    qint64 written = saveFile.write(finalContents);
    if (written != finalContents.size()) {
        saveFile.cancelWriting();
        return FileSystemResult(
            FileSystemResult::ErrorCode::IOError,
            QString("Failed to write complete content to file: %1").arg(path)
        );
    }

    if (!saveFile.commit()) {
        return FileSystemResult(
            FileSystemResult::ErrorCode::IOError,
            QString("Failed to commit file write: %1").arg(saveFile.errorString())
        );
    }

    // Copy permissions from original if it existed
    if (QFileInfo::exists(path) && options.preserveMetadata) {
        QFile origFile(path);
        origFile.setPermissions(origFile.permissions());
    }

    emit fileWritten(path);

    return FileSystemResult();
}

QString DirectFileSystem::detectLineEnding(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return "lf";
    }

    QByteArray content = file.read(8192);  // Check first 8KB
    file.close();

    if (content.contains("\r\n")) {
        return "crlf";
    } else if (content.contains("\r")) {
        return "cr";
    }

    return "lf";
}

bool DirectFileSystem::detectBOM(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    QByteArray firstBytes = file.read(4);
    file.close();

    // Check for UTF-8 BOM
    return firstBytes.startsWith("\xef\xbb\xbf");
}

QString DirectFileSystem::normalizeLineEndings(
    const QString& content,
    const QString& currentEnding,
    const QString& targetEnding)
{
    QString result = content;

    // First normalize to LF
    result.replace("\r\n", "\n");
    result.replace("\r", "\n");

    // Then convert to target
    if (targetEnding == "crlf") {
        result.replace("\n", "\r\n");
    } else if (targetEnding == "cr") {
        result.replace("\n", "\r");
    }

    return result;
}

bool DirectFileSystem::copyFilePermissions(const QString& from, const QString& to)
{
    QFileInfo sourceInfo(from);
    if (!sourceInfo.exists()) {
        return false;
    }

    QFile targetFile(to);
    return targetFile.setPermissions(sourceInfo.permissions());
}

QByteArray DirectFileSystem::readExistingContent(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }

    QByteArray content = file.readAll();
    file.close();
    return content;
}

QString DirectFileSystem::safePath(const QString& path) const
{
    QFileInfo info(path);
    return info.canonicalFilePath();
}

bool DirectFileSystem::isValidPath(const QString& path) const
{
    if (path.isEmpty()) {
        return false;
    }

    if (path.contains("..")) {
        return false;
    }

    QFileInfo info(path);
    QString canonical = info.absoluteFilePath();

    // Check if path tries to escape workspace
    if (!canonical.startsWith(m_workspaceRoot.absolutePath()) && 
        !QDir(m_workspaceRoot).isAbsolutePath(canonical)) {
        return false;
    }

    return true;
}

bool DirectFileSystem::isSensitivePath(const QString& path) const
{
    QString absPath = QFileInfo(path).absoluteFilePath();

    for (const auto& protected_path : m_protectedPaths) {
        if (absPath.startsWith(protected_path)) {
            return true;
        }
    }

    return false;
}

QJsonObject DirectFileSystem::collectMetadata(const QString& path)
{
    QJsonObject meta;
    QFileInfo info(path);

    if (!info.exists()) {
        meta["error"] = "Path does not exist";
        return meta;
    }

    meta["path"] = path;
    meta["exists"] = true;
    meta["isFile"] = info.isFile();
    meta["isDir"] = info.isDir();
    meta["size"] = static_cast<qint64>(info.size());
    meta["created"] = info.birthTime().toString(Qt::ISODate);
    meta["modified"] = info.lastModified().toString(Qt::ISODate);
    meta["permissions"] = QString::number(info.permissions(), 8);

    if (info.isFile()) {
        meta["lineEnding"] = detectLineEnding(path);
        meta["hasBOM"] = detectBOM(path);
        meta["extension"] = info.suffix();
    }

    return meta;
}

QString DirectFileSystem::getFileExtension(const QString& path) const
{
    return QFileInfo(path).suffix();
}
