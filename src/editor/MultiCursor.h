#ifndef MULTICURSOR_H
#define MULTICURSOR_H

#include <QObject>
#include <QList>

/**
 * @class MultiCursor
 * @brief Manage multiple cursor positions for batch editing
 * 
 * Features:
 * - Add/remove cursor positions
 * - Select multiple text occurrences
 * - Batch edit at all cursors
 * - Cursor history
 */
class MultiCursor : public QObject {
    Q_OBJECT

public:
    explicit MultiCursor(QObject* parent = nullptr);

    // Cursor position
    struct CursorPos {
        int line = 0;
        int column = 0;

        bool operator==(const CursorPos& other) const {
            return line == other.line && column == other.column;
        }

        bool operator<(const CursorPos& other) const {
            if (line != other.line) return line < other.line;
            return column < other.column;
        }
    };

    // Add a cursor at position
    void addCursor(CursorPos pos);

    // Remove cursor at position
    void removeCursor(CursorPos pos);

    // Clear all cursors except main
    void clearSecondaryCursors();

    // Get all cursor positions (sorted)
    QList<CursorPos> getAllCursors() const;

    // Get main cursor
    CursorPos getMainCursor() const { return m_mainCursor; }

    // Set main cursor
    void setMainCursor(CursorPos pos) { m_mainCursor = pos; }

    // Get total cursor count
    int cursorCount() const { return m_cursors.size() + 1; }

    // Check if cursor exists at position
    bool hasCursor(CursorPos pos) const;

    // Get cursor at line (if multiple, return first)
    CursorPos getCursorAtLine(int line) const;

    // Insert text at all cursors
    QString insertAtAllCursors(const QString& text, const QString& insertText);

    // Delete at all cursors
    QString deleteAtAllCursors(const QString& text, int deleteCount = 1);

    // Apply transformation at all cursors
    QString transformAtAllCursors(const QString& text,
                                 std::function<QString(const QString&, int, int)> transform);

signals:
    void cursorAdded(int line, int column);
    void cursorRemoved(int line, int column);
    void cursorCountChanged(int totalCount);

private:
    CursorPos m_mainCursor;
    QList<CursorPos> m_cursors; // Secondary cursors
    
    // Sort cursors by position
    void sortCursors();
};

#endif // MULTICURSOR_H
