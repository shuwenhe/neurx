#ifndef SMARTSELECTION_H
#define SMARTSELECTION_H

#include <QObject>
#include <QString>
#include <QList>

/**
 * Smart Selection - Intelligent text selection expansion
 * Expands selection in layers: word → line → paragraph → file
 */
class SmartSelection : public QObject {
    Q_OBJECT

public:
    explicit SmartSelection(QObject* parent = nullptr);

    // Selection modes
    enum SelectionMode {
        None = 0,
        Word,
        Line,
        Paragraph,
        AllText
    };

    // Get current selection bounds at a position
    struct SelectionBounds {
        int startLine = 0;
        int startColumn = 0;
        int endLine = 0;
        int endColumn = 0;
        QString selectedText;
    };

    /**
     * Expand selection from current position
     * Returns the next selection level bounds
     */
    SelectionBounds expandSelection(const QString& text, int cursorLine, int cursorColumn);

    /**
     * Contract selection back to previous level
     */
    SelectionBounds contractSelection();

    /**
     * Get current selection mode
     */
    SelectionMode currentMode() const { return m_currentMode; }

    /**
     * Reset selection state
     */
    void resetSelection();

signals:
    void selectionExpanded(SelectionBounds bounds);
    void selectionContracted(SelectionBounds bounds);
    void modeChanged(int newMode);

private:
    // Helper methods for different selection levels
    SelectionBounds selectWord(const QString& text, int line, int column);
    SelectionBounds selectLine(const QString& text, int line);
    SelectionBounds selectParagraph(const QString& text, int line);
    SelectionBounds selectAll(const QString& text);

    // Text utilities
    bool isWordChar(const QChar& ch) const;
    int findWordStart(const QString& line, int column) const;
    int findWordEnd(const QString& line, int column) const;
    int findParagraphStart(const QString& text, int line) const;
    int findParagraphEnd(const QString& text, int line) const;

    // State tracking
    SelectionMode m_currentMode = None;
    int m_initialLine = 0;
    int m_initialColumn = 0;
    QList<SelectionBounds> m_selectionHistory;
};

#endif // SMARTSELECTION_H
