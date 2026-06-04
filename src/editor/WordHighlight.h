#ifndef WORDHIGHLIGHT_H
#define WORDHIGHLIGHT_H

#include <QObject>
#include <QString>
#include <QList>
#include <QRegularExpression>

/**
 * Word Highlight - Highlight all occurrences of selected word
 * Similar to VS Code's "Highlight Word on Hover" feature
 */
class WordHighlight : public QObject {
    Q_OBJECT

public:
    explicit WordHighlight(QObject* parent = nullptr);

    // Highlight occurrence information
    struct Highlight {
        int line = 0;
        int column = 0;
        int length = 0;
        bool isCaseSensitive = false;
    };

    /**
     * Find and highlight all occurrences of a word
     * @param text The full text to search in
     * @param word The word to highlight
     * @param caseSensitive Whether to match case
     * @param wholeWord Whether to match whole words only
     * @return List of all occurrences
     */
    QList<Highlight> highlightWord(const QString& text, const QString& word, 
                                   bool caseSensitive = false, 
                                   bool wholeWord = true);

    /**
     * Find occurrences at a specific line/column position
     * @param text The full text
     * @param line The line number
     * @param column The column number
     * @return List of all occurrences of the word at that position
     */
    QList<Highlight> highlightAtPosition(const QString& text, int line, int column);

    /**
     * Get highlights for current editor state
     */
    QList<Highlight> currentHighlights() const { return m_currentHighlights; }

    /**
     * Clear all highlights
     */
    void clearHighlights();

    /**
     * Check if a position is in a highlighted region
     */
    bool isHighlighted(int line, int column) const;

signals:
    void highlightsFound(QList<Highlight> highlights);
    void highlightsCleared();

private:
    // Text utilities
    QString getWordAtPosition(const QString& text, int line, int column) const;
    bool isWordChar(const QChar& ch) const;
    int findWordStart(const QString& line, int column) const;
    int findWordEnd(const QString& line, int column) const;
    
    // Search helpers
    QList<Highlight> findOccurrences(const QString& text, const QString& searchTerm, 
                                     bool caseSensitive, bool wholeWord);

    // State
    QList<Highlight> m_currentHighlights;
    QString m_currentWord;
};

#endif // WORDHIGHLIGHT_H
