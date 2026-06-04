#pragma once

#include <QString>
#include <QObject>

/**
 * @class CaseConverter
 * @brief Converts text between different case styles
 * 
 * Supported conversions:
 * - UPPERCASE
 * - lowercase
 * - Title Case
 * - camelCase
 * - snake_case
 * - CONSTANT_CASE
 * - kebab-case
 */

class CaseConverter : public QObject {
    Q_OBJECT

public:
    explicit CaseConverter(QObject *parent = nullptr);
    ~CaseConverter() override = default;

    enum CaseStyle {
        UpperCase,
        LowerCase,
        TitleCase,
        CamelCase,
        SnakeCase,
        ConstantCase,
        KebabCase,
        PascalCase
    };

    // Convert text to specified case
    static QString convert(const QString& text, CaseStyle style);
    Q_INVOKABLE QString convertText(const QString& text, int style) const;
    
    // Detect word boundaries and convert each word
    static QString convertWord(const QString& word, CaseStyle style);
    
    // Convert multiple words
    static QString convertWords(const QStringList& words, CaseStyle style);
    
    // Detect case style of given text
    static CaseStyle detectStyle(const QString& text);
    Q_INVOKABLE int detectTextStyle(const QString& text) const;

signals:
    void conversionCompleted(const QString& result);

private:
    // Helper functions
    static QString toUpperCase(const QString& text);
    static QString toLowerCase(const QString& text);
    static QString toTitleCase(const QString& text);
    static QString toCamelCase(const QString& text);
    static QString toSnakeCase(const QString& text);
    static QString toConstantCase(const QString& text);
    static QString toKebabCase(const QString& text);
    static QString toPascalCase(const QString& text);
    
    // Extract words from text (splitting on boundaries)
    static QStringList extractWords(const QString& text);
};
