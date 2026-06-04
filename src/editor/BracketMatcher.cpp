#include "BracketMatcher.h"
#include <QDebug>

BracketMatcher::BracketMatcher(QObject *parent)
    : QObject(parent)
{
}

QVariantMap BracketMatcher::matchingBracketAt(const QString &text, int line, int column) const
{
    BracketMatcher *self = const_cast<BracketMatcher *>(this);
    const BracketPair pair = self->findMatchingBracket(text, line, column);
    QVariantMap result;
    result.insert(QStringLiteral("openLine"), pair.openLine);
    result.insert(QStringLiteral("openColumn"), pair.openColumn);
    result.insert(QStringLiteral("closeLine"), pair.closeLine);
    result.insert(QStringLiteral("closeColumn"), pair.closeColumn);
    result.insert(QStringLiteral("openChar"), QString(QChar(pair.openChar)));
    result.insert(QStringLiteral("closeChar"), QString(QChar(pair.closeChar)));
    result.insert(QStringLiteral("hasMatch"), pair.openLine >= 0 && pair.closeLine >= 0);
    return result;
}

BracketPair BracketMatcher::findMatchingBracket(const QString& text, int line, int column)
{
    QChar ch = getCharAt(text, line, column);
    
    if (isOpeningBracket(ch)) {
        return scanForward(text, line, column);
    } else if (isClosingBracket(ch)) {
        return scanBackward(text, line, column);
    }
    
    emit noMatchingBracket();
    return BracketPair();
}

BracketPair BracketMatcher::getMatchingBracket(const QString& text, int line, int column)
{
    return findMatchingBracket(text, line, column);
}

QChar BracketMatcher::getCharAt(const QString& text, int line, int column) const
{
    const QStringList lines = text.split('\n');
    
    if (line < 0 || line >= lines.size()) {
        return QChar();
    }
    
    const QString& currentLine = lines[line];
    if (column < 0 || column >= currentLine.size()) {
        return QChar();
    }
    
    return currentLine[column];
}

bool BracketMatcher::isOpeningBracket(QChar ch)
{
    return ch == '(' || ch == '{' || ch == '[';
}

bool BracketMatcher::isClosingBracket(QChar ch)
{
    return ch == ')' || ch == '}' || ch == ']';
}

QChar BracketMatcher::getMatchingBracketChar(QChar ch)
{
    if (ch == '(') return ')';
    if (ch == ')') return '(';
    if (ch == '{') return '}';
    if (ch == '}') return '{';
    if (ch == '[') return ']';
    if (ch == ']') return '[';
    return QChar();
}

BracketPair BracketMatcher::scanForward(const QString& text, int startLine, int startColumn)
{
    BracketPair result;
    const QStringList lines = text.split('\n');
    
    if (startLine < 0 || startLine >= lines.size()) {
        emit noMatchingBracket();
        return result;
    }
    
    QChar openChar = getCharAt(text, startLine, startColumn);
    if (!isOpeningBracket(openChar)) {
        emit noMatchingBracket();
        return result;
    }
    
    result.openLine = startLine;
    result.openColumn = startColumn;
    result.openChar = openChar.toLatin1();
    result.closeChar = getMatchingBracketChar(openChar).toLatin1();
    
    int depth = 1;
    int currentLine = startLine;
    int currentColumn = startColumn + 1;
    
    while (currentLine < lines.size()) {
        const QString& line = lines[currentLine];
        
        while (currentColumn < line.size()) {
            QChar ch = line[currentColumn];
            
            // Check for same type of bracket
            if (ch == openChar) {
                depth++;
            } else if (ch == QChar(result.closeChar)) {
                depth--;
                if (depth == 0) {
                    result.closeLine = currentLine;
                    result.closeColumn = currentColumn;
                    emit bracketsFound(result);
                    return result;
                }
            }
            
            currentColumn++;
        }
        
        currentLine++;
        currentColumn = 0;
    }
    
    emit noMatchingBracket();
    return BracketPair();
}

BracketPair BracketMatcher::scanBackward(const QString& text, int startLine, int startColumn)
{
    BracketPair result;
    const QStringList lines = text.split('\n');
    
    if (startLine < 0 || startLine >= lines.size()) {
        emit noMatchingBracket();
        return result;
    }
    
    QChar closeChar = getCharAt(text, startLine, startColumn);
    if (!isClosingBracket(closeChar)) {
        emit noMatchingBracket();
        return result;
    }
    
    result.closeLine = startLine;
    result.closeColumn = startColumn;
    result.closeChar = closeChar.toLatin1();
    result.openChar = getMatchingBracketChar(closeChar).toLatin1();
    
    int depth = 1;
    int currentLine = startLine;
    int currentColumn = startColumn - 1;
    
    while (currentLine >= 0) {
        const QString& line = lines[currentLine];
        
        while (currentColumn >= 0) {
            QChar ch = line[currentColumn];
            
            // Check for same type of bracket
            if (ch == closeChar) {
                depth++;
            } else if (ch == QChar(result.openChar)) {
                depth--;
                if (depth == 0) {
                    result.openLine = currentLine;
                    result.openColumn = currentColumn;
                    emit bracketsFound(result);
                    return result;
                }
            }
            
            currentColumn--;
        }
        
        currentLine--;
        if (currentLine >= 0) {
            currentColumn = lines[currentLine].size() - 1;
        }
    }
    
    emit noMatchingBracket();
    return BracketPair();
}

QString BracketMatcher::prepareText(const QString& text) const
{
    return text;
}

int BracketMatcher::getPositionInFlattened(const QString& text, int line, int column) const
{
    const QStringList lines = text.split('\n');
    int pos = 0;
    
    for (int i = 0; i < line && i < lines.size(); ++i) {
        pos += lines[i].size() + 1; // +1 for newline
    }
    
    pos += column;
    return pos;
}

void BracketMatcher::convertFromFlattened(const QString& text, int pos, int& line, int& column) const
{
    const QStringList lines = text.split('\n');
    line = 0;
    column = 0;
    int currentPos = 0;
    
    for (int i = 0; i < lines.size(); ++i) {
        int lineLength = lines[i].size() + 1; // +1 for newline
        if (currentPos + lineLength > pos) {
            line = i;
            column = pos - currentPos;
            return;
        }
        currentPos += lineLength;
    }
}
