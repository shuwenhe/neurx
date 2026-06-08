#include "PluginValidator.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDebug>
#include <QVersionNumber>
#include <QCryptographicHash>

PluginValidator::PluginValidator()
{
    // Initialize default validation rules
    m_rules.minNameLength = 1;
    m_rules.maxNameLength = 256;
    m_rules.allowedPluginTypes = {"tool", "provider", "service"};
}

PluginValidator::~PluginValidator()
{
}

PluginValidator::ValidationResult PluginValidator::validate(const QString &manifestPath,
                                                           ValidationLevel level)
{
    ValidationResult result;
    result.level = level;
    m_allErrors.clear();
    m_securityWarnings.clear();
    m_healthIssues.clear();

    if (manifestPath.isEmpty()) {
        m_lastError = "Manifest path is empty";
        result.errors.append(m_lastError);
        return result;
    }

    // Read manifest file
    QFile file(manifestPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_lastError = QString("Cannot open manifest: %1").arg(manifestPath);
        result.errors.append(m_lastError);
        return result;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        m_lastError = "Invalid manifest JSON format";
        result.errors.append(m_lastError);
        return result;
    }

    result.metadata = doc.object();

    // Level 1: Basic metadata validation
    if (level >= ValidationBasic) {
        if (!validateManifestFormat(result.metadata)) {
            result.errors.append("Invalid manifest format");
        }

        PluginMetadata metadata;
        metadata.fromJson(result.metadata);
        validateMetadata(metadata);

        if (!m_allErrors.isEmpty()) {
            result.errors.append(m_allErrors);
            m_allErrors.clear();
        }
    }

    // Level 2: Strict validation (dependencies, etc.)
    if (level >= ValidationStrict) {
        // Additional checks can be added here
    }

    // Level 3: Full validation (signature)
    if (level >= ValidationFull) {
        QString signature = result.metadata.value("signature").toString();
        if (!signature.isEmpty()) {
            QFileInfo fileInfo(manifestPath);
            QString pluginPath = fileInfo.dir().path();
            if (validateSignature(pluginPath, signature)) {
                result.signatureVerified = true;
            }
        }
    }

    // Level 4: Security scanning
    if (level >= ValidationSecure) {
        QFileInfo fileInfo(manifestPath);
        QString pluginPath = fileInfo.dir().path();
        performSecurityScan(pluginPath);
        result.warnings.append(m_securityWarnings);
    }

    result.isValid = result.errors.isEmpty();
    return result;
}

PluginValidator::ValidationResult PluginValidator::validateMetadata(const PluginMetadata &metadata)
{
    ValidationResult result;
    result.level = ValidationBasic;

    if (!metadata.isValid()) {
        result.errors.append(metadata.validationError());
        m_lastError = metadata.validationError();
    } else {
        result.isValid = true;
    }

    m_allErrors = result.errors;
    return result;
}

PluginValidator::ValidationResult PluginValidator::validatePlugin(PluginInterface *plugin)
{
    ValidationResult result;

    if (!plugin) {
        result.errors.append("Plugin pointer is null");
        m_lastError = "Plugin pointer is null";
        return result;
    }

    // Check basic properties
    if (plugin->pluginId().isEmpty()) {
        result.errors.append("Plugin ID is empty");
    }

    if (plugin->metadata().name().isEmpty()) {
        result.errors.append("Plugin name is empty");
    }

    // Perform health check
    if (performHealthCheck(plugin)) {
        result.isValid = result.errors.isEmpty();
        result.warnings.append(m_healthIssues);
    }

    return result;
}

bool PluginValidator::validateManifestFormat(const QJsonObject &manifest)
{
    if (!manifest.contains("id")) {
        m_lastError = "Missing required field: id";
        m_allErrors.append(m_lastError);
        return false;
    }

    if (!manifest.contains("name")) {
        m_lastError = "Missing required field: name";
        m_allErrors.append(m_lastError);
        return false;
    }

    if (!manifest.contains("version")) {
        m_lastError = "Missing required field: version";
        m_allErrors.append(m_lastError);
        return false;
    }

    return true;
}

bool PluginValidator::validateDependencies(const PluginMetadata &metadata,
                                          const QList<PluginMetadata> &availablePlugins)
{
    for (const auto &dep : metadata.dependencies()) {
        bool found = false;
        for (const auto &available : availablePlugins) {
            if (available.id() == dep.pluginId) {
                found = true;
                break;
            }
        }

        if (!found && !dep.optional) {
            m_lastError = QString("Missing required dependency: %1").arg(dep.pluginId);
            m_allErrors.append(m_lastError);
            return false;
        }
    }

    return true;
}

bool PluginValidator::validateCompatibility(const PluginMetadata &metadata)
{
    // Check version compatibility
    QVersionNumber pluginVersion = metadata.version();

    // Check if version is reasonable
    if (pluginVersion.majorVersion() < 0 || pluginVersion.majorVersion() > 999) {
        m_lastError = "Invalid version number";
        m_allErrors.append(m_lastError);
        return false;
    }

    return true;
}

bool PluginValidator::validateSignature(const QString &filePath, const QString &signature)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = "Cannot open file for signature verification";
        return false;
    }

    // Simple hash-based verification (in production, use cryptographic signatures)
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!hash.addData(&file)) {
        file.close();
        return false;
    }
    file.close();

    QString computedHash = QString::fromLatin1(hash.result().toHex());
    return computedHash == signature;
}

bool PluginValidator::performSecurityScan(const QString &pluginPath)
{
    m_securityWarnings.clear();

    QFileInfo pathInfo(pluginPath);
    if (pathInfo.isFile()) {
        checkForMaliciousPatterns(pluginPath);
    }

    // Check for suspicious permissions
    if (pathInfo.isReadable() && !pathInfo.isWritable()) {
        // Expected: plugins should not be writable
    } else if (pathInfo.isReadable() && pathInfo.isWritable()) {
        m_securityWarnings.append("Plugin file is writable (unexpected)");
    }

    return m_securityWarnings.isEmpty();
}

bool PluginValidator::performHealthCheck(PluginInterface *plugin)
{
    m_healthIssues.clear();

    if (!plugin) {
        return false;
    }

    // Check plugin state
    PluginInterface::PluginState state = plugin->state();
    if (state == PluginInterface::Failed) {
        m_healthIssues.append("Plugin is in Failed state");
        return false;
    }

    if (state == PluginInterface::Disabled) {
        m_healthIssues.append("Plugin is Disabled");
        return false;
    }

    // Check capabilities
    auto caps = plugin->getCapabilities();
    if (caps.isEmpty()) {
        m_healthIssues.append("Plugin has no capabilities");
    }

    return true;
}

QJsonObject PluginValidator::getValidationRules() const
{
    QJsonObject rules;
    rules["minNameLength"] = m_rules.minNameLength;
    rules["maxNameLength"] = m_rules.maxNameLength;
    rules["minVersionMajor"] = m_rules.minVersionMajor;
    rules["maxVersionMajor"] = m_rules.maxVersionMajor;

    QJsonArray types;
    for (const auto &type : m_rules.allowedPluginTypes) {
        types.append(type);
    }
    rules["allowedPluginTypes"] = types;

    rules["maxDependencies"] = m_rules.maxDependencies;
    rules["strictDependencies"] = m_rules.strictDependencies;
    rules["requireSignature"] = m_rules.requireSignature;

    return rules;
}

void PluginValidator::setValidationRules(const QJsonObject &rules)
{
    if (rules.contains("minNameLength")) {
        m_rules.minNameLength = rules.value("minNameLength").toInt(1);
    }

    if (rules.contains("maxNameLength")) {
        m_rules.maxNameLength = rules.value("maxNameLength").toInt(256);
    }

    if (rules.contains("allowedPluginTypes")) {
        m_rules.allowedPluginTypes.clear();
        QJsonArray types = rules.value("allowedPluginTypes").toArray();
        for (const auto &type : types) {
            m_rules.allowedPluginTypes.append(type.toString());
        }
    }

    if (rules.contains("maxDependencies")) {
        m_rules.maxDependencies = rules.value("maxDependencies").toInt(100);
    }

    if (rules.contains("strictDependencies")) {
        m_rules.strictDependencies = rules.value("strictDependencies").toBool();
    }

    if (rules.contains("requireSignature")) {
        m_rules.requireSignature = rules.value("requireSignature").toBool();
    }
}

void PluginValidator::validateRequiredFields(const PluginMetadata &metadata)
{
    if (metadata.id().isEmpty()) {
        m_allErrors.append("Plugin ID is required");
    }

    if (metadata.name().isEmpty()) {
        m_allErrors.append("Plugin name is required");
    }

    if (metadata.version().isNull()) {
        m_allErrors.append("Plugin version is required");
    }
}

void PluginValidator::validateMetadataValues(const PluginMetadata &metadata)
{
    // Validate name length
    if (metadata.name().length() < m_rules.minNameLength) {
        m_allErrors.append(QString("Plugin name too short (min %1)").arg(m_rules.minNameLength));
    }

    if (metadata.name().length() > m_rules.maxNameLength) {
        m_allErrors.append(QString("Plugin name too long (max %1)").arg(m_rules.maxNameLength));
    }

    // Validate version
    validateVersionNumber(metadata.version());

    // Validate plugin type
    if (!m_rules.allowedPluginTypes.contains(metadata.pluginType())) {
        m_allErrors.append(QString("Invalid plugin type: %1").arg(metadata.pluginType()));
    }
}

void PluginValidator::validateVersionNumber(const QVersionNumber &version)
{
    if (version.majorVersion() < m_rules.minVersionMajor ||
        version.majorVersion() > m_rules.maxVersionMajor) {
        m_allErrors.append(QString("Invalid version number (major: %1 - %2)")
            .arg(m_rules.minVersionMajor).arg(m_rules.maxVersionMajor));
    }
}

void PluginValidator::validatePluginPath(const QString &path)
{
    if (path.isEmpty()) {
        m_allErrors.append("Plugin path is empty");
        return;
    }

    QFileInfo fileInfo(path);
    if (!fileInfo.exists()) {
        m_allErrors.append(QString("Plugin path does not exist: %1").arg(path));
    }
}

void PluginValidator::checkForSuspiciousCode(const QString &pluginPath)
{
    // This is a placeholder for more sophisticated code analysis
    // In production, this would use static analysis tools
}

void PluginValidator::checkForMaliciousPatterns(const QString &filePath)
{
    // Placeholder for malicious pattern detection
    // Could check for known malware signatures, suspicious function calls, etc.
}

QString PluginValidator::ValidationResult::summary() const
{
    QString summary;
    summary += QString("Valid: %1\n").arg(isValid ? "Yes" : "No");
    summary += QString("Level: %1\n").arg(static_cast<int>(level));

    if (!errors.isEmpty()) {
        summary += QString("Errors (%1):\n").arg(errors.size());
        for (const auto &error : errors) {
            summary += QString("  - %1\n").arg(error);
        }
    }

    if (!warnings.isEmpty()) {
        summary += QString("Warnings (%1):\n").arg(warnings.size());
        for (const auto &warning : warnings) {
            summary += QString("  - %1\n").arg(warning);
        }
    }

    return summary;
}
