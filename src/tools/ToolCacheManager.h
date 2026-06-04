#pragma once

#include <QObject>
#include <QMap>
#include <QVector>
#include <QMutex>
#include <QDateTime>
#include "ToolSchemaTypes.h"

/**
 * @class ToolCacheManager
 * @brief 工具执行缓存管理器 - 提供智能缓存、失效策略和统计
 * 
 * 功能：
 * - 多层缓存策略（内存、磁盘）
 * - 智能缓存失效（TTL、LRU、LFU）
 * - 缓存预热和预测
 * - 缓存统计和性能分析
 * - 缓存持久化和恢复
 */
class ToolCacheManager : public QObject {
    Q_OBJECT

public:
    explicit ToolCacheManager(QObject *parent = nullptr);
    ~ToolCacheManager() = default;

    // ── 缓存操作 ────────────────────────────────────────

    /// 从缓存获取结果
    bool getFromCache(const QString &toolId,
                     const QString &capabilityName,
                     const QVariantMap &parameters,
                     QVariantMap &result,
                     float &confidence) const;

    /// 存储到缓存
    void putInCache(const QString &toolId,
                   const QString &capabilityName,
                   const QVariantMap &parameters,
                   const QVariantMap &result,
                   int timeoutSeconds = 3600,
                   float confidence = 1.0f);

    /// 失效缓存项
    void invalidateCacheEntry(const QString &entryId);

    /// 失效工具的所有缓存
    void invalidateToolCache(const QString &toolId);

    /// 失效特定能力的缓存
    void invalidateCapabilityCache(const QString &toolId,
                                   const QString &capabilityName);

    /// 清空所有缓存
    void clearAllCache();

    /// 检查缓存是否存在
    bool cacheExists(const QString &toolId,
                    const QString &capabilityName,
                    const QVariantMap &parameters) const;

    // ── 缓存配置 ────────────────────────────────────────

    /// 启用/禁用缓存
    void enableCache(bool enable);

    /// 设置缓存大小限制
    void setMaxCacheSize(int sizeBytes);

    /// 设置缓存失效策略
    void setCacheInvalidationStrategy(CacheInvalidationStrategy strategy);

    /// 设置缓存TTL
    void setCacheDefaultTTL(int seconds);

    /// 设置缓存置信度阈值
    void setCacheConfidenceThreshold(float threshold);

    /// 启用磁盘缓存
    void enableDiskCache(bool enable);

    /// 设置磁盘缓存路径
    void setDiskCachePath(const QString &path);

    // ── 缓存预热 ────────────────────────────────────────

    /// 预热缓存 - 预加载常用结果
    void warmupCache(const QString &toolId,
                    const QVector<QVariantMap> &parametersList,
                    std::function<void(int completed, int total)> progressCallback = nullptr);

    /// 获取缓存预热建议
    QVector<QVariantMap> getPreheatSuggestions(const QString &toolId,
                                              int limit = 10) const;

    /// 设置自适应预热
    void enableAdaptivePreheating(bool enable);

    // ── 缓存统计 ────────────────────────────────────────

    /// 获取全局缓存统计
    CacheStatistics getGlobalCacheStatistics() const;

    /// 获取工具级缓存统计
    CacheStatistics getToolCacheStatistics(const QString &toolId) const;

    /// 获取缓存命中率
    float getCacheHitRate() const;

    /// 获取缓存大小
    qint64 getCacheSizeBytes() const;

    /// 获取缓存项数量
    int getCacheEntryCount() const;

    /// 获取缓存条目列表
    QVector<CacheEntry> listCacheEntries(int limit = 100, int offset = 0) const;

    /// 分析缓存效率
    QVariantMap analyzeCacheEfficiency() const;

    // ── 缓存驱逐 ────────────────────────────────────────

    /// 执行缓存驱逐 - 根据策略移除项
    int evictCacheEntries(int targetSizeBytes);

    /// 手动驱逐LRU项
    int evictLRUEntries(int count);

    /// 手动驱逐LFU项
    int evictLFUEntries(int count);

    /// 驱逐过期项
    int evictExpiredEntries();

    /// 获取驱逐统计
    QVariantMap getEvictionStatistics() const;

    // ── 缓存持久化 ────────────────────────────────────

    /// 保存缓存到磁盘
    bool saveCacheToDisk(const QString &filePath) const;

    /// 从磁盘加载缓存
    bool loadCacheFromDisk(const QString &filePath);

    /// 导出缓存报告
    QString exportCacheReport() const;

    /// 导入缓存配置
    bool importCacheConfiguration(const QString &configFilePath);

    // ── 缓存优化 ────────────────────────────────────────

    /// 重建缓存索引 - 优化查询性能
    void rebuildCacheIndex();

    /// 压缩缓存 - 合并相同结果
    int compressCache();

    /// 获取缓存碎片率
    float getCacheFragmentationRatio() const;

    /// 优化缓存 - 自动驱逐和压缩
    void optimizeCache();

signals:
    /// 缓存命中
    void cacheHit(const QString &toolId, const QString &capabilityName);

    /// 缓存失效
    void cacheMiss(const QString &toolId, const QString &capabilityName);

    /// 缓存项失效
    void cacheItemInvalidated(const QString &entryId);

    /// 缓存已满，需要驱逐
    void cacheNeedsEviction(qint64 currentSize, qint64 maxSize);

    /// 缓存统计更新
    void cacheStatisticsUpdated(const CacheStatistics &stats);

    /// 缓存预热进度
    void preheatProgress(int completed, int total);

    /// 缓存预热完成
    void preheatCompleted();

private:
    struct CacheMetadata {
        QString entryId;
        QString toolId;
        QString capabilityName;
        QVariantMap parameters;
        QVariantMap result;
        QDateTime createdAt;
        QDateTime expiresAt;
        int accessCount = 0;
        int hitCount = 0;
        QDateTime lastAccessedAt;
        int sizeBytes = 0;
        float confidence = 1.0f;
        bool isDirty = false;
    };

    QMap<QString, CacheMetadata> m_cache;
    QVector<QString> m_accessOrder;  // 用于LRU
    
    mutable CacheStatistics m_statistics;
    CacheInvalidationStrategy m_invalidationStrategy;

    bool m_cacheEnabled = true;
    int m_maxCacheSizeBytes = 104857600;  // 100MB
    int m_defaultTTLSeconds = 3600;
    float m_confidenceThreshold = 0.8f;

    bool m_diskCacheEnabled = false;
    QString m_diskCachePath;
    bool m_adaptivePreheatEnabled = false;

    mutable QMutex m_mutex;

    // 辅助方法
    QString generateCacheKey(const QString &toolId,
                            const QString &capabilityName,
                            const QVariantMap &parameters) const;
    QString generateEntryId() const;
    void updateAccessStats(const QString &entryId);
    void checkCacheSize();
};
