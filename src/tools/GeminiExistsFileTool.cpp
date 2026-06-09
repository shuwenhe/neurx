#include "GeminiExistsFileTool.h"
#include <QFileInfo>
#include <QJsonDocument>

GeminiExistsFileTool::GeminiExistsFileTool(QObject *parent) : BaseTool(parent) {}

QString GeminiExistsFileTool::name() const { return QStringLiteral("exists"); }
QString GeminiExistsFileTool::description() const { return QStringLiteral("Check file or directory existence"); }

QJsonObject GeminiExistsFileTool::parametersSchema() const {
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "path": { "type": "string", "description": "The path to check" }
        },
        "required": ["path"]
    })JSON").object();
}

ToolResult GeminiExistsFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString path = args.value("path").toString();
    if (path.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfo fi(path);
    QJsonObject res{{"success", true}, {"exists", fi.exists()}, {"isFile", fi.isFile()}, {"isDir", fi.isDir()}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}
