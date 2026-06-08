#ifndef CONTEXTMENUINTEGRATION_H
#define CONTEXTMENUINTEGRATION_H

#include <QString>
#include <QList>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @class ContextMenuIntegration
 * @brief 上下文菜单集成系统
 * 
 * 功能：
 * - 右键菜单命令注册
 * - 上下文过滤（编辑器、文件浏览器、终端）
 * - 菜单项组织和分组
 * - 动态菜单条件评估
 * - 菜单项启用/禁用
 */

class ContextMenuIntegration
{
public:
    enum ContextType {
        EditorContext,         // 编辑器右键菜单
        FileExplorerContext,   // 文件浏览器右键菜单
        TerminalContext,       // 终端右键菜单
        TabContext,            // 标签栏右键菜单
        GlobalContext          // 全局右键菜单
    };

    struct MenuItem {
        QString commandId;
        QString label;
        QString category;
        QString icon;
        int order = 0;           // 菜单项顺序
        bool enabled = true;
        bool separator = false;  // 是否为分隔符
        QString when;            // 显示条件
        QList<MenuItem> submenu; // 子菜单
    };

    struct ContextMenu {
        ContextType type;
        QString title;
        QList<MenuItem> items;
        bool hasSearch = false;
    };

    explicit ContextMenuIntegration();
    ~ContextMenuIntegration();

    // 菜单项注册
    void registerMenuItem(ContextType type, const MenuItem &item);
    void registerMenuItems(ContextType type, const QList<MenuItem> &items);
    void unregisterMenuItem(ContextType type, const QString &commandId);

    // 获取菜单
    ContextMenu getContextMenu(ContextType type);
    QList<MenuItem> getMenuItems(ContextType type);
    MenuItem getMenuItem(ContextType type, const QString &commandId);

    // 菜单项管理
    void updateMenuItem(ContextType type, const MenuItem &item);
    void enableMenuItem(ContextType type, const QString &commandId, bool enabled = true);
    void disableMenuItem(ContextType type, const QString &commandId);
    void addSeparator(ContextType type, const QString &afterCommandId = "");
    void addSubmenu(ContextType type, const QString &parentCommandId, const MenuItem &submenuItem);

    // 排序和组织
    void setMenuItemOrder(ContextType type, const QString &commandId, int order);
    void sortMenuItems(ContextType type);
    void groupMenuItems(ContextType type, const QString &category);

    // 条件评估
    bool evaluateCondition(const QString &when, const QJsonObject &context = {});
    void setContextData(const QString &key, const QJsonValue &value);
    QJsonObject getContextData() const;

    // 导入导出
    QJsonObject exportMenuStructure();
    bool importMenuStructure(const QJsonObject &data);

    // 默认菜单设置
    void initializeDefaultMenus();

    // 获取菜单统计
    int getItemCount(ContextType type) const;
    QList<QString> getCategories(ContextType type) const;

private:
    QMap<ContextType, QList<MenuItem>> m_menus;
    QJsonObject m_contextData;

    // 菜单验证
    bool isValidMenuItem(const MenuItem &item) const;
    void sortByOrder(QList<MenuItem> &items);

    // 默认菜单项
    void createEditorContextMenu();
    void createFileExplorerContextMenu();
    void createTerminalContextMenu();
    void createTabContextMenu();
    void createGlobalContextMenu();
};

#endif // CONTEXTMENUINTEGRATION_H
