#include "tools/FileSystemTool.h"
#include "tools/CheckpointManager.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>

namespace {

bool isPathInsideWorkspace(const QString &path, const QString &workspaceRoot)
{
    const QString cleanRoot = QDir::cleanPath(workspaceRoot);
    const QString cleanPath = QDir::cleanPath(path);
    if (cleanRoot.isEmpty() || cleanPath.isEmpty())
        return false;

    if (cleanPath == cleanRoot)
        return true;

    const QString relative = QDir(cleanRoot).relativeFilePath(cleanPath);
    return !relative.isEmpty()
        && !relative.startsWith(QStringLiteral(".."))
        && !QDir::isAbsolutePath(relative);
}

bool writeFileAtomically(const QString &path, const QString &content, QString *error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        if (error)
            *error = file.errorString();
        return false;
    }

    QTextStream out(&file);
    out << content;
    out.flush();
    if (!file.commit()) {
        if (error)
            *error = file.errorString();
        return false;
    }
    return true;
}

} // namespace

static bool isWriteOperationName(const QString &operation)
{
    return operation == QStringLiteral("write_file")
        || operation == QStringLiteral("create_file")
        || operation == QStringLiteral("delete_file")
        || operation == QStringLiteral("move_file");
}

FileSystemTool::FileSystemTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
    , m_checkpointManager(std::make_unique<CheckpointManager>(workspaceRoot))
    , m_smartFileCreator(std::make_unique<SmartFileCreator>(workspaceRoot))
{}

QJsonObject FileSystemTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "operation": {
                "type": "string",
                "enum": ["read_file","write_file","list_directory","create_file","delete_file","move_file"],
                "description": "The file operation to perform."
            },
            "path":    { "type": "string", "description": "Relative path from workspace root." },
            "content": { "type": "string", "description": "File content (for write/create)." },
            "mode": { "type": "string", "enum": ["simple","smart","template","batch","structure"], "description": "Enhanced create_file mode." },
            "intent": { "type": "string", "description": "What the new file should contain (smart mode)." },
            "template": { "type": "string", "description": "Template name for create_file." },
            "template_vars": { "type": "object", "description": "Variables for the selected template." },
            "related_files": { "type": "array", "items": { "type": "string" }, "description": "Related workspace files to guide smart creation." },
            "overwrite": { "type": "boolean", "description": "Allow replacing an existing file during create_file." },
            "create_dirs": { "type": "boolean", "description": "Create missing parent directories during create_file." },
            "files": { "type": "array", "description": "Batch or structure file specs for create_file.", "items": { "type": "object" } },
            "structure_intent": { "type": "string", "description": "High-level intent for a created file structure." },
            "generate_missing": { "type": "boolean", "description": "Whether create_file structure mode may add inferred files." },
            "destination": { "type": "string", "description": "Destination path (for move)." },
            "start_line": { "type": "integer", "description": "First line to read (1-based, inclusive)." },
            "end_line":   { "type": "integer", "description": "Last line to read (1-based, inclusive)." }
        },
        "required": ["operation"]
    })").object();
}

ToolResult FileSystemTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString op = args["operation"].toString();
    if (m_sandboxManager && op != "create_file") {
        const QString path = args["path"].toString();
        const QString absPath = safePath(path);
        if (absPath.isEmpty())
            return {callId, name(), true, "Path traversal denied."};
        if (m_sandboxManager->isProtectedMetadata(absPath))
            return {callId, name(), true, "Protected metadata access denied: " + path};
        const FileSystemAccessMode mode = isWriteOperationName(op)
            ? FileSystemAccessMode::Write
            : FileSystemAccessMode::Read;
        if (!m_sandboxManager->canAccess(absPath, mode))
            return {callId, name(), true, "Sandbox policy denied access: " + path};
        if (m_sandboxManager->isReadOnlyMode() && isWriteOperationName(op))
            return {callId, name(), true, "Read-only sandbox mode blocks file writes."};
    }
    if (op == "read_file")       return opReadFile(callId, args);
    if (op == "write_file")      return opWriteFile(callId, args);
    if (op == "list_directory")  return opListDir(callId, args);
    if (op == "create_file")     return opCreateFile(callId, args);
    if (op == "delete_file")     return opDeleteFile(callId, args);
    if (op == "move_file")       return opMoveFile(callId, args);

    return {callId, name(), true, "Unknown operation: " + op};
}

QString FileSystemTool::summary(const QJsonObject &args) const
{
    return args["operation"].toString() + " " + args["path"].toString();
}

bool FileSystemTool::isWriteOperation(const QString &operation) const
{
    return isWriteOperationName(operation);
}

void FileSystemTool::setSandboxManager(SandboxManager *manager)
{
    m_sandboxManager = manager;
    if (m_smartFileCreator)
        m_smartFileCreator->setSandboxManager(manager);
}

QString FileSystemTool::safePath(const QString &rel) const
{
    if (rel.trimmed().isEmpty())
        return {};
    const QString abs = QDir::cleanPath(m_root.absoluteFilePath(rel));
    if (!isPathInsideWorkspace(abs, m_root.absolutePath()))
        return {};
    return abs;
}

QString FileSystemTool::workspaceRelativePath(const QString &relOrAbsPath) const
{
    const QString abs = safePath(relOrAbsPath);
    if (abs.isEmpty())
        return {};
    return m_root.relativeFilePath(abs);
}

QString FileSystemTool::checkpointPaths(const QStringList &paths, const QString &description) const
{
    if (!m_checkpointManager || !m_checkpointManager->isAvailable())
        return {};

    QStringList relPaths;
    for (const QString &path : paths) {
        const QString rel = workspaceRelativePath(path);
        if (!rel.isEmpty() && QFileInfo::exists(m_root.absoluteFilePath(rel)) && !relPaths.contains(rel))
            relPaths.append(rel);
    }

    if (relPaths.isEmpty())
        return {};

    return m_checkpointManager->checkpoint(relPaths, description);
}

ToolResult FileSystemTool::opReadFile(const QString &callId, const QJsonObject &args)
{
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
    if (m_sandboxManager && !m_sandboxManager->canAccess(path, FileSystemAccessMode::Read))
        return {callId, name(), true, "Sandbox policy denied read access."};

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {callId, name(), true, "Cannot open: " + f.errorString()};

    QTextStream in(&f);
    const int startLine = args.value("start_line").toInt(1);
    const int endLine   = args.value("end_line").toInt(INT_MAX);

    QString result;
    int lineNum = 0;
    while (!in.atEnd()) {
        ++lineNum;
        const QString line = in.readLine();
        if (lineNum < startLine) continue;
        if (lineNum > endLine)   break;
        result += QString::number(lineNum) + "\t" + line + "\n";
    }
    return {callId, name(), false, result};
}

ToolResult FileSystemTool::opWriteFile(const QString &callId, const QJsonObject &args)
{
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
    if (m_sandboxManager && !m_sandboxManager->canAccess(path, FileSystemAccessMode::Write))
        return {callId, name(), true, "Sandbox policy denied write access."};
    const QString checkpointId = checkpointPaths({args["path"].toString()},
                                                 QStringLiteral("file_system write %1").arg(args["path"].toString()));

    QFileInfo fi(path);
    m_root.mkpath(fi.dir().absolutePath());

    QString error;
    if (!writeFileAtomically(path, args["content"].toString(), &error))
        return {callId, name(), true, "Cannot write: " + error};

    QString result = "Written: " + args["path"].toString();
    if (!checkpointId.isEmpty())
        result += "\nCheckpoint: " + checkpointId;
    return {callId, name(), false, result};
}

ToolResult FileSystemTool::opListDir(const QString &callId, const QJsonObject &args)
{
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
    if (m_sandboxManager && !m_sandboxManager->canAccess(path, FileSystemAccessMode::Read))
        return {callId, name(), true, "Sandbox policy denied read access."};

    QDir dir(path);
    if (!dir.exists()) return {callId, name(), true, "Directory not found."};

    QStringList entries;
    for (const auto &e : dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot,
                                           QDir::DirsFirst | QDir::Name)) {
        entries << (e.isDir() ? "[DIR]  " : "[FILE] ") + e.fileName()
                       + (e.isFile() ? QString("  (%1 B)").arg(e.size()) : "");
    }
    return {callId, name(), false, entries.join("\n")};
}

ToolResult FileSystemTool::opCreateFile(const QString &callId, const QJsonObject &args)
{
    const bool hasEnhancedArgs = args.contains("mode")
        || args.contains("intent")
        || args.contains("template")
        || args.contains("template_vars")
        || args.contains("related_files")
        || args.contains("files")
        || args.contains("structure_intent")
        || args.contains("overwrite")
        || args.contains("create_dirs")
        || args.contains("generate_missing");

    if (!hasEnhancedArgs && !args.contains("content")) {
        const QString path = safePath(args["path"].toString());
        if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
        if (QFile::exists(path)) return {callId, name(), true, "File already exists."};
        return opWriteFile(callId, args);
    }

    QJsonObject smartArgs;
    if (args.contains("mode")) smartArgs["mode"] = args.value("mode");
    if (args.contains("path")) smartArgs["path"] = args.value("path");
    if (args.contains("content")) smartArgs["content"] = args.value("content");
    if (args.contains("intent")) smartArgs["intent"] = args.value("intent");
    if (args.contains("template")) smartArgs["template"] = args.value("template");
    if (args.contains("template_vars")) smartArgs["template_vars"] = args.value("template_vars");
    if (args.contains("related_files")) smartArgs["related_files"] = args.value("related_files");
    if (args.contains("overwrite")) smartArgs["overwrite"] = args.value("overwrite");
    if (args.contains("create_dirs")) smartArgs["create_dirs"] = args.value("create_dirs");
    if (args.contains("files")) smartArgs["files"] = args.value("files");
    if (args.contains("structure_intent")) smartArgs["structure_intent"] = args.value("structure_intent");
    if (args.contains("generate_missing")) smartArgs["generate_missing"] = args.value("generate_missing");

    ToolResult result = m_smartFileCreator->execute(callId, smartArgs);
    result.name = name();
    return result;
}

ToolResult FileSystemTool::opDeleteFile(const QString &callId, const QJsonObject &args)
{
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
    if (m_sandboxManager && !m_sandboxManager->canAccess(path, FileSystemAccessMode::Write))
        return {callId, name(), true, "Sandbox policy denied delete access."};
    const QString checkpointId = checkpointPaths({args["path"].toString()},
                                                 QStringLiteral("file_system delete %1").arg(args["path"].toString()));

    if (!QFile::remove(path))
        return {callId, name(), true, "Failed to delete file."};
    QString result = "Deleted: " + args["path"].toString();
    if (!checkpointId.isEmpty())
        result += "\nCheckpoint: " + checkpointId;
    return {callId, name(), false, result};
}

ToolResult FileSystemTool::opMoveFile(const QString &callId, const QJsonObject &args)
{
    const QString src  = safePath(args["path"].toString());
    const QString dest = safePath(args["destination"].toString());
    if (src.isEmpty() || dest.isEmpty())
        return {callId, name(), true, "Path traversal denied."};
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(src, FileSystemAccessMode::Write)
            || !m_sandboxManager->canAccess(dest, FileSystemAccessMode::Write))
            return {callId, name(), true, "Sandbox policy denied move access."};
    }
    const QString checkpointId = checkpointPaths(
        {args["path"].toString(), args["destination"].toString()},
        QStringLiteral("file_system move %1 -> %2")
            .arg(args["path"].toString(), args["destination"].toString()));

    if (!QFile::rename(src, dest))
        return {callId, name(), true, "Failed to move file."};
    QString result = "Moved to: " + args["destination"].toString();
    if (!checkpointId.isEmpty())
        result += "\nCheckpoint: " + checkpointId;
    return {callId, name(), false, result};
}
