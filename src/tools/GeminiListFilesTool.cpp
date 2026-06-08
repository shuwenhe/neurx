#include "GeminiListFilesTool.h"
#include <QFileInfoList>
#include <QJsonArray>
#include <QDirIterator>
#include <QJsonDocument>

GeminiListFilesTool::GeminiListFilesTool(QObject *parent) : BaseTool(parent) {}

QString GeminiListFilesTool::name() const { return QStringLiteral("list_files"); }
QString GeminiListFilesTool::description() const { return QStringLiteral("List files in a directory"); }

QJsonObject GeminiListFilesTool::parametersSchema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["recursive"] = QStringLiteral("boolean (optional)");
    s["pattern"] = QStringLiteral("string (optional, glob)");
    return s;
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

    QJsonArray items;
    if (recursive) {
        QDirIterator it(path, QStringList() << pattern, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            items.append(it.filePath());
        }
    } else {
        QFileInfoList list = dir.entryInfoList(QStringList() << pattern, QDir::AllEntries | QDir::NoDotAndDotDot, QDir::Name);
        for (const QFileInfo &fi : list) items.append(fi.filePath());
    }

    QJsonObject res{{"success", true}, {"items", items}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}

