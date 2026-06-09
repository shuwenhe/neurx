#include "GeminiCompleteTaskTool.h"
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>

GeminiCompleteTaskTool::GeminiCompleteTaskTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiCompleteTaskTool::name() const
{
    return "complete_task";
}

QString GeminiCompleteTaskTool::description() const
{
    return "Call this tool to submit your final results or findings and complete the task. This is the ONLY way to finish.";
}

QJsonObject GeminiCompleteTaskTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";

    QJsonObject properties;

    QJsonObject resultProp;
    resultProp["type"] = "string";
    resultProp["description"] = "Your final results or findings to return to the orchestrator. Ensure this is comprehensive.";
    properties["result"] = resultProp;

    schema["properties"] = properties;

    QJsonArray required;
    required.append("result");
    schema["required"] = required;

    return schema;
}

ToolResult GeminiCompleteTaskTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString result = args["result"].toString();

    if (result.isEmpty()) {
        return {callId, name(), true, "Missing required 'result' argument. You must provide your findings when calling complete_task."};
    }

    QJsonObject data;
    data["taskCompleted"] = true;
    data["submittedOutput"] = result;

    QString displayMessage = "Result submitted and task completed.";

    ToolResult res{callId, name(), false, displayMessage};
    // We could attach structured data if ToolResult supported it,
    // but typically the message returned is what the LLM sees.
    // In gemini-cli, it returns {llmContent: returnDisplay, returnDisplay, data: {taskCompleted: true, ...}}

    return res;
}

