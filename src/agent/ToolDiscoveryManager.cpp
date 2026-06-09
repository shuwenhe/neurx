#include "agent/ToolDiscoveryManager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QCoreApplication>
#include <QStandardPaths>
#include <algorithm>
#include <QMutex>

ToolDiscoveryManager::ToolDiscoveryManager(QObject *parent)
    : QObject(parent)
{
}

ToolDiscoveryManager::~ToolDiscoveryManager() = default;

int ToolDiscoveryManager::discoverAllTools()
{
    m_context.tools.clear();
    m_context.cacheValid = false;

    // Scan standard tool locations
    QStringList searchPaths{
        QCoreApplication::applicationDirPath() + "/tools",
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/tools",
        QDir::homePath() + "/.neurx-code/tools"
    };

    int count = 0;
    for (const auto &path : searchPaths) {
        count += discoverFromDirectory(path);
    }

    _buildCaches();
    emit discoveryComplete(count);
    return count;
}

int ToolDiscoveryManager::discoverFromDirectory(const QString &directory)
{
    QDir dir(directory);
    if (!dir.exists()) {
        return 0;
    }

    int discovered = 0;
    auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);

    for (const auto &entry : entries) {
        if (entry.isDir()) {
            // Recursively search subdirectories
            discovered += discoverFromDirectory(entry.absoluteFilePath());
        } else if (entry.suffix() == "json") {
            // Load tool definition from JSON
            QFile file(entry.absoluteFilePath());
            if (!file.open(QIODevice::ReadOnly)) {
                continue;
            }

            QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            file.close();

            if (doc.isObject()) {
                QJsonObject obj = doc.object();
                ToolMetadata metadata;
                metadata.id = obj["id"].toString();
                metadata.name = obj["name"].toString();
                metadata.description = obj["description"].toString();
                metadata.category = obj["category"].toString();
                metadata.version = obj["version"].toString("1.0");
                metadata.schema = obj["schema"].toObject();
                metadata.priority = obj["priority"].toInt(50);
                metadata.enabled = obj["enabled"].toBool(true);
                metadata.estimatedExecutionTime = obj["estimatedTime"].toInt(-1);

                auto capsArray = obj["capabilities"].toArray();
                for (const auto &cap : capsArray) {
                    metadata.capabilities.append(cap.toString());
                }

                auto aliasArray = obj["aliases"].toArray();
                for (const auto &alias : aliasArray) {
                    metadata.aliases.append(alias.toString());
                }

                auto depsArray = obj["dependencies"].toArray();
                for (const auto &dep : depsArray) {
                    metadata.dependencies.append(dep.toString());
                }

                if (!metadata.id.isEmpty()) {
                    m_context.tools[metadata.id] = metadata;
                    for (const auto &alias : metadata.aliases) {
                        m_context.aliasMap[alias] = metadata.id;
                    }
                    emit toolDiscovered(metadata.id);
                    discovered++;
                }
            }
        }
    }

    return discovered;
}

bool ToolDiscoveryManager::registerTool(const ToolMetadata &metadata)
{
    if (metadata.id.isEmpty()) {
        return false;
    }

    m_context.tools[metadata.id] = metadata;

    for (const auto &alias : metadata.aliases) {
        m_context.aliasMap[alias] = metadata.id;
    }

    m_context.cacheValid = false;
    _buildCaches();

    emit toolRegistered(metadata.id);
    return true;
}

bool ToolDiscoveryManager::unregisterTool(const QString &toolId)
{
    auto it = m_context.tools.find(toolId);
    if (it == m_context.tools.end()) {
        return false;
    }

    const auto &metadata = it.value();
    for (const auto &alias : metadata.aliases) {
        m_context.aliasMap.remove(alias);
    }

    m_context.tools.erase(it);
    m_context.cacheValid = false;

    emit toolUnregistered(toolId);
    return true;
}

int ToolDiscoveryManager::refreshTools(const QString &toolId)
{
    if (toolId.isEmpty()) {
        return discoverAllTools();
    } else {
        // Refresh single tool
        auto it = m_context.tools.find(toolId);
        if (it != m_context.tools.end()) {
            it.value().usageCount = m_usageStats[toolId];
            return 1;
        }
    }
    return 0;
}

QStringList ToolDiscoveryManager::findToolsByCapability(const QString &capability) const
{
    if (!m_context.cacheValid) {
        const_cast<ToolDiscoveryManager *>(this)->_buildCaches();
    }

    return m_context.capabilityMap.value(capability, {});
}

QStringList ToolDiscoveryManager::findToolsByCategory(const QString &category)
{
    if (!m_context.cacheValid) {
        _buildCaches();
    }

    return m_context.categoryMap.value(category, {});
}

QStringList ToolDiscoveryManager::findToolsBySearch(const QString &searchText, bool includeDescription)
{
    QStringList results;
    QString lower = searchText.toLower();

    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        const auto &meta = it.value();

        if (meta.name.toLower().contains(lower) ||
            meta.id.toLower().contains(lower) ||
            (includeDescription && meta.description.toLower().contains(lower))) {
            results.append(meta.id);
        }
    }

    return results;
}

QStringList ToolDiscoveryManager::findToolsByFilter(const DiscoveryFilter &filter)
{
    QStringList results;

    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        const auto &meta = it.value();

        // Check enabled
        if (filter.enabledOnly && !meta.enabled) {
            continue;
        }

        // Check priority
        if (meta.priority < filter.minPriority) {
            continue;
        }

        // Check excluded IDs
        if (filter.excludeIds.contains(meta.id)) {
            continue;
        }

        // Check categories
        if (!filter.categories.isEmpty() && !filter.categories.contains(meta.category)) {
            continue;
        }

        // Check capabilities
        bool hasAllCaps = true;
        for (const auto &cap : filter.capabilities) {
            if (!meta.capabilities.contains(cap)) {
                hasAllCaps = false;
                break;
            }
        }
        if (!hasAllCaps) {
            continue;
        }

        // Check search text
        if (!filter.searchText.isEmpty()) {
            QString lower = filter.searchText.toLower();
            if (!meta.name.toLower().contains(lower) &&
                !meta.id.toLower().contains(lower) &&
                !meta.description.toLower().contains(lower)) {
                continue;
            }
        }

        results.append(meta.id);
    }

    return results;
}

bool ToolDiscoveryManager::hasTool(const QString &toolId) const
{
    return m_context.tools.contains(toolId);
}

const ToolDiscoveryManager::ToolMetadata *ToolDiscoveryManager::getToolInfo(const QString &toolId) const
{
    auto it = m_context.tools.find(toolId);
    if (it != m_context.tools.end()) {
        return &it.value();
    }
    return nullptr;
}

const ToolDiscoveryManager::ToolMetadata *ToolDiscoveryManager::getToolByAlias(const QString &alias) const
{
    auto it = m_context.aliasMap.find(alias);
    if (it != m_context.aliasMap.end()) {
        return getToolInfo(it.value());
    }
    return nullptr;
}

QStringList ToolDiscoveryManager::getAllCapabilities() const
{
    if (!m_context.cacheValid) {
        const_cast<ToolDiscoveryManager *>(this)->_buildCaches();
    }

    QStringList result;
    for (auto it = m_context.capabilityMap.begin(); it != m_context.capabilityMap.end(); ++it) {
        result.append(it.key());
    }
    return result;
}

QStringList ToolDiscoveryManager::getAllCategories() const
{
    if (!m_context.cacheValid) {
        const_cast<ToolDiscoveryManager *>(this)->_buildCaches();
    }

    QStringList result;
    for (auto it = m_context.categoryMap.begin(); it != m_context.categoryMap.end(); ++it) {
        result.append(it.key());
    }
    return result;
}

bool ToolDiscoveryManager::hasCapability(const QString &toolId, const QString &capability) const
{
    auto info = getToolInfo(toolId);
    return info && info->capabilities.contains(capability);
}

QStringList ToolDiscoveryManager::getToolsWithCapability(const QString &capability) const
{
    return findToolsByCapability(capability);
}

QString ToolDiscoveryManager::findBestTool(const QStringList &requiredCapabilities,
                                         const QStringList &preferredCapabilities) const
{
    QString bestTool;
    double bestScore = -1.0;

    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        const auto &meta = it.value();

        // Check required capabilities
        bool hasAll = true;
        for (const auto &cap : requiredCapabilities) {
            if (!meta.capabilities.contains(cap)) {
                hasAll = false;
                break;
            }
        }

        if (!hasAll) {
            continue;
        }

        double score = _calculateScore(meta, requiredCapabilities, preferredCapabilities);
        if (score > bestScore) {
            bestScore = score;
            bestTool = meta.id;
        }
    }

    return bestTool;
}

QJsonObject ToolDiscoveryManager::getStatistics() const
{
    QJsonObject stats;
    stats["total_tools"] = (int)m_context.tools.size();
    stats["categories"] = (int)m_context.categoryMap.size();
    stats["capabilities"] = (int)m_context.capabilityMap.size();
    stats["cache_hits"] = m_context.cacheHits;
    stats["cache_misses"] = m_context.cacheMisses;

    int enabledCount = 0;
    for (const auto &meta : m_context.tools) {
        if (meta.enabled) {
            enabledCount++;
        }
    }
    stats["enabled_tools"] = enabledCount;

    return stats;
}

QJsonObject ToolDiscoveryManager::getToolStats(const QString &toolId) const
{
    QJsonObject stats;
    auto it = m_context.tools.find(toolId);
    if (it == m_context.tools.end()) {
        return stats;
    }

    const auto &meta = it.value();
    stats["uses"] = meta.usageCount;
    stats["success_rate"] = meta.successRate;
    stats["last_used"] = meta.lastUsed.toString(Qt::ISODate);
    stats["estimated_time"] = meta.estimatedExecutionTime;

    return stats;
}

void ToolDiscoveryManager::recordToolUsage(const QString &toolId, bool success)
{
    auto it = m_context.tools.find(toolId);
    if (it == m_context.tools.end()) {
        return;
    }

    auto &meta = it.value();
    meta.usageCount++;
    meta.lastUsed = QDateTime::currentDateTime();

    // Update success rate
    if (success) {
        meta.successRate = (meta.successRate * (meta.usageCount - 1) + 1.0) / meta.usageCount;
    } else {
        meta.successRate = (meta.successRate * (meta.usageCount - 1)) / meta.usageCount;
    }

    emit toolStatsUpdated(toolId);
}

QJsonObject ToolDiscoveryManager::getPerformanceReport() const
{
    QJsonObject report;

    // Sort by success rate
    QVector<QPair<QString, double>> successRates;
    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        successRates.append({it.key(), it.value().successRate});
    }
    std::sort(successRates.begin(), successRates.end(),
              [](const auto &a, const auto &b) { return a.second > b.second; });

    QJsonArray top10;
    int count = 0;
    for (const auto &[toolId, rate] : successRates) {
        if (count++ >= 10) break;
        QJsonObject entry;
        entry["tool_id"] = toolId;
        entry["success_rate"] = rate;
        auto info = getToolInfo(toolId);
        if (info) {
            entry["estimated_time"] = info->estimatedExecutionTime;
        }
        top10.append(entry);
    }
    report["top_performers"] = top10;

    return report;
}

double ToolDiscoveryManager::checkCompatibility(const QString &toolId) const
{
    auto info = getToolInfo(toolId);
    if (!info) {
        return 0.0;
    }

    if (!_isCompatible(*info)) {
        return 0.0;
    }

    return 1.0 - (info->dependencies.size() * 0.1);
}

QStringList ToolDiscoveryManager::resolveDependencies(const QString &toolId) const
{
    auto info = getToolInfo(toolId);
    if (!info) {
        return {};
    }

    return info->dependencies;
}

bool ToolDiscoveryManager::areDependenciesAvailable(const QString &toolId) const
{
    auto deps = resolveDependencies(toolId);
    for (const auto &dep : deps) {
        if (!hasTool(dep)) {
            return false;
        }
    }
    return true;
}

QMap<QString, QStringList> ToolDiscoveryManager::getCategorizedTools() const
{
    if (!m_context.cacheValid) {
        const_cast<ToolDiscoveryManager *>(this)->_buildCaches();
    }
    return m_context.categoryMap;
}

QStringList ToolDiscoveryManager::getToolsByPriority(bool descending) const
{
    QVector<QPair<QString, int>> tools;
    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        tools.append({it.key(), it.value().priority});
    }

    std::sort(tools.begin(), tools.end(),
              [descending](const auto &a, const auto &b) {
                  return descending ? a.second > b.second : a.second < b.second;
              });

    QStringList result;
    for (const auto &[id, _] : tools) {
        result.append(id);
    }
    return result;
}

QMap<QString, QStringList> ToolDiscoveryManager::getRecommendedTools() const
{
    QMap<QString, QStringList> recommended;

    // Map common tasks to recommended tools
    recommended["file_operations"] = findToolsByCapability("file_write");
    recommended["code_generation"] = findToolsByCapability("code_gen");
    recommended["search"] = findToolsByCapability("search");
    recommended["testing"] = findToolsByCapability("test");
    recommended["git"] = findToolsByCapability("vcs");

    return recommended;
}

QStringList ToolDiscoveryManager::sortToolsByMetric(const QStringList &toolIds, const QString &metric) const
{
    QVector<QPair<QString, double>> scored;

    for (const auto &toolId : toolIds) {
        auto info = getToolInfo(toolId);
        if (!info) continue;

        double score = 0.0;
        if (metric == "priority") {
            score = info->priority;
        } else if (metric == "success_rate") {
            score = info->successRate * 100;
        } else if (metric == "speed") {
            score = info->estimatedExecutionTime > 0 ? 1000.0 / info->estimatedExecutionTime : 100;
        } else if (metric == "usage") {
            score = info->usageCount;
        }

        scored.append({toolId, score});
    }

    std::sort(scored.begin(), scored.end(),
              [](const auto &a, const auto &b) { return a.second > b.second; });

    QStringList result;
    for (const auto &[id, _] : scored) {
        result.append(id);
    }
    return result;
}

QJsonObject ToolDiscoveryManager::exportCatalog() const
{
    QJsonObject catalog;

    QJsonArray toolsArray;
    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        const auto &meta = it.value();

        QJsonObject toolObj;
        toolObj["id"] = meta.id;
        toolObj["name"] = meta.name;
        toolObj["description"] = meta.description;
        toolObj["category"] = meta.category;
        toolObj["version"] = meta.version;
        toolObj["priority"] = meta.priority;
        toolObj["enabled"] = meta.enabled;

        QJsonArray capsArray;
        for (const auto &cap : meta.capabilities) {
            capsArray.append(cap);
        }
        toolObj["capabilities"] = capsArray;

        QJsonArray aliasArray;
        for (const auto &alias : meta.aliases) {
            aliasArray.append(alias);
        }
        toolObj["aliases"] = aliasArray;

        toolsArray.append(toolObj);
    }

    catalog["tools"] = toolsArray;
    catalog["export_date"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    catalog["tool_count"] = (int)m_context.tools.size();

    return catalog;
}

int ToolDiscoveryManager::importCatalog(const QJsonObject &catalogJson)
{
    int count = 0;
    auto toolsArray = catalogJson["tools"].toArray();

    for (const auto &toolVal : toolsArray) {
        auto toolObj = toolVal.toObject();

        ToolMetadata metadata;
        metadata.id = toolObj["id"].toString();
        metadata.name = toolObj["name"].toString();
        metadata.description = toolObj["description"].toString();
        metadata.category = toolObj["category"].toString();
        metadata.version = toolObj["version"].toString("1.0");
        metadata.priority = toolObj["priority"].toInt(50);
        metadata.enabled = toolObj["enabled"].toBool(true);

        auto capsArray = toolObj["capabilities"].toArray();
        for (const auto &cap : capsArray) {
            metadata.capabilities.append(cap.toString());
        }

        if (registerTool(metadata)) {
            count++;
        }
    }

    return count;
}

QJsonObject ToolDiscoveryManager::exportToolConfig(const QString &toolId) const
{
    auto info = getToolInfo(toolId);
    if (!info) {
        return {};
    }

    QJsonObject config;
    config["id"] = info->id;
    config["schema"] = info->schema;

    QJsonObject configObj;
    for (auto it = info->config.begin(); it != info->config.end(); ++it) {
        configObj[it.key()] = QJsonValue::fromVariant(it.value());
    }
    config["configuration"] = configObj;

    return config;
}

bool ToolDiscoveryManager::importToolConfig(const QString &toolId, const QJsonObject &config)
{
    auto it = m_context.tools.find(toolId);
    if (it == m_context.tools.end()) {
        return false;
    }

    auto &meta = it.value();
    auto configObj = config["configuration"].toObject();

    for (auto confIt = configObj.begin(); confIt != configObj.end(); ++confIt) {
        meta.config[confIt.key()] = confIt.value().toVariant();
    }

    return true;
}

void ToolDiscoveryManager::clearCache()
{
    m_context.tools.clear();
    m_context.aliasMap.clear();
    m_context.capabilityMap.clear();
    m_context.categoryMap.clear();
    m_context.cacheValid = false;
    m_context.cacheHits = 0;
    m_context.cacheMisses = 0;
}

void ToolDiscoveryManager::invalidateCache()
{
    m_context.cacheValid = false;
}

QJsonObject ToolDiscoveryManager::getCacheStats() const
{
    QJsonObject stats;
    stats["hits"] = m_context.cacheHits;
    stats["misses"] = m_context.cacheMisses;
    stats["size"] = (int)m_context.tools.size();
    return stats;
}

void ToolDiscoveryManager::_buildCaches()
{
    m_context.capabilityMap.clear();
    m_context.categoryMap.clear();

    for (auto it = m_context.tools.begin(); it != m_context.tools.end(); ++it) {
        const auto &meta = it.value();

        // Build capability map
        for (const auto &cap : meta.capabilities) {
            m_context.capabilityMap[cap].append(meta.id);
        }

        // Build category map
        m_context.categoryMap[meta.category].append(meta.id);
    }

    m_context.cacheValid = true;
}

void ToolDiscoveryManager::_scanToolDefinitions()
{
    // Scan for tool definition files
    discoverAllTools();
}

bool ToolDiscoveryManager::_isCompatible(const ToolMetadata &metadata) const
{
    // Check if tool dependencies are available
    for (const auto &dep : metadata.dependencies) {
        if (!hasTool(dep)) {
            return false;
        }
    }
    return true;
}

double ToolDiscoveryManager::_calculateScore(const ToolMetadata &metadata,
                                             const QStringList &required,
                                             const QStringList &preferred) const
{
    double score = 0.0;

    // Base score from priority
    score += metadata.priority;

    // Bonus for success rate
    score += metadata.successRate * 20;

    // Bonus for preferred capabilities
    for (const auto &cap : preferred) {
        if (metadata.capabilities.contains(cap)) {
            score += 10;
        }
    }

    // Penalty for unmet dependencies
    score -= metadata.dependencies.size() * 5;

    return score;
}
