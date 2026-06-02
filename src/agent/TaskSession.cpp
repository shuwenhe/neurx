#include "agent/TaskSession.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUuid>

namespace {

QString sessionRootPath()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(base).filePath(QStringLiteral("sessions"));
}

QString latestSessionPath()
{
    return QDir(sessionRootPath()).filePath(QStringLiteral("latest.json"));
}

QString sessionPathForId(const QString &sessionId)
{
    return QDir(sessionRootPath()).filePath(sessionId + QStringLiteral(".json"));
}

QJsonArray variantListToJsonArray(const QVariantList &items)
{
    QJsonArray arr;
    for (const auto &item : items)
        arr.append(QJsonValue::fromVariant(item));
    return arr;
}

QVariantList jsonArrayToVariantList(const QJsonArray &items)
{
    QVariantList list;
    for (const auto &item : items)
        list.append(item.toVariant());
    return list;
}

QJsonObject snapshotToJson(const TaskSessionSnapshot &snapshot)
{
    const QString threadId = snapshot.effectiveThreadId();
    QJsonObject obj;
    obj["threadId"] = threadId;
    obj["sessionId"] = snapshot.sessionId;
    obj["parentThreadId"] = snapshot.parentThreadId;
    obj["workspacePath"] = snapshot.workspacePath;
    obj["currentProvider"] = snapshot.currentProvider;
    obj["currentModel"] = snapshot.currentModel;
    obj["currentFilePath"] = snapshot.currentFilePath;
    obj["updatedAt"] = snapshot.updatedAt.isValid()
        ? snapshot.updatedAt.toUTC().toString(Qt::ISODateWithMs)
        : QString{};
    obj["todoItems"] = variantListToJsonArray(snapshot.todoItems);
    obj["executionTimeline"] = variantListToJsonArray(snapshot.executionTimeline);
    obj["approvalProfile"] = QJsonValue::fromVariant(snapshot.approvalProfile);

    QJsonArray messagesJson;
    for (const auto &message : snapshot.messages)
        messagesJson.append(message.toJson());
    obj["messages"] = messagesJson;
    return obj;
}

TaskSessionSnapshot snapshotFromJson(const QJsonObject &obj)
{
    TaskSessionSnapshot snapshot;
    snapshot.threadId = obj.value("threadId").toString();
    snapshot.sessionId = obj.value("sessionId").toString();
    if (snapshot.threadId.trimmed().isEmpty())
        snapshot.threadId = snapshot.sessionId;
    if (snapshot.sessionId.trimmed().isEmpty())
        snapshot.sessionId = snapshot.threadId;
    snapshot.parentThreadId = obj.value("parentThreadId").toString();
    snapshot.workspacePath = obj.value("workspacePath").toString();
    snapshot.currentProvider = obj.value("currentProvider").toString();
    snapshot.currentModel = obj.value("currentModel").toString();
    snapshot.currentFilePath = obj.value("currentFilePath").toString();
    snapshot.updatedAt = QDateTime::fromString(obj.value("updatedAt").toString(), Qt::ISODateWithMs);
    snapshot.todoItems = jsonArrayToVariantList(obj.value("todoItems").toArray());
    snapshot.executionTimeline = jsonArrayToVariantList(obj.value("executionTimeline").toArray());
    snapshot.approvalProfile = obj.value("approvalProfile").toObject().toVariantMap();

    for (const auto &value : obj.value("messages").toArray()) {
        if (value.isObject())
            snapshot.messages.append(AgentMessage::fromJson(value.toObject()));
    }
    return snapshot;
}

} // namespace

TaskSessionSnapshot TaskSessionStore::loadLatest()
{
    QFile file(latestSessionPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    const auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject())
        return {};

    return snapshotFromJson(doc.object());
}

TaskSessionSnapshot TaskSessionStore::loadById(const QString &sessionId)
{
    const QString normalized = sessionId.trimmed();
    if (normalized.isEmpty())
        return {};

    QFile file(sessionPathForId(normalized));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    const auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject())
        return {};

    return snapshotFromJson(doc.object());
}

QList<QVariantMap> TaskSessionStore::listSessions()
{
    QList<QVariantMap> sessions;
    QDir root(sessionRootPath());
    if (!root.exists())
        return sessions;

    const QFileInfoList files = root.entryInfoList({QStringLiteral("*.json")}, QDir::Files, QDir::Time);
    for (const QFileInfo &info : files) {
        if (info.fileName() == QStringLiteral("latest.json"))
            continue;

        const TaskSessionSnapshot snapshot = loadById(info.completeBaseName());
        if (!snapshot.isValid())
            continue;

        QVariantMap item;
        item["threadId"] = snapshot.effectiveThreadId();
        item["sessionId"] = snapshot.effectiveThreadId();
        item["parentThreadId"] = snapshot.parentThreadId;
        item["workspacePath"] = snapshot.workspacePath;
        item["currentProvider"] = snapshot.currentProvider;
        item["currentModel"] = snapshot.currentModel;
        item["currentFilePath"] = snapshot.currentFilePath;
        item["messageCount"] = snapshot.messages.size();
        item["eventCount"] = snapshot.executionTimeline.size();
        item["updatedAt"] = snapshot.updatedAt.isValid()
            ? snapshot.updatedAt.toLocalTime().toString(Qt::ISODate)
            : info.lastModified().toLocalTime().toString(Qt::ISODate);
        sessions.append(item);
    }
    return sessions;
}

bool TaskSessionStore::saveLatest(const TaskSessionSnapshot &snapshot)
{
    if (!snapshot.isValid())
        return false;

    TaskSessionSnapshot normalized = snapshot;
    if (normalized.threadId.trimmed().isEmpty())
        normalized.threadId = normalized.sessionId.trimmed();
    if (normalized.sessionId.trimmed().isEmpty())
        normalized.sessionId = normalized.threadId.trimmed();

    QDir root(sessionRootPath());
    if (!root.exists() && !QDir().mkpath(root.path()))
        return false;

    QSaveFile file(latestSessionPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    const QJsonDocument doc(snapshotToJson(normalized));
    file.write(doc.toJson(QJsonDocument::Indented));
    if (!file.commit())
        return false;

    QSaveFile sessionFile(sessionPathForId(normalized.effectiveThreadId()));
    if (!sessionFile.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    sessionFile.write(doc.toJson(QJsonDocument::Indented));
    return sessionFile.commit();
}

QString TaskSessionStore::defaultSessionId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}
