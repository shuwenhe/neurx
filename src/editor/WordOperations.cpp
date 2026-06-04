#include "WordOperations.h"
#include <QRegularExpression>
#include <QDebug>

WordOperations::WordOperations(QObject *parent)
    : QObject(parent)
{
}

QVariantMap WordOperations::wordBoundsAt(const QString &text, int line, int column) const
{
    WordOperations *self = const_cast<WordOperations *>(this);
    const WordBounds bounds = self->getWordBounds(text, line, column);
    QVariantMap result;
    result.insert(QStringLiteral("startLine"), bounds.startLine);
    result.insert(QStringLiteral("startColumn"), bounds.startColumn);
    result.insert(QStringLiteral("endLine"), bounds.endLine);
    result.insert(QStringLiteral("endColumn"), bounds.endColumn);
    result.insert(QStringLiteral("word"), bounds.word);
    result.insert(QStringLiteral("hasWord"), !bounds.word.isEmpty());
    return result;
}

WordOperations::WordBounds WordOperations::getWordBounds(const QString& text, int line, int column)
{
    WordBounds bounds;
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return bounds;
    }
    
    const QString& currentLine = lines[line];
    if (column < 0 || column > currentLine.size()) {
        return bounds;
    }
    
    // Find start of word
    int startCol = column;
    while (startCol > 0 && isWordChar(currentLine[startCol - 1])) {
        startCol--;
    }
    
    // Find end of word
    int endCol = column;
    while (endCol < currentLine.size() && isWordChar(currentLine[endCol])) {
        endCol++;
    }
    
    bounds.startLine = line;
    bounds.startColumn = startCol;
    bounds.endLine = line;
    bounds.endColumn = endCol;
    bounds.word = currentLine.mid(startCol, endCol - startCol);
    
    return bounds;
}

void WordOperations::findNextWord(const QString& text, int& line, int& column)
{
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return;
    }
    
    const QString& currentLine = lines[line];
    
    // Skip current word
    while (column < currentLine.size() && isWordChar(currentLine[column])) {
        column++;
    }
    
    // Skip whitespace
    while (column < currentLine.size() && isWhitespace(currentLine[column])) {
        column++;
    }
    
    // If we're at end of line, move to next line
    if (column >= currentLine.size()) {
        line++;
        column = 0;
        
        while (line < lines.size()) {
            if (line < lines.size() && lines[line].size() > 0) {
                // Skip whitespace at start of line
                while (column < lines[line].size() && isWhitespace(lines[line][column])) {
                    column++;
                }
                if (column < lines[line].size()) {
                    emit cursorMoved(line, column);
                    return;
                }
            }
            line++;
            column = 0;
        }
    }
    
    emit cursorMoved(line, column);
}

void WordOperations::findPreviousWord(const QString& text, int& line, int& column)
{
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return;
    }
    
    // Move back one character first
    if (column > 0) {
        column--;
    } else if (line > 0) {
        line--;
        column = lines[line].size() - 1;
    } else {
        return;
    }
    
    // Skip whitespace
    while ((column >= 0 && isWhitespace(lines[line][column])) || 
           (column < 0 && line > 0)) {
        if (column < 0) {
            line--;
            column = lines[line].size() - 1;
        } else {
            column--;
        }
    }
    
    // Skip word
    while (column >= 0 && isWordChar(lines[line][column])) {
        column--;
    }
    
    // Move to start of word
    column++;
    
    emit cursorMoved(line, column);
}

QString WordOperations::deleteWordForward(const QString& text, int line, int column)
{
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return text;
    }
    
    QString currentLine = lines[line];
    WordBounds bounds = getWordBounds(text, line, column);
    
    if (bounds.startLine < 0) {
        emit operationCompleted("deleteWordForward");
        return text;
    }
    
    // Delete from current position to end of word
    int deleteStart = column;
    int deleteEnd = bounds.endColumn;
    
    if (deleteStart < currentLine.size()) {
        currentLine.remove(deleteStart, deleteEnd - deleteStart);
    }
    
    QStringList result = lines;
    result[line] = currentLine;
    
    emit wordProcessed("deleteWordForward", result.join('\n'));
    emit operationCompleted("deleteWordForward");
    
    return result.join('\n');
}

QString WordOperations::deleteWordBackward(const QString& text, int line, int column)
{
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return text;
    }
    
    QString currentLine = lines[line];
    WordBounds bounds = getWordBounds(text, line, column);
    
    if (bounds.startLine < 0) {
        emit operationCompleted("deleteWordBackward");
        return text;
    }
    
    // Delete from start of word to current position
    int deleteStart = bounds.startColumn;
    int deleteEnd = column;
    
    if (deleteStart >= 0 && deleteEnd > deleteStart) {
        currentLine.remove(deleteStart, deleteEnd - deleteStart);
    }
    
    QStringList result = lines;
    result[line] = currentLine;
    
    emit wordProcessed("deleteWordBackward", result.join('\n'));
    emit operationCompleted("deleteWordBackward");
    
    return result.join('\n');
}

void WordOperations::moveWordForward(const QString& text, int& line, int& column)
{
    findNextWord(text, line, column);
}

void WordOperations::moveWordBackward(const QString& text, int& line, int& column)
{
    findPreviousWord(text, line, column);
}

QString WordOperations::convertCase(const QString& text, int line, int column, CaseType caseType)
{
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return text;
    }
    
    QString currentLine = lines[line];
    WordBounds bounds = getWordBounds(text, line, column);
    
    if (bounds.word.isEmpty()) {
        emit operationCompleted("convertCase");
        return text;
    }
    
    QString convertedWord = convertWordCase(bounds.word, caseType);
    
    currentLine.replace(bounds.startColumn, bounds.word.size(), convertedWord);
    
    QStringList result = lines;
    result[line] = currentLine;
    
    emit wordProcessed("convertCase", result.join('\n'));
    emit operationCompleted("convertCase");
    
    return result.join('\n');
}

WordOperations::WordBounds WordOperations::findNextWordOccurrence(const QString& text, int line, int column, const QString& word)
{
    WordBounds result;
    const QStringList lines = text.split('\n');
    
    for (int l = line; l < lines.size(); ++l) {
        const QString& currentLine = lines[l];
        int startPos = (l == line) ? column : 0;
        
        int pos = currentLine.indexOf(word, startPos);
        if (pos != -1) {
            result.startLine = l;
            result.startColumn = pos;
            result.endLine = l;
            result.endColumn = pos + word.size();
            result.word = word;
            return result;
        }
    }
    
    return result;
}

bool WordOperations::isWordChar(QChar ch)
{
    return ch.isLetterOrNumber() || ch == '_';
}

bool WordOperations::isWhitespace(QChar ch)
{
    return ch.isSpace();
}

QString WordOperations::convertWordCase(const QString& word, CaseType caseType) const
{
    switch (caseType) {
        case Uppercase:
            return word.toUpper();
        
        case Lowercase:
            return word.toLower();
        
        case TitleCase: {
            QString result = word.toLower();
            if (!result.isEmpty()) {
                result[0] = result[0].toUpper();
            }
            return result;
        }
        
        case ToggleCase: {
            QString result;
            for (QChar ch : word) {
                if (ch.isUpper()) {
                    result += ch.toLower();
                } else {
                    result += ch.toUpper();
                }
            }
            return result;
        }
        
        default:
            return word;
    }
}

QString WordOperations::toCamelCase(const QString& word) const
{
    QStringList parts = word.split(QRegularExpression("[_-]"));
    QString result;
    
    for (int i = 0; i < parts.size(); ++i) {
        QString part = parts[i].toLower();
        if (i > 0 && !part.isEmpty()) {
            part[0] = part[0].toUpper();
        }
        result += part;
    }
    
    return result;
}

QString WordOperations::toSnakeCase(const QString& word) const
{
    QString result;
    
    for (int i = 0; i < word.size(); ++i) {
        QChar ch = word[i];
        
        if (ch.isUpper() && i > 0) {
            result += '_';
            result += ch.toLower();
        } else {
            result += ch.toLower();
        }
    }
    
    return result;
}

QString WordOperations::getWordAt(const QString& text, int line, int column) const
{
    WordBounds bounds = const_cast<WordOperations*>(this)->getWordBounds(text, line, column);
    return bounds.word;
}
