#pragma once
#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QDir>

// ── MemoryTool ───────────────────────────────────────────────────────────────
//  Persistent curated memory across sessions, stored in the workspace at
//  .neurx/MEMORY.md  — agent's own notes (project conventions, tool quirks,
//                       things learned about the codebase)
//  .neurx/USER.md    — notes about the user (preferences, workflow habits)
//
//  Both files are loaded once at session start and injected into the system
//  prompt via buildSnapshot(). Mid-session writes update disk immediately but
//  do NOT mutate the live prompt (preserves LLM prefix cache for the session).
//  The snapshot refreshes on the next session.
//
//  Entry delimiter: § (section sign), matching the hermes-agent convention so
//  skill/memory files stay interoperable.
//
//  Actions: add, replace, remove, read

class MemoryTool : public BaseTool {
    Q_OBJECT
public:
    explicit MemoryTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString     name()        const override { return "memory"; }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    // Returns a formatted string suitable for injection into the system prompt.
    // Call once at session start; result is stable for the session lifetime.
    QString buildSnapshot() const;

private:
    enum class Store { Agent, User };

    ToolResult opAdd    (Store store, const QJsonObject &args);
    ToolResult opReplace(Store store, const QJsonObject &args);
    ToolResult opRemove (Store store, const QJsonObject &args);
    ToolResult opRead   (Store store);

    QString  filePath(Store store) const;
    QString  readRaw (Store store) const;
    bool     writeRaw(Store store, const QString &content) const;

    static const QString kDelimiter;   // "\n§\n"
    static const int     kMaxChars;    // 24 000

    QString m_workspaceRoot;
};
