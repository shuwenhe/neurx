#include "MultiCursor.h"
#include <algorithm>

MultiCursor::MultiCursor(QObject* parent)
    : QObject(parent) {
}

void MultiCursor::addCursor(CursorPos pos) {
    if (pos == m_mainCursor || hasCursor(pos)) {
        return; // Don't add duplicate
    }

    m_cursors.append(pos);
    sortCursors();
    
    emit cursorAdded(pos.line, pos.column);
    emit cursorCountChanged(cursorCount());
}

void MultiCursor::removeCursor(CursorPos pos) {
    if (m_cursors.removeOne(pos)) {
        emit cursorRemoved(pos.line, pos.column);
        emit cursorCountChanged(cursorCount());
    }
}

void MultiCursor::clearSecondaryCursors() {
    if (!m_cursors.isEmpty()) {
        m_cursors.clear();
        emit cursorCountChanged(1); // Only main cursor remains
    }
}

QList<MultiCursor::CursorPos> MultiCursor::getAllCursors() const {
    QList<CursorPos> all;
    all.append(m_mainCursor);
    all.append(m_cursors);
    std::sort(all.begin(), all.end());
    return all;
}

bool MultiCursor::hasCursor(CursorPos pos) const {
    return m_cursors.contains(pos);
}

MultiCursor::CursorPos MultiCursor::getCursorAtLine(int line) const {
    // Check main cursor first
    if (m_mainCursor.line == line) {
        return m_mainCursor;
    }

    // Check secondary cursors
    for (const auto& cursor : m_cursors) {
        if (cursor.line == line) {
            return cursor;
        }
    }

    return CursorPos();
}

QString MultiCursor::insertAtAllCursors(const QString& text, const QString& insertText) {
    auto lines = text.split('\n');
    auto allCursors = getAllCursors();

    // Insert from last to first to preserve positions
    for (int i = allCursors.size() - 1; i >= 0; --i) {
        const auto& cursor = allCursors[i];
        if (cursor.line >= 0 && cursor.line < lines.size()) {
            QString& line = lines[cursor.line];
            line.insert(cursor.column, insertText);
        }
    }

    return lines.join('\n');
}

QString MultiCursor::deleteAtAllCursors(const QString& text, int deleteCount) {
    auto lines = text.split('\n');
    auto allCursors = getAllCursors();

    // Delete from last to first to preserve positions
    for (int i = allCursors.size() - 1; i >= 0; --i) {
        const auto& cursor = allCursors[i];
        if (cursor.line >= 0 && cursor.line < lines.size()) {
            QString& line = lines[cursor.line];
            int deleteEnd = std::min(cursor.column + deleteCount, (int)line.length());
            line.remove(cursor.column, deleteEnd - cursor.column);
        }
    }

    return lines.join('\n');
}

QString MultiCursor::transformAtAllCursors(const QString& text,
                                          std::function<QString(const QString&, int, int)> transform) {
    auto lines = text.split('\n');
    auto allCursors = getAllCursors();

    // Transform from last to first
    for (int i = allCursors.size() - 1; i >= 0; --i) {
        const auto& cursor = allCursors[i];
        if (cursor.line >= 0 && cursor.line < lines.size()) {
            QString transformResult = transform(lines[cursor.line], cursor.line, cursor.column);
            lines[cursor.line] = transformResult;
        }
    }

    return lines.join('\n');
}

void MultiCursor::sortCursors() {
    std::sort(m_cursors.begin(), m_cursors.end());
}
