#include "InlineRename.h"
#include <QRegularExpression>

InlineRename::InlineRename(QObject* parent)
    : QObject(parent) {
}

InlineRename::RenameInfo InlineRename::startRename(const QString& text, int line, int column) {
    m_currentRenameInfo = RenameInfo();

    // Get word at cursor position
    QString word = getWordAtPosition(text, line, column);
    
    if (word.isEmpty() || !isValidIdentifier(word)) {
        emit renameCancelled();
        return m_currentRenameInfo;
    }

    // Find all occurrences
    m_currentRenameInfo.oldName = word;
    m_currentRenameInfo.locations = findRenameLocations(text, word);
    m_currentRenameInfo.occurrences = m_currentRenameInfo.locations.size();

    emit renameStarted(m_currentRenameInfo);
    return m_currentRenameInfo;
}

QString InlineRename::applyRename(const QString& text, const QString& newName) {
    if (!isRenameActive()) {
        return text;
    }

    if (!isValidIdentifier(newName)) {
        return text;
    }

    // Replace all occurrences
    QString result = replaceAllOccurrences(text, m_currentRenameInfo.oldName, newName);
    
    int occurrences = m_currentRenameInfo.occurrences;
    m_currentRenameInfo = RenameInfo();
    
    emit renameApplied(result, occurrences);
    return result;
}

void InlineRename::cancelRename() {
    m_currentRenameInfo = RenameInfo();
    emit renameCancelled();
}

QString InlineRename::getWordAtPosition(const QString& text, int line, int column) const {
    auto lines = text.split('\n');
    
    if (line >= lines.size()) {
        return QString();
    }

    const QString& currentLine = lines[line];
    if (column > currentLine.length()) {
        column = currentLine.length();
    }

    // If at word char, extract whole word
    if (column < currentLine.length() && isWordChar(currentLine[column])) {
        int start = findWordStart(currentLine, column);
        int end = findWordEnd(currentLine, column);
        return currentLine.mid(start, end - start);
    }

    // Try the character before cursor
    if (column > 0 && isWordChar(currentLine[column - 1])) {
        int start = findWordStart(currentLine, column - 1);
        int end = findWordEnd(currentLine, column - 1);
        return currentLine.mid(start, end - start);
    }

    return QString();
}

bool InlineRename::isWordChar(const QChar& ch) const {
    return ch.isLetterOrNumber() || ch == '_';
}

bool InlineRename::isValidIdentifier(const QString& name) const {
    if (name.isEmpty()) return false;
    
    // Must start with letter or underscore
    if (!name[0].isLetter() && name[0] != '_') {
        return false;
    }
    
    // Rest must be alphanumeric or underscore
    for (int i = 1; i < name.length(); ++i) {
        if (!isWordChar(name[i])) {
            return false;
        }
    }
    
    return true;
}

int InlineRename::findWordStart(const QString& line, int column) const {
    if (column > line.length()) {
        column = line.length();
    }

    while (column > 0 && isWordChar(line[column - 1])) {
        --column;
    }

    return column;
}

int InlineRename::findWordEnd(const QString& line, int column) const {
    while (column < line.length() && isWordChar(line[column])) {
        ++column;
    }

    return column;
}

QList<std::pair<int, int>> InlineRename::findRenameLocations(const QString& text, const QString& identifier) {
    QList<std::pair<int, int>> locations;
    auto lines = text.split('\n');

    // Use regex with word boundaries to find exact matches
    QRegularExpression regex(QString("\\b%1\\b").arg(QRegularExpression::escape(identifier)),
                            QRegularExpression::CaseInsensitiveOption);

    for (int lineNum = 0; lineNum < lines.size(); ++lineNum) {
        const QString& line = lines[lineNum];
        auto matchIterator = regex.globalMatch(line);

        while (matchIterator.hasNext()) {
            auto match = matchIterator.next();
            locations.append({lineNum, match.capturedStart()});
        }
    }

    return locations;
}

QString InlineRename::replaceAllOccurrences(const QString& text, 
                                            const QString& oldName, 
                                            const QString& newName) {
    auto lines = text.split('\n');
    
    // Use word boundary regex to replace only whole-word matches
    QRegularExpression regex(QString("\\b%1\\b").arg(QRegularExpression::escape(oldName)));
    
    for (auto& line : lines) {
        line.replace(regex, newName);
    }
    
    return lines.join('\n');
}
