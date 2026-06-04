#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QPair>
#include <QStringList>

/**
 * @class LineOperations
 * @brief Provides line manipulation operations
 * 
 * Features:
 * - Delete lines
 * - Duplicate lines
 * - Move lines up/down
 * - Sort and reverse
 */

class LineOperations : public QObject {
    Q_OBJECT

public:
    explicit LineOperations(QObject* parent = nullptr);
    ~LineOperations() override = default;
    
    // Static text manipulation methods
    static QStringList deleteLines(const QStringList& lines, const QList<int>& lineIndices);
    static QStringList duplicateLines(const QStringList& lines, int startLine, int endLine);
    static QStringList moveLinesUp(const QStringList& lines, int startLine, int endLine);
    static QStringList moveLinesDown(const QStringList& lines, int startLine, int endLine);
    static QStringList sortLines(const QStringList& lines, int startLine, int endLine, bool ascending = true);
    static QStringList reverseLines(const QStringList& lines, int startLine, int endLine);
    static QStringList removeDuplicateLines(const QStringList& lines, int startLine, int endLine);
    static QStringList trimWhitespace(const QStringList& lines, int startLine, int endLine, bool leading = false, bool trailing = true);
    static QStringList joinLines(const QStringList& lines, int startLine, int endLine);

    // Instance methods (using the static ones)
    void deleteLines(const QList<int>& lines);
    void deleteLine(int line);
    void deleteToLineStart(int line, int column);
    void deleteToLineEnd(int line, int column);
    
    // Line duplication and movement
    void duplicateLines(int startLine, int endLine);
    void moveLineUp(int line);
    void moveLineDown(int line);
    void moveLinesToIndex(int startLine, int endLine, int targetLine);
    
    // Line sorting
    void sortLines(int startLine, int endLine, bool ascending = true);
    void sortLinesDescending(int startLine, int endLine);
    void reverseLines(int startLine, int endLine);
    void removeDuplicateLines(int startLine, int endLine);
    
    // Whitespace operations
    void removeTrailingWhitespace(int startLine, int endLine);
    void removeLeadingWhitespace(int startLine, int endLine);
    void trimAllWhitespace(int startLine, int endLine);
    
    // Line joining
    void joinLines(int startLine, int endLine);
    void joinLinesPreservingIndent(int startLine, int endLine);

signals:
    void linesModified(int startLine, int endLine);
    void lineDeleted(int line);
    void lineDuplicated(int line, int newLine);

private:
    friend class Editor;
};
