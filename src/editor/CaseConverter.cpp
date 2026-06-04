#include "CaseConverter.h"
#include <QRegularExpression>
#include <QDebug>

CaseConverter::CaseConverter(QObject *parent)
    : QObject(parent)
{
}

QString CaseConverter::convertText(const QString &text, int style) const
{
    return convert(text, static_cast<CaseStyle>(style));
}

QString CaseConverter::convert(const QString& text, CaseStyle style)
{
    switch (style) {
        case UpperCase:
            return toUpperCase(text);
        case LowerCase:
            return toLowerCase(text);
        case TitleCase:
            return toTitleCase(text);
        case CamelCase:
            return toCamelCase(text);
        case SnakeCase:
            return toSnakeCase(text);
        case ConstantCase:
            return toConstantCase(text);
        case KebabCase:
            return toKebabCase(text);
        case PascalCase:
            return toPascalCase(text);
        default:
            return text;
    }
}

QString CaseConverter::convertWord(const QString& word, CaseStyle style)
{
    return convert(word, style);
}

QString CaseConverter::convertWords(const QStringList& words, CaseStyle style)
{
    QStringList converted;
    for (const QString& word : words) {
        converted.append(convert(word, style));
    }
    return converted.join(" ");
}

CaseConverter::CaseStyle CaseConverter::detectStyle(const QString& text)
{
    // Check for snake_case
    if (text.contains('_')) {
        return SnakeCase;
    }
    
    // Check for kebab-case
    if (text.contains('-')) {
        return KebabCase;
    }
    
    // Check for camelCase
    bool hasMixedCase = false;
    bool startsWithLower = !text.isEmpty() && text[0].isLower();
    
    for (int i = 1; i < text.size(); ++i) {
        if (text[i].isUpper()) {
            hasMixedCase = true;
            break;
        }
    }
    
    if (startsWithLower && hasMixedCase) {
        return CamelCase;
    }
    
    // Check for PascalCase
    bool startsWithUpper = !text.isEmpty() && text[0].isUpper();
    if (startsWithUpper && hasMixedCase) {
        return PascalCase;
    }
    
    // Default based on content
    bool allUpper = text == text.toUpper();
    bool allLower = text == text.toLower();
    
    if (allUpper) return UpperCase;
    if (allLower) return LowerCase;
    
    return TitleCase;
}

int CaseConverter::detectTextStyle(const QString &text) const
{
    return static_cast<int>(detectStyle(text));
}

QString CaseConverter::toUpperCase(const QString& text)
{
    return text.toUpper();
}

QString CaseConverter::toLowerCase(const QString& text)
{
    return text.toLower();
}

QString CaseConverter::toTitleCase(const QString& text)
{
    QStringList words = extractWords(text);
    QStringList result;
    
    for (const QString& word : words) {
        if (word.isEmpty()) continue;
        
        QString titleWord = word.toLower();
        titleWord[0] = titleWord[0].toUpper();
        result.append(titleWord);
    }
    
    return result.join(" ");
}

QString CaseConverter::toCamelCase(const QString& text)
{
    QStringList words = extractWords(text);
    QString result;
    
    for (int i = 0; i < words.size(); ++i) {
        if (words[i].isEmpty()) continue;
        
        if (i == 0) {
            result += words[i].toLower();
        } else {
            QString word = words[i].toLower();
            word[0] = word[0].toUpper();
            result += word;
        }
    }
    
    return result;
}

QString CaseConverter::toSnakeCase(const QString& text)
{
    QStringList words = extractWords(text);
    QStringList result;
    
    for (const QString& word : words) {
        if (!word.isEmpty()) {
            result.append(word.toLower());
        }
    }
    
    return result.join("_");
}

QString CaseConverter::toConstantCase(const QString& text)
{
    return toSnakeCase(text).toUpper();
}

QString CaseConverter::toKebabCase(const QString& text)
{
    QStringList words = extractWords(text);
    QStringList result;
    
    for (const QString& word : words) {
        if (!word.isEmpty()) {
            result.append(word.toLower());
        }
    }
    
    return result.join("-");
}

QString CaseConverter::toPascalCase(const QString& text)
{
    QStringList words = extractWords(text);
    QString result;
    
    for (const QString& word : words) {
        if (word.isEmpty()) continue;
        
        QString pascalWord = word.toLower();
        pascalWord[0] = pascalWord[0].toUpper();
        result += pascalWord;
    }
    
    return result;
}

QStringList CaseConverter::extractWords(const QString& text)
{
    // Split on underscores, hyphens, or camelCase boundaries
    QStringList words;
    QString currentWord;
    
    for (int i = 0; i < text.size(); ++i) {
        QChar ch = text[i];
        
        if (ch == '_' || ch == '-' || ch == ' ') {
            if (!currentWord.isEmpty()) {
                words.append(currentWord);
                currentWord.clear();
            }
        } else if (i > 0 && ch.isUpper() && text[i-1].isLower()) {
            // camelCase boundary
            if (!currentWord.isEmpty()) {
                words.append(currentWord);
                currentWord.clear();
            }
            currentWord += ch;
        } else {
            currentWord += ch;
        }
    }
    
    if (!currentWord.isEmpty()) {
        words.append(currentWord);
    }
    
    return words;
}
