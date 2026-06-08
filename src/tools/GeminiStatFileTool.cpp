#include "GeminiStatFileTool.h"
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>

GeminiStatFileTool::GeminiStatFileTool(QObject *parent) : BaseTool(parent) {}

QString GeminiStatFileTool::name() const { return QStringLiteral("stat_file"); }
QString GeminiStatFileTool::description() const { return QStringLiteral("Get file/directory metadata"); }

QJsonObject GeminiStatFileTool::parametersSchema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    return s;
}

ToolResult GeminiStatFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString path = args.value("path").toString();
    if (path.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfo fi(path);
    if (!fi.exists()) {
        QJsonObject res{{"success", false}, {"error", "Path does not exist"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QJsonObject result;
    result["success"] = true;
    result["absolutePath"] = fi.absoluteFilePath();
    result["isFile"] = fi.isFile();
    result["isDir"] = fi.isDir();
    result["size"] = static_cast<qint64>(fi.size());
    result["lastModified"] = fi.lastModified().toString(Qt::ISODate);
    result["lastRead"] = fi.lastRead().toString(Qt::ISODate);
    result["owner"] = fi.owner();
    result["group"] = fi.group();

    return {callId, name(), false, QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact))};
}

