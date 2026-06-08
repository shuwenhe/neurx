#include "CommandPalette.h"
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <algorithm>

CommandPalette::CommandPalette(CommandRegistry *registry)
    : m_registry(registry)
{
}

CommandPalette::~CommandPalette()
{
}

CommandPalette::SearchResult CommandPalette::searchCommands(const QString &query, int limit)
{
    auto startTime = QDateTime::currentMSecsSinceEpoch();
    SearchResult result;

    if (!m_registry) {
        return result;
    }

    // 搜索所有匹配查询的命令
    auto commands = m_registry->searchCommands(query);

    // 转换为CommandItem
    for (const auto &cmd : commands) {
        result.items.append(toCommandItem(cmd));
    }

    // 排序结果
    rankSearchResults(result.items, query);

    // 应用限制
    if (result.items.size() > limit) {
        result.items = result.items.mid(0, limit);
    }

    result.totalMatches = result.items.size();
    result.timeMs = QDateTime::currentMSecsSinceEpoch() - startTime;

    return result;
}

QList<CommandPalette::CommandItem> CommandPalette::filterByCategory(const QString &category)
{
    if (!m_registry) {
        return {};
    }

    QList<CommandItem> items;
    for (const auto &cmd : m_registry->listCommands()) {
        if (cmd.category == static_cast<int>(CommandRegistry::FileOperation) && category == "FileOperation") {
            items.append(toCommandItem(cmd));
        } else if (cmd.category == static_cast<int>(CommandRegistry::Agent) && category == "Agent") {
            items.append(toCommandItem(cmd));
        } else if (cmd.category == static_cast<int>(CommandRegistry::GitOperation) && category == "GitOperation") {
            items.append(toCommandItem(cmd));
        } else if (cmd.category == static_cast<int>(CommandRegistry::Navigation) && category == "Navigation") {
            items.append(toCommandItem(cmd));
        } else if (cmd.category == static_cast<int>(CommandRegistry::Debug) && category == "Debug") {
            items.append(toCommandItem(cmd));
        }
    }

    sortByFrequency(items);
    return items;
}

QList<CommandPalette::CommandItem> CommandPalette::getRecentCommands(int limit)
{
    QList<CommandItem> items;

    for (int i = 0; i < qMin(limit, m_recentCommands.size()); ++i) {
        if (m_registry && m_registry->commandExists(m_recentCommands[i])) {
            auto cmd = m_registry->getCommand(m_recentCommands[i]);
            CommandItem item = toCommandItem(cmd);
            item.isRecent = true;
            items.append(item);
        }
    }

    return items;
}

QList<CommandPalette::CommandItem> CommandPalette::getFavoriteCommands()
{
    QList<CommandItem> items;

    for (auto it = m_favorites.begin(); it != m_favorites.end(); ++it) {
        if (it.value() && m_registry && m_registry->commandExists(it.key())) {
            auto cmd = m_registry->getCommand(it.key());
            items.append(toCommandItem(cmd));
        }
    }

    return items;
}

CommandPalette::CommandItem CommandPalette::toCommandItem(const CommandRegistry::RegisteredCommand &cmd)
{
    CommandItem item;
    item.id = cmd.id;
    item.title = cmd.title;
    item.description = cmd.description;
    item.category = QString::number(cmd.category);
    item.executionCount = 0;
    item.isRecent = m_recentCommands.contains(cmd.id);

    if (m_registry) {
        auto bindings = m_registry->getKeyBindings(cmd.id);
        if (!bindings.isEmpty()) {
            item.keybinding = bindings.first().keyCombination;
        }
    }

    return item;
}

CommandPalette::CommandItem CommandPalette::toCommandItem(const CommandRegistry::RegisteredCommand &cmd,
                                                        const CommandRegistry::KeyBinding &binding)
{
    CommandItem item = toCommandItem(cmd);
    item.keybinding = binding.keyCombination;
    return item;
}

void CommandPalette::rankSearchResults(QList<CommandItem> &items, const QString &query)
{
    // 按相关性分数排序
    std::sort(items.begin(), items.end(), [this, &query](const CommandItem &a, const CommandItem &b) {
        int scoreA = calculateRelevanceScore(a, query);
        int scoreB = calculateRelevanceScore(b, query);
        return scoreA > scoreB;
    });
}

QList<CommandPalette::CommandItem> CommandPalette::sortByRecency(QList<CommandItem> items)
{
    std::sort(items.begin(), items.end(), [this](const CommandItem &a, const CommandItem &b) {
        int idxA = m_recentCommands.indexOf(a.id);
        int idxB = m_recentCommands.indexOf(b.id);
        
        if (idxA == -1 && idxB == -1) {
            return a.title < b.title;
        }
        if (idxA == -1) {
            return false;
        }
        if (idxB == -1) {
            return true;
        }
        return idxA < idxB;
    });

    return items;
}

QList<CommandPalette::CommandItem> CommandPalette::sortByFrequency(QList<CommandItem> items)
{
    std::sort(items.begin(), items.end(), [this](const CommandItem &a, const CommandItem &b) {
        int countA = m_usageCount.value(a.id, 0);
        int countB = m_usageCount.value(b.id, 0);
        return countA > countB;
    });

    return items;
}

void CommandPalette::markAsFavorite(const QString &commandId)
{
    m_favorites[commandId] = true;
}

void CommandPalette::unmarkAsFavorite(const QString &commandId)
{
    m_favorites[commandId] = false;
}

bool CommandPalette::isFavorite(const QString &commandId) const
{
    return m_favorites.value(commandId, false);
}

void CommandPalette::recordCommandUsage(const QString &commandId)
{
    // 更新使用计数
    m_usageCount[commandId]++;

    // 更新最近使用列表
    m_recentCommands.removeAll(commandId);
    m_recentCommands.prepend(commandId);

    // 保持大小限制
    if (m_recentCommands.size() > MAX_RECENT_COMMANDS) {
        m_recentCommands = m_recentCommands.mid(0, MAX_RECENT_COMMANDS);
    }

    // 清理过期的使用计数
    if (m_usageCount.size() > MAX_USAGE_TRACKING) {
        // 移除最少使用的命令
        QString leastUsed;
        int minCount = INT_MAX;
        for (auto it = m_usageCount.begin(); it != m_usageCount.end(); ++it) {
            if (it.value() < minCount) {
                minCount = it.value();
                leastUsed = it.key();
            }
        }
        if (!leastUsed.isEmpty()) {
            m_usageCount.remove(leastUsed);
        }
    }
}

QJsonArray CommandPalette::toJsonArray(const QList<CommandItem> &items)
{
    QJsonArray array;
    for (const auto &item : items) {
        array.append(toJsonObject(item));
    }
    return array;
}

QJsonObject CommandPalette::toJsonObject(const CommandItem &item)
{
    QJsonObject obj;
    obj["id"] = item.id;
    obj["title"] = item.title;
    obj["description"] = item.description;
    obj["category"] = item.category;
    obj["icon"] = item.icon;
    obj["keybinding"] = item.keybinding;
    obj["execution_count"] = item.executionCount;
    obj["is_recent"] = item.isRecent;
    obj["has_conflict"] = item.hasConflict;
    return obj;
}

int CommandPalette::getTotalCommands() const
{
    return m_registry ? m_registry->getTotalCommandCount() : 0;
}

int CommandPalette::getFavoriteCount() const
{
    int count = 0;
    for (const auto &fav : m_favorites.values()) {
        if (fav) {
            count++;
        }
    }
    return count;
}

int CommandPalette::getRecentCount() const
{
    return m_recentCommands.size();
}

QJsonObject CommandPalette::exportPreferences()
{
    QJsonObject prefs;

    QJsonArray favArray;
    for (auto it = m_favorites.begin(); it != m_favorites.end(); ++it) {
        if (it.value()) {
            favArray.append(it.key());
        }
    }
    prefs["favorites"] = favArray;

    QJsonArray recentArray;
    for (const auto &cmd : m_recentCommands) {
        recentArray.append(cmd);
    }
    prefs["recent"] = recentArray;

    QJsonObject usageObj;
    for (auto it = m_usageCount.begin(); it != m_usageCount.end(); ++it) {
        usageObj[it.key()] = it.value();
    }
    prefs["usage"] = usageObj;

    return prefs;
}

void CommandPalette::importPreferences(const QJsonObject &data)
{
    // 导入收藏
    if (data.contains("favorites")) {
        QJsonArray favArray = data["favorites"].toArray();
        for (const auto &item : favArray) {
            m_favorites[item.toString()] = true;
        }
    }

    // 导入最近使用
    if (data.contains("recent")) {
        QJsonArray recentArray = data["recent"].toArray();
        for (const auto &item : recentArray) {
            m_recentCommands.append(item.toString());
        }
    }

    // 导入使用统计
    if (data.contains("usage")) {
        QJsonObject usageObj = data["usage"].toObject();
        for (auto it = usageObj.begin(); it != usageObj.end(); ++it) {
            m_usageCount[it.key()] = it.value().toInt();
        }
    }
}

int CommandPalette::calculateRelevanceScore(const CommandItem &item, const QString &query)
{
    int score = 0;

    // 精确匹配标题
    if (item.title == query) {
        score += 100;
    }
    // 标题以查询开头
    else if (item.title.startsWith(query, Qt::CaseInsensitive)) {
        score += 80;
    }
    // 标题包含查询
    else if (item.title.contains(query, Qt::CaseInsensitive)) {
        score += 50;
    }

    // 命令ID匹配
    if (item.id.contains(query, Qt::CaseInsensitive)) {
        score += 30;
    }

    // 描述匹配
    if (item.description.contains(query, Qt::CaseInsensitive)) {
        score += 10;
    }

    // 最近使用的提升分数
    if (item.isRecent) {
        score += 40;
    }

    // 使用频率提升分数
    if (m_usageCount.contains(item.id)) {
        score += qMin(20, m_usageCount[item.id] / 5);
    }

    return score;
}

bool CommandPalette::matchesQuery(const QString &text, const QString &query)
{
    return text.contains(query, Qt::CaseInsensitive);
}
