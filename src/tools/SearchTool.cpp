#include "tools/SearchTool.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QJsonDocument>

SearchTool::SearchTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{}

QJsonObject SearchTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "operation": {
                "type": "string",
                "enum": ["grep_search", "find_files"],
                "description": "grep_search: search file contents; find_files: match file paths."
            },
            "pattern": {
                "type": "string",
                "description": "Regex pattern for grep_search, or glob-like pattern for find_files."
            },
            "include": {
                "type": "string",
                "description": "File name glob filter, e.g. '*.cpp' (optional)."
            },
            "case_sensitive": {
                "type": "boolean",
                "description": "Case-sensitive matching (default false)."
            },
            "max_results": {
                "type": "integer",
                "description": "Maximum number of results to return (default 50)."
            }
        },
        "required": ["operation", "pattern"]
    })").object();
}

ToolResult SearchTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString op = args["operation"].toString();
    if (op == "grep_search") return opGrepSearch(callId, args);
    if (op == "find_files")  return opFindFiles(callId, args);
    return {callId, name(), true, "Unknown operation: " + op};
}

QString SearchTool::summary(const QJsonObject &args) const
{
    return args["operation"].toString() + ": " + args["pattern"].toString();
}

ToolResult SearchTool::opGrepSearch(const QString &callId, const QJsonObject &args)
{
    const QString patternStr = args["pattern"].toString();
    const bool caseSensitive = args.value("case_sensitive").toBool(false);
    const int maxResults     = args.value("max_results").toInt(50);
    const QString include    = args.value("include").toString();

    QRegularExpression re(patternStr,
        caseSensitive ? QRegularExpression::NoPatternOption
                      : QRegularExpression::CaseInsensitiveOption);
    if (!re.isValid())
        return {callId, name(), true, "Invalid regex: " + re.errorString()};

    QStringList nameFilters;
    if (!include.isEmpty()) nameFilters << include;

    QDirIterator it(m_workspaceRoot, nameFilters,
                    QDir::Files | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);

    QStringList results;
    int count = 0;
    while (it.hasNext() && count < maxResults) {
        const QString filePath = it.next();
        QFile f(filePath);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        QTextStream in(&f);
        int lineNum = 0;
        while (!in.atEnd() && count < maxResults) {
            ++lineNum;
            const QString line = in.readLine();
            if (re.match(line).hasMatch()) {
                const QString rel = QDir(m_workspaceRoot).relativeFilePath(filePath);
                results << QString("%1:%2:%3").arg(rel).arg(lineNum).arg(line.trimmed());
                ++count;
            }
        }
    }
    if (results.isEmpty()) return {callId, name(), false, "No matches found."};
    return {callId, name(), false, results.join("\n")};
}

ToolResult SearchTool::opFindFiles(const QString &callId, const QJsonObject &args)
{
    const QString pattern = args["pattern"].toString();
    const int maxResults  = args.value("max_results").toInt(100);

    QDirIterator it(m_workspaceRoot, QStringList() << "*",
                    QDir::Files | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);

    QRegularExpression re(QRegularExpression::wildcardToRegularExpression(pattern),
                          QRegularExpression::CaseInsensitiveOption);

    QStringList results;
    while (it.hasNext() && results.size() < maxResults) {
        const QString filePath = it.next();
        const QString rel = QDir(m_workspaceRoot).relativeFilePath(filePath);
        if (re.match(rel).hasMatch())
            results << rel;
    }
    if (results.isEmpty()) return {callId, name(), false, "No files matched."};
    return {callId, name(), false, results.join("\n")};
}
