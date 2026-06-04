#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QVariantMap>

/**
 * @class WordOperations
 * @brief Handles word-level editing operations
 * 
 * Provides word-level operations:
 * - Delete word (forward/backward)
 * - Move word (forward/backward)
 * - Case conversion (upper/lower/title case)
 * - Word selection
 * - Word boundary detection
 */

class WordOperations : public QObject {
    Q_OBJECT

public:
    explicit WordOperations(QObject *parent = nullptr);
    ~WordOperations() override = default;

    Q_INVOKABLE QVariantMap wordBoundsAt(const QString& text, int line, int column) const;

    enum CaseType {
        Uppercase,
        Lowercase,
        TitleCase,
        ToggleCase
    };

    // Word selection and detection
    struct WordBounds {
        int startLine = -1;
        int startColumn = -1;
        int endLine = -1;
        int endColumn = -1;
        QString word;
    };

    // Find word boundaries at position
    Q_INVOKABLE WordBounds getWordBounds(const QString& text, int line, int column);
    
    // Find next word position
    Q_INVOKABLE void findNextWord(const QString& text, int& line, int& column);
    
    // Find previous word position
    Q_INVOKABLE void findPreviousWord(const QString& text, int& line, int& column);
    
    // Delete word forward (from cursor to end of word)
    Q_INVOKABLE QString deleteWordForward(const QString& text, int line, int column);
    
    // Delete word backward (from start of word to cursor)
    Q_INVOKABLE QString deleteWordBackward(const QString& text, int line, int column);
    
    // Move word forward
    Q_INVOKABLE void moveWordForward(const QString& text, int& line, int& column);
    
    // Move word backward
    Q_INVOKABLE void moveWordBackward(const QString& text, int& line, int& column);
    
    // Convert case for word at position
    Q_INVOKABLE QString convertCase(const QString& text, int line, int column, CaseType caseType);
    
    // Get next word occurrence
    WordBounds findNextWordOccurrence(const QString& text, int line, int column, const QString& word);

signals:
    void wordProcessed(const QString& operation, const QString& result);
    void operationCompleted(const QString& operation);
    void cursorMoved(int line, int column);

private:
    // Helper: Check if character is word character
    static bool isWordChar(QChar ch);
    
    // Helper: Check if character is whitespace
    static bool isWhitespace(QChar ch);
    
    // Helper: Convert word case
    QString convertWordCase(const QString& word, CaseType caseType) const;
    
    // Helper: Convert to camelCase
    QString toCamelCase(const QString& word) const;
    
    // Helper: Convert to snake_case
    QString toSnakeCase(const QString& word) const;
    
    // Helper: Get word at position
    QString getWordAt(const QString& text, int line, int column) const;
};
