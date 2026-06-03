#pragma once

#include "thread/ThreadTypes.h"
#include <QObject>
#include <QVector>
#include <memory>

/**
 * @class ThreadStore
 * @brief Abstract interface for thread persistence and lifecycle management
 * 
 * Provides async operations for:
 * - Creating new threads
 * - Resuming from checkpoints
 * - Forking threads
 * - Saving state
 * - Managing thread lifecycle
 * 
 * Implementations can be in-memory, file-based, database-backed, etc.
 */
class ThreadStore : public QObject {
    Q_OBJECT
public:
    virtual ~ThreadStore() = default;
    
    // ── Creation and Initialization ────────────────────────────────────
    
    /// Create a new thread with initial parameters
    virtual void createThread(const CreateThreadParams &params,
                             std::function<void(ThreadStoreError, ThreadId)> callback) = 0;

    /// Upsert a thread record using an explicit thread id.
    virtual void upsertThread(const StoredThread &thread,
                             std::function<void(ThreadStoreError)> callback) = 0;
    
    /// Fork an existing thread (branch into parallel execution)
    virtual void forkThread(const ThreadId &parentId,
                           const QVariantMap &forkContext,
                           std::function<void(ThreadStoreError, ThreadId)> callback) = 0;
    
    // ── Resume and Checkpoint ──────────────────────────────────────────
    
    /// Resume a thread from a checkpoint
    virtual void resumeThread(const ResumeThreadParams &params,
                             std::function<void(ThreadStoreError, StoredThread)> callback) = 0;
    
    /// Save current thread state as checkpoint
    virtual void saveCheckpoint(const ThreadId &threadId,
                               const QVariantMap &state,
                               const QString &label,
                               std::function<void(ThreadStoreError)> callback) = 0;
    
    /// List available checkpoints for a thread
    virtual void listCheckpoints(const ThreadId &threadId,
                                std::function<void(ThreadStoreError, QVector<QString>)> callback) = 0;
    
    /// Load a specific checkpoint
    virtual void loadCheckpoint(const ThreadId &threadId,
                               const QString &checkpointId,
                               std::function<void(ThreadStoreError, QVariantMap)> callback) = 0;
    
    // ── Query and Metadata ─────────────────────────────────────────────
    
    /// Get thread metadata
    virtual void getThread(const ThreadId &threadId,
                          std::function<void(ThreadStoreError, StoredThread)> callback) = 0;
    
    /// List all threads (with optional filter)
    virtual void listThreads(const QVariantMap &filter,
                            std::function<void(ThreadStoreError, QVector<StoredThread>)> callback) = 0;
    
    /// Update thread metadata
    virtual void updateThreadMetadata(const ThreadId &threadId,
                                     const QVariantMap &metadata,
                                     std::function<void(ThreadStoreError)> callback) = 0;
    
    // ── Lifecycle Management ───────────────────────────────────────────
    
    /// Mark thread as active/inactive
    virtual void setThreadActive(const ThreadId &threadId,
                                bool active,
                                std::function<void(ThreadStoreError)> callback) = 0;
    
    /// Delete a thread and its checkpoints
    virtual void deleteThread(const ThreadId &threadId,
                             std::function<void(ThreadStoreError)> callback) = 0;
    
    /// Prune old checkpoints (keep only N most recent)
    virtual void pruneCheckpoints(const ThreadId &threadId,
                                 int keepCount,
                                 std::function<void(ThreadStoreError)> callback) = 0;
    
    // ── Statistics and Maintenance ─────────────────────────────────────
    
    /// Get storage statistics
    virtual void getStats(std::function<void(const QVariantMap &stats)> callback) = 0;
    
    /// Perform maintenance (cleanup, defragmentation, etc.)
    virtual void maintenance(std::function<void(ThreadStoreError)> callback) = 0;
    
signals:
    /// Emitted when thread state is modified externally
    void threadModified(const ThreadId &threadId);
    
    /// Emitted when thread is deleted
    void threadDeleted(const ThreadId &threadId);
    
    /// Emitted when checkpoint is created
    void checkpointCreated(const ThreadId &threadId, const QString &checkpointId);
};

using ThreadStorePtr = std::shared_ptr<ThreadStore>;
