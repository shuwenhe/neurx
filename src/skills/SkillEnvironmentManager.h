#pragma once

#include "ClaudeSkillTypes.h"
#include <QString>
#include <QMap>
#include <QVector>
#include <functional>
#include <memory>

/**
 * @class SkillEnvironmentManager
 * @brief Manages environment variables for Claude skills
 * 
 * Responsibilities:
 * - Collect and validate environment variables
 * - Manage secret storage and masking
 * - Handle environment variable callbacks
 * - Persist to ~/.hermes/.env or profile-scoped storage
 */
class SkillEnvironmentManager {
public:
    using EnvCollectedCallback = std::function<void(bool success, const QString &error)>;
    using EnvPromptCallback = std::function<QString(const QString &prompt, const QString &help)>;
    using EnvSecretCallback = std::function<QString(const QString &prompt)>;
    
    SkillEnvironmentManager();
    virtual ~SkillEnvironmentManager() = default;
    
    // ── Variable Collection ────────────────────────────────
    
    /// Collect required environment variables for a skill
    virtual void collectEnvironmentVariables(
        const ClaudeSkill &skill,
        EnvPromptCallback promptCallback,
        EnvSecretCallback secretCallback,
        EnvCollectedCallback resultCallback
    ) = 0;
    
    /// Set environment variable
    virtual void setEnvironmentVariable(const QString &name, const QString &value) = 0;
    
    /// Get environment variable (may trigger prompt if missing)
    virtual QString getEnvironmentVariable(const QString &name) = 0;
    
    // ── Validation ─────────────────────────────────────────
    
    /// Validate environment variables for a skill
    virtual bool validateEnvironmentVariables(
        const ClaudeSkill &skill,
        QStringList &missingVariables,
        QString &error
    ) = 0;
    
    /// Check if variable satisfies requirement (pattern, non-empty, etc.)
    virtual bool validateVariable(
        const EnvironmentVariableDef &def,
        const QString &value
    ) = 0;
    
    // ── Storage ────────────────────────────────────────────
    
    /// Load environment from storage (~/.hermes/.env)
    virtual void loadFromStorage(const QString &storageFile) = 0;
    
    /// Save environment to storage
    virtual void saveToStorage(const QString &storageFile) = 0;
    
    /// Clear all stored variables
    virtual void clearStorage() = 0;
    
    // ── Querying ───────────────────────────────────────────
    
    /// Get all current environment variables (excluding secrets)
    virtual QMap<QString, QString> getAllVariables() const = 0;
    
    /// Get all required variables for skill (not including optional defaults)
    virtual QStringList getRequiredVariablesForSkill(const ClaudeSkill &skill) const = 0;
    
    /// Check if all required variables are set
    virtual bool areAllRequiredVariablesSet(const ClaudeSkill &skill) const = 0;
};

/**
 * @class DefaultSkillEnvironmentManager
 * @brief Default implementation of SkillEnvironmentManager
 */
class DefaultSkillEnvironmentManager : public SkillEnvironmentManager {
public:
    DefaultSkillEnvironmentManager();
    ~DefaultSkillEnvironmentManager() override = default;
    
    void collectEnvironmentVariables(
        const ClaudeSkill &skill,
        EnvPromptCallback promptCallback,
        EnvSecretCallback secretCallback,
        EnvCollectedCallback resultCallback
    ) override;
    
    void setEnvironmentVariable(const QString &name, const QString &value) override;
    QString getEnvironmentVariable(const QString &name) override;
    
    bool validateEnvironmentVariables(
        const ClaudeSkill &skill,
        QStringList &missingVariables,
        QString &error
    ) override;
    
    bool validateVariable(
        const EnvironmentVariableDef &def,
        const QString &value
    ) override;
    
    void loadFromStorage(const QString &storageFile) override;
    void saveToStorage(const QString &storageFile) override;
    void clearStorage() override;
    
    QMap<QString, QString> getAllVariables() const override;
    QStringList getRequiredVariablesForSkill(const ClaudeSkill &skill) const override;
    bool areAllRequiredVariablesSet(const ClaudeSkill &skill) const override;
    
private:
    /// Validate variable against pattern/constraints
    bool matchesPattern(const QString &value, const QString &pattern) const;
    
    /// Mask secret variable for display
    QString maskSecret(const QString &value) const;
    
    /// Parse dotenv file format
    QMap<QString, QString> parseDotenv(const QString &content) const;
    
    /// Serialize variables to dotenv format
    QString serializeToDotenv() const;
    
    // Storage
    QMap<QString, QString> m_variables;
    QMap<QString, QString> m_secrets;  // Separate storage for sensitive values
};

/**
 * @class EnvironmentVariableValidator
 * @brief Utility for validating environment variables
 */
class EnvironmentVariableValidator {
public:
    /// Validate pattern match
    static bool validatePattern(const QString &value, const QString &pattern);
    
    /// Validate URL format
    static bool validateUrl(const QString &value);
    
    /// Validate email format
    static bool validateEmail(const QString &value);
    
    /// Validate IP address
    static bool validateIpAddress(const QString &value);
    
    /// Validate API key format (basic)
    static bool validateApiKey(const QString &value);
};
