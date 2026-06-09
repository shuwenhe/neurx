#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class RealtimeCollaborationEngine
 * @brief Real-time collaboration and multi-user editing
 */

class RealtimeCollaborationEngine : public QObject {
    Q_OBJECT

public:
    struct CollaborationSession {
        QString sessionId;
        QString documentId;
        QString owner;
        QVector<QString> participants;
        QDateTime createdAt;
        bool isActive;
    };

    struct Change {
        QString changeId;
        QString userId;
        QString type;  // insert, delete, replace
        int position;
        QString content;
        int version;
        qint64 timestamp;
    };

    struct Cursor {
        QString userId;
        int line;
        int column;
        QString color;
    };

    explicit RealtimeCollaborationEngine(QObject* parent = nullptr);
    ~RealtimeCollaborationEngine();

    QString createSession(const QString& documentId, const QString& owner);
    void joinSession(const QString& sessionId, const QString& userId);
    void leaveSession(const QString& sessionId, const QString& userId);

    void broadcastChange(const QString& sessionId, const Change& change);
    void broadcastCursor(const QString& sessionId, const Cursor& cursor);
    
    QVector<Change> getChangeHistory(const QString& sessionId);
    QString reconstructDocument(const QString& sessionId);

    void setPermission(const QString& sessionId, const QString& userId, const QString& permission);

signals:
    void sessionCreated(const QString& sessionId);
    void userJoined(const QString& sessionId, const QString& userId);
    void userLeft(const QString& sessionId, const QString& userId);
    void changeReceived(const QString& sessionId, const Change& change);
    void cursorMoved(const QString& sessionId, const Cursor& cursor);

private:
    QMap<QString, CollaborationSession> m_sessions;
    QMap<QString, QVector<Change>> m_changes;
};
