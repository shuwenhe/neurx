#include "SearchService.h"
#include "FileService.h"
#include "WorkspaceService.h"
#include <QRegularExpression>
#include <QUuid>
#include <QStringList>

namespace {

QRegularExpression buildSearchRegex(const SearchQuery& query) {
    QRegularExpression regex;

    if (query.useRegex) {
        QRegularExpression::PatternOptions options;
        if (!query.caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }
        regex.setPattern(query.text);
        regex.setPatternOptions(options);
        return regex;
    }

    QString pattern = QRegularExpression::escape(query.text);
    if (query.wholeWord) {
        pattern = "\\b" + pattern + "\\b";
    }

    QRegularExpression::PatternOptions options;
    if (!query.caseSensitive) {
        options |= QRegularExpression::CaseInsensitiveOption;
    }
    regex.setPattern(pattern);
    regex.setPatternOptions(options);
    return regex;
}

QString replaceTextInternal(const QString& text, const SearchQuery& query,
                            const QString& replacement, int* replacedCount) {
    const QRegularExpression regex = buildSearchRegex(query);
    int count = 0;
    QString result = text;

    // Count matches
    auto it = regex.globalMatch(result);
    while (it.hasNext()) {
        it.next();
        ++count;
    }

    // Perform replacement
    result.replace(regex, replacement);

    if (replacedCount) {
        *replacedCount = count;
    }
    return result;
}

}  // namespace

class SearchService::Impl {
public:
    struct SearchCache {
        QString id;
        SearchQuery query;
        QList<SearchMatch> results;
    };
    
    QList<SearchCache> searchCache;
    static constexpr int MAX_CACHE = 20;
    
    QString generateId() {
        return QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
    
    SearchCache* findCache(const QString& searchId) {
        for (auto& cache : searchCache) {
            if (cache.id == searchId) {
                return &cache;
            }
        }
        return nullptr;
    }
    
    QList<SearchMatch> searchInTextInternal(const QString& text, const SearchQuery& query,
                                             const QString& sourceFile = QString()) {
        QList<SearchMatch> results;
        
        if (query.text.isEmpty()) {
            return results;
        }
        
        QRegularExpression regex;
        if (query.useRegex) {
            QRegularExpression::PatternOptions options;
            if (!query.caseSensitive) {
                options |= QRegularExpression::CaseInsensitiveOption;
            }
            regex.setPattern(query.text);
            regex.setPatternOptions(options);
        } else {
            // Escape special regex chars for literal search
            QString pattern = QRegularExpression::escape(query.text);
            if (query.wholeWord) {
                pattern = "\\b" + pattern + "\\b";
            }
            QRegularExpression::PatternOptions options;
            if (!query.caseSensitive) {
                options |= QRegularExpression::CaseInsensitiveOption;
            }
            regex.setPattern(pattern);
            regex.setPatternOptions(options);
        }
        
        auto lines = text.split('\n');
        for (int lineNum = 0; lineNum < lines.size(); ++lineNum) {
            const auto& line = lines[lineNum];
            
            auto iterator = regex.globalMatch(line);
            while (iterator.hasNext()) {
                auto match = iterator.next();
                
                SearchMatch result;
                result.file = sourceFile;
                result.line = lineNum;
                result.column = match.capturedStart();
                result.length = match.capturedLength();
                result.lineText = line;
                result.matchText = match.captured();
                
                results.append(result);
            }
        }
        
        return results;
    }
};

SearchService* SearchService::instance() {
    static SearchService s_instance;
    return &s_instance;
}

SearchService::SearchService()
    : m_impl(std::make_unique<Impl>()) {
}

SearchService::~SearchService() = default;

QList<SearchMatch> SearchService::search(const SearchQuery& query) {
    QList<SearchMatch> results;
    
    auto fileService = FileService::instance();
    auto workspaceService = WorkspaceService::instance();
    
    // Get files to search in
    QStringList filesToSearch;
    if (query.includePatterns.isEmpty()) {
        // Default to all files
        filesToSearch = workspaceService->findFiles("*");
    } else {
        for (const auto& pattern : query.includePatterns) {
            filesToSearch.append(workspaceService->findFiles(pattern));
        }
    }
    
    // Filter by exclusion patterns
    for (const auto& file : filesToSearch) {
        if (workspaceService->isExcluded(file)) {
            continue;
        }
        
        auto fileResults = searchInFile(file, query);
        results.append(fileResults);
    }
    
    return results;
}

QList<SearchMatch> SearchService::searchInFile(const QString& filePath, const SearchQuery& query) {
    auto fileService = FileService::instance();
    
    QString content = fileService->readFileAsText(filePath);
    return searchInText(content, query, filePath);
}

QList<SearchMatch> SearchService::searchInText(const QString& text, const SearchQuery& query,
                                               const QString& sourceFile) {
    return m_impl->searchInTextInternal(text, query, sourceFile);
}

int SearchService::replaceAll(const SearchQuery& query, const QString& replacement) {
    int totalReplaced = 0;
    
    auto fileService = FileService::instance();
    auto workspaceService = WorkspaceService::instance();
    
    QStringList filesToSearch;
    if (query.includePatterns.isEmpty()) {
        filesToSearch = workspaceService->findFiles("*");
    } else {
        for (const auto& pattern : query.includePatterns) {
            filesToSearch.append(workspaceService->findFiles(pattern));
        }
    }
    
    for (const auto& file : filesToSearch) {
        if (workspaceService->isExcluded(file)) {
            continue;
        }
        
        totalReplaced += replaceInFile(file, query, replacement);
    }
    
    return totalReplaced;
}

int SearchService::replaceInFile(const QString& filePath, const SearchQuery& query,
                                const QString& replacement) {
    auto fileService = FileService::instance();
    
    QString content = fileService->readFileAsText(filePath);
    int replacedCount = 0;
    QString newContent = replaceTextInternal(content, query, replacement, &replacedCount);
    
    if (content != newContent) {
        fileService->writeFileAsText(filePath, newContent);
        return replacedCount;
    }
    
    return 0;
}

int SearchService::replaceInText(const QString& text, const SearchQuery& query,
                                const QString& replacement) {
    int count = 0;
    replaceTextInternal(text, query, replacement, &count);
    return count;
}

QString SearchService::startIncrementalSearch(const SearchQuery& query) {
    auto searchId = m_impl->generateId();
    
    SearchService::Impl::SearchCache cache;
    cache.id = searchId;
    cache.query = query;
    cache.results = search(query);
    
    m_impl->searchCache.append(cache);
    
    if (m_impl->searchCache.size() > m_impl->MAX_CACHE) {
        m_impl->searchCache.removeFirst();
    }
    
    emit searchStarted(searchId);
    emit searchCompleted(searchId, cache.results.size());
    
    return searchId;
}

void SearchService::updateIncrementalSearch(const QString& searchId, const SearchQuery& query) {
    auto cache = m_impl->findCache(searchId);
    if (!cache) {
        return;
    }
    
    cache->query = query;
    cache->results = search(query);
    
    emit searchProgressUpdated(searchId, cache->results.size(), cache->results.size());
}

void SearchService::stopIncrementalSearch(const QString& searchId) {
    for (int i = 0; i < m_impl->searchCache.size(); ++i) {
        if (m_impl->searchCache[i].id == searchId) {
            m_impl->searchCache.removeAt(i);
            emit searchCanceled(searchId);
            return;
        }
    }
}

QList<SearchMatch> SearchService::getSearchResults(const QString& searchId) const {
    auto cache = m_impl->findCache(searchId);
    return cache ? cache->results : QList<SearchMatch>();
}

int SearchService::getResultCount(const QString& searchId) const {
    auto cache = m_impl->findCache(searchId);
    return cache ? cache->results.size() : 0;
}

bool SearchService::hasResults(const QString& searchId) const {
    return getResultCount(searchId) > 0;
}

void SearchService::clearResults(const QString& searchId) {
    auto cache = m_impl->findCache(searchId);
    if (cache) {
        cache->results.clear();
    }
}

QStringList SearchService::findReferences(const QString& symbol) {
    SearchQuery query;
    query.text = symbol;
    query.wholeWord = true;
    
    auto results = search(query);
    QStringList files;
    
    for (const auto& result : results) {
        if (!files.contains(result.file)) {
            files.append(result.file);
        }
    }
    
    return files;
}

QStringList SearchService::findDefinitions(const QString& symbol) {
    // This would typically use LSP
    return findReferences(symbol);
}
