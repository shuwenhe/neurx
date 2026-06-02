#pragma once
#include <QObject>
#include <QList>
#include <QString>
#include "agent/AgentMessage.h"
#include "agent/Planner.h"
#include "agent/Executor.h"
#include "agent/Verifier.h"
#include "agent/ToolRegistry.h"
#include "llm/LLMProvider.h"

// ── AgentConfig ───────────────────────────────────────────────────────────────

struct AgentConfig {
    QString systemPrompt;
    int     maxIterations{20};      // hard cap on plan→act cycles per turn
    int     contextWindowTokens{200000};
    bool    autoApproveTools{false};// if false, emit toolApprovalRequired
};

// ── AgentEngine ───────────────────────────────────────────────────────────────
//  Drives the plan → tool-call → observe → respond loop.
//  Thread-safe: run() executes in a worker thread via QtConcurrent.

class AgentEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(AgentStatus status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString activeModel READ activeModel WRITE setActiveModel NOTIFY activeModelChanged)

public:
    enum class AgentStatus { Idle, Thinking, Executing, Waiting };
    Q_ENUM(AgentStatus)

    explicit AgentEngine(QObject *parent = nullptr);
    ~AgentEngine() override;

    void setProvider(LLMProvider *provider);
    void setToolRegistry(ToolRegistry *registry);
    void setConfig(const AgentConfig &config);
    void setSystemPrompt(const QString &prompt);
    void setAutoApproveTools(bool enabled);
    QString systemPrompt() const { return m_config.systemPrompt; }

    AgentStatus status()      const { return m_status; }
    QString     activeModel() const { return m_activeModel; }
    void        setActiveModel(const QString &model);

    // Conversation history access (read-only from QML side).
    const QList<AgentMessage> &history() const { return m_history; }
    void setHistory(const QList<AgentMessage> &history);
    void clearHistory();

public slots:
    // Submit a new user message and kick off the agent loop.
    void submitUserMessage(const QString &text);
    // Inject a file/code snippet into context (from editor or file tree).
    void injectContext(const QString &filePath, const QString &content,
                       int startLine = -1, int endLine = -1);
    // Approve or reject a pending tool call (when autoApproveTools==false).
    void approveTool(const QString &callId, bool approved);
    // Interrupt the current loop mid-run.
    void interrupt();

signals:
    void statusChanged(AgentStatus status);
    void activeModelChanged(const QString &model);

    // Streaming tokens from the LLM.
    void tokenReceived(const TokenEvent &event);

    // A complete assistant message has arrived (may contain tool calls).
    void messageAdded(const AgentMessage &message);

    // Emitted before each tool execution so the UI can show a "card".
    void toolExecuting(const ToolCall &call);
    // Emitted after a tool finishes.
    void toolFinished(const ToolResult &result);
    // Emitted by streaming tools (e.g. ShellTool) as incremental output arrives.
    void toolOutputChunk(const QString &callId, const QString &chunk);

    // When autoApproveTools==false, the UI must call approveTool() to proceed.
    void toolApprovalRequired(const ToolCall &call);

    // The full agent turn is complete (no more tool calls).
    void turnComplete();
    void errorOccurred(const QString &error);

private:
    void runLoop();
    void setStatus(AgentStatus s);
    void appendMessage(const AgentMessage &msg);

    LLMProvider      *m_provider{nullptr};
    ToolRegistry     *m_registry{nullptr};
    Planner           m_planner;
    Executor          m_executor;
    Verifier          m_verifier;
    AgentConfig       m_config;
    AgentStatus       m_status{AgentStatus::Idle};
    QString           m_activeModel;
    QList<AgentMessage> m_history;

    // Pending approval: callId → ToolCall
    QHash<QString, ToolCall> m_pendingApprovals;
    bool m_interrupted{false};
};
