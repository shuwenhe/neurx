#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

/**
 * @class BracketMatcher
 * @brief Finds and manages matching bracket pairs
 * 
 * Provides bracket matching functionality:
 * - Find matching bracket pairs ()、{}、[]
 * - Jump to matching bracket
 * - Highlight bracket pairs
 * - Support nested brackets
 */

struct BracketPair {
    int openLine = -1;
    int openColumn = -1;
    int closeLine = -1;
    int closeColumn = -1;
    char openChar = 0;
    char closeChar = 0;
};

class BracketMatcher : public QObject {
    Q_OBJECT

public:
    explicit BracketMatcher(QObject *parent = nullptr);
    ~BracketMatcher() override = default;

    Q_INVOKABLE QVariantMap matchingBracketAt(const QString& text, int line, int column) const;

    // Find matching bracket
    BracketPair findMatchingBracket(const QString& text, int line, int column);
    
    // Jump to matching bracket from current position
    BracketPair getMatchingBracket(const QString& text, int line, int column);
    
    // Get character at position
    QChar getCharAt(const QString& text, int line, int column) const;
    
    // Check if character is opening bracket
    static bool isOpeningBracket(QChar ch);
    
    // Check if character is closing bracket
    static bool isClosingBracket(QChar ch);
    
    // Get matching bracket character
    static QChar getMatchingBracketChar(QChar ch);
    
    // Scan forward to find closing bracket
    BracketPair scanForward(const QString& text, int startLine, int startColumn);
    
    // Scan backward to find opening bracket
    BracketPair scanBackward(const QString& text, int startLine, int startColumn);

signals:
    // Emitted when brackets are found
    void bracketsFound(const BracketPair& pair);
    void noMatchingBracket();

private:
    // Helper: Convert text to single string for easier scanning
    QString prepareText(const QString& text) const;
    
    // Helper: Get position in flattened text
    int getPositionInFlattened(const QString& text, int line, int column) const;
    
    // Helper: Convert flattened position back to line/column
    void convertFromFlattened(const QString& text, int pos, int& line, int& column) const;
};
