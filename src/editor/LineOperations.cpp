#include "editor/LineOperations.h"
#include <QDebug>
#include <algorithm>

LineOperations::LineOperations(QObject* parent)
    : QObject(parent)
{
}

QStringList LineOperations::deleteLines(const QStringList& lines, const QList<int>& lineIndices)
{
    QStringList result = lines;
    QList<int> sortedIndices = lineIndices;
    std::sort(sortedIndices.rbegin(), sortedIndices.rend());

    for (int index : sortedIndices) {
        if (index >= 0 && index < result.size()) {
            result.removeAt(index);
        }
    }
    return result;
}

QStringList LineOperations::duplicateLines(const QStringList& lines, int startLine, int endLine)
{
    if (startLine < 0 || endLine >= lines.size() || startLine > endLine) return lines;

    QStringList result = lines;
    QStringList toDuplicate;
    for (int i = startLine; i <= endLine; ++i) {
        toDuplicate.append(lines[i]);
    }

    for (int i = 0; i < toDuplicate.size(); ++i) {
        result.insert(endLine + 1 + i, toDuplicate[i]);
    }
    return result;
}

QStringList LineOperations::moveLinesUp(const QStringList& lines, int startLine, int endLine)
{
    if (startLine <= 0 || endLine >= lines.size() || startLine > endLine) return lines;

    QStringList result = lines;
    QString prevLine = result.takeAt(startLine - 1);
    result.insert(endLine, prevLine);
    return result;
}

QStringList LineOperations::moveLinesDown(const QStringList& lines, int startLine, int endLine)
{
    if (startLine < 0 || endLine >= lines.size() - 1 || startLine > endLine) return lines;

    QStringList result = lines;
    QString nextLine = result.takeAt(endLine + 1);
    result.insert(startLine, nextLine);
    return result;
}

QStringList LineOperations::sortLines(const QStringList& lines, int startLine, int endLine, bool ascending)
{
    if (startLine < 0 || endLine >= lines.size() || startLine > endLine) return lines;

    QStringList result = lines;
    QStringList toSort;
    for (int i = startLine; i <= endLine; ++i) {
        toSort.append(lines[i]);
    }

    if (ascending) {
        std::sort(toSort.begin(), toSort.end());
    } else {
        std::sort(toSort.begin(), toSort.end(), std::greater<QString>());
    }

    for (int i = 0; i < toSort.size(); ++i) {
        result[startLine + i] = toSort[i];
    }
    return result;
}

QStringList LineOperations::reverseLines(const QStringList& lines, int startLine, int endLine)
{
    if (startLine < 0 || endLine >= lines.size() || startLine > endLine) return lines;

    QStringList result = lines;
    for (int i = 0; i <= (endLine - startLine) / 2; ++i) {
        std::swap(result[startLine + i], result[endLine - i]);
    }
    return result;
}

QStringList LineOperations::removeDuplicateLines(const QStringList& lines, int startLine, int endLine)
{
    if (startLine < 0 || endLine >= lines.size() || startLine > endLine) return lines;

    QStringList result = lines.mid(0, startLine);
    QStringList middle = lines.mid(startLine, endLine - startLine + 1);
    QStringList seen;
    for (const QString& line : middle) {
        if (!seen.contains(line)) {
            seen.append(line);
            result.append(line);
        }
    }
    result.append(lines.mid(endLine + 1));
    return result;
}

QStringList LineOperations::trimWhitespace(const QStringList& lines, int startLine, int endLine, bool leading, bool trailing)
{
    QStringList result = lines;
    for (int i = startLine; i <= endLine; ++i) {
        if (i >= 0 && i < result.size()) {
            if (leading && trailing) result[i] = result[i].trimmed();
            else if (leading) {
                int firstNonSpace = 0;
                while (firstNonSpace < result[i].size() && result[i][firstNonSpace].isSpace()) firstNonSpace++;
                result[i] = result[i].mid(firstNonSpace);
            }
            else if (trailing) {
                int lastNonSpace = result[i].size() - 1;
                while (lastNonSpace >= 0 && result[i][lastNonSpace].isSpace()) lastNonSpace--;
                result[i] = result[i].left(lastNonSpace + 1);
            }
        }
    }
    return result;
}

QStringList LineOperations::joinLines(const QStringList& lines, int startLine, int endLine)
{
    if (startLine < 0 || endLine >= lines.size() || startLine >= endLine) return lines;

    QStringList result = lines.mid(0, startLine);
    QString joined = lines.mid(startLine, endLine - startLine + 1).join(" ");
    result.append(joined);
    result.append(lines.mid(endLine + 1));
    return result;
}

void LineOperations::deleteLines(const QList<int>& lines)
{
    if (lines.isEmpty()) return;
    // 按降序删除以保持行号正确
    QList<int> sortedLines = lines;
    std::sort(sortedLines.rbegin(), sortedLines.rend());
    
    for (int line : sortedLines) {
        deleteLine(line);
    }
}

void LineOperations::deleteLine(int line)
{
    qDebug() << "Delete line:" << line;
    emit lineDeleted(line);
}

void LineOperations::deleteToLineStart(int line, int column)
{
    qDebug() << "Delete to line start at" << line << ":" << column;
    emit linesModified(line, line);
}

void LineOperations::deleteToLineEnd(int line, int column)
{
    qDebug() << "Delete to line end at" << line << ":" << column;
    emit linesModified(line, line);
}

void LineOperations::duplicateLines(int startLine, int endLine)
{
    qDebug() << "Duplicate lines" << startLine << "-" << endLine;
    emit lineDuplicated(startLine, endLine + 1);
    emit linesModified(startLine, endLine + (endLine - startLine + 1));
}

void LineOperations::moveLineUp(int line)
{
    if (line > 0) {
        qDebug() << "Move line" << line << "up";
        emit linesModified(line - 1, line);
    }
}

void LineOperations::moveLineDown(int line)
{
    qDebug() << "Move line" << line << "down";
    emit linesModified(line, line + 1);
}

void LineOperations::moveLinesToIndex(int startLine, int endLine, int targetLine)
{
    qDebug() << "Move lines" << startLine << "-" << endLine << "to" << targetLine;
    emit linesModified(startLine, targetLine);
}

void LineOperations::sortLines(int startLine, int endLine, bool ascending)
{
    qDebug() << "Sort lines" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::sortLinesDescending(int startLine, int endLine)
{
    sortLines(startLine, endLine, false);
}

void LineOperations::reverseLines(int startLine, int endLine)
{
    qDebug() << "Reverse lines" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::removeDuplicateLines(int startLine, int endLine)
{
    qDebug() << "Remove duplicate lines" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::removeTrailingWhitespace(int startLine, int endLine)
{
    qDebug() << "Remove trailing whitespace" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::removeLeadingWhitespace(int startLine, int endLine)
{
    qDebug() << "Remove leading whitespace" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::trimAllWhitespace(int startLine, int endLine)
{
    qDebug() << "Trim all whitespace" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::joinLines(int startLine, int endLine)
{
    qDebug() << "Join lines" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}

void LineOperations::joinLinesPreservingIndent(int startLine, int endLine)
{
    qDebug() << "Join lines (preserve indent)" << startLine << "-" << endLine;
    emit linesModified(startLine, endLine);
}
