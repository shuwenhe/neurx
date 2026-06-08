#include "GeminiMoveFileTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>

QJsonObject GeminiMoveFileTool::parametersSchema() const {
    QJsonObject props;
    props["source"] = QJsonObject{{"type", "string"}, {"description", "Source path"}};
    props["destination"] = QJsonObject{{"type", "string"}, {"description", "Destination path"}};
    return QJsonObject{{"type", "object"}, {"properties", props}, {"required", QJsonArray{"source", "destination"}}};
}

ToolResult GeminiMoveFileTool::execute(const QString &callId, const QJsonObject &args) {
    QString src = args.value("source").toString();
    QString dst = args.value("destination").toString();

    if (src.isEmpty() || dst.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'source' or 'destination'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfo srcInfo(src);
    if (!srcInfo.exists()) {
        QJsonObject res{{"success", false}, {"error", "Source path does not exist"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    // Attempt to rename/move
    bool ok = false;
    if (srcInfo.isDir()) {
        QDir dir;
        ok = dir.rename(src, dst);
    } else {
        ok = QFile::rename(src, dst);
    }

    if (!ok) {
        // Try fallback for cross-device if it is a file
        if (srcInfo.isFile()) {
            if (QFile::copy(src, dst)) {
                if (QFile::remove(src)) {
                    ok = true;
                } else {
                    // Copied but couldn't delete original
                     QJsonObject res{{"success", false}, {"error", "Copied to destination but failed to remove source"}};
                     return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
                }
            }
        }
    }

    if (ok) {
        QJsonObject res{{"success", true}, {"from", src}, {"to", dst}};
        return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    } else {
        QJsonObject res{{"success", false}, {"error", "Failed to move/rename"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }
}

