#ifndef AUTO_COMMENT_GENERATOR_H
#define AUTO_COMMENT_GENERATOR_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QMap>
#include <memory>

/**
 * AutoCommentGenerator
 *
 * Generates contextual comments for GitHub issues based on lifecycle events.
 * Features:
 * - Context-aware comment generation
 * - Template-based comments
 * - Lifecycle event-based notifications
 * - Comment threading management
 */
class AutoCommentGenerator : public QObject {
    Q_OBJECT

public:
    enum CommentType {
        LifecycleNudge,
        DuplicateNotification,
        NeedsInfoRequest,
        NeedsReproRequest,
        StaleWarning,
        AutoCloseWarning,
        WontFixNotification,
        ResolvedConfirmation,
        LabelChangeNotification,
        Custom
    };
    
    struct CommentTemplate {
        CommentType type;
        QString title;
        QString bodyTemplate;
        QString botSignature;
        bool includeTimestamp;
    };

    explicit AutoCommentGenerator(QObject* parent = nullptr);
    ~AutoCommentGenerator();

    // Comment generation
    QString generateComment(CommentType type, const QJsonObject& context);
    QString generateLifecycleComment(int issueNumber, const QString& label, int daysInactive);
    QString generateDuplicateComment(int duplicateOfNumber);
    QString generateNeedsInfoComment(const QStringList& missingInfo);
    QString generateNeedsReproComment();
    QString generateStaleWarningComment(int daysInactive);
    QString generateAutoCloseComment(const QString& reason);
    
    // Template management
    void registerTemplate(const CommentTemplate& tmpl);
    CommentTemplate getTemplate(CommentType type) const;
    void updateTemplate(CommentType type, const QString& newBodyTemplate);
    
    // Context-aware generation
    QString fillTemplate(const QString& template_, const QJsonObject& context);
    QString formatWithMarkdown(const QString& text);
    
    // Comment formatting
    QString formatList(const QStringList& items);
    QString formatCode(const QString& code);
    QString formatLink(const QString& text, const QString& url);
    QString formatBold(const QString& text);
    QString formatItalic(const QString& text);
    
    // Bot signature and metadata
    void setBotName(const QString& name);
    void setBotUrl(const QString& url);
    void setIncludeTimestamp(bool include);
    QString getBotSignature() const;
    
    // Configuration
    void setCommentStyle(const QString& style);  // "friendly", "formal", "technical"
    void setIncludeSuggestions(bool include);
    void setMaxCommentLength(int length);

signals:
    void commentGenerated(const QString& comment, CommentType type);
    void templateRegistered(CommentType type);
    void commentFormatted(const QString& formattedComment);

private:
    QString getDefaultTemplate(CommentType type) const;
    QString getCommentStyle() const;
    QString applyCommentStyle(const QString& comment) const;
    QString generateContext(const QJsonObject& data) const;
    
    QMap<CommentType, CommentTemplate> m_templates;
    QString m_botName;
    QString m_botUrl;
    bool m_includeTimestamp;
    QString m_commentStyle;
    bool m_includeSuggestions;
    int m_maxCommentLength;
};

#endif // AUTO_COMMENT_GENERATOR_H
