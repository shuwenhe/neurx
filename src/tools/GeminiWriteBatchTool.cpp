#include "GeminiWriteBatchTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QSaveFile>

QJsonObject GeminiWriteBatchTool::parametersSchema() const {
    QJsonObject props;
    props["files"] = QJsonObject{
        {"type", "array"},
        {"description", "Array of objects with 'path' and 'content' or 'contentsBase64'"},
        {"items", QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"path", QJsonObject{{"type", "string"}}},
                {"content", QJsonObject{{"type", "string"}}},
                {"contentsBase64", QJsonObject{{"type", "string"}}}
            }},
            {"required", QJsonArray{"path"}}
        }}
    };
    props["atomic"] = QJsonObject{{"type", "boolean"}, {"description", "Use atomic write for each file"}};
    return QJsonObject{{"type", "object"}, {"properties", props}, {"required", QJsonArray{"files"}}};
}

ToolResult GeminiWriteBatchTool::execute(const QString &callId, const QJsonObject &args) {
    QJsonArray files = args.value("files").toArray();
    bool atomic = args.value("atomic").toBool(false);

    int count = 0;
    for (const QJsonValue &v : files) {
        QJsonObject fileObj = v.toObject();
        QString path = fileObj.value("path").toString();
        if (path.isEmpty()) continue;

        QByteArray bytes;
        if (fileObj.contains("contentsBase64")) {
            bytes = QByteArray::fromBase64(fileObj.value("contentsBase64").toString().toLatin1());
        } else if (fileObj.contains("content")) {
            bytes = fileObj.value("content").toString().toUtf8();
        }

        QFileInfo finfo(path);
        QDir().mkpath(finfo.dir().absolutePath());

        if (atomic) {
            QSaveFile file(path);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(bytes);
                if (file.commit()) count++;
            }
        } else {
            QFile file(path);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(bytes);
                file.close();
                count++;
            }
        }
    }

    QJsonObject res{{"success", true}, {"count", count}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}

