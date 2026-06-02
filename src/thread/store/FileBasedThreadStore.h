#pragma once

#include "ThreadStore.h"
#include <QString>
#include <memory>

/**
 * @class FileBasedThreadStore
 * @brief File system-based thread storage implementation
 * 
 * Provides persistent thread storage using JSON files:
 * - Threads stored as JSON in dedicated directory
 * - Checkpoints stored separately per thread
 * - Thread metadata indexed for quick lookup
 * - Atomic writes for data consistency
 * 
 * Directory structure:
 * {baseDir}/
 *   metadata.json (index)
 *   threads/
 *     {threadId}/
 *       thread.json (thread data)
 *       checkpoints/
 *         {checkpointId}.json
 */
class FileBasedThreadStore : public ThreadStore {
    Q_OBJECT
public:
    explicit FileBasedThreadStore(const QString &baseDir, QObject *parent = nullptr);
    ~FileBasedThreadStore();
    
    // Initialization
    bool initialize();
    bool isInitialized() const;
    QString getBasePath() const;
    
    // ThreadStore interface
    void createThread(const CreateThreadParams &params,
                     std::function<void(ThreadStoreError, ThreadId)> callback) override;
    void upsertThread(const StoredThread &thread,
                     std::function<void(ThreadStoreError)> callback) override;
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
    QString m_baseDir;
    bool m_initialized{false};
    mutable QMutex m_mutex;
    
    // File operations
    QString threadPath(const ThreadId &threadId) const;
    QString checkpointPath(const ThreadId &threadId, const QString &checkpointId) const;
    QString checkpointsDir(const ThreadId &threadId) const;
    QString metadataPath() const;
    
    // Serialization
    bool saveThreadToFile(const StoredThread &thread);
    bool loadThreadFromFile(const ThreadId &threadId, StoredThread &thread);
    bool saveCheckpointToFile(const ThreadId &threadId, const CheckpointData &checkpoint);
    bool loadCheckpointFromFile(const ThreadId &threadId, const QString &checkpointId, CheckpointData &checkpoint);
    
    // Utilities
    bool ensureDirectoryExists(const QString &path);
    QVariantMap loadMetadata();
    bool saveMetadata(const QVariantMap &metadata);
};

using FileBasedThreadStorePtr = std::shared_ptr<FileBasedThreadStore>;
