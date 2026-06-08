#include "GeminiCopyFileTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QDirIterator>

QJsonObject GeminiCopyFileTool::parametersSchema() const {
    QJsonObject props;
    props["source"] = QJsonObject{{"type", "string"}, {"description", "Source path"}};
    props["destination"] = QJsonObject{{"type", "string"}, {"description", "Destination path"}};
    props["recursive"] = QJsonObject{{"type", "boolean"}, {"description", "Copy recursively for directories"}};
    return QJsonObject{{"type", "object"}, {"properties", props}, {"required", QJsonArray{"source", "destination"}}};
}

static bool copyRecursively(const QString &srcPath, const QString &dstPath) {
    QFileInfo srcInfo(srcPath);
    if (srcInfo.isDir()) {
        QDir dstDir(dstPath);
        if (!dstDir.mkpath(".")) return false;
        QDir srcDir(srcPath);
        QStringList entries = srcDir.entryList(QDir::NoDotAndDotDot | QDir::AllEntries);
        for (const QString &entry : entries) {
            if (!copyRecursively(srcPath + "/" + entry, dstPath + "/" + entry)) return false;
        }
    } else {
        if (!QFile::copy(srcPath, dstPath)) return false;
    }
    return true;
}

ToolResult GeminiCopyFileTool::execute(const QString &callId, const QJsonObject &args) {
    QString src = args.value("source").toString();
    QString dst = args.value("destination").toString();
    bool recursive = args.value("recursive").toBool(false);

    if (src.isEmpty() || dst.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'source' or 'destination'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    QFileInfo srcInfo(src);
    if (!srcInfo.exists()) {
        QJsonObject res{{"success", false}, {"error", "Source path does not exist"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

    bool ok = false;
    if (srcInfo.isDir()) {
        if (recursive) {
            ok = copyRecursively(src, dst);
        } else {
            QJsonObject res{{"success", false}, {"error", "Source is a directory but 'recursive' not set"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }
    } else {
        ok = QFile::copy(src, dst);
    }

    if (ok) {
        QJsonObject res{{"success", true}, {"from", src}, {"to", dst}};
        return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    } else {
        QJsonObject res{{"success", false}, {"error", "Failed to copy"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }
}

