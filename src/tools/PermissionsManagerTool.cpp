#include "tools/PermissionsManagerTool.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

PermissionsManagerTool::PermissionsManagerTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[PermissionsManagerTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject PermissionsManagerTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({"chmod", "chown", "check", "make_readonly", "make_writable"});
    typeObj["description"] = "Type of permission operation";
    properties["type"] = typeObj;
    
    QJsonObject pathObj;
    pathObj["type"] = "string";
    pathObj["description"] = "File or directory path";
    properties["path"] = pathObj;
    
    QJsonObject modeObj;
    modeObj["type"] = "string";
    modeObj["description"] = "File mode (e.g., '0755', '0644', 'u+x')";
    properties["mode"] = modeObj;
    
    QJsonObject ownerObj;
    ownerObj["type"] = "string";
    ownerObj["description"] = "Owner name or UID:GID";
    properties["owner"] = ownerObj;
    
    QJsonObject recursiveObj;
    recursiveObj["type"] = "boolean";
    recursiveObj["description"] = "Apply recursively for directories";
    recursiveObj["default"] = false;
    properties["recursive"] = recursiveObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type", "path"});
    
    return schema;
}

ToolResult PermissionsManagerTool::execute(const QString &callId, const QJsonObject &args)
{
    PermissionOp op = parseOp(args);
    
    if (op.type == "chmod") {
        return opChmod(callId, op);
    } else if (op.type == "chown") {
        return opChown(callId, op);
    } else if (op.type == "check") {
        return opCheck(callId, op);
    } else if (op.type == "make_readonly") {
        return opMakeReadOnly(callId, op);
    } else if (op.type == "make_writable") {
        return opMakeWritable(callId, op);
    }
    
    return {callId, name(), true, "Unknown operation type: " + op.type};
}

QString PermissionsManagerTool::summary(const QJsonObject &args) const
{
    return QString("%1 on %2")
        .arg(args["type"].toString())
        .arg(args["path"].toString());
}

PermissionsManagerTool::PermissionOp PermissionsManagerTool::parseOp(const QJsonObject &args)
{
    PermissionOp op;
    op.type = args["type"].toString();
    op.path = args["path"].toString();
    op.mode = args["mode"].toString();
    op.owner = args["owner"].toString();
    op.recursive = args["recursive"].toBool(false);
    return op;
}

QString PermissionsManagerTool::safePath(const QString &relPath) const
{
    QFileInfo info(relPath);
    if (info.isAbsolute()) {
        return QDir::cleanPath(info.absoluteFilePath());
    }
    
    QString absPath = QDir::cleanPath(m_workspaceRoot + "/" + relPath);
    QString relative = QDir(m_workspaceRoot).relativeFilePath(absPath);
    
    if (relative.startsWith("..")) {
        return QString();
    }
    
    return absPath;
}

QString PermissionsManagerTool::permissionsToString(const QFile::Permissions &perms)
{
    QString result;
    
    // Owner permissions
    result += (perms & QFile::ReadOwner) ? "r" : "-";
    result += (perms & QFile::WriteOwner) ? "w" : "-";
    result += (perms & QFile::ExeOwner) ? "x" : "-";
    
    // Group permissions
    result += (perms & QFile::ReadGroup) ? "r" : "-";
    result += (perms & QFile::WriteGroup) ? "w" : "-";
    result += (perms & QFile::ExeGroup) ? "x" : "-";
    
    // Others permissions
    result += (perms & QFile::ReadOther) ? "r" : "-";
    result += (perms & QFile::WriteOther) ? "w" : "-";
    result += (perms & QFile::ExeOther) ? "x" : "-";
    
    return result;
}

ToolResult PermissionsManagerTool::opChmod(const QString &callId, const PermissionOp &op)
{
    QString absPath = safePath(op.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo info(absPath);
    if (!info.exists()) {
        return {callId, name(), true, "File not found: " + op.path};
    }
    
    // Parse mode string (simple implementation)
    QFile::Permissions newPerms = QFile::ReadOwner | QFile::WriteOwner;
    
    if (op.mode.contains("755")) {
        newPerms = QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                   QFile::ReadGroup | QFile::ExeGroup |
                   QFile::ReadOther | QFile::ExeOther;
    } else if (op.mode.contains("644")) {
        newPerms = QFile::ReadOwner | QFile::WriteOwner |
                   QFile::ReadGroup | QFile::ReadOther;
    } else if (op.mode.contains("777")) {
        newPerms = QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                   QFile::ReadGroup | QFile::WriteGroup | QFile::ExeGroup |
                   QFile::ReadOther | QFile::WriteOther | QFile::ExeOther;
    }
    
    QStringList successful;
    QStringList failed;
    
    if (info.isDir() && op.recursive) {
        QDirIterator it(absPath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                       QDirIterator::Subdirectories);
        
        while (it.hasNext()) {
            it.next();
            QFile file(it.filePath());
            if (file.setPermissions(newPerms)) {
                successful.append(it.filePath());
            } else {
                failed.append(it.filePath());
            }
        }
    } else {
        QFile file(absPath);
        if (file.setPermissions(newPerms)) {
            successful.append(absPath);
        } else {
            failed.append(absPath);
        }
    }
    
    QJsonObject result;
    result["path"] = op.path;
    result["mode"] = op.mode;
    result["successful_count"] = successful.count();
    result["failed_count"] = failed.count();
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult PermissionsManagerTool::opChown(const QString &callId, const PermissionOp &op)
{
    // Note: chown typically requires elevated privileges and OS-specific implementation
    // This is a placeholder for documentation purposes
    
    QString absPath = safePath(op.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo info(absPath);
    if (!info.exists()) {
        return {callId, name(), true, "File not found: " + op.path};
    }
    
    QJsonObject result;
    result["path"] = op.path;
    result["status"] = "Note: chown requires elevated privileges and OS-specific implementation";
    result["owner"] = op.owner;
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult PermissionsManagerTool::opCheck(const QString &callId, const PermissionOp &op)
{
    QString absPath = safePath(op.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo info(absPath);
    if (!info.exists()) {
        return {callId, name(), true, "File not found: " + op.path};
    }
    
    QFile file(absPath);
    QFile::Permissions perms = file.permissions();
    
    QJsonObject result;
    result["path"] = op.path;
    result["readable"] = info.isReadable();
    result["writable"] = info.isWritable();
    result["executable"] = info.isExecutable();
    result["permissions_string"] = permissionsToString(perms);
    result["owner"] = info.owner();
    result["group"] = info.group();
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult PermissionsManagerTool::opMakeReadOnly(const QString &callId, const PermissionOp &op)
{
    QString absPath = safePath(op.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo info(absPath);
    if (!info.exists()) {
        return {callId, name(), true, "File not found: " + op.path};
    }
    
    QFile::Permissions perms = QFile::ReadOwner | QFile::ReadGroup | QFile::ReadOther;
    
    QStringList successful;
    QStringList failed;
    
    if (info.isDir() && op.recursive) {
        QDirIterator it(absPath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                       QDirIterator::Subdirectories);
        
        while (it.hasNext()) {
            it.next();
            QFile file(it.filePath());
            if (file.setPermissions(perms)) {
                successful.append(it.filePath());
            } else {
                failed.append(it.filePath());
            }
        }
    } else {
        QFile file(absPath);
        if (file.setPermissions(perms)) {
            successful.append(absPath);
        } else {
            failed.append(absPath);
        }
    }
    
    QJsonObject result;
    result["status"] = "readonly";
    result["successful_count"] = successful.count();
    result["failed_count"] = failed.count();
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult PermissionsManagerTool::opMakeWritable(const QString &callId, const PermissionOp &op)
{
    QString absPath = safePath(op.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo info(absPath);
    if (!info.exists()) {
        return {callId, name(), true, "File not found: " + op.path};
    }
    
    QFile::Permissions perms = QFile::ReadOwner | QFile::WriteOwner |
                               QFile::ReadGroup | QFile::WriteGroup |
                               QFile::ReadOther | QFile::WriteOther;
    
    QStringList successful;
    QStringList failed;
    
    if (info.isDir() && op.recursive) {
        QDirIterator it(absPath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                       QDirIterator::Subdirectories);
        
        while (it.hasNext()) {
            it.next();
            QFile file(it.filePath());
            if (file.setPermissions(perms)) {
                successful.append(it.filePath());
            } else {
                failed.append(it.filePath());
            }
        }
    } else {
        QFile file(absPath);
        if (file.setPermissions(perms)) {
            successful.append(absPath);
        } else {
            failed.append(absPath);
        }
    }
    
    QJsonObject result;
    result["status"] = "writable";
    result["successful_count"] = successful.count();
    result["failed_count"] = failed.count();
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}
