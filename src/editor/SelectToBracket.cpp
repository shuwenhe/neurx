#include "SelectToBracket.h"

SelectToBracket::SelectToBracket(QObject* parent)
    : QObject(parent) {
}

SelectToBracket::SelectionBounds SelectToBracket::selectToBracket(const QString& text, int cursorLine, int cursorColumn) {
    QChar currentChar = getCharAt(text, cursorLine, cursorColumn);
    SelectionBounds bounds;

    // If on opening bracket, select to closing bracket
    if (isOpeningBracket(currentChar)) {
        bounds = scanForwardToClosing(text, cursorLine, cursorColumn);
        bounds.startLine = cursorLine;
        bounds.startColumn = cursorColumn;
    }
    // If on closing bracket, select back to opening bracket
    else if (isClosingBracket(currentChar)) {
        bounds = scanBackwardToOpening(text, cursorLine, cursorColumn);
        bounds.endLine = cursorLine;
        bounds.endColumn = cursorColumn + 1; // Include closing bracket
    }
    else {
        // Try to find next bracket forward
        bounds = scanForwardToClosing(text, cursorLine, cursorColumn);
        if (bounds.found) {
            bounds.startLine = cursorLine;
            bounds.startColumn = cursorColumn;
        } else {
            // Or find previous bracket backward
            bounds = scanBackwardToOpening(text, cursorLine, cursorColumn);
            if (bounds.found) {
                bounds.endLine = cursorLine;
                bounds.endColumn = cursorColumn;
            }
        }
    }

    if (bounds.found) {
        emit selectionExpanded(bounds);
    } else {
        emit noBracketFound(cursorLine, cursorColumn);
    }

    return bounds;
}

SelectToBracket::SelectionBounds SelectToBracket::selectBracketPair(const QString& text, int cursorLine, int cursorColumn) {
    SelectionBounds bounds;
    QChar currentChar = getCharAt(text, cursorLine, cursorColumn);

    // If on opening bracket
    if (isOpeningBracket(currentChar)) {
        bounds = scanForwardToClosing(text, cursorLine, cursorColumn);
        bounds.startLine = cursorLine;
        bounds.startColumn = cursorColumn;
    }
    // If on closing bracket
    else if (isClosingBracket(currentChar)) {
        bounds = scanBackwardToOpening(text, cursorLine, cursorColumn);
        bounds.endLine = cursorLine;
        bounds.endColumn = cursorColumn + 1;
    }
    else {
        return bounds;
    }

    if (bounds.found) {
        emit selectionExpanded(bounds);
    }

    return bounds;
}

SelectToBracket::SelectionBounds SelectToBracket::expandSelectionToBracket(const QString& text,
                                                                           int selectionStartLine, int selectionStartColumn,
                                                                           int selectionEndLine, int selectionEndColumn) {
    SelectionBounds bounds;
    auto lines = text.split('\n');

    // Look for opening bracket before start
    for (int line = selectionStartLine; line >= 0; --line) {
        int startCol = (line == selectionStartLine) ? selectionStartColumn - 1 : lines[line].length() - 1;
        
        for (int col = startCol; col >= 0; --col) {
            if (isOpeningBracket(lines[line][col])) {
                bounds.startLine = line;
                bounds.startColumn = col;
                bounds.found = true;
                break;
            }
        }
        
        if (bounds.found) break;
    }

    // Look for closing bracket after end
    for (int line = selectionEndLine; line < lines.size(); ++line) {
        int startCol = (line == selectionEndLine) ? selectionEndColumn : 0;
        
        for (int col = startCol; col < lines[line].length(); ++col) {
            if (isClosingBracket(lines[line][col])) {
                bounds.endLine = line;
                bounds.endColumn = col + 1;
                bounds.found = true;
                break;
            }
        }
        
        if (bounds.found) break;
    }

    if (bounds.found) {
        // Extract selected text
        for (int line = bounds.startLine; line <= bounds.endLine && line < lines.size(); ++line) {
            int startCol = (line == bounds.startLine) ? bounds.startColumn : 0;
            int endCol = (line == bounds.endLine) ? bounds.endColumn : lines[line].length();
            
            bounds.selectedText += lines[line].mid(startCol, endCol - startCol);
            if (line < bounds.endLine) {
                bounds.selectedText += "\n";
            }
        }
        
        emit selectionExpanded(bounds);
    }

    return bounds;
}

bool SelectToBracket::isOpeningBracket(const QChar& ch) const {
    return ch == '(' || ch == '{' || ch == '[';
}

bool SelectToBracket::isClosingBracket(const QChar& ch) const {
    return ch == ')' || ch == '}' || ch == ']';
}

QChar SelectToBracket::getMatchingBracket(const QChar& ch) const {
    if (ch == '(') return ')';
    if (ch == ')') return '(';
    if (ch == '{') return '}';
    if (ch == '}') return '{';
    if (ch == '[') return ']';
    if (ch == ']') return '[';
    return QChar();
}

QChar SelectToBracket::getOpeningBracket(const QChar& ch) const {
    if (ch == ')') return '(';
    if (ch == '}') return '{';
    if (ch == ']') return '[';
    return ch;
}

SelectToBracket::SelectionBounds SelectToBracket::scanForwardToClosing(const QString& text, int startLine, int startColumn) {
    SelectionBounds bounds;
    auto lines = text.split('\n');

    if (startLine >= lines.size() || startColumn >= lines[startLine].length()) {
        return bounds;
    }

    QChar openChar = getCharAt(text, startLine, startColumn);
    
    // Must start on opening bracket
    if (!isOpeningBracket(openChar)) {
        return bounds;
    }

    QChar closeChar = getMatchingBracket(openChar);
    int depth = 0;

    // Scan forward from start position
    for (int line = startLine; line < lines.size(); ++line) {
        int startCol = (line == startLine) ? startColumn : 0;
        
        for (int col = startCol; col < lines[line].length(); ++col) {
            QChar ch = lines[line][col];
            
            if (ch == openChar) {
                depth++;
            } else if (ch == closeChar) {
                depth--;
                if (depth == 0) {
                    bounds.endLine = line;
                    bounds.endColumn = col + 1;
                    bounds.found = true;
                    
                    // Extract text
                    for (int l = startLine; l <= line && l < lines.size(); ++l) {
                        int sc = (l == startLine) ? startColumn : 0;
                        int ec = (l == line) ? col + 1 : lines[l].length();
                        bounds.selectedText += lines[l].mid(sc, ec - sc);
                        if (l < line) {
                            bounds.selectedText += "\n";
                        }
                    }
                    
                    return bounds;
                }
            }
        }
    }

    return bounds;
}

SelectToBracket::SelectionBounds SelectToBracket::scanBackwardToOpening(const QString& text, int startLine, int startColumn) {
    SelectionBounds bounds;
    auto lines = text.split('\n');

    if (startLine >= lines.size() || startColumn >= lines[startLine].length()) {
        return bounds;
    }

    QChar closeChar = getCharAt(text, startLine, startColumn);
    
    // Must start on closing bracket
    if (!isClosingBracket(closeChar)) {
        return bounds;
    }

    QChar openChar = getOpeningBracket(closeChar);
    int depth = 0;

    // Scan backward from start position
    for (int line = startLine; line >= 0; --line) {
        int endCol = (line == startLine) ? startColumn : lines[line].length() - 1;
        
        for (int col = endCol; col >= 0; --col) {
            QChar ch = lines[line][col];
            
            if (ch == closeChar) {
                depth++;
            } else if (ch == openChar) {
                depth--;
                if (depth == 0) {
                    bounds.startLine = line;
                    bounds.startColumn = col;
                    bounds.found = true;
                    
                    // Extract text
                    for (int l = line; l <= startLine && l < lines.size(); ++l) {
                        int sc = (l == line) ? col : 0;
                        int ec = (l == startLine) ? startColumn + 1 : lines[l].length();
                        bounds.selectedText += lines[l].mid(sc, ec - sc);
                        if (l < startLine) {
                            bounds.selectedText += "\n";
                        }
                    }
                    
                    return bounds;
                }
            }
        }
    }

    return bounds;
}

QChar SelectToBracket::getCharAt(const QString& text, int line, int column) const {
    auto lines = text.split('\n');
    if (line >= 0 && line < lines.size() && column >= 0 && column < lines[line].length()) {
        return lines[line][column];
    }
    return QChar();
}

int SelectToBracket::getDepthAtPosition(const QString& text, int line, int column) const {
    int depth = 0;
    auto lines = text.split('\n');

    for (int l = 0; l <= line && l < lines.size(); ++l) {
        int endCol = (l == line) ? column : lines[l].length();
        
        for (int col = 0; col < endCol; ++col) {
            QChar ch = lines[l][col];
            if (isOpeningBracket(ch)) {
                depth++;
            } else if (isClosingBracket(ch)) {
                depth--;
            }
        }
    }

    return depth;
}
