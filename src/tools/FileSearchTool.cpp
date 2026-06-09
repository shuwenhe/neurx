#include "tools/FileSearchTool.h"
#include <QFile>
#include <QFileInfo>
#include <QDirIterator>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>
#include <algorithm>

FileSearchTool::FileSearchTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_root(workspaceRoot)
{
    qInfo() << "[FileSearchTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject FileSearchTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject pattern;
    pattern["type"] = "string";
    pattern["description"] = "Search pattern (regex or literal text)";
    properties["pattern"] = pattern;
    
    QJsonObject glob;
    glob["type"] = "string";
    glob["description"] = "File glob pattern (e.g., '*.ts', 'src/**/*.js')";
    glob["default"] = "**/*";
    properties["glob"] = glob;
    
    QJsonObject mode;
    mode["type"] = "string";
    QJsonArray enumVals;
    enumVals.append("regex");
    enumVals.append("literal");
    mode["enum"] = enumVals;
    mode["description"] = "Search mode: regex (ECMAScript) or literal";
    mode["default"] = "regex";
    properties["mode"] = mode;
    
    QJsonObject caseSensitive;
    caseSensitive["type"] = "boolean";
    caseSensitive["description"] = "Case-sensitive search";
    caseSensitive["default"] = false;
    properties["case_sensitive"] = caseSensitive;
    
    QJsonObject wholeWord;
    wholeWord["type"] = "boolean";
    wholeWord["description"] = "Match whole words only (regex mode)";
    wholeWord["default"] = false;
    properties["whole_word"] = wholeWord;
    
    QJsonObject contextLines;
    contextLines["type"] = "integer";
    contextLines["description"] = "Lines of context before/after each match";
    contextLines["default"] = 2;
    contextLines["minimum"] = 0;
    contextLines["maximum"] = 10;
    properties["context_lines"] = contextLines;
    
    QJsonObject maxResults;
    maxResults["type"] = "integer";
    maxResults["description"] = "Maximum results to return";
    maxResults["default"] = 1000;
    maxResults["minimum"] = 1;
    maxResults["maximum"] = 10000;
    properties["max_results"] = maxResults;
    
    schema["properties"] = properties;
    
    QJsonArray required;
    required.append("pattern");
    schema["required"] = required;
    
    return schema;
}

ToolResult FileSearchTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString pattern = args["pattern"].toString();
    if (pattern.isEmpty()) {
        return {callId, name(), true, "Pattern cannot be empty"};
    }

    const QString glob = args.value("glob").toString("**/*");
    const QString mode = args.value("mode").toString("regex");
    const bool caseSensitive = args.value("case_sensitive").toBool(false);
    const bool wholeWord = args.value("whole_word").toBool(false);
    const int contextLines = qBound(0, args.value("context_lines").toInt(DEFAULT_CONTEXT_LINES), 10);
    const int maxResults = qBound(1, args.value("max_results").toInt(DEFAULT_MAX_RESULTS), 10000);

    SearchResult result;

    if (mode == "literal") {
        result = searchLiteral(pattern, glob, contextLines, maxResults, caseSensitive);
    } else {
        result = searchRegex(pattern, glob, contextLines, maxResults, caseSensitive, wholeWord);
    }

    // Build response
    QJsonObject response;
    response["pattern"] = pattern;
    response["glob"] = glob;
    response["mode"] = mode;
    response["total_matches"] = result.totalMatches;
    response["files_searched"] = result.filesSearched;
    response["truncated"] = result.truncated;

    QJsonArray matchesArray;
    for (const auto &match : result.matches) {
        QJsonObject matchObj;
        matchObj["file"] = match.filepath;
        matchObj["line"] = match.lineNumber;
        matchObj["column"] = match.columnNumber;
        matchObj["content"] = match.lineContent;
        if (!match.beforeContext.isEmpty()) {
            matchObj["before_context"] = match.beforeContext;
        }
        if (!match.afterContext.isEmpty()) {
            matchObj["after_context"] = match.afterContext;
        }
        matchesArray.append(matchObj);
    }
    response["matches"] = matchesArray;

    if (!result.matchedFiles.isEmpty()) {
        response["matched_files"] = QJsonArray::fromStringList(result.matchedFiles);
    }

    if (!result.error.isEmpty()) {
        response["error"] = result.error;
    }

    return {callId, name(), result.totalMatches == 0, QJsonDocument(response).toJson(QJsonDocument::Compact)};
}

QString FileSearchTool::summary(const QJsonObject &args) const
{
    return QString("Search '%1' in %2")
        .arg(args["pattern"].toString())
        .arg(args.value("glob").toString("**/*"));
}

FileSearchTool::SearchResult FileSearchTool::searchRegex(
    const QString &pattern,
    const QString &glob,
    int contextLines,
    int maxResults,
    bool caseSensitive,
    bool wholeWord)
{
    SearchResult result;

    try {
        // Build regex pattern
        QString regexPattern = pattern;
        if (wholeWord) {
            regexPattern = QString(R"(\b%1\b)").arg(QRegularExpression::escape(pattern));
        }

        QRegularExpression::PatternOptions options;
        if (!caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }
        options |= QRegularExpression::UseUnicodePropertiesOption;

        QRegularExpression regex(regexPattern, options);
        if (!regex.isValid()) {
            result.error = QString("Invalid regex: %1").arg(regex.errorString());
            return result;
        }

        // Enumerate files
        const QStringList files = enumerateFiles(m_root.absolutePath(), glob);
        result.filesSearched = files.count();

        QSet<QString> matchedFiles;
        int currentMatches = 0;

        for (const QString &filepath : files) {
            if (currentMatches >= maxResults) {
                result.truncated = true;
                break;
            }

            if (isBinaryFile(filepath)) {
                continue;
            }

            QFile file(filepath);
            if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                continue;
            }

            // Check file size
            if (file.size() > MAX_FILE_SIZE_BYTES) {
                file.close();
                continue;
            }

            QTextStream in(&file);
            int lineNumber = 0;
            while (!in.atEnd() && currentMatches < maxResults) {
                ++lineNumber;
                const QString line = in.readLine();

                QRegularExpressionMatchIterator it = regex.globalMatch(line);
                while (it.hasNext()) {
                    QRegularExpressionMatch match = it.next();

                    SearchMatch searchMatch;
                    searchMatch.filepath = m_root.relativeFilePath(filepath);
                    searchMatch.lineNumber = lineNumber;
                    searchMatch.columnNumber = match.capturedStart() + 1;  // 1-based
                    searchMatch.lineContent = line;

                    if (contextLines > 0) {
                        const auto contextParts = getContextLines(filepath, lineNumber, contextLines, contextLines);
                        if (contextParts.count() >= 2) {
                            searchMatch.beforeContext = contextParts[0];
                            searchMatch.afterContext = contextParts[1];
                        }
                    }

                    result.matches.append(searchMatch);
                    currentMatches++;

                    if (currentMatches >= maxResults) {
                        result.truncated = true;
                        break;
                    }
                }
            }

            if (currentMatches > 0) {
                matchedFiles.insert(m_root.relativeFilePath(filepath));
            }

            file.close();
        }

        result.totalMatches = currentMatches;
        result.matchedFiles = matchedFiles.values();
        std::sort(result.matchedFiles.begin(), result.matchedFiles.end());

    } catch (const std::exception &e) {
        result.error = QString("Search error: %1").arg(QString::fromStdString(e.what()));
    }

    return result;
}

FileSearchTool::SearchResult FileSearchTool::searchLiteral(
    const QString &text,
    const QString &glob,
    int contextLines,
    int maxResults,
    bool caseSensitive)
{
    SearchResult result;

    // Enumerate files
    const QStringList files = enumerateFiles(m_root.absolutePath(), glob);
    result.filesSearched = files.count();

    QSet<QString> matchedFiles;
    int currentMatches = 0;
    Qt::CaseSensitivity cs = caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;

    for (const QString &filepath : files) {
        if (currentMatches >= maxResults) {
            result.truncated = true;
            break;
        }

        if (isBinaryFile(filepath)) {
            continue;
        }

        QFile file(filepath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        // Check file size
        if (file.size() > MAX_FILE_SIZE_BYTES) {
            file.close();
            continue;
        }

        QTextStream in(&file);
        int lineNumber = 0;
        while (!in.atEnd() && currentMatches < maxResults) {
            ++lineNumber;
            const QString line = in.readLine();

            int pos = 0;
            while ((pos = line.indexOf(text, pos, cs)) != -1) {
                if (currentMatches >= maxResults) {
                    result.truncated = true;
                    break;
                }

                SearchMatch searchMatch;
                searchMatch.filepath = m_root.relativeFilePath(filepath);
                searchMatch.lineNumber = lineNumber;
                searchMatch.columnNumber = pos + 1;  // 1-based
                searchMatch.lineContent = line;

                if (contextLines > 0) {
                    const auto contextParts = getContextLines(filepath, lineNumber, contextLines, contextLines);
                    if (contextParts.count() >= 2) {
                        searchMatch.beforeContext = contextParts[0];
                        searchMatch.afterContext = contextParts[1];
                    }
                }

                result.matches.append(searchMatch);
                currentMatches++;
                pos += text.length();
            }
        }

        if (currentMatches > 0) {
            matchedFiles.insert(m_root.relativeFilePath(filepath));
        }

        file.close();
    }

    result.totalMatches = currentMatches;
    result.matchedFiles = matchedFiles.values();
    std::sort(result.matchedFiles.begin(), result.matchedFiles.end());

    return result;
}

bool FileSearchTool::matchesGlobPattern(const QString &filepath, const QString &pattern) const
{
    // Simple glob pattern matching (supports *, **, ?)
    QRegularExpression globRegex(
        "^" + QRegularExpression::wildcardToRegularExpression(pattern) + "$",
        QRegularExpression::CaseInsensitiveOption);
    return globRegex.match(filepath).hasMatch();
}

bool FileSearchTool::isBinaryFile(const QString &filepath) const
{
    // Common binary extensions
    static const QSet<QString> binaryExtensions{
        "bin", "exe", "dll", "so", "dylib", "o", "a", "lib",
        "class", "pyc", "pyo", "zip", "tar", "gz", "rar",
        "jpg", "jpeg", "png", "gif", "bmp", "ico", "tiff",
        "mp3", "mp4", "wav", "flac", "mov", "avi", "mkv",
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "git", "sqlite", "db"
    };

    const QString ext = QFileInfo(filepath).suffix().toLower();
    if (binaryExtensions.contains(ext)) {
        return true;
    }

    // Check first 512 bytes for null bytes
    QFile file(filepath);
    if (file.open(QIODevice::ReadOnly)) {
        const QByteArray header = file.read(512);
        file.close();
        if (header.contains('\0')) {
            return true;
        }
    }

    return false;
}

QString FileSearchTool::safePath(const QString &relOrAbsPath) const
{
    QFileInfo fi(relOrAbsPath);
    if (fi.isAbsolute()) {
        return QDir::cleanPath(fi.absoluteFilePath());
    }
    return QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
}

QStringList FileSearchTool::getContextLines(
    const QString &filepath,
    int lineNumber,
    int beforeCount,
    int afterCount) const
{
    QStringList result;
    QString beforeContext, afterContext;

    QFile file(filepath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {beforeContext, afterContext};
    }

    QTextStream in(&file);
    QStringList allLines;
    while (!in.atEnd()) {
        allLines.append(in.readLine());
    }
    file.close();

    // Get before context
    int startLine = qMax(0, lineNumber - beforeCount - 1);
    for (int i = startLine; i < lineNumber - 1; ++i) {
        if (i >= 0 && i < allLines.count()) {
            beforeContext += QString::number(i + 1) + ": " + allLines[i] + "\n";
        }
    }

    // Get after context
    int endLine = qMin(allLines.count(), lineNumber + afterCount);
    for (int i = lineNumber; i < endLine; ++i) {
        if (i >= 0 && i < allLines.count()) {
            afterContext += QString::number(i + 1) + ": " + allLines[i] + "\n";
        }
    }

    result.append(beforeContext);
    result.append(afterContext);
    return result;
}

int FileSearchTool::getLineNumber(const QString &filepath, qint64 byteOffset) const
{
    QFile file(filepath);
    if (!file.open(QIODevice::ReadOnly)) {
        return -1;
    }

    int lineNumber = 1;
    qint64 pos = 0;
    while (pos < byteOffset && !file.atEnd()) {
        const QByteArray chunk = file.read(1);
        if (chunk.isEmpty()) {
            break;
        }
        const char c = chunk.at(0);
        if (c == '\n') {
            lineNumber++;
        }
        pos++;
    }

    file.close();
    return lineNumber;
}

QStringList FileSearchTool::enumerateFiles(const QString &baseDir, const QString &glob) const
{
    QStringList files;
    QDirIterator it(baseDir, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);

    // Parse glob pattern to filter
    QString globFilter = glob;
    bool isRecursive = globFilter.contains("**");

    int fileCount = 0;
    while (it.hasNext() && fileCount < DEFAULT_MAX_FILES) {
        const QString filepath = it.next();
        const QString relative = m_root.relativeFilePath(filepath);

        if (matchesGlobPattern(relative, glob)) {
            files.append(filepath);
            fileCount++;
        }
    }

    std::sort(files.begin(), files.end());
    return files;
}
