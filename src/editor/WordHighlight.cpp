#include "WordHighlight.h"

WordHighlight::WordHighlight(QObject* parent)
    : QObject(parent) {
}

QList<WordHighlight::Highlight> WordHighlight::highlightWord(const QString& text, 
                                                             const QString& word,
                                                             bool caseSensitive,
                                                             bool wholeWord) {
    if (word.isEmpty()) {
        clearHighlights();
        return QList<Highlight>();
    }

    m_currentWord = word;
    m_currentHighlights = findOccurrences(text, word, caseSensitive, wholeWord);
    
    emit highlightsFound(m_currentHighlights);
    return m_currentHighlights;
}

QList<WordHighlight::Highlight> WordHighlight::highlightAtPosition(const QString& text, 
                                                                   int line, 
                                                                   int column) {
    // Get word at position
    QString word = getWordAtPosition(text, line, column);
    
    if (word.isEmpty()) {
        clearHighlights();
        return QList<Highlight>();
    }

    // Find all occurrences with case-insensitive whole-word matching
    return highlightWord(text, word, false, true);
}

void WordHighlight::clearHighlights() {
    m_currentHighlights.clear();
    m_currentWord.clear();
    emit highlightsCleared();
}

bool WordHighlight::isHighlighted(int line, int column) const {
    for (const auto& highlight : m_currentHighlights) {
        if (highlight.line == line && 
            column >= highlight.column && 
            column < highlight.column + highlight.length) {
            return true;
        }
    }
    return false;
}

QString WordHighlight::getWordAtPosition(const QString& text, int line, int column) const {
    auto lines = text.split('\n');
    
    if (line >= lines.size()) {
        return QString();
    }

    const QString& currentLine = lines[line];
    if (column > currentLine.length()) {
        column = currentLine.length();
    }

    // If at word char, extract whole word
    if (column < currentLine.length() && isWordChar(currentLine[column])) {
        int start = findWordStart(currentLine, column);
        int end = findWordEnd(currentLine, column);
        return currentLine.mid(start, end - start);
    }

    // If before word char, try next position
    if (column < currentLine.length() && isWordChar(currentLine[column])) {
        int start = findWordStart(currentLine, column);
        int end = findWordEnd(currentLine, column);
        return currentLine.mid(start, end - start);
    }

    return QString();
}

bool WordHighlight::isWordChar(const QChar& ch) const {
    return ch.isLetterOrNumber() || ch == '_';
}

int WordHighlight::findWordStart(const QString& line, int column) const {
    if (column > line.length()) {
        column = line.length();
    }

    while (column > 0 && isWordChar(line[column - 1])) {
        --column;
    }

    return column;
}

int WordHighlight::findWordEnd(const QString& line, int column) const {
    while (column < line.length() && isWordChar(line[column])) {
        ++column;
    }

    return column;
}

QList<WordHighlight::Highlight> WordHighlight::findOccurrences(const QString& text,
                                                               const QString& searchTerm,
                                                               bool caseSensitive,
                                                               bool wholeWord) {
    QList<Highlight> results;
    auto lines = text.split('\n');

    // Build regex pattern
    QString pattern = wholeWord ? QString("\\b%1\\b").arg(searchTerm) : searchTerm;
    QRegularExpression regex(pattern, caseSensitive ? QRegularExpression::NoPatternOption 
                                                     : QRegularExpression::CaseInsensitiveOption);

    // Search in each line
    for (int lineNum = 0; lineNum < lines.size(); ++lineNum) {
        const QString& line = lines[lineNum];
        auto matchIterator = regex.globalMatch(line);

        while (matchIterator.hasNext()) {
            auto match = matchIterator.next();
            Highlight highlight;
            highlight.line = lineNum;
            highlight.column = match.capturedStart();
            highlight.length = match.capturedLength();
            highlight.isCaseSensitive = caseSensitive;
            
            results.append(highlight);
        }
    }

    return results;
}
