#include "GeminiAskUserTool.h"

GeminiAskUserTool::GeminiAskUserTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiAskUserTool::name() const
{
    return "ask_user";
}

QString GeminiAskUserTool::description() const
{
    return "Ask the user one or more questions. Can be free-form text or multiple choice.";
}

QJsonObject GeminiAskUserTool::parametersSchema() const
{
    QJsonObject question;
    question["type"] = "object";
    QJsonObject qProps;
    qProps["header"] = QJsonObject{{"type", "string"}};
    qProps["question"] = QJsonObject{{"type", "string"}};
    qProps["type"] = QJsonObject{{"type", "string"}}; // text, choice, etc.
    qProps["options"] = QJsonObject{
        {"type", "array"},
        {"items", QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"label", QJsonObject{{"type", "string"}}},
                {"description", QJsonObject{{"type", "string"}}}
            }},
            {"required", QJsonArray{"label"}}
        }}
    };
    qProps["multi_select"] = QJsonObject{{"type", "boolean"}};
    question["properties"] = qProps;
    question["required"] = QJsonArray{"header", "question"};

    QJsonObject schema;
    schema["type"] = "object";
    schema["properties"] = QJsonObject{
        {"questions", QJsonObject{
            {"type", "array"},
            {"items", question}
        }}
    };
    schema["required"] = QJsonArray{"questions"};
    return schema;
}

ToolResult GeminiAskUserTool::execute(const QString &callId, const QJsonObject &args)
{
    QJsonArray questions = args["questions"].toArray();

    // In a real implementation, this would wait for user input.
    // Here we signal that questions were asked.
    emit questionsAsked(questions, callId);

    // Return a message indicating questions have been queued/asked
    return {callId, name(), false, "Questions presented to user. Waiting for response..."};
}

