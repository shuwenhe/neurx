#include "tools/AdvancedSearchTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QTextStream>
#include <QRegularExpression>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QDirIterator>

AdvancedSearchTool::AdvancedSearchTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[AdvancedSearchTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject AdvancedSearchTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({"grep", "find", "symbol"});
    typeObj["description"] = "Type of search operation";
    properties["type"] = typeObj;
    
    QJsonObject patternObj;
    patternObj["type"] = "string";
    patternObj["description"] = "Search pattern or regex";
    properties["pattern"] = patternObj;
    
    QJsonObject globObj;
    globObj["type"] = "string";
    globObj["description"] = "Glob pattern for file finding";
    properties["glob_pattern"] = globObj;
    
    QJsonObject pathObj;
    pathObj["type"] = "string";
    pathObj["description"] = "Search path relative to workspace root";
    pathObj["default"] = ".";
    properties["path"] = pathObj;
    
    QJsonObject regexObj;
    regexObj["type"] = "boolean";
    regexObj["description"] = "Use regex for pattern matching";
    regexObj["default"] = false;
    properties["regex"] = regexObj;
    
    QJsonObject caseObj;
    caseObj["type"] = "boolean";
    caseObj["description"] = "Case sensitive search";
    caseObj["default"] = true;
    properties["case_sensitive"] = caseObj;
    
    QJsonObject contextObj;
    contextObj["type"] = "integer";
    contextObj["description"] = "Number of context lines to show";
    contextObj["default"] = 0;
    properties["context_lines"] = contextObj;
    
    QJsonObject extensionsObj;
    extensionsObj["type"] = "array";
    extensionsObj["description"] = "File extensions to search in";
    properties["extensions"] = extensionsObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type"});
    
    return schema;
}

ToolResult AdvancedSearchTool::execute(const QString &callId, const QJsonObject &args)
{
    SearchQuery query = parseQuery(args);
    
    if (query.type == "grep") {
        return opGrep(callId, query);
    } else if (query.type == "find") {
        return opFind(callId, query);
    } else if (query.type == "symbol") {
        return opSymbol(callId, query);
    }
    
    return {callId, name(), true, "Unknown search type: " + query.type};
}

QString AdvancedSearchTool::summary(const QJsonObject &args) const
{
    return QString("%1 for '%2' in %3")
        .arg(args["type"].toString())
        .arg(args["pattern"].toString())
        .arg(args["path"].toString("."));
}

AdvancedSearchTool::SearchQuery AdvancedSearchTool::parseQuery(const QJsonObject &args)
{
    SearchQuery query;
    query.type = args["type"].toString();
    query.pattern = args["pattern"].toString();
    query.globPattern = args["glob_pattern"].toString();
    query.searchPath = args["path"].toString(".");
    query.useRegex = args["regex"].toBool(false);
    query.caseSensitive = args["case_sensitive"].toBool(true);
    query.contextLines = args["context_lines"].toInt(0);
    
    if (args["extensions"].isArray()) {
        QJsonArray extsArray = args["extensions"].toArray();
        for (const auto &ext : extsArray) {
            query.fileExtensions.append(ext.toString());
        }
    }
    
    return query;
}

QString AdvancedSearchTool::safePath(const QString &relPath) const
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

QStringList AdvancedSearchTool::findFilesRecursive(const QString &basePath, 
                                                   const QStringList &extensions)
{
    QStringList results;
    
    QDirIterator it(basePath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                   QDirIterator::Subdirectories);
    
    while (it.hasNext()) {
        it.next();
        
        if (it.fileInfo().isFile()) {
            if (extensions.isEmpty()) {
                results.append(it.filePath());
            } else {
                QString suffix = it.fileInfo().suffix();
                if (extensions.contains(suffix)) {
                    results.append(it.filePath());
                }
            }
        }
    }
    
    return results;
}

QStringList AdvancedSearchTool::grepInFile(const QString &filePath, const SearchQuery &query)
{
    QStringList results;
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return results;
    }
    
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) {
        lines.append(in.readLine());
    }
    file.close();
    
    for (int i = 0; i < lines.count(); ++i) {
        const QString &line = lines[i];
        
        bool matches = false;
        if (query.useRegex) {
            QRegularExpression::PatternOptions options = QRegularExpression::NoPatternOption;
            if (!query.caseSensitive) {
                options |= QRegularExpression::CaseInsensitiveOption;
            }
            QRegularExpression regex(query.pattern, options);
            matches = regex.match(line).hasMatch();
        } else {
            if (query.caseSensitive) {
                matches = line.contains(query.pattern);
            } else {
                matches = line.contains(query.pattern, Qt::CaseInsensitive);
            }
        }
        
        if (matches) {
            // 添加上下文行
            int startLine = qMax(0, i - query.contextLines);
            int endLine = qMin(lines.count() - 1, i + query.contextLines);
            
            for (int j = startLine; j <= endLine; ++j) {
                QString prefix = (j == i) ? ">>> " : "    ";
                results.append(QString("%1:%2:%3%4").arg(QFileInfo(filePath).fileName())
                              .arg(j + 1).arg(prefix).arg(lines[j]));
            }
            
            if (query.contextLines > 0 && endLine < lines.count() - 1) {
                results.append("");  // 分隔符
            }
        }
    }
    
    return results;
}

ToolResult AdvancedSearchTool::opGrep(const QString &callId, const SearchQuery &query)
{
    QString searchPath = safePath(query.searchPath);
    if (searchPath.isEmpty()) {
        searchPath = m_workspaceRoot;
    }
    
    QFileInfo pathInfo(searchPath);
    if (!pathInfo.exists()) {
        return {callId, name(), true, "Search path not found: " + query.searchPath};
    }
    
    // 获取要搜索的文件列表
    QStringList filesToSearch;
    if (pathInfo.isDir()) {
        filesToSearch = findFilesRecursive(searchPath, query.fileExtensions);
    } else {
        filesToSearch.append(searchPath);
    }
    
    QStringList allResults;
    int matchedFiles = 0;
    
    for (const QString &file : filesToSearch) {
        QStringList fileResults = grepInFile(file, query);
        if (!fileResults.isEmpty()) {
            matchedFiles++;
            allResults.append(fileResults);
        }
    }
    
    if (allResults.isEmpty()) {
        return {callId, name(), false, "No matches found for pattern: " + query.pattern};
    }
    
    QJsonObject result;
    result["pattern"] = query.pattern;
    result["matched_files"] = matchedFiles;
    result["total_matches"] = allResults.count();
    result["results"] = QJsonArray::fromStringList(allResults.mid(0, 100));  // 限制前 100 个结果
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult AdvancedSearchTool::opFind(const QString &callId, const SearchQuery &query)
{
    QString searchPath = safePath(query.searchPath);
    if (searchPath.isEmpty()) {
        searchPath = m_workspaceRoot;
    }
    
    QFileInfo pathInfo(searchPath);
    if (!pathInfo.exists()) {
        return {callId, name(), true, "Search path not found: " + query.searchPath};
    }
    
    QStringList results;
    if (pathInfo.isDir()) {
        results = findFilesRecursive(searchPath, query.fileExtensions);
    } else {
        results.append(searchPath);
    }
    
    // 过滤结果
    if (!query.globPattern.isEmpty()) {
        QStringList filtered;
        QRegularExpression globRegex(QRegularExpression::wildcardToRegularExpression(query.globPattern));
        for (const QString &file : results) {
            if (globRegex.match(QFileInfo(file).fileName()).hasMatch()) {
                filtered.append(file);
            }
        }
        results = filtered;
    }
    
    QJsonObject resultObj;
    resultObj["pattern"] = query.globPattern.isEmpty() ? "*" : query.globPattern;
    resultObj["found_count"] = results.count();
    resultObj["results"] = QJsonArray::fromStringList(results.mid(0, 100));  // 限制前 100 个
    
    return {callId, name(), false, QJsonDocument(resultObj).toJson(QJsonDocument::Compact)};
}

ToolResult AdvancedSearchTool::opSymbol(const QString &callId, const SearchQuery &query)
{
    // 简单的符号搜索：寻找函数定义、类定义等
    QString searchPath = safePath(query.searchPath);
    if (searchPath.isEmpty()) {
        searchPath = m_workspaceRoot;
    }
    
    QStringList results;
    
    // 支持的符号类型
    QStringList patterns;
    if (query.pattern.toLower() == "function") {
        patterns << "^\\s*(async\\s+)?function\\s+\\w+" 
                 << "^\\s*(async\\s+)?(\\w+)\\s*\\([^)]*\\)\\s*\\{";
    } else if (query.pattern.toLower() == "class") {
        patterns << "^\\s*class\\s+\\w+" 
                 << "^\\s*(export\\s+)?class\\s+\\w+";
    } else if (query.pattern.toLower() == "interface") {
        patterns << "^\\s*interface\\s+\\w+";
    } else {
        patterns << "^\\s*(const|let|var|function|class)\\s+" + query.pattern;
    }
    
    QFileInfo pathInfo(searchPath);
    QStringList filesToSearch;
    
    if (pathInfo.isDir()) {
        filesToSearch = findFilesRecursive(searchPath, {"ts", "js", "cpp", "h"});
    } else {
        filesToSearch.append(searchPath);
    }
    
    for (const QString &file : filesToSearch) {
        QFile f(file);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        
        QTextStream in(&f);
        int lineNum = 0;
        while (!in.atEnd()) {
            QString line = in.readLine();
            lineNum++;
            
            for (const QString &pattern : patterns) {
                QRegularExpression regex(pattern);
                if (regex.match(line).hasMatch()) {
                    results.append(QString("%1:%2: %3").arg(QFileInfo(file).fileName())
                                  .arg(lineNum).arg(line.trimmed().left(80)));
                }
            }
        }
        f.close();
    }
    
    QJsonObject resultObj;
    resultObj["symbol_type"] = query.pattern;
    resultObj["found_count"] = results.count();
    resultObj["results"] = QJsonArray::fromStringList(results.mid(0, 100));
    
    return {callId, name(), false, QJsonDocument(resultObj).toJson(QJsonDocument::Compact)};
}
