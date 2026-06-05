#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QIcon>
#include <functional>
#include <memory>

/**
 * @class QuickAccessManager
 * @brief VS Code-like quick access panel (command palette)
 * 
 * Features:
 * - Command search and filtering
 * - Recent commands
 * - Fuzzy search
 * - Custom providers (files, symbols, etc)
 * - Keyboard shortcuts display
 */

struct QuickAccessItem {
    enum Type {
        Command,
        File,
        Symbol,
        RecentFile,
        Custom
    };
    
    QString id;
    QString label;
    QString description;
    QString keyBindings;  // Display string like "Ctrl+F"
    Type type = Command;
    QIcon icon;
    std::function<void()> handler;
    int score = 0;  // For sorting
    bool separatorBefore = false;
};

class IQuickAccessProvider : public QObject {
    Q_OBJECT
public:
    virtual ~IQuickAccessProvider() = default;
    virtual QString getPrefix() const = 0;
    virtual QList<QuickAccessItem> getItems(const QString& query) = 0;
    virtual bool execute(const QuickAccessItem& item) = 0;
};

class QuickAccessManager : public QObject {
    Q_OBJECT

public:
    static QuickAccessManager* instance();
    
    // Item management
    void registerItem(const QuickAccessItem& item);
    void unregisterItem(const QString& itemId);
    QList<QuickAccessItem> getAllItems() const;
    
    // Provider management
    void registerProvider(IQuickAccessProvider* provider);
    void unregisterProvider(const QString& prefix);
    
    // Search and filter
    QList<QuickAccessItem> search(const QString& query);
    QList<QuickAccessItem> searchWithPrefix(const QString& prefix, const QString& query);
    
    // Recent items
    QList<QuickAccessItem> getRecentItems(int maxCount = 10);
    void addToRecent(const QuickAccessItem& item);
    void clearRecent();
    
    // Execution
    bool execute(const QuickAccessItem& item);
    bool executeById(const QString& itemId);
    
    // Quick command access
    QList<QuickAccessItem> getCommandItems() const;
    QList<QuickAccessItem> getFileItems() const;
    QList<QuickAccessItem> getSymbolItems() const;

signals:
    void itemsChanged();
    void itemExecuted(const QuickAccessItem& item);
    void searchResultsUpdated(const QList<QuickAccessItem>& results);

private:
    QuickAccessManager();
    ~QuickAccessManager() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
