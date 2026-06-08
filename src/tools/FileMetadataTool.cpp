#include "tools/FileMetadataTool.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QCryptographicHash>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QMimeDatabase>
#include <QMimeType>

FileMetadataTool::FileMetadataTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[FileMetadataTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject FileMetadataTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({"file_info", "file_hash", "dir_stats", "encoding"});
    typeObj["description"] = "Type of metadata to retrieve";
    properties["type"] = typeObj;
    
    QJsonObject pathObj;
    pathObj["type"] = "string";
    pathObj["description"] = "Relative path to file/directory from workspace root";
    properties["path"] = pathObj;
    
    QJsonObject hashAlgoObj;
    hashAlgoObj["type"] = "string";
    hashAlgoObj["enum"] = QJsonArray::fromStringList({"md5", "sha256"});
    hashAlgoObj["description"] = "Hash algorithm for file_hash";
    hashAlgoObj["default"] = "sha256";
    properties["hash_algo"] = hashAlgoObj;
    
    QJsonObject recursiveObj;
    recursiveObj["type"] = "boolean";
    recursiveObj["description"] = "Include subdirectories for dir_stats";
    recursiveObj["default"] = false;
    properties["recursive"] = recursiveObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type", "path"});
    
    return schema;
}

ToolResult FileMetadataTool::execute(const QString &callId, const QJsonObject &args)
{
    MetadataQuery query = parseQuery(args);
    
    if (query.type == "file_info") {
        return opFileInfo(callId, query);
    } else if (query.type == "file_hash") {
        return opFileHash(callId, query);
    } else if (query.type == "dir_stats") {
        return opDirStats(callId, query);
    } else if (query.type == "encoding") {
        return opEncoding(callId, query);
    }
    
    return {callId, name(), true, "Unknown metadata type: " + query.type};
}

QString FileMetadataTool::summary(const QJsonObject &args) const
{
    return QString("Get %1 metadata for %2")
        .arg(args["type"].toString())
        .arg(args["path"].toString());
}

FileMetadataTool::MetadataQuery FileMetadataTool::parseQuery(const QJsonObject &args)
{
    MetadataQuery query;
    query.type = args["type"].toString();
    query.path = args["path"].toString();
    query.hashAlgo = args["hash_algo"].toString("sha256");
    query.recursive = args["recursive"].toBool(false);
    return query;
}

QString FileMetadataTool::safePath(const QString &relPath) const
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

ToolResult FileMetadataTool::opFileInfo(const QString &callId, const MetadataQuery &query)
{
    QString absPath = safePath(query.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected: " + query.path};
    }
    
    QFileInfo info(absPath);
    if (!info.exists()) {
        return {callId, name(), true, "File not found: " + absPath};
    }
    
    QJsonObject result;
    result["path"] = query.path;
    result["absolute_path"] = absPath;
    result["exists"] = true;
    result["is_file"] = info.isFile();
    result["is_dir"] = info.isDir();
    result["is_symlink"] = info.isSymLink();
    result["size"] = (qint64)info.size();
    result["size_human"] = QString("%1 bytes").arg(info.size());
    result["created"] = info.birthTime().toString(Qt::ISODate);
    result["modified"] = info.lastModified().toString(Qt::ISODate);
    result["accessed"] = info.lastRead().toString(Qt::ISODate);
    
    // 权限
    QJsonObject perms;
    perms["readable"] = info.isReadable();
    perms["writable"] = info.isWritable();
    perms["executable"] = info.isExecutable();
    result["permissions"] = perms;
    
    // 文件类型
    result["file_type"] = getFileType(absPath);
    result["suffix"] = info.suffix();
    
    // 编码（仅文件）
    if (info.isFile()) {
        result["encoding"] = detectEncoding(absPath);
    }
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult FileMetadataTool::opFileHash(const QString &callId, const MetadataQuery &query)
{
    QString absPath = safePath(query.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected: " + query.path};
    }
    
    QFileInfo info(absPath);
    if (!info.exists() || !info.isFile()) {
        return {callId, name(), true, "File not found: " + absPath};
    }
    
    QString hash = calculateFileHash(absPath, query.hashAlgo);
    if (hash.isEmpty()) {
        return {callId, name(), true, "Failed to calculate hash"};
    }
    
    QJsonObject result;
    result["path"] = query.path;
    result["algorithm"] = query.hashAlgo;
    result["hash"] = hash;
    result["size"] = (qint64)info.size();
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult FileMetadataTool::opDirStats(const QString &callId, const MetadataQuery &query)
{
    QString absPath = safePath(query.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected: " + query.path};
    }
    
    QDir dir(absPath);
    if (!dir.exists()) {
        return {callId, name(), true, "Directory not found: " + absPath};
    }
    
    QJsonObject result;
    result["path"] = query.path;
    
    QDir::Filters filters = QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot;
    QDir::SortFlags sorts = QDir::NoSort;
    
    if (query.recursive) {
        filters |= QDir::Drives;
        sorts = QDir::DirsFirst;
    }
    
    QStringList entries = dir.entryList(filters, sorts);
    
    // 统计信息
    int fileCount = 0;
    int dirCount = 0;
    qint64 totalSize = 0;
    
    for (const QString &entry : entries) {
        QString fullPath = dir.absoluteFilePath(entry);
        QFileInfo info(fullPath);
        
        if (info.isDir()) {
            dirCount++;
            if (query.recursive) {
                // 递归统计
                QDirIterator it(fullPath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                                QDirIterator::Subdirectories);
                while (it.hasNext()) {
                    it.next();
                    if (it.fileInfo().isFile()) {
                        fileCount++;
                        totalSize += it.fileInfo().size();
                    } else if (it.fileInfo().isDir()) {
                        dirCount++;
                    }
                }
            }
        } else {
            fileCount++;
            totalSize += info.size();
        }
    }
    
    result["entries_count"] = entries.count();
    result["file_count"] = fileCount;
    result["directory_count"] = dirCount;
    result["total_size"] = totalSize;
    result["total_size_human"] = QString("%1 bytes").arg(totalSize);
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult FileMetadataTool::opEncoding(const QString &callId, const MetadataQuery &query)
{
    QString absPath = safePath(query.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected: " + query.path};
    }
    
    QFileInfo info(absPath);
    if (!info.exists() || !info.isFile()) {
        return {callId, name(), true, "File not found: " + absPath};
    }
    
    QString encoding = detectEncoding(absPath);
    
    QJsonObject result;
    result["path"] = query.path;
    result["encoding"] = encoding;
    result["size"] = (qint64)info.size();
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

QString FileMetadataTool::calculateFileHash(const QString &filePath, const QString &algo)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[FileMetadataTool] Cannot open file for hashing:" << filePath;
        return QString();
    }
    
    QCryptographicHash::Algorithm algorithm = QCryptographicHash::Sha256;
    if (algo == "md5") {
        algorithm = QCryptographicHash::Md5;
    }
    
    QCryptographicHash hash(algorithm);
    const int bufferSize = 65536;  // 64KB chunks
    
    while (!file.atEnd()) {
        QByteArray buffer = file.read(bufferSize);
        hash.addData(buffer);
    }
    
    file.close();
    return hash.result().toHex();
}

QString FileMetadataTool::detectEncoding(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return "unknown";
    }
    
    QByteArray data = file.read(8192);  // 读取前 8KB
    file.close();
    
    // 检查 BOM
    if (data.startsWith("\xef\xbb\xbf")) {
        return "UTF-8-BOM";
    } else if (data.startsWith("\xff\xfe")) {
        return "UTF-16LE-BOM";
    } else if (data.startsWith("\xfe\xff")) {
        return "UTF-16BE-BOM";
    }
    
    // 检查 UTF-8
    bool isUtf8 = true;
    for (int i = 0; i < data.size(); ++i) {
        unsigned char c = (unsigned char)data[i];
        if ((c & 0x80) == 0) continue;
        
        if ((c & 0xE0) == 0xC0 && i + 1 < data.size() &&
            ((data[i + 1] & 0xC0) == 0x80)) {
            i++;
        } else if ((c & 0xF0) == 0xE0 && i + 2 < data.size() &&
                   ((data[i + 1] & 0xC0) == 0x80) &&
                   ((data[i + 2] & 0xC0) == 0x80)) {
            i += 2;
        } else if ((c & 0xF8) == 0xF0 && i + 3 < data.size() &&
                   ((data[i + 1] & 0xC0) == 0x80) &&
                   ((data[i + 2] & 0xC0) == 0x80) &&
                   ((data[i + 3] & 0xC0) == 0x80)) {
            i += 3;
        } else {
            isUtf8 = false;
            break;
        }
    }
    
    if (isUtf8) {
        return "UTF-8";
    }
    
    return "ASCII or unknown";
}

QString FileMetadataTool::getFileType(const QString &filePath)
{
    QMimeDatabase db;
    QMimeType mime = db.mimeTypeForFile(filePath);
    return mime.name();
}
