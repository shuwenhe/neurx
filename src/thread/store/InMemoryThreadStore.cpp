#include "InMemoryThreadStore.h"
#include <QDateTime>
#include <QDebug>

InMemoryThreadStore::InMemoryThreadStore(QObject *parent)
    : ThreadStore(parent)
{
}

void InMemoryThreadStore::createThread(const CreateThreadParams &params,
                                       std::function<void(ThreadStoreError, ThreadId)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    ThreadId newId = ThreadId::generate();
    
    StoredThread thread;
    thread.id = newId;
    thread.metadata.threadId = newId;
    thread.metadata.parentThreadId = params.parentThreadId;
    thread.metadata.mode = params.mode;
    thread.metadata.createdAt = QDateTime::currentDateTime();
    thread.metadata.lastModified = QDateTime::currentDateTime();
    thread.metadata.customMetadata = params.metadata;
    
    thread.isActive = true;
    thread.lastExecuted = QDateTime::currentDateTime();
    
    ThreadData data;
    data.thread = thread;
    m_threads[newId] = data;
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, newId);
    }
    
    emit threadModified(newId);
}

void InMemoryThreadStore::upsertThread(const StoredThread &thread,
                                       std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);

    if (thread.id.isNull()) {
        locker.unlock();
        if (callback)
            callback(ThreadStoreError::InvalidOperation);
        return;
    }

    ThreadData &data = m_threads[thread.id];
    data.thread = thread;
    if (data.thread.metadata.threadId.isNull())
        data.thread.metadata.threadId = thread.id;
    data.thread.metadata.lastModified = QDateTime::currentDateTime();
    locker.unlock();

    if (callback)
        callback(ThreadStoreError::Success);
    emit threadModified(thread.id);
}

void InMemoryThreadStore::forkThread(const ThreadId &parentId,
                                     const QVariantMap &forkContext,
                                     std::function<void(ThreadStoreError, ThreadId)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(parentId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, ThreadId());
        }
        return;
    }
    
    ThreadId newId = ThreadId::generate();
    
    StoredThread thread;
    thread.id = newId;
    thread.metadata.threadId = newId;
    thread.metadata.parentThreadId = parentId;
    thread.metadata.mode = ThreadInitializationMode::Forked;
    thread.metadata.createdAt = QDateTime::currentDateTime();
    thread.metadata.lastModified = QDateTime::currentDateTime();
    thread.metadata.customMetadata = forkContext;
    
    // Copy parent's last state as starting point
    thread.lastState = it->thread.lastState;
    thread.isActive = true;
    
    // Increment parent's fork count
    it->thread.metadata.forkCount++;
    
    ThreadData data;
    data.thread = thread;
    m_threads[newId] = data;
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, newId);
    }
    
    emit threadModified(newId);
}

void InMemoryThreadStore::resumeThread(const ResumeThreadParams &params,
                                       std::function<void(ThreadStoreError, StoredThread)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(params.threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, StoredThread());
        }
        return;
    }
    
    StoredThread thread = it->thread;
    
    // Try to load checkpoint if specified
    if (!params.checkpointVersion.isEmpty()) {
        auto &checkpoints = it->checkpoints;
        auto cpIt = std::find_if(checkpoints.begin(), checkpoints.end(),
                                [&](const CheckpointData &cp) {
                                    return cp.id == params.checkpointVersion;
                                });
        if (cpIt != checkpoints.end()) {
            thread.lastState = cpIt->state;
        } else {
            locker.unlock();
            if (callback) {
                callback(ThreadStoreError::CheckpointNotFound, StoredThread());
            }
            return;
        }
    } else if (!it->checkpoints.empty()) {
        // Use latest checkpoint
        thread.lastState = it->checkpoints.back().state;
    }
    
    // Merge context overrides
    for (auto it = params.contextOverrides.begin(); it != params.contextOverrides.end(); ++it) {
        thread.lastState[it.key()] = it.value();
    }
    
    thread.isActive = true;
    it->thread = thread;
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, thread);
    }
    
    emit threadModified(params.threadId);
}

void InMemoryThreadStore::saveCheckpoint(const ThreadId &threadId,
                                        const QVariantMap &state,
                                        const QString &label,
                                        std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    CheckpointData checkpoint;
    checkpoint.id = QString("%1_%2").arg(label, QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
    checkpoint.label = label;
    checkpoint.state = state;
    checkpoint.createdAt = QDateTime::currentDateTime();
    
    it->checkpoints.append(checkpoint);
    it->thread.availableCheckpoints.append(checkpoint.id);
    it->thread.lastState = state;
    it->thread.metadata.lastCheckpointAt = QDateTime::currentDateTime();
    it->thread.metadata.checkpointCount++;
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit checkpointCreated(threadId, checkpoint.id);
    emit threadModified(threadId);
}

void InMemoryThreadStore::listCheckpoints(const ThreadId &threadId,
                                         std::function<void(ThreadStoreError, QVector<QString>)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, QVector<QString>());
        }
        return;
    }
    
    QVector<QString> ids;
    for (const auto &cp : it->checkpoints) {
        ids.append(cp.id);
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, ids);
    }
}

void InMemoryThreadStore::loadCheckpoint(const ThreadId &threadId,
                                        const QString &checkpointId,
                                        std::function<void(ThreadStoreError, QVariantMap)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, QVariantMap());
        }
        return;
    }
    
    auto cpIt = std::find_if(it->checkpoints.begin(), it->checkpoints.end(),
                            [&](const CheckpointData &cp) {
                                return cp.id == checkpointId;
                            });
    if (cpIt == it->checkpoints.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::CheckpointNotFound, QVariantMap());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, cpIt->state);
    }
}

void InMemoryThreadStore::getThread(const ThreadId &threadId,
                                   std::function<void(ThreadStoreError, StoredThread)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, StoredThread());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, it->thread);
    }
}

void InMemoryThreadStore::listThreads(const QVariantMap &filter,
                                     std::function<void(ThreadStoreError, QVector<StoredThread>)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<StoredThread> threads;
    for (const auto &data : m_threads) {
        threads.append(data.thread);
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, threads);
    }
}

void InMemoryThreadStore::updateThreadMetadata(const ThreadId &threadId,
                                              const QVariantMap &metadata,
                                              std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    it->thread.metadata.customMetadata = metadata;
    it->thread.metadata.lastModified = QDateTime::currentDateTime();
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadModified(threadId);
}

void InMemoryThreadStore::setThreadActive(const ThreadId &threadId,
                                         bool active,
                                         std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    it->thread.isActive = active;
    it->thread.lastExecuted = QDateTime::currentDateTime();
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadModified(threadId);
}

void InMemoryThreadStore::deleteThread(const ThreadId &threadId,
                                      std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    m_threads.erase(it);
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadDeleted(threadId);
}

void InMemoryThreadStore::pruneCheckpoints(const ThreadId &threadId,
                                          int keepCount,
                                          std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_threads.find(threadId);
    if (it == m_threads.end()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    if (it->checkpoints.size() > keepCount) {
        int toRemove = it->checkpoints.size() - keepCount;
        it->checkpoints.erase(it->checkpoints.begin(), it->checkpoints.begin() + toRemove);
        
        it->thread.availableCheckpoints.clear();
        for (const auto &cp : it->checkpoints) {
            it->thread.availableCheckpoints.append(cp.id);
        }
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadModified(threadId);
}

void InMemoryThreadStore::getStats(std::function<void(const QVariantMap &stats)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["threadCount"] = m_threads.size();
    
    int totalCheckpoints = 0;
    for (const auto &data : m_threads) {
        totalCheckpoints += data.checkpoints.size();
    }
    stats["totalCheckpoints"] = totalCheckpoints;
    
    locker.unlock();
    
    if (callback) {
        callback(stats);
    }
}

void InMemoryThreadStore::maintenance(std::function<void(ThreadStoreError)> callback)
{
    // In-memory store doesn't need maintenance, but we can clean up inactive threads
    QMutexLocker locker(&m_mutex);
    
    // Could implement cleanup of old inactive threads here
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
}
