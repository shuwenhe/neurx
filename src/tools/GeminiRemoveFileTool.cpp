#include "GeminiRemoveFileTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>

GeminiRemoveFileTool::GeminiRemoveFileTool(QObject *parent) : BaseTool(parent) {}

QString GeminiRemoveFileTool::name() const { return QStringLiteral("remove_file"); }
QString GeminiRemoveFileTool::description() const { return QStringLiteral("Delete file or directory (non-recursive by default)"); }

QJsonObject GeminiRemoveFileTool::parametersSchema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["recursive"] = QStringLiteral("boolean (optional)");
    return s;
}

ToolResult GeminiRemoveFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString path = args.value("path").toString();
    bool recursive = args.value("recursive").toBool(false);

    if (path.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfo fi(path);
    if (!fi.exists()) {
        QJsonObject res{{"success", false}, {"error", "Path does not exist"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    if (fi.isDir() && recursive) {
        QDir dir(path);
        bool ok = dir.removeRecursively();
        if (!ok) {
            QJsonObject res{{"success", false}, {"error", "Failed to remove directory recursively"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }
        QJsonObject res{{"success", true}};
        return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    } else if (fi.isDir()) {
        QDir dir(path);
        bool ok = dir.rmdir(path);
        if (!ok) {
            QJsonObject res{{"success", false}, {"error", "Failed to remove empty directory"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }
        QJsonObject res{{"success", true}};
        return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    } else {
        bool ok = QFile::remove(path);
        if (!ok) {
            QJsonObject res{{"success", false}, {"error", "Failed to remove file"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }
        QJsonObject res{{"success", true}};
        return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }
}

