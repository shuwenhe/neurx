#pragma once
#include <QObject>
#include <QHash>
#include <QJsonObject>
#include <functional>
#include "agent/AgentMessage.h"

// ── BaseTool ──────────────────────────────────────────────────────────────────
//  All tools must derive from BaseTool and be registered in ToolRegistry.

class BaseTool : public QObject {
    Q_OBJECT
public:
    explicit BaseTool(QObject *parent = nullptr) : QObject(parent) {}

    // Human-readable name used as the function/tool name in LLM calls.
    virtual QString name()        const = 0;
    virtual QString description() const = 0;

    // JSON Schema for the parameters accepted by this tool.
    virtual QJsonObject parametersSchema() const = 0;

    // Execute the tool synchronously; heavy operations should use QtConcurrent internally.
    // Returns a ToolResult that will be fed back into the agent context.
    virtual ToolResult execute(const QString &callId,
                               const QJsonObject &args) = 0;

    // Render a short human-readable summary for the UI "tool card".
    virtual QString summary(const QJsonObject &args) const { Q_UNUSED(args); return name(); }

signals:
    // Emitted during execute() for tools that stream partial output (e.g. ShellTool).
    // Each chunk is an incremental stdout/stderr fragment.
    void outputChunk(const QString &callId, const QString &chunk);
};

// ── ToolRegistry ─────────────────────────────────────────────────────────────

class ToolRegistry : public QObject {
    Q_OBJECT
public:
    explicit ToolRegistry(QObject *parent = nullptr);

    void registerTool(BaseTool *tool);
    void unregisterTool(const QString &name);

    BaseTool *tool(const QString &name) const;
    QList<BaseTool *> allTools() const;

    // Produce the tools array for an LLM request (OpenAI / Anthropic schema).
    QJsonArray toOpenAISchema()    const;
    QJsonArray toAnthropicSchema() const;

private:
    QHash<QString, BaseTool *> m_tools;
};
