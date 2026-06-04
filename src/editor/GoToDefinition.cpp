#include "GoToDefinition.h"
#include <QRegularExpression>

GoToDefinition::GoToDefinition(QObject* parent)
    : QObject(parent) {
}

GoToDefinition::Definition GoToDefinition::findDefinition(const QString& text, int line, int column) {
    // Get symbol at cursor position
    QString symbol = getWordAtPosition(text, line, column);
    
    if (symbol.isEmpty()) {
        emit definitionNotFound(symbol);
        return Definition();
    }

    // Try to find the definition
    auto definitions = findDefinitions(text, symbol);
    
    if (definitions.isEmpty()) {
        emit definitionNotFound(symbol);
        return Definition();
    }

    Definition result = definitions.first();
    
    // Add to navigation history
    m_navigationHistory.erase(m_navigationHistory.begin() + m_historyIndex + 1, 
                             m_navigationHistory.end());
    m_navigationHistory.append(result);
    m_historyIndex = m_navigationHistory.size() - 1;
    
    emit definitionFound(result);
    return result;
}

QList<GoToDefinition::Definition> GoToDefinition::findDefinitions(const QString& text, const QString& symbol) {
    QList<Definition> results;
    auto lines = text.split('\n');

    // Try to find function definition
    Definition funcDef = findFunctionDefinition(text, symbol);
    if (funcDef.found) {
        results.append(funcDef);
    }

    // Try to find class definition
    Definition classDef = findClassDefinition(text, symbol);
    if (classDef.found) {
        results.append(classDef);
    }

    // Try to find variable declaration
    Definition varDef = findVariableDefinition(text, symbol);
    if (varDef.found) {
        results.append(varDef);
    }

    // Try to find enum definition
    Definition enumDef = findEnumDefinition(text, symbol);
    if (enumDef.found) {
        results.append(enumDef);
    }

    return results;
}

GoToDefinition::Definition GoToDefinition::navigateBack() {
    if (canNavigateBack()) {
        --m_historyIndex;
        Definition result = m_navigationHistory[m_historyIndex];
        emit navigationChanged(result);
        return result;
    }
    return Definition();
}

GoToDefinition::Definition GoToDefinition::navigateForward() {
    if (canNavigateForward()) {
        ++m_historyIndex;
        Definition result = m_navigationHistory[m_historyIndex];
        emit navigationChanged(result);
        return result;
    }
    return Definition();
}

QString GoToDefinition::getWordAtPosition(const QString& text, int line, int column) const {
    auto lines = text.split('\n');
    
    if (line >= lines.size()) {
        return QString();
    }

    const QString& currentLine = lines[line];
    if (column > currentLine.length()) {
        column = currentLine.length();
    }

    if (column < currentLine.length() && isWordChar(currentLine[column])) {
        int start = findWordStart(currentLine, column);
        int end = findWordEnd(currentLine, column);
        return currentLine.mid(start, end - start);
    }

    if (column > 0 && isWordChar(currentLine[column - 1])) {
        int start = findWordStart(currentLine, column - 1);
        int end = findWordEnd(currentLine, column - 1);
        return currentLine.mid(start, end - start);
    }

    return QString();
}

bool GoToDefinition::isWordChar(const QChar& ch) const {
    return ch.isLetterOrNumber() || ch == '_';
}

int GoToDefinition::findWordStart(const QString& line, int column) const {
    while (column > 0 && isWordChar(line[column - 1])) {
        --column;
    }
    return column;
}

int GoToDefinition::findWordEnd(const QString& line, int column) const {
    while (column < line.length() && isWordChar(line[column])) {
        ++column;
    }
    return column;
}

GoToDefinition::Definition GoToDefinition::findFunctionDefinition(const QString& text, const QString& symbol) {
    Definition result;
    auto lines = text.split('\n');

    // Pattern: function definition (function name followed by parentheses)
    // Supports: function name(), void name(), Type name(), etc.
    QRegularExpression funcPattern(QString("^\\s*(?:void|int|bool|QString|auto|\\w+\\*?)?\\s+%1\\s*\\(")
                                  .arg(QRegularExpression::escape(symbol)),
                                  QRegularExpression::MultilineOption);

    for (int i = 0; i < lines.size(); ++i) {
        if (funcPattern.match(lines[i]).hasMatch()) {
            result.line = i;
            result.column = lines[i].indexOf(symbol);
            result.symbol = symbol;
            result.type = "function";
            result.found = true;
            result.preview = extractLinePreview(text, i);
            return result;
        }
    }

    return result;
}

GoToDefinition::Definition GoToDefinition::findClassDefinition(const QString& text, const QString& symbol) {
    Definition result;
    auto lines = text.split('\n');

    // Pattern: class/struct definition
    QRegularExpression classPattern(QString("^\\s*(?:class|struct)\\s+%1(?:\\s|:|\\{)")
                                   .arg(QRegularExpression::escape(symbol)));

    for (int i = 0; i < lines.size(); ++i) {
        if (classPattern.match(lines[i]).hasMatch()) {
            result.line = i;
            result.column = lines[i].indexOf(symbol);
            result.symbol = symbol;
            result.type = "class";
            result.found = true;
            result.preview = extractLinePreview(text, i);
            return result;
        }
    }

    return result;
}

GoToDefinition::Definition GoToDefinition::findVariableDefinition(const QString& text, const QString& symbol) {
    Definition result;
    auto lines = text.split('\n');

    // Pattern: variable declaration (type name = or type name;)
    QRegularExpression varPattern(QString("\\b(?:int|bool|QString|auto|float|double|\\w+\\*?)\\s+%1\\s*[=;]")
                                 .arg(QRegularExpression::escape(symbol)));

    for (int i = 0; i < lines.size(); ++i) {
        auto match = varPattern.match(lines[i]);
        if (match.hasMatch()) {
            result.line = i;
            result.column = lines[i].indexOf(symbol);
            result.symbol = symbol;
            result.type = "variable";
            result.found = true;
            result.preview = extractLinePreview(text, i);
            return result;
        }
    }

    return result;
}

GoToDefinition::Definition GoToDefinition::findEnumDefinition(const QString& text, const QString& symbol) {
    Definition result;
    auto lines = text.split('\n');

    // Pattern: enum definition
    QRegularExpression enumPattern(QString("^\\s*enum\\s+(?:class)?\\s+%1\\s*")
                                  .arg(QRegularExpression::escape(symbol)));

    for (int i = 0; i < lines.size(); ++i) {
        if (enumPattern.match(lines[i]).hasMatch()) {
            result.line = i;
            result.column = lines[i].indexOf(symbol);
            result.symbol = symbol;
            result.type = "enum";
            result.found = true;
            result.preview = extractLinePreview(text, i);
            return result;
        }
    }

    return result;
}

QString GoToDefinition::extractLinePreview(const QString& text, int line) const {
    auto lines = text.split('\n');
    if (line >= 0 && line < lines.size()) {
        return lines[line].trimmed();
    }
    return QString();
}
