#include "TopicTool.h"

TopicTool::TopicTool(QObject *parent) : BaseTool(parent) {}

QString TopicTool::description() const {
    return "Update the conversation's topic, summary, and strategic intent. "
           "This helps maintain focus and track progress towards the overall goal.";
}

QJsonObject TopicTool::parametersSchema() const {
    QJsonObject schema;
    schema["type"] = "object";
    QJsonObject props;
    props["title"] = QJsonObject{
        {"type", "string"},
        {"description", "A short, descriptive title for the current task or topic."}
    };
    props["summary"] = QJsonObject{
        {"type", "string"},
        {"description", "A brief summary of the progress and current state."}
    };
    props["strategic_intent"] = QJsonObject{
        {"type", "string"},
        {"description", "The high-level goal or 'commander's intent' for this session."}
    };
    schema["properties"] = props;
    return schema;
}

ToolResult TopicTool::execute(const QString &callId, const QJsonObject &args) {
    QString title = args.value("title").toString();
    QString summary = args.value("summary").toString();
    QString intent = args.value("strategic_intent").toString();

    emit eventOccurred(callId, {
        {"event", "topic_updated"},
        {"title", title},
        {"summary", summary},
        {"strategic_intent", intent}
    });

    return {callId, name(), false, "Topic updated. Intent: " + intent};
}

