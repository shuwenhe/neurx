#include "tools/FileSystemTool.h"
#include "tools/CheckpointManager.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>

FileSystemTool::FileSystemTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
    , m_checkpointManager(std::make_unique<CheckpointManager>(workspaceRoot))
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
            "destination": { "type": "string", "description": "Destination path (for move)." },
            "start_line": { "type": "integer", "description": "First line to read (1-based, inclusive)." },
            "end_line":   { "type": "integer", "description": "Last line to read (1-based, inclusive)." }
        },
        "required": ["operation", "path"]
    })").object();
}

ToolResult FileSystemTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString op = args["operation"].toString();
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

QString FileSystemTool::safePath(const QString &rel) const
{
    const QString abs = m_root.absoluteFilePath(rel);
    // Prevent path traversal
    if (!QFileInfo(abs).absoluteFilePath().startsWith(m_root.absolutePath()))
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
    const QString checkpointId = checkpointPaths({args["path"].toString()},
                                                 QStringLiteral("file_system write %1").arg(args["path"].toString()));

    QFileInfo fi(path);
    m_root.mkpath(fi.dir().absolutePath());

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return {callId, name(), true, "Cannot write: " + f.errorString()};

    QTextStream out(&f);
    out << args["content"].toString();
    QString result = "Written: " + args["path"].toString();
    if (!checkpointId.isEmpty())
        result += "\nCheckpoint: " + checkpointId;
    return {callId, name(), false, result};
}

ToolResult FileSystemTool::opListDir(const QString &callId, const QJsonObject &args)
{
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};

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
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
    if (QFile::exists(path)) return {callId, name(), true, "File already exists."};
    return opWriteFile(callId, args);
}

ToolResult FileSystemTool::opDeleteFile(const QString &callId, const QJsonObject &args)
{
    const QString path = safePath(args["path"].toString());
    if (path.isEmpty()) return {callId, name(), true, "Path traversal denied."};
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
