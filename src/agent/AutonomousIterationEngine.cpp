#include "AutonomousIterationEngine.h"
#include <QDebug>
#include <QDateTime>

AutonomousIterationEngine::AutonomousIterationEngine(QObject* parent)
    : QObject(parent) {
}

AutonomousIterationEngine::~AutonomousIterationEngine() {
}

QString AutonomousIterationEngine::startIterationLoop(const IterationConfig& config) {
    QString loopId = QString::number(QDateTime::currentMSecsSinceEpoch());
    LoopStatistics stats;
    stats.loopId = loopId;
    stats.totalIterations = 0;
    stats.avgQualityScore = 0.0f;
    stats.successful = false;

    m_stats[loopId] = stats;
    emit iterationStarted(loopId);

    return loopId;
}

void AutonomousIterationEngine::submitIterationResult(const QString& loopId, const IterationStep& step) {
    m_iterationHistory[loopId].append(step);
    emit iterationStepCompleted(loopId, step.iterationNumber);
}

void AutonomousIterationEngine::evaluateAndRefinement(const QString& loopId) {
    if (m_iterationHistory.contains(loopId)) {
        auto& history = m_iterationHistory[loopId];
        if (!history.isEmpty() && history.last().requiresRefinement) {
            emit refinementNeeded(loopId, history.last().feedback);
        }
    }
}

AutonomousIterationEngine::IterationStep AutonomousIterationEngine::getCurrentStep(const QString& loopId) {
    if (m_iterationHistory.contains(loopId) && !m_iterationHistory[loopId].isEmpty()) {
        return m_iterationHistory[loopId].last();
    }
    return IterationStep();
}

QVector<AutonomousIterationEngine::IterationStep> AutonomousIterationEngine::getIterationHistory(const QString& loopId) {
    return m_iterationHistory.value(loopId);
}

void AutonomousIterationEngine::pauseIteration(const QString& loopId) {
    qDebug() << "Paused iteration loop:" << loopId;
}

void AutonomousIterationEngine::resumeIteration(const QString& loopId) {
    qDebug() << "Resumed iteration loop:" << loopId;
}

void AutonomousIterationEngine::cancelIteration(const QString& loopId) {
    emit iterationCancelled(loopId);
}

AutonomousIterationEngine::LoopStatistics AutonomousIterationEngine::getLoopStatistics(const QString& loopId) {
    return m_stats.value(loopId);
}
