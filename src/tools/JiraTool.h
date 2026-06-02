#pragma once
#include "agent/ToolRegistry.h"
#include <QNetworkAccessManager>
#include <QObject>

// ── JiraTool ──────────────────────────────────────────────────────────────────
//  Allows the agent to interact with Jira (read issues, transition, comment).
//  Requires JIRA_TOKEN, JIRA_EMAIL, and JIRA_URL.

class JiraTool : public BaseTool {
    Q_OBJECT
public:
    explicit JiraTool(QObject *parent = nullptr);

    QString name()        const override { return "jira"; }
    QString description() const override {
        return "Interact with Jira. Actions: read_issue, list_assigned_issues, add_comment. "
               "Requires issue key (e.g. 'PROJ-123') and relevant parameters.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    ToolResult readIssue(const QString &callId, const QString &issueKey);
    ToolResult listAssignedIssues(const QString &callId);
    ToolResult addComment(const QString &callId, const QString &issueKey, const QString &body);

    QString m_token;
    QString m_email;
    QString m_baseUrl;
    QNetworkAccessManager *m_network;
};
