#include "editor/CommentManager.h"
#include <QDebug>

CommentManager::CommentManager(QObject* parent)
    : QObject(parent)
{
    initializeBuiltInSyntax();
}

void CommentManager::initializeBuiltInSyntax()
{
    // C++ style
    registerLanguageSyntax("cpp", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    // C style
    registerLanguageSyntax("c", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    // Python style
    registerLanguageSyntax("python", {
        .lineComment = "#",
        .blockStart = "\"\"\"",
        .blockEnd = "\"\"\"",
        .supportBlockComment = true
    });
    
    // JavaScript/TypeScript
    registerLanguageSyntax("javascript", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    registerLanguageSyntax("typescript", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    // Java
    registerLanguageSyntax("java", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    // HTML/XML
    registerLanguageSyntax("html", {
        .lineComment = "",
        .blockStart = "<!--",
        .blockEnd = "-->",
        .supportBlockComment = true
    });
    
    // Rust
    registerLanguageSyntax("rust", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    // Go
    registerLanguageSyntax("go", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
    
    // QML
    registerLanguageSyntax("qml", {
        .lineComment = "//",
        .blockStart = "/*",
        .blockEnd = "*/",
        .supportBlockComment = true
    });
}

void CommentManager::registerLanguageSyntax(const QString& language, const CommentSyntax& syntax)
{
    m_syntaxMap[language.toLower()] = syntax;
}

CommentSyntax CommentManager::getSyntax(const QString& language) const
{
    QString lang = language.toLower();
    if (m_syntaxMap.contains(lang)) {
        return m_syntaxMap[lang];
    }
    // Default to C++ style
    return m_syntaxMap.value("cpp");
}

QStringList CommentManager::toggleLineComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax)
{
    if (syntax.lineComment.isEmpty()) return lines;

    QStringList result = lines;
    bool allCommented = true;
    for (int i = startLine; i <= endLine; ++i) {
        if (i < 0 || i >= result.size()) continue;
        if (!result[i].trimmed().startsWith(syntax.lineComment)) {
            allCommented = false;
            break;
        }
    }

    if (allCommented) {
        return removeLineComment(lines, startLine, endLine, syntax);
    } else {
        return addLineComment(lines, startLine, endLine, syntax);
    }
}

QStringList CommentManager::toggleBlockComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax)
{
    if (!syntax.supportBlockComment || syntax.blockStart.isEmpty() || syntax.blockEnd.isEmpty()) return lines;

    QString joined = lines.mid(startLine, endLine - startLine + 1).join('\n');
    QString trimmed = joined.trimmed();

    if (trimmed.startsWith(syntax.blockStart) && trimmed.endsWith(syntax.blockEnd)) {
        // Remove block comment
        QString content = joined;
        int startIdx = content.indexOf(syntax.blockStart);
        content.remove(startIdx, syntax.blockStart.length());
        int endIdx = content.lastIndexOf(syntax.blockEnd);
        content.remove(endIdx, syntax.blockEnd.length());

        QStringList result = lines.mid(0, startLine);
        result.append(content.split('\n'));
        result.append(lines.mid(endLine + 1));
        return result;
    } else {
        // Add block comment
        QStringList result = lines.mid(0, startLine);
        QStringList middle = lines.mid(startLine, endLine - startLine + 1);
        if (!middle.isEmpty()) {
            middle[0].prepend(syntax.blockStart);
            middle.last().append(syntax.blockEnd);
        }
        result.append(middle);
        result.append(lines.mid(endLine + 1));
        return result;
    }
}

QStringList CommentManager::addLineComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax)
{
    if (syntax.lineComment.isEmpty()) return lines;

    QStringList result = lines;
    for (int i = startLine; i <= endLine; ++i) {
        if (i >= 0 && i < result.size()) {
            int firstNonSpace = 0;
            while (firstNonSpace < result[i].size() && result[i][firstNonSpace].isSpace()) firstNonSpace++;
            result[i].insert(firstNonSpace, syntax.lineComment + " ");
        }
    }
    return result;
}

QStringList CommentManager::removeLineComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax)
{
    if (syntax.lineComment.isEmpty()) return lines;

    QStringList result = lines;
    for (int i = startLine; i <= endLine; ++i) {
        if (i >= 0 && i < result.size()) {
            int idx = result[i].indexOf(syntax.lineComment);
            if (idx != -1) {
                result[i].remove(idx, syntax.lineComment.length());
                if (idx < result[i].size() && result[i][idx] == ' ') {
                    result[i].remove(idx, 1);
                }
            }
        }
    }
    return result;
}

void CommentManager::toggleLineComment(int startLine, int endLine, const QString& language)
{
    qDebug() << "Toggle line comment" << startLine << "-" << endLine << "(" << language << ")";
    emit linesCommented(startLine, endLine, true);
    emit operationCompleted("toggleLineComment");
}

void CommentManager::toggleBlockComment(int startLine, int endLine, const QString& language)
{
    qDebug() << "Toggle block comment" << startLine << "-" << endLine << "(" << language << ")";
    emit linesCommented(startLine, endLine, true);
    emit operationCompleted("toggleBlockComment");
}

void CommentManager::addLineComment(int startLine, int endLine, const QString& language)
{
    qDebug() << "Add line comment" << startLine << "-" << endLine;
    emit linesCommented(startLine, endLine, true);
    emit operationCompleted("addLineComment");
}

void CommentManager::removeLineComment(int startLine, int endLine, const QString& language)
{
    qDebug() << "Remove line comment" << startLine << "-" << endLine;
    emit linesCommented(startLine, endLine, false);
    emit operationCompleted("removeLineComment");
}

void CommentManager::addBlockComment(int startLine, int endLine, const QString& language)
{
    qDebug() << "Add block comment" << startLine << "-" << endLine;
    emit linesCommented(startLine, endLine, true);
    emit operationCompleted("addBlockComment");
}

void CommentManager::removeBlockComment(int startLine, int endLine, const QString& language)
{
    qDebug() << "Remove block comment" << startLine << "-" << endLine;
    emit linesCommented(startLine, endLine, false);
    emit operationCompleted("removeBlockComment");
}
