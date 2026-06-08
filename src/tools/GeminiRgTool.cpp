#include "GeminiRgTool.h"
#include <QProcess>
#include <QJsonArray>
#include <QFileInfo>
#include <QDirIterator>
#include <QTextStream>

GeminiRgTool::GeminiRgTool(QObject *parent) : Tool(parent) {}

QString GeminiRgTool::name() const { return QStringLiteral("rg_search"); }
QString GeminiRgTool::description() const { return QStringLiteral("Search using ripgrep if available, fallback to simple grep"); }

QJsonObject GeminiRgTool::schema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string (file or directory)");
    s["pattern"] = QStringLiteral("string (regular expression)");
    s["recursive"] = QStringLiteral("boolean (optional)");
    return s;
}

QJsonObject GeminiRgTool::run(const QJsonObject &args) {
    QString path = args.value("path").toString();
    QString pattern = args.value("pattern").toString();
    bool recursive = args.value("recursive").toBool(true);

    if (path.isEmpty() || pattern.isEmpty()) return QJsonObject{{"success", false}, {"error", "Missing 'path' or 'pattern'"}};

    // Try to run rg
    QProcess check;
    check.start("rg", {"--version"});
    check.waitForFinished(500);
    bool hasRg = (check.exitStatus() == QProcess::NormalExit && check.exitCode() == 0);

    QJsonArray matches;

    if (hasRg) {
        QStringList argsList;
        argsList << "-n" << "--hidden" << "--no-ignore" << "-S" << "-e" << pattern;
        if (!QFileInfo(path).isDir()) argsList << path;
        else if (recursive) argsList << path;

        QProcess proc;
        proc.start("rg", argsList);
        if (!proc.waitForFinished(10000)) {
            // timeout
            proc.kill();
            return QJsonObject{{"success", false}, {"error", "rg timeout or failed"}};
        }
        const QByteArray out = proc.readAllStandardOutput();
        QTextStream ts(out);
        while (!ts.atEnd()) {
            const QString line = ts.readLine();
            // rg -n output is: path:line:col:match
            const auto parts = line.split(':');
            if (parts.size() >= 3) {
                QJsonObject m;
                m["file"] = parts[0];
                m["line"] = parts[1].toInt();
                // join the rest as text
                QString text = parts.mid(2).join(":");
                m["text"] = text;
                matches.append(m);
            }
        }
    } else {
        // fallback to simple grep implemented inline (non-optimized)
        QFileInfo fi(path);
        QRegularExpression rx(pattern);
        if (!rx.isValid()) return QJsonObject{{"success", false}, {"error", "Invalid regular expression"}};

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
    }

    return QJsonObject{{"success", true}, {"matches", matches}};
}

