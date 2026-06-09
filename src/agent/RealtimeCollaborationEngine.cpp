#include "RealtimeCollaborationEngine.h"
#include <QDebug>

RealtimeCollaborationEngine::RealtimeCollaborationEngine(QObject* parent)
    : QObject(parent) {
}

RealtimeCollaborationEngine::~RealtimeCollaborationEngine() {
}

QString RealtimeCollaborationEngine::createSession(const QString& documentId, const QString& owner) {
    CollaborationSession session;
    session.sessionId = QString::number(QDateTime::currentMSecsSinceEpoch());
    session.documentId = documentId;
    session.owner = owner;
    session.createdAt = QDateTime::currentDateTime();
    session.isActive = true;
    
    m_sessions[session.sessionId] = session;
    emit sessionCreated(session.sessionId);
    
    return session.sessionId;
}

void RealtimeCollaborationEngine::joinSession(const QString& sessionId, const QString& userId) {
    if (m_sessions.contains(sessionId)) {
        m_sessions[sessionId].participants.append(userId);
        emit userJoined(sessionId, userId);
    }
}

void RealtimeCollaborationEngine::leaveSession(const QString& sessionId, const QString& userId) {
    if (m_sessions.contains(sessionId)) {
        auto& participants = m_sessions[sessionId].participants;
        participants.erase(
            std::remove(participants.begin(), participants.end(), userId),
            participants.end()
        );
        emit userLeft(sessionId, userId);
    }
}

void RealtimeCollaborationEngine::broadcastChange(const QString& sessionId, const Change& change) {
    m_changes[sessionId].append(change);
    emit changeReceived(sessionId, change);
}

void RealtimeCollaborationEngine::broadcastCursor(const QString& sessionId, const Cursor& cursor) {
    emit cursorMoved(sessionId, cursor);
}

QVector<RealtimeCollaborationEngine::Change> RealtimeCollaborationEngine::getChangeHistory(const QString& sessionId) {
    return m_changes.value(sessionId);
}

QString RealtimeCollaborationEngine::reconstructDocument(const QString& sessionId) {
    QString document;
    for (const auto& change : m_changes.value(sessionId)) {
        if (change.type == "insert") {
            document.insert(change.position, change.content);
        }
    }
    return document;
}

void RealtimeCollaborationEngine::setPermission(const QString& sessionId, const QString& userId, const QString& permission) {
    qDebug() << "Set permission for user" << userId << ":" << permission;
}
