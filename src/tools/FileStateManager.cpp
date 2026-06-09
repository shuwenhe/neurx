#include "tools/FileStateManager.h"
#include <QFile>
#include <QFileInfo>
#include <QMutexLocker>
#include <QDateTime>
#include <cmath>
#include <algorithm>

FileStateManager::FileStateManager()
{
}

void FileStateManager::recordRead(const QString &taskId, const QString &filepath,
                                  bool partial, double mtime)
{
    if (m_disabled) return;

    if (mtime < 0.0) {
        mtime = _getFileMtime(filepath);
    }

    double now = QDateTime::currentMSecsSinceEpoch() / 1000.0;

    QMutexLocker locker(&m_stateLock);
    auto &agentReads = m_reads[taskId];
    agentReads[filepath] = {mtime, now, partial};

    _capDict(agentReads);
}

void FileStateManager::noteWrite(const QString &taskId, const QString &filepath, double mtime)
{
    if (m_disabled) return;

    if (mtime < 0.0) {
        mtime = _getFileMtime(filepath);
    }

    double now = QDateTime::currentMSecsSinceEpoch() / 1000.0;

    QMutexLocker locker(&m_stateLock);
    m_lastWriter[filepath] = {taskId, now};

    // Cap global writers map
    if (m_lastWriter.size() > MAX_GLOBAL_WRITERS) {
        auto it = m_lastWriter.begin();
        std::advance(it, m_lastWriter.size() - MAX_GLOBAL_WRITERS);
        m_lastWriter.erase(m_lastWriter.begin(), it);
    }

    // Writer's own read record is now up-to-date
    m_reads[taskId][filepath] = {mtime, now, false};
    _capDict(m_reads[taskId]);
}

QString FileStateManager::checkStale(const QString &taskId, const QString &filepath) const
{
    if (m_disabled) return "";

    QMutexLocker locker(&m_stateLock);

    // Get stamps
    auto readIt = m_reads.find(taskId);
    const auto *readStamp = (readIt != m_reads.end()) ? &readIt.value() : nullptr;
    auto stamp = readStamp ? readStamp->find(filepath) : QMap<QString, ReadRecord>::const_iterator{};

    auto lastWriterIt = m_lastWriter.find(filepath);
    const auto *lastWriter = (lastWriterIt != m_lastWriter.end()) ? &lastWriterIt.value() : nullptr;

    // Case 3: Never read and no write record - net-new file or first touch
    if ((readStamp == nullptr || stamp == readStamp->end()) && lastWriter == nullptr) {
        return "";
    }

    // Check current mtime
    double currentMtime = _getFileMtime(filepath);
    if (std::isnan(currentMtime)) {
        // File doesn't exist - write will create it
        return "";
    }

    // Case 1: Sibling subagent modified after our last read
    if (lastWriter != nullptr) {
        if (lastWriter->taskId != taskId) {
            if (readStamp == nullptr || stamp == readStamp->end()) {
                return QString("File %1 was modified by agent %2 but this agent never read it. "
                             "Read the file before writing.")
                    .arg(filepath, lastWriter->taskId);
            }

            double readTs = stamp.value().timestamp;
            if (lastWriter->timestamp > readTs) {
                return QString("File %1 was modified by agent %2 after this agent's last read. "
                             "Re-read the file before writing.")
                    .arg(filepath, lastWriter->taskId);
            }
        }
    }

    // Case 2: External modification (mtime drifted)
    if (readStamp != nullptr && stamp != readStamp->end()) {
        double readMtime = stamp.value().mtime;
        bool partial = stamp.value().partial;

        if (std::abs(currentMtime - readMtime) > 0.001) {  // Account for floating point
            return QString("File %1 was modified since you last read it (external edit). "
                         "Re-read the file before writing.")
                .arg(filepath);
        }
    }

    return "";
}

QStringList FileStateManager::getRecentWrites(double sinceSeconds, const QStringList &paths) const
{
    if (m_disabled) return {};

    QMutexLocker locker(&m_stateLock);
    double threshold = QDateTime::currentMSecsSinceEpoch() / 1000.0 - sinceSeconds;

    QStringList recent;
    for (auto it = m_lastWriter.begin(); it != m_lastWriter.end(); ++it) {
        if (it.value().timestamp >= threshold) {
            if (paths.isEmpty() || paths.contains(it.key())) {
                recent.append(it.key());
            }
        }
    }

    return recent;
}

bool FileStateManager::wasModifiedExternally(const QString &filepath) const
{
    if (m_disabled) return false;

    double currentMtime = _getFileMtime(filepath);
    if (std::isnan(currentMtime)) {
        return false;
    }

    QMutexLocker locker(&m_stateLock);

    for (auto &agentReads : m_reads) {
        auto it = agentReads.find(filepath);
        if (it != agentReads.end()) {
            double recordedMtime = it.value().mtime;
            if (std::abs(currentMtime - recordedMtime) > 0.001) {
                return true;
            }
        }
    }

    return false;
}

QString FileStateManager::getLastWriter(const QString &filepath) const
{
    if (m_disabled) return "";

    QMutexLocker locker(&m_stateLock);
    auto it = m_lastWriter.find(filepath);
    if (it != m_lastWriter.end()) {
        return it.value().taskId;
    }
    return "";
}

QMap<QString, int> FileStateManager::getStatistics() const
{
    QMutexLocker locker(&m_stateLock);

    QMap<QString, int> stats;
    stats["agents_tracked"] = m_reads.size();
    stats["total_read_records"] = 0;
    for (const auto &agentReads : m_reads) {
        stats["total_read_records"] += agentReads.size();
    }
    stats["write_records"] = m_lastWriter.size();

    return stats;
}

void FileStateManager::clear()
{
    QMutexLocker stateLocker(&m_stateLock);
    m_reads.clear();
    m_lastWriter.clear();

    QMutexLocker metaLocker(&m_metaLock);
    m_pathLocks.clear();
}

void FileStateManager::setDisabled(bool disabled)
{
    m_disabled = disabled;
}

bool FileStateManager::isDisabled() const
{
    return m_disabled;
}

std::shared_ptr<QMutex> FileStateManager::_getLockFor(const QString &filepath) const
{
    QMutexLocker locker(&m_metaLock);

    auto it = m_pathLocks.find(filepath);
    if (it != m_pathLocks.end()) {
        return it.value();
    }

    auto newLock = std::make_shared<QMutex>();
    m_pathLocks[filepath] = newLock;

    // Cap path locks
    if (m_pathLocks.size() > MAX_PATHS_PER_AGENT * 4) {
        auto it = m_pathLocks.begin();
        std::advance(it, m_pathLocks.size() - MAX_PATHS_PER_AGENT * 4);
        m_pathLocks.erase(m_pathLocks.begin(), it);
    }

    return newLock;
}

double FileStateManager::_getFileMtime(const QString &filepath) const
{
    QFileInfo fi(filepath);
    if (!fi.exists()) {
        return std::nan("");
    }

    return fi.lastModified().toSecsSinceEpoch();
}

void FileStateManager::_capDict(QMap<QString, ReadRecord> &dict) const
{
    if (dict.size() > MAX_PATHS_PER_AGENT) {
        auto it = dict.begin();
        std::advance(it, dict.size() - MAX_PATHS_PER_AGENT);
        dict.erase(dict.begin(), it);
    }
}
