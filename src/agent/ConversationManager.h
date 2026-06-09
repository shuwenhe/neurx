#pragma once

#include <QString>
#include <QMap>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <memory>
#include <deque>
#include <QObject>

/**
 * @class ConversationManager
 * @brief Manages agent conversations, sessions, and history
 *
 * Features:
 * - Multi-conversation support
 * - Message history with threading
 * - Session state management
 * - Conversation export/import
 * - Memory optimization with history limits
 * - Branching conversations
 * - Context preservation
 *
 * Usage:
 *   ConversationManager convMgr;
 *   QString sessionId = convMgr.createSession("task-1");
 *   convMgr.addMessage(sessionId, "user", "What is 2+2?");
 *   auto history = convMgr.getHistory(sessionId);
 */

class ConversationManager : public QObject {
    Q_OBJECT

public:
    explicit ConversationManager(QObject *parent = nullptr);
    ~ConversationManager();

    /// Message metadata
    struct Message {
        QString id;                       // Unique message ID
        QString role;                     // "user", "assistant", "system"
        QString content;                  // Message content
        QDateTime timestamp;              // Creation timestamp
        QString sender;                   // Sender identifier
        QJsonObject metadata;             // Additional metadata
        int tokens = 0;                   // Token count
        QString parentId;                 // Parent message ID (for branching)
        QStringList childIds;             // Child message IDs
    };

    /// Session metadata
    struct Session {
        QString id;                       // Unique session ID
        QString title;                    // Session title/name
        QString description;              // Session description
        QString taskId;                   // Associated task ID
        QDateTime created;                // Creation time
        QDateTime lastModified;           // Last modification time
        QStringList messageIds;           // Ordered list of message IDs
        int totalTokens = 0;              // Total tokens in session
        QMap<QString, QVariant> context;  // Session context variables
        bool isActive = true;             // Whether session is active
        QString activeThread;             // Current active message thread
    };

    /// Conversation statistics
    struct ConversationStats {
        int totalMessages = 0;
        int userMessages = 0;
        int assistantMessages = 0;
        int totalTokens = 0;
        QDateTime firstMessage;
        QDateTime lastMessage;
        double averageResponseLength = 0;
    };

    // Session management
    /**
     * Create a new conversation session
     * @param taskId Associated task identifier
     * @param title Session title
     * @return Session ID
     */
    QString createSession(const QString &taskId = "", const QString &title = "");

    /**
     * Close/archive a session
     * @param sessionId Session identifier
     * @return Success flag
     */
    bool closeSession(const QString &sessionId);

    /**
     * Get session info
     * @param sessionId Session identifier
     * @return Session metadata (null if not found)
     */
    const Session *getSession(const QString &sessionId) const;

    /**
     * List all sessions
     * @param activeOnly Only active sessions
     * @return List of session IDs
     */
    QStringList listSessions(bool activeOnly = true) const;

    /**
     * Find sessions by task
     * @param taskId Task identifier
     * @return List of session IDs
     */
    QStringList findSessionsByTask(const QString &taskId) const;

    // Message operations
    /**
     * Add message to session
     * @param sessionId Session identifier
     * @param role Message role ("user", "assistant", "system")
     * @param content Message content
     * @param metadata Optional metadata
     * @return Message ID
     */
    QString addMessage(const QString &sessionId, const QString &role,
                       const QString &content, const QJsonObject &metadata = {});

    /**
     * Get message by ID
     * @param sessionId Session identifier
     * @param messageId Message identifier
     * @return Message (null if not found)
     */
    const Message *getMessage(const QString &sessionId, const QString &messageId) const;

    /**
     * Get conversation history
     * @param sessionId Session identifier
     * @param limit Maximum messages (0 = all)
     * @return List of messages in order
     */
    QVector<Message> getHistory(const QString &sessionId, int limit = 0) const;

    /**
     * Get conversation summary (recent messages)
     * @param sessionId Session identifier
     * @param messageCount Number of recent messages
     * @return Formatted conversation summary
     */
    QString getConversationSummary(const QString &sessionId, int messageCount = 10) const;

    /**
     * Edit a message
     * @param sessionId Session identifier
     * @param messageId Message identifier
     * @param newContent New message content
     * @return Success flag
     */
    bool editMessage(const QString &sessionId, const QString &messageId, const QString &newContent);

    /**
     * Delete a message
     * @param sessionId Session identifier
     * @param messageId Message identifier
     * @return Success flag
     */
    bool deleteMessage(const QString &sessionId, const QString &messageId);

    /**
     * Truncate conversation history (keep recent messages)
     * @param sessionId Session identifier
     * @param keepCount Number of messages to keep
     * @return Number of messages removed
     */
    int truncateHistory(const QString &sessionId, int keepCount);

    // Threading/Branching
    /**
     * Create a branch from message
     * @param sessionId Source session ID
     * @param messageId Message to branch from
     * @param newTitle Title for new branch session
     * @return New session ID
     */
    QString branchConversation(const QString &sessionId, const QString &messageId, const QString &newTitle = "");

    /**
     * Set active thread
     * @param sessionId Session identifier
     * @param threadId Message ID of thread root
     * @return Success flag
     */
    bool setActiveThread(const QString &sessionId, const QString &threadId);

    /**
     * Get message thread
     * @param sessionId Session identifier
     * @param messageId Message identifier
     * @return All messages in thread
     */
    QVector<Message> getThread(const QString &sessionId, const QString &messageId) const;

    // Context management
    /**
     * Set session context variable
     * @param sessionId Session identifier
     * @param key Variable name
     * @param value Variable value
     */
    void setContextVariable(const QString &sessionId, const QString &key, const QVariant &value);

    /**
     * Get session context variable
     * @param sessionId Session identifier
     * @param key Variable name
     * @return Variable value (null if not found)
     */
    QVariant getContextVariable(const QString &sessionId, const QString &key) const;

    /**
     * Get all session context
     * @param sessionId Session identifier
     * @return Context map
     */
    QMap<QString, QVariant> getContext(const QString &sessionId) const;

    /**
     * Clear session context
     * @param sessionId Session identifier
     */
    void clearContext(const QString &sessionId);

    // Statistics
    /**
     * Get conversation statistics
     * @param sessionId Session identifier
     * @return Statistics structure
     */
    ConversationStats getStatistics(const QString &sessionId) const;

    /**
     * Get global statistics
     * @return Statistics across all sessions
     */
    QJsonObject getGlobalStatistics() const;

    /**
     * Get token count estimation
     * @param text Text to estimate
     * @return Estimated token count
     */
    int estimateTokens(const QString &text) const;

    // Search
    /**
     * Search messages in session
     * @param sessionId Session identifier
     * @param searchText Text to search for
     * @param role Filter by role ("", "user", "assistant", "system")
     * @return List of matching messages
     */
    QVector<Message> searchMessages(const QString &sessionId, const QString &searchText,
                                    const QString &role = "") const;

    /**
     * Search across all sessions
     * @param searchText Text to search for
     * @return Map of session ID to matching messages
     */
    QMap<QString, QVector<Message>> searchAllSessions(const QString &searchText) const;

    // Import/Export
    /**
     * Export session to JSON
     * @param sessionId Session identifier
     * @return JSON representation
     */
    QJsonObject exportSession(const QString &sessionId) const;

    /**
     * Import session from JSON
     * @param sessionJson JSON data
     * @return Imported session ID
     */
    QString importSession(const QJsonObject &sessionJson);

    /**
     * Export all sessions to JSON
     * @return JSON with all sessions
     */
    QJsonObject exportAllSessions() const;

    /**
     * Import multiple sessions
     * @param allSessionsJson JSON data
     * @return Number of sessions imported
     */
    int importAllSessions(const QJsonObject &allSessionsJson);

    /**
     * Save session to file
     * @param sessionId Session identifier
     * @param filepath File path
     * @return Success flag
     */
    bool saveSessionToFile(const QString &sessionId, const QString &filepath) const;

    /**
     * Load session from file
     * @param filepath File path
     * @return Loaded session ID or empty string
     */
    QString loadSessionFromFile(const QString &filepath);

    // Cleanup
    /**
     * Clean up old sessions
     * @param daysOld Delete sessions older than N days
     * @return Number of sessions deleted
     */
    int cleanupOldSessions(int daysOld = 30);

    /**
     * Get memory usage estimate
     * @return Bytes used by conversations
     */
    qint64 getMemoryUsage() const;

    /**
     * Clear all conversations
     */
    void clear();

    /**
     * Get session limit
     * @return Maximum sessions allowed (-1 = unlimited)
     */
    int getSessionLimit() const { return m_maxSessions; }

    /**
     * Set session limit
     * @param limit Maximum sessions (-1 = unlimited)
     */
    void setSessionLimit(int limit) { m_maxSessions = limit; }

signals:
    /// Emitted when message is added
    void messageAdded(const QString &sessionId, const QString &messageId);

    /// Emitted when session is created
    void sessionCreated(const QString &sessionId);

    /// Emitted when session is closed
    void sessionClosed(const QString &sessionId);

    /// Emitted when message is edited
    void messageEdited(const QString &sessionId, const QString &messageId);

    /// Emitted when conversation memory is getting full
    void memoryWarning(qint64 usedBytes, qint64 limitBytes);

private:
    struct ConversationContext {
        QMap<QString, Session> sessions;
        QMap<QString, Message> messages;  // Flat map of all messages
        QMap<QString, QString> messageToSession;  // message ID -> session ID mapping
    };

    ConversationContext m_context;
    int m_maxSessions = 100;  // Maximum number of sessions
    qint64 m_maxMemory = 100 * 1024 * 1024;  // 100 MB max memory

    // Helper methods
    QString _generateId(const QString &prefix);
    bool _sessionExists(const QString &sessionId) const;
    QVector<Message> _buildMessageThread(const QString &sessionId, const QString &messageId) const;
};
