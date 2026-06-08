#include "GeminiGrepTool.h"
#include <QFile>
#include <QTextStream>
#include <QDirIterator>
#include <QJsonArray>
#include <QRegularExpression>
#include <QFileInfo>

GeminiGrepTool::GeminiGrepTool(QObject *parent) : Tool(parent) {}

QString GeminiGrepTool::name() const { return QStringLiteral("grep"); }
QString GeminiGrepTool::description() const { return QStringLiteral("Search for text in files (simple grep)"); }

QJsonObject GeminiGrepTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string (file or directory)"); // directory => recursive
    s["pattern"] = QStringLiteral("string (regular expression)");
    s["recursive"] = QStringLiteral("boolean (optional)");
    return s;
}

QJsonObject GeminiGrepTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    QString pattern = args.value("pattern").toString();
    bool recursive = args.value("recursive").toBool(true);

    if (path.isEmpty() || pattern.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path' or 'pattern'"}};

    QRegularExpression rx(pattern);
    if (!rx.isValid()) return QJsonObject{{"success", false}, {"error", "Invalid regular expression"}};

    QJsonArray matches;

    QFileInfo fi(path);
    if (fi.isFile()) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&file);
            int lineNo = 0;
            while (!in.atEnd()) {
                QString line = in.readLine();
                ++lineNo;
                if (rx.match(line).hasMatch()) {
                    QJsonObject m;
                    m["file"] = path;
                    m["line"] = lineNo;
                    m["text"] = line;
                    matches.append(m);
                }
            }
            file.close();
        }
    } else if (fi.isDir()) {
        QDirIterator it(path, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            if (!QFileInfo(it.filePath()).isFile()) continue;
            QFile file(it.filePath());
            if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
            QTextStream in(&file);
            int lineNo = 0;
            while (!in.atEnd()) {
                QString line = in.readLine();
                ++lineNo;
                if (rx.match(line).hasMatch()) {
                    QJsonObject m;
                    m["file"] = it.filePath();
                    m["line"] = lineNo;
                    m["text"] = line;
                    matches.append(m);
                }
            }
            file.close();
        }
    } else {
        return QJsonObject{{"success", false}, {"error", "Path is neither file nor directory"}};
    }

    return QJsonObject{{"success", true}, {"matches", matches}};
}

