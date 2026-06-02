#include "DefaultToolDiscovery.h"
#include <QUuid>
#include <QDebug>
#include <algorithm>

DefaultToolDiscovery::DefaultToolDiscovery(QObject *parent)
    : ToolDiscovery(parent) {
}

// ── 基础搜索 ────────────────────────────────────────

void DefaultToolDiscovery::searchTools(
    const ToolDiscoveryQuery &query,
    ToolDiscoveryCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    // 关键词搜索
    if (!query.keyword.isEmpty()) {
        recordSearch(query.keyword);
        QString keywordLower = query.keyword.toLower();
        
        for (const auto &tool : m_tools) {
            if (tool.schema.name.toLower().contains(keywordLower) ||
                tool.schema.description.toLower().contains(keywordLower) ||
                tool.schema.toolId.toLower().contains(keywordLower)) {
                results.append(tool.schema);
            }
        }
    } else {
        // 如果没有关键词，返回所有工具
        for (const auto &tool : m_tools) {
            results.append(tool.schema);
        }
    }
    
    // 按分类过滤
    if (!query.category.isEmpty()) {
        auto it = std::remove_if(results.begin(), results.end(),
            [&query](const ToolSchema &s) { return s.category != query.category; });
        results.erase(it, results.end());
    }
    
    // 按标签过滤
    if (!query.tags.isEmpty()) {
        auto it = std::remove_if(results.begin(), results.end(),
            [&query](const ToolSchema &s) {
                for (const auto &tag : query.tags) {
                    if (!s.tags.contains(tag)) return true;
                }
                return false;
            });
        results.erase(it, results.end());
    }
    
    // 按权限级别过滤
    auto it = std::remove_if(results.begin(), results.end(),
        [&query](const ToolSchema &s) {
            return static_cast<int>(s.minPermissionLevel) > static_cast<int>(query.minLevel);
        });
    results.erase(it, results.end());
    
    // 仅返回活跃工具
    if (query.onlyActive) {
        auto it = std::remove_if(results.begin(), results.end(),
            [this](const ToolSchema &s) { return !isToolAvailable(s.toolId); });
        results.erase(it, results.end());
    }
    
    // 排序
    if (query.sortByPopularity) {
        std::sort(results.begin(), results.end(),
            [this](const ToolSchema &a, const ToolSchema &b) {
                return m_tools[a.toolId].usageCount > m_tools[b.toolId].usageCount;
            });
    }
    
    // 分页
    int start = query.offset;
    int end = qMin(start + query.limit, results.size());
    if (start < results.size()) {
        results = QVector<ToolSchema>(results.begin() + start, results.begin() + end);
    }
    
    emit searchCompleted(results.size());
    
    if (callback) {
        callback(results);
    }
}

ToolSchema DefaultToolDiscovery::getTool(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_tools.contains(toolId)) {
        m_tools[toolId].usageCount++;
        return m_tools[toolId].schema;
    }
    
    return ToolSchema();
}

QVector<ToolSchema> DefaultToolDiscovery::getAllTools() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> allTools;
    
    for (const auto &tool : m_tools) {
        allTools.append(tool.schema);
    }
    
    return allTools;
}

QVector<ToolSchema> DefaultToolDiscovery::browseByCategory(
    const QString &category,
    int limit,
    int offset) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &tool : m_tools) {
        if (tool.schema.category == category) {
            results.append(tool.schema);
        }
    }
    
    // 应用分页
    int start = offset;
    int end = qMin(start + limit, results.size());
    if (start < results.size()) {
        return QVector<ToolSchema>(results.begin() + start, results.begin() + end);
    }
    
    return QVector<ToolSchema>();
}

// ── 智能推荐 ────────────────────────────────────────

void DefaultToolDiscovery::recommendTools(
    const QString &description,
    ToolDiscoveryCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> recommendations;
    
    // 提取关键词
    auto keywords = extractKeywords(description);
    
    QMap<QString, int> scores;
    
    for (const auto &tool : m_tools) {
        int score = 0;
        
        // 根据关键词匹配评分
        for (const auto &keyword : keywords) {
            if (tool.schema.name.toLower().contains(keyword) ||
                tool.schema.description.toLower().contains(keyword)) {
                score += 10;
            }
            
            for (const auto &tag : tool.schema.tags) {
                if (tag.toLower().contains(keyword)) {
                    score += 5;
                }
            }
        }
        
        // 根据评分加权
        score += tool.overallRating * 2;
        
        // 根据使用量加权
        score += tool.usageCount / 100;
        
        if (score > 0) {
            scores[tool.schema.toolId] = score;
        }
    }
    
    // 按评分排序
    QStringList sorted = scores.keys();
    std::sort(sorted.begin(), sorted.end(),
        [&scores](const QString &a, const QString &b) {
            return scores[a] > scores[b];
        });
    
    // 返回前N个
    for (int i = 0; i < qMin(10, sorted.size()); ++i) {
        if (m_tools.contains(sorted[i])) {
            recommendations.append(m_tools[sorted[i]].schema);
        }
    }
    
    if (callback) {
        callback(recommendations);
    }
}

QVector<ToolSchema> DefaultToolDiscovery::getComplementaryTools(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_tools.contains(toolId)) {
        return QVector<ToolSchema>();
    }
    
    const auto &tool = m_tools[toolId];
    QVector<ToolSchema> complementary;
    
    // 寻找具有相同能力但不同工具ID的工具
    for (const auto &capability : tool.schema.capabilities) {
        for (const auto &otherTool : m_tools) {
            if (otherTool.schema.toolId == toolId) continue;
            
            for (const auto &otherCap : otherTool.schema.capabilities) {
                if (otherCap.name == capability.name) {
                    complementary.append(otherTool.schema);
                    break;
                }
            }
        }
    }
    
    return complementary;
}

QVector<ToolSchema> DefaultToolDiscovery::getPopularTools(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> tools;
    
    for (const auto &tool : m_tools) {
        tools.append(tool.schema);
    }
    
    std::sort(tools.begin(), tools.end(),
        [this](const ToolSchema &a, const ToolSchema &b) {
            return m_tools[a.toolId].usageCount > m_tools[b.toolId].usageCount;
        });
    
    if (tools.size() > limit) {
        tools.resize(limit);
    }
    
    return tools;
}

QVector<ToolSchema> DefaultToolDiscovery::getNewTools(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> tools;
    
    for (const auto &tool : m_tools) {
        tools.append(tool.schema);
    }
    
    std::sort(tools.begin(), tools.end(),
        [this](const ToolSchema &a, const ToolSchema &b) {
            return m_tools[a.toolId].createdAt > m_tools[b.toolId].createdAt;
        });
    
    if (tools.size() > limit) {
        tools.resize(limit);
    }
    
    return tools;
}

QVector<ToolSchema> DefaultToolDiscovery::getTopRatedTools(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> tools;
    
    for (const auto &tool : m_tools) {
        tools.append(tool.schema);
    }
    
    std::sort(tools.begin(), tools.end(),
        [this](const ToolSchema &a, const ToolSchema &b) {
            return m_tools[a.toolId].overallRating > m_tools[b.toolId].overallRating;
        });
    
    if (tools.size() > limit) {
        tools.resize(limit);
    }
    
    return tools;
}

void DefaultToolDiscovery::recommendToolsForUser(
    const QString &userId,
    ToolDiscoveryCallback callback) {
    
    // 简单的基于用户历史的推荐
    // 实际应用中可以使用更复杂的算法
    recommendTools(QString("User %1 interested tools").arg(userId), callback);
}

// ── 能力匹配 ────────────────────────────────────────

QVector<ToolSchema> DefaultToolDiscovery::findByCapability(
    const QString &capabilityName,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &tool : m_tools) {
        for (const auto &cap : tool.schema.capabilities) {
            if (cap.name == capabilityName) {
                results.append(tool.schema);
                break;
            }
        }
        
        if (results.size() >= limit) break;
    }
    
    return results;
}

QVector<ToolSchema> DefaultToolDiscovery::findByIO(
    const QStringList &inputs,
    const QStringList &outputs) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &tool : m_tools) {
        bool matches = true;
        
        // 检查所有输入参数
        for (const auto &input : inputs) {
            bool found = false;
            for (const auto &cap : tool.schema.capabilities) {
                if (cap.inputParams.contains(input)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                matches = false;
                break;
            }
        }
        
        if (!matches) continue;
        
        // 检查所有输出参数
        for (const auto &output : outputs) {
            bool found = false;
            for (const auto &cap : tool.schema.capabilities) {
                if (cap.outputParams.contains(output)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                matches = false;
                break;
            }
        }
        
        if (matches) {
            results.append(tool.schema);
        }
    }
    
    return results;
}

QVector<ToolSchema> DefaultToolDiscovery::findCompatibleTools(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_tools.contains(toolId)) {
        return QVector<ToolSchema>();
    }
    
    const auto &tool = m_tools[toolId];
    QVector<ToolSchema> compatible;
    
    // 提取工具的所有输出
    QStringList outputs;
    for (const auto &cap : tool.schema.capabilities) {
        outputs.append(cap.outputParams);
    }
    
    // 寻找能接受这些输出的工具
    for (const auto &otherTool : m_tools) {
        if (otherTool.schema.toolId == toolId) continue;
        
        for (const auto &cap : otherTool.schema.capabilities) {
            for (const auto &input : cap.inputParams) {
                if (outputs.contains(input)) {
                    compatible.append(otherTool.schema);
                    goto next_tool;
                }
            }
        }
        next_tool:;
    }
    
    return compatible;
}

bool DefaultToolDiscovery::canChain(const QStringList &toolIds) const {
    
    if (toolIds.size() < 2) return true;
    
    QMutexLocker locker(&m_mutex);
    
    for (int i = 0; i < toolIds.size() - 1; ++i) {
        const auto &currentId = toolIds[i];
        const auto &nextId = toolIds[i + 1];
        
        if (!m_tools.contains(currentId) || !m_tools.contains(nextId)) {
            return false;
        }
        
        auto compatible = findCompatibleTools(currentId);
        bool found = false;
        for (const auto &tool : compatible) {
            if (tool.toolId == nextId) {
                found = true;
                break;
            }
        }
        
        if (!found) return false;
    }
    
    return true;
}

// ── 高级搜索 ────────────────────────────────────────

void DefaultToolDiscovery::advancedSearch(
    const QVariantMap &filters,
    ToolDiscoveryCallback callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &tool : m_tools) {
        bool matches = true;
        
        // 应用所有过滤条件
        if (filters.contains("category") &&
            tool.schema.category != filters["category"].toString()) {
            matches = false;
        }
        
        if (filters.contains("minRating") &&
            tool.overallRating < filters["minRating"].toFloat()) {
            matches = false;
        }
        
        if (filters.contains("minUsage") &&
            tool.usageCount < filters["minUsage"].toInt()) {
            matches = false;
        }
        
        if (matches) {
            results.append(tool.schema);
        }
    }
    
    if (callback) {
        callback(results);
    }
}

QVector<ToolSchema> DefaultToolDiscovery::similarTools(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_tools.contains(toolId)) {
        return QVector<ToolSchema>();
    }
    
    const auto &baseTool = m_tools[toolId];
    QMap<QString, float> similarities;
    
    for (const auto &tool : m_tools) {
        if (tool.schema.toolId == toolId) continue;
        
        float sim = calculateSimilarity(baseTool.schema, tool.schema);
        if (sim > 0) {
            similarities[tool.schema.toolId] = sim;
        }
    }
    
    // 按相似度排序
    QStringList sorted = similarities.keys();
    std::sort(sorted.begin(), sorted.end(),
        [&similarities](const QString &a, const QString &b) {
            return similarities[a] > similarities[b];
        });
    
    QVector<ToolSchema> results;
    for (int i = 0; i < qMin(limit, sorted.size()); ++i) {
        if (m_tools.contains(sorted[i])) {
            results.append(m_tools[sorted[i]].schema);
        }
    }
    
    return results;
}

QVector<QVector<ToolSchema>> DefaultToolDiscovery::searchToolChains(
    const QString &description,
    int maxDepth) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVector<ToolSchema>> chains;
    
    // 找到初始工具
    ToolDiscoveryQuery query;
    query.keyword = description;
    
    // 简单实现：返回一个可能的链
    QVector<ToolSchema> baseTools;
    for (const auto &tool : m_tools) {
        if (tool.schema.description.contains(description)) {
            baseTools.append(tool.schema);
            if (baseTools.size() >= 3) break;
        }
    }
    
    if (!baseTools.isEmpty()) {
        chains.append(baseTools);
    }
    
    return chains;
}

// ── 工具评价 ────────────────────────────────────────

float DefaultToolDiscovery::getToolRating(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_tools.contains(toolId)) {
        return m_tools[toolId].overallRating;
    }
    
    return 0.0f;
}

QVector<QVariantMap> DefaultToolDiscovery::getToolReviews(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> reviews;
    
    if (m_tools.contains(toolId)) {
        const auto &tool = m_tools[toolId];
        
        for (int i = 0; i < qMin(limit, tool.reviews.size()); ++i) {
            QVariantMap review;
            review["userId"] = tool.reviews[i].userId;
            review["rating"] = tool.reviews[i].rating;
            review["comment"] = tool.reviews[i].comment;
            review["createdAt"] = tool.reviews[i].createdAt.toString();
            reviews.append(review);
        }
    }
    
    return reviews;
}

void DefaultToolDiscovery::submitReview(
    const QString &toolId,
    float rating,
    const QString &comment,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_tools.contains(toolId)) {
        if (callback) callback(false);
        return;
    }
    
    ToolReview review;
    review.userId = QUuid::createUuid().toString();
    review.rating = qBound(0.0f, rating, 5.0f);
    review.comment = comment;
    review.createdAt = QDateTime::currentDateTime();
    
    m_tools[toolId].reviews.append(review);
    
    // 更新总评分
    float totalRating = 0.0f;
    for (const auto &r : m_tools[toolId].reviews) {
        totalRating += r.rating;
    }
    m_tools[toolId].overallRating = totalRating / m_tools[toolId].reviews.size();
    
    if (callback) callback(true);
}

int DefaultToolDiscovery::getDownloadCount(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_tools.contains(toolId)) {
        return m_tools[toolId].downloadCount;
    }
    
    return 0;
}

int DefaultToolDiscovery::getUsageCount(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_tools.contains(toolId)) {
        return m_tools[toolId].usageCount;
    }
    
    return 0;
}

// ── 工具可用性 ───────────────────────────────────────

bool DefaultToolDiscovery::isToolAvailable(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    return m_tools.contains(toolId);
}

bool DefaultToolDiscovery::isToolSupportedForUser(
    const QString &toolId,
    const QString &userId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_tools.contains(toolId)) {
        return false;
    }
    
    // 简单检查：只要用户ID不为空就支持
    return !userId.isEmpty();
}

QVariantMap DefaultToolDiscovery::getToolStatus(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap status;
    
    if (m_tools.contains(toolId)) {
        const auto &tool = m_tools[toolId];
        status["available"] = true;
        status["rating"] = tool.overallRating;
        status["usageCount"] = tool.usageCount;
        status["downloadCount"] = tool.downloadCount;
        status["lastUpdated"] = tool.lastUpdated.toString();
    } else {
        status["available"] = false;
    }
    
    return status;
}

float DefaultToolDiscovery::getToolHealth(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_tools.contains(toolId)) {
        return 0.0f;
    }
    
    const auto &tool = m_tools[toolId];
    
    // 健康度 = 评分(40%) + 使用量(40%) + 更新时间(20%)
    float ratingHealth = tool.overallRating * 0.4f;
    float usageHealth = qMin(1.0f, tool.usageCount / 1000.0f) * 0.4f;
    
    // 检查更新时间
    int daysSinceUpdate = tool.lastUpdated.daysTo(QDateTime::currentDateTime());
    float updateHealth = (daysSinceUpdate < 30) ? 0.2f : 0.1f;
    
    return ratingHealth + usageHealth + updateHealth;
}

// ── 工具统计 ────────────────────────────────────────

QVariantMap DefaultToolDiscovery::getDiscoveryStatistics() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalTools"] = m_tools.size();
    stats["totalSearches"] = 0;
    stats["totalReviews"] = 0;
    
    int totalReviews = 0;
    for (const auto &tool : m_tools) {
        totalReviews += tool.reviews.size();
    }
    stats["totalReviews"] = totalReviews;
    
    for (const auto &count : m_searchTrends) {
        stats["totalSearches"] = stats["totalSearches"].toInt() + count;
    }
    
    return stats;
}

QVector<QPair<QString, int>> DefaultToolDiscovery::getSearchTrends(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QPair<QString, int>> trends;
    
    for (auto it = m_searchTrends.begin(); it != m_searchTrends.end(); ++it) {
        trends.append({it.key(), it.value()});
    }
    
    std::sort(trends.begin(), trends.end(),
        [](const QPair<QString, int> &a, const QPair<QString, int> &b) {
            return a.second > b.second;
        });
    
    if (trends.size() > limit) {
        trends.resize(limit);
    }
    
    return trends;
}

QVector<QString> DefaultToolDiscovery::getPopularCapabilities(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QMap<QString, int> capCount;
    
    for (const auto &tool : m_tools) {
        for (const auto &cap : tool.schema.capabilities) {
            capCount[cap.name]++;
        }
    }
    
    QStringList caps = capCount.keys();
    std::sort(caps.begin(), caps.end(),
        [&capCount](const QString &a, const QString &b) {
            return capCount[a] > capCount[b];
        });
    
    if (caps.size() > limit) {
        caps.resize(limit);
    }
    
    return QVector<QString>(caps.begin(), caps.end());
}

QVariantMap DefaultToolDiscovery::getCategoryStatistics() const {
    
    QMutexLocker locker(&m_mutex);
    
    QMap<QString, int> categoryCounts;
    
    for (const auto &tool : m_tools) {
        categoryCounts[tool.schema.category]++;
    }
    
    QVariantMap stats;
    for (auto it = categoryCounts.begin(); it != categoryCounts.end(); ++it) {
        stats[it.key()] = it.value();
    }
    
    return stats;
}

// ── 工具集合 ────────────────────────────────────────

QString DefaultToolDiscovery::createCollection(
    const QString &name,
    const QString &description,
    const QStringList &toolIds,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    Collection collection;
    collection.collectionId = QUuid::createUuid().toString();
    collection.name = name;
    collection.description = description;
    collection.toolIds = QVector<QString>(toolIds.begin(), toolIds.end());
    collection.createdAt = QDateTime::currentDateTime();
    
    m_collections[collection.collectionId] = collection;
    
    if (callback) callback(true);
    
    return collection.collectionId;
}

QVector<QString> DefaultToolDiscovery::getCollection(
    const QString &collectionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_collections.contains(collectionId)) {
        return m_collections[collectionId].toolIds;
    }
    
    return QVector<QString>();
}

QVector<QVariantMap> DefaultToolDiscovery::listCollections() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> list;
    
    for (const auto &collection : m_collections) {
        QVariantMap item;
        item["collectionId"] = collection.collectionId;
        item["name"] = collection.name;
        item["description"] = collection.description;
        item["toolCount"] = collection.toolIds.size();
        item["createdAt"] = collection.createdAt.toString();
        list.append(item);
    }
    
    return list;
}

void DefaultToolDiscovery::addToCollection(
    const QString &collectionId,
    const QString &toolId,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_collections.contains(collectionId)) {
        auto &collection = m_collections[collectionId];
        if (!collection.toolIds.contains(toolId)) {
            collection.toolIds.append(toolId);
        }
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultToolDiscovery::removeFromCollection(
    const QString &collectionId,
    const QString &toolId,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_collections.contains(collectionId)) {
        auto &collection = m_collections[collectionId];
        int removed = collection.toolIds.removeAll(toolId);
        if (callback) callback(removed > 0);
    } else {
        if (callback) callback(false);
    }
}

// ── 辅助方法 ────────────────────────────────────────

void DefaultToolDiscovery::recordSearch(const QString &keyword) {
    
    m_searchTrends[keyword.toLower()]++;
}

float DefaultToolDiscovery::calculateSimilarity(
    const ToolSchema &tool1,
    const ToolSchema &tool2) const {
    
    float similarity = 0.0f;
    
    // 分类匹配
    if (tool1.category == tool2.category) {
        similarity += 0.3f;
    }
    
    // 标签匹配
    int commonTags = 0;
    for (const auto &tag : tool1.tags) {
        if (tool2.tags.contains(tag)) {
            commonTags++;
        }
    }
    similarity += (commonTags / float(qMax(tool1.tags.size(), 1)) * 0.3f);
    
    // 能力匹配
    int commonCapabilities = 0;
    for (const auto &cap1 : tool1.capabilities) {
        for (const auto &cap2 : tool2.capabilities) {
            if (cap1.name == cap2.name) {
                commonCapabilities++;
                break;
            }
        }
    }
    similarity += (commonCapabilities / float(qMax(tool1.capabilities.size(), 1)) * 0.4f);
    
    return qBound(0.0f, similarity, 1.0f);
}

QVector<QString> DefaultToolDiscovery::extractKeywords(const QString &text) const {
    
    QVector<QString> keywords;
    
    // 简单实现：按空格分割
    QStringList words = text.split(" ", Qt::SkipEmptyParts);
    
    for (const auto &word : words) {
        QString cleaned = word.toLower();
        // 移除标点符号
        cleaned.replace(QRegExp("[^a-z0-9_]"), "");
        
        if (cleaned.length() > 2) {  // 忽略太短的词
            keywords.append(cleaned);
        }
    }
    
    return keywords;
}
