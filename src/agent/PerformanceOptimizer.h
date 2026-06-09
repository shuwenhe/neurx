#pragma once

#include <QString>
#include <QObject>
#include <QVector>
#include <memory>

/**
 * @class PerformanceOptimizer
 * @brief Code optimization and performance analysis
 */

class PerformanceOptimizer : public QObject {
    Q_OBJECT

public:
    struct OptimizationSuggestion {
        QString file;
        int line;
        QString suggestion;
        float expectedImprovement;
        QString category;
    };

    struct MemoryProfile {
        int totalMemoryMB;
        int usedMemoryMB;
        QVector<QString> topConsumers;
        float fragmentation;
    };

    explicit PerformanceOptimizer(QObject* parent = nullptr);
    ~PerformanceOptimizer();

    QVector<OptimizationSuggestion> analyzeCode(const QString& filePath);
    MemoryProfile profileMemory();
    QVector<QString> detectBottlenecks();
    float estimateComplexity(const QString& code);
    QString suggestRefactoring(const QString& code);

signals:
    void analysisCompleted();
    void bottleneckDetected(const QString& location);

private:
    QVector<OptimizationSuggestion> m_suggestions;
};
