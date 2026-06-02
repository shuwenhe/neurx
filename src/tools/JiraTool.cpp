#include "tools/JiraTool.h"
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QProcessEnvironment>

JiraTool::JiraTool(QObject *parent) : BaseTool(parent)
{
    m_network = new QNetworkAccessManager(this);
    auto env = QProcessEnvironment::systemEnvironment();
    m_token = env.value("JIRA_TOKEN").trimmed();
    m_email = env.value("JIRA_EMAIL").trimmed();
    m_baseUrl = env.value("JIRA_URL").trimmed();
    if (m_baseUrl.endsWith("/")) m_baseUrl.chop(1);
}

QJsonObject JiraTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["read_issue", "list_assigned_issues", "add_comment"],
                "description": "The Jira action to perform."
            },
            "issue_key": {
                "type": "string",
                "description": "The Jira issue key (e.g., 'PROJECT-123')."
            },
            "comment_body": {
                "type": "string",
                "description": "The content of the comment."
            }
        },
        "required": ["action"]
    })").object();
}

QString JiraTool::summary(const QJsonObject &args) const
{
    return QString("jira %1 %2").arg(args["action"].toString(), args["issue_key"].toString());
}

ToolResult JiraTool::execute(const QString &callId, const QJsonObject &args)
{
    if (m_token.isEmpty() || m_email.isEmpty() || m_baseUrl.isEmpty()) {
        return {callId, name(), true, "JIRA_TOKEN, JIRA_EMAIL, and JIRA_URL must be set."};
    }

    const QString action = args["action"].toString();

    if (action == "read_issue") {
        return readIssue(callId, args["issue_key"].toString());
    } else if (action == "list_assigned_issues") {
        return listAssignedIssues(callId);
    } else if (action == "add_comment") {
        return addComment(callId, args["issue_key"].toString(), args["comment_body"].toString());
    }

    return {callId, name(), true, "Unknown action: " + action};
}

ToolResult JiraTool::readIssue(const QString &callId, const QString &issueKey)
{
    if (issueKey.isEmpty()) return {callId, name(), true, "issue_key is required."};

    QUrl url(QString("%1/rest/api/3/issue/%2").arg(m_baseUrl, issueKey));
    QNetworkRequest req(url);
    QString auth = QString("%1:%2").arg(m_email, m_token);
    req.setRawHeader("Authorization", "Basic " + auth.toUtf8().toBase64());
    req.setRawHeader("Accept", "application/json");

    QEventLoop loop;
    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort(); reply->deleteLater();
        return {callId, name(), true, "Jira API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "Jira API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, QString::fromUtf8(data)};
}

ToolResult JiraTool::listAssignedIssues(const QString &callId)
{
    QUrl url(QString("%1/rest/api/3/search").arg(m_baseUrl));
    QUrlQuery query;
    query.addQueryItem("jql", "assignee = currentUser() AND status != Closed AND status != Done");
    url.setQuery(query);

    QNetworkRequest req(url);
    QString auth = QString("%1:%2").arg(m_email, m_token);
    req.setRawHeader("Authorization", "Basic " + auth.toUtf8().toBase64());
    req.setRawHeader("Accept", "application/json");

    QEventLoop loop;
    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort(); reply->deleteLater();
        return {callId, name(), true, "Jira API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "Jira API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, QString::fromUtf8(data)};
}

ToolResult JiraTool::addComment(const QString &callId, const QString &issueKey, const QString &body)
{
    if (issueKey.isEmpty() || body.isEmpty()) return {callId, name(), true, "issue_key and comment_body are required."};

    QUrl url(QString("%1/rest/api/3/issue/%2/comment").arg(m_baseUrl, issueKey));
    QNetworkRequest req(url);
    QString auth = QString("%1:%2").arg(m_email, m_token);
    req.setRawHeader("Authorization", "Basic " + auth.toUtf8().toBase64());
    req.setRawHeader("Content-Type", "application/json");

    // Jira API v3 uses Atlassian Document Format (ADF) for comments.
    // For simplicity, we'll wrap the string in a basic ADF structure.
    QJsonObject doc;
    doc["version"] = 1;
    doc["type"] = "doc";
    QJsonArray content;
    QJsonObject paragraph;
    paragraph["type"] = "paragraph";
    QJsonArray pContent;
    QJsonObject text;
    text["type"] = "text";
    text["text"] = body;
    pContent.append(text);
    paragraph["content"] = pContent;
    content.append(paragraph);
    doc["content"] = content;

    QJsonObject json;
    json["body"] = doc;
    QByteArray postData = QJsonDocument(json).toJson();

    QEventLoop loop;
    QNetworkReply *reply = m_network->post(req, postData);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(15000, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort(); reply->deleteLater();
        return {callId, name(), true, "Jira API request timed out."};
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->readAll();
        reply->deleteLater();
        return {callId, name(), true, "Jira API error: " + err};
    }

    QByteArray data = reply->readAll();
    reply->deleteLater();
    return {callId, name(), false, "Comment added successfully: " + QString::fromUtf8(data)};
}
