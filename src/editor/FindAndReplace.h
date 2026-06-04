#ifndef FINDANDREPLACE_H
#define FINDANDREPLACE_H

#include <QObject>
#include <QString>
#include <QList>
#include <QRegularExpression>

/**
 * @class FindAndReplace
 * @brief Advanced find and replace functionality for editor
 * 
 * Features:
 * - Basic text find
 * - Regex pattern support
 * - Case-sensitive/insensitive search
 * - Whole word matching
 * - Replace single or all occurrences
 * - Replace history
 * - Search scope management
 */
class FindAndReplace : public QObject {
    Q_OBJECT

public:
    explicit FindAndReplace(QObject* parent = nullptr);

    // Search configuration
    enum SearchOption {
        None = 0,
        CaseSensitive = 1,
        WholeWord = 2,
        Regex = 4,
        Backward = 8,
        Selection = 16
    };
    Q_DECLARE_FLAGS(SearchOptions, SearchOption)

    // Search result
    struct SearchResult {
        int line = -1;
        int column = -1;
        int length = 0;
        QString text;
        bool found = false;
    };

    // Find next occurrence
    SearchResult findNext(const QString& text, const QString& searchText, 
                         int fromLine = 0, int fromColumn = 0,
                         SearchOptions options = None);

    // Find previous occurrence
    SearchResult findPrevious(const QString& text, const QString& searchText,
                             int fromLine = -1, int fromColumn = -1,
                             SearchOptions options = None);

    // Find all occurrences
    QList<SearchResult> findAll(const QString& text, const QString& searchText,
                               SearchOptions options = None);

    // Replace next occurrence
    struct ReplaceResult {
        QString text;
        int occurrenceCount = 0;
        bool success = false;
    };

    ReplaceResult replaceNext(const QString& text, const QString& searchText,
                              const QString& replaceText, int atLine = 0, int atColumn = 0,
                              SearchOptions options = None);

    // Replace all occurrences
    ReplaceResult replaceAll(const QString& text, const QString& searchText,
                            const QString& replaceText,
                            SearchOptions options = None);

    // Get current search state
    QString currentSearchText() const { return m_currentSearchText; }
    int currentOccurrenceIndex() const { return m_currentOccurrenceIndex; }
    int totalOccurrences() const { return m_allOccurrences.size(); }

    // Clear search state
    void clearSearch();

signals:
    void searchStarted(const QString& text);
    void occurrenceFound(SearchResult result, int index, int total);
    void noMoreOccurrences();
    void replacementMade(int count);
    void searchCompleted(int matchCount);

private:
    // Helper methods
    QString buildSearchPattern(const QString& text, SearchOptions options) const;
    bool isValidRegex(const QString& pattern) const;
    void updateOccurrenceList(const QString& text, const QString& searchText,
                            SearchOptions options);

    // State
    QString m_currentSearchText;
    QList<SearchResult> m_allOccurrences;
    int m_currentOccurrenceIndex = 0;
    SearchOptions m_searchOptions;
};

Q_DECLARE_OPERATORS_FOR_FLAGS(FindAndReplace::SearchOptions)

#endif // FINDANDREPLACE_H
