#include "GeminiExistsFileTool.h"
#include <QFileInfo>

GeminiExistsFileTool::GeminiExistsFileTool(QObject *parent) : Tool(parent) {}

QString GeminiExistsFileTool::name() const { return QStringLiteral("exists"); }
QString GeminiExistsFileTool::description() const { return QStringLiteral("Check file or directory existence"); }

QJsonObject GeminiExistsFileTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    return s;
}

QJsonObject GeminiExistsFileTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    if (path.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path'"}};

    QFileInfo fi(path);
    return QJsonObject{{"success", true}, {"exists", fi.exists()}, {"isFile", fi.isFile()}, {"isDir", fi.isDir()}};
}

