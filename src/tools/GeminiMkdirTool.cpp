#include "GeminiMkdirTool.h"
#include <QDir>
#include <QJsonDocument>

GeminiMkdirTool::GeminiMkdirTool(QObject *parent) : BaseTool(parent) {}

QString GeminiMkdirTool::name() const { return QStringLiteral("make_dir"); }
QString GeminiMkdirTool::description() const { return QStringLiteral("Create directory (optionally recursive)"); }

QJsonObject GeminiMkdirTool::parametersSchema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["recursive"] = QStringLiteral("boolean (optional, default true)");
    return s;
}

ToolResult GeminiMkdirTool::execute(const QString &callId, const QJsonObject &args)
{
    QString path = args.value("path").toString();
    bool recursive = args.value("recursive").toBool(true);

    if (path.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QDir dir;
    bool ok = recursive ? dir.mkpath(path) : dir.mkdir(path);
    if (!ok) {
        QJsonObject res{{"success", false}, {"error", "Failed to create directory"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }
    QJsonObject res{{"success", true}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}

