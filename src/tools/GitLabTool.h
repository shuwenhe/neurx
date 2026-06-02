#pragma once
#include "agent/ToolRegistry.h"
#include <QNetworkAccessManager>
#include <QObject>

// ── GitLabTool ────────────────────────────────────────────────────────────────
//  Allows the agent to interact with GitLab (issues, merge requests, comments).
//  Requires GITLAB_TOKEN and optionally GITLAB_URL (defaults to gitlab.com).

class GitLabTool : public BaseTool {
    Q_OBJECT
public:
    explicit GitLabTool(QObject *parent = nullptr);

    QString name()        const override { return "gitlab"; }
    QString description() const override {
        return "Interact with GitLab. Actions: read_issue, list_mrs, add_comment. "
               "Requires project ID or path (e.g. 'group/project') and relevant parameters.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    ToolResult readIssue(const QString &callId, const QString &project, int iid);
    ToolResult listMRs(const QString &callId, const QString &project, const QString &state);
    ToolResult addComment(const QString &callId, const QString &project, const QString &type, int iid, const QString &body);

    QString m_token;
    QString m_baseUrl;
    QNetworkAccessManager *m_network;
};
