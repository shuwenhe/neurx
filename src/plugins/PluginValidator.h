#ifndef PLUGINVALIDATOR_H
#define PLUGINVALIDATOR_H

#include "PluginMetadata.h"
#include "PluginInterface.h"
#include <QString>
#include <QList>
#include <QJsonObject>

/**
 * @class PluginValidator
 * @brief Plugin validation and verification framework
 * 
 * Features:
 * - Manifest validation
 * - Dependency checking
 * - Signature verification
 * - Compatibility checking
 * - Security scanning
 * - Health checks
 */

class PluginValidator
{
public:
    enum ValidationLevel {
        ValidationNone = 0,
        ValidationBasic = 1,        // Metadata only
        ValidationStrict = 2,       // Metadata + dependencies
        ValidationFull = 3,         // Metadata + dependencies + signature
        ValidationSecure = 4        // Full + security scanning
    };

    struct ValidationResult {
        bool isValid = false;
        ValidationLevel level = ValidationNone;
        QList<QString> warnings;
        QList<QString> errors;
        QJsonObject metadata;
        QString signature;
        bool signatureVerified = false;

        QString summary() const;
    };

    explicit PluginValidator();
    ~PluginValidator();

    // Main validation functions
    ValidationResult validate(const QString &manifestPath,
                            ValidationLevel level = ValidationFull);

    ValidationResult validateMetadata(const PluginMetadata &metadata);

    ValidationResult validatePlugin(PluginInterface *plugin);

    // Specific validation checks
    bool validateManifestFormat(const QJsonObject &manifest);
    bool validateDependencies(const PluginMetadata &metadata, const QList<PluginMetadata> &availablePlugins);
    bool validateCompatibility(const PluginMetadata &metadata);
    bool validateSignature(const QString &filePath, const QString &signature);

    // Security checks
    bool performSecurityScan(const QString &pluginPath);
    QList<QString> getSecurityWarnings() const { return m_securityWarnings; }

    // Health checks
    bool performHealthCheck(PluginInterface *plugin);
    QList<QString> getHealthIssues() const { return m_healthIssues; }

    // Get validation rules
    QJsonObject getValidationRules() const;
    void setValidationRules(const QJsonObject &rules);

    // Get detailed error info
    QString getLastError() const { return m_lastError; }
    QList<QString> getAllErrors() const { return m_allErrors; }

private:
    struct ValidationRules {
        int minNameLength = 1;
        int maxNameLength = 256;
        int minVersionMajor = 0;
        int maxVersionMajor = 999;
        QList<QString> allowedPluginTypes = {"tool", "provider", "service"};
        int maxDependencies = 100;
        bool strictDependencies = false;
        bool requireSignature = false;
    };

    ValidationRules m_rules;
    QString m_lastError;
    QList<QString> m_allErrors;
    QList<QString> m_securityWarnings;
    QList<QString> m_healthIssues;

    // Helper methods
    void validateRequiredFields(const PluginMetadata &metadata);
    void validateMetadataValues(const PluginMetadata &metadata);
    void validateVersionNumber(const QVersionNumber &version);
    void validatePluginPath(const QString &path);
    void checkForSuspiciousCode(const QString &pluginPath);
    void checkForMaliciousPatterns(const QString &filePath);
};

#endif // PLUGINVALIDATOR_H
