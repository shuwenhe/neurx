#include "GeminiReadManyFilesTool.h"
#include <QFile>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>
#include <QDirIterator>
#include <QFileInfo>
#include <QJsonDocument>
#include <QRegularExpression>

GeminiReadManyFilesTool::GeminiReadManyFilesTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiReadManyFilesTool::name() const
{
    return "gemini_read_many_files";
}

QString GeminiReadManyFilesTool::description() const
{
    return "Reads multiple files matching glob patterns and concatenates their content.";
}

QJsonObject GeminiReadManyFilesTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"include", QJsonObject{
                {"type", "array"},
                {"items", QJsonObject{{"type", "string"}}},
                {"description", "Glob patterns for files to include."}
            }},
            {"exclude", QJsonObject{
                {"type", "array"},
                {"items", QJsonObject{{"type", "string"}}},
                {"description", "Optional. Glob patterns for files/directories to exclude."}
            }},
            {"base_dir", QJsonObject{
                {"type", "string"},
                {"description", "Optional. The base directory to search in. Defaults to workspace root."}
            }}
        }},
        {"required", QJsonArray{"include"}}
    };
}

ToolResult GeminiReadManyFilesTool::execute(const QString &callId, const QJsonObject &args)
{
    const QJsonArray include = args["include"].toArray();
    const QJsonArray exclude = args["exclude"].toArray();
    QString baseDir = args["base_dir"].toString();

    if (include.isEmpty()) {
        return {callId, name(), true, "Missing 'include' patterns."};
    }

    if (baseDir.isEmpty()) {
        baseDir = ".";
    }

    QStringList excludePatterns;
    for (const QJsonValue &ex : exclude) {
        excludePatterns << ex.toString();
    }

    // Default ignores if not specified otherwise (optional in future)
    if (excludePatterns.isEmpty()) {
        excludePatterns << "*.log" << ".git/*" << "node_modules/*" << "dist/*" << "build/*";
    }

    QString result;
    int filesRead = 0;
    QStringList skipped;
    QStringList processedFiles;

    for (const QJsonValue &val : include) {
        const QString pattern = val.toString();
        if (pattern.isEmpty()) continue;

        QDirIterator it(baseDir, QStringList() << pattern, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString filePath = it.next();

            // Check against exclude patterns
            bool isExcluded = false;
            for (const QString &exPattern : excludePatterns) {
                QRegularExpression re(QRegularExpression::wildcardToRegularExpression(exPattern));
                if (re.match(filePath).hasMatch()) {
                    isExcluded = true;
                    break;
                }
            }
            if (isExcluded) continue;

            if (processedFiles.contains(filePath)) continue;

            QFile file(filePath);
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&file);
                result += QString("--- %1 ---\n\n").arg(filePath);
                result += in.readAll();
                result += "\n\n";
                file.close();
                filesRead++;
                processedFiles << filePath;
            } else {
                skipped << filePath;
            }
        }
    }

    if (filesRead == 0) {
        return {callId, name(), false, "No files found matching the patterns or failed to read them."};
    }

    QJsonObject response;
    response["content"] = result;
    response["files_read"] = filesRead;
    if (!skipped.isEmpty()) {
        response["skipped"] = QJsonArray::fromStringList(skipped);
    }

    return {callId, name(), false, QJsonDocument(response).toJson(QJsonDocument::Compact)};
}
