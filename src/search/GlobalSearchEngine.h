#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QVariantMap>
#include <QThread>

/**
 * @class GlobalSearchEngine
 * @brief Performs global search and replace across the workspace
 * 
 * Features:
 * - Regular expression support
 * - Case-sensitive search
 * - Multi-file search and replace
 * - Async search execution
 */

struct SearchResult {
    Q_GADGET
    
public:
    QString filePath;
    int lineNumber = 0;
    int columnNumber = 0;
    QString lineContent;
    int matchStart = 0;
    int matchLength = 0;
    
    QVariantMap toMap() const {
        return QVariantMap{
            {"filePath", filePath},
            {"lineNumber", lineNumber},
            {"columnNumber", columnNumber},
            {"lineContent", lineContent},
            {"matchStart", matchStart},
            {"matchLength", matchLength}
        };
    }
};

class GlobalSearchEngine : public QObject {
    Q_OBJECT

public:
    explicit GlobalSearchEngine(QObject* parent = nullptr);
    ~GlobalSearchEngine() override;
    
    // Search operations
    void search(const QString& pattern, const QString& rootPath, 
                bool useRegex = false, bool caseSensitive = false);
    
    void searchInFile(const QString& filePath, const QString& pattern,
                     bool useRegex = false, bool caseSensitive = false);
    
    // Replace operations
    void replace(const QString& pattern, const QString& replacement,
                 const QString& rootPath, bool useRegex = false);
    
    // Async control
    void cancelSearch();
    bool isSearching() const { return m_isSearching; }
    
    // Statistics
    int resultCount() const { return m_results.size(); }
    int filesSearched() const { return m_filesSearched; }

signals:
    void resultsFound(const QList<QVariantMap>& results);
    void resultAdded(const QVariantMap& result);
    void searchStarted();
    void searchFinished();
    void searchCancelled();
    void error(const QString& message);
    void progressUpdated(int filesSearched);

private:
    void searchDirectory(const QString& dirPath, const QString& pattern,
                        bool useRegex, bool caseSensitive);
    
    QList<SearchResult> m_results;
    int m_filesSearched = 0;
    bool m_isSearching = false;
    bool m_shouldCancel = false;
};
