#pragma once

#include "ConfigTypes.h"
#include <QObject>
#include <memory>

/**
 * @class ConfigManager
 * @brief Abstract configuration management interface
 * 
 * Handles loading, validation, and merging of configuration
 * from multiple sources (files, environment, CLI)
 */
class ConfigManager : public QObject {
    Q_OBJECT
public:
    virtual ~ConfigManager() = default;
    
protected:
    explicit ConfigManager(QObject *parent = nullptr) : QObject(parent) {}
    
    // ── Loading ────────────────────────────────────────────────
    
    /// Load configuration from file (TOML format)
    virtual void loadFromFile(const QString &filePath,
                             ConfigCallback callback) = 0;
    
    /// Load configuration from environment variables
    virtual void loadFromEnvironment(ConfigCallback callback) = 0;
    
    /// Load configuration from command-line arguments
    virtual void loadFromCommandLine(const QStringList &args,
                                    ConfigCallback callback) = 0;
    
    /// Merge multiple configuration sources
    virtual NeurxConfig mergeConfigs(const QVector<NeurxConfig> &configs) = 0;
    
    // ── Access ─────────────────────────────────────────────────
    
    /// Get current configuration
    virtual NeurxConfig getConfig() const = 0;
    
    /// Get specific subsystem configuration
    virtual AgentConfig getAgentConfig() const = 0;
    virtual LLMConfig getLLMConfig() const = 0;
    virtual StorageConfig getStorageConfig() const = 0;
    virtual ApprovalConfig getApprovalConfig() const = 0;
    virtual LoggingConfig getLoggingConfig() const = 0;
    
    /// Get tool configuration
    virtual ToolConfig getToolConfig(const QString &toolName) const = 0;
    
    /// Get custom configuration value
    virtual QVariant getCustomValue(const QString &key, const QVariant &defaultValue = QVariant()) const = 0;
    
    // ── Validation ──────────────────────────────────────────────
    
    /// Validate configuration
    virtual bool validateConfig(const NeurxConfig &config, QString &errorMsg) = 0;
    
    /// Check if configuration is valid
    virtual bool isValid() const = 0;
    
    // ── Modification ────────────────────────────────────────────
    
    /// Set configuration value (in-memory only)
    virtual void setAgentConfig(const AgentConfig &config) = 0;
    virtual void setLLMConfig(const LLMConfig &config) = 0;
    virtual void setStorageConfig(const StorageConfig &config) = 0;
    virtual void setApprovalConfig(const ApprovalConfig &config) = 0;
    
    /// Add or update tool configuration
    virtual void setToolConfig(const QString &toolName, const ToolConfig &config) = 0;
    
    /// Set custom value
    virtual void setCustomValue(const QString &key, const QVariant &value) = 0;
    
    /// Save configuration to file
    virtual void saveToFile(const QString &filePath,
                           std::function<void(ConfigError)> callback) = 0;
    
    // ── Profiles ────────────────────────────────────────────────
    
    /// Get available profiles
    virtual QStringList getAvailableProfiles() const = 0;
    
    /// Switch to profile
    virtual void switchProfile(const QString &profileName,
                              ConfigCallback callback) = 0;
    
    /// Get current profile
    virtual QString getCurrentProfile() const = 0;
    
    // ── Defaults ────────────────────────────────────────────────
    
    /// Reset to default configuration
    virtual void resetToDefaults() = 0;
    
    /// Get default configuration template
    virtual NeurxConfig getDefaultConfig() const = 0;

signals:
    /// Emitted when configuration changes
    void configChanged(const NeurxConfig &newConfig);
    
    /// Emitted on configuration error
    void configError(ConfigError error, const QString &message);
    
    /// Emitted when profile changes
    void profileChanged(const QString &profileName);
};

using ConfigManagerPtr = std::shared_ptr<ConfigManager>;
