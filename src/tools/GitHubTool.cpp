#include "tools/GitHubTool.h"
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QProcessEnvironment>

GitHubTool::GitHubTool(QObject *parent) : BaseTool(parent)
{
    m_network = new QNetworkAccessManager(this);
    m_token = QProcessEnvironment::systemEnvironment().value("GITHUB_TOKEN").trimmed();
}

QJsonObject GitHubTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["read_issue", "list_issues", "add_comment"],
                "description": "The GitHub action to perform."
            },
            "repo": {
                "type": "string",
                "description": "The repository full name (e.g., 'owner/repo')."
            },
            "issue_number": {
                "type": "integer",
                "description": "The issue or PR number (for read_issue or add_comment)."
            },
            "comment_body": {
                "type": "string",
                "description": "The content of the comment (for add_comment)."
            },
            "state": {
                "type": "string",
                "enum": ["open", "closed", "all"],
                "description": "Issue state filter (for list_issues).",
                "default": "open"
            }
        },
        "required": ["action", "repo"]
    })").object();
}

QString GitHubTool::summary(const QJsonObject &args) const
{
    return QString("github %1 %2").arg(args["action"].toString(), args["repo"].toString());
}

ToolResult GitHubTool::execute(const QString &callId, const QJsonObject &args)
{
    if (m_token.isEmpty()) {
        return {callId, name(), true, "GITHUB_TOKEN environment variable is not set."};
    }

    const QString action = args["action"].toString();
    const QString repo = args["repo"].toString();

    if (action == "read_issue") {
        return readIssue(callId, repo, args["issue_number"].toInt());
    } else if (action == "list_issues") {
        return listIssues(callId, repo, args.value("state").toString("open"));
    } else if (action == "add_comment") {
        return addComment(callId, repo, args["issue_number"].toInt(), args["comment_body"].toString());
    }

    return {callId, name(), true, "Unknown action: " + action};
}

ToolResult GitHubTool::readIssue(const QString &callId, const QString &repo, int number)
{
    if (number <= 0) return {callId, name(), true, "Valid issue_number is required."};

    QUrl url(QString("https://api.github.com/repos/%1/issues/%2").arg(repo).arg(number));
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    req.setRawHeader("Accept", "application/vnd.github.v3+json");
    req.setRawHeader("User-Agent", "neurx-agent");

    QEventLoop loop;
    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        return {callId, name(), true, "GitHub API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        if (err.isEmpty()) err = reply->errorString();
        reply->deleteLater();
        return {callId, name(), true, "GitHub API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, QString::fromUtf8(data)};
}

ToolResult GitHubTool::listIssues(const QString &callId, const QString &repo, const QString &state)
{
    QUrl url(QString("https://api.github.com/repos/%1/issues").arg(repo));
    url.setQuery(QString("state=%1").arg(state));

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    req.setRawHeader("Accept", "application/vnd.github.v3+json");
    req.setRawHeader("User-Agent", "neurx-agent");

    QEventLoop loop;
    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        return {callId, name(), true, "GitHub API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "GitHub API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, QString::fromUtf8(data)};
}

ToolResult GitHubTool::addComment(const QString &callId, const QString &repo, int number, const QString &body)
{
    if (number <= 0 || body.isEmpty()) return {callId, name(), true, "issue_number and comment_body are required."};

    QUrl url(QString("https://api.github.com/repos/%1/issues/%2/comments").arg(repo).arg(number));
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    req.setRawHeader("Accept", "application/vnd.github.v3+json");
    req.setRawHeader("Content-Type", "application/json");
    req.setRawHeader("User-Agent", "neurx-agent");

    QJsonObject json;
    json["body"] = body;
    QByteArray postData = QJsonDocument(json).toJson();

    QEventLoop loop;
    QNetworkReply *reply = m_network->post(req, postData);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        return {callId, name(), true, "GitHub API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "GitHub API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, "Comment added successfully: " + QString::fromUtf8(data)};
}
