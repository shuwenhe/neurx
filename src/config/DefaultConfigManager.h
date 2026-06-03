#pragma once

#include "ConfigManager.h"
#include <QSettings>
#include <QMap>
#include <QMutex>
#include <memory>

/**
 * @class DefaultConfigManager
 * @brief Default configuration manager implementation
 * 
 * Features:
 * - TOML file loading and parsing
 * - Environment variable override
 * - Configuration validation
 * - Profile management
 * - In-memory caching
 */
class DefaultConfigManager : public ConfigManager {
    Q_OBJECT
public:
    explicit DefaultConfigManager(QObject *parent = nullptr);
    ~DefaultConfigManager();
    
    // Loading
    void loadFromFile(const QString &filePath,
                     ConfigCallback callback) override;
    void loadFromEnvironment(ConfigCallback callback) override;
    void loadFromCommandLine(const QStringList &args,
                            ConfigCallback callback) override;
    NeurxConfig mergeConfigs(const QVector<NeurxConfig> &configs) override;
    
    // Access
    NeurxConfig getConfig() const override;
    AgentConfig getAgentConfig() const override;
    LLMConfig getLLMConfig() const override;
    StorageConfig getStorageConfig() const override;
    ApprovalConfig getApprovalConfig() const override;
    LoggingConfig getLoggingConfig() const override;
    ToolConfig getToolConfig(const QString &toolName) const override;
    QVariant getCustomValue(const QString &key, const QVariant &defaultValue = QVariant()) const override;
    
    // Validation
    bool validateConfig(const NeurxConfig &config, QString &errorMsg) override;
    bool isValid() const override;
    
    // Modification
    void setAgentConfig(const AgentConfig &config) override;
    void setLLMConfig(const LLMConfig &config) override;
    void setStorageConfig(const StorageConfig &config) override;
    void setApprovalConfig(const ApprovalConfig &config) override;
    void setToolConfig(const QString &toolName, const ToolConfig &config) override;
    void setCustomValue(const QString &key, const QVariant &value) override;
    void saveToFile(const QString &filePath,
                   std::function<void(ConfigError)> callback) override;
    
    // Profiles
    QStringList getAvailableProfiles() const override;
    void switchProfile(const QString &profileName,
                      ConfigCallback callback) override;
    QString getCurrentProfile() const override;
    
    // Defaults
    void resetToDefaults() override;
    NeurxConfig getDefaultConfig() const override;

private:
    NeurxConfig m_config;
    NeurxConfig m_defaults;
    bool m_isValid{false};
    mutable QMutex m_mutex;
    
    QMap<QString, NeurxConfig> m_profiles;
    QString m_currentProfile{"default"};
    QString m_configFilePath;
    
    // Parsing helpers
    NeurxConfig parseTomlFile(const QString &filePath, ConfigError &error);
    NeurxConfig parseEnvironment();
    NeurxConfig parseCommandLine(const QStringList &args);
    
    // Validation helpers
    bool validateAgent(const AgentConfig &config, QString &error);
    bool validateLLM(const LLMConfig &config, QString &error);
    bool validateStorage(const StorageConfig &config, QString &error);
    bool validateApproval(const ApprovalConfig &config, QString &error);
    bool validateTool(const ToolConfig &config, QString &error);
    
    // Utility
    NeurxConfig getDefaultConfig_impl() const;
    QString expandPath(const QString &path);
    void initializeDefaultProfiles();
};

using DefaultConfigManagerPtr = std::shared_ptr<DefaultConfigManager>;
