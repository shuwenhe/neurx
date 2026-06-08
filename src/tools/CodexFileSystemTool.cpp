#include "tools/CodexFileSystemTool.h"
#include "sandbox/SandboxManager.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QDebug>

CodexFileSystemTool::CodexFileSystemTool(
    const QString& workspaceRoot,
    QObject* parent)
    : BaseTool(parent)
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
                "enum": ["write_file", "read_file", "create_directory", "delete_file", "get_metadata", "write_batch", "exists", "list_directory", "move", "copy", "append"],
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
    } else if (operation == "read_file") {
        return opReadFile(callId, args);
    } else if (operation == "create_directory") {
        return opCreateDirectory(callId, args);
    } else if (operation == "delete_file") {
        return opDeleteFile(callId, args);
    } else if (operation == "get_metadata") {
        return opGetMetadata(callId, args);
    } else if (operation == "write_batch") {
        return opWriteBatch(callId, args);
    } else if (operation == "exists") {
        return opExists(callId, args);
    } else if (operation == "list_directory") {
        return opListDirectory(callId, args);
    } else if (operation == "move") {
        return opMoveFile(callId, args);
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
    return QString("Codex file system %1: %2").arg(operation, path);
}

void CodexFileSystemTool::setSandboxManager(SandboxManager* manager)
{
    if (m_fileSystem) {
        m_fileSystem->setSandboxManager(manager);
    }
}

// Private implementation

ToolResult CodexFileSystemTool::opWriteFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
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

    // Perform write
    auto fsResult = m_fileSystem->writeFile(path, contents, options, sandbox.get());

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

ToolResult CodexFileSystemTool::opExists(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    bool exists = m_fileSystem->exists(path, sandbox.get());

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

    if (path.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path is required"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QJsonObject meta = m_fileSystem->getMetadata(path, sandbox.get());
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

    QDir dir(path);
    QFileInfoList list = dir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries, QDir::DirsFirst | QDir::Name);

    QJsonArray entries;
    for (const QFileInfo& info : list) {
        QJsonObject item;
        item["name"] = info.fileName();
        item["path"] = info.absoluteFilePath();
        item["isFile"] = info.isFile();
        item["isDir"] = info.isDir();
        item["size"] = static_cast<qint64>(info.size());
        item["modified"] = info.lastModified().toString(Qt::ISODate);
        entries.append(item);
    }

    QJsonObject out;
    out["path"] = path;
    out["entries"] = entries;
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

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    // Check source metadata
    QJsonObject srcMeta = m_fileSystem->getMetadata(src, sandbox.get());
    if (srcMeta.contains("error")) {
        result.isError = true;
        result.content = QJsonDocument(srcMeta).toJson(QJsonDocument::Compact);
        return result;
    }

    // Try atomic rename
    QFile srcFile(src);
    bool ok = srcFile.rename(dst);
    if (!ok) {
        // Fallback to copy + delete
        if (!QFile::copy(src, dst)) {
            result.isError = true;
            QJsonObject out;
            out["error"] = QString("Failed to move %1 -> %2").arg(src, dst);
            result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
            return result;
        }
        if (!QFile::remove(src)) {
            // Best-effort: report copy success but delete failed
            result.isError = true;
            QJsonObject out;
            out["error"] = QString("Copied to %1 but failed to remove source %2").arg(dst, src);
            result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
            return result;
        }
    }

    QJsonObject out;
    out["success"] = true;
    out["from"] = src;
    out["to"] = dst;
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
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

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QJsonObject srcMeta = m_fileSystem->getMetadata(src, sandbox.get());
    if (srcMeta.contains("error")) {
        result.isError = true;
        result.content = QJsonDocument(srcMeta).toJson(QJsonDocument::Compact);
        return result;
    }

    if (!QFile::copy(src, dst)) {
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

    // Read existing content if present
    QByteArray existing;
    auto readRes = m_fileSystem->readFile(path, existing, sandbox.get());
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
    auto writeRes = m_fileSystem->writeFile(path, finalContents, options, sandbox.get());
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

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    QByteArray contents;
    auto fsResult = m_fileSystem->readFile(path, contents, sandbox.get());

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

    auto fsResult = m_fileSystem->createDirectory(path, options, sandbox.get());

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

    bool deleteRecursive = args.value("deleteRecursive").toBool(false);

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    auto fsResult = m_fileSystem->deleteFile(path, deleteRecursive, sandbox.get());

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

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }

    auto metadata = m_fileSystem->getMetadata(path, sandbox.get());

    result.isError = metadata.contains("error");
    result.content = QJsonDocument(metadata).toJson(QJsonDocument::Compact);

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

        files.append({path, contents});
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
