#include "tools/GitLabTool.h"
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QProcessEnvironment>
#include <QUrlQuery>

GitLabTool::GitLabTool(QObject *parent) : BaseTool(parent)
{
    m_network = new QNetworkAccessManager(this);
    auto env = QProcessEnvironment::systemEnvironment();
    m_token = env.value("GITLAB_TOKEN").trimmed();
    m_baseUrl = env.value("GITLAB_URL", "https://gitlab.com").trimmed();
    if (m_baseUrl.endsWith("/")) m_baseUrl.chop(1);
}

QJsonObject GitLabTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["read_issue", "list_mrs", "add_comment"],
                "description": "The GitLab action to perform."
            },
            "project": {
                "type": "string",
                "description": "The project ID or URL-encoded path (e.g., 'group/project')."
            },
            "iid": {
                "type": "integer",
                "description": "The internal ID of the issue or MR."
            },
            "comment_body": {
                "type": "string",
                "description": "The content of the comment."
            },
            "target_type": {
                "type": "string",
                "enum": ["issues", "merge_requests"],
                "description": "Type of target for comment (default: issues)."
            },
            "state": {
                "type": "string",
                "enum": ["opened", "closed", "merged", "all"],
                "description": "State filter for MRs.",
                "default": "opened"
            }
        },
        "required": ["action", "project"]
    })").object();
}

QString GitLabTool::summary(const QJsonObject &args) const
{
    return QString("gitlab %1 %2").arg(args["action"].toString(), args["project"].toString());
}

ToolResult GitLabTool::execute(const QString &callId, const QJsonObject &args)
{
    if (m_token.isEmpty()) {
        return {callId, name(), true, "GITLAB_TOKEN environment variable is not set."};
    }

    const QString action = args["action"].toString();
    const QString project = QUrl::toPercentEncoding(args["project"].toString());

    if (action == "read_issue") {
        return readIssue(callId, project, args["iid"].toInt());
    } else if (action == "list_mrs") {
        return listMRs(callId, project, args.value("state").toString("opened"));
    } else if (action == "add_comment") {
        return addComment(callId, project, args.value("target_type").toString("issues"), args["iid"].toInt(), args["comment_body"].toString());
    }

    return {callId, name(), true, "Unknown action: " + action};
}

ToolResult GitLabTool::readIssue(const QString &callId, const QString &project, int iid)
{
    if (iid <= 0) return {callId, name(), true, "Valid iid is required."};

    QUrl url(QString("%1/api/v4/projects/%2/issues/%3").arg(m_baseUrl, project).arg(iid));
    QNetworkRequest req(url);
    req.setRawHeader("PRIVATE-TOKEN", m_token.toUtf8());

    QEventLoop loop;
    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort(); reply->deleteLater();
        return {callId, name(), true, "GitLab API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "GitLab API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, QString::fromUtf8(data)};
}

ToolResult GitLabTool::listMRs(const QString &callId, const QString &project, const QString &state)
{
    QUrl url(QString("%1/api/v4/projects/%2/merge_requests").arg(m_baseUrl, project));
    QUrlQuery query;
    query.addQueryItem("state", state);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("PRIVATE-TOKEN", m_token.toUtf8());

    QEventLoop loop;
    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort(); reply->deleteLater();
        return {callId, name(), true, "GitLab API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "GitLab API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, QString::fromUtf8(data)};
}

ToolResult GitLabTool::addComment(const QString &callId, const QString &project, const QString &type, int iid, const QString &body)
{
    if (iid <= 0 || body.isEmpty()) return {callId, name(), true, "iid and comment_body are required."};

    QUrl url(QString("%1/api/v4/projects/%2/%3/%4/notes").arg(m_baseUrl, project, type).arg(iid));
    QNetworkRequest req(url);
    req.setRawHeader("PRIVATE-TOKEN", m_token.toUtf8());
    req.setRawHeader("Content-Type", "application/json");

    QJsonObject json;
    json["body"] = body;
    QByteArray postData = QJsonDocument(json).toJson();

    QEventLoop loop;
    QNetworkReply *reply = m_network->post(req, postData);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort(); reply->deleteLater();
        return {callId, name(), true, "GitLab API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "GitLab API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, "Comment added successfully: " + QString::fromUtf8(data)};
}
