#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QMap>
#include <QVector>
#include <memory>
#include <vector>

/**
 * @class DisasterRecoveryManager
 * @brief Disaster recovery and backup management
 */

class DisasterRecoveryManager : public QObject {
    Q_OBJECT

public:
    struct BackupConfig {
        QString id;
        QString targetName;
        QString backupPath;
        QString schedule;  // cron expression
        bool enabled;
        int retentionDays;
        int compressionLevel;
    };

    struct RecoveryPoint {
        QString id;
        QString backupId;
        QString timestamp;
        QString status;  // success, failed, in_progress
        int sizeBytes;
        QString checksum;
    };

    explicit DisasterRecoveryManager(QObject* parent = nullptr);
    ~DisasterRecoveryManager();

    void createBackupConfig(const BackupConfig& config);
    void updateBackupConfig(const BackupConfig& config);
    void deleteBackupConfig(const QString& configId);
    QVector<BackupConfig> getAllBackupConfigs();

    QString startBackup(const QString& configId);
    QString startFullRestore(const QString& recoveryPointId);
    QString startPartialRestore(const QString& recoveryPointId, const QStringList& items);

    QVector<RecoveryPoint> getRecoveryPoints(const QString& backupId);
    RecoveryPoint getLatestRecoveryPoint(const QString& backupId);

    void verifyBackup(const QString& recoveryPointId);
    bool validateRecoveryPoint(const QString& recoveryPointId);

    struct RecoveryMetrics {
        int totalBackups;
        int successfulBackups;
        float avgRecoveryTimeSeconds;
        int verifiedRecoveryPoints;
    };
    RecoveryMetrics getRecoveryMetrics();

signals:
    void backupStarted(const QString& backupId);
    void backupCompleted(const QString& recoveryPointId);
    void restoreCompleted(const QString& restoreId);
    void backupFailed(const QString& backupId, const QString& error);

private:
    QMap<QString, BackupConfig> m_configs;
    QVector<RecoveryPoint> m_recoveryPoints;
};
