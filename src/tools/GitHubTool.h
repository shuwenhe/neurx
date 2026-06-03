#pragma once
#include "agent/AgentToolRegistry.h"
#include <QNetworkAccessManager>
#include <QObject>

// ── GitHubTool ────────────────────────────────────────────────────────────────
//  Allows the agent to interact with GitHub (read issues, list PRs, comment).
//  Requires a GITHUB_TOKEN environment variable.

class GitHubTool : public BaseTool {
    Q_OBJECT
public:
    explicit GitHubTool(QObject *parent = nullptr);

    QString name()        const override { return "github"; }
    QString description() const override {
        return "Interact with GitHub. Actions: read_issue, list_issues, add_comment. "
               "Requires repo name (e.g. 'owner/repo') and relevant parameters.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    ToolResult readIssue(const QString &callId, const QString &repo, int number);
    ToolResult listIssues(const QString &callId, const QString &repo, const QString &state);
    ToolResult addComment(const QString &callId, const QString &repo, int number, const QString &body);

    QString m_token;
    QNetworkAccessManager *m_network;
};
