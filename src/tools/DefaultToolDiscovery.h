#pragma once

#include "ToolDiscovery.h"
#include <QMap>
#include <QSet>
#include <QMutex>

/**
 * @class DefaultToolDiscovery
 * @brief 工具发现系统默认实现
 * 
 * 功能：
 * - 工具搜索和浏览
 * - 智能推荐
 * - 能力匹配
 * - 评价系统
 */
class DefaultToolDiscovery : public ToolDiscovery {
    Q_OBJECT
public:
    explicit DefaultToolDiscovery(QObject *parent = nullptr);
    ~DefaultToolDiscovery() = default;
    
    // ── 基础搜索 ───────────────────────────────────────
    void searchTools(const ToolDiscoveryQuery &query,
                    ToolDiscoveryCallback callback = nullptr) override;
    
    ToolSchema getTool(const QString &toolId) const override;
    
    QVector<ToolSchema> getAllTools() const override;
    
    QVector<ToolSchema> browseByCategory(const QString &category,
                                        int limit = 50,
                                        int offset = 0) const override;
    
    // ── 智能推荐 ───────────────────────────────────────
    void recommendTools(const QString &description,
                       ToolDiscoveryCallback callback = nullptr) override;
    
    QVector<ToolSchema> getComplementaryTools(const QString &toolId) const override;
    
    QVector<ToolSchema> getPopularTools(int limit = 20) const override;
    
    QVector<ToolSchema> getNewTools(int limit = 20) const override;
    
    QVector<ToolSchema> getTopRatedTools(int limit = 20) const override;
    
    void recommendToolsForUser(const QString &userId,
                              ToolDiscoveryCallback callback = nullptr) override;
    
    // ── 能力匹配 ───────────────────────────────────────
    QVector<ToolSchema> findByCapability(const QString &capabilityName,
                                        int limit = 50) const override;
    
    QVector<ToolSchema> findByIO(const QStringList &inputs,
                                const QStringList &outputs) const override;
    
    QVector<ToolSchema> findCompatibleTools(const QString &toolId) const override;
    
    bool canChain(const QStringList &toolIds) const override;
    
    // ── 高级搜索 ───────────────────────────────────────
    void advancedSearch(const QVariantMap &filters,
                       ToolDiscoveryCallback callback = nullptr) override;
    
    QVector<ToolSchema> similarTools(const QString &toolId,
                                    int limit = 20) const override;
    
    QVector<QVector<ToolSchema>> searchToolChains(const QString &description,
                                                 int maxDepth = 3) const override;
    
    // ── 工具评价 ───────────────────────────────────────
    float getToolRating(const QString &toolId) const override;
    
    QVector<QVariantMap> getToolReviews(const QString &toolId,
                                       int limit = 50) const override;
    
    void submitReview(const QString &toolId,
                     float rating,
                     const QString &comment,
                     std::function<void(bool success)> callback = nullptr) override;
    
    int getDownloadCount(const QString &toolId) const override;
    
    int getUsageCount(const QString &toolId) const override;
    
    // ── 工具可用性 ───────────────────────────────────────
    bool isToolAvailable(const QString &toolId) const override;
    
    bool isToolSupportedForUser(const QString &toolId,
                               const QString &userId) const override;
    
    QVariantMap getToolStatus(const QString &toolId) const override;
    
    float getToolHealth(const QString &toolId) const override;
    
    // ── 工具统计 ───────────────────────────────────────
    QVariantMap getDiscoveryStatistics() const override;
    
    QVector<QPair<QString, int>> getSearchTrends(int limit = 10) const override;
    
    QVector<QString> getPopularCapabilities(int limit = 20) const override;
    
    QVariantMap getCategoryStatistics() const override;
    
    // ── 工具集合 ───────────────────────────────────────
    QString createCollection(const QString &name,
                            const QString &description,
                            const QStringList &toolIds,
                            std::function<void(bool)> callback = nullptr) override;
    
    QVector<QString> getCollection(const QString &collectionId) const override;
    
    QVector<QVariantMap> listCollections() const override;
    
    void addToCollection(const QString &collectionId,
                        const QString &toolId,
                        std::function<void(bool)> callback = nullptr) override;
    
    void removeFromCollection(const QString &collectionId,
                             const QString &toolId,
                             std::function<void(bool)> callback = nullptr) override;

private:
    struct ToolReview {
        QString userId;
        float rating;
        QString comment;
        QDateTime createdAt;
    };
    
    struct ToolMetadata {
        ToolSchema schema;
        QVector<ToolReview> reviews;
        int downloadCount;
        int usageCount;
        QDateTime createdAt;
        QDateTime lastUpdated;
        float overallRating;
    };
    
    struct Collection {
        QString collectionId;
        QString name;
        QString description;
        QVector<QString> toolIds;
        QDateTime createdAt;
    };
    
    // 存储
    QMap<QString, ToolMetadata> m_tools;
    QMap<QString, Collection> m_collections;
    QMap<QString, int> m_searchTrends;  // keyword -> count
    
    mutable QMutex m_mutex;
    
    // 辅助方法
    void recordSearch(const QString &keyword);
    
    float calculateSimilarity(const ToolSchema &tool1,
                             const ToolSchema &tool2) const;
    
    QVector<QString> extractKeywords(const QString &text) const;
};

#endif // DEFAULTTOOLDISCOVERY_H
