#pragma once

#include <QString>
#include <QObject>
#include <QMap>
#include <QVector>
#include <memory>
#include <vector>

/**
 * @class AutonomousIterationEngine
 * @brief AI-powered autonomous iteration and refinement loops
 */

class AutonomousIterationEngine : public QObject {
    Q_OBJECT

public:
    struct IterationConfig {
        QString taskId;
        QString initialTask;
        int maxIterations;
        float successThreshold;
        bool autoExit;
    };

    struct IterationStep {
        int iterationNumber;
        QString taskDescription;
        QString result;
        float qualityScore;
        QString feedback;
        bool requiresRefinement;
    };

    explicit AutonomousIterationEngine(QObject* parent = nullptr);
    ~AutonomousIterationEngine();

    QString startIterationLoop(const IterationConfig& config);
    void submitIterationResult(const QString& loopId, const IterationStep& step);
    void evaluateAndRefinement(const QString& loopId);

    IterationStep getCurrentStep(const QString& loopId);
    QVector<IterationStep> getIterationHistory(const QString& loopId);

    void pauseIteration(const QString& loopId);
    void resumeIteration(const QString& loopId);
    void cancelIteration(const QString& loopId);

    struct LoopStatistics {
        QString loopId;
        int totalIterations;
        float avgQualityScore;
        bool successful;
        QString finalResult;
    };
    LoopStatistics getLoopStatistics(const QString& loopId);

signals:
    void iterationStarted(const QString& loopId);
    void iterationStepCompleted(const QString& loopId, int stepNumber);
    void refinementNeeded(const QString& loopId, const QString& feedback);
    void iterationCompleted(const QString& loopId, bool success);
    void iterationCancelled(const QString& loopId);

private:
    QMap<QString, QVector<IterationStep>> m_iterationHistory;
    QMap<QString, LoopStatistics> m_stats;
};
