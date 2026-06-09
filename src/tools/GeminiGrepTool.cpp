#include "GeminiGrepTool.h"
#include <QFile>
#include <QTextStream>
#include <QDirIterator>
#include <QJsonArray>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QProcess>

        GeminiGrepTool::GeminiGrepTool(QObject *parent) : BaseTool(parent) {}

        QString GeminiGrepTool::name() const { return QStringLiteral("grep_search"); }

        QString GeminiGrepTool::description() const {
            return QStringLiteral("Search for text in the workspace using ripgrep or a fallback. Supports includes, excludes, and context.");
        }

        QJsonObject GeminiGrepTool::parametersSchema() const {
            return QJsonDocument::fromJson(R"JSON({
                "type": "object",
                "properties": {
                    "pattern": { "type": "string", "description": "The regex pattern to search for." },
                    "path": { "type": "string", "description": "The path to search in (default: '.')" },
                    "include_pattern": { "type": "string", "description": "Glob pattern for files to include." },
                    "exclude_pattern": { "type": "string", "description": "Glob pattern for files to exclude." },
                    "case_sensitive": { "type": "boolean", "default": false },
                    "names_only": { "type": "boolean", "description": "Only return filenames.", "default": false },
                    "fixed_strings": { "type": "boolean", "description": "Treat pattern as literal string.", "default": false },
                    "context": { "type": "integer", "description": "Number of context lines." }
                },
                "required": ["pattern"]
            })JSON").object();
        }

        ToolResult GeminiGrepTool::execute(const QString &callId, const QJsonObject &args)
        {
            QString pattern = args.value("pattern").toString();
            QString path = args.value("path").toString(".");
            QString include = args.value("include_pattern").toString();
            QString exclude = args.value("exclude_pattern").toString();
            bool caseSensitive = args.value("case_sensitive").toBool(false);
            bool namesOnly = args.value("names_only").toBool(false);
            bool fixedStrings = args.value("fixed_strings").toBool(false);
            int context = args.value("context").toInt(0);

            if (pattern.isEmpty()) {
                return {callId, name(), true, "Pattern is required."};
            }

            QStringList rgArgs;
            rgArgs << "--column" << "--line-number" << "--no-heading" << "--color" << "never" << "-S";

            if (!caseSensitive) rgArgs << "-i";
            if (namesOnly) rgArgs << "-l";
            if (fixedStrings) rgArgs << "-F";
            if (context > 0) rgArgs << "-C" << QString::number(context);
            if (!include.isEmpty()) rgArgs << "-g" << include;
            if (!exclude.isEmpty()) rgArgs << "-g" << "!" + exclude;

            rgArgs << "--" << pattern << path;

            QProcess process;
            process.start("rg", rgArgs);
            if (!process.waitForFinished(10000)) {
                process.kill();
                return {callId, name(), true, "ripgrep timed out or failed to start."};
            }

            if (process.exitCode() != 0 && process.exitCode() != 1) {
                 return {callId, name(), true, "ripgrep error: " + process.readAllStandardError()};
            }

            QString output = QString::fromUtf8(process.readAllStandardOutput());
            if (output.isEmpty()) {
                return {callId, name(), false, "No matches found."};
            }

            return {callId, name(), false, output};
        }
