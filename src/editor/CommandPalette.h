#ifndef COMMANDPALETTE_H
#define COMMANDPALETTE_H

#include <QString>
#include <QList>
#include <QJsonObject>
#include <QJsonArray>
#include "CommandRegistry.h"

/**
 * @class CommandPalette
 * @brief 命令调色板 - 快速命令搜索和执行UI
 * 
 * 功能：
 * - 实时命令搜索与过滤
 * - 快捷键提示显示
 * - 最近使用的命令列表
 * - 命令分类浏览
 * - 命令描述和参数帮助
 * - 快捷键冲突警告
 */

class CommandPalette
{
public:
    struct CommandItem {
        QString id;
        QString title;
        QString description;
        QString category;
        QString icon;
        QString keybinding;
        int executionCount = 0;
        bool isRecent = false;
        bool hasConflict = false;
    };

    struct SearchResult {
        QList<CommandItem> items;
        int totalMatches = 0;
        int timeMs = 0;
    };

    explicit CommandPalette(CommandRegistry *registry = nullptr);
    ~CommandPalette();

    // 设置注册表
    void setCommandRegistry(CommandRegistry *registry) { m_registry = registry; }

    // 搜索和过滤
    SearchResult searchCommands(const QString &query, int limit = 50);
    QList<CommandItem> filterByCategory(const QString &category);
    QList<CommandItem> getRecentCommands(int limit = 10);
    QList<CommandItem> getFavoriteCommands();

    // 命令项转换
    CommandItem toCommandItem(const CommandRegistry::RegisteredCommand &cmd);
    CommandItem toCommandItem(const CommandRegistry::RegisteredCommand &cmd,
                            const CommandRegistry::KeyBinding &binding);

    // 排序和排名
    void rankSearchResults(QList<CommandItem> &items, const QString &query);
    QList<CommandItem> sortByRecency(QList<CommandItem> items);
    QList<CommandItem> sortByFrequency(QList<CommandItem> items);

    // 收藏和最近使用
    void markAsFavorite(const QString &commandId);
    void unmarkAsFavorite(const QString &commandId);
    bool isFavorite(const QString &commandId) const;
    void recordCommandUsage(const QString &commandId);

    // 导出数据为UI格式
    QJsonArray toJsonArray(const QList<CommandItem> &items);
    QJsonObject toJsonObject(const CommandItem &item);

    // 统计信息
    int getTotalCommands() const;
    int getFavoriteCount() const;
    int getRecentCount() const;

    // 导入导出偏好设置
    QJsonObject exportPreferences();
    void importPreferences(const QJsonObject &data);

private:
    CommandRegistry *m_registry = nullptr;
    QMap<QString, bool> m_favorites;
    QMap<QString, int> m_usageCount;
    QList<QString> m_recentCommands;
    
    static const int MAX_RECENT_COMMANDS = 20;
    static const int MAX_USAGE_TRACKING = 1000;

    // 搜索算法
    int calculateRelevanceScore(const CommandItem &item, const QString &query);
    bool matchesQuery(const QString &text, const QString &query);
};

#endif // COMMANDPALETTE_H
