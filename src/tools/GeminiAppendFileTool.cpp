#include "GeminiAppendFileTool.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QFileInfo>

GeminiAppendFileTool::GeminiAppendFileTool(QObject *parent) : Tool(parent) {}

QString GeminiAppendFileTool::name() const { return QStringLiteral("append_file"); }
QString GeminiAppendFileTool::description() const { return QStringLiteral("Append text to a file (create if missing)"); }

QJsonObject GeminiAppendFileTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["content"] = QStringLiteral("string");
    return s;
}

QJsonObject GeminiAppendFileTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    QString content = args.value("content").toString();

    if (path.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path'"}};

    QFileInfo fi(path);
    QDir dir(fi.path());
    if (!dir.exists()) {
        if (!dir.mkpath(".")) return QJsonObject{{"success", false}, {"error", "Failed to create parent directory"}};
    }

    QFile file(path);
    if (!file.open(QIODevice::Append | QIODevice::Text)) {
        return QJsonObject{{"success", false}, {"error", file.errorString()}};
    }
    QTextStream out(&file);
    out << content;
    file.close();
    return QJsonObject{{"success", true}};
}

