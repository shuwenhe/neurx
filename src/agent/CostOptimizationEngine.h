#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class CostOptimizationEngine
 * @brief Cost analysis and optimization recommendations
 */

class CostOptimizationEngine : public QObject {
    Q_OBJECT

public:
    struct CostMetric {
        QString metricName;
        float costPerUnit;
        int usageCount;
        float totalCost;
        QString category;
        qint64 timestamp;
    };

    struct OptimizationRecommendation {
        QString recommendation;
        QString component;
        float estimatedSavings;
        float implementationComplexity;  // 0-1.0
        QString rationale;
    };

    struct CostBreakdown {
        float totalCost;
        QMap<QString, float> categoryCosts;
        QVector<CostMetric> topCostDrivers;
        float projectedMonthlyCost;
    };

    explicit CostOptimizationEngine(QObject* parent = nullptr);
    ~CostOptimizationEngine();

    void recordMetric(const CostMetric& metric);
    CostBreakdown getCurrentCostBreakdown();
    CostBreakdown getCostBreakdown(qint64 startTime, qint64 endTime);

    QVector<OptimizationRecommendation> getOptimizationRecommendations();
    QVector<OptimizationRecommendation> getRecommendationsByCategory(const QString& category);

    void applyOptimization(const OptimizationRecommendation& recommendation);
    float estimateSavings(const OptimizationRecommendation& recommendation);

    struct BudgetAlert {
        QString alertType;
        float threshold;
        float currentUsage;
        bool isTriggered;
    };
    void setBudgetAlerts(const QVector<BudgetAlert>& alerts);

signals:
    void metricsUpdated();
    void recommendationsGenerated();
    void budgetAlertTriggered(const QString& alertType);

private:
    QVector<CostMetric> m_metrics;
    QVector<OptimizationRecommendation> m_recommendations;
};
