#pragma once
#include <QSyntaxHighlighter>
#include <QTextCharFormat>
#include <QRegularExpression>
#include <QList>
#include <QtQuick/QQuickTextDocument>

// ── SyntaxHighlighter ─────────────────────────────────────────────────────────
//  QML-instantiable syntax highlighter.  Bind to a TextArea via:
//      SyntaxHighlighter { textDocument: editorArea.textDocument; language: "cpp" }

class SyntaxHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument* textDocument READ textDocument
               WRITE setTextDocument NOTIFY textDocumentChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)

public:
    explicit SyntaxHighlighter(QObject *parent = nullptr);

    QQuickTextDocument *textDocument() const { return m_quickDoc; }
    void setTextDocument(QQuickTextDocument *doc);

    QString language() const { return m_language; }
    void setLanguage(const QString &lang);

signals:
    void textDocumentChanged();
    void languageChanged();

protected:
    void highlightBlock(const QString &text) override;

private:
    struct Rule {
        QRegularExpression pattern;
        QTextCharFormat    format;
    };

    void rebuildRules();
    void setupCpp();
    void setupPython();
    void setupJavaScript();
    void setupQml();
    void setupJson();
    void setupShell();
    void setupMarkdown();

    QList<Rule>           m_rules;
    QTextCharFormat       m_mlCommentFmt;
    QRegularExpression    m_mlCommentStart;
    QRegularExpression    m_mlCommentEnd;
    bool                  m_hasMultiLine = false;

    QQuickTextDocument   *m_quickDoc  = nullptr;
    QString               m_language;
};
