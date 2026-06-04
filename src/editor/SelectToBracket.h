#ifndef SELECTTOBRACKET_H
#define SELECTTOBRACKET_H

#include <QObject>
#include <QString>

/**
 * Select To Bracket - Expand selection to matching bracket pair
 * Selects from current position to matching bracket
 */
class SelectToBracket : public QObject {
    Q_OBJECT

public:
    explicit SelectToBracket(QObject* parent = nullptr);

    // Selection bounds
    struct SelectionBounds {
        int startLine = 0;
        int startColumn = 0;
        int endLine = 0;
        int endColumn = 0;
        QString selectedText;
        bool found = false;
    };

    /**
     * Select from cursor to matching bracket
     * @param text The full text
     * @param cursorLine Current line
     * @param cursorColumn Current column
     * @return Selection bounds if bracket found
     */
    SelectionBounds selectToBracket(const QString& text, int cursorLine, int cursorColumn);

    /**
     * Select from bracket to matching bracket (both inclusive)
     * @param text The full text
     * @param cursorLine Current line
     * @param cursorColumn Current column
     * @return Selection bounds including both brackets
     */
    SelectionBounds selectBracketPair(const QString& text, int cursorLine, int cursorColumn);

    /**
     * Expand existing selection to bracket
     * @param text The full text
     * @param selectionStartLine Start of current selection
     * @param selectionStartColumn Start of current selection
     * @param selectionEndLine End of current selection
     * @param selectionEndColumn End of current selection
     * @return Expanded selection bounds
     */
    SelectionBounds expandSelectionToBracket(const QString& text,
                                            int selectionStartLine, int selectionStartColumn,
                                            int selectionEndLine, int selectionEndColumn);

signals:
    void selectionExpanded(SelectionBounds bounds);
    void noBracketFound(int line, int column);

private:
    // Bracket utilities
    bool isOpeningBracket(const QChar& ch) const;
    bool isClosingBracket(const QChar& ch) const;
    QChar getMatchingBracket(const QChar& ch) const;
    QChar getOpeningBracket(const QChar& ch) const;
    
    // Scanning methods
    SelectionBounds scanForwardToClosing(const QString& text, int startLine, int startColumn);
    SelectionBounds scanBackwardToOpening(const QString& text, int startLine, int startColumn);
    SelectionBounds scanToMatchingBracket(const QString& text, int line, int column, bool forward);
    
    // Helper
    QChar getCharAt(const QString& text, int line, int column) const;
    int getDepthAtPosition(const QString& text, int line, int column) const;
};

#endif // SELECTTOBRACKET_H
