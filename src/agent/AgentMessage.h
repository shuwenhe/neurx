#pragma once
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>

// ── Roles ────────────────────────────────────────────────────────────────────

enum class MessageRole {
    System,
    User,
    Assistant,
    Tool,           // tool result fed back into the context
};

// ── Tool call / result (OpenAI-style, mapped to Anthropic internally) ────────

struct ToolCall {
    QString id;           // unique per call, e.g. "toolu_01..."
    QString name;
    QJsonObject arguments;
};

struct ToolResult {
    QString callId;       // matches ToolCall::id
    QString name;
    bool    isError{false};
    QString content;      // serialized output or error message
};

// ── A single message in the conversation history ─────────────────────────────

struct AgentMessage {
    MessageRole     role{MessageRole::User};
    QString         content;                // text part
    QList<ToolCall> toolCalls;             // non-empty when role==Assistant invoking tools
    QList<ToolResult> toolResults;         // non-empty when role==Tool
    QDateTime       timestamp{QDateTime::currentDateTimeUtc()};

    bool hasToolCalls()   const { return !toolCalls.isEmpty(); }
    bool hasToolResults() const { return !toolResults.isEmpty(); }

    QJsonObject toJson() const;
    static AgentMessage fromJson(const QJsonObject &obj);
};

// ── Streaming token event ─────────────────────────────────────────────────────

struct TokenEvent {
    enum class Type { TextDelta, ToolCallDelta, ToolCallEnd, MessageEnd, Error };
    Type    type{Type::TextDelta};
    QString delta;
    QString toolCallId;
    QString toolName;
    QJsonObject toolArgsDelta;
    QString errorMessage;
};
