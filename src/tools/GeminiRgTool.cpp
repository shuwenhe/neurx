#include "GeminiRgTool.h"
#include <QProcess>
#include <QJsonArray>
#include <QFileInfo>
#include <QDirIterator>
#include <QTextStream>
#include <QJsonDocument>

GeminiRgTool::GeminiRgTool(QObject *parent) : BaseTool(parent) {}

QString GeminiRgTool::name() const { return QStringLiteral("rg_search"); }
QString GeminiRgTool::description() const { return QStringLiteral("Search using ripgrep if available, fallback to simple grep"); }

QJsonObject GeminiRgTool::parametersSchema() const {
    QJsonObject s;
    s["path"] = QStringLiteral("string (file or directory)");
    s["pattern"] = QStringLiteral("string (regular expression)");
    s["recursive"] = QStringLiteral("boolean (optional)");
    return s;
}

ToolResult GeminiRgTool::execute(const QString &callId, const QJsonObject &args) {
    QString path = args.value("path").toString();
    QString pattern = args.value("pattern").toString();
    bool recursive = args.value("recursive").toBool(true);

    if (path.isEmpty() || pattern.isEmpty()) {
        QJsonObject res{{"success", false}, {"error", "Missing 'path' or 'pattern'"}};
        return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
    }

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
            QJsonObject res{{"success", false}, {"error", "rg timeout or failed"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
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
        if (!rx.isValid()) {
            QJsonObject res{{"success", false}, {"error", "Invalid regular expression"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }

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
            QJsonObject res{{"success", false}, {"error", "Path is neither file nor directory"}};
            return {callId, name(), true, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
        }
    }

    QJsonObject res{{"success", true}, {"matches", matches}};
    return {callId, name(), false, QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact))};
}
