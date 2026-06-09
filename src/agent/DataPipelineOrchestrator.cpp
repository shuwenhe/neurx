#include "DataPipelineOrchestrator.h"
#include <QDebug>
#include <QDateTime>

DataPipelineOrchestrator::DataPipelineOrchestrator(QObject* parent)
    : QObject(parent) {
}

DataPipelineOrchestrator::~DataPipelineOrchestrator() {
}

void DataPipelineOrchestrator::createPipeline(const DataPipeline& pipeline) {
    m_pipelines[pipeline.id] = pipeline;
}

void DataPipelineOrchestrator::updatePipeline(const DataPipeline& pipeline) {
    if (m_pipelines.contains(pipeline.id)) {
        m_pipelines[pipeline.id] = pipeline;
    }
}

DataPipelineOrchestrator::DataPipeline DataPipelineOrchestrator::getPipeline(const QString& pipelineId) {
    return m_pipelines.value(pipelineId);
}

QVector<DataPipelineOrchestrator::DataPipeline> DataPipelineOrchestrator::getAllPipelines() {
    return QVector<DataPipeline>(m_pipelines.values().begin(), m_pipelines.values().end());
}

void DataPipelineOrchestrator::addDataSource(const QString& pipelineId, const DataSource& source) {
    if (m_pipelines.contains(pipelineId)) {
        m_pipelines[pipelineId].sources.append(source);
    }
}

void DataPipelineOrchestrator::addPipelineStage(const QString& pipelineId, const PipelineStage& stage) {
    if (m_pipelines.contains(pipelineId)) {
        m_pipelines[pipelineId].stages.append(stage);
    }
}

QString DataPipelineOrchestrator::executePipeline(const QString& pipelineId) {
    if (!m_pipelines.contains(pipelineId)) {
        return "";
    }

    ExecutionLog log;
    log.executionId = QString::number(QDateTime::currentMSecsSinceEpoch());
    log.pipelineId = pipelineId;
    log.status = "running";
    log.startTime = QDateTime::currentMSecsSinceEpoch();

    m_executionLogs.append(log);
    emit pipelineExecutionStarted(log.executionId);

    return log.executionId;
}

void DataPipelineOrchestrator::stopPipelineExecution(const QString& executionId) {
    for (auto& log : m_executionLogs) {
        if (log.executionId == executionId) {
            log.status = "stopped";
            break;
        }
    }
}

DataPipelineOrchestrator::ExecutionLog DataPipelineOrchestrator::getExecutionLog(const QString& executionId) {
    for (const auto& log : m_executionLogs) {
        if (log.executionId == executionId) {
            return log;
        }
    }
    return ExecutionLog();
}

void DataPipelineOrchestrator::scheduleRecurring(const QString& pipelineId, const QString& cronExpression) {
    qDebug() << "Scheduled pipeline" << pipelineId << "with cron:" << cronExpression;
}

void DataPipelineOrchestrator::monitorPipeline(const QString& pipelineId) {
    qDebug() << "Monitoring pipeline:" << pipelineId;
}
