#include "ComplianceFramework.h"
#include <QDebug>

ComplianceFramework::ComplianceFramework(QObject* parent)
    : QObject(parent) {
}

ComplianceFramework::~ComplianceFramework() {
}

void ComplianceFramework::registerRequirement(const ComplianceRequirement& requirement) {
    m_requirements[requirement.id] = requirement;
    emit requirementAdded(requirement.id);
}

void ComplianceFramework::updateRequirement(const ComplianceRequirement& requirement) {
    if (m_requirements.contains(requirement.id)) {
        m_requirements[requirement.id] = requirement;
        emit complianceStatusChanged(requirement.id);
    }
}

QVector<ComplianceFramework::ComplianceRequirement> ComplianceFramework::getAllRequirements() {
    return QVector<ComplianceRequirement>(m_requirements.values().begin(), m_requirements.values().end());
}

QVector<ComplianceFramework::ComplianceRequirement> ComplianceFramework::getRequirementsByStandard(ComplianceStandard standard) {
    QVector<ComplianceRequirement> results;
    for (const auto& req : m_requirements.values()) {
        if (req.standard == standard) {
            results.append(req);
        }
    }
    return results;
}

void ComplianceFramework::logAction(const AuditLog& log) {
    m_auditLogs.append(log);
    emit auditLogCreated(log.id);
}

QVector<ComplianceFramework::AuditLog> ComplianceFramework::getAuditLogs(const QString& resource) {
    QVector<AuditLog> results;
    for (const auto& log : m_auditLogs) {
        if (log.resource == resource) {
            results.append(log);
        }
    }
    return results;
}

QVector<ComplianceFramework::AuditLog> ComplianceFramework::getAuditLogsByUser(const QString& user) {
    QVector<AuditLog> results;
    for (const auto& log : m_auditLogs) {
        if (log.user == user) {
            results.append(log);
        }
    }
    return results;
}

ComplianceFramework::ComplianceReport ComplianceFramework::generateComplianceReport(ComplianceStandard standard) {
    ComplianceReport report;
    report.standard = standard;
    report.compliancePercentage = 95.0f;
    report.generatedAt = QDateTime::currentDateTime();
    return report;
}

void ComplianceFramework::assignOwner(const QString& requirementId, const QString& owner) {
    if (m_requirements.contains(requirementId)) {
        m_requirements[requirementId].owner = owner;
    }
}

void ComplianceFramework::markAsCompliant(const QString& requirementId) {
    if (m_requirements.contains(requirementId)) {
        m_requirements[requirementId].status = "compliant";
        emit complianceStatusChanged(requirementId);
    }
}
