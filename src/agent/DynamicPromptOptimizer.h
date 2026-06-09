#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class DynamicPromptOptimizer
 * @brief Dynamic prompt optimization and adaptation
 */

class DynamicPromptOptimizer : public QObject {
    Q_OBJECT

public:
    struct PromptTemplate {
        QString id;
        QString basePrompt;
        QStringList variablePlaceholders;
        QString context;
        float effectiveness;  // 0-1.0
    };

    struct OptimizationStrategy {
        QString name;
        QString description;
        QString strategyType;  // clarity, specificity, structure, examples
        float improvementPotential;
    };

    struct OptimizedPrompt {
        QString originalPrompt;
        QString optimizedPrompt;
        float improvementScore;
        QStringList appliedStrategies;
        QString reasoning;
    };

    explicit DynamicPromptOptimizer(QObject* parent = nullptr);
    ~DynamicPromptOptimizer();

    void registerTemplate(const PromptTemplate& template_);
    QString optimizePrompt(const QString& prompt);
    QString optimizePromptForContext(const QString& prompt, const QJsonObject& context);

    OptimizedPrompt analyzeAndOptimize(const QString& prompt);
    QString suggestImprovements(const QString& prompt);

    void registerStrategy(const OptimizationStrategy& strategy);
    QVector<OptimizationStrategy> getAvailableStrategies();

    QString addExamplesToPrompt(const QString& prompt, const QVector<QString>& examples);
    QString clarifyPrompt(const QString& prompt);
    QString structurePrompt(const QString& prompt);

    struct OptimizationMetrics {
        float originalClarity;
        float optimizedClarity;
        float originalSpecificity;
        float optimizedSpecificity;
        float avgImprovement;
    };
    OptimizationMetrics analyzeOptimizationQuality(const QString& original, const QString& optimized);

signals:
    void promptOptimized(const OptimizedPrompt& result);
    void strategyApplied(const QString& strategyName);

private:
    QMap<QString, PromptTemplate> m_templates;
    QVector<OptimizationStrategy> m_strategies;
    QVector<OptimizedPrompt> m_optimizationHistory;
};
