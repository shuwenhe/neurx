#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class InteractiveOutputStyler
 * @brief Interactive and customizable output styling
 */

class InteractiveOutputStyler : public QObject {
    Q_OBJECT

public:
    enum OutputStyle {
        Concise,
        Explanatory,
        Learning,
        Verbose,
        Structured,
        Creative,
        Technical,
        Minimal
    };

    enum ContentLevel {
        Beginner,
        Intermediate,
        Advanced,
        Expert
    };

    struct StylePreferences {
        OutputStyle style;
        ContentLevel level;
        bool includeExamples;
        bool includeBestPractices;
        bool includeWarnings;
        bool includeAlternatives;
        float verbosityLevel;  // 0-1.0
    };

    struct StyledOutput {
        QString mainContent;
        QStringList educationalNotes;
        QStringList codeExamples;
        QStringList bestPractices;
        QStringList warnings;
        QStringList alternatives;
    };

    explicit InteractiveOutputStyler(QObject* parent = nullptr);
    ~InteractiveOutputStyler();

    void setOutputStyle(OutputStyle style);
    void setContentLevel(ContentLevel level);
    void setStylePreferences(const StylePreferences& prefs);

    StylePreferences getStylePreferences() const;

    StyledOutput formatOutput(const QString& rawContent);
    QString applyStyleFormatting(const QString& content);

    void addEducationalContext(const QString& context);
    void addCodeExample(const QString& title, const QString& code, const QString& language);
    void addBestPractice(const QString& practice);
    void addWarning(const QString& warning);
    void addAlternative(const QString& alternative);

    QString formatForUI(const QString& content, const QString& format);  // markdown, html, plaintext, richtext
    QString formatWithSyntaxHighlight(const QString& code, const QString& language);

    struct StyleStats {
        QString activeStyle;
        int totalOutputs;
        float avgVerbosity;
        QMap<QString, int> styleUsage;
    };
    StyleStats getStyleStatistics();

signals:
    void styleChanged(const QString& newStyle);
    void outputFormatted(const StyledOutput& output);

private:
    StylePreferences m_preferences;
    QVector<QString> m_educationalNotes;
    QVector<QString> m_codeExamples;
    StyleStats m_stats;
};
