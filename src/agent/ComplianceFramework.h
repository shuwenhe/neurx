#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class ComplianceFramework
 * @brief Compliance tracking and auditing
 */

class ComplianceFramework : public QObject {
    Q_OBJECT

public:
    enum ComplianceStandard {
        GDPR,
        HIPAA,
        SOC2,
        ISO27001,
        PCI_DSS,
        CCPA
    };

    struct ComplianceRequirement {
        QString id;
        ComplianceStandard standard;
        QString description;
        QString status;  // compliant, non-compliant, pending
        QString owner;
        QDateTime dueDate;
    };

    struct AuditLog {
        QString id;
        QString action;
        QString user;
        QString resource;
        QString changeDetails;
        QDateTime timestamp;
    };

    explicit ComplianceFramework(QObject* parent = nullptr);
    ~ComplianceFramework();

    void registerRequirement(const ComplianceRequirement& requirement);
    void updateRequirement(const ComplianceRequirement& requirement);
    QVector<ComplianceRequirement> getAllRequirements();
    QVector<ComplianceRequirement> getRequirementsByStandard(ComplianceStandard standard);

    void logAction(const AuditLog& log);
    QVector<AuditLog> getAuditLogs(const QString& resource);
    QVector<AuditLog> getAuditLogsByUser(const QString& user);

    struct ComplianceReport {
        ComplianceStandard standard;
        float compliancePercentage;
        QVector<ComplianceRequirement> nonCompliantItems;
        QDateTime generatedAt;
    };
    ComplianceReport generateComplianceReport(ComplianceStandard standard);

    void assignOwner(const QString& requirementId, const QString& owner);
    void markAsCompliant(const QString& requirementId);

signals:
    void requirementAdded(const QString& requirementId);
    void complianceStatusChanged(const QString& requirementId);
    void auditLogCreated(const QString& logId);

private:
    QMap<QString, ComplianceRequirement> m_requirements;
    QVector<AuditLog> m_auditLogs;
};
