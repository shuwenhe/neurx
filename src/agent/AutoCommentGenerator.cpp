#include "AutoCommentGenerator.h"
#include <QDebug>
#include <QDateTime>
#include <QRegularExpression>
#include <QJsonDocument>

namespace {

QString valueToString(const QJsonValue &value)
{
    if (value.isString()) {
        return value.toString();
    }
    if (value.isDouble()) {
        return QString::number(value.toDouble());
    }
    if (value.isBool()) {
        return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    }
    if (value.isArray()) {
        return QString::fromUtf8(QJsonDocument(value.toArray()).toJson(QJsonDocument::Compact));
    }
    if (value.isObject()) {
        return QString::fromUtf8(QJsonDocument(value.toObject()).toJson(QJsonDocument::Compact));
    }
    return value.toVariant().toString();
}

QString joinSuggestions(const QJsonArray &suggestions)
{
    if (suggestions.isEmpty()) {
        return QString();
    }

    QStringList lines;
    for (const auto &item : suggestions) {
        lines << QStringLiteral("- %1").arg(item.toString());
    }
    return lines.join('\n');
}

}

AutoCommentGenerator::AutoCommentGenerator(QObject* parent)
    : QObject(parent), m_botName("Claude Code Bot"), m_botUrl("https://claude.ai/code"),
      m_includeTimestamp(true), m_commentStyle("friendly"), m_includeSuggestions(true),
      m_maxCommentLength(5000)
{
    // Initialize default templates
    registerTemplate({
        LifecycleNudge,
        "Lifecycle Nudge",
        "{{nudge_message}}\n\nThis issue will be closed automatically if there's no activity within {{days}} days.",
        getBotSignature(),
        true
    });
    
    registerTemplate({
        DuplicateNotification,
        "Duplicate Notification",
        "This issue has been automatically detected as a duplicate of #{{duplicate_of}}.\n\n"
        "Please follow the original issue for updates and discussion.",
        getBotSignature(),
        true
    });
    
    registerTemplate({
        NeedsInfoRequest,
        "Needs Information",
        "We need more information to continue investigating:\n{{missing_info}}\n\n"
        "Can you provide these details?",
        getBotSignature(),
        false
    });
    
    registerTemplate({
        NeedsReproRequest,
        "Needs Reproduction",
        "We weren't able to reproduce this. Could you provide:\n\n"
        "1. **Steps to reproduce** - specific actions to trigger the issue\n"
        "2. **Expected behavior** - what should happen\n"
        "3. **Actual behavior** - what currently happens\n"
        "4. **Minimal example** - a small code snippet\n\n"
        "A clear reproduction case helps us fix the issue faster!",
        getBotSignature(),
        false
    });
    
    registerTemplate({
        StaleWarning,
        "Stale Warning",
        "This issue has been inactive for {{days}} days and is now marked as stale.\n\n"
        "If no response is provided soon, it may be automatically closed.",
        getBotSignature(),
        true
    });
    
    registerTemplate({
        AutoCloseWarning,
        "Auto Close Warning",
        "This issue is being automatically closed due to inactivity ({{days}} days).\n\n"
        "Feel free to reopen if you'd like to continue the discussion.",
        getBotSignature(),
        true
    });
}

AutoCommentGenerator::~AutoCommentGenerator()
{
}

QString AutoCommentGenerator::generateComment(CommentType type, const QJsonObject& context)
{
    CommentTemplate tmpl = getTemplate(type);
    if (tmpl.type == Custom) {
        tmpl = {type, "", getDefaultTemplate(type), getBotSignature(), true};
    }
    
    QString comment = fillTemplate(tmpl.bodyTemplate, context);
    
    if (tmpl.includeTimestamp && m_includeTimestamp) {
        comment += "\n\n---\n";
        comment += "*" + QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm") + "*";
    }

    const QString botSignature = tmpl.botSignature.isEmpty() ? getBotSignature() : tmpl.botSignature;
    if (!botSignature.isEmpty()) {
        comment += "\n" + botSignature;
    }

    if (m_includeSuggestions && context.contains("suggestions")) {
        const QString suggestionBlock = joinSuggestions(context.value("suggestions").toArray());
        if (!suggestionBlock.isEmpty()) {
            comment += "\n\n**Suggestions**\n" + suggestionBlock;
        }
    }

    comment = applyCommentStyle(comment);
    if (comment.length() > m_maxCommentLength) {
        comment = comment.left(m_maxCommentLength - 32) + QStringLiteral("\n\n[comment truncated]");
    }
    
    emit commentGenerated(comment, type);
    return comment;
}

QString AutoCommentGenerator::generateLifecycleComment(
    int issueNumber,
    const QString& label,
    int daysInactive)
{
    QJsonObject context;
    context["issue_number"] = issueNumber;
    context["label"] = label;
    context["days"] = daysInactive;
    
    QString nudge;
    if (label == "needs-info") {
        nudge = "We need more information to continue investigating.";
    } else if (label == "needs-repro") {
        nudge = "We weren't able to reproduce this.";
    } else if (label == "stale") {
        nudge = "This issue has been inactive for too long.";
    } else if (label == "autoclose") {
        nudge = "This issue is being automatically closed.";
    }
    
    context["nudge_message"] = nudge;
    
    return generateComment(LifecycleNudge, context);
}

QString AutoCommentGenerator::generateDuplicateComment(int duplicateOfNumber)
{
    QJsonObject context;
    context["duplicate_of"] = duplicateOfNumber;
    
    return generateComment(DuplicateNotification, context);
}

QString AutoCommentGenerator::generateNeedsInfoComment(const QStringList& missingInfo)
{
    QJsonObject context;
    context["missing_info"] = formatList(missingInfo);
    
    return generateComment(NeedsInfoRequest, context);
}

QString AutoCommentGenerator::generateNeedsReproComment()
{
    QJsonObject context;
    return generateComment(NeedsReproRequest, context);
}

QString AutoCommentGenerator::generateStaleWarningComment(int daysInactive)
{
    QJsonObject context;
    context["days"] = daysInactive;
    
    return generateComment(StaleWarning, context);
}

QString AutoCommentGenerator::generateAutoCloseComment(const QString& reason)
{
    QJsonObject context;
    context["reason"] = reason;
    
    return generateComment(AutoCloseWarning, context);
}

void AutoCommentGenerator::registerTemplate(const CommentTemplate& tmpl)
{
    m_templates[tmpl.type] = tmpl;
    emit templateRegistered(tmpl.type);
}

AutoCommentGenerator::CommentTemplate AutoCommentGenerator::getTemplate(CommentType type) const
{
    if (m_templates.contains(type)) {
        return m_templates.value(type);
    }
    return {Custom, "", "", "", false};
}

void AutoCommentGenerator::updateTemplate(CommentType type, const QString& newBodyTemplate)
{
    if (m_templates.contains(type)) {
        CommentTemplate tmpl = m_templates[type];
        tmpl.bodyTemplate = newBodyTemplate;
        m_templates[type] = tmpl;
    }
}

QString AutoCommentGenerator::fillTemplate(const QString& template_, const QJsonObject& context)
{
    QString result = template_;
    
    // Replace {{key}} placeholders with context values
    for (auto it = context.begin(); it != context.end(); ++it) {
        QString placeholder = "{{" + it.key() + "}}";
        result.replace(placeholder, valueToString(it.value()));
    }
    
    return result;
}

QString AutoCommentGenerator::formatWithMarkdown(const QString& text)
{
    QString result = text;
    result.replace("\r\n", "\n");
    result.replace("\r", "\n");
    return result;
}

QString AutoCommentGenerator::formatList(const QStringList& items)
{
    if (items.isEmpty()) {
        return QStringLiteral("- none");
    }
    QString result;
    for (const QString& item : items) {
        result += "- " + item + "\n";
    }
    return result.trimmed();
}

QString AutoCommentGenerator::formatCode(const QString& code)
{
    return "```\n" + code + "\n```";
}

QString AutoCommentGenerator::formatLink(const QString& text, const QString& url)
{
    return "[" + text + "](" + url + ")";
}

QString AutoCommentGenerator::formatBold(const QString& text)
{
    return "**" + text + "**";
}

QString AutoCommentGenerator::formatItalic(const QString& text)
{
    return "*" + text + "*";
}

void AutoCommentGenerator::setBotName(const QString& name)
{
    m_botName = name;
    for (auto it = m_templates.begin(); it != m_templates.end(); ++it) {
        it.value().botSignature = getBotSignature();
    }
}

void AutoCommentGenerator::setBotUrl(const QString& url)
{
    m_botUrl = url;
    for (auto it = m_templates.begin(); it != m_templates.end(); ++it) {
        it.value().botSignature = getBotSignature();
    }
}

void AutoCommentGenerator::setIncludeTimestamp(bool include)
{
    m_includeTimestamp = include;
}

QString AutoCommentGenerator::getBotSignature() const
{
    if (m_botUrl.isEmpty()) {
        return "🤖 Generated by " + m_botName;
    }
    return "[" + QString("🤖 ") + m_botName + "](" + m_botUrl + ")";
}

void AutoCommentGenerator::setCommentStyle(const QString& style)
{
    if (style == "friendly" || style == "formal" || style == "technical") {
        m_commentStyle = style;
    }
}

void AutoCommentGenerator::setIncludeSuggestions(bool include)
{
    m_includeSuggestions = include;
}

void AutoCommentGenerator::setMaxCommentLength(int length)
{
    m_maxCommentLength = qMax(500, length);
}

QString AutoCommentGenerator::getDefaultTemplate(CommentType type) const
{
    switch (type) {
        case LifecycleNudge:
            return "{{nudge_message}}\n\nThis issue will be closed automatically if there's no activity within {{days}} days.";
        
        case DuplicateNotification:
            return "This issue has been automatically detected as a duplicate of #{{duplicate_of}}.";
        
        case NeedsInfoRequest:
            return "We need more information:\n{{missing_info}}";
        
        case NeedsReproRequest:
            return "Could you provide reproduction steps?";
        
        case StaleWarning:
            return "This issue is now marked as stale due to {{days}} days of inactivity.";
        
        case AutoCloseWarning:
            return "This issue is being automatically closed due to inactivity.";
        
        case WontFixNotification:
            return "This issue has been marked as won't fix.";
        
        case ResolvedConfirmation:
            return "This issue has been resolved.";
        
        case LabelChangeNotification:
            return "Labels have been updated.";
        
        case Custom:
        default:
            return "{{message}}";
    }
}

QString AutoCommentGenerator::getCommentStyle() const
{
    return m_commentStyle;
}

QString AutoCommentGenerator::applyCommentStyle(const QString& comment) const
{
    // Apply style-specific formatting
    QString styled = comment;
    
    if (m_commentStyle == "formal") {
        // Make more formal/professional
        styled.replace("Can you", "Could you");
        styled.replace("we need", "We require");
        styled.replace("we're", "we are");
    } else if (m_commentStyle == "technical") {
        // Add technical details
        styled.prepend(QStringLiteral("[Technical] "));
    } else if (m_commentStyle == "friendly") {
        styled.replace("We need", "We'd love to have");
    }
    // "friendly" style uses default
    
    return styled;
}

QString AutoCommentGenerator::generateContext(const QJsonObject& data) const
{
    QString context;
    
    for (auto it = data.begin(); it != data.end(); ++it) {
        context += it.key() + ": " + it.value().toString() + "\n";
    }
    
    return context;
}
