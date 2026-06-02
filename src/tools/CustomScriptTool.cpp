#include "tools/CustomScriptTool.h"
#include <QJsonDocument>
#include <QProcess>
#include <QDebug>

CustomScriptTool::CustomScriptTool(const QString &name, const QString &description,
                                 const QString &scriptPath, const QJsonObject &schema,
                                 QObject *parent)
    : BaseTool(parent), m_name(name), m_description(description),
      m_scriptPath(scriptPath), m_schema(schema)
{}

ToolResult CustomScriptTool::execute(const QString &callId, const QJsonObject &args)
{
    QProcess proc;
    QStringList procArgs;
    procArgs << m_scriptPath << QString::fromUtf8(QJsonDocument(args).toJson(QJsonDocument::Compact));

    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start("sh", {"-c", QString("%1 '%2'").arg(m_scriptPath, QString::fromUtf8(QJsonDocument(args).toJson(QJsonDocument::Compact)))});

    if (!proc.waitForFinished(30000)) {
        proc.kill();
        return {callId, name(), true, "Script execution timed out."};
    }

    const QByteArray output = proc.readAll();
    return {callId, name(), proc.exitCode() != 0, QString::fromUtf8(output)};
}
