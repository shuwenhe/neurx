#include "GeminiWriteTodosTool.h"
#include <QJsonArray>
#include <QJsonDocument>

GeminiWriteTodosTool::GeminiWriteTodosTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiWriteTodosTool::name() const
{
    return "write_todos";
}

QString GeminiWriteTodosTool::description() const
{
    return "Write the full list of todos. This overwrites any existing list.";
}

QJsonObject GeminiWriteTodosTool::parametersSchema() const
{
    QJsonObject todoItem;
    todoItem["type"] = "object";
    QJsonObject properties;
    properties["description"] = QJsonObject{{"type", "string"}};
    properties["status"] = QJsonObject{
        {"type", "string"},
        {"enum", QJsonArray{"pending", "in_progress", "completed", "cancelled", "blocked"}}
    };
    todoItem["properties"] = properties;
    todoItem["required"] = QJsonArray{"description", "status"};

    QJsonObject schema;
    schema["type"] = "object";
    schema["properties"] = QJsonObject{
        {"todos", QJsonObject{
            {"type", "array"},
            {"items", todoItem}
        }}
    };
    schema["required"] = QJsonArray{"todos"};
    return schema;
}

ToolResult GeminiWriteTodosTool::execute(const QString &callId, const QJsonObject &args)
{
    QJsonArray todos = args["todos"].toArray();

    int inProgressCount = 0;
    for (const QJsonValue &v : todos) {
        QJsonObject t = v.toObject();
        if (t["description"].toString().trimmed().isEmpty()) {
            return {callId, name(), true, "Each todo must have a non-empty description."};
        }
        if (t["status"].toString() == "in_progress") {
            inProgressCount++;
        }
    }

    if (inProgressCount > 1) {
        return {callId, name(), true, "Only one task can be 'in_progress' at a time."};
    }

    emit todosUpdated(todos);

    QStringList summary;
    for (int i = 0; i < todos.size(); ++i) {
        QJsonObject t = todos[i].toObject();
        summary << QString("%1. [%2] %3").arg(i + 1).arg(t["status"].toString()).arg(t["description"].toString());
    }

    QString result = todos.isEmpty()
        ? "Successfully cleared the todo list."
        : "Successfully updated the todo list. Current list:\n" + summary.join("\n");

    return {callId, name(), false, result};
}
