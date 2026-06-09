#include "GeminiUpdateTopicTool.h"

GeminiUpdateTopicTool::GeminiUpdateTopicTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiUpdateTopicTool::name() const
{
    return "update_topic";
}

QString GeminiUpdateTopicTool::description() const
{
    return "Sets the current strategic topic and intent. Used to group operations and focus the agent.";
}

QJsonObject GeminiUpdateTopicTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"title", QJsonObject{{"type", "string"}}},
            {"summary", QJsonObject{{"type", "string"}}},
            {"strategic_intent", QJsonObject{{"type", "string"}}}
        }}
    };
}

ToolResult GeminiUpdateTopicTool::execute(const QString &callId, const QJsonObject &args)
{
    QString title = args["title"].toString();
    QString summary = args["summary"].toString();
    QString strategicIntent = args["strategic_intent"].toString();

    emit topicUpdated(title, summary, strategicIntent);

    QString res = QString("Topic updated: %1\nIntent: %2").arg(title, strategicIntent);
    return {callId, name(), false, res};
}

