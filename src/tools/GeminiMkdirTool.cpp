#include "GeminiMkdirTool.h"
#include <QDir>

GeminiMkdirTool::GeminiMkdirTool(QObject *parent) : Tool(parent) {}

QString GeminiMkdirTool::name() const { return QStringLiteral("make_dir"); }
QString GeminiMkdirTool::description() const { return QStringLiteral("Create directory (optionally recursive)"); }

QJsonObject GeminiMkdirTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["recursive"] = QStringLiteral("boolean (optional, default true)");
    return s;
}

QJsonObject GeminiMkdirTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    bool recursive = args.value("recursive").toBool(true);

    if (path.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path'"}};

    QDir dir;
    bool ok = recursive ? dir.mkpath(path) : dir.mkdir(path);
    if (!ok) return QJsonObject{{"success", false}, {"error", "Failed to create directory"}};
    return QJsonObject{{"success", true}};
}

