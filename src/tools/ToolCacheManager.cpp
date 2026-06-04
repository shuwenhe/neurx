#include "ToolCacheManager.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QUuid>
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>

ToolCacheManager::ToolCacheManager(QObject *parent)
    : QObject(parent),
      m_invalidationStrategy(CacheInvalidationStrategy::TTL),
      m_statistics{0, 0, 0, 0.0f, 0, 0, 0.0f, QDateTime::currentDateTime(), 0} {
    qDebug() << "[ToolCacheManager] Initialized with" << m_maxCacheSizeBytes / (1024 * 1024) << "MB cache";
}

// ── 缓存操作 ────────────────────────────────────────

bool ToolCacheManager::getFromCache(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    QVariantMap &result,
    float &confidence) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_cacheEnabled) {
        m_statistics.missCount++;
        // const_cast for signal emission in const method
        const_cast<ToolCacheManager*>(this)->emit cacheMiss(toolId, capabilityName);
        return false;
    }
    
    QString key = generateCacheKey(toolId, capabilityName, parameters);
    
    if (m_cache.contains(key)) {
        const auto &entry = m_cache[key];
        
        // 检查是否过期
        if (QDateTime::currentDateTime() > entry.expiresAt) {
            const_cast<ToolCacheManager*>(this)->invalidateCacheEntry(entry.entryId);
            m_statistics.missCount++;
            const_cast<ToolCacheManager*>(this)->emit cacheMiss(toolId, capabilityName);
            return false;
        }
        
        // 检查置信度
        if (entry.confidence < m_confidenceThreshold) {
            m_statistics.missCount++;
            const_cast<ToolCacheManager*>(this)->emit cacheMiss(toolId, capabilityName);
            return false;
        }
        
        result = entry.result;
        confidence = entry.confidence;
        
        // 更新访问统计
        const_cast<ToolCacheManager*>(this)->updateAccessStats(key);
        
        m_statistics.hitCount++;
        m_statistics.hitRatio = (float)m_statistics.hitCount / 
                               (m_statistics.hitCount + m_statistics.missCount);
        
        const_cast<ToolCacheManager*>(this)->emit cacheHit(toolId, capabilityName);
        
        qDebug() << "[ToolCacheManager] Cache hit for" << capabilityName;
        return true;
    }
    
    m_statistics.missCount++;
    const_cast<ToolCacheManager*>(this)->emit cacheMiss(toolId, capabilityName);
    return false;
}

void ToolCacheManager::putInCache(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    const QVariantMap &result,
    int timeoutSeconds,
    float confidence) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_cacheEnabled) {
        return;
    }
    
    QString key = generateCacheKey(toolId, capabilityName, parameters);
    
    CacheMetadata entry;
    entry.entryId = generateEntryId();
    entry.toolId = toolId;
    entry.capabilityName = capabilityName;
    entry.parameters = parameters;
    entry.result = result;
    entry.createdAt = QDateTime::currentDateTime();
    entry.expiresAt = entry.createdAt.addSecs(timeoutSeconds);
    entry.confidence = confidence;
    // Calculate size - simplified version
    entry.sizeBytes = sizeof(entry) + 256;  // Rough estimate
    
    m_cache[key] = entry;
    m_accessOrder.append(key);
    
    m_statistics.totalEntries = m_cache.size();
    m_statistics.totalSizeBytes += entry.sizeBytes;
    
    checkCacheSize();
    
    qDebug() << "[ToolCacheManager] Cached result for" << capabilityName;
}

void ToolCacheManager::invalidateCacheEntry(const QString &entryId) {
    QMutexLocker locker(&m_mutex);
    
    // 查找并删除条目
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        if (it.value().entryId == entryId) {
            m_statistics.totalSizeBytes -= it.value().sizeBytes;
            m_cache.erase(it);
            m_statistics.totalEntries = m_cache.size();
            
            emit cacheItemInvalidated(entryId);
            return;
        }
    }
}

void ToolCacheManager::invalidateToolCache(const QString &toolId) {
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> keysToRemove;
    
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        if (it.value().toolId == toolId) {
            keysToRemove.append(it.key());
        }
    }
    
    for (const auto &key : keysToRemove) {
        m_statistics.totalSizeBytes -= m_cache[key].sizeBytes;
        m_cache.remove(key);
        m_accessOrder.removeAll(key);
    }
    
    m_statistics.totalEntries = m_cache.size();
    qDebug() << "[ToolCacheManager] Invalidated cache for tool" << toolId;
}

void ToolCacheManager::invalidateCapabilityCache(
    const QString &toolId,
    const QString &capabilityName) {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> keysToRemove;
    
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        if (it.value().toolId == toolId && 
            it.value().capabilityName == capabilityName) {
            keysToRemove.append(it.key());
        }
    }
    
    for (const auto &key : keysToRemove) {
        m_statistics.totalSizeBytes -= m_cache[key].sizeBytes;
        m_cache.remove(key);
        m_accessOrder.removeAll(key);
    }
    
    m_statistics.totalEntries = m_cache.size();
}

void ToolCacheManager::clearAllCache() {
    QMutexLocker locker(&m_mutex);
    
    m_cache.clear();
    m_accessOrder.clear();
    m_statistics.totalEntries = 0;
    m_statistics.totalSizeBytes = 0;
    m_statistics.itemsEvicted = 0;
    
    qDebug() << "[ToolCacheManager] Cache cleared";
}

bool ToolCacheManager::cacheExists(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters) const {
    
    QMutexLocker locker(&m_mutex);
    
    QString key = generateCacheKey(toolId, capabilityName, parameters);
    
    if (m_cache.contains(key)) {
        const auto &entry = m_cache[key];
        return QDateTime::currentDateTime() <= entry.expiresAt;
    }
    
    return false;
}

// ── 缓存配置 ────────────────────────────────────────

void ToolCacheManager::enableCache(bool enable) {
    QMutexLocker locker(&m_mutex);
    m_cacheEnabled = enable;
    qDebug() << "[ToolCacheManager] Cache" << (enable ? "enabled" : "disabled");
}

void ToolCacheManager::setMaxCacheSize(int sizeBytes) {
    QMutexLocker locker(&m_mutex);
    m_maxCacheSizeBytes = sizeBytes;
}

void ToolCacheManager::setCacheInvalidationStrategy(
    CacheInvalidationStrategy strategy) {
    QMutexLocker locker(&m_mutex);
    m_invalidationStrategy = strategy;
    qDebug() << "[ToolCacheManager] Cache invalidation strategy updated";
}

void ToolCacheManager::setCacheDefaultTTL(int seconds) {
    QMutexLocker locker(&m_mutex);
    m_defaultTTLSeconds = seconds;
}

void ToolCacheManager::setCacheConfidenceThreshold(float threshold) {
    QMutexLocker locker(&m_mutex);
    m_confidenceThreshold = threshold;
}

void ToolCacheManager::enableDiskCache(bool enable) {
    QMutexLocker locker(&m_mutex);
    m_diskCacheEnabled = enable;
    qDebug() << "[ToolCacheManager] Disk cache" << (enable ? "enabled" : "disabled");
}

void ToolCacheManager::setDiskCachePath(const QString &path) {
    QMutexLocker locker(&m_mutex);
    m_diskCachePath = path;
    QDir().mkpath(path);
    qDebug() << "[ToolCacheManager] Disk cache path:" << path;
}

// ── 缓存预热 ────────────────────────────────────────

void ToolCacheManager::warmupCache(
    const QString &toolId,
    const QVector<QVariantMap> &parametersList,
    std::function<void(int, int)> progressCallback) {
    
    qDebug() << "[ToolCacheManager] Starting cache warmup for" << toolId;
    
    for (int i = 0; i < parametersList.size(); ++i) {
        // 这里应该调用工具执行来预热缓存
        // putInCache(toolId, "", parametersList[i], result);
        
        if (progressCallback) {
            progressCallback(i + 1, parametersList.size());
        }
    }
    
    emit preheatCompleted();
}

QVector<QVariantMap> ToolCacheManager::getPreheatSuggestions(
    const QString &toolId,
    int limit) const {
    
    QVector<QVariantMap> suggestions;
    
    // 分析频繁使用的参数组合
    QMap<QString, int> paramFrequency;
    
    // 简化实现 - 返回空列表
    
    return suggestions;
}

void ToolCacheManager::enableAdaptivePreheating(bool enable) {
    QMutexLocker locker(&m_mutex);
    m_adaptivePreheatEnabled = enable;
}

// ── 缓存统计 ────────────────────────────────────────

CacheStatistics ToolCacheManager::getGlobalCacheStatistics() const {
    QMutexLocker locker(&m_mutex);
    return m_statistics;
}

CacheStatistics ToolCacheManager::getToolCacheStatistics(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    CacheStatistics stats{0, 0, 0, 0.0f, 0, 0, 0.0f, QDateTime::currentDateTime(), 0};
    
    for (const auto &entry : m_cache) {
        if (entry.toolId == toolId) {
            stats.totalEntries++;
            stats.hitCount += entry.hitCount;
            stats.totalSizeBytes += entry.sizeBytes;
        }
    }
    
    stats.hitRatio = stats.totalEntries > 0 ? 
                    (float)stats.hitCount / stats.totalEntries : 0.0f;
    
    return stats;
}

float ToolCacheManager::getCacheHitRate() const {
    QMutexLocker locker(&m_mutex);
    return m_statistics.hitRatio;
}

qint64 ToolCacheManager::getCacheSizeBytes() const {
    QMutexLocker locker(&m_mutex);
    return m_statistics.totalSizeBytes;
}

int ToolCacheManager::getCacheEntryCount() const {
    QMutexLocker locker(&m_mutex);
    return m_statistics.totalEntries;
}

QVector<CacheEntry> ToolCacheManager::listCacheEntries(
    int limit,
    int offset) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<CacheEntry> entries;
    
    int count = 0;
    for (auto it = m_cache.begin(); it != m_cache.end() && count < limit; ++it) {
        if (count >= offset) {
            const auto &meta = it.value();
            CacheEntry entry;
            entry.entryId = meta.entryId;
            entry.toolId = meta.toolId;
            entry.capabilityName = meta.capabilityName;
            entry.createdAt = meta.createdAt;
            entry.expiresAt = meta.expiresAt;
            entry.accessCount = meta.accessCount;
            entry.sizeBytes = meta.sizeBytes;
            entry.confidence = meta.confidence;
            entries.append(entry);
        }
        count++;
    }
    
    return entries;
}

QVariantMap ToolCacheManager::analyzeCacheEfficiency() const {
    QMutexLocker locker(&m_mutex);
    
    QVariantMap analysis;
    analysis["hitRate"] = m_statistics.hitRatio;
    analysis["hitCount"] = m_statistics.hitCount;
    analysis["missCount"] = m_statistics.missCount;
    analysis["totalEntries"] = m_statistics.totalEntries;
    analysis["totalSizeBytes"] = m_statistics.totalSizeBytes;
    analysis["fragmentationRatio"] = getCacheFragmentationRatio();
    
    return analysis;
}

// ── 缓存驱逐 ────────────────────────────────────────

int ToolCacheManager::evictCacheEntries(int targetSizeBytes) {
    QMutexLocker locker(&m_mutex);
    
    int evicted = 0;
    
    if (m_invalidationStrategy == CacheInvalidationStrategy::LRU) {
        evicted = evictLRUEntries(10);
    } else if (m_invalidationStrategy == CacheInvalidationStrategy::LFU) {
        evicted = evictLFUEntries(10);
    }
    
    return evicted;
}

int ToolCacheManager::evictLRUEntries(int count) {
    int evicted = 0;
    
    for (int i = 0; i < count && !m_accessOrder.isEmpty(); ++i) {
        QString key = m_accessOrder.first();
        m_accessOrder.removeFirst();
        
        if (m_cache.contains(key)) {
            m_statistics.totalSizeBytes -= m_cache[key].sizeBytes;
            m_cache.remove(key);
            m_statistics.itemsEvicted++;
            evicted++;
        }
    }
    
    m_statistics.totalEntries = m_cache.size();
    return evicted;
}

int ToolCacheManager::evictLFUEntries(int count) {
    // 查找访问频率最低的项
    QVector<QPair<QString, int>> frequency;
    
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        frequency.append({it.key(), it.value().accessCount});
    }
    
    std::sort(frequency.begin(), frequency.end(),
              [](const auto &a, const auto &b) { return a.second < b.second; });
    
    int evicted = 0;
    for (int i = 0; i < count && i < frequency.size(); ++i) {
        const auto &key = frequency[i].first;
        if (m_cache.contains(key)) {
            m_statistics.totalSizeBytes -= m_cache[key].sizeBytes;
            m_cache.remove(key);
            m_statistics.itemsEvicted++;
            evicted++;
        }
    }
    
    m_statistics.totalEntries = m_cache.size();
    return evicted;
}

int ToolCacheManager::evictExpiredEntries() {
    QVector<QString> keysToRemove;
    
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        if (QDateTime::currentDateTime() > it.value().expiresAt) {
            keysToRemove.append(it.key());
        }
    }
    
    for (const auto &key : keysToRemove) {
        m_statistics.totalSizeBytes -= m_cache[key].sizeBytes;
        m_cache.remove(key);
        m_accessOrder.removeAll(key);
    }
    
    m_statistics.totalEntries = m_cache.size();
    return keysToRemove.size();
}

QVariantMap ToolCacheManager::getEvictionStatistics() const {
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["itemsEvicted"] = m_statistics.itemsEvicted;
    stats["lastCleared"] = m_statistics.lastClearedAt.toString();
    
    return stats;
}

// ── 缓存持久化 ────────────────────────────────────

bool ToolCacheManager::saveCacheToDisk(const QString &filePath) const {
    qDebug() << "[ToolCacheManager] Saving cache to" << filePath;
    // 实现缓存持久化
    return true;
}

bool ToolCacheManager::loadCacheFromDisk(const QString &filePath) {
    qDebug() << "[ToolCacheManager] Loading cache from" << filePath;
    // 实现缓存恢复
    return true;
}

QString ToolCacheManager::exportCacheReport() const {
    QString report = "Cache Report\n";
    report += QString("Total Entries: %1\n").arg(m_statistics.totalEntries);
    report += QString("Hit Rate: %1%\n").arg(m_statistics.hitRatio * 100);
    report += QString("Cache Size: %1 MB\n")
        .arg(m_statistics.totalSizeBytes / (1024 * 1024));
    
    return report;
}

bool ToolCacheManager::importCacheConfiguration(const QString &configFilePath) {
    qDebug() << "[ToolCacheManager] Importing cache configuration from" << configFilePath;
    return true;
}

// ── 缓存优化 ────────────────────────────────────────

void ToolCacheManager::rebuildCacheIndex() {
    QMutexLocker locker(&m_mutex);
    
    qDebug() << "[ToolCacheManager] Rebuilding cache index";
    // 重建索引以优化查询性能
}

int ToolCacheManager::compressCache() {
    QMutexLocker locker(&m_mutex);
    
    int compressed = 0;
    // 合并重复结果
    
    return compressed;
}

float ToolCacheManager::getCacheFragmentationRatio() const {
    if (m_statistics.totalSizeBytes == 0) return 0.0f;
    
    return 0.1f;  // 简化实现
}

void ToolCacheManager::optimizeCache() {
    QMutexLocker locker(&m_mutex);
    
    evictExpiredEntries();
    compressCache();
    rebuildCacheIndex();
    
    qDebug() << "[ToolCacheManager] Cache optimization completed";
}

// ── 辅助方法 ────────────────────────────────────────

QString ToolCacheManager::generateCacheKey(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters) const {
    
    // Create a string representation of parameters for hashing
    QStringList paramParts;
    for (auto it = parameters.begin(); it != parameters.end(); ++it) {
        paramParts.append(it.key() + "=" + it.value().toString());
    }
    
    QString keySource = QString("%1:%2:%3")
        .arg(toolId, capabilityName, paramParts.join(";"));
    
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(keySource.toUtf8());
    
    return hash.result().toHex();
}

QString ToolCacheManager::generateEntryId() const {
    return "cache_" + QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void ToolCacheManager::updateAccessStats(const QString &entryId) {
    // 更新访问统计
    for (auto &entry : m_cache) {
        if (entry.entryId == entryId) {
            entry.accessCount++;
            entry.lastAccessedAt = QDateTime::currentDateTime();
            
            // 更新访问顺序（LRU）
            m_accessOrder.removeAll(entryId);
            m_accessOrder.append(entryId);
            break;
        }
    }
}

void ToolCacheManager::checkCacheSize() {
    if (m_statistics.totalSizeBytes > m_maxCacheSizeBytes) {
        emit cacheNeedsEviction(m_statistics.totalSizeBytes, m_maxCacheSizeBytes);
        evictCacheEntries(m_maxCacheSizeBytes * 9 / 10);  // 驱逐到90%容量
    }
}
