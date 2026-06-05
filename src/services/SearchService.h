#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QList>
#include <functional>
#include <memory>

/**
 * @class SearchService
 * @brief Global search/replace functionality
 * 
 * Features:
 * - Text search across workspace
 * - Regex support
 * - Replace functionality
 * - Search result caching
 * - Progress reporting
 */

struct SearchMatch {
    QString file;
    int line = 0;
    int column = 0;
    int length = 0;
    QString lineText;
    QString matchText;
};

struct SearchQuery {
    QString text;
    bool useRegex = false;
    bool caseSensitive = false;
    bool wholeWord = false;
    bool includeHidden = false;
    QStringList includePatterns;  // e.g., "*.cpp"
    QStringList excludePatterns;  // e.g., "node_modules"
};

class SearchService : public QObject {
    Q_OBJECT

public:
    static SearchService* instance();
    
    // Search operations
    QList<SearchMatch> search(const SearchQuery& query);
    QList<SearchMatch> searchInFile(const QString& filePath, const SearchQuery& query);
    QList<SearchMatch> searchInText(const QString& text, const SearchQuery& query, const QString& sourceFile = QString());
    
    // Replace operations
    int replaceAll(const SearchQuery& query, const QString& replacement);
    int replaceInFile(const QString& filePath, const SearchQuery& query, const QString& replacement);
    int replaceInText(const QString& text, const SearchQuery& query, const QString& replacement);
    
    // Incremental search
    QString startIncrementalSearch(const SearchQuery& query);
    void updateIncrementalSearch(const QString& searchId, const SearchQuery& query);
    void stopIncrementalSearch(const QString& searchId);
    
    // Results management
    QList<SearchMatch> getSearchResults(const QString& searchId) const;
    int getResultCount(const QString& searchId) const;
    bool hasResults(const QString& searchId) const;
    void clearResults(const QString& searchId);
    
    // Advanced
    QStringList findReferences(const QString& symbol);
    QStringList findDefinitions(const QString& symbol);

signals:
    void searchStarted(const QString& searchId);
    void searchProgressUpdated(const QString& searchId, int current, int total);
    void searchCompleted(const QString& searchId, int resultCount);
    void searchCanceled(const QString& searchId);
    void searchError(const QString& searchId, const QString& error);

private:
    SearchService();
    ~SearchService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
