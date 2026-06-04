#include "SmartSelection.h"

SmartSelection::SmartSelection(QObject* parent)
    : QObject(parent), m_currentMode(None) {
}

SmartSelection::SelectionBounds SmartSelection::expandSelection(const QString& text, int cursorLine, int cursorColumn) {
    // If starting new selection, initialize from current position
    if (m_currentMode == None) {
        m_initialLine = cursorLine;
        m_initialColumn = cursorColumn;
    }

    SelectionBounds bounds;

    switch (m_currentMode) {
        case None:
            // Expand to word
            bounds = selectWord(text, cursorLine, cursorColumn);
            m_currentMode = Word;
            m_selectionHistory.clear();
            m_selectionHistory.append(bounds);
            break;

        case Word:
            // Expand to line
            bounds = selectLine(text, cursorLine);
            m_currentMode = Line;
            m_selectionHistory.append(bounds);
            break;

        case Line:
            // Expand to paragraph
            bounds = selectParagraph(text, cursorLine);
            m_currentMode = Paragraph;
            m_selectionHistory.append(bounds);
            break;

        case Paragraph:
            // Expand to all text
            bounds = selectAll(text);
            m_currentMode = AllText;
            m_selectionHistory.append(bounds);
            break;

        case AllText:
            // Already at max, return current
            bounds = m_selectionHistory.last();
            break;
    }

    emit selectionExpanded(bounds);
    emit modeChanged(m_currentMode);
    return bounds;
}

SmartSelection::SelectionBounds SmartSelection::contractSelection() {
    SelectionBounds bounds;

    if (m_selectionHistory.isEmpty()) {
        return bounds;
    }

    if (m_selectionHistory.size() > 1) {
        m_selectionHistory.removeLast();
        bounds = m_selectionHistory.last();
        
        // Update mode
        m_currentMode = static_cast<SelectionMode>(m_selectionHistory.size());
    } else {
        resetSelection();
    }

    emit selectionContracted(bounds);
    emit modeChanged(m_currentMode);
    return bounds;
}

void SmartSelection::resetSelection() {
    m_currentMode = None;
    m_initialLine = 0;
    m_initialColumn = 0;
    m_selectionHistory.clear();
}

SmartSelection::SelectionBounds SmartSelection::selectWord(const QString& text, int line, int column) {
    auto lines = text.split('\n');
    SelectionBounds bounds;

    if (line >= lines.size()) {
        return bounds;
    }

    const QString& currentLine = lines[line];
    if (column > currentLine.length()) {
        column = currentLine.length();
    }

    // Find word boundaries
    int startCol = findWordStart(currentLine, column);
    int endCol = findWordEnd(currentLine, column);

    bounds.startLine = line;
    bounds.startColumn = startCol;
    bounds.endLine = line;
    bounds.endColumn = endCol;
    bounds.selectedText = currentLine.mid(startCol, endCol - startCol);

    return bounds;
}

SmartSelection::SelectionBounds SmartSelection::selectLine(const QString& text, int line) {
    auto lines = text.split('\n');
    SelectionBounds bounds;

    if (line >= lines.size()) {
        return bounds;
    }

    bounds.startLine = line;
    bounds.startColumn = 0;
    bounds.endLine = line;
    bounds.endColumn = lines[line].length();
    bounds.selectedText = lines[line];

    return bounds;
}

SmartSelection::SelectionBounds SmartSelection::selectParagraph(const QString& text, int line) {
    auto lines = text.split('\n');
    SelectionBounds bounds;

    if (line >= lines.size()) {
        return bounds;
    }

    int startLine = findParagraphStart(text, line);
    int endLine = findParagraphEnd(text, line);

    bounds.startLine = startLine;
    bounds.startColumn = 0;
    bounds.endLine = endLine;
    bounds.endColumn = (endLine < lines.size()) ? lines[endLine].length() : 0;

    // Collect text
    for (int i = startLine; i <= endLine && i < lines.size(); ++i) {
        bounds.selectedText += lines[i];
        if (i < endLine) {
            bounds.selectedText += "\n";
        }
    }

    return bounds;
}

SmartSelection::SelectionBounds SmartSelection::selectAll(const QString& text) {
    auto lines = text.split('\n');
    SelectionBounds bounds;

    bounds.startLine = 0;
    bounds.startColumn = 0;
    bounds.endLine = lines.size() - 1;
    bounds.endColumn = (lines.size() > 0) ? lines.last().length() : 0;
    bounds.selectedText = text;

    return bounds;
}

bool SmartSelection::isWordChar(const QChar& ch) const {
    return ch.isLetterOrNumber() || ch == '_';
}

int SmartSelection::findWordStart(const QString& line, int column) const {
    if (column > line.length()) {
        column = line.length();
    }

    // If at space/non-word, move back to find word start
    if (column > 0 && !isWordChar(line[column - 1])) {
        // Skip non-word chars backwards
        while (column > 0 && !isWordChar(line[column - 1])) {
            --column;
        }
    }

    // Find start of word
    while (column > 0 && isWordChar(line[column - 1])) {
        --column;
    }

    return column;
}

int SmartSelection::findWordEnd(const QString& line, int column) const {
    if (column >= line.length()) {
        return line.length();
    }

    // If at non-word, skip to find word
    if (!isWordChar(line[column])) {
        while (column < line.length() && !isWordChar(line[column])) {
            ++column;
        }
    }

    // Find end of word
    while (column < line.length() && isWordChar(line[column])) {
        ++column;
    }

    return column;
}

int SmartSelection::findParagraphStart(const QString& text, int line) const {
    auto lines = text.split('\n');

    // Move up until empty line or start of file
    while (line > 0) {
        if (lines[line - 1].trimmed().isEmpty()) {
            break;
        }
        --line;
    }

    return line;
}

int SmartSelection::findParagraphEnd(const QString& text, int line) const {
    auto lines = text.split('\n');

    // Move down until empty line or end of file
    while (line < lines.size() - 1) {
        if (lines[line + 1].trimmed().isEmpty()) {
            break;
        }
        ++line;
    }

    return line;
}
