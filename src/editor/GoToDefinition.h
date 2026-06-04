#ifndef GOTODEFINITION_H
#define GOTODEFINITION_H

#include <QObject>
#include <QString>
#include <QList>

/**
 * Go To Definition - Navigate to symbol definition
 * Triggered by F12 or Ctrl+Click, jumps to where identifier is defined
 */
class GoToDefinition : public QObject {
    Q_OBJECT

public:
    explicit GoToDefinition(QObject* parent = nullptr);

    // Definition location info
    struct Definition {
        int line = -1;
        int column = 0;
        QString symbol;
        QString type; // "function", "class", "variable", "enum", etc.
        bool found = false;
        QString preview; // Line preview for context
    };

    /**
     * Find definition of symbol at cursor position
     * @param text The full text
     * @param line Current line number
     * @param column Current column number
     * @return Definition info if found
     */
    Definition findDefinition(const QString& text, int line, int column);

    /**
     * Find definitions for a specific symbol
     * @param text The full text
     * @param symbol The symbol name to find
     * @return List of all definitions for this symbol
     */
    QList<Definition> findDefinitions(const QString& text, const QString& symbol);

    /**
     * Navigate back in definition history
     */
    Definition navigateBack();

    /**
     * Navigate forward in definition history
     */
    Definition navigateForward();

    /**
     * Check if we can navigate back
     */
    bool canNavigateBack() const { return m_historyIndex > 0; }

    /**
     * Check if we can navigate forward
     */
    bool canNavigateForward() const { return m_historyIndex < m_navigationHistory.size() - 1; }

signals:
    void definitionFound(Definition definition);
    void definitionNotFound(QString symbol);
    void navigationChanged(Definition current);

private:
    // Symbol detection
    QString getWordAtPosition(const QString& text, int line, int column) const;
    bool isWordChar(const QChar& ch) const;
    int findWordStart(const QString& line, int column) const;
    int findWordEnd(const QString& line, int column) const;

    // Pattern detection for different symbol types
    Definition findFunctionDefinition(const QString& text, const QString& symbol);
    Definition findClassDefinition(const QString& text, const QString& symbol);
    Definition findVariableDefinition(const QString& text, const QString& symbol);
    Definition findEnumDefinition(const QString& text, const QString& symbol);
    
    // Utility
    int getSymbolType(const QString& line, const QString& symbol) const;
    QString extractLinePreview(const QString& text, int line) const;

    // Navigation history
    QList<Definition> m_navigationHistory;
    int m_historyIndex = -1;
};

#endif // GOTODEFINITION_H
