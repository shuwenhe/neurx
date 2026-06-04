#include "FindAndReplace.h"

FindAndReplace::FindAndReplace(QObject* parent)
    : QObject(parent), m_searchOptions(None) {
}

FindAndReplace::SearchResult FindAndReplace::findNext(const QString& text, const QString& searchText,
                                                      int fromLine, int fromColumn,
                                                      SearchOptions options) {
    SearchResult result;
    auto lines = text.split('\n');

    if (searchText.isEmpty() || lines.isEmpty()) {
        return result;
    }

    // Update occurrence list if new search
    if (searchText != m_currentSearchText || options != m_searchOptions) {
        updateOccurrenceList(text, searchText, options);
        m_currentSearchText = searchText;
        m_searchOptions = options;
        m_currentOccurrenceIndex = 0;
    }

    if (m_allOccurrences.isEmpty()) {
        emit noMoreOccurrences();
        return result;
    }

    // Find next occurrence after fromLine/fromColumn
    for (int i = 0; i < m_allOccurrences.size(); ++i) {
        const auto& occ = m_allOccurrences[i];
        if (occ.line > fromLine || (occ.line == fromLine && occ.column >= fromColumn)) {
            result = occ;
            m_currentOccurrenceIndex = i;
            emit occurrenceFound(result, i, m_allOccurrences.size());
            return result;
        }
    }

    // Wrap around to beginning
    if (!m_allOccurrences.isEmpty()) {
        result = m_allOccurrences.first();
        m_currentOccurrenceIndex = 0;
        emit occurrenceFound(result, 0, m_allOccurrences.size());
    }

    return result;
}

FindAndReplace::SearchResult FindAndReplace::findPrevious(const QString& text, const QString& searchText,
                                                         int fromLine, int fromColumn,
                                                         SearchOptions options) {
    SearchResult result;
    auto lines = text.split('\n');

    if (searchText.isEmpty() || lines.isEmpty()) {
        return result;
    }

    // Update occurrence list if new search
    if (searchText != m_currentSearchText || options != m_searchOptions) {
        updateOccurrenceList(text, searchText, options);
        m_currentSearchText = searchText;
        m_searchOptions = options;
    }

    if (m_allOccurrences.isEmpty()) {
        emit noMoreOccurrences();
        return result;
    }

    // If fromLine not specified, start from end
    if (fromLine < 0) {
        fromLine = lines.size() - 1;
        fromColumn = (fromLine < lines.size()) ? lines[fromLine].length() : 0;
    }

    // Find previous occurrence before fromLine/fromColumn
    for (int i = m_allOccurrences.size() - 1; i >= 0; --i) {
        const auto& occ = m_allOccurrences[i];
        if (occ.line < fromLine || (occ.line == fromLine && occ.column <= fromColumn)) {
            result = occ;
            m_currentOccurrenceIndex = i;
            emit occurrenceFound(result, i, m_allOccurrences.size());
            return result;
        }
    }

    // Wrap around to end
    if (!m_allOccurrences.isEmpty()) {
        result = m_allOccurrences.last();
        m_currentOccurrenceIndex = m_allOccurrences.size() - 1;
        emit occurrenceFound(result, m_currentOccurrenceIndex, m_allOccurrences.size());
    }

    return result;
}

QList<FindAndReplace::SearchResult> FindAndReplace::findAll(const QString& text, const QString& searchText,
                                                            SearchOptions options) {
    updateOccurrenceList(text, searchText, options);
    emit searchCompleted(m_allOccurrences.size());
    return m_allOccurrences;
}

FindAndReplace::ReplaceResult FindAndReplace::replaceNext(const QString& text, const QString& searchText,
                                                          const QString& replaceText, int atLine, int atColumn,
                                                          SearchOptions options) {
    ReplaceResult result;
    auto lines = text.split('\n');

    if (searchText.isEmpty()) {
        return result;
    }

    // Find next occurrence
    auto found = findNext(text, searchText, atLine, atColumn, options);
    if (!found.found) {
        return result;
    }

    // Replace at found location
    if (found.line >= 0 && found.line < lines.size()) {
        QString& line = lines[found.line];
        line.replace(found.column, found.length, replaceText);
        result.text = lines.join('\n');
        result.occurrenceCount = 1;
        result.success = true;
        emit replacementMade(1);
    }

    return result;
}

FindAndReplace::ReplaceResult FindAndReplace::replaceAll(const QString& text, const QString& searchText,
                                                        const QString& replaceText,
                                                        SearchOptions options) {
    ReplaceResult result;
    auto lines = text.split('\n');

    if (searchText.isEmpty()) {
        return result;
    }

    // Find all occurrences
    auto allFound = findAll(text, searchText, options);
    
    if (allFound.isEmpty()) {
        return result;
    }

    // Replace all from end to start (to preserve positions)
    for (int i = allFound.size() - 1; i >= 0; --i) {
        const auto& found = allFound[i];
        if (found.line >= 0 && found.line < lines.size()) {
            QString& line = lines[found.line];
            line.replace(found.column, found.length, replaceText);
        }
    }

    result.text = lines.join('\n');
    result.occurrenceCount = allFound.size();
    result.success = true;
    emit replacementMade(allFound.size());

    return result;
}

void FindAndReplace::clearSearch() {
    m_currentSearchText.clear();
    m_allOccurrences.clear();
    m_currentOccurrenceIndex = 0;
    m_searchOptions = None;
}

QString FindAndReplace::buildSearchPattern(const QString& text, SearchOptions options) const {
    if (options & Regex) {
        return text; // Use as-is for regex
    }

    // Escape special characters for literal search
    return QRegularExpression::escape(text);
}

bool FindAndReplace::isValidRegex(const QString& pattern) const {
    QRegularExpression regex(pattern);
    return regex.isValid();
}

void FindAndReplace::updateOccurrenceList(const QString& text, const QString& searchText,
                                        SearchOptions options) {
    m_allOccurrences.clear();
    m_currentOccurrenceIndex = 0;

    auto lines = text.split('\n');
    if (searchText.isEmpty()) {
        return;
    }

    // Build search pattern
    QString pattern = buildSearchPattern(searchText, options);

    // Create regex with options
    QRegularExpression::PatternOptions regexOptions = QRegularExpression::NoPatternOption;
    if (!(options & CaseSensitive)) {
        regexOptions |= QRegularExpression::CaseInsensitiveOption;
    }

    QRegularExpression regex(pattern, regexOptions);
    if (!regex.isValid()) {
        return;
    }

    // Search in all lines
    for (int lineNum = 0; lineNum < lines.size(); ++lineNum) {
        const QString& line = lines[lineNum];
        auto matchIterator = regex.globalMatch(line);

        while (matchIterator.hasNext()) {
            auto match = matchIterator.next();
            
            // Apply whole word filter if needed
            if (options & WholeWord) {
                // Check word boundaries
                bool isWordStart = (match.capturedStart() == 0 || 
                                  !line[match.capturedStart() - 1].isLetterOrNumber());
                bool isWordEnd = (match.capturedEnd() >= line.length() ||
                                !line[match.capturedEnd()].isLetterOrNumber());
                
                if (!isWordStart || !isWordEnd) {
                    continue;
                }
            }

            SearchResult result;
            result.line = lineNum;
            result.column = match.capturedStart();
            result.length = match.capturedLength();
            result.text = match.captured();
            result.found = true;

            m_allOccurrences.append(result);
        }
    }
}
