#include "GeminiListFilesTool.h"
#include <QFileInfoList>
#include <QJsonArray>
#include <QDirIterator>

GeminiListFilesTool::GeminiListFilesTool(QObject *parent) : Tool(parent) {}

QString GeminiListFilesTool::name() const { return QStringLiteral("list_files"); }
QString GeminiListFilesTool::description() const { return QStringLiteral("List files in a directory"); }

QJsonObject GeminiListFilesTool::schema() const {
    // 简单 schema，前端可据此生成 UI
    QJsonObject s;
    s["path"] = QStringLiteral("string");
    s["recursive"] = QStringLiteral("boolean (optional)");
    s["pattern"] = QStringLiteral("string (optional, glob)");
    return s;
}

QJsonObject GeminiListFilesTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    bool recursive = args.value("recursive").toBool(false);
    QString pattern = args.value("pattern").toString("*");

    if (path.isEmpty()) {
        return QJsonObject{{"success", false}, {"error", "Missing 'path' argument"}};
    }

    QDir dir(path);
    if (!dir.exists()) {
        return QJsonObject{{"success", false}, {"error", QString("Directory does not exist: %1").arg(path)}};
    }

    QJsonArray items;
    if (recursive) {
        QDirIterator it(path, QStringList() << pattern, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            items.append(it.filePath());
        }
    } else {
        QFileInfoList list = dir.entryInfoList(QStringList() << pattern, QDir::AllEntries | QDir::NoDotAndDotDot, QDir::Name);
        for (const QFileInfo &fi : list) items.append(fi.filePath());
    }

    return QJsonObject{{"success", true}, {"items", items}};
}

