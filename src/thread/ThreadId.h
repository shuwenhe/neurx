#pragma once

#include <QString>
#include <QUuid>
#include <QByteArray>

/**
 * @class ThreadId
 * @brief Uniquely identifies a thread using UUID v7 (timestamp-based, sortable)
 * 
 * Migrated from Codex thread model for resumable, forkable, and persistent
 * agent execution across multiple turns and sessions.
 * 
 * Thread model enables:
 * - Resume: Continue from checkpoint
 * - Fork: Branch into parallel execution
 * - Persist: Save state to storage
 */
class ThreadId {
public:
    /// Create a new random Thread ID (UUID v7)
    static ThreadId generate();
    
    /// Parse a Thread ID from string representation
    static ThreadId fromString(const QString &str);
    
    /// Parse from raw UUID
    static ThreadId fromUuid(const QUuid &uuid);
    
    // Constructors
    ThreadId() = default;
    explicit ThreadId(const QString &uuidStr);
    explicit ThreadId(const QUuid &uuid);
    
    // Accessors
    QString toString() const;
    QUuid toUuid() const;
    QByteArray toByteArray() const;
    
    // Operators
    bool operator==(const ThreadId &other) const;
    bool operator!=(const ThreadId &other) const;
    bool operator<(const ThreadId &other) const;
    
    bool isNull() const;
    
private:
    QUuid m_uuid;
};

// Hash support for use in QHash/std::unordered_map
inline uint qHash(const ThreadId &id)
{
    return qHash(id.toUuid());
}
