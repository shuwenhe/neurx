#include "tools/CodexFileSystemTool.h"
#include "sandbox/SandboxManager.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QDateTime>
#include <QCryptographicHash>
#include <QSet>
#include <QRegularExpression>
#include <QDebug>

CodexFileSystemTool::CodexFileSystemTool(
    const QString& workspaceRoot,
    QObject* parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
    , m_root(workspaceRoot)
{
    m_fileSystem = std::make_shared<LocalFileSystem>(workspaceRoot, parent);
}

CodexFileSystemTool::~CodexFileSystemTool() = default;

QJsonObject CodexFileSystemTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "operation": {
                "type": "string",
                "enum": ["write_file", "create_file", "read_file", "create_directory", "delete_file", "get_metadata", "stat_file", "hash_file", "chmod", "symlink", "touch", "truncate", "read_range", "tail", "write_batch", "exists", "list_directory", "find_files", "read_many_files", "move", "rename", "copy", "append"],
                "description": "File system operation to perform"
            },
            "path": {
                "type": "string",
                "description": "File or directory path"
            },
            "contents": {
                "type": "string",
                "description": "File contents (for write operations)"
            },
            "contentsBase64": {
                "type": "string",
                "description": "File contents as Base64 (binary data)"
            },
            "options": {
                "type": "object",
                "description": "Write options (atomic, createDirs, lineEnding, preserveMetadata, preserveBOM)",
                "properties": {
                    "atomic": {"type": "boolean"},
                    "createDirs": {"type": "boolean"},
                    "lineEnding": {"type": "string", "enum": ["auto", "lf", "crlf", "cr"]},
                    "preserveMetadata": {"type": "boolean"},
                    "preserveBOM": {"type": "boolean"}
                }
            },
            "directoryOptions": {
                "type": "object",
                "description": "Directory creation options",
                "properties": {
                    "recursive": {"type": "boolean"},
                    "failIfExists": {"type": "boolean"}
                }
            },
            "deleteRecursive": {
                "type": "boolean",
                "description": "Delete recursively (for directories)"
            },
            "recursive": {
                "type": "boolean",
                "description": "List directories recursively"
            },
            "includeHidden": {
                "type": "boolean",
                "description": "Include hidden entries in directory listings"
            },
            "maxResults": {
                "type": "integer",
                "description": "Maximum number of entries to return from directory listings"
            },
            "include": {
                "type": "array",
                "description": "Glob patterns for multi-file operations",
                "items": {
                    "type": "string"
                }
            },
            "base_dir": {
                "type": "string",
                "description": "Base directory for multi-file operations"
            },
            "maxFiles": {
                "type": "integer",
                "description": "Maximum number of files to match for multi-file operations"
            },
            "includeHiddenFiles": {
                "type": "boolean",
                "description": "Include hidden files in multi-file operations"
            },
            "destination": {
                "type": "string",
                "description": "Destination path for move/copy/rename"
            },
            "target": {
                "type": "string",
                "description": "Symlink target path"
            },
            "linkPath": {
                "type": "string",
                "description": "Symlink path to create"
            },
            "mode": {
                "type": "string",
                "description": "Octal permissions string for chmod, e.g. 644 or 0755"
            },
            "algorithm": {
                "type": "string",
                "description": "Hash algorithm for hash_file (sha256, sha1, md5, sha512)",
                "default": "sha256"
            },
            "start": {
                "type": "integer",
                "description": "Start byte offset for read_range"
            },
            "length": {
                "type": "integer",
                "description": "Length in bytes for read_range or number of lines for tail"
            },
            "files": {
                "type": "array",
                "description": "Array of {path, contents} for batch operations",
                "items": {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string"},
                        "contents": {"type": "string"},
                        "contentsBase64": {"type": "string"}
                    }
                }
            },
            "sandbox": {
                "type": "object",
                "description": "Sandbox context for restricted access",
                "properties": {
                    "workspaceId": {"type": "string"},
                    "confineDir": {"type": "string"},
                    "allowedPaths": {"type": "array", "items": {"type": "string"}},
                    "deniedPaths": {"type": "array", "items": {"type": "string"}},
                    "canRead": {"type": "boolean"},
                    "canWrite": {"type": "boolean"},
                    "canDelete": {"type": "boolean"},
                    "canCreateDirs": {"type": "boolean"}
                }
            }
        },
        "required": ["operation", "path"]
    })JSON").object();
}

ToolResult CodexFileSystemTool::execute(const QString& callId, const QJsonObject& args)
{
    QString operation = args.value("operation").toString();

    if (operation == "write_file") {
        return opWriteFile(callId, args);
    } else if (operation == "create_file") {
        return opCreateFile(callId, args);
    } else if (operation == "read_file") {
        return opReadFile(callId, args);
    } else if (operation == "create_directory") {
        return opCreateDirectory(callId, args);
    } else if (operation == "delete_file") {
        return opDeleteFile(callId, args);
    } else if (operation == "get_metadata") {
        return opGetMetadata(callId, args);
    } else if (operation == "stat_file") {
        return opStatFile(callId, args);
    } else if (operation == "hash_file") {
        return opHashFile(callId, args);
    } else if (operation == "chmod") {
        return opChmodFile(callId, args);
    } else if (operation == "symlink") {
        return opSymlinkFile(callId, args);
    } else if (operation == "touch") {
        return opTouchFile(callId, args);
    } else if (operation == "truncate") {
        return opTruncateFile(callId, args);
    } else if (operation == "read_range") {
        return opReadRangeFile(callId, args);
    } else if (operation == "tail") {
        return opTailFile(callId, args);
    } else if (operation == "write_batch") {
        return opWriteBatch(callId, args);
    } else if (operation == "exists") {
        return opExists(callId, args);
    } else if (operation == "list_directory") {
        return opListDirectory(callId, args);
    } else if (operation == "find_files") {
        return opFindFiles(callId, args);
    } else if (operation == "read_many_files") {
        return opReadManyFiles(callId, args);
    } else if (operation == "move") {
        return opMoveFile(callId, args);
    } else if (operation == "rename") {
        return opRenameFile(callId, args);
    } else if (operation == "copy") {
        return opCopyFile(callId, args);
    } else if (operation == "append") {
        return opAppendFile(callId, args);
    }

    return ToolResult{
        callId,
        name(),
        true,
        QString(R"({"error": "Unknown operation: %1"})").arg(operation)
    };
}

QString CodexFileSystemTool::summary(const QJsonObject& args) const
{
    QString operation = args.value("operation").toString();
    QString path = args.value("path").toString();
    const QString destination = args.value("destination").toString();
    if (!destination.isEmpty()) {
        return QString("Codex file system %1: %2 -> %3").arg(operation, path, destination);
    }
    return QString("Codex file system %1: %2").arg(operation, path);
}

void CodexFileSystemTool::setSandboxManager(SandboxManager* manager)
{
    if (m_fileSystem) {
        m_fileSystem->setSandboxManager(manager);
    }
}

// Private implementation

QString CodexFileSystemTool::safePath(const QString& relOrAbsPath) const
{
    const QFileInfo fileInfo(relOrAbsPath);
    if (fileInfo.isAbsolute()) {
        const QString absPath = QDir::cleanPath(fileInfo.absoluteFilePath());
        const QString cleanRoot = QDir::cleanPath(m_root.absolutePath());
        return absPath.startsWith(cleanRoot) ? absPath : QString();
    }

    const QString absPath = QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
    const QString cleanRoot = QDir::cleanPath(m_root.absolutePath());
    return absPath.startsWith(cleanRoot) ? absPath : QString();
}

QString CodexFileSystemTool::workspaceRelativePath(const QString& relOrAbsPath) const
{
    const QString absPath = safePath(relOrAbsPath);
    if (absPath.isEmpty()) {
        return QString();
    }
    return m_root.relativeFilePath(absPath);
}

bool CodexFileSystemTool::ensureParentDirectory(const QString& absPath) const
{
    const QFileInfo info(absPath);
    const QString parent = info.dir().absolutePath();
    if (parent.isEmpty()) {
        return false;
    }
    return QDir().mkpath(parent);
}

bool CodexFileSystemTool::copyRecursive(const QString& source, const QString& destination) const
{
    const QFileInfo srcInfo(source);
    if (!srcInfo.exists()) {
        return false;
    }

    if (srcInfo.isDir()) {
        if (!QDir().mkpath(destination)) {
            return false;
        }

        QDir sourceDir(source);
        const QFileInfoList entries = sourceDir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries);
        for (const QFileInfo& entry : entries) {
            const QString targetPath = QDir(destination).absoluteFilePath(entry.fileName());
            if (entry.isDir()) {
                if (!copyRecursive(entry.absoluteFilePath(), targetPath)) {
                    return false;
                }
            } else {
                QDir().mkpath(QFileInfo(targetPath).dir().absolutePath());
                QFile::remove(targetPath);
                if (!QFile::copy(entry.absoluteFilePath(), targetPath)) {
                    return false;
                }
            }
        }
        return true;
    }

    QDir().mkpath(QFileInfo(destination).dir().absolutePath());
    QFile::remove(destination);
    return QFile::copy(source, destination);
}

bool CodexFileSystemTool::moveRecursive(const QString& source, const QString& destination) const
{
    const QFileInfo srcInfo(source);
    if (!srcInfo.exists()) {
        return false;
    }

    if (srcInfo.isDir()) {
        if (QDir().rename(source, destination)) {
            return true;
        }
        if (!copyRecursive(source, destination)) {
            return false;
        }
        return QDir(source).removeRecursively();
    }

    QDir().mkpath(QFileInfo(destination).dir().absolutePath());
    QFile::remove(destination);
    if (QFile::rename(source, destination)) {
        return true;
    }
    if (!QFile::copy(source, destination)) {
        return false;
    }
    return QFile::remove(source);
}

ToolResult CodexFileSystemTool::opWriteFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    // Get contents
    QByteArray contents;
    if (args.contains("contentsBase64")) {
        contents = QByteArray::fromBase64(args.value("contentsBase64").toString().toLatin1());
    } else if (args.contains("contents")) {
        contents = args.value("contents").toString().toUtf8();
    } else {
        result.isError = true;
        result.content = R"({"error": "contents or contentsBase64 is required"})";
        return result;
    }

    // Parse options
    WriteFileOptions options;
    if (args.contains("options")) {
        QJsonObject opts = args.value("options").toObject();
        if (opts.contains("atomic")) {
            options.atomic = opts.value("atomic").toBool();
        }
        if (opts.contains("createDirs")) {
            options.createDirs = opts.value("createDirs").toBool();
        }
        if (opts.contains("lineEnding")) {
            options.lineEnding = opts.value("lineEnding").toString();
        }
        if (opts.contains("preserveMetadata")) {
            options.preserveMetadata = opts.value("preserveMetadata").toBool();
        }
        if (opts.contains("preserveBOM")) {
            options.preserveBOM = opts.value("preserveBOM").toBool();
        }
    }

    // Create sandbox context if provided
    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canWrite()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies write access"})";
        return result;
    }

    // Perform write
    if (options.createDirs) {
        ensureParentDirectory(safe);
    }

    auto fsResult = m_fileSystem->writeFile(safe, contents, options, sandbox.get());

    if (fsResult.isOk()) {
        result.isError = false;
        QJsonObject output;
        output["success"] = true;
        output["path"] = path;
        output["bytesWritten"] = static_cast<int>(contents.size());
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    } else {
        result.isError = true;
        QJsonObject output;
        output["error"] = fsResult.message();
        output["code"] = static_cast<int>(fsResult.code());
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    }

    return result;
}

ToolResult CodexFileSystemTool::opCreateFile(const QString& callId, const QJsonObject& args)
{
    QJsonObject createArgs = args;
    if (!createArgs.contains("contents") && !createArgs.contains("contentsBase64")) {
        createArgs["contents"] = QString();
    }
    return opWriteFile(callId, createArgs);
}

ToolResult CodexFileSystemTool::opExists(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    bool exists = m_fileSystem->exists(safe, sandbox.get());

    QJsonObject output;
    output["path"] = path;
    output["exists"] = exists;
    result.isError = false;
    result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opListDirectory(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();
    const bool recursive = args.value("recursive").toBool(false);
    const bool includeHidden = args.value("includeHidden").toBool(false);
    const int maxResults = args.value("maxResults").toInt(1000);

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QJsonObject meta = m_fileSystem->getMetadata(safe, sandbox.get());
    if (meta.contains("error")) {
        result.isError = true;
        result.content = QJsonDocument(meta).toJson(QJsonDocument::Compact);
        return result;
    }

    if (!meta.value("isDir").toBool()) {
        result.isError = true;
        QJsonObject out;
        out["error"] = QString("Path is not a directory: %1").arg(path);
        result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
        return result;
    }

    QJsonArray entries;
    QDir::Filters filters = QDir::NoDotAndDotDot | QDir::AllEntries;
    if (includeHidden) {
        filters |= QDir::Hidden;
    }

    if (!recursive) {
        QDir dir(safe);
        const QFileInfoList list = dir.entryInfoList(filters, QDir::DirsFirst | QDir::Name);
        for (const QFileInfo& info : list) {
            QJsonObject item;
            item["name"] = info.fileName();
            item["path"] = info.absoluteFilePath();
            item["relativePath"] = workspaceRelativePath(info.absoluteFilePath());
            item["isFile"] = info.isFile();
            item["isDir"] = info.isDir();
            item["size"] = static_cast<qint64>(info.size());
            item["modified"] = info.lastModified().toString(Qt::ISODate);
            entries.append(item);
            if (entries.size() >= maxResults) {
                break;
            }
        }
    } else {
        QDirIterator it(safe, filters, QDirIterator::Subdirectories);
        while (it.hasNext() && entries.size() < maxResults) {
            const QFileInfo info = it.nextFileInfo();
            QJsonObject item;
            item["name"] = info.fileName();
            item["path"] = info.absoluteFilePath();
            item["relativePath"] = workspaceRelativePath(info.absoluteFilePath());
            item["isFile"] = info.isFile();
            item["isDir"] = info.isDir();
            item["size"] = static_cast<qint64>(info.size());
            item["modified"] = info.lastModified().toString(Qt::ISODate);
            entries.append(item);
        }
    }

    QJsonObject out;
    out["path"] = path;
    out["recursive"] = recursive;
    out["entries"] = entries;
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

QStringList CodexFileSystemTool::collectFilesByPatterns(
    const QString& baseDir,
    const QStringList& patterns,
    bool includeHidden,
    int maxResults) const
{
    QStringList matched;
    QSet<QString> seen;

    if (baseDir.isEmpty() || patterns.isEmpty() || maxResults <= 0) {
        return matched;
    }

    QDir::Filters filters = QDir::Files | QDir::NoDotAndDotDot;
    if (includeHidden) {
        filters |= QDir::Hidden;
    }

    for (const QString& pattern : patterns) {
        if (pattern.isEmpty()) {
            continue;
        }

        QDirIterator it(baseDir, QStringList() << pattern, filters, QDirIterator::Subdirectories);
        while (it.hasNext() && matched.size() < maxResults) {
            const QString filePath = QDir::cleanPath(it.next());
            if (seen.contains(filePath)) {
                continue;
            }
            seen.insert(filePath);
            matched.append(filePath);
        }

        if (matched.size() >= maxResults) {
            break;
        }
    }

    matched.sort(Qt::CaseInsensitive);
    return matched;
}

ToolResult CodexFileSystemTool::opFindFiles(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QJsonArray include = args.value("include").toArray();
    QStringList patterns;
    patterns.reserve(include.size());
    for (const auto& value : include) {
        const QString pattern = value.toString();
        if (!pattern.isEmpty()) {
            patterns.append(pattern);
        }
    }

    if (patterns.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "include patterns are required"})";
        return result;
    }

    QString baseDir = args.value("base_dir").toString();
    if (baseDir.isEmpty()) {
        baseDir = m_root.absolutePath();
    } else {
        const QString safeBase = safePath(baseDir);
        if (safeBase.isEmpty()) {
            result.isError = true;
            result.content = R"({"error": "path traversal attack detected"})";
            return result;
        }
        baseDir = safeBase;
    }

    const bool includeHidden = args.value("includeHiddenFiles").toBool(false);
    const int maxResults = args.value("maxFiles").toInt(1000);
    const QStringList files = collectFilesByPatterns(baseDir, patterns, includeHidden, maxResults);

    QJsonArray fileArray;
    for (const QString& filePath : files) {
        QJsonObject item;
        item["path"] = filePath;
        item["relativePath"] = workspaceRelativePath(filePath);
        item["name"] = QFileInfo(filePath).fileName();
        fileArray.append(item);
    }

    QJsonObject out;
    out["base_dir"] = baseDir;
    out["patterns"] = QJsonArray::fromStringList(patterns);
    out["files_found"] = fileArray.size();
    out["files"] = fileArray;
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opReadManyFiles(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QJsonArray include = args.value("include").toArray();
    QStringList patterns;
    patterns.reserve(include.size());
    for (const auto& value : include) {
        const QString pattern = value.toString();
        if (!pattern.isEmpty()) {
            patterns.append(pattern);
        }
    }

    if (patterns.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "include patterns are required"})";
        return result;
    }

    QString baseDir = args.value("base_dir").toString();
    if (baseDir.isEmpty()) {
        baseDir = m_root.absolutePath();
    } else {
        const QString safeBase = safePath(baseDir);
        if (safeBase.isEmpty()) {
            result.isError = true;
            result.content = R"({"error": "path traversal attack detected"})";
            return result;
        }
        baseDir = safeBase;
    }

    const bool includeHidden = args.value("includeHiddenFiles").toBool(false);
    const int maxResults = args.value("maxFiles").toInt(1000);
    const QStringList files = collectFilesByPatterns(baseDir, patterns, includeHidden, maxResults);

    if (files.isEmpty()) {
        result.isError = false;
        result.content = R"({"content":"","files_read":0,"files":[]})";
        return result;
    }

    QString mergedContent;
    QJsonArray fileArray;
    int filesRead = 0;

    for (const QString& filePath : files) {
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        const QByteArray bytes = file.readAll();
        file.close();

        mergedContent += QString("--- %1 ---\n\n").arg(workspaceRelativePath(filePath).isEmpty() ? filePath : workspaceRelativePath(filePath));
        mergedContent += QString::fromUtf8(bytes);
        mergedContent += "\n\n";

        QJsonObject item;
        item["path"] = filePath;
        item["relativePath"] = workspaceRelativePath(filePath);
        item["bytes"] = static_cast<int>(bytes.size());
        fileArray.append(item);
        ++filesRead;
    }

    if (filesRead == 0) {
        result.isError = true;
        result.content = R"({"error":"No files found matching the patterns or failed to read them."})";
        return result;
    }

    QJsonObject out;
    out["base_dir"] = baseDir;
    out["patterns"] = QJsonArray::fromStringList(patterns);
    out["files_read"] = filesRead;
    out["files"] = fileArray;
    out["content"] = mergedContent;
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opMoveFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString src = args.value("path").toString();
    QString dst = args.value("destination").toString();
    if (dst.isEmpty()) dst = args.value("dest").toString();

    if (src.isEmpty() || dst.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path and destination are required"})";
        return result;
    }

    const QString safeSrc = safePath(src);
    const QString safeDst = safePath(dst);
    if (safeSrc.isEmpty() || safeDst.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    // Check source metadata
    QJsonObject srcMeta = m_fileSystem->getMetadata(safeSrc, sandbox.get());
    if (srcMeta.contains("error")) {
        result.isError = true;
        result.content = QJsonDocument(srcMeta).toJson(QJsonDocument::Compact);
        return result;
    }

    if (!ensureParentDirectory(safeDst)) {
        result.isError = true;
        result.content = R"({"error": "failed to create destination directory"})";
        return result;
    }

    if (!moveRecursive(safeSrc, safeDst)) {
        result.isError = true;
        QJsonObject out;
        out["error"] = QString("Failed to move %1 -> %2").arg(src, dst);
        result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
        return result;
    }

    QJsonObject out;
    out["success"] = true;
    out["from"] = src;
    out["to"] = dst;
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opRenameFile(const QString& callId, const QJsonObject& args)
{
    QJsonObject renameArgs = args;
    if (!renameArgs.contains("destination") && renameArgs.contains("dest")) {
        renameArgs["destination"] = renameArgs.value("dest");
    }
    return opMoveFile(callId, renameArgs);
}

ToolResult CodexFileSystemTool::opCopyFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString src = args.value("path").toString();
    QString dst = args.value("destination").toString();
    if (dst.isEmpty()) dst = args.value("dest").toString();

    if (src.isEmpty() || dst.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path and destination are required"})";
        return result;
    }

    const QString safeSrc = safePath(src);
    const QString safeDst = safePath(dst);
    if (safeSrc.isEmpty() || safeDst.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QJsonObject srcMeta = m_fileSystem->getMetadata(safeSrc, sandbox.get());
    if (srcMeta.contains("error")) {
        result.isError = true;
        result.content = QJsonDocument(srcMeta).toJson(QJsonDocument::Compact);
        return result;
    }

    if (!ensureParentDirectory(safeDst)) {
        result.isError = true;
        result.content = R"({"error": "failed to create destination directory"})";
        return result;
    }

    if (!copyRecursive(safeSrc, safeDst)) {
        result.isError = true;
        QJsonObject out;
        out["error"] = QString("Failed to copy %1 -> %2").arg(src, dst);
        result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
        return result;
    }

    QJsonObject out;
    out["success"] = true;
    out["from"] = src;
    out["to"] = dst;
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opAppendFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    // Get contents to append
    QByteArray toAppend;
    if (args.contains("contentsBase64")) {
        toAppend = QByteArray::fromBase64(args.value("contentsBase64").toString().toLatin1());
    } else if (args.contains("contents")) {
        toAppend = args.value("contents").toString().toUtf8();
    } else {
        result.isError = true;
        result.content = R"({"error": "contents or contentsBase64 is required"})";
        return result;
    }

    WriteFileOptions options;
    if (args.contains("options")) {
        QJsonObject opts = args.value("options").toObject();
        if (opts.contains("atomic")) options.atomic = opts.value("atomic").toBool();
        if (opts.contains("createDirs")) options.createDirs = opts.value("createDirs").toBool();
        if (opts.contains("lineEnding")) options.lineEnding = opts.value("lineEnding").toString();
        if (opts.contains("preserveMetadata")) options.preserveMetadata = opts.value("preserveMetadata").toBool();
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    if (!ensureParentDirectory(safe)) {
        result.isError = true;
        result.content = R"({"error": "failed to create parent directory"})";
        return result;
    }

    // Read existing content if present
    QByteArray existing;
    auto readRes = m_fileSystem->readFile(safe, existing, sandbox.get());
    if (readRes.isErr()) {
        if (readRes.code() == FileSystemResult::ErrorCode::NotFound) {
            existing.clear();
        } else {
            result.isError = true;
            result.content = QJsonDocument(resultToJson(readRes)).toJson(QJsonDocument::Compact);
            return result;
        }
    }

    QByteArray finalContents = existing + toAppend;
    auto writeRes = m_fileSystem->writeFile(safe, finalContents, options, sandbox.get());
    if (writeRes.isOk()) {
        QJsonObject out;
        out["success"] = true;
        out["path"] = path;
        out["bytesWritten"] = static_cast<int>(toAppend.size());
        result.isError = false;
        result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    } else {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(writeRes)).toJson(QJsonDocument::Compact);
    }

    return result;
}

ToolResult CodexFileSystemTool::opReadFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QByteArray contents;
    auto fsResult = m_fileSystem->readFile(safe, contents, sandbox.get());

    if (fsResult.isOk()) {
        result.isError = false;
        QJsonObject output;
        output["success"] = true;
        output["path"] = path;
        output["size"] = static_cast<int>(contents.size());
        output["contents"] = QString::fromUtf8(contents);
        output["contentsBase64"] = QString(contents.toBase64());
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    } else {
        result.isError = true;
        QJsonObject output;
        output["error"] = fsResult.message();
        output["code"] = static_cast<int>(fsResult.code());
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    }

    return result;
}

ToolResult CodexFileSystemTool::opCreateDirectory(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    CreateDirectoryOptions options;
    if (args.contains("directoryOptions")) {
        QJsonObject opts = args.value("directoryOptions").toObject();
        if (opts.contains("recursive")) {
            options.recursive = opts.value("recursive").toBool();
        }
        if (opts.contains("failIfExists")) {
            options.failIfExists = opts.value("failIfExists").toBool();
        }
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    auto fsResult = m_fileSystem->createDirectory(safe, options, sandbox.get());

    if (fsResult.isOk()) {
        result.isError = false;
        QJsonObject output;
        output["success"] = true;
        output["path"] = path;
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    } else {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(fsResult)).toJson(QJsonDocument::Compact);
    }

    return result;
}

ToolResult CodexFileSystemTool::opDeleteFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    bool deleteRecursive = args.value("deleteRecursive").toBool(false);

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    auto fsResult = m_fileSystem->deleteFile(safe, deleteRecursive, sandbox.get());

    if (fsResult.isOk()) {
        result.isError = false;
        QJsonObject output;
        output["success"] = true;
        output["path"] = path;
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    } else {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(fsResult)).toJson(QJsonDocument::Compact);
    }

    return result;
}

ToolResult CodexFileSystemTool::opGetMetadata(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    auto metadata = m_fileSystem->getMetadata(safe, sandbox.get());

    result.isError = metadata.contains("error");
    result.content = QJsonDocument(metadata).toJson(QJsonDocument::Compact);

    return result;
}

ToolResult CodexFileSystemTool::opStatFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QJsonObject metadata = m_fileSystem->getMetadata(safe, sandbox.get());
    if (metadata.contains("error")) {
        result.isError = true;
        result.content = QJsonDocument(metadata).toJson(QJsonDocument::Compact);
        return result;
    }

    QFileInfo info(safe);
    metadata["name"] = info.fileName();
    metadata["absolutePath"] = info.absoluteFilePath();
    metadata["canonicalPath"] = info.canonicalFilePath();
    metadata["suffix"] = info.suffix();
    metadata["completeSuffix"] = info.completeSuffix();
    metadata["baseName"] = info.baseName();
    metadata["isSymLink"] = info.isSymLink();
    metadata["isExecutable"] = info.isExecutable();
    metadata["permissionsDecimal"] = static_cast<int>(info.permissions());
    metadata["permissionsOctal"] = QString::number(static_cast<int>(info.permissions()), 8);
    metadata["owner"] = info.owner();
    metadata["group"] = info.group();
    metadata["lastRead"] = info.lastRead().toString(Qt::ISODate);
    metadata["birthTime"] = info.birthTime().toString(Qt::ISODate);
    if (info.isSymLink()) {
        metadata["symLinkTarget"] = info.symLinkTarget();
    }

    result.isError = false;
    result.content = QJsonDocument(metadata).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opHashFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();
    const QString algorithm = args.value("algorithm").toString("sha256").toLower();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QByteArray contents;
    const auto readResult = m_fileSystem->readFile(safe, contents, sandbox.get());
    if (readResult.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(readResult)).toJson(QJsonDocument::Compact);
        return result;
    }

    QCryptographicHash::Algorithm hashAlg = QCryptographicHash::Sha256;
    if (algorithm == "sha1") {
        hashAlg = QCryptographicHash::Sha1;
    } else if (algorithm == "md5") {
        hashAlg = QCryptographicHash::Md5;
    } else if (algorithm == "sha512") {
        hashAlg = QCryptographicHash::Sha512;
    } else if (algorithm != "sha256") {
        result.isError = true;
        result.content = QString(R"({"error":"Unsupported hash algorithm: %1"})").arg(algorithm);
        return result;
    }

    QCryptographicHash hasher(hashAlg);
    hasher.addData(contents);

    QJsonObject out;
    out["path"] = path;
    out["algorithm"] = algorithm;
    out["hash"] = QString::fromLatin1(hasher.result().toHex());
    out["size"] = static_cast<int>(contents.size());

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

static QFileDevice::Permissions permissionsFromOctalMode(const QString& modeString, bool& ok)
{
    QString trimmed = modeString.trimmed();
    if (trimmed.startsWith("0")) {
        // Keep octal parsing behavior.
    }

    int octal = trimmed.toInt(&ok, 8);
    if (!ok) {
        octal = trimmed.toInt(&ok, 10);
    }
    if (!ok) {
        return {};
    }

    int owner = (octal / 100) % 10;
    int group = (octal / 10) % 10;
    int other = octal % 10;

    auto apply = [](int bits, QFileDevice::Permission read, QFileDevice::Permission write, QFileDevice::Permission exec) {
        QFileDevice::Permissions perms;
        if (bits & 4) perms |= read;
        if (bits & 2) perms |= write;
        if (bits & 1) perms |= exec;
        return perms;
    };

    QFileDevice::Permissions perms;
    perms |= apply(owner, QFileDevice::ReadOwner, QFileDevice::WriteOwner, QFileDevice::ExeOwner);
    perms |= apply(group, QFileDevice::ReadGroup, QFileDevice::WriteGroup, QFileDevice::ExeGroup);
    perms |= apply(other, QFileDevice::ReadOther, QFileDevice::WriteOther, QFileDevice::ExeOther);
    return perms;
}

ToolResult CodexFileSystemTool::opChmodFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();
    const QString mode = args.value("mode").toString();

    if (path.isEmpty() || mode.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path and mode are required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    QFile file(safe);
    if (!file.exists()) {
        result.isError = true;
        result.content = QString(R"({"error":"Path does not exist: %1"})").arg(path);
        return result;
    }

    bool ok = false;
    const QFileDevice::Permissions perms = permissionsFromOctalMode(mode, ok);
    if (!ok) {
        result.isError = true;
        result.content = R"({"error": "invalid mode string"})";
        return result;
    }

    if (!file.setPermissions(perms)) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to set permissions on %1"})").arg(path);
        return result;
    }

    QJsonObject out;
    out["path"] = path;
    out["mode"] = mode;
    out["applied"] = true;
    out["permissionsDecimal"] = static_cast<int>(perms);
    out["permissionsOctal"] = QString::number(static_cast<int>(perms), 8);

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opSymlinkFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString target = args.value("target").toString();
    const QString linkPath = args.value("linkPath").toString();

    if (target.isEmpty() || linkPath.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "target and linkPath are required"})";
        return result;
    }

    const QString safeTarget = safePath(target);
    const QString safeLinkPath = safePath(linkPath);
    if (safeTarget.isEmpty() || safeLinkPath.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    if (!ensureParentDirectory(safeLinkPath)) {
        result.isError = true;
        result.content = R"({"error": "failed to create parent directory"})";
        return result;
    }

    if (QFile::exists(safeLinkPath)) {
        QFile::remove(safeLinkPath);
    }

    if (!QFile::link(safeTarget, safeLinkPath)) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to create symlink from %1 to %2"})").arg(linkPath, target);
        return result;
    }

    QJsonObject out;
    out["target"] = target;
    out["linkPath"] = linkPath;
    out["created"] = true;
    out["absoluteTarget"] = safeTarget;
    out["absoluteLinkPath"] = safeLinkPath;

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opTouchFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    if (!ensureParentDirectory(safe)) {
        result.isError = true;
        result.content = R"({"error": "failed to create parent directory"})";
        return result;
    }

    QFile file(safe);
    bool created = false;
    if (!file.exists()) {
        if (!file.open(QIODevice::WriteOnly)) {
            result.isError = true;
            result.content = QString(R"({"error":"Failed to create file: %1"})").arg(file.errorString());
            return result;
        }
        file.close();
        created = true;
    }

    const QDateTime now = QDateTime::currentDateTimeUtc();
    file.setFileTime(now, QFileDevice::FileModificationTime);
    file.setFileTime(now, QFileDevice::FileAccessTime);

    QJsonObject out;
    out["path"] = path;
    out["created"] = created;
    out["touched"] = true;
    out["modified"] = now.toString(Qt::ISODate);

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opTruncateFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();
    const qint64 size = static_cast<qint64>(args.value("length").toVariant().toLongLong());

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }
    if (size < 0) {
        result.isError = true;
        result.content = R"({"error": "length must be >= 0"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    if (!ensureParentDirectory(safe)) {
        result.isError = true;
        result.content = R"({"error": "failed to create parent directory"})";
        return result;
    }

    QFile file(safe);
    const bool exists = file.exists();
    if (!file.open(exists ? QIODevice::ReadWrite : QIODevice::WriteOnly)) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to open file: %1"})").arg(file.errorString());
        return result;
    }

    if (!file.resize(size)) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to truncate file: %1"})").arg(file.errorString());
        return result;
    }
    file.close();

    QJsonObject out;
    out["path"] = path;
    out["size"] = size;
    out["truncated"] = true;

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opReadRangeFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();
    const qint64 start = static_cast<qint64>(args.value("start").toVariant().toLongLong());
    const qint64 length = static_cast<qint64>(args.value("length").toVariant().toLongLong());

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }
    if (start < 0) {
        result.isError = true;
        result.content = R"({"error": "start must be >= 0"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canWrite()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies write access"})";
        return result;
    }

    QByteArray contents;
    const auto readResult = m_fileSystem->readFile(safe, contents, sandbox.get());
    if (readResult.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(readResult)).toJson(QJsonDocument::Compact);
        return result;
    }

    if (start > contents.size()) {
        result.isError = true;
        result.content = R"({"error": "start is beyond end of file"})";
        return result;
    }

    const qint64 available = contents.size() - start;
    const qint64 bytesToRead = (length < 0) ? available : qMin(length, available);
    const QByteArray slice = contents.mid(start, bytesToRead);

    QJsonObject out;
    out["path"] = path;
    out["start"] = start;
    out["length"] = bytesToRead;
    out["size"] = contents.size();
    out["contents"] = QString::fromUtf8(slice);
    out["contentsBase64"] = QString::fromLatin1(slice.toBase64());

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opTailFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();
    const int lines = qMax(1, args.value("length").toInt(20));

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
    }

    QByteArray contents;
    const auto readResult = m_fileSystem->readFile(safe, contents, sandbox.get());
    if (readResult.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(readResult)).toJson(QJsonDocument::Compact);
        return result;
    }

    const QString text = QString::fromUtf8(contents);
    const QStringList allLines = text.split('\n');
    const int totalLines = allLines.size();
    const int startIndex = qMax(0, totalLines - lines);
    const QStringList tailLines = allLines.mid(startIndex);

    QJsonObject out;
    out["path"] = path;
    out["lines"] = lines;
    out["totalLines"] = totalLines;
    out["startLine"] = startIndex + 1;
    out["content"] = tailLines.join("\n");
    out["contentsBase64"] = QString::fromLatin1(tailLines.join("\n").toUtf8().toBase64());

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opWriteBatch(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    
    QJsonArray filesArray = args.value("files").toArray();
    if (filesArray.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "files array is required"})";
        return result;
    }

    QList<QPair<QString, QByteArray>> files;
    for (const auto& item : filesArray) {
        QJsonObject fileObj = item.toObject();
        QString path = fileObj.value("path").toString();
        QByteArray contents;

        if (fileObj.contains("contentsBase64")) {
            contents = QByteArray::fromBase64(
                fileObj.value("contentsBase64").toString().toLatin1()
            );
        } else if (fileObj.contains("contents")) {
            contents = fileObj.value("contents").toString().toUtf8();
        }

        const QString safe = safePath(path);
        if (safe.isEmpty()) {
            result.isError = true;
            result.content = QString(R"({"error": "path traversal attack detected: %1"})").arg(path);
            return result;
        }

        files.append({safe, contents});
    }

    WriteFileOptions options;
    if (args.contains("options")) {
        QJsonObject opts = args.value("options").toObject();
        if (opts.contains("atomic")) {
            options.atomic = opts.value("atomic").toBool();
        }
        if (opts.contains("createDirs")) {
            options.createDirs = opts.value("createDirs").toBool();
        }
        if (opts.contains("lineEnding")) {
            options.lineEnding = opts.value("lineEnding").toString();
        }
        if (opts.contains("preserveMetadata")) {
            options.preserveMetadata = opts.value("preserveMetadata").toBool();
        }
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
    }

    auto fsResult = m_fileSystem->writeFileBatch(files, options, sandbox.get());

    if (fsResult.isOk()) {
        result.isError = false;
        QJsonObject output;
        output["success"] = true;
        output["filesWritten"] = static_cast<int>(files.size());
        result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
    } else {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(fsResult)).toJson(QJsonDocument::Compact);
    }

    return result;
}

FileSystemSandboxContext* CodexFileSystemTool::createSandboxContext(const QJsonObject& sandboxSpec) const
{
    auto sandbox = new FileSystemSandboxContext(
        sandboxSpec.value("workspaceId").toString()
    );

    if (sandboxSpec.contains("confineDir")) {
        sandbox->setConfineDir(sandboxSpec.value("confineDir").toString());
    }

    if (sandboxSpec.contains("allowedPaths")) {
        QJsonArray allowed = sandboxSpec.value("allowedPaths").toArray();
        for (const auto& path : allowed) {
            sandbox->addAllowedPath(path.toString());
        }
    }

    if (sandboxSpec.contains("deniedPaths")) {
        QJsonArray denied = sandboxSpec.value("deniedPaths").toArray();
        for (const auto& path : denied) {
            sandbox->addDeniedPath(path.toString());
        }
    }

    if (sandboxSpec.contains("canRead")) {
        sandbox->setCanRead(sandboxSpec.value("canRead").toBool());
    }
    if (sandboxSpec.contains("canWrite")) {
        sandbox->setCanWrite(sandboxSpec.value("canWrite").toBool());
    }
    if (sandboxSpec.contains("canDelete")) {
        sandbox->setCanDelete(sandboxSpec.value("canDelete").toBool());
    }
    if (sandboxSpec.contains("canCreateDirs")) {
        sandbox->setCanCreateDirs(sandboxSpec.value("canCreateDirs").toBool());
    }

    return sandbox;
}

QJsonObject CodexFileSystemTool::resultToJson(const FileSystemResult& result)
{
    QJsonObject obj;
    if (result.isErr()) {
        obj["error"] = result.message();
        obj["code"] = static_cast<int>(result.code());
    } else {
        obj["success"] = true;
    }
    return obj;
}
