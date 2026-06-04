#ifndef OPERATIONCACHE_H
#define OPERATIONCACHE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>
#include <QVector>
#include <memory>
#include <chrono>

/**
 * @class OperationCache
 * @brief Intelligent caching for editor operations
 * 
 * Features:
 * - LRU cache for frequent operations
 * - Operation history tracking
 * - Smart cache invalidation
 * - Memory-aware caching
 */

class OperationCache : public QObject {
    Q_OBJECT

public:
    explicit OperationCache(QObject* parent = nullptr);
    ~OperationCache();

    // Cache entry
    struct CacheEntry {
        QString key;
        QString value;
        std::chrono::steady_clock::time_point timestamp;
        int accessCount = 0;
    };

    // Set cache size limit
    void setMaxCacheSize(size_t bytes);
    size_t getMaxCacheSize() const;

    // Cache operations
    void set(const QString& key, const QString& value);
    QString get(const QString& key);
    bool contains(const QString& key) const;
    void remove(const QString& key);
    void clear();

    // Statistics
    struct CacheStats {
        int hits = 0;
        int misses = 0;
        size_t currentSize = 0;
        int entryCount = 0;

        double getHitRate() const {
            int total = hits + misses;
            return total > 0 ? static_cast<double>(hits) / total : 0.0;
        }
    };

    CacheStats getStats() const;
    void resetStats();

    // Cache optimization
    void optimizeMemory();
    void evictLRU();

    // Batch operations with caching
    QMap<QString, QString> getBatch(const QStringList& keys);
    void setBatch(const QMap<QString, QString>& items);

signals:
    void cacheHit(const QString& key);
    void cacheMiss(const QString& key);
    void cacheEvicted(const QString& key);
    void memoryCritical();

private:
    // LRU Map: key -> entry
    QMap<QString, CacheEntry> m_cache;

    // Access order for LRU
    QVector<QString> m_accessOrder;

    // Statistics
    CacheStats m_stats;

    // Configuration
    size_t m_maxCacheSize = 10 * 1024 * 1024;  // 10MB default

    // Helper methods
    void updateAccessOrder(const QString& key);
    size_t calculateSize() const;
    bool shouldEvict() const;
};

#endif // OPERATIONCACHE_H
