#include "CustomScriptTool.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

CustomScriptTool::CustomScriptTool(const QString &name, const QString &description,
                                 const QString &scriptPath, const QJsonObject &schema,
                                 QObject *parent)
    : BaseTool(parent)
    , m_name(name)
    , m_description(description)
    , m_scriptPath(scriptPath)
    , m_schema(schema)
{
}

ToolResult CustomScriptTool::execute(const QString &callId, const QJsonObject &args)
{
    // Implementation for executing local scripts
    QProcess process;
    process.setProgram(m_scriptPath);

    // Convert args to JSON string
    QString argsJson = QJsonDocument(args).toJson(QJsonDocument::Compact);
    process.setArguments({argsJson});

    process.start();
    if (!process.waitForFinished(30000)) { // 30s timeout
        return {callId, m_name, true, "Script execution timed out"};
    }

    if (process.exitCode() != 0) {
        return {callId, m_name, true, "Script failed with exit code " + QString::number(process.exitCode()) + ": " + process.readAllStandardError()};
    }

    return {callId, m_name, false, QString::fromUtf8(process.readAllStandardOutput())};
}
