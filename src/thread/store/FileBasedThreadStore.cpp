#include "FileBasedThreadStore.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QMutexLocker>
#include <QDebug>

FileBasedThreadStore::FileBasedThreadStore(const QString &baseDir, QObject *parent)
    : ThreadStore(parent), m_baseDir(baseDir)
{
}

FileBasedThreadStore::~FileBasedThreadStore()
{
}

bool FileBasedThreadStore::initialize()
{
    QMutexLocker locker(&m_mutex);
    
    // Create base directory structure
    if (!ensureDirectoryExists(m_baseDir)) {
        return false;
    }
    
    QString threadsDir = m_baseDir + "/threads";
    if (!ensureDirectoryExists(threadsDir)) {
        return false;
    }
    
    m_initialized = true;
    return true;
}

bool FileBasedThreadStore::isInitialized() const
{
    QMutexLocker locker(&m_mutex);
    return m_initialized;
}

QString FileBasedThreadStore::getBasePath() const
{
    QMutexLocker locker(&m_mutex);
    return m_baseDir;
}

void FileBasedThreadStore::createThread(const CreateThreadParams &params,
                                       std::function<void(ThreadStoreError, ThreadId)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError, ThreadId());
        }
        return;
    }
    
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
    
    if (!saveThreadToFile(thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError, ThreadId());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, newId);
    }
    
    emit threadModified(newId);
}

void FileBasedThreadStore::upsertThread(const StoredThread &thread,
                                        std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);

    if (!m_initialized) {
        locker.unlock();
        if (callback)
            callback(ThreadStoreError::StorageError);
        return;
    }

    if (thread.id.isNull()) {
        locker.unlock();
        if (callback)
            callback(ThreadStoreError::InvalidOperation);
        return;
    }

    StoredThread normalized = thread;
    if (normalized.metadata.threadId.isNull())
        normalized.metadata.threadId = normalized.id;
    normalized.metadata.lastModified = QDateTime::currentDateTime();

    if (!saveThreadToFile(normalized)) {
        locker.unlock();
        if (callback)
            callback(ThreadStoreError::StorageError);
        return;
    }

    locker.unlock();
    if (callback)
        callback(ThreadStoreError::Success);
    emit threadModified(normalized.id);
}

void FileBasedThreadStore::forkThread(const ThreadId &parentId,
                                     const QVariantMap &forkContext,
                                     std::function<void(ThreadStoreError, ThreadId)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError, ThreadId());
        }
        return;
    }
    
    StoredThread parentThread;
    if (!loadThreadFromFile(parentId, parentThread)) {
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
    thread.lastState = parentThread.lastState;
    thread.isActive = true;
    
    if (!saveThreadToFile(thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError, ThreadId());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, newId);
    }
    
    emit threadModified(newId);
}

void FileBasedThreadStore::resumeThread(const ResumeThreadParams &params,
                                       std::function<void(ThreadStoreError, StoredThread)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError, StoredThread());
        }
        return;
    }
    
    StoredThread thread;
    if (!loadThreadFromFile(params.threadId, thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, StoredThread());
        }
        return;
    }
    
    // Try to load checkpoint if specified
    if (!params.checkpointVersion.isEmpty()) {
        CheckpointData checkpoint;
        if (!loadCheckpointFromFile(params.threadId, params.checkpointVersion, checkpoint)) {
            locker.unlock();
            if (callback) {
                callback(ThreadStoreError::CheckpointNotFound, StoredThread());
            }
            return;
        }
        thread.lastState = checkpoint.state;
    }
    
    // Merge context overrides
    for (auto it = params.contextOverrides.begin(); it != params.contextOverrides.end(); ++it) {
        thread.lastState[it.key()] = it.value();
    }
    
    thread.isActive = true;
    thread.lastExecuted = QDateTime::currentDateTime();
    
    if (!saveThreadToFile(thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError, StoredThread());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, thread);
    }
    
    emit threadModified(params.threadId);
}

void FileBasedThreadStore::saveCheckpoint(const ThreadId &threadId,
                                         const QVariantMap &state,
                                         const QString &label,
                                         std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (!m_initialized) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError);
        }
        return;
    }
    
    StoredThread thread;
    if (!loadThreadFromFile(threadId, thread)) {
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
    
    if (!saveCheckpointToFile(threadId, checkpoint)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError);
        }
        return;
    }
    
    thread.lastState = state;
    thread.availableCheckpoints.append(checkpoint.id);
    thread.metadata.checkpointCount++;
    thread.metadata.lastCheckpointAt = QDateTime::currentDateTime();
    
    if (!saveThreadToFile(thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError);
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit checkpointCreated(threadId, checkpoint.id);
    emit threadModified(threadId);
}

void FileBasedThreadStore::listCheckpoints(const ThreadId &threadId,
                                          std::function<void(ThreadStoreError, QVector<QString>)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString cpDir = checkpointsDir(threadId);
    QDir dir(cpDir);
    
    if (!dir.exists()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, QVector<QString>());
        }
        return;
    }
    
    QStringList filters;
    filters << "*.json";
    QStringList files = dir.entryList(filters, QDir::Files);
    
    QVector<QString> ids;
    for (const auto &file : files) {
        ids.append(file.left(file.size() - 5));
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, ids);
    }
}

void FileBasedThreadStore::loadCheckpoint(const ThreadId &threadId,
                                         const QString &checkpointId,
                                         std::function<void(ThreadStoreError, QVariantMap)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    CheckpointData checkpoint;
    if (!loadCheckpointFromFile(threadId, checkpointId, checkpoint)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::CheckpointNotFound, QVariantMap());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, checkpoint.state);
    }
}

void FileBasedThreadStore::getThread(const ThreadId &threadId,
                                    std::function<void(ThreadStoreError, StoredThread)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    StoredThread thread;
    if (!loadThreadFromFile(threadId, thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound, StoredThread());
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, thread);
    }
}

void FileBasedThreadStore::listThreads(const QVariantMap &filter,
                                      std::function<void(ThreadStoreError, QVector<StoredThread>)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString threadsDir = m_baseDir + "/threads";
    QDir dir(threadsDir);
    
    if (!dir.exists()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::Success, QVector<StoredThread>());
        }
        return;
    }
    
    QStringList threadDirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    QVector<StoredThread> threads;
    
    for (const auto &dirName : threadDirs) {
        ThreadId id = ThreadId::fromString(dirName);
        StoredThread thread;
        if (loadThreadFromFile(id, thread)) {
            threads.append(thread);
        }
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success, threads);
    }
}

void FileBasedThreadStore::updateThreadMetadata(const ThreadId &threadId,
                                               const QVariantMap &metadata,
                                               std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    StoredThread thread;
    if (!loadThreadFromFile(threadId, thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    thread.metadata.customMetadata = metadata;
    thread.metadata.lastModified = QDateTime::currentDateTime();
    
    if (!saveThreadToFile(thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError);
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadModified(threadId);
}

void FileBasedThreadStore::setThreadActive(const ThreadId &threadId,
                                          bool active,
                                          std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    StoredThread thread;
    if (!loadThreadFromFile(threadId, thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    thread.isActive = active;
    thread.lastExecuted = QDateTime::currentDateTime();
    
    if (!saveThreadToFile(thread)) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError);
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadModified(threadId);
}

void FileBasedThreadStore::deleteThread(const ThreadId &threadId,
                                       std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString threadDir = threadPath(threadId);
    QDir dir(threadDir);
    
    if (!dir.exists()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    if (!dir.removeRecursively()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::StorageError);
        }
        return;
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadDeleted(threadId);
}

void FileBasedThreadStore::pruneCheckpoints(const ThreadId &threadId,
                                           int keepCount,
                                           std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString cpDir = checkpointsDir(threadId);
    QDir dir(cpDir);
    
    if (!dir.exists()) {
        locker.unlock();
        if (callback) {
            callback(ThreadStoreError::NotFound);
        }
        return;
    }
    
    QStringList files = dir.entryList(QStringList() << "*.json", QDir::Files);
    std::sort(files.begin(), files.end());
    
    int toDelete = files.size() - keepCount;
    for (int i = 0; i < toDelete && i < files.size(); ++i) {
        dir.remove(files[i]);
    }
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
    
    emit threadModified(threadId);
}

void FileBasedThreadStore::getStats(std::function<void(const QVariantMap &stats)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString threadsDir = m_baseDir + "/threads";
    QDir dir(threadsDir);
    
    int threadCount = 0;
    int checkpointCount = 0;
    
    if (dir.exists()) {
        QStringList threadDirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        threadCount = threadDirs.size();
        
        for (const auto &dirName : threadDirs) {
            QString cpPath = threadPath(ThreadId::fromString(dirName)) + "/checkpoints";
            QDir cpDir(cpPath);
            if (cpDir.exists()) {
                checkpointCount += cpDir.entryList(QStringList() << "*.json", QDir::Files).size();
            }
        }
    }
    
    QVariantMap stats;
    stats["threadCount"] = threadCount;
    stats["totalCheckpoints"] = checkpointCount;
    stats["storageBasePath"] = m_baseDir;
    
    locker.unlock();
    
    if (callback) {
        callback(stats);
    }
}

void FileBasedThreadStore::maintenance(std::function<void(ThreadStoreError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    // Could implement cleanup of orphaned files, etc.
    
    locker.unlock();
    
    if (callback) {
        callback(ThreadStoreError::Success);
    }
}

QString FileBasedThreadStore::threadPath(const ThreadId &threadId) const
{
    return m_baseDir + "/threads/" + threadId.toString();
}

QString FileBasedThreadStore::checkpointPath(const ThreadId &threadId, const QString &checkpointId) const
{
    return checkpointsDir(threadId) + "/" + checkpointId + ".json";
}

QString FileBasedThreadStore::checkpointsDir(const ThreadId &threadId) const
{
    return threadPath(threadId) + "/checkpoints";
}

QString FileBasedThreadStore::metadataPath() const
{
    return m_baseDir + "/metadata.json";
}

bool FileBasedThreadStore::saveThreadToFile(const StoredThread &thread)
{
    QString path = threadPath(thread.id);
    
    if (!ensureDirectoryExists(path)) {
        return false;
    }
    
    // Serialize the full thread snapshot so the store can act as a state layer,
    // not just a metadata index.
    QJsonObject threadObj;
    threadObj["id"] = thread.id.toString();
    threadObj["isActive"] = thread.isActive;
    threadObj["metadata"] = QJsonObject::fromVariantMap(QVariantMap{
        {QStringLiteral("threadId"), thread.metadata.threadId.toString()},
        {QStringLiteral("parentThreadId"), thread.metadata.parentThreadId.toString()},
        {QStringLiteral("mode"), int(thread.metadata.mode)},
        {QStringLiteral("createdAt"), thread.metadata.createdAt.toUTC().toString(Qt::ISODateWithMs)},
        {QStringLiteral("lastModified"), thread.metadata.lastModified.toUTC().toString(Qt::ISODateWithMs)},
        {QStringLiteral("lastCheckpointAt"), thread.metadata.lastCheckpointAt.toUTC().toString(Qt::ISODateWithMs)},
        {QStringLiteral("checkpointCount"), thread.metadata.checkpointCount},
        {QStringLiteral("forkCount"), thread.metadata.forkCount},
        {QStringLiteral("customMetadata"), thread.metadata.customMetadata},
    });
    threadObj["lastState"] = QJsonObject::fromVariantMap(thread.lastState);
    threadObj["availableCheckpoints"] = QJsonArray::fromStringList(thread.availableCheckpoints);
    threadObj["lastExecuted"] = thread.lastExecuted.isValid()
        ? thread.lastExecuted.toUTC().toString(Qt::ISODateWithMs)
        : QString{};
    
    // Save to file
    QString filePath = path + "/thread.json";
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    
    QJsonDocument doc(threadObj);
    file.write(doc.toJson());
    file.close();
    
    return true;
}

bool FileBasedThreadStore::loadThreadFromFile(const ThreadId &threadId, StoredThread &thread)
{
    QString filePath = threadPath(threadId) + "/thread.json";
    QFile file(filePath);
    
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        return false;
    }
    
    // Deserialize from JSON
    thread.id = threadId;
    thread.isActive = doc.object()["isActive"].toBool(false);
    const QJsonObject metaObj = doc.object().value("metadata").toObject();
    thread.metadata.threadId = ThreadId::fromString(metaObj.value("threadId").toString(threadId.toString()));
    thread.metadata.parentThreadId = ThreadId::fromString(metaObj.value("parentThreadId").toString());
    thread.metadata.mode = static_cast<ThreadInitializationMode>(metaObj.value("mode").toInt(int(ThreadInitializationMode::Fresh)));
    thread.metadata.createdAt = QDateTime::fromString(metaObj.value("createdAt").toString(), Qt::ISODateWithMs);
    thread.metadata.lastModified = QDateTime::fromString(metaObj.value("lastModified").toString(), Qt::ISODateWithMs);
    thread.metadata.lastCheckpointAt = QDateTime::fromString(metaObj.value("lastCheckpointAt").toString(), Qt::ISODateWithMs);
    thread.metadata.checkpointCount = metaObj.value("checkpointCount").toInt(0);
    thread.metadata.forkCount = metaObj.value("forkCount").toInt(0);
    thread.metadata.customMetadata = metaObj.value("customMetadata").toObject().toVariantMap();
    thread.lastState = doc.object().value("lastState").toObject().toVariantMap();
    for (const auto &value : doc.object().value("availableCheckpoints").toArray()) {
        thread.availableCheckpoints.append(value.toString());
    }
    thread.lastExecuted = QDateTime::fromString(doc.object().value("lastExecuted").toString(), Qt::ISODateWithMs);

    return true;
}

bool FileBasedThreadStore::saveCheckpointToFile(const ThreadId &threadId, const CheckpointData &checkpoint)
{
    if (!ensureDirectoryExists(checkpointsDir(threadId))) {
        return false;
    }
    
    QString filePath = checkpointPath(threadId, checkpoint.id);
    QFile file(filePath);
    
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    
    QJsonObject cpObj;
    cpObj["id"] = checkpoint.id;
    cpObj["label"] = checkpoint.label;
    
    QJsonDocument doc(cpObj);
    file.write(doc.toJson());
    file.close();
    
    return true;
}

bool FileBasedThreadStore::loadCheckpointFromFile(const ThreadId &threadId, const QString &checkpointId, CheckpointData &checkpoint)
{
    QString filePath = checkpointPath(threadId, checkpointId);
    QFile file(filePath);
    
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        return false;
    }
    
    checkpoint.id = checkpointId;
    checkpoint.label = doc.object()["label"].toString();
    
    return true;
}

bool FileBasedThreadStore::ensureDirectoryExists(const QString &path)
{
    QDir dir;
    return dir.mkpath(path);
}

QVariantMap FileBasedThreadStore::loadMetadata()
{
    QString path = metadataPath();
    QFile file(path);
    
    if (!file.open(QIODevice::ReadOnly)) {
        return QVariantMap();
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    return doc.toVariant().toMap();
}

bool FileBasedThreadStore::saveMetadata(const QVariantMap &metadata)
{
    QString path = metadataPath();
    QFile file(path);
    
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    
    QJsonDocument doc = QJsonDocument::fromVariant(metadata);
    file.write(doc.toJson());
    file.close();
    
    return true;
}

#include "moc_FileBasedThreadStore.cpp"
