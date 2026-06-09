#include "GeminiListFilesTool.h"
#include <QDirIterator>
#include <QFileInfoList>
#include <QJsonArray>
#include <QJsonDocument>

GeminiListFilesTool::GeminiListFilesTool(QObject *parent) : BaseTool(parent) {}

QString GeminiListFilesTool::name() const { return QStringLiteral("list_files"); }
QString GeminiListFilesTool::description() const { return QStringLiteral("List files in a directory"); }

QJsonObject GeminiListFilesTool::parametersSchema() const {
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "path": { "type": "string", "description": "The directory path to list" },
            "recursive": { "type": "boolean", "description": "Whether to list files recursively", "default": false },
            "pattern": { "type": "string", "description": "Glob pattern for matching files", "default": "*" }
        },
        "required": ["path"]
    })JSON").object();
}

ToolResult GeminiListFilesTool::execute(const QString &callId, const QJsonObject &args)
{
    QString path = args.value("path").toString();
    bool recursive = args.value("recursive").toBool(false);
    QString pattern = args.value("pattern").toString("*");

    if (path.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path' argument"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QDir dir(path);
    if (!dir.exists()) {
        QJsonObject res{{"success", false}, {"error", QString("Directory does not exist: %1").arg(path)}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfoList entries;
    if (recursive) {
        QDirIterator it(path, QStringList() << pattern, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            entries.append(it.fileInfo());
        }
    } else {
        entries = dir.entryInfoList(QStringList() << pattern, QDir::AllEntries | QDir::NoDotAndDotDot, QDir::Name);
    }

    // Sort: Directories first, then alphabetically
    std::sort(entries.begin(), entries.end(), [](const QFileInfo &a, const QFileInfo &b) {
        if (a.isDir() && !b.isDir()) return true;
        if (!a.isDir() && b.isDir()) return false;
        return QString::compare(a.fileName(), b.fileName(), Qt::CaseInsensitive) < 0;
    });

    QJsonArray items;
    for (const QFileInfo &fi : entries) {
        QJsonObject item;
        item["name"] = fi.fileName();
        item["path"] = fi.absoluteFilePath();
        item["is_dir"] = fi.isDir();
        item["size"] = fi.size();
        item["modified"] = fi.lastModified().toString(Qt::ISODate);
        items.append(item);
    }

    QJsonObject res{{"success", true}, {"items", items}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}
