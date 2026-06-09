#include "EnterpriseIntegrationPlatform.h"
#include <QDebug>
#include <QDateTime>

EnterpriseIntegrationPlatform::EnterpriseIntegrationPlatform(QObject* parent)
    : QObject(parent) {
}

EnterpriseIntegrationPlatform::~EnterpriseIntegrationPlatform() {
}

void EnterpriseIntegrationPlatform::registerExternalSystem(const ExternalSystem& system) {
    m_systems[system.id] = system;
}

void EnterpriseIntegrationPlatform::deregisterExternalSystem(const QString& systemId) {
    m_systems.remove(systemId);
}

QVector<EnterpriseIntegrationPlatform::ExternalSystem> EnterpriseIntegrationPlatform::getAllSystems() {
    return QVector<ExternalSystem>(m_systems.values().begin(), m_systems.values().end());
}

void EnterpriseIntegrationPlatform::createMapping(const QString& sourceSystemId, const QString& targetSystemId, const IntegrationMapping& mapping) {
    qDebug() << "Created mapping from" << sourceSystemId << "to" << targetSystemId;
}

QVector<EnterpriseIntegrationPlatform::IntegrationMapping> EnterpriseIntegrationPlatform::getMappings(const QString& sourceSystemId, const QString& targetSystemId) {
    return QVector<IntegrationMapping>();
}

QString EnterpriseIntegrationPlatform::syncData(const QString& sourceSystemId, const QString& targetSystemId) {
    SyncLog log;
    log.syncId = QString::number(QDateTime::currentMSecsSinceEpoch());
    log.sourceSystem = sourceSystemId;
    log.targetSystem = targetSystemId;
    log.timestamp = QDateTime::currentMSecsSinceEpoch();
    log.status = "running";

    m_syncLogs.append(log);
    emit syncStarted(log.syncId);

    return log.syncId;
}

QString EnterpriseIntegrationPlatform::syncSpecificEntity(const QString& sourceSystemId, const QString& targetSystemId, const QString& entityId) {
    qDebug() << "Syncing entity" << entityId;
    return syncData(sourceSystemId, targetSystemId);
}

void EnterpriseIntegrationPlatform::setupRealTimeSync(const QString& sourceSystemId, const QString& targetSystemId) {
    qDebug() << "Real-time sync enabled between" << sourceSystemId << "and" << targetSystemId;
}

void EnterpriseIntegrationPlatform::setupScheduledSync(const QString& sourceSystemId, const QString& targetSystemId, const QString& cronExpression) {
    qDebug() << "Scheduled sync with cron:" << cronExpression;
}

QVector<EnterpriseIntegrationPlatform::SyncLog> EnterpriseIntegrationPlatform::getSyncLogs(const QString& sourceSystemId, int limit) {
    QVector<SyncLog> results;
    int count = 0;
    for (int i = m_syncLogs.size() - 1; i >= 0 && count < limit; --i, ++count) {
        if (m_syncLogs[i].sourceSystem == sourceSystemId) {
            results.append(m_syncLogs[i]);
        }
    }
    return results;
}
