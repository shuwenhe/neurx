#include "agent/ConversationManager.h"
#include <QUuid>
#include <QFile>
#include <QJsonDocument>
#include <QDateTime>
#include <algorithm>

ConversationManager::ConversationManager(QObject *parent)
    : QObject(parent)
{
}

ConversationManager::~ConversationManager() = default;

QString ConversationManager::createSession(const QString &taskId, const QString &title)
{
    // Check session limit
    if (m_maxSessions > 0 && m_context.sessions.size() >= m_maxSessions) {
        // Clean up old sessions
        cleanupOldSessions(1);
    }

    QString sessionId = _generateId("session");

    Session session;
    session.id = sessionId;
    session.title = title.isEmpty() ? QString("Session %1").arg(sessionId.left(8)) : title;
    session.taskId = taskId;
    session.created = QDateTime::currentDateTime();
    session.lastModified = session.created;

    m_context.sessions[sessionId] = session;
    emit sessionCreated(sessionId);

    return sessionId;
}

bool ConversationManager::closeSession(const QString &sessionId)
{
    auto it = m_context.sessions.find(sessionId);
    if (it == m_context.sessions.end()) {
        return false;
    }

    it.value().isActive = false;
    it.value().lastModified = QDateTime::currentDateTime();

    emit sessionClosed(sessionId);
    return true;
}

const ConversationManager::Session *ConversationManager::getSession(const QString &sessionId) const
{
    auto it = m_context.sessions.find(sessionId);
    if (it != m_context.sessions.end()) {
        return &it.value();
    }
    return nullptr;
}

QStringList ConversationManager::listSessions(bool activeOnly) const
{
    QStringList result;

    for (auto it = m_context.sessions.begin(); it != m_context.sessions.end(); ++it) {
        if (!activeOnly || it.value().isActive) {
            result.append(it.key());
        }
    }

    return result;
}

QStringList ConversationManager::findSessionsByTask(const QString &taskId) const
{
    QStringList result;

    for (auto it = m_context.sessions.begin(); it != m_context.sessions.end(); ++it) {
        if (it.value().taskId == taskId) {
            result.append(it.key());
        }
    }

    return result;
}

QString ConversationManager::addMessage(const QString &sessionId, const QString &role,
                                       const QString &content, const QJsonObject &metadata)
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return "";
    }

    QString messageId = _generateId("msg");

    Message msg;
    msg.id = messageId;
    msg.role = role;
    msg.content = content;
    msg.timestamp = QDateTime::currentDateTime();
    msg.metadata = metadata;
    msg.tokens = estimateTokens(content);

    m_context.messages[messageId] = msg;
    m_context.messageToSession[messageId] = sessionId;

    auto &session = sessionIt.value();
    session.messageIds.append(messageId);
    session.totalTokens += msg.tokens;
    session.lastModified = msg.timestamp;

    emit messageAdded(sessionId, messageId);

    return messageId;
}

const ConversationManager::Message *ConversationManager::getMessage(const QString &sessionId,
                                                                    const QString &messageId) const
{
    auto it = m_context.messages.find(messageId);
    if (it != m_context.messages.end()) {
        // Verify message belongs to session
        auto sessionIt = m_context.messageToSession.find(messageId);
        if (sessionIt != m_context.messageToSession.end() && sessionIt.value() == sessionId) {
            return &it.value();
        }
    }
    return nullptr;
}

QVector<ConversationManager::Message> ConversationManager::getHistory(const QString &sessionId, int limit) const
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return {};
    }

    const auto &session = sessionIt.value();
    QVector<Message> result;

    int start = 0;
    if (limit > 0 && session.messageIds.size() > limit) {
        start = session.messageIds.size() - limit;
    }

    for (int i = start; i < session.messageIds.size(); ++i) {
        auto msgIt = m_context.messages.find(session.messageIds[i]);
        if (msgIt != m_context.messages.end()) {
            result.append(msgIt.value());
        }
    }

    return result;
}

QString ConversationManager::getConversationSummary(const QString &sessionId, int messageCount) const
{
    auto history = getHistory(sessionId, messageCount);

    QString summary;
    for (const auto &msg : history) {
        summary += QString("[%1] %2\n").arg(msg.role, msg.content.left(100));
    }

    return summary;
}

bool ConversationManager::editMessage(const QString &sessionId, const QString &messageId,
                                     const QString &newContent)
{
    auto msgIt = m_context.messages.find(messageId);
    if (msgIt == m_context.messages.end()) {
        return false;
    }

    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return false;
    }

    auto &msg = msgIt.value();
    int oldTokens = msg.tokens;
    msg.content = newContent;
    msg.tokens = estimateTokens(newContent);

    auto &session = sessionIt.value();
    session.totalTokens += (msg.tokens - oldTokens);
    session.lastModified = QDateTime::currentDateTime();

    emit messageEdited(sessionId, messageId);
    return true;
}

bool ConversationManager::deleteMessage(const QString &sessionId, const QString &messageId)
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return false;
    }

    auto &session = sessionIt.value();
    auto msgIdIt = session.messageIds.indexOf(messageId);
    if (msgIdIt == -1) {
        return false;
    }

    auto msgIt = m_context.messages.find(messageId);
    if (msgIt != m_context.messages.end()) {
        session.totalTokens -= msgIt.value().tokens;
        m_context.messages.erase(msgIt);
    }

    session.messageIds.removeAt(msgIdIt);
    m_context.messageToSession.remove(messageId);
    session.lastModified = QDateTime::currentDateTime();

    return true;
}

int ConversationManager::truncateHistory(const QString &sessionId, int keepCount)
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return 0;
    }

    auto &session = sessionIt.value();
    int removed = 0;

    while (session.messageIds.size() > keepCount) {
        QString msgId = session.messageIds.takeFirst();
        auto msgIt = m_context.messages.find(msgId);
        if (msgIt != m_context.messages.end()) {
            session.totalTokens -= msgIt.value().tokens;
            m_context.messages.erase(msgIt);
        }
        m_context.messageToSession.remove(msgId);
        removed++;
    }

    session.lastModified = QDateTime::currentDateTime();
    return removed;
}

QString ConversationManager::branchConversation(const QString &sessionId, const QString &messageId,
                                              const QString &newTitle)
{
    // Create new session
    auto oldSession = getSession(sessionId);
    if (!oldSession) {
        return "";
    }

    QString newSessionId = createSession(oldSession->taskId, newTitle.isEmpty() ? "Branch: " + oldSession->title : newTitle);
    auto newSessionIt = m_context.sessions.find(newSessionId);

    if (newSessionIt == m_context.sessions.end()) {
        return "";
    }

    // Copy messages up to and including the branch point
    bool foundBranch = false;
    for (const auto &msgId : oldSession->messageIds) {
        auto msgIt = m_context.messages.find(msgId);
        if (msgIt != m_context.messages.end()) {
            const auto &msg = msgIt.value();

            // Create new message copy
            QString newMsgId = _generateId("msg");
            Message newMsg = msg;
            newMsg.id = newMsgId;

            m_context.messages[newMsgId] = newMsg;
            m_context.messageToSession[newMsgId] = newSessionId;

            newSessionIt.value().messageIds.append(newMsgId);
            newSessionIt.value().totalTokens += newMsg.tokens;

            if (msgId == messageId) {
                foundBranch = true;
                break;
            }
        }
    }

    newSessionIt.value().lastModified = QDateTime::currentDateTime();
    return newSessionId;
}

bool ConversationManager::setActiveThread(const QString &sessionId, const QString &threadId)
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return false;
    }

    auto msgIt = m_context.messages.find(threadId);
    if (msgIt == m_context.messages.end()) {
        return false;
    }

    sessionIt.value().activeThread = threadId;
    return true;
}

QVector<ConversationManager::Message> ConversationManager::getThread(const QString &sessionId,
                                                                     const QString &messageId) const
{
    return _buildMessageThread(sessionId, messageId);
}

void ConversationManager::setContextVariable(const QString &sessionId, const QString &key,
                                            const QVariant &value)
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt != m_context.sessions.end()) {
        sessionIt.value().context[key] = value;
    }
}

QVariant ConversationManager::getContextVariable(const QString &sessionId, const QString &key) const
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt != m_context.sessions.end()) {
        return sessionIt.value().context.value(key);
    }
    return {};
}

QMap<QString, QVariant> ConversationManager::getContext(const QString &sessionId) const
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt != m_context.sessions.end()) {
        return sessionIt.value().context;
    }
    return {};
}

void ConversationManager::clearContext(const QString &sessionId)
{
    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt != m_context.sessions.end()) {
        sessionIt.value().context.clear();
    }
}

ConversationManager::ConversationStats ConversationManager::getStatistics(const QString &sessionId) const
{
    ConversationStats stats;

    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return stats;
    }

    const auto &session = sessionIt.value();
    stats.totalMessages = session.messageIds.size();
    stats.totalTokens = session.totalTokens;

    int totalLength = 0;

    for (const auto &msgId : session.messageIds) {
        auto msgIt = m_context.messages.find(msgId);
        if (msgIt != m_context.messages.end()) {
            const auto &msg = msgIt.value();

            if (msg.role == "user") {
                stats.userMessages++;
            } else if (msg.role == "assistant") {
                stats.assistantMessages++;
            }

            totalLength += msg.content.length();

            if (stats.firstMessage.isNull() || msg.timestamp < stats.firstMessage) {
                stats.firstMessage = msg.timestamp;
            }

            if (msg.timestamp > stats.lastMessage) {
                stats.lastMessage = msg.timestamp;
            }
        }
    }

    if (stats.assistantMessages > 0) {
        stats.averageResponseLength = (double)totalLength / stats.assistantMessages;
    }

    return stats;
}

QJsonObject ConversationManager::getGlobalStatistics() const
{
    QJsonObject stats;

    int totalSessions = m_context.sessions.size();
    int activeSessions = 0;
    int totalMessages = 0;
    int totalTokens = 0;

    for (auto it = m_context.sessions.begin(); it != m_context.sessions.end(); ++it) {
        if (it.value().isActive) {
            activeSessions++;
        }
        totalMessages += it.value().messageIds.size();
        totalTokens += it.value().totalTokens;
    }

    stats["total_sessions"] = totalSessions;
    stats["active_sessions"] = activeSessions;
    stats["total_messages"] = totalMessages;
    stats["total_tokens"] = totalTokens;
    stats["memory_usage"] = (int)getMemoryUsage();

    return stats;
}

int ConversationManager::estimateTokens(const QString &text) const
{
    // Simple approximation: ~4 characters per token
    return (text.length() + 3) / 4;
}

QVector<ConversationManager::Message> ConversationManager::searchMessages(const QString &sessionId,
                                                                          const QString &searchText,
                                                                          const QString &role) const
{
    QVector<Message> results;

    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return results;
    }

    QString lower = searchText.toLower();

    for (const auto &msgId : sessionIt.value().messageIds) {
        auto msgIt = m_context.messages.find(msgId);
        if (msgIt != m_context.messages.end()) {
            const auto &msg = msgIt.value();

            if (!role.isEmpty() && msg.role != role) {
                continue;
            }

            if (msg.content.toLower().contains(lower)) {
                results.append(msg);
            }
        }
    }

    return results;
}

QMap<QString, QVector<ConversationManager::Message>> ConversationManager::searchAllSessions(
    const QString &searchText) const
{
    QMap<QString, QVector<Message>> results;

    for (auto sessionIt = m_context.sessions.begin(); sessionIt != m_context.sessions.end(); ++sessionIt) {
        auto matches = searchMessages(sessionIt.key(), searchText);
        if (!matches.isEmpty()) {
            results[sessionIt.key()] = matches;
        }
    }

    return results;
}

QJsonObject ConversationManager::exportSession(const QString &sessionId) const
{
    auto session = getSession(sessionId);
    if (!session) {
        return {};
    }

    QJsonObject sessionObj;
    sessionObj["id"] = session->id;
    sessionObj["title"] = session->title;
    sessionObj["description"] = session->description;
    sessionObj["task_id"] = session->taskId;
    sessionObj["created"] = session->created.toString(Qt::ISODate);
    sessionObj["modified"] = session->lastModified.toString(Qt::ISODate);

    QJsonArray messagesArray;
    for (const auto &msgId : session->messageIds) {
        auto msgIt = m_context.messages.find(msgId);
        if (msgIt != m_context.messages.end()) {
            const auto &msg = msgIt.value();

            QJsonObject msgObj;
            msgObj["id"] = msg.id;
            msgObj["role"] = msg.role;
            msgObj["content"] = msg.content;
            msgObj["timestamp"] = msg.timestamp.toString(Qt::ISODate);
            msgObj["tokens"] = msg.tokens;
            msgObj["metadata"] = msg.metadata;

            messagesArray.append(msgObj);
        }
    }

    sessionObj["messages"] = messagesArray;
    return sessionObj;
}

QString ConversationManager::importSession(const QJsonObject &sessionJson)
{
    QString sessionId = sessionJson["id"].toString();
    if (sessionId.isEmpty()) {
        sessionId = createSession(sessionJson["task_id"].toString(), sessionJson["title"].toString());
    }

    auto sessionIt = m_context.sessions.find(sessionId);
    if (sessionIt == m_context.sessions.end()) {
        return "";
    }

    auto &session = sessionIt.value();
    session.description = sessionJson["description"].toString();

    auto messagesArray = sessionJson["messages"].toArray();
    for (const auto &msgVal : messagesArray) {
        auto msgObj = msgVal.toObject();

        QString msgId = msgObj["id"].toString();
        if (msgId.isEmpty()) {
            msgId = _generateId("msg");
        }

        Message msg;
        msg.id = msgId;
        msg.role = msgObj["role"].toString();
        msg.content = msgObj["content"].toString();
        msg.timestamp = QDateTime::fromString(msgObj["timestamp"].toString(), Qt::ISODate);
        msg.tokens = msgObj["tokens"].toInt();
        msg.metadata = msgObj["metadata"].toObject();

        m_context.messages[msgId] = msg;
        m_context.messageToSession[msgId] = sessionId;
        session.messageIds.append(msgId);
        session.totalTokens += msg.tokens;
    }

    return sessionId;
}

QJsonObject ConversationManager::exportAllSessions() const
{
    QJsonObject root;
    QJsonArray sessionsArray;

    for (auto it = m_context.sessions.begin(); it != m_context.sessions.end(); ++it) {
        sessionsArray.append(exportSession(it.key()));
    }

    root["sessions"] = sessionsArray;
    root["export_date"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    root["session_count"] = (int)m_context.sessions.size();

    return root;
}

int ConversationManager::importAllSessions(const QJsonObject &allSessionsJson)
{
    int count = 0;
    auto sessionsArray = allSessionsJson["sessions"].toArray();

    for (const auto &sessionVal : sessionsArray) {
        auto sessionId = importSession(sessionVal.toObject());
        if (!sessionId.isEmpty()) {
            count++;
        }
    }

    return count;
}

bool ConversationManager::saveSessionToFile(const QString &sessionId, const QString &filepath) const
{
    QJsonObject sessionJson = exportSession(sessionId);
    if (sessionJson.isEmpty()) {
        return false;
    }

    QFile file(filepath);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }

    QJsonDocument doc(sessionJson);
    file.write(doc.toJson());
    file.close();

    return true;
}

QString ConversationManager::loadSessionFromFile(const QString &filepath)
{
    QFile file(filepath);
    if (!file.open(QIODevice::ReadOnly)) {
        return "";
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        return "";
    }

    return importSession(doc.object());
}

int ConversationManager::cleanupOldSessions(int daysOld)
{
    int removed = 0;
    auto now = QDateTime::currentDateTime();

    QStringList toRemove;
    for (auto it = m_context.sessions.begin(); it != m_context.sessions.end(); ++it) {
        if (!it.value().isActive) {
            int daysPassed = it.value().lastModified.daysTo(now);
            if (daysPassed >= daysOld) {
                toRemove.append(it.key());
            }
        }
    }

    for (const auto &sessionId : toRemove) {
        closeSession(sessionId);
        removed++;
    }

    return removed;
}

qint64 ConversationManager::getMemoryUsage() const
{
    qint64 total = 0;

    for (const auto &msg : m_context.messages) {
        total += msg.content.size();
    }

    for (const auto &session : m_context.sessions) {
        total += session.title.size();
        total += session.description.size();
    }

    return total;
}

void ConversationManager::clear()
{
    m_context.sessions.clear();
    m_context.messages.clear();
    m_context.messageToSession.clear();
}

QString ConversationManager::_generateId(const QString &prefix)
{
    return prefix + "-" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);
}

bool ConversationManager::_sessionExists(const QString &sessionId) const
{
    return m_context.sessions.contains(sessionId);
}

QVector<ConversationManager::Message> ConversationManager::_buildMessageThread(
    const QString &sessionId, const QString &messageId) const
{
    QVector<Message> thread;

    auto msgIt = m_context.messages.find(messageId);
    if (msgIt == m_context.messages.end()) {
        return thread;
    }

    // Walk up to root
    QStringList pathToRoot;
    QString currentId = messageId;

    while (!currentId.isEmpty()) {
        pathToRoot.prepend(currentId);
        auto msg = getMessage(sessionId, currentId);
        if (!msg || msg->parentId.isEmpty()) {
            break;
        }
        currentId = msg->parentId;
    }

    // Add all messages in path
    for (const auto &id : pathToRoot) {
        auto msg = getMessage(sessionId, id);
        if (msg) {
            thread.append(*msg);
        }
    }

    // Add all children
    for (const auto &id : pathToRoot) {
        auto msg = getMessage(sessionId, id);
        if (msg) {
            for (const auto &childId : msg->childIds) {
                auto child = getMessage(sessionId, childId);
                if (child && !pathToRoot.contains(childId)) {
                    thread.append(*child);
                }
            }
        }
    }

    return thread;
}
