#include "ContextMenuIntegration.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>
#include <algorithm>

ContextMenuIntegration::ContextMenuIntegration()
{
    initializeDefaultMenus();
}

ContextMenuIntegration::~ContextMenuIntegration()
{
}

void ContextMenuIntegration::registerMenuItem(ContextType type, const MenuItem &item)
{
    if (!isValidMenuItem(item)) {
        qWarning() << "Invalid menu item:" << item.label;
        return;
    }

    m_menus[type].append(item);
    sortMenuItems(type);
}

void ContextMenuIntegration::registerMenuItems(ContextType type, const QList<MenuItem> &items)
{
    for (const auto &item : items) {
        registerMenuItem(type, item);
    }
}

void ContextMenuIntegration::unregisterMenuItem(ContextType type, const QString &commandId)
{
    auto &items = m_menus[type];
    items.erase(std::remove_if(items.begin(), items.end(),
        [&commandId](const MenuItem &item) { return item.commandId == commandId; }),
        items.end());
}

ContextMenuIntegration::ContextMenu ContextMenuIntegration::getContextMenu(ContextType type)
{
    ContextMenu menu;
    menu.type = type;
    menu.items = m_menus.value(type);
    return menu;
}

QList<ContextMenuIntegration::MenuItem> ContextMenuIntegration::getMenuItems(ContextType type)
{
    return m_menus.value(type);
}

ContextMenuIntegration::MenuItem ContextMenuIntegration::getMenuItem(ContextType type, const QString &commandId)
{
    for (const auto &item : m_menus.value(type)) {
        if (item.commandId == commandId) {
            return item;
        }
    }
    return MenuItem();
}

void ContextMenuIntegration::updateMenuItem(ContextType type, const MenuItem &item)
{
    auto &items = m_menus[type];
    for (auto &existing : items) {
        if (existing.commandId == item.commandId) {
            existing = item;
            sortMenuItems(type);
            return;
        }
    }
}

void ContextMenuIntegration::enableMenuItem(ContextType type, const QString &commandId, bool enabled)
{
    auto &items = m_menus[type];
    for (auto &item : items) {
        if (item.commandId == commandId) {
            item.enabled = enabled;
            return;
        }
    }
}

void ContextMenuIntegration::disableMenuItem(ContextType type, const QString &commandId)
{
    enableMenuItem(type, commandId, false);
}

void ContextMenuIntegration::addSeparator(ContextType type, const QString &afterCommandId)
{
    MenuItem separator;
    separator.separator = true;
    separator.label = "";
    separator.order = 999;

    if (!afterCommandId.isEmpty()) {
        auto &items = m_menus[type];
        for (int i = 0; i < items.size(); ++i) {
            if (items[i].commandId == afterCommandId) {
                separator.order = items[i].order + 0.5;
                break;
            }
        }
    }

    registerMenuItem(type, separator);
}

void ContextMenuIntegration::addSubmenu(ContextType type, const QString &parentCommandId, const MenuItem &submenuItem)
{
    auto &items = m_menus[type];
    for (auto &item : items) {
        if (item.commandId == parentCommandId) {
            item.submenu.append(submenuItem);
            return;
        }
    }
}

void ContextMenuIntegration::setMenuItemOrder(ContextType type, const QString &commandId, int order)
{
    auto &items = m_menus[type];
    for (auto &item : items) {
        if (item.commandId == commandId) {
            item.order = order;
            sortMenuItems(type);
            return;
        }
    }
}

void ContextMenuIntegration::sortMenuItems(ContextType type)
{
    sortByOrder(m_menus[type]);
}

void ContextMenuIntegration::groupMenuItems(ContextType type, const QString &category)
{
    auto &items = m_menus[type];
    
    // 按分类重新组织
    std::sort(items.begin(), items.end(), [&category](const MenuItem &a, const MenuItem &b) {
        if ((a.category == category) && (b.category != category)) {
            return true;
        }
        if ((a.category != category) && (b.category == category)) {
            return false;
        }
        return a.order < b.order;
    });
}

bool ContextMenuIntegration::evaluateCondition(const QString &when, const QJsonObject &context)
{
    if (when.isEmpty()) {
        return true;
    }

    // 简化的条件评估
    QJsonObject evalContext = context.isEmpty() ? m_contextData : context;

    // 支持简单的布尔条件
    if (when == "editorFocus") {
        return evalContext.value("focus").toString() == "editor";
    } else if (when == "hasSelection") {
        return evalContext.value("hasSelection").toBool();
    } else if (when == "inTerminal") {
        return evalContext.value("focus").toString() == "terminal";
    }

    return true;
}

void ContextMenuIntegration::setContextData(const QString &key, const QJsonValue &value)
{
    m_contextData[key] = value;
}

QJsonObject ContextMenuIntegration::getContextData() const
{
    return m_contextData;
}

QJsonObject ContextMenuIntegration::exportMenuStructure()
{
    QJsonObject exported;

    for (auto it = m_menus.begin(); it != m_menus.end(); ++it) {
        QString contextName;
        switch (it.key()) {
        case EditorContext: contextName = "editor"; break;
        case FileExplorerContext: contextName = "fileExplorer"; break;
        case TerminalContext: contextName = "terminal"; break;
        case TabContext: contextName = "tab"; break;
        case GlobalContext: contextName = "global"; break;
        }

        QJsonArray itemsArray;
        for (const auto &item : it.value()) {
            QJsonObject itemObj;
            itemObj["commandId"] = item.commandId;
            itemObj["label"] = item.label;
            itemObj["category"] = item.category;
            itemObj["icon"] = item.icon;
            itemObj["order"] = item.order;
            itemObj["enabled"] = item.enabled;
            itemObj["separator"] = item.separator;
            itemObj["when"] = item.when;
            itemsArray.append(itemObj);
        }
        exported[contextName] = itemsArray;
    }

    return exported;
}

bool ContextMenuIntegration::importMenuStructure(const QJsonObject &data)
{
    QMap<QString, ContextType> contextMap;
    contextMap["editor"] = EditorContext;
    contextMap["fileExplorer"] = FileExplorerContext;
    contextMap["terminal"] = TerminalContext;
    contextMap["tab"] = TabContext;
    contextMap["global"] = GlobalContext;

    for (auto it = data.begin(); it != data.end(); ++it) {
        if (!contextMap.contains(it.key())) {
            continue;
        }

        ContextType type = contextMap[it.key()];
        QJsonArray itemsArray = it.value().toArray();

        for (const auto &itemValue : itemsArray) {
            QJsonObject itemObj = itemValue.toObject();
            MenuItem item;
            item.commandId = itemObj.value("commandId").toString();
            item.label = itemObj.value("label").toString();
            item.category = itemObj.value("category").toString();
            item.icon = itemObj.value("icon").toString();
            item.order = itemObj.value("order").toInt();
            item.enabled = itemObj.value("enabled").toBool(true);
            item.separator = itemObj.value("separator").toBool();
            item.when = itemObj.value("when").toString();

            registerMenuItem(type, item);
        }
    }

    return true;
}

void ContextMenuIntegration::initializeDefaultMenus()
{
    createEditorContextMenu();
    createFileExplorerContextMenu();
    createTerminalContextMenu();
    createTabContextMenu();
    createGlobalContextMenu();
}

int ContextMenuIntegration::getItemCount(ContextType type) const
{
    return m_menus.value(type).size();
}

QList<QString> ContextMenuIntegration::getCategories(ContextType type) const
{
    QSet<QString> categories;
    for (const auto &item : m_menus.value(type)) {
        if (!item.category.isEmpty()) {
            categories.insert(item.category);
        }
    }
    return categories.values();
}

bool ContextMenuIntegration::isValidMenuItem(const MenuItem &item) const
{
    if (item.separator) {
        return true;
    }
    return !item.commandId.isEmpty();
}

void ContextMenuIntegration::sortByOrder(QList<MenuItem> &items)
{
    std::sort(items.begin(), items.end(), [](const MenuItem &a, const MenuItem &b) {
        return a.order < b.order;
    });
}

void ContextMenuIntegration::createEditorContextMenu()
{
    QList<MenuItem> items;

    // Agent操作
    items.append(MenuItem{
        "neurx.runAgent",
        "Run Agent",
        "Agent",
        "play-icon",
        10,
        true,
        false,
        "editorFocus"
    });

    items.append(MenuItem{
        "neurx.assessRisk",
        "Assess Risk",
        "Agent",
        "shield-icon",
        20,
        true,
        false,
        "editorFocus"
    });

    // 分隔符
    items.append(MenuItem{
        "",
        "",
        "",
        "",
        50,
        true,
        true,
        ""
    });

    // 编辑操作
    items.append(MenuItem{
        "neurx.formatSelectedFiles",
        "Format Code",
        "Edit",
        "format-icon",
        60,
        true,
        false,
        "hasSelection"
    });

    items.append(MenuItem{
        "neurx.searchWorkspace",
        "Search in Workspace",
        "Navigation",
        "search-icon",
        70,
        true,
        false,
        "editorFocus"
    });

    registerMenuItems(EditorContext, items);
}

void ContextMenuIntegration::createFileExplorerContextMenu()
{
    QList<MenuItem> items;

    items.append(MenuItem{
        "neurx.createFileFromTemplate",
        "Create from Template",
        "FileOperation",
        "file-add-icon",
        10
    });

    items.append(MenuItem{
        "neurx.generateDirectoryTree",
        "Generate Directory Tree",
        "FileOperation",
        "tree-icon",
        20
    });

    items.append(MenuItem{
        "",
        "",
        "",
        "",
        50,
        true,
        true,
        ""
    });

    items.append(MenuItem{
        "neurx.batchRename",
        "Batch Rename",
        "FileOperation",
        "rename-icon",
        60
    });

    registerMenuItems(FileExplorerContext, items);
}

void ContextMenuIntegration::createTerminalContextMenu()
{
    QList<MenuItem> items;

    items.append(MenuItem{
        "neurx.runAgent",
        "Run Agent on Terminal",
        "Agent",
        "play-icon",
        10
    });

    items.append(MenuItem{
        "",
        "",
        "",
        "",
        50,
        true,
        true,
        ""
    });

    items.append(MenuItem{
        "neurx.analyzeGitHistory",
        "Analyze Git History",
        "Git",
        "git-icon",
        60
    });

    registerMenuItems(TerminalContext, items);
}

void ContextMenuIntegration::createTabContextMenu()
{
    QList<MenuItem> items;

    items.append(MenuItem{
        "neurx.goToDefinition",
        "Go to Definition",
        "Navigation",
        "goto-icon",
        10,
        true,
        false,
        "hasSelection"
    });

    items.append(MenuItem{
        "neurx.findReferences",
        "Find References",
        "Navigation",
        "refs-icon",
        20,
        true,
        false,
        "hasSelection"
    });

    registerMenuItems(TabContext, items);
}

void ContextMenuIntegration::createGlobalContextMenu()
{
    QList<MenuItem> items;

    items.append(MenuItem{
        "neurx.showDiagnostics",
        "Show Diagnostics",
        "Debug",
        "bug-icon",
        10
    });

    items.append(MenuItem{
        "neurx.enableDebugLogging",
        "Enable Debug Logging",
        "Debug",
        "debug-icon",
        20
    });

    registerMenuItems(GlobalContext, items);
}
