#include "tools/CodexFileSystemTool.h"
#include "sandbox/SandboxManager.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QDateTime>
#include <QCryptographicHash>
#include <QSet>
#include <QRegularExpression>
#include <QProcess>
#include <QTemporaryFile>
#include <QTextStream>
#include <QDebug>
#include <functional>

namespace {

QString trimPatchHeaderPath(QString rawPath)
{
    rawPath = rawPath.trimmed();
    const int tab = rawPath.indexOf('\t');
    if (tab >= 0) rawPath = rawPath.left(tab);
    const int sp = rawPath.indexOf(' ');
    if (sp >= 0) rawPath = rawPath.left(sp);
    return rawPath.trimmed();
}

QString normalizePatchPath(QString rawPath)
{
    rawPath = trimPatchHeaderPath(rawPath);
    if (rawPath == "/dev/null") return rawPath;
    if (rawPath.startsWith("a/") || rawPath.startsWith("b/")) {
        rawPath = rawPath.mid(2);
    }
    return rawPath;
}

QStringList parseTouchedPaths(const QString& patchText)
{
    QStringList touched;
    const QStringList lines = patchText.split('\n');
    for (const QString& line : lines) {
        if (line.startsWith("--- ") || line.startsWith("+++ ")) {
            const QString path = normalizePatchPath(line.mid(4));
            if (path.isEmpty() || path == "/dev/null") {
                continue;
            }
            if (!touched.contains(path)) {
                touched << path;
            }
        }
    }
    return touched;
}

bool writeTextFile(const QString& path, const QString& text)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    QTextStream out(&file);
    out << text;
    return file.commit();
}

QString readTextFile(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll());
}

QString patchBackupRoot(const QString& workspaceRoot)
{
    return QDir(workspaceRoot).absoluteFilePath(".neurx/codex-patch-backups");
}

QString patchLastManifestPath(const QString& workspaceRoot)
{
    return QDir(patchBackupRoot(workspaceRoot)).absoluteFilePath("last/manifest.json");
}

bool ensurePatchBackup(const QString& workspaceRoot, const QStringList& touchedPaths, QString& backupId, QString& error)
{
    backupId = QDateTime::currentDateTimeUtc().toString("yyyyMMddhhmmsszzz");
    const QString root = QDir(patchBackupRoot(workspaceRoot)).absoluteFilePath("last");
    if (!QDir().mkpath(root)) {
        error = QStringLiteral("Failed to create patch backup directory.");
        return false;
    }

    QJsonArray entries;
    for (const QString& relPath : touchedPaths) {
        const QFileInfo info(QDir(workspaceRoot).absoluteFilePath(relPath));
        const QString absPath = info.absoluteFilePath();
        const bool existed = info.exists();
        const QString backupPath = QDir(root).absoluteFilePath(relPath);

        if (existed) {
            QDir().mkpath(QFileInfo(backupPath).absolutePath());
            QFile::remove(backupPath);
            if (!QFile::copy(absPath, backupPath)) {
                error = QStringLiteral("Failed to backup: %1").arg(relPath);
                return false;
            }
        }

        QJsonObject entry;
        entry["path"] = relPath;
        entry["backup_path"] = backupPath;
        entry["existed"] = existed;
        entries.append(entry);
    }

    QJsonObject manifest;
    manifest["backup_id"] = backupId;
    manifest["entries"] = entries;
    manifest["patch_time_utc"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    const QString manifestText = QString::fromUtf8(QJsonDocument(manifest).toJson(QJsonDocument::Indented));
    if (!writeTextFile(QDir(root).absoluteFilePath("manifest.json"), manifestText)) {
        error = QStringLiteral("Failed to write patch backup manifest.");
        return false;
    }
    if (!writeTextFile(patchLastManifestPath(workspaceRoot), manifestText)) {
        error = QStringLiteral("Failed to write last patch backup manifest.");
        return false;
    }

    return true;
}

bool restorePatchBackup(const QString& workspaceRoot, const QString& manifestPath, QString& error)
{
    const QString manifestText = readTextFile(manifestPath);
    if (manifestText.isEmpty()) {
        error = QStringLiteral("No backup manifest found.");
        return false;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(manifestText.toUtf8());
    if (!doc.isObject()) {
        error = QStringLiteral("Invalid patch backup manifest.");
        return false;
    }

    const QJsonArray entries = doc.object().value("entries").toArray();
    for (const auto& entryVal : entries) {
        const QJsonObject entry = entryVal.toObject();
        const QString relPath = entry.value("path").toString();
        const QString backupPath = entry.value("backup_path").toString();
        const bool existed = entry.value("existed").toBool();
        const QString absPath = QDir(workspaceRoot).absoluteFilePath(relPath);

        if (!existed) {
            QFile::remove(absPath);
            continue;
        }

        const QString backupText = readTextFile(backupPath);
        if (backupText.isEmpty() && !QFileInfo::exists(backupPath)) {
            error = QStringLiteral("Missing backup file: %1").arg(relPath);
            return false;
        }

        if (!writeTextFile(absPath, backupText)) {
            error = QStringLiteral("Failed to restore: %1").arg(relPath);
            return false;
        }
    }

    return true;
}

bool isGitRepo(const QString& root)
{
    QProcess proc;
    proc.setWorkingDirectory(root);
    proc.start("git", {"rev-parse", "--is-inside-work-tree"});
    if (!proc.waitForFinished(3000)) {
        proc.kill();
        return false;
    }
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        return false;
    }
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed() == "true";
}

} // namespace

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
                "enum": ["write_file", "create_file", "read_file", "read_to_end", "create_directory", "delete_file", "get_metadata", "stat_file", "hash_file", "chmod", "symlink", "touch", "truncate", "read_range", "tail", "write_batch", "exists", "list_directory", "find_files", "read_many_files", "read_tree", "search_in_files", "diff_file", "replace_in_file", "preview_patch", "apply_patch", "revert_last_patch", "move", "move_tree", "rename", "copy", "copy_tree", "append"],
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
            "maxDepth": {
                "type": "integer",
                "description": "Maximum recursion depth for read_tree"
            },
            "includeContents": {
                "type": "boolean",
                "description": "Include file contents for read_tree"
            },
            "pattern": {
                "type": "string",
                "description": "Text or regular expression pattern for search_in_files"
            },
            "regex": {
                "type": "boolean",
                "description": "Treat pattern as regular expression"
            },
            "caseSensitive": {
                "type": "boolean",
                "description": "Case-sensitive search"
            },
            "contextLines": {
                "type": "integer",
                "description": "Number of context lines to include around each match"
            },
            "wholeWord": {
                "type": "boolean",
                "description": "Match whole words only"
            },
            "maxMatches": {
                "type": "integer",
                "description": "Maximum number of matches to return"
            },
            "destination": {
                "type": "string",
                "description": "Destination path for move/copy/rename"
            },
            "otherPath": {
                "type": "string",
                "description": "Second path for diff operations"
            },
            "old_string": {
                "type": "string",
                "description": "Text to replace in replace_in_file"
            },
            "new_string": {
                "type": "string",
                "description": "Replacement text for replace_in_file"
            },
            "allowMultiple": {
                "type": "boolean",
                "description": "Replace all occurrences instead of exactly one"
            },
            "replaceRegex": {
                "type": "boolean",
                "description": "Treat old_string as a regular expression for replace_in_file"
            },
            "replaceCaseSensitive": {
                "type": "boolean",
                "description": "Use case-sensitive matching for replace_in_file"
            },
            "patch": {
                "type": "string",
                "description": "Unified diff patch for preview_patch/apply_patch"
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
    } else if (operation == "read_to_end") {
        return opReadToEndFile(callId, args);
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
    } else if (operation == "read_tree") {
        return opReadTree(callId, args);
    } else if (operation == "search_in_files") {
        return opSearchInFiles(callId, args);
    } else if (operation == "diff_file") {
        return opDiffFile(callId, args);
    } else if (operation == "replace_in_file") {
        return opReplaceInFile(callId, args);
    } else if (operation == "preview_patch") {
        return opPreviewPatch(callId, args);
    } else if (operation == "apply_patch") {
        return opApplyPatch(callId, args);
    } else if (operation == "revert_last_patch") {
        return opRevertLastPatch(callId, args);
    } else if (operation == "move") {
        return opMoveFile(callId, args);
    } else if (operation == "move_tree") {
        return opMoveTree(callId, args);
    } else if (operation == "rename") {
        return opRenameFile(callId, args);
    } else if (operation == "copy") {
        return opCopyFile(callId, args);
    } else if (operation == "copy_tree") {
        return opCopyTree(callId, args);
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

ToolResult CodexFileSystemTool::opReadTree(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    QString path = args.value("path").toString();
    if (path.isEmpty()) {
        path = QStringLiteral(".");
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error":"path traversal attack detected"})";
        return result;
    }

    const bool includeHidden = args.value("includeHiddenFiles").toBool(false);
    const bool includeContents = args.value("includeContents").toBool(false);
    const int maxDepth = qMax(-1, args.value("maxDepth").toInt(-1));
    const int maxFiles = qMax(1, args.value("maxFiles").toInt(1000));

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
    }

    int filesSeen = 0;
    bool truncated = false;

    std::function<QJsonObject(const QString&, int)> buildNode;
    buildNode = [&](const QString& absPath, int depth) -> QJsonObject {
        QFileInfo info(absPath);
        QJsonObject node;
        node["name"] = info.fileName().isEmpty() ? info.absoluteFilePath() : info.fileName();
        node["path"] = absPath;
        node["relativePath"] = workspaceRelativePath(absPath);
        node["exists"] = info.exists();
        node["isDir"] = info.isDir();
        node["isFile"] = info.isFile();
        node["size"] = static_cast<qint64>(info.size());
        node["modified"] = info.lastModified().toString(Qt::ISODate);

        if (!info.exists()) {
            node["error"] = "Path does not exist";
            return node;
        }

        if (info.isDir()) {
            if (maxDepth >= 0 && depth >= maxDepth) {
                node["truncated"] = true;
                return node;
            }

            QDir dir(absPath);
            QDir::Filters filters = QDir::NoDotAndDotDot | QDir::AllEntries;
            if (includeHidden) {
                filters |= QDir::Hidden;
            }

            QJsonArray children;
            const QFileInfoList entries = dir.entryInfoList(filters, QDir::DirsFirst | QDir::Name);
            for (const QFileInfo& entry : entries) {
                if (filesSeen >= maxFiles) {
                    truncated = true;
                    node["truncated"] = true;
                    break;
                }
                children.append(buildNode(entry.absoluteFilePath(), depth + 1));
            }
            node["children"] = children;
            return node;
        }

        ++filesSeen;
        if (includeContents) {
            QByteArray contents;
            const auto readResult = m_fileSystem->readFile(absPath, contents, sandbox.get());
            if (readResult.isOk()) {
                node["contents"] = QString::fromUtf8(contents);
                node["contentsBase64"] = QString::fromLatin1(contents.toBase64());
            } else {
                node["readError"] = readResult.message();
                node["readCode"] = static_cast<int>(readResult.code());
            }
        }

        return node;
    };

    QJsonObject out;
    out["path"] = path;
    out["root"] = buildNode(safe, 0);
    out["filesSeen"] = filesSeen;
    out["truncated"] = truncated;
    out["includeContents"] = includeContents;
    out["maxDepth"] = maxDepth;

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opSearchInFiles(const QString& callId, const QJsonObject& args)
{
    ToolResult result;

    const QString pattern = args.value("pattern").toString();
    if (pattern.isEmpty()) {
        result.isError = true;
        result.content = R"({"error":"pattern is required"})";
        return result;
    }

    const QJsonArray include = args.value("include").toArray();
    QStringList patterns;
    patterns.reserve(include.size());
    for (const auto& value : include) {
        const QString p = value.toString();
        if (!p.isEmpty()) {
            patterns.append(p);
        }
    }
    if (patterns.isEmpty()) {
        patterns << "**/*";
    }

    QString baseDir = args.value("base_dir").toString();
    if (baseDir.isEmpty()) {
        baseDir = m_root.absolutePath();
    } else {
        const QString safeBase = safePath(baseDir);
        if (safeBase.isEmpty()) {
            result.isError = true;
            result.content = R"({"error":"path traversal attack detected"})";
            return result;
        }
        baseDir = safeBase;
    }

    const bool includeHidden = args.value("includeHiddenFiles").toBool(false);
    bool useRegex = args.value("regex").toBool(false);
    const bool caseSensitive = args.value("caseSensitive").toBool(false);
    const bool wholeWord = args.value("wholeWord").toBool(false);
    const int contextLines = qMax(0, args.value("contextLines").toInt(0));
    const int maxMatches = qMax(1, args.value("maxMatches").toInt(200));

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
    }

    const QStringList files = collectFilesByPatterns(baseDir, patterns, includeHidden, maxMatches);
    QRegularExpression regex;
    if (useRegex) {
        QRegularExpression::PatternOptions options = QRegularExpression::NoPatternOption;
        if (!caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }
        regex = QRegularExpression(pattern, options);
        if (!regex.isValid()) {
            result.isError = true;
            result.content = QString(R"({"error":"Invalid regular expression: %1"})").arg(regex.errorString());
            return result;
        }
    } else {
        if (wholeWord) {
            const QString wholeWordPattern = QStringLiteral(R"(\b%1\b)").arg(QRegularExpression::escape(pattern));
            regex = QRegularExpression(wholeWordPattern,
                                       caseSensitive ? QRegularExpression::NoPatternOption
                                                     : QRegularExpression::CaseInsensitiveOption);
            useRegex = true;
        }
    }

    QJsonArray matches;
    int filesSearched = 0;

    for (const QString& filePath : files) {
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        const QString text = QString::fromUtf8(file.readAll());
        file.close();
        ++filesSearched;

        const QStringList lines = text.split('\n');
        for (int i = 0; i < lines.size() && matches.size() < maxMatches; ++i) {
            const QString& line = lines.at(i);
            bool matched = false;
            int column = -1;

            if (useRegex) {
                const auto match = regex.match(line);
                matched = match.hasMatch();
                if (matched) {
                    column = match.capturedStart() + 1;
                }
            } else {
                QString haystack = line;
                QString needle = pattern;
                if (!caseSensitive) {
                    haystack = haystack.toLower();
                    needle = needle.toLower();
                }
                column = haystack.indexOf(needle) + 1;
                matched = column > 0;
            }

            if (!matched) {
                continue;
            }

            QJsonObject matchObj;
            matchObj["path"] = filePath;
            matchObj["relativePath"] = workspaceRelativePath(filePath);
            matchObj["lineNumber"] = i + 1;
            matchObj["columnNumber"] = column;
            matchObj["line"] = line;

            if (contextLines > 0) {
                const int beforeStart = qMax(0, i - contextLines);
                const int afterEnd = qMin(lines.size(), i + contextLines + 1);
                matchObj["beforeContext"] = lines.mid(beforeStart, i - beforeStart).join("\n");
                matchObj["afterContext"] = lines.mid(i + 1, afterEnd - (i + 1)).join("\n");
            }

            matches.append(matchObj);
        }

        if (matches.size() >= maxMatches) {
            break;
        }
    }

    QJsonObject out;
    out["base_dir"] = baseDir;
    out["pattern"] = pattern;
    out["regex"] = useRegex;
    out["caseSensitive"] = caseSensitive;
    out["wholeWord"] = wholeWord;
    out["filesSearched"] = filesSearched;
    out["matches"] = matches;
    out["matchCount"] = matches.size();

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opDiffFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString leftPath = args.value("path").toString();
    QString rightPath = args.value("destination").toString();
    if (rightPath.isEmpty()) {
        rightPath = args.value("otherPath").toString();
    }

    if (leftPath.isEmpty() || rightPath.isEmpty()) {
        result.isError = true;
        result.content = R"({"error": "path and destination/otherPath are required"})";
        return result;
    }

    const QString safeLeft = safePath(leftPath);
    const QString safeRight = safePath(rightPath);
    if (safeLeft.isEmpty() || safeRight.isEmpty()) {
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

    QByteArray leftBytes;
    QByteArray rightBytes;
    auto leftRes = m_fileSystem->readFile(safeLeft, leftBytes, sandbox.get());
    if (leftRes.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(leftRes)).toJson(QJsonDocument::Compact);
        return result;
    }

    auto rightRes = m_fileSystem->readFile(safeRight, rightBytes, sandbox.get());
    if (rightRes.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(rightRes)).toJson(QJsonDocument::Compact);
        return result;
    }

    const QStringList leftLines = QString::fromUtf8(leftBytes).split('\n', Qt::KeepEmptyParts);
    const QStringList rightLines = QString::fromUtf8(rightBytes).split('\n', Qt::KeepEmptyParts);
    const int maxLines = qMax(leftLines.size(), rightLines.size());

    QJsonArray changes;
    int added = 0;
    int removed = 0;
    int changed = 0;

    for (int i = 0; i < maxLines; ++i) {
        const bool hasLeft = i < leftLines.size();
        const bool hasRight = i < rightLines.size();
        const QString leftLine = hasLeft ? leftLines.at(i) : QString();
        const QString rightLine = hasRight ? rightLines.at(i) : QString();

        if (hasLeft && hasRight && leftLine == rightLine) {
            continue;
        }

        QJsonObject change;
        change["lineNumber"] = i + 1;
        if (!hasLeft) {
            change["type"] = "added";
            change["right"] = rightLine;
            ++added;
        } else if (!hasRight) {
            change["type"] = "removed";
            change["left"] = leftLine;
            ++removed;
        } else {
            change["type"] = "changed";
            change["left"] = leftLine;
            change["right"] = rightLine;
            ++changed;
        }
        changes.append(change);
    }

    QJsonObject out;
    out["leftPath"] = leftPath;
    out["rightPath"] = rightPath;
    out["leftSize"] = static_cast<int>(leftBytes.size());
    out["rightSize"] = static_cast<int>(rightBytes.size());
    out["added"] = added;
    out["removed"] = removed;
    out["changed"] = changed;
    out["different"] = !changes.isEmpty();
    out["changes"] = changes;

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opReplaceInFile(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString path = args.value("path").toString();
    const QString oldString = args.value("old_string").toString();
    const QString newString = args.value("new_string").toString();
    const bool allowMultiple = args.value("allowMultiple").toBool(false);
    const bool useRegex = args.value("replaceRegex").toBool(false);
    const bool caseSensitive = args.value("replaceCaseSensitive").toBool(false);

    if (path.isEmpty() || oldString.isEmpty()) {
        result.isError = true;
        result.content = R"({"error":"path and old_string are required"})";
        return result;
    }

    const QString safe = safePath(path);
    if (safe.isEmpty()) {
        result.isError = true;
        result.content = R"({"error":"path traversal attack detected"})";
        return result;
    }

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && (!sandbox->canRead() || !sandbox->canWrite())) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies replace access"})";
        return result;
    }

    QByteArray bytes;
    const auto readResult = m_fileSystem->readFile(safe, bytes, sandbox.get());
    if (readResult.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(readResult)).toJson(QJsonDocument::Compact);
        return result;
    }

    const QString original = QString::fromUtf8(bytes);
    QString updated = original;
    int replacements = 0;

    if (useRegex) {
        QRegularExpression::PatternOptions options = QRegularExpression::NoPatternOption;
        if (!caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }

        const QRegularExpression rx(oldString, options);
        if (!rx.isValid()) {
            result.isError = true;
            result.content = QString(R"({"error":"Invalid regular expression: %1"})").arg(rx.errorString());
            return result;
        }

        auto it = rx.globalMatch(original);
        while (it.hasNext()) {
            it.next();
            ++replacements;
        }

        if (replacements == 0) {
            result.isError = true;
            result.content = R"({"error":"No matches found"})";
            return result;
        }
        if (!allowMultiple && replacements > 1) {
            result.isError = true;
            result.content = QString(R"({"error":"Found %1 matches, but allowMultiple is false"})").arg(replacements);
            return result;
        }

        updated.replace(rx, newString);
    } else {
        Qt::CaseSensitivity cs = caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;
        if (caseSensitive) {
            replacements = original.count(oldString, Qt::CaseSensitive);
        } else {
            replacements = original.count(oldString, Qt::CaseInsensitive);
        }

        if (replacements == 0) {
            result.isError = true;
            result.content = R"({"error":"No matches found"})";
            return result;
        }
        if (!allowMultiple && replacements > 1) {
            result.isError = true;
            result.content = QString(R"({"error":"Found %1 matches, but allowMultiple is false"})").arg(replacements);
            return result;
        }

        Q_UNUSED(cs);
        updated.replace(oldString, newString, caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive);
    }

    QFile file(safe);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to open file for write: %1"})").arg(file.errorString());
        return result;
    }
    if (file.write(updated.toUtf8()) < 0) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to write updated file: %1"})").arg(file.errorString());
        return result;
    }
    file.close();

    QJsonObject out;
    out["success"] = true;
    out["path"] = path;
    out["replacements"] = replacements;
    out["regex"] = useRegex;
    out["caseSensitive"] = caseSensitive;
    out["allowMultiple"] = allowMultiple;

    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opPreviewPatch(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString patchText = args.value("patch").toString();
    if (patchText.trimmed().isEmpty()) {
        result.isError = true;
        result.content = R"({"error":"patch is required"})";
        return result;
    }

    if (!isGitRepo(m_root.absolutePath())) {
        result.isError = true;
        result.content = R"({"error":"workspace is not a git repository"})";
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

    const QStringList touchedPaths = parseTouchedPaths(patchText);
    QJsonObject out;
    out["patchLines"] = patchText.split('\n').size();
    out["touchedPaths"] = QJsonArray::fromStringList(touchedPaths);
    out["isGitRepo"] = true;

    QTemporaryFile tmp(QDir(m_root.absolutePath()).absoluteFilePath(".neurx-patch-XXXXXX.diff"));
    if (!tmp.open()) {
        result.isError = true;
        result.content = R"({"error":"failed to create temporary patch file"})";
        return result;
    }
    tmp.write(patchText.toUtf8());
    tmp.flush();

    QProcess proc;
    proc.setWorkingDirectory(m_root.absolutePath());
    proc.start("git", {"apply", "--check", "--verbose", tmp.fileName()});
    if (!proc.waitForFinished(30000)) {
        proc.kill();
        result.isError = true;
        result.content = R"({"error":"git apply preview timed out"})";
        return result;
    }

    const QString output = QString::fromUtf8(proc.readAllStandardOutput()) + QString::fromUtf8(proc.readAllStandardError());
    if (proc.exitCode() != 0 || proc.exitStatus() != QProcess::NormalExit) {
        result.isError = true;
        out["error"] = output.trimmed().isEmpty() ? QStringLiteral("Patch preview failed") : output.trimmed();
        result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
        return result;
    }

    out["preview"] = true;
    out["message"] = "Patch is applicable.";
    if (!output.trimmed().isEmpty()) {
        out["output"] = output.trimmed();
    }
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opApplyPatch(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString patchText = args.value("patch").toString();
    if (patchText.trimmed().isEmpty()) {
        result.isError = true;
        result.content = R"({"error":"patch is required"})";
        return result;
    }

    if (!isGitRepo(m_root.absolutePath())) {
        result.isError = true;
        result.content = R"({"error":"workspace is not a git repository"})";
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

    const QStringList touchedPaths = parseTouchedPaths(patchText);
    if (sandbox && sandbox->shouldRunInSandbox()) {
        for (const QString& relPath : touchedPaths) {
            const QString safe = safePath(relPath);
            if (safe.isEmpty()) {
                result.isError = true;
                result.content = QString(R"({"error":"path traversal attack detected: %1"})").arg(relPath);
                return result;
            }
        }
    }

    QString backupId;
    QString backupError;
    if (!ensurePatchBackup(m_root.absolutePath(), touchedPaths, backupId, backupError)) {
        result.isError = true;
        result.content = QString(R"({"error":"%1"})").arg(backupError);
        return result;
    }

    QTemporaryFile tmp(QDir(m_root.absolutePath()).absoluteFilePath(".neurx-patch-XXXXXX.diff"));
    if (!tmp.open()) {
        result.isError = true;
        result.content = R"({"error":"failed to create temporary patch file"})";
        return result;
    }
    tmp.write(patchText.toUtf8());
    tmp.flush();

    QProcess proc;
    proc.setWorkingDirectory(m_root.absolutePath());
    proc.start("git", {"apply", "--whitespace=nowarn", tmp.fileName()});
    if (!proc.waitForFinished(30000)) {
        proc.kill();
        result.isError = true;
        result.content = R"({"error":"git apply timed out"})";
        return result;
    }

    const QString output = QString::fromUtf8(proc.readAllStandardOutput()) + QString::fromUtf8(proc.readAllStandardError());
    if (proc.exitCode() != 0 || proc.exitStatus() != QProcess::NormalExit) {
        QString restoreError;
        if (!restorePatchBackup(m_root.absolutePath(), patchLastManifestPath(m_root.absolutePath()), restoreError)) {
            result.isError = true;
            QJsonObject out;
            out["error"] = output.trimmed().isEmpty() ? QStringLiteral("Patch application failed") : output.trimmed();
            out["rollbackError"] = restoreError;
            result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
            return result;
        }
        result.isError = true;
        QJsonObject out;
        out["error"] = output.trimmed().isEmpty() ? QStringLiteral("Patch application failed") : output.trimmed();
        result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
        return result;
    }

    QJsonObject out;
    out["success"] = true;
    out["patchApplied"] = true;
    out["backupId"] = backupId;
    out["touchedPaths"] = QJsonArray::fromStringList(touchedPaths);
    if (!output.trimmed().isEmpty()) {
        out["output"] = output.trimmed();
    }
    result.isError = false;
    result.content = QJsonDocument(out).toJson(QJsonDocument::Compact);
    return result;
}

ToolResult CodexFileSystemTool::opRevertLastPatch(const QString& callId, const QJsonObject& args)
{
    Q_UNUSED(args);
    ToolResult result;
    const QString manifestPath = patchLastManifestPath(m_root.absolutePath());
    if (!QFileInfo::exists(manifestPath)) {
        result.isError = true;
        result.content = R"({"error":"No patch backup manifest found"})";
        return result;
    }

    QString error;
    if (!restorePatchBackup(m_root.absolutePath(), manifestPath, error)) {
        result.isError = true;
        result.content = QString(R"({"error":"%1"})").arg(error);
        return result;
    }

    QJsonObject out;
    out["success"] = true;
    out["restored"] = true;
    out["manifestPath"] = manifestPath;

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
    if (sandbox && sandbox->shouldRunInSandbox() && (!sandbox->canRead() || !sandbox->canWrite() || !sandbox->canDelete())) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies move access"})";
        return result;
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

ToolResult CodexFileSystemTool::opMoveTree(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString src = args.value("path").toString();
    QString dst = args.value("destination").toString();
    if (dst.isEmpty()) {
        dst = args.value("otherPath").toString();
    }

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
    if (sandbox && sandbox->shouldRunInSandbox() && (!sandbox->canRead() || !sandbox->canWrite() || !sandbox->canDelete())) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies move access"})";
        return result;
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

    if (!moveRecursive(safeSrc, safeDst)) {
        result.isError = true;
        result.content = QString(R"({"error":"Failed to move tree %1 -> %2"})").arg(src, dst);
        return result;
    }

    QJsonObject out;
    out["success"] = true;
    out["from"] = src;
    out["to"] = dst;
    out["recursive"] = true;

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
    if (sandbox && sandbox->shouldRunInSandbox() && (!sandbox->canRead() || !sandbox->canWrite())) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies copy access"})";
        return result;
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

ToolResult CodexFileSystemTool::opCopyTree(const QString& callId, const QJsonObject& args)
{
    ToolResult result;
    const QString src = args.value("path").toString();
    QString dst = args.value("destination").toString();
    if (dst.isEmpty()) {
        dst = args.value("otherPath").toString();
    }

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
    if (sandbox && sandbox->shouldRunInSandbox() && (!sandbox->canRead() || !sandbox->canWrite())) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies copy access"})";
        return result;
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
        result.content = QString(R"({"error":"Failed to copy tree %1 -> %2"})").arg(src, dst);
        return result;
    }

    QJsonObject out;
    out["success"] = true;
    out["from"] = src;
    out["to"] = dst;
    out["recursive"] = true;

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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canWrite()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies write access"})";
        return result;
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
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

ToolResult CodexFileSystemTool::opReadToEndFile(const QString& callId, const QJsonObject& args)
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
    }

    QByteArray contents;
    const auto fsResult = m_fileSystem->readFile(safe, contents, sandbox.get());
    if (fsResult.isErr()) {
        result.isError = true;
        result.content = QJsonDocument(resultToJson(fsResult)).toJson(QJsonDocument::Compact);
        return result;
    }

    QJsonObject output;
    output["success"] = true;
    output["path"] = path;
    output["size"] = static_cast<int>(contents.size());
    output["contents"] = QString::fromUtf8(contents);
    output["contentsBase64"] = QString::fromLatin1(contents.toBase64());

    result.isError = false;
    result.content = QJsonDocument(output).toJson(QJsonDocument::Compact);
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canCreateDirs()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies directory creation"})";
        return result;
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canDelete()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies delete access"})";
        return result;
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canRead()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies read access"})";
        return result;
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canWrite()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies write access"})";
        return result;
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

    std::unique_ptr<FileSystemSandboxContext> sandbox;
    if (args.contains("sandbox")) {
        sandbox.reset(createSandboxContext(args.value("sandbox").toObject()));
    }
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canWrite()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies write access"})";
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
    if (sandbox && sandbox->shouldRunInSandbox() && !sandbox->canWrite()) {
        result.isError = true;
        result.content = R"({"error":"Sandbox policy denies write access"})";
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
