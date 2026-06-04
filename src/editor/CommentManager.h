#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>

/**
 * @class CommentManager
 * @brief Manages code commenting operations
 * 
 * Features:
 * - Toggle line comments
 * - Toggle block comments
 * - Add/remove comments
 * - Language-specific comment syntax
 */

struct CommentSyntax {
    QString lineComment;      // "//" for C++
    QString blockStart;       // "/*" for C++
    QString blockEnd;         // "*/" for C++
    bool supportBlockComment = false;
};

class CommentManager : public QObject {
    Q_OBJECT

public:
    explicit CommentManager(QObject* parent = nullptr);
    ~CommentManager() override = default;
    
    // Static text manipulation methods
    static QStringList toggleLineComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax);
    static QStringList toggleBlockComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax);
    static QStringList addLineComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax);
    static QStringList removeLineComment(const QStringList& lines, int startLine, int endLine, const CommentSyntax& syntax);

    // Configuration
    void registerLanguageSyntax(const QString& language, const CommentSyntax& syntax);
    CommentSyntax getSyntax(const QString& language) const;
    
    // Comment operations
    void toggleLineComment(int startLine, int endLine, const QString& language);
    void toggleBlockComment(int startLine, int endLine, const QString& language);
    void addLineComment(int startLine, int endLine, const QString& language);
    void removeLineComment(int startLine, int endLine, const QString& language);
    void addBlockComment(int startLine, int endLine, const QString& language);
    void removeBlockComment(int startLine, int endLine, const QString& language);

signals:
    void linesCommented(int startLine, int endLine, bool commented);
    void operationCompleted(const QString& operation);

private:
    QMap<QString, CommentSyntax> m_syntaxMap;
    
    void initializeBuiltInSyntax();
};
