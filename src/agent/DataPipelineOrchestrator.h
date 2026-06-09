#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class DataPipelineOrchestrator
 * @brief Data pipeline and ETL orchestration
 */

class DataPipelineOrchestrator : public QObject {
    Q_OBJECT

public:
    struct DataSource {
        QString id;
        QString type;  // database, api, file, stream
        QString connection;
        QString query;
        int pollIntervalSeconds;
    };

    struct PipelineStage {
        QString id;
        QString name;
        QString operation;  // transform, filter, aggregate, join
        QJsonObject config;
        QString inputStage;
        bool enabled;
    };

    struct DataPipeline {
        QString id;
        QString name;
        QString description;
        QVector<DataSource> sources;
        QVector<PipelineStage> stages;
        bool enabled;
    };

    explicit DataPipelineOrchestrator(QObject* parent = nullptr);
    ~DataPipelineOrchestrator();

    void createPipeline(const DataPipeline& pipeline);
    void updatePipeline(const DataPipeline& pipeline);
    DataPipeline getPipeline(const QString& pipelineId);
    QVector<DataPipeline> getAllPipelines();

    void addDataSource(const QString& pipelineId, const DataSource& source);
    void addPipelineStage(const QString& pipelineId, const PipelineStage& stage);

    QString executePipeline(const QString& pipelineId);
    void stopPipelineExecution(const QString& executionId);

    struct ExecutionLog {
        QString executionId;
        QString pipelineId;
        QString status;  // running, success, failed
        qint64 startTime;
        qint64 endTime;
        int recordsProcessed;
        QString errorMessage;
    };
    ExecutionLog getExecutionLog(const QString& executionId);

    void scheduleRecurring(const QString& pipelineId, const QString& cronExpression);
    void monitorPipeline(const QString& pipelineId);

signals:
    void pipelineExecutionStarted(const QString& executionId);
    void pipelineExecutionCompleted(const QString& executionId, bool success);
    void stageCompleted(const QString& executionId, const QString& stageId);
    void pipelineError(const QString& executionId, const QString& error);

private:
    QMap<QString, DataPipeline> m_pipelines;
    QVector<ExecutionLog> m_executionLogs;
};
