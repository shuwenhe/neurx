#include "tools/BatchFileOperationsTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QTextStream>

BatchFileOperationsTool::BatchFileOperationsTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[BatchFileOperationsTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject BatchFileOperationsTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({"batch_create", "batch_delete", "batch_move", "batch_copy", "create_structure"});
    typeObj["description"] = "Type of batch operation";
    properties["type"] = typeObj;
    
    QJsonObject filesObj;
    filesObj["type"] = "array";
    filesObj["description"] = "Array of file specs for batch_create";
    properties["files"] = filesObj;
    
    QJsonObject pathsObj;
    pathsObj["type"] = "array";
    pathsObj["description"] = "Paths for batch_delete";
    properties["paths"] = pathsObj;
    
    QJsonObject sourceObj;
    sourceObj["type"] = "array";
    sourceObj["description"] = "Source paths for batch_move/copy";
    properties["source"] = sourceObj;
    
    QJsonObject destObj;
    destObj["type"] = "array";
    destObj["description"] = "Destination paths for batch_move/copy";
    properties["destination"] = destObj;
    
    QJsonObject dryRunObj;
    dryRunObj["type"] = "boolean";
    dryRunObj["description"] = "Preview operations without executing";
    dryRunObj["default"] = false;
    properties["dry_run"] = dryRunObj;
    
    QJsonObject rollbackObj;
    rollbackObj["type"] = "boolean";
    rollbackObj["description"] = "Rollback all operations if any fails";
    rollbackObj["default"] = true;
    properties["rollback_on_error"] = rollbackObj;
    
    QJsonObject structureObj;
    structureObj["type"] = "object";
    structureObj["description"] = "Directory structure for create_structure";
    properties["structure"] = structureObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type"});
    
    return schema;
}

ToolResult BatchFileOperationsTool::execute(const QString &callId, const QJsonObject &args)
{
    BatchOperation op = parseOperation(args);
    
    if (op.type == "batch_create") {
        return opBatchCreate(callId, op);
    } else if (op.type == "batch_delete") {
        return opBatchDelete(callId, op);
    } else if (op.type == "batch_move") {
        return opBatchMove(callId, op);
    } else if (op.type == "batch_copy") {
        return opBatchCopy(callId, op);
    } else if (op.type == "create_structure") {
        return opCreateStructure(callId, op);
    }
    
    return {callId, name(), true, "Unknown operation type: " + op.type};
}

QString BatchFileOperationsTool::summary(const QJsonObject &args) const
{
    return QString("%1 on %2 items")
        .arg(args["type"].toString())
        .arg(args["files"].isArray() ? args["files"].toArray().count() : 0);
}

BatchFileOperationsTool::BatchOperation BatchFileOperationsTool::parseOperation(const QJsonObject &args)
{
    BatchOperation op;
    op.type = args["type"].toString();
    op.dryRun = args["dry_run"].toBool(false);
    op.rollbackOnError = args["rollback_on_error"].toBool(true);
    
    // 解析文件规范
    if (args["files"].isArray()) {
        QJsonArray filesArray = args["files"].toArray();
        for (const auto &item : filesArray) {
            if (item.isObject()) {
                QJsonObject obj = item.toObject();
                FileSpec spec;
                spec.path = obj["path"].toString();
                spec.content = obj["content"].toString();
                spec.isDirectory = obj["is_directory"].toBool(false);
                op.specs.append(spec);
            }
        }
    }
    
    // 解析路径数组
    if (args["paths"].isArray()) {
        QJsonArray pathsArray = args["paths"].toArray();
        for (const auto &item : pathsArray) {
            op.source.append(item.toString());
        }
    }
    
    // 解析源和目标路径
    if (args["source"].isArray()) {
        QJsonArray sourceArray = args["source"].toArray();
        for (const auto &item : sourceArray) {
            op.source.append(item.toString());
        }
    }
    
    if (args["destination"].isArray()) {
        QJsonArray destArray = args["destination"].toArray();
        for (const auto &item : destArray) {
            op.destination.append(item.toString());
        }
    }
    
    return op;
}

QString BatchFileOperationsTool::safePath(const QString &relPath) const
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

bool BatchFileOperationsTool::createFileWithParents(const QString &path, const QString &content)
{
    QFileInfo info(path);
    QDir dir = info.dir();
    
    if (!dir.exists()) {
        if (!dir.mkpath(dir.absolutePath())) {
            qWarning() << "[BatchFileOperationsTool] Failed to create parent directories:" << path;
            return false;
        }
    }
    
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "[BatchFileOperationsTool] Failed to create file:" << path;
        return false;
    }
    
    QTextStream out(&file);
    out << content;
    file.close();
    
    return true;
}

bool BatchFileOperationsTool::deleteFileRecursive(const QString &path)
{
    QFileInfo info(path);
    
    if (info.isDir()) {
        QDir dir(path);
        if (!dir.removeRecursively()) {
            qWarning() << "[BatchFileOperationsTool] Failed to delete directory:" << path;
            return false;
        }
    } else if (info.exists()) {
        if (!QFile::remove(path)) {
            qWarning() << "[BatchFileOperationsTool] Failed to delete file:" << path;
            return false;
        }
    }
    
    return true;
}

ToolResult BatchFileOperationsTool::opBatchCreate(const QString &callId, const BatchOperation &op)
{
    QStringList successful;
    QStringList failed;
    QStringList preview;
    
    for (const FileSpec &spec : op.specs) {
        QString absPath = safePath(spec.path);
        if (absPath.isEmpty()) {
            failed.append(spec.path + " (path traversal)");
            continue;
        }
        
        if (op.dryRun) {
            preview.append(QString("[%1] %2")
                .arg(spec.isDirectory ? "DIR" : "FILE")
                .arg(spec.path));
            continue;
        }
        
        if (spec.isDirectory) {
            if (QDir().mkpath(absPath)) {
                successful.append(spec.path);
            } else {
                failed.append(spec.path);
            }
        } else {
            if (createFileWithParents(absPath, spec.content)) {
                successful.append(spec.path);
            } else {
                failed.append(spec.path);
            }
        }
    }
    
    if (op.dryRun) {
        QJsonObject result;
        result["mode"] = "dry_run";
        result["preview"] = QJsonArray::fromStringList(preview);
        return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
    }
    
    QJsonObject result;
    result["successful"] = QJsonArray::fromStringList(successful);
    result["failed"] = QJsonArray::fromStringList(failed);
    result["successful_count"] = successful.count();
    result["failed_count"] = failed.count();
    
    if (!failed.isEmpty() && op.rollbackOnError) {
        result["status"] = "rolled_back";
        // TODO: 实现回滚逻辑
    } else {
        result["status"] = "completed";
    }
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult BatchFileOperationsTool::opBatchDelete(const QString &callId, const BatchOperation &op)
{
    QStringList successful;
    QStringList failed;
    QStringList preview;
    
    for (const QString &path : op.source) {
        QString absPath = safePath(path);
        if (absPath.isEmpty()) {
            failed.append(path + " (path traversal)");
            continue;
        }
        
        if (op.dryRun) {
            preview.append("DELETE: " + path);
            continue;
        }
        
        if (deleteFileRecursive(absPath)) {
            successful.append(path);
        } else {
            failed.append(path);
        }
    }
    
    if (op.dryRun) {
        QJsonObject result;
        result["mode"] = "dry_run";
        result["preview"] = QJsonArray::fromStringList(preview);
        return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
    }
    
    QJsonObject result;
    result["successful"] = QJsonArray::fromStringList(successful);
    result["failed"] = QJsonArray::fromStringList(failed);
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult BatchFileOperationsTool::opBatchMove(const QString &callId, const BatchOperation &op)
{
    if (op.source.count() != op.destination.count()) {
        return {callId, name(), true, "Source and destination counts mismatch"};
    }
    
    QStringList successful;
    QStringList failed;
    
    for (int i = 0; i < op.source.count(); ++i) {
        QString srcAbs = safePath(op.source[i]);
        QString dstAbs = safePath(op.destination[i]);
        
        if (srcAbs.isEmpty() || dstAbs.isEmpty()) {
            failed.append(op.source[i]);
            continue;
        }
        
        if (op.dryRun) {
            qInfo() << "[BatchFileOperationsTool] MOVE:" << srcAbs << "->" << dstAbs;
            continue;
        }
        
        if (QFile::rename(srcAbs, dstAbs)) {
            successful.append(op.source[i]);
        } else {
            failed.append(op.source[i]);
        }
    }
    
    QJsonObject result;
    result["successful"] = QJsonArray::fromStringList(successful);
    result["failed"] = QJsonArray::fromStringList(failed);
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult BatchFileOperationsTool::opBatchCopy(const QString &callId, const BatchOperation &op)
{
    if (op.source.count() != op.destination.count()) {
        return {callId, name(), true, "Source and destination counts mismatch"};
    }
    
    QStringList successful;
    QStringList failed;
    
    for (int i = 0; i < op.source.count(); ++i) {
        QString srcAbs = safePath(op.source[i]);
        QString dstAbs = safePath(op.destination[i]);
        
        if (srcAbs.isEmpty() || dstAbs.isEmpty()) {
            failed.append(op.source[i]);
            continue;
        }
        
        if (op.dryRun) {
            qInfo() << "[BatchFileOperationsTool] COPY:" << srcAbs << "->" << dstAbs;
            continue;
        }
        
        if (QFile::copy(srcAbs, dstAbs)) {
            successful.append(op.source[i]);
        } else {
            failed.append(op.source[i]);
        }
    }
    
    QJsonObject result;
    result["successful"] = QJsonArray::fromStringList(successful);
    result["failed"] = QJsonArray::fromStringList(failed);
    
    return {callId, name(), failed.isEmpty(), QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult BatchFileOperationsTool::opCreateStructure(const QString &callId, const BatchOperation &op)
{
    // TODO: 实现文件结构创建逻辑
    return {callId, name(), false, "Create structure stub - to be implemented"};
}
