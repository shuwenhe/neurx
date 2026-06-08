#pragma once
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QVariantList>

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
    
    bool operator==(const ToolCall &other) const {
        return id == other.id && name == other.name && arguments == other.arguments;
    }
};

struct ToolResult {
    QString callId;       // matches ToolCall::id
    QString name;
    bool    isError{false};
    QString content;      // serialized output or error message
    
    bool operator==(const ToolResult &other) const {
        return callId == other.callId && name == other.name && 
               isError == other.isError && content == other.content;
    }
};

// ── A single message in the conversation history ─────────────────────────────

struct AgentMessage {
    MessageRole     role{MessageRole::User};
    QString         content;                // text part
    QVariantList    attachments;            // list of QVariantMap attachments (e.g. images)
    QList<ToolCall> toolCalls;             // non-empty when role==Assistant invoking tools
    QList<ToolResult> toolResults;         // non-empty when role==Tool
    QDateTime       timestamp{QDateTime::currentDateTimeUtc()};

    bool hasToolCalls()   const { return !toolCalls.isEmpty(); }
    bool hasToolResults() const { return !toolResults.isEmpty(); }
    bool hasAttachments() const { return !attachments.isEmpty(); }
    
    bool operator==(const AgentMessage &other) const {
        return role == other.role && content == other.content && 
               toolCalls == other.toolCalls && toolResults == other.toolResults;
    }

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
    
    bool operator==(const TokenEvent &other) const {
        return type == other.type && delta == other.delta && 
               toolCallId == other.toolCallId && toolName == other.toolName;
    }
};

// ── Qt Meta-Type Registration ────────────────────────────────────────────────

Q_DECLARE_METATYPE(ToolCall)
Q_DECLARE_METATYPE(ToolResult)
Q_DECLARE_METATYPE(TokenEvent)
Q_DECLARE_METATYPE(AgentMessage)
Q_DECLARE_METATYPE(QList<ToolCall>)
Q_DECLARE_METATYPE(QList<ToolResult>)
