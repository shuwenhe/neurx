#pragma once
#include "agent/AgentToolRegistry.h"
#include <QProcess>
#include <QObject>

// ── DockerShellTool ───────────────────────────────────────────────────────────
//  Executes shell commands inside a sandboxed Docker container.
//  Provides both isolation and state persistence for the AI agent.

class DockerShellTool : public BaseTool {
    Q_OBJECT
public:
    explicit DockerShellTool(const QString &workspacePath, QObject *parent = nullptr);
    ~DockerShellTool();

    QString name()        const override { return "run_docker_command"; }
    QString description() const override {
        return "Execute a shell command inside a sandboxed Docker container. "
               "The workspace is mounted at /workspace. "
               "Use for isolated builds, tests, and running untrusted code. "
               "Persistence: Shell state and installed packages remain available throughout the session.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    void setContainerImage(const QString &image) { m_image = image; }
    void stopContainer();

private:
    bool ensureContainerRunning();
    QString execCommand(const QString &command, int timeoutMs, const QString &callId, bool &ok);

    QString m_workspacePath;
    QString m_containerName;
    QString m_image{"python:3.11-bookworm"};
    int     m_defaultTimeoutMs{60000};
    bool    m_containerInitialized{false};
};
