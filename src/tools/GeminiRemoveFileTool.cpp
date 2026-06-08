#include "GeminiRemoveFileTool.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>

GeminiRemoveFileTool::GeminiRemoveFileTool(QObject *parent) : Tool(parent) {}

QString GeminiRemoveFileTool::name() const { return QStringLiteral("remove_file"); }
QString GeminiRemoveFileTool::description() const { return QStringLiteral("Delete file or directory (non-recursive by default)"); }

QJsonObject GeminiRemoveFileTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["recursive"] = QStringLiteral("boolean (optional)");
    return s;
}

QJsonObject GeminiRemoveFileTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    bool recursive = args.value("recursive").toBool(false);

    if (path.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path'"}};

    QFileInfo fi(path);
    if (!fi.exists()) return QJsonObject{{"success", false}, {"error", "Path does not exist"}};

    if (fi.isDir() && recursive) {
        QDir dir(path);
        bool ok = dir.removeRecursively();
        if (!ok) return QJsonObject{{"success", false}, {"error", "Failed to remove directory recursively"}};
        return QJsonObject{{"success", true}};
    } else if (fi.isDir()) {
        // non-recursive remove
        QDir dir(path);
        bool ok = dir.rmdir(path);
        if (!ok) return QJsonObject{{"success", false}, {"error", "Failed to remove empty directory"}};
        return QJsonObject{{"success", true}};
    } else {
        bool ok = QFile::remove(path);
        if (!ok) return QJsonObject{{"success", false}, {"error", "Failed to remove file"}};
        return QJsonObject{{"success", true}};
    }
}

