#include "GeminiAppendFileTool.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>

GeminiAppendFileTool::GeminiAppendFileTool(QObject *parent) : BaseTool(parent) {}

QString GeminiAppendFileTool::name() const { return QStringLiteral("append_file"); }
QString GeminiAppendFileTool::description() const { return QStringLiteral("Append text to a file (create if missing)"); }

QJsonObject GeminiAppendFileTool::parametersSchema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["content"] = QStringLiteral("string");
    return s;
}

ToolResult GeminiAppendFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString path = args.value("path").toString();
    QString content = args.value("content").toString();

    if (path.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfo fi(path);
    QDir dir(fi.path());
    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            QJsonObject res{{"success", false}, {"error", "Failed to create parent directory"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }
    }

    QFile file(path);
    if (!file.open(QIODevice::Append | QIODevice::Text)) {
        QJsonObject res{{"success", false}, {"error", file.errorString()}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }
    QTextStream out(&file);
    out << content;
    file.close();
    QJsonObject res{{"success", true}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}

