#include "QuickAccessManager.h"
#include <QStringMatcher>
#include <algorithm>
#include <QDateTime>

namespace {

bool hasQuickAccessItem(const QList<QuickAccessItem>& items, const QString& itemId) {
    return std::any_of(items.begin(), items.end(), [&itemId](const QuickAccessItem& item) {
        return item.id == itemId;
    });
}

}  // namespace

class QuickAccessManager::Impl {
public:
    QList<QuickAccessItem> items;
    QList<QuickAccessItem> recentItems;
    QList<IQuickAccessProvider*> providers;
    static constexpr int MAX_RECENT = 50;
    
    int fuzzyScore(const QString& query, const QString& text) {
        if (query.isEmpty()) return 100;
        if (text.isEmpty()) return 0;
        
        int score = 0;
        int queryIdx = 0;
        int consecutive = 0;
        int maxConsecutive = 0;
        
        for (int i = 0; i < text.length() && queryIdx < query.length(); ++i) {
            if (text[i].toLower() == query[queryIdx].toLower()) {
                queryIdx++;
                consecutive++;
                maxConsecutive = qMax(maxConsecutive, consecutive);
                score += 10;
                
                // Bonus for starting
                if (i == 0) score += 20;
            } else {
                consecutive = 0;
            }
        }
        
        // Check if all query chars matched
        if (queryIdx < query.length()) {
            return 0;  // Incomplete match
        }
        
        // Prefer shorter matches
        score -= text.length() / 10;
        
        // Consecutive matches get bonus
        score += maxConsecutive * 5;
        
        return score;
    }
};

QuickAccessManager* QuickAccessManager::instance() {
    static QuickAccessManager s_instance;
    return &s_instance;
}

QuickAccessManager::QuickAccessManager()
    : m_impl(std::make_unique<Impl>()) {
}

QuickAccessManager::~QuickAccessManager() = default;

void QuickAccessManager::registerItem(const QuickAccessItem& item) {
    m_impl->items.append(item);
    emit itemsChanged();
}

void QuickAccessManager::unregisterItem(const QString& itemId) {
    m_impl->items.erase(
        std::remove_if(m_impl->items.begin(), m_impl->items.end(),
                      [&itemId](const QuickAccessItem& item) { return item.id == itemId; }),
        m_impl->items.end()
    );
    emit itemsChanged();
}

QList<QuickAccessItem> QuickAccessManager::getAllItems() const {
    return m_impl->items;
}

void QuickAccessManager::registerProvider(IQuickAccessProvider* provider) {
    if (!m_impl->providers.contains(provider)) {
        m_impl->providers.append(provider);
    }
}

void QuickAccessManager::unregisterProvider(const QString& prefix) {
    m_impl->providers.erase(
        std::remove_if(m_impl->providers.begin(), m_impl->providers.end(),
                      [&prefix](IQuickAccessProvider* p) {
                          return p->getPrefix() == prefix;
                      }),
        m_impl->providers.end()
    );
}

QList<QuickAccessItem> QuickAccessManager::search(const QString& query) {
    QList<QuickAccessItem> results;
    
    // Check for prefix
    QString actualQuery = query;
    IQuickAccessProvider* targetProvider = nullptr;
    
    for (auto provider : m_impl->providers) {
        auto prefix = provider->getPrefix();
        if (query.startsWith(prefix)) {
            actualQuery = query.mid(prefix.length());
            targetProvider = provider;
            break;
        }
    }
    
    // If provider found, use it
    if (targetProvider) {
        results = targetProvider->getItems(actualQuery);
    } else {
        // Search in all items
        for (const auto& item : m_impl->items) {
            int score = m_impl->fuzzyScore(actualQuery, item.label);
            if (score > 0) {
                auto result = item;
                result.score = score;
                results.append(result);
            }
            
            // Also try description
            if (item.description.contains(actualQuery, Qt::CaseInsensitive)) {
                auto result = item;
                result.score = qMax(result.score, 50);
                if (!hasQuickAccessItem(results, result.id)) {
                    results.append(result);
                }
            }
        }
        
        // Sort by score
        std::sort(results.begin(), results.end(),
                 [](const QuickAccessItem& a, const QuickAccessItem& b) {
                     return a.score > b.score;
                 });
    }
    
    emit searchResultsUpdated(results);
    return results;
}

QList<QuickAccessItem> QuickAccessManager::searchWithPrefix(const QString& prefix, const QString& query) {
    for (auto provider : m_impl->providers) {
        if (provider->getPrefix() == prefix) {
            return provider->getItems(query);
        }
    }
    return QList<QuickAccessItem>();
}

QList<QuickAccessItem> QuickAccessManager::getRecentItems(int maxCount) {
    return m_impl->recentItems.mid(
        qMax(0, m_impl->recentItems.size() - maxCount)
    );
}

void QuickAccessManager::addToRecent(const QuickAccessItem& item) {
    // Remove duplicate if exists
    m_impl->recentItems.erase(
        std::remove_if(m_impl->recentItems.begin(), m_impl->recentItems.end(),
                      [&item](const QuickAccessItem& i) { return i.id == item.id; }),
        m_impl->recentItems.end()
    );
    
    // Add to end
    m_impl->recentItems.append(item);
    
    // Trim if too large
    if (m_impl->recentItems.size() > m_impl->MAX_RECENT) {
        m_impl->recentItems.removeFirst();
    }
}

void QuickAccessManager::clearRecent() {
    m_impl->recentItems.clear();
}

bool QuickAccessManager::execute(const QuickAccessItem& item) {
    if (item.handler) {
        item.handler();
        addToRecent(item);
        emit itemExecuted(item);
        return true;
    }
    return false;
}

bool QuickAccessManager::executeById(const QString& itemId) {
    for (const auto& item : m_impl->items) {
        if (item.id == itemId) {
            return execute(item);
        }
    }
    return false;
}

QList<QuickAccessItem> QuickAccessManager::getCommandItems() const {
    QList<QuickAccessItem> commands;
    for (const auto& item : m_impl->items) {
        if (item.type == QuickAccessItem::Command) {
            commands.append(item);
        }
    }
    return commands;
}

QList<QuickAccessItem> QuickAccessManager::getFileItems() const {
    QList<QuickAccessItem> files;
    for (const auto& item : m_impl->items) {
        if (item.type == QuickAccessItem::File) {
            files.append(item);
        }
    }
    return files;
}

QList<QuickAccessItem> QuickAccessManager::getSymbolItems() const {
    QList<QuickAccessItem> symbols;
    for (const auto& item : m_impl->items) {
        if (item.type == QuickAccessItem::Symbol) {
            symbols.append(item);
        }
    }
    return symbols;
}
