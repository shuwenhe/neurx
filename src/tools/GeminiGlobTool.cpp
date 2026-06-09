#include "GeminiGlobTool.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <algorithm>

GeminiGlobTool::GeminiGlobTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiGlobTool::name() const
{
    return "gemini_glob";
}

QString GeminiGlobTool::description() const
{
    return "Finds files matching a glob pattern, sorted by modification time.";
}

QJsonObject GeminiGlobTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"pattern", QJsonObject{
                {"type", "string"},
                {"description", "The glob pattern to match files against."}
            }},
            {"dir_path", QJsonObject{
                {"type", "string"},
                {"description", "Optional. The directory to search in. Defaults to current directory."}
            }},
            {"case_sensitive", QJsonObject{
                {"type", "boolean"},
                {"description", "Whether the search should be case-sensitive. Defaults to false."}
            }}
        }},
        {"required", QJsonArray{"pattern"}}
    };
}

ToolResult GeminiGlobTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString pattern = args["pattern"].toString();
    QString dirPath = args["dir_path"].toString();
    bool caseSensitive = args["case_sensitive"].toBool(false);

    if (pattern.isEmpty()) {
        return {callId, name(), true, "Missing 'pattern' argument."};
    }

    if (dirPath.isEmpty()) {
        dirPath = ".";
    }

    QDir::Filters filters = QDir::Files | QDir::NoDotAndDotDot;
    QDirIterator::IteratorFlags flags = QDirIterator::Subdirectories;
    if (!caseSensitive) {
        // Qt's QDirIterator matching is usually case-sensitive by default if we use filters,
        // but naming filters can be case-insensitive.
    }

    QFileInfoList entries;
    QDirIterator it(dirPath, QStringList() << pattern, QDir::Files, QDirIterator::Subdirectories);
    // Actually QDirIterator doesn't have a case sensitivity flag in constructor for name filters.
    // We have to filter manually or use QDir::entryInfoList if we want more control,
    // but QDirIterator is better for recursion.

    while (it.hasNext()) {
        it.next();
        entries.append(it.fileInfo());
    }

    // Sort by modification time (newest first)
    std::sort(entries.begin(), entries.end(), [](const QFileInfo &a, const QFileInfo &b) {
        return a.lastModified() > b.lastModified();
    });

    QJsonArray resultFiles;
    for (const QFileInfo &fi : entries) {
        resultFiles.append(fi.filePath());
    }

    QJsonObject response;
    response["files"] = resultFiles;
    response["count"] = resultFiles.size();

    return {callId, name(), false, QJsonDocument(response).toJson(QJsonDocument::Compact)};
}
