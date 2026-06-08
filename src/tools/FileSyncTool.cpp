#include "tools/FileSyncTool.h"
#include <QFile>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QCryptographicHash>

FileSyncTool::FileSyncTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[FileSyncTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject FileSyncTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({"sync", "backup", "diff", "cleanup"});
    typeObj["description"] = "Type of sync operation";
    properties["type"] = typeObj;
    
    QJsonObject sourceObj;
    sourceObj["type"] = "string";
    sourceObj["description"] = "Source file or directory";
    properties["source"] = sourceObj;
    
    QJsonObject destObj;
    destObj["type"] = "string";
    destObj["description"] = "Destination file or directory";
    properties["destination"] = destObj;
    
    QJsonObject recursiveObj;
    recursiveObj["type"] = "boolean";
    recursiveObj["description"] = "Recursive sync for directories";
    recursiveObj["default"] = false;
    properties["recursive"] = recursiveObj;
    
    QJsonObject dryRunObj;
    dryRunObj["type"] = "boolean";
    dryRunObj["description"] = "Preview without making changes";
    dryRunObj["default"] = false;
    properties["dry_run"] = dryRunObj;
    
    QJsonObject overwriteObj;
    overwriteObj["type"] = "boolean";
    overwriteObj["description"] = "Overwrite existing files";
    overwriteObj["default"] = false;
    properties["overwrite"] = overwriteObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type"});
    
    return schema;
}

ToolResult FileSyncTool::execute(const QString &callId, const QJsonObject &args)
{
    SyncOperation op = parseOperation(args);
    
    if (op.type == "sync") {
        return opSync(callId, op);
    } else if (op.type == "backup") {
        return opBackup(callId, op);
    } else if (op.type == "diff") {
        return opDiff(callId, op);
    } else if (op.type == "cleanup") {
        return opCleanup(callId, op);
    }
    
    return {callId, name(), true, "Unknown operation type: " + op.type};
}

QString FileSyncTool::summary(const QJsonObject &args) const
{
    return QString("%1 from %2 to %3")
        .arg(args["type"].toString())
        .arg(args["source"].toString())
        .arg(args["destination"].toString());
}

FileSyncTool::SyncOperation FileSyncTool::parseOperation(const QJsonObject &args)
{
    SyncOperation op;
    op.type = args["type"].toString();
    op.source = args["source"].toString();
    op.destination = args["destination"].toString();
    op.recursive = args["recursive"].toBool(false);
    op.dryRun = args["dry_run"].toBool(false);
    op.overwrite = args["overwrite"].toBool(false);
    return op;
}

QString FileSyncTool::safePath(const QString &relPath) const
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

QString FileSyncTool::createBackupDirectory()
{
    QString backupDir = m_workspaceRoot + "/.backups/" + 
                       QDateTime::currentDateTime().toString("yyyy-MM-dd");
    
    if (!QDir().mkpath(backupDir)) {
        return QString();
    }
    
    return backupDir;
}

ToolResult FileSyncTool::opSync(const QString &callId, const SyncOperation &op)
{
    QString srcPath = safePath(op.source);
    QString dstPath = safePath(op.destination);
    
    if (srcPath.isEmpty() || dstPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo srcInfo(srcPath);
    if (!srcInfo.exists()) {
        return {callId, name(), true, "Source not found: " + op.source};
    }
    
    QJsonObject result;
    
    if (srcInfo.isFile()) {
        // 单文件同步
        if (op.dryRun) {
            result["mode"] = "dry_run";
            result["preview"] = "COPY: " + op.source + " -> " + op.destination;
            return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
        }
        
        // 检查目标文件是否存在
        QFileInfo dstInfo(dstPath);
        if (dstInfo.exists() && !op.overwrite) {
            return {callId, name(), true, "Destination already exists (use overwrite=true)"};
        }
        
        // 创建目标目录
        QDir().mkpath(QFileInfo(dstPath).absolutePath());
        
        if (QFile::copy(srcPath, dstPath)) {
            result["status"] = "success";
            result["copied"] = 1;
        } else {
            result["status"] = "error";
            result["error"] = "Failed to copy file";
        }
    } else if (srcInfo.isDir()) {
        // 目录同步
        if (!op.recursive) {
            return {callId, name(), true, "Use recursive=true for directory sync"};
        }
        
        QStringList synced;
        QStringList failed;
        
        QDirIterator it(srcPath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                       QDirIterator::Subdirectories);
        
        while (it.hasNext()) {
            it.next();
            
            QString relPath = QDir(srcPath).relativeFilePath(it.filePath());
            QString targetPath = dstPath + "/" + relPath;
            
            if (it.fileInfo().isDir()) {
                if (!QDir().mkpath(targetPath)) {
                    failed.append(relPath);
                }
            } else {
                QDir().mkpath(QFileInfo(targetPath).absolutePath());
                
                if (QFile::copy(it.filePath(), targetPath)) {
                    synced.append(relPath);
                } else {
                    failed.append(relPath);
                }
            }
        }
        
        result["status"] = failed.isEmpty() ? "success" : "partial";
        result["synced"] = synced.count();
        result["failed"] = failed.count();
    }
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult FileSyncTool::opBackup(const QString &callId, const SyncOperation &op)
{
    QString srcPath = safePath(op.source);
    if (srcPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo srcInfo(srcPath);
    if (!srcInfo.exists()) {
        return {callId, name(), true, "Source not found: " + op.source};
    }
    
    QString backupDir = createBackupDirectory();
    if (backupDir.isEmpty()) {
        return {callId, name(), true, "Failed to create backup directory"};
    }
    
    QString backupPath = backupDir + "/" + srcInfo.fileName();
    
    if (op.dryRun) {
        QJsonObject result;
        result["mode"] = "dry_run";
        result["backup_path"] = backupPath;
        return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
    }
    
    if (QFile::copy(srcPath, backupPath)) {
        QJsonObject result;
        result["status"] = "success";
        result["backup_path"] = backupPath;
        return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
    } else {
        return {callId, name(), true, "Failed to create backup"};
    }
}

ToolResult FileSyncTool::opDiff(const QString &callId, const SyncOperation &op)
{
    QString srcPath = safePath(op.source);
    QString dstPath = safePath(op.destination);
    
    if (srcPath.isEmpty() || dstPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    QFileInfo srcInfo(srcPath);
    QFileInfo dstInfo(dstPath);
    
    if (!srcInfo.exists() || !dstInfo.exists()) {
        return {callId, name(), true, "Source or destination not found"};
    }
    
    QJsonObject result;
    
    if (srcInfo.isFile() && dstInfo.isFile()) {
        // 比较文件内容
        QFile srcFile(srcPath);
        QFile dstFile(dstPath);
        
        if (!srcFile.open(QIODevice::ReadOnly) || !dstFile.open(QIODevice::ReadOnly)) {
            return {callId, name(), true, "Failed to open files for comparison"};
        }
        
        QByteArray srcData = srcFile.readAll();
        QByteArray dstData = dstFile.readAll();
        
        srcFile.close();
        dstFile.close();
        
        result["identical"] = (srcData == dstData);
        result["source_size"] = (qint64)srcData.size();
        result["destination_size"] = (qint64)dstData.size();
        
        if (srcData != dstData) {
            result["source_hash"] = QString(QCryptographicHash::hash(srcData, QCryptographicHash::Sha256).toHex());
            result["destination_hash"] = QString(QCryptographicHash::hash(dstData, QCryptographicHash::Sha256).toHex());
        }
    } else {
        return {callId, name(), true, "Both paths must be files for diff"};
    }
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult FileSyncTool::opCleanup(const QString &callId, const SyncOperation &op)
{
    // 清理临时文件、备份等
    QString cleanupPath = safePath(op.source.isEmpty() ? m_workspaceRoot : op.source);
    if (cleanupPath.isEmpty()) {
        cleanupPath = m_workspaceRoot;
    }
    
    QJsonObject result;
    int tempFilesRemoved = 0;
    int tempDirsRemoved = 0;
    
    // 查找并删除临时文件
    QStringList tempPatterns = {"*.tmp", "*.bak", ".DS_Store", "*.swp", "*~"};
    
    QDirIterator it(cleanupPath, QDir::Files | QDir::NoDotAndDotDot,
                   QDirIterator::Subdirectories);
    
    while (it.hasNext()) {
        it.next();
        
        QString fileName = it.fileInfo().fileName();
        for (const QString &pattern : tempPatterns) {
            QRegularExpression regex(QRegularExpression::wildcardToRegularExpression(pattern));
            if (regex.match(fileName).hasMatch()) {
                if (op.dryRun) {
                    qInfo() << "[FileSyncTool] Would delete:" << it.filePath();
                } else {
                    if (QFile::remove(it.filePath())) {
                        tempFilesRemoved++;
                    }
                }
                break;
            }
        }
    }
    
    result["status"] = "success";
    result["temp_files_removed"] = tempFilesRemoved;
    result["temp_dirs_removed"] = tempDirsRemoved;
    
    if (op.dryRun) {
        result["mode"] = "dry_run";
    }
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}
