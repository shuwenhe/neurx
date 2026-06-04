#include "OperationCache.h"
#include <algorithm>

OperationCache::OperationCache(QObject* parent)
    : QObject(parent), m_stats{} {
}

OperationCache::~OperationCache() {
    clear();
}

void OperationCache::setMaxCacheSize(size_t bytes) {
    m_maxCacheSize = bytes;
    optimizeMemory();
}

size_t OperationCache::getMaxCacheSize() const {
    return m_maxCacheSize;
}

void OperationCache::set(const QString& key, const QString& value) {
    // Remove old entry if exists
    if (m_cache.contains(key)) {
        m_cache.remove(key);
    }

    // Check if adding new entry exceeds limit
    if (calculateSize() + value.size() > m_maxCacheSize) {
        if (shouldEvict()) {
            evictLRU();
        }
    }

    // Add new entry
    CacheEntry entry;
    entry.key = key;
    entry.value = value;
    entry.timestamp = std::chrono::steady_clock::now();
    entry.accessCount = 0;

    m_cache[key] = entry;
    updateAccessOrder(key);
}

QString OperationCache::get(const QString& key) {
    auto it = m_cache.find(key);
    if (it != m_cache.end()) {
        it->accessCount++;
        it->timestamp = std::chrono::steady_clock::now();
        updateAccessOrder(key);

        m_stats.hits++;
        emit cacheHit(key);
        return it->value;
    }

    m_stats.misses++;
    emit cacheMiss(key);
    return QString();
}

bool OperationCache::contains(const QString& key) const {
    return m_cache.contains(key);
}

void OperationCache::remove(const QString& key) {
    if (m_cache.remove(key) > 0) {
        auto it = std::find(m_accessOrder.begin(), m_accessOrder.end(), key);
        if (it != m_accessOrder.end()) {
            m_accessOrder.erase(it);
        }
    }
}

void OperationCache::clear() {
    m_cache.clear();
    m_accessOrder.clear();
}

OperationCache::CacheStats OperationCache::getStats() const {
    CacheStats stats = m_stats;
    stats.currentSize = calculateSize();
    stats.entryCount = m_cache.size();
    return stats;
}

void OperationCache::resetStats() {
    m_stats.hits = 0;
    m_stats.misses = 0;
}

void OperationCache::optimizeMemory() {
    while (shouldEvict() && !m_cache.isEmpty()) {
        evictLRU();
    }
}

void OperationCache::evictLRU() {
    if (m_accessOrder.isEmpty()) return;

    QString lruKey = m_accessOrder.front();
    m_accessOrder.pop_front();
    m_cache.remove(lruKey);

    emit cacheEvicted(lruKey);

    // Check memory critical
    if (calculateSize() > m_maxCacheSize * 0.9) {
        emit memoryCritical();
    }
}

QMap<QString, QString> OperationCache::getBatch(const QStringList& keys) {
    QMap<QString, QString> results;

    for (const auto& key : keys) {
        QString value = get(key);
        if (!value.isEmpty()) {
            results[key] = value;
        }
    }

    return results;
}

void OperationCache::setBatch(const QMap<QString, QString>& items) {
    for (auto it = items.begin(); it != items.end(); ++it) {
        set(it.key(), it.value());
    }
}

void OperationCache::updateAccessOrder(const QString& key) {
    auto it = std::find(m_accessOrder.begin(), m_accessOrder.end(), key);
    if (it != m_accessOrder.end()) {
        m_accessOrder.erase(it);
    }
    m_accessOrder.push_back(key);
}

size_t OperationCache::calculateSize() const {
    size_t size = 0;
    for (const auto& entry : m_cache) {
        size += entry.key.size() + entry.value.size();
    }
    return size;
}

bool OperationCache::shouldEvict() const {
    return calculateSize() > m_maxCacheSize;
}
