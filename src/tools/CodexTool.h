#pragma once
#include "agent/AgentToolRegistry.h"

// ── CodexTool ─────────────────────────────────────────────────────────────────
//  Delegates a complex coding sub-task to the Codex CLI agent.
//  Runs: codex --full-auto [--model <m>] "<task>"
//  in the workspace directory and returns combined stdout+stderr.
//
//  Best used when the parent agent wants to hand off a large, well-scoped task
//  (e.g. "refactor X", "implement Y with tests") to a fully autonomous Codex
//  loop instead of driving every tool call itself.

class CodexTool : public BaseTool {
    Q_OBJECT
public:
    explicit CodexTool(const QString &workingDir, QObject *parent = nullptr);

    QString name()        const override { return QStringLiteral("codex_agent"); }
    QString description() const override {
        return QStringLiteral(
            "Delegate a complex coding sub-task to the Codex CLI agent. "
            "Codex will autonomously plan and execute multi-step operations "
            "(read/write files, run tests, apply patches, etc.) and return "
            "a summary of what it did. "
            "It can also be used for exact file writes when file_path and "
            "new_text are provided. "
            "Use for large, well-scoped tasks such as: refactoring a module, "
            "implementing a feature with tests, or fixing all lint errors. "
            "The 'task' parameter must be a detailed, self-contained description "
            "including relevant file paths and success criteria."
        );
    }

    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    // Override the path used to locate the codex binary (default: resolved from PATH).
    void setCodexBinaryPath(const QString &path) { m_codexBin = path; }

    // Override the default 5-minute timeout (milliseconds).
    void setDefaultTimeoutMs(int ms) { m_timeoutMs = ms; }

private:
    QString buildWriteTask(const QString &filePath, const QString &newText, const QString &cwd) const;

    QString m_workingDir;
    QString m_codexBin{QStringLiteral("codex")};
    int     m_timeoutMs{300'000};   // 5 min – Codex may run multi-step loops
};
