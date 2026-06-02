#pragma once
#include "agent/ToolRegistry.h"
#include <QString>
#include <QList>

// ── SessionStore ──────────────────────────────────────────────────────────────
//  Persists conversation history to SQLite with FTS5 for cross-session recall.
//  Database: ~/.neurx/sessions.db (outside workspace, shared across projects).
//
//  Exposes a BaseTool ("session_search") the agent can call to retrieve
//  summaries of past conversations relevant to the current task.
//
//  Schema:
//    sessions(id TEXT PK, workspace TEXT, started_at INTEGER)
//    messages(id INTEGER PK, session_id TEXT, role TEXT,
//             content TEXT, ts INTEGER)
//    messages_fts(content) → FTS5 over messages

struct SessionMessage {
    QString role;     // "user" | "assistant" | "tool"
    QString content;
};

class SessionStore : public BaseTool {
    Q_OBJECT
public:
    explicit SessionStore(QObject *parent = nullptr);
    ~SessionStore() override;

    // ── BaseTool interface ────────────────────────────────────────────────────
    QString     name()        const override { return "session_search"; }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    // ── Session management ────────────────────────────────────────────────────
    // Begin a new session; call once when the workspace is set.
    void beginSession(const QString &workspacePath);

    // Append a message to the current session (call after every turn).
    void appendMessage(const QString &role, const QString &content);

    bool isOpen() const { return m_db != nullptr; }

private:
    bool openDb();
    bool ensureSchema();

    // Returns up to maxResults session excerpts matching the FTS query.
    QString search(const QString &query, int maxResults = 3);

    void *m_db{nullptr};   // sqlite3* — void* to avoid pulling sqlite3.h into header
    QString m_sessionId;
    QString m_dbPath;
};
