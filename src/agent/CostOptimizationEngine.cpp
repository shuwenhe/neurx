#include "CostOptimizationEngine.h"
#include <QDebug>

CostOptimizationEngine::CostOptimizationEngine(QObject* parent)
    : QObject(parent) {
}

CostOptimizationEngine::~CostOptimizationEngine() {
}

void CostOptimizationEngine::recordMetric(const CostMetric& metric) {
    m_metrics.append(metric);
    emit metricsUpdated();
}

CostOptimizationEngine::CostBreakdown CostOptimizationEngine::getCurrentCostBreakdown() {
    CostBreakdown breakdown;
    breakdown.totalCost = 0.0f;
    
    for (const auto& metric : m_metrics) {
        breakdown.totalCost += metric.totalCost;
        breakdown.categoryCosts[metric.category] += metric.totalCost;
    }
    
    breakdown.projectedMonthlyCost = breakdown.totalCost * 30.0f;
    return breakdown;
}

CostOptimizationEngine::CostBreakdown CostOptimizationEngine::getCostBreakdown(qint64 startTime, qint64 endTime) {
    CostBreakdown breakdown;
    breakdown.totalCost = 0.0f;
    
    for (const auto& metric : m_metrics) {
        if (metric.timestamp >= startTime && metric.timestamp <= endTime) {
            breakdown.totalCost += metric.totalCost;
            breakdown.categoryCosts[metric.category] += metric.totalCost;
        }
    }
    
    return breakdown;
}

QVector<CostOptimizationEngine::OptimizationRecommendation> CostOptimizationEngine::getOptimizationRecommendations() {
    return m_recommendations;
}

QVector<CostOptimizationEngine::OptimizationRecommendation> CostOptimizationEngine::getRecommendationsByCategory(const QString& category) {
    QVector<OptimizationRecommendation> results;
    for (const auto& rec : m_recommendations) {
        if (rec.component == category) {
            results.append(rec);
        }
    }
    return results;
}

void CostOptimizationEngine::applyOptimization(const OptimizationRecommendation& recommendation) {
    qDebug() << "Applied optimization:" << recommendation.recommendation;
}

float CostOptimizationEngine::estimateSavings(const OptimizationRecommendation& recommendation) {
    return recommendation.estimatedSavings;
}

void CostOptimizationEngine::setBudgetAlerts(const QVector<BudgetAlert>& alerts) {
    for (const auto& alert : alerts) {
        qDebug() << "Budget alert set:" << alert.alertType << "threshold:" << alert.threshold;
    }
}
