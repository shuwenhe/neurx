#pragma once
#include "agent/ToolRegistry.h"
#include "approvals/ApprovalManager.h"
#include "sandbox/SandboxManager.h"
#include <QProcess>

// ── ShellTool ─────────────────────────────────────────────────────────────────
//  Executes shell commands in the workspace directory.
//  Uses QProcess; output is captured and returned to the agent.
//  Configurable timeout and env vars; interactive stdin is not supported.

class ShellTool : public BaseTool {
    Q_OBJECT
public:
    explicit ShellTool(const QString &workingDir, QObject *parent = nullptr);

    QString name()        const override { return "run_command"; }
    QString description() const override {
        return "Execute a shell command in the workspace directory and return stdout+stderr. "
               "Use for build commands, tests, git operations, package managers, etc. "
               "Commands run non-interactively with a configurable timeout.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    void setDefaultTimeoutMs(int ms) { m_defaultTimeoutMs = ms; }
    void setAllowedCommands(const QStringList &cmds) { m_allowlist = cmds; }
    void setSandboxManager(SandboxManager *manager) { m_sandboxManager = manager; }
    void setApprovalManager(ApprovalManager *manager) { m_approvalManager = manager; }

private:
    bool isAllowed(const QString &command) const;
    bool isDestructiveCommand(const QString &command) const;

    QString     m_workingDir;
    int         m_defaultTimeoutMs{30000};
    QStringList m_allowlist; // empty = all allowed
    SandboxManager *m_sandboxManager{nullptr};
    ApprovalManager *m_approvalManager{nullptr};
};
