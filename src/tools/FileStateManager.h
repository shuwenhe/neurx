#pragma once

#include <QString>
#include <QMap>
#include <QMutex>
#include <QDateTime>
#include <memory>
#include <functional>

/**
 * @class FileStateManager
 * @brief Cross-agent file coordination system
 * 
 * Migrated from claude-code/hermes-agent file_state module:
 * - Track file reads per agent
 * - Track file writes (global)
 * - Detect staleness (external modifications)
 * - Per-file locking for read→modify→write atomicity
 * - Write conflict detection
 */

class FileStateManager {
public:
    using FileReadStamp = std::tuple<double, double, bool>;  // mtime, timestamp, partial

    explicit FileStateManager();
    ~FileStateManager() = default;

    // Read tracking
    void recordRead(const QString &taskId, const QString &filepath,
                   bool partial = false, double mtime = -1.0);

    // Write tracking
    void noteWrite(const QString &taskId, const QString &filepath, double mtime = -1.0);

    // Staleness checking
    QString checkStale(const QString &taskId, const QString &filepath) const;

    // Per-file locking
    template<typename F>
    auto withFileLock(const QString &filepath, F &&fn) const
    {
        auto lock = _getLockFor(filepath);
        lock->lock();
        try {
            return fn();
        } catch (...) {
            lock->unlock();
            throw;
        }
        lock->unlock();
    }

    // Query operations
    QStringList getRecentWrites(double sinceSeconds, const QStringList &paths = {}) const;
    bool wasModifiedExternally(const QString &filepath) const;
    QString getLastWriter(const QString &filepath) const;

    // Statistics
    QMap<QString, int> getStatistics() const;

    // Control
    void clear();
    void setDisabled(bool disabled);
    bool isDisabled() const;

    static constexpr int MAX_PATHS_PER_AGENT = 4096;
    static constexpr int MAX_GLOBAL_WRITERS = 4096;

private:
    struct ReadRecord {
        double mtime;
        double timestamp;
        bool partial;
    };

    struct WriteRecord {
        QString taskId;
        double timestamp;
    };

    std::shared_ptr<QMutex> _getLockFor(const QString &filepath) const;
    double _getFileMtime(const QString &filepath) const;
    void _capDict(QMap<QString, ReadRecord> &dict) const;

    // State
    QMap<QString, QMap<QString, ReadRecord>> m_reads;  // taskId -> filepath -> stamp
    QMap<QString, WriteRecord> m_lastWriter;            // filepath -> writer info
    mutable QMap<QString, std::shared_ptr<QMutex>> m_pathLocks;
    mutable QMutex m_metaLock;
    mutable QMutex m_stateLock;

    bool m_disabled{false};
};
