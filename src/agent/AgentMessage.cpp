#include "agent/AgentMessage.h"

namespace {

QString roleToString(MessageRole role)
{
    switch (role) {
    case MessageRole::System: return QStringLiteral("system");
    case MessageRole::User: return QStringLiteral("user");
    case MessageRole::Assistant: return QStringLiteral("assistant");
    case MessageRole::Tool: return QStringLiteral("tool");
    }
    return QStringLiteral("user");
}

MessageRole stringToRole(const QString &role)
{
    if (role == QLatin1String("system"))
        return MessageRole::System;
    if (role == QLatin1String("assistant"))
        return MessageRole::Assistant;
    if (role == QLatin1String("tool"))
        return MessageRole::Tool;
    return MessageRole::User;
}

QJsonObject toolCallToJson(const ToolCall &call)
{
    QJsonObject obj;
    obj["id"] = call.id;
    obj["name"] = call.name;
    obj["arguments"] = call.arguments;
    return obj;
}

ToolCall toolCallFromJson(const QJsonObject &obj)
{
    ToolCall call;
    call.id = obj.value("id").toString();
    call.name = obj.value("name").toString();
    call.arguments = obj.value("arguments").toObject();
    return call;
}

QJsonObject toolResultToJson(const ToolResult &result)
{
    QJsonObject obj;
    obj["callId"] = result.callId;
    obj["name"] = result.name;
    obj["isError"] = result.isError;
    obj["content"] = result.content;
    return obj;
}

ToolResult toolResultFromJson(const QJsonObject &obj)
{
    ToolResult result;
    result.callId = obj.value("callId").toString();
    result.name = obj.value("name").toString();
    result.isError = obj.value("isError").toBool();
    result.content = obj.value("content").toString();
    return result;
}

} // namespace

QJsonObject AgentMessage::toJson() const
{
    QJsonObject obj;
    obj["role"] = roleToString(role);
    obj["content"] = content;
    obj["timestamp"] = timestamp.toUTC().toString(Qt::ISODateWithMs);

    QJsonArray toolCallsJson;
    for (const auto &call : toolCalls)
        toolCallsJson.append(toolCallToJson(call));
    obj["toolCalls"] = toolCallsJson;

    QJsonArray toolResultsJson;
    for (const auto &result : toolResults)
        toolResultsJson.append(toolResultToJson(result));
    obj["toolResults"] = toolResultsJson;

    return obj;
}

AgentMessage AgentMessage::fromJson(const QJsonObject &obj)
{
    AgentMessage message;
    message.role = stringToRole(obj.value("role").toString());
    message.content = obj.value("content").toString();
    message.timestamp = QDateTime::fromString(
        obj.value("timestamp").toString(), Qt::ISODateWithMs);
    if (!message.timestamp.isValid())
        message.timestamp = QDateTime::currentDateTimeUtc();

    for (const auto &value : obj.value("toolCalls").toArray()) {
        if (value.isObject())
            message.toolCalls.append(toolCallFromJson(value.toObject()));
    }

    for (const auto &value : obj.value("toolResults").toArray()) {
        if (value.isObject())
            message.toolResults.append(toolResultFromJson(value.toObject()));
    }

    return message;
}
