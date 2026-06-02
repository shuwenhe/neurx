#pragma once

#include "ThreadStore.h"
#include <QMap>
#include <QMutex>

/**
 * @class InMemoryThreadStore
 * @brief In-memory implementation of ThreadStore for testing and development
 * 
 * Stores all thread data and checkpoints in RAM.
 * Data is lost when application terminates.
 * Suitable for unit tests and ephemeral sessions.
 */
class InMemoryThreadStore : public ThreadStore {
    Q_OBJECT
public:
    explicit InMemoryThreadStore(QObject *parent = nullptr);
    
    // Implementation of ThreadStore interface
    
    void createThread(const CreateThreadParams &params,
                     std::function<void(ThreadStoreError, ThreadId)> callback) override;
    
    void forkThread(const ThreadId &parentId,
                   const QVariantMap &forkContext,
                   std::function<void(ThreadStoreError, ThreadId)> callback) override;
    
    void resumeThread(const ResumeThreadParams &params,
                     std::function<void(ThreadStoreError, StoredThread)> callback) override;
    
    void saveCheckpoint(const ThreadId &threadId,
                       const QVariantMap &state,
                       const QString &label,
                       std::function<void(ThreadStoreError)> callback) override;
    
    void listCheckpoints(const ThreadId &threadId,
                        std::function<void(ThreadStoreError, QVector<QString>)> callback) override;
    
    void loadCheckpoint(const ThreadId &threadId,
                       const QString &checkpointId,
                       std::function<void(ThreadStoreError, QVariantMap)> callback) override;
    
    void getThread(const ThreadId &threadId,
                  std::function<void(ThreadStoreError, StoredThread)> callback) override;
    
    void listThreads(const QVariantMap &filter,
                    std::function<void(ThreadStoreError, QVector<StoredThread>)> callback) override;
    
    void updateThreadMetadata(const ThreadId &threadId,
                             const QVariantMap &metadata,
                             std::function<void(ThreadStoreError)> callback) override;
    
    void setThreadActive(const ThreadId &threadId,
                        bool active,
                        std::function<void(ThreadStoreError)> callback) override;
    
    void deleteThread(const ThreadId &threadId,
                     std::function<void(ThreadStoreError)> callback) override;
    
    void pruneCheckpoints(const ThreadId &threadId,
                         int keepCount,
                         std::function<void(ThreadStoreError)> callback) override;
    
    void getStats(std::function<void(const QVariantMap &stats)> callback) override;
    
    void maintenance(std::function<void(ThreadStoreError)> callback) override;

private:
    struct CheckpointData {
        QString id;
        QString label;
        QVariantMap state;
        QDateTime createdAt;
    };
    
    struct ThreadData {
        StoredThread thread;
        QVector<CheckpointData> checkpoints;
    };
    
    // Thread-safe access
    mutable QMutex m_mutex;
    QMap<ThreadId, ThreadData> m_threads;
};
