#ifndef EXPLANATORY_OUTPUT_STYLE_MANAGER_H
#define EXPLANATORY_OUTPUT_STYLE_MANAGER_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <memory>

/**
 * ExplanatoryOutputStyleManager
 *
 * Implements the "Explanatory" output style as a session hook.
 * Provides educational insights about implementation choices and codebase patterns.
 * This recreates the deprecated Explanatory output style functionality.
 *
 * Key Features:
 * - SessionStart hook injection
 * - Educational context generation
 * - Implementation insights
 * - Codebase pattern explanations
 */
class ExplanatoryOutputStyleManager : public QObject {
    Q_OBJECT

public:
    explicit ExplanatoryOutputStyleManager(QObject* parent = nullptr);
    ~ExplanatoryOutputStyleManager();

    // Core functionality
    QString generateSessionStartContext();
    QString generateInsightBox(const QStringList& insights);
    QString generateImplementationExplanation(
        const QString& codeSnippet,
        const QString& fileContext,
        const QString& patternType
    );
    
    // Configuration
    void enableVerboseMode(bool enabled);
    void setMaxInsightPoints(int count);
    void setInsightTemplate(const QString& template_);
    
    // Session management
    QJsonObject getHookContext();
    QString formatEducationalContent(const QString& content);

signals:
    void insightGenerated(const QString& insight);
    void contextInjected(const QJsonObject& context);

private:
    struct InsightPattern {
        QString name;
        QString description;
        QStringList keywords;
    };

    QString generateEducationalInsights(
        const QString& code,
        const QString& context
    );
    QStringList analyzePattern(const QString& code);
    QString formatInsight(const QString& title, const QStringList& points);
    
    bool m_verboseMode;
    int m_maxInsightPoints;
    QString m_insightTemplate;
    QMap<QString, InsightPattern> m_patterns;
};

#endif // EXPLANATORY_OUTPUT_STYLE_MANAGER_H
