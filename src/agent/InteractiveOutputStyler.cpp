#include "InteractiveOutputStyler.h"
#include <QDebug>

InteractiveOutputStyler::InteractiveOutputStyler(QObject* parent)
    : QObject(parent) {
    m_preferences.style = Structured;
    m_preferences.level = Intermediate;
    m_preferences.includeExamples = true;
    m_preferences.includeBestPractices = true;
    m_preferences.includeWarnings = true;
    m_preferences.verbosityLevel = 0.7f;
}

InteractiveOutputStyler::~InteractiveOutputStyler() {
}

void InteractiveOutputStyler::setOutputStyle(OutputStyle style) {
    m_preferences.style = style;
    emit styleChanged(QString::number(static_cast<int>(style)));
}

void InteractiveOutputStyler::setContentLevel(ContentLevel level) {
    m_preferences.level = level;
}

void InteractiveOutputStyler::setStylePreferences(const StylePreferences& prefs) {
    m_preferences = prefs;
}

InteractiveOutputStyler::StylePreferences InteractiveOutputStyler::getStylePreferences() const {
    return m_preferences;
}

InteractiveOutputStyler::StyledOutput InteractiveOutputStyler::formatOutput(const QString& rawContent) {
    StyledOutput output;
    output.mainContent = rawContent;
    
    if (m_preferences.includeExamples) {
        output.codeExamples = m_codeExamples;
    }
    if (m_preferences.includeBestPractices) {
        output.bestPractices << "Follow the established code conventions";
        output.bestPractices << "Add meaningful documentation";
        output.bestPractices << "Consider edge cases and error handling";
    }
    
    emit outputFormatted(output);
    return output;
}

QString InteractiveOutputStyler::applyStyleFormatting(const QString& content) {
    QString formatted = content;
    
    switch (m_preferences.style) {
    case Concise:
        formatted = content.left(200) + "...";
        break;
    case Explanatory:
        formatted = "## Explanation\n\n" + content + "\n\n## Key Points\n- Point 1\n- Point 2";
        break;
    case Learning:
        formatted = "**Learning Note**: " + content;
        break;
    case Verbose:
        formatted = content + "\n\n## Additional Context\nMore detailed information...";
        break;
    case Structured:
        formatted = "### Implementation\n\n" + content;
        break;
    default:
        break;
    }
    
    return formatted;
}

void InteractiveOutputStyler::addEducationalContext(const QString& context) {
    m_educationalNotes.append(context);
}

void InteractiveOutputStyler::addCodeExample(const QString& title, const QString& code, const QString& language) {
    m_codeExamples.append(QString("## %1 (%2)\n```%2\n%3\n```").arg(title, language, code));
}

void InteractiveOutputStyler::addBestPractice(const QString& practice) {
    qDebug() << "Added best practice:" << practice;
}

void InteractiveOutputStyler::addWarning(const QString& warning) {
    qDebug() << "Added warning:" << warning;
}

void InteractiveOutputStyler::addAlternative(const QString& alternative) {
    qDebug() << "Added alternative:" << alternative;
}

QString InteractiveOutputStyler::formatForUI(const QString& content, const QString& format) {
    if (format == "markdown") {
        return content;
    } else if (format == "html") {
        QString html = content;
        return "<p>" + html.replace("\n", "</p><p>") + "</p>";
    } else if (format == "plaintext") {
        return content;
    }
    return content;
}

QString InteractiveOutputStyler::formatWithSyntaxHighlight(const QString& code, const QString& language) {
    return QString("```%1\n%2\n```").arg(language, code);
}

InteractiveOutputStyler::StyleStats InteractiveOutputStyler::getStyleStatistics() {
    return m_stats;
}
