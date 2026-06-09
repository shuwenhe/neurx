#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class EnterpriseIntegrationPlatform
 * @brief Enterprise system integration and APIs
 */

class EnterpriseIntegrationPlatform : public QObject {
    Q_OBJECT

public:
    enum SystemType {
        CRM,
        ERP,
        HRM,
        Accounting,
        Analytics,
        Custom
    };

    struct ExternalSystem {
        QString id;
        SystemType type;
        QString name;
        QString apiUrl;
        QString authToken;
        bool active;
    };

    struct IntegrationMapping {
        QString sourceField;
        QString targetField;
        QString transformationRule;
        bool bidirectional;
    };

    explicit EnterpriseIntegrationPlatform(QObject* parent = nullptr);
    ~EnterpriseIntegrationPlatform();

    void registerExternalSystem(const ExternalSystem& system);
    void deregisterExternalSystem(const QString& systemId);
    QVector<ExternalSystem> getAllSystems();

    void createMapping(const QString& sourceSystemId, const QString& targetSystemId, const IntegrationMapping& mapping);
    QVector<IntegrationMapping> getMappings(const QString& sourceSystemId, const QString& targetSystemId);

    QString syncData(const QString& sourceSystemId, const QString& targetSystemId);
    QString syncSpecificEntity(const QString& sourceSystemId, const QString& targetSystemId, const QString& entityId);

    void setupRealTimeSync(const QString& sourceSystemId, const QString& targetSystemId);
    void setupScheduledSync(const QString& sourceSystemId, const QString& targetSystemId, const QString& cronExpression);

    struct SyncLog {
        QString syncId;
        QString sourceSystem;
        QString targetSystem;
        qint64 timestamp;
        QString status;
        int recordsSync;
        QString errorMessage;
    };
    QVector<SyncLog> getSyncLogs(const QString& sourceSystemId, int limit = 100);

signals:
    void syncStarted(const QString& syncId);
    void syncCompleted(const QString& syncId, int recordsSync);
    void syncFailed(const QString& syncId, const QString& error);

private:
    QMap<QString, ExternalSystem> m_systems;
    QVector<SyncLog> m_syncLogs;
};
