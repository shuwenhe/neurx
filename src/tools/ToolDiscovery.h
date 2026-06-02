#pragma once

#include "ToolSchemaTypes.h"
#include <QObject>
#include <memory>

/**
 * @class ToolDiscovery
 * @brief 智能工具发现系统
 * 
 * 功能：
 * - 工具发现和搜索
 * - 智能推荐
 * - 工具匹配
 * - 能力查询
 */
class ToolDiscovery : public QObject {
    Q_OBJECT
public:
    virtual ~ToolDiscovery() = default;
    
    // ── 基础搜索 ───────────────────────────────────────
    
    /// 搜索工具
    virtual void searchTools(const ToolDiscoveryQuery &query,
                            ToolDiscoveryCallback callback = nullptr) = 0;
    
    /// 获取工具详情
    virtual ToolSchema getTool(const QString &toolId) const = 0;
    
    /// 获取所有工具
    virtual QVector<ToolSchema> getAllTools() const = 0;
    
    /// 按分类浏览工具
    virtual QVector<ToolSchema> browseByCategory(const QString &category,
                                                int limit = 50,
                                                int offset = 0) const = 0;
    
    // ── 智能推荐 ───────────────────────────────────────
    
    /// 基于描述推荐工具
    virtual void recommendTools(const QString &description,
                               ToolDiscoveryCallback callback = nullptr) = 0;
    
    /// 推荐补充工具（配套工具）
    virtual QVector<ToolSchema> getComplementaryTools(const QString &toolId) const = 0;
    
    /// 推荐热门工具
    virtual QVector<ToolSchema> getPopularTools(int limit = 20) const = 0;
    
    /// 推荐新工具
    virtual QVector<ToolSchema> getNewTools(int limit = 20) const = 0;
    
    /// 推荐高评分工具
    virtual QVector<ToolSchema> getTopRatedTools(int limit = 20) const = 0;
    
    /// 基于用户偏好推荐
    virtual void recommendToolsForUser(const QString &userId,
                                       ToolDiscoveryCallback callback = nullptr) = 0;
    
    // ── 能力匹配 ───────────────────────────────────────
    
    /// 查找具有特定能力的工具
    virtual QVector<ToolSchema> findByCapability(const QString &capabilityName,
                                                int limit = 50) const = 0;
    
    /// 查找具有特定输入/输出的工具
    virtual QVector<ToolSchema> findByIO(const QStringList &inputs,
                                        const QStringList &outputs) const = 0;
    
    /// 查找可以链接的工具
    virtual QVector<ToolSchema> findCompatibleTools(const QString &toolId) const = 0;
    
    /// 验证能力链是否可行
    virtual bool canChain(const QStringList &toolIds) const = 0;
    
    // ── 高级搜索 ───────────────────────────────────────
    
    /// 高级搜索
    virtual void advancedSearch(const QVariantMap &filters,
                               ToolDiscoveryCallback callback = nullptr) = 0;
    
    /// 相似性搜索
    virtual QVector<ToolSchema> similarTools(const QString &toolId,
                                            int limit = 20) const = 0;
    
    /// 搜索工具链
    virtual QVector<QVector<ToolSchema>> searchToolChains(const QString &description,
                                                         int maxDepth = 3) const = 0;
    
    // ── 工具评价 ───────────────────────────────────────
    
    /// 获取工具评分
    virtual float getToolRating(const QString &toolId) const = 0;
    
    /// 获取工具评价
    virtual QVector<QVariantMap> getToolReviews(const QString &toolId,
                                               int limit = 50) const = 0;
    
    /// 提交工具评价
    virtual void submitReview(const QString &toolId,
                             float rating,
                             const QString &comment,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 获取工具下载量
    virtual int getDownloadCount(const QString &toolId) const = 0;
    
    /// 获取工具使用量
    virtual int getUsageCount(const QString &toolId) const = 0;
    
    // ── 工具可用性 ───────────────────────────────────────
    
    /// 检查工具是否可用
    virtual bool isToolAvailable(const QString &toolId) const = 0;
    
    /// 检查工具是否支持用户
    virtual bool isToolSupportedForUser(const QString &toolId,
                                       const QString &userId) const = 0;
    
    /// 获取工具状态
    virtual QVariantMap getToolStatus(const QString &toolId) const = 0;
    
    /// 获取工具健康状况
    virtual float getToolHealth(const QString &toolId) const = 0;
    
    // ── 工具统计 ───────────────────────────────────────
    
    /// 获取发现统计
    virtual QVariantMap getDiscoveryStatistics() const = 0;
    
    /// 获取搜索趋势
    virtual QVector<QPair<QString, int>> getSearchTrends(int limit = 10) const = 0;
    
    /// 获取热门能力
    virtual QVector<QString> getPopularCapabilities(int limit = 20) const = 0;
    
    /// 获取工具分类统计
    virtual QVariantMap getCategoryStatistics() const = 0;
    
    // ── 工具集合 ───────────────────────────────────────
    
    /// 创建工具集合
    virtual QString createCollection(const QString &name,
                                    const QString &description,
                                    const QStringList &toolIds,
                                    std::function<void(bool)> callback = nullptr) = 0;
    
    /// 获取工具集合
    virtual QVector<QString> getCollection(const QString &collectionId) const = 0;
    
    /// 列出所有集合
    virtual QVector<QVariantMap> listCollections() const = 0;
    
    /// 添加工具到集合
    virtual void addToCollection(const QString &collectionId,
                                const QString &toolId,
                                std::function<void(bool)> callback = nullptr) = 0;
    
    /// 从集合移除工具
    virtual void removeFromCollection(const QString &collectionId,
                                     const QString &toolId,
                                     std::function<void(bool)> callback = nullptr) = 0;

// ── 信号 ──────────────────────────────────────────────
signals:
    /// 工具被发现
    void toolDiscovered(const QString &toolId);
    
    /// 新工具已添加
    void toolAdded(const QString &toolId);
    
    /// 工具已更新
    void toolUpdated(const QString &toolId);
    
    /// 工具已移除
    void toolRemoved(const QString &toolId);
    
    /// 搜索完成
    void searchCompleted(int resultCount);
};

#endif // TOOLDISCOVERY_H
