#include "GeminiStatFileTool.h"
#include <QFileInfo>
#include <QJsonObject>

GeminiStatFileTool::GeminiStatFileTool(QObject *parent) : Tool(parent) {}

QString GeminiStatFileTool::name() const { return QStringLiteral("stat_file"); }
QString GeminiStatFileTool::description() const { return QStringLiteral("Get file/directory metadata"); }

QJsonObject GeminiStatFileTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    return s;
}

QJsonObject GeminiStatFileTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    if (path.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path'"}};

    QFileInfo fi(path);
    if (!fi.exists()) return QJsonObject{{"success", false}, {"error", "Path does not exist"}};

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
    return result;
}

