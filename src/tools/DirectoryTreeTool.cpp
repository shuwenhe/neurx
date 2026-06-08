#include "tools/DirectoryTreeTool.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QRegularExpression>

DirectoryTreeTool::DirectoryTreeTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[DirectoryTreeTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject DirectoryTreeTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject pathObj;
    pathObj["type"] = "string";
    pathObj["description"] = "Directory path";
    pathObj["default"] = ".";
    properties["path"] = pathObj;
    
    QJsonObject formatObj;
    formatObj["type"] = "string";
    formatObj["enum"] = QJsonArray::fromStringList({"text", "json", "markdown"});
    formatObj["description"] = "Output format";
    formatObj["default"] = "text";
    properties["format"] = formatObj;
    
    QJsonObject depthObj;
    depthObj["type"] = "integer";
    depthObj["description"] = "Maximum recursion depth";
    depthObj["default"] = 5;
    properties["max_depth"] = depthObj;
    
    QJsonObject ignoreObj;
    ignoreObj["type"] = "array";
    ignoreObj["description"] = "Glob patterns to ignore";
    properties["ignore"] = ignoreObj;
    
    QJsonObject sizeObj;
    sizeObj["type"] = "boolean";
    sizeObj["description"] = "Show file sizes";
    sizeObj["default"] = false;
    properties["show_size"] = sizeObj;
    
    QJsonObject permsObj;
    permsObj["type"] = "boolean";
    permsObj["description"] = "Show permissions";
    permsObj["default"] = false;
    properties["show_permissions"] = permsObj;
    
    schema["properties"] = properties;
    
    return schema;
}

ToolResult DirectoryTreeTool::execute(const QString &callId, const QJsonObject &args)
{
    TreeQuery query = parseQuery(args);
    return opGenerateTree(callId, query);
}

QString DirectoryTreeTool::summary(const QJsonObject &args) const
{
    return QString("Generate %1 tree for %2")
        .arg(args["format"].toString("text"))
        .arg(args["path"].toString("."));
}

DirectoryTreeTool::TreeQuery DirectoryTreeTool::parseQuery(const QJsonObject &args)
{
    TreeQuery query;
    query.path = args["path"].toString(".");
    query.format = args["format"].toString("text");
    query.maxDepth = args["max_depth"].toInt(5);
    query.showSize = args["show_size"].toBool(false);
    query.showPermissions = args["show_permissions"].toBool(false);
    
    if (args["ignore"].isArray()) {
        QJsonArray ignoreArray = args["ignore"].toArray();
        for (const auto &item : ignoreArray) {
            query.ignoredPatterns.append(item.toString());
        }
    }
    
    // 默认忽略模式
    query.ignoredPatterns << ".*" << "node_modules" << "build" << ".git" << "CMakeFiles";
    
    return query;
}

QString DirectoryTreeTool::safePath(const QString &relPath) const
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

bool DirectoryTreeTool::shouldIgnore(const QString &name, const QStringList &patterns)
{
    for (const QString &pattern : patterns) {
        QRegularExpression regex(QRegularExpression::wildcardToRegularExpression(pattern));
        if (regex.match(name).hasMatch()) {
            return true;
        }
    }
    return false;
}

QString DirectoryTreeTool::buildTextTree(const QString &path, int currentDepth, 
                                        const TreeQuery &query, const QString &prefix)
{
    if (currentDepth > query.maxDepth) {
        return "";
    }
    
    QString result;
    QDir dir(path);
    QStringList entries = dir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (int i = 0; i < entries.count(); ++i) {
        QString entry = entries[i];
        
        if (shouldIgnore(entry, query.ignoredPatterns)) {
            continue;
        }
        
        QString fullPath = dir.absoluteFilePath(entry);
        QFileInfo info(fullPath);
        
        bool isLast = (i == entries.count() - 1);
        QString connector = isLast ? "└── " : "├── ";
        QString nextPrefix = isLast ? prefix + "    " : prefix + "│   ";
        
        result += prefix + connector + entry;
        
        if (query.showSize && info.isFile()) {
            result += QString(" (%1 bytes)").arg(info.size());
        }
        
        result += "\n";
        
        if (info.isDir()) {
            result += buildTextTree(fullPath, currentDepth + 1, query, nextPrefix);
        }
    }
    
    return result;
}

QJsonObject DirectoryTreeTool::buildJsonTree(const QString &path, int currentDepth, 
                                            const TreeQuery &query)
{
    QJsonObject obj;
    QDir dir(path);
    QFileInfo rootInfo(path);
    
    obj["name"] = rootInfo.fileName();
    obj["path"] = QDir(m_workspaceRoot).relativeFilePath(path);
    obj["type"] = "directory";
    
    if (currentDepth <= query.maxDepth) {
        QJsonArray childrenArray;
        QStringList entries = dir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        for (const QString &entry : entries) {
            if (shouldIgnore(entry, query.ignoredPatterns)) {
                continue;
            }
            
            QString fullPath = dir.absoluteFilePath(entry);
            QFileInfo info(fullPath);
            
            QJsonObject child;
            child["name"] = entry;
            child["path"] = QDir(m_workspaceRoot).relativeFilePath(fullPath);
            child["type"] = info.isDir() ? "directory" : "file";
            
            if (info.isFile()) {
                child["size"] = (qint64)info.size();
            }
            
            if (info.isDir()) {
                child["children"] = buildJsonTree(fullPath, currentDepth + 1, query)["children"];
            }
            
            childrenArray.append(child);
        }
        
        obj["children"] = childrenArray;
    }
    
    return obj;
}

QString DirectoryTreeTool::buildMarkdownTree(const QString &path, int currentDepth, 
                                            const TreeQuery &query, const QString &prefix)
{
    if (currentDepth > query.maxDepth) {
        return "";
    }
    
    QString result;
    QDir dir(path);
    QStringList entries = dir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (int i = 0; i < entries.count(); ++i) {
        QString entry = entries[i];
        
        if (shouldIgnore(entry, query.ignoredPatterns)) {
            continue;
        }
        
        QString fullPath = dir.absoluteFilePath(entry);
        QFileInfo info(fullPath);
        
        QString indent(currentDepth * 2, ' ');
        result += indent + "- " + entry;
        
        if (query.showSize && info.isFile()) {
            result += QString(" (%1 B)").arg(info.size());
        }
        
        result += "\n";
        
        if (info.isDir()) {
            result += buildMarkdownTree(fullPath, currentDepth + 1, query, prefix);
        }
    }
    
    return result;
}

ToolResult DirectoryTreeTool::opGenerateTree(const QString &callId, const TreeQuery &query)
{
    QString absPath = safePath(query.path);
    if (absPath.isEmpty()) {
        absPath = m_workspaceRoot;
    }
    
    QFileInfo pathInfo(absPath);
    if (!pathInfo.exists() || !pathInfo.isDir()) {
        return {callId, name(), true, "Directory not found: " + query.path};
    }
    
    QString result;
    
    if (query.format == "text") {
        result = pathInfo.fileName() + "/\n";
        result += buildTextTree(absPath, 0, query);
    } else if (query.format == "json") {
        QJsonObject treeObj = buildJsonTree(absPath, 0, query);
        result = QJsonDocument(treeObj).toJson(QJsonDocument::Indented);
    } else if (query.format == "markdown") {
        result = "# " + pathInfo.fileName() + "\n\n";
        result += buildMarkdownTree(absPath, 0, query);
    }
    
    QJsonObject resultObj;
    resultObj["path"] = query.path;
    resultObj["format"] = query.format;
    resultObj["tree"] = result;
    
    return {callId, name(), false, QJsonDocument(resultObj).toJson(QJsonDocument::Compact)};
}
