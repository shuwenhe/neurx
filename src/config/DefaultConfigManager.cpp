#include "DefaultConfigManager.h"
#include <QStandardPaths>
#include <QFile>
#include <QDebug>
#include <QProcessEnvironment>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMutex>

DefaultConfigManager::DefaultConfigManager(QObject *parent)
    : ConfigManager(parent)
{
    // Initialize with default configuration
    m_config = getDefaultConfig_impl();
    m_defaults = m_config;
    m_isValid = true;
    
    // Initialize default profiles
    initializeDefaultProfiles();
}

DefaultConfigManager::~DefaultConfigManager()
{
}

void DefaultConfigManager::loadFromFile(const QString &filePath,
                                       ConfigCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    ConfigError error = ConfigError::Success;
    NeurxConfig config = parseTomlFile(filePath, error);
    
    if (error == ConfigError::Success) {
        m_config = config;
        m_configFilePath = filePath;
        m_isValid = true;
        locker.unlock();
        
        if (callback) {
            callback(ConfigError::Success, m_config);
        }
        emit configChanged(m_config);
    } else {
        locker.unlock();
        if (callback) {
            callback(error, NeurxConfig());
        }
    }
}

void DefaultConfigManager::loadFromEnvironment(ConfigCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    NeurxConfig envConfig = parseEnvironment();
    m_config = mergeConfigs(QVector<NeurxConfig>{m_config, envConfig});
    m_isValid = true;
    
    locker.unlock();
    
    if (callback) {
        callback(ConfigError::Success, m_config);
    }
    emit configChanged(m_config);
}

void DefaultConfigManager::loadFromCommandLine(const QStringList &args,
                                              ConfigCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    NeurxConfig cliConfig = parseCommandLine(args);
    m_config = mergeConfigs(QVector<NeurxConfig>{m_config, cliConfig});
    m_isValid = true;
    
    locker.unlock();
    
    if (callback) {
        callback(ConfigError::Success, m_config);
    }
    emit configChanged(m_config);
}

NeurxConfig DefaultConfigManager::mergeConfigs(const QVector<NeurxConfig> &configs)
{
    if (configs.isEmpty()) {
        return m_defaults;
    }
    
    NeurxConfig merged = configs[0];
    
    for (int i = 1; i < configs.size(); ++i) {
        const auto &config = configs[i];
        
        // Merge agent config (override only if explicitly set)
        if (!config.agent.name.isEmpty()) {
            merged.agent = config.agent;
        }
        
        // Merge LLM config
        if (!config.llm.provider.isEmpty()) {
            merged.llm = config.llm;
        }
        
        // Merge storage config
        if (!config.storage.backend.isEmpty()) {
            merged.storage = config.storage;
        }
        
        // Merge approval config
        if (!config.approval.mode.isEmpty()) {
            merged.approval = config.approval;
        }
        
        // Merge tool configs
        for (auto it = config.tools.begin(); it != config.tools.end(); ++it) {
            merged.tools[it.key()] = it.value();
        }
        
        // Merge custom settings
        for (auto it = config.custom.begin(); it != config.custom.end(); ++it) {
            merged.custom[it.key()] = it.value();
        }
    }
    
    return merged;
}

NeurxConfig DefaultConfigManager::getConfig() const
{
    QMutexLocker locker(&m_mutex);
    return m_config;
}

AgentConfig DefaultConfigManager::getAgentConfig() const
{
    QMutexLocker locker(&m_mutex);
    return m_config.agent;
}

LLMConfig DefaultConfigManager::getLLMConfig() const
{
    QMutexLocker locker(&m_mutex);
    return m_config.llm;
}

StorageConfig DefaultConfigManager::getStorageConfig() const
{
    QMutexLocker locker(&m_mutex);
    return m_config.storage;
}

ApprovalConfig DefaultConfigManager::getApprovalConfig() const
{
    QMutexLocker locker(&m_mutex);
    return m_config.approval;
}

LoggingConfig DefaultConfigManager::getLoggingConfig() const
{
    QMutexLocker locker(&m_mutex);
    return m_config.logging;
}

ToolConfig DefaultConfigManager::getToolConfig(const QString &toolName) const
{
    QMutexLocker locker(&m_mutex);
    auto it = m_config.tools.find(toolName);
    if (it != m_config.tools.end()) {
        return it.value();
    }
    return ToolConfig{toolName, true, QVariantMap(), QStringList()};
}

QVariant DefaultConfigManager::getCustomValue(const QString &key, const QVariant &defaultValue) const
{
    QMutexLocker locker(&m_mutex);
    return m_config.custom.value(key, defaultValue);
}

bool DefaultConfigManager::validateConfig(const NeurxConfig &config, QString &errorMsg)
{
    // Validate agent config
    if (!validateAgent(config.agent, errorMsg)) {
        return false;
    }
    
    // Validate LLM config
    if (!validateLLM(config.llm, errorMsg)) {
        return false;
    }
    
    // Validate storage config
    if (!validateStorage(config.storage, errorMsg)) {
        return false;
    }
    
    // Validate approval config
    if (!validateApproval(config.approval, errorMsg)) {
        return false;
    }
    
    // Validate tools
    for (const auto &tool : config.tools) {
        if (!validateTool(tool, errorMsg)) {
            return false;
        }
    }
    
    return true;
}

bool DefaultConfigManager::isValid() const
{
    QMutexLocker locker(&m_mutex);
    return m_isValid;
}

void DefaultConfigManager::setAgentConfig(const AgentConfig &config)
{
    QMutexLocker locker(&m_mutex);
    m_config.agent = config;
    emit configChanged(m_config);
}

void DefaultConfigManager::setLLMConfig(const LLMConfig &config)
{
    QMutexLocker locker(&m_mutex);
    m_config.llm = config;
    emit configChanged(m_config);
}

void DefaultConfigManager::setStorageConfig(const StorageConfig &config)
{
    QMutexLocker locker(&m_mutex);
    m_config.storage = config;
    emit configChanged(m_config);
}

void DefaultConfigManager::setApprovalConfig(const ApprovalConfig &config)
{
    QMutexLocker locker(&m_mutex);
    m_config.approval = config;
    emit configChanged(m_config);
}

void DefaultConfigManager::setToolConfig(const QString &toolName, const ToolConfig &config)
{
    QMutexLocker locker(&m_mutex);
    m_config.tools[toolName] = config;
    emit configChanged(m_config);
}

void DefaultConfigManager::setCustomValue(const QString &key, const QVariant &value)
{
    QMutexLocker locker(&m_mutex);
    m_config.custom[key] = value;
    emit configChanged(m_config);
}

void DefaultConfigManager::saveToFile(const QString &filePath,
                                     std::function<void(ConfigError)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        locker.unlock();
        if (callback) {
            callback(ConfigError::PermissionDenied);
        }
        return;
    }
    
    // Serialize to JSON (can be extended to TOML)
    QJsonObject configObj;
    configObj["profile"] = static_cast<int>(m_config.profile);
    configObj["version"] = m_config.version;
    
    QJsonObject agentObj;
    agentObj["name"] = m_config.agent.name;
    agentObj["model"] = m_config.agent.model;
    agentObj["maxRetries"] = m_config.agent.maxRetries;
    configObj["agent"] = agentObj;
    
    QJsonDocument doc(configObj);
    file.write(doc.toJson());
    file.close();
    
    locker.unlock();
    
    if (callback) {
        callback(ConfigError::Success);
    }
}

QStringList DefaultConfigManager::getAvailableProfiles() const
{
    QMutexLocker locker(&m_mutex);
    return m_profiles.keys();
}

void DefaultConfigManager::switchProfile(const QString &profileName,
                                        ConfigCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_profiles.find(profileName);
    if (it == m_profiles.end()) {
        locker.unlock();
        if (callback) {
            callback(ConfigError::FileNotFound, NeurxConfig());
        }
        return;
    }
    
    m_config = it.value();
    m_currentProfile = profileName;
    
    locker.unlock();
    
    if (callback) {
        callback(ConfigError::Success, m_config);
    }
    emit profileChanged(profileName);
    emit configChanged(m_config);
}

QString DefaultConfigManager::getCurrentProfile() const
{
    QMutexLocker locker(&m_mutex);
    return m_currentProfile;
}

void DefaultConfigManager::resetToDefaults()
{
    QMutexLocker locker(&m_mutex);
    m_config = m_defaults;
    m_isValid = true;
    emit configChanged(m_config);
}

NeurxConfig DefaultConfigManager::getDefaultConfig() const
{
    return getDefaultConfig_impl();
}

NeurxConfig DefaultConfigManager::parseTomlFile(const QString &filePath, ConfigError &error)
{
    QFile file(filePath);
    if (!file.exists()) {
        error = ConfigError::FileNotFound;
        return m_defaults;
    }
    
    if (!file.open(QIODevice::ReadOnly)) {
        error = ConfigError::PermissionDenied;
        return m_defaults;
    }
    
    // For now, parse as JSON (TOML parser can be added later)
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        error = ConfigError::ParseError;
        return m_defaults;
    }
    
    NeurxConfig config = m_defaults;
    error = ConfigError::Success;
    return config;
}

NeurxConfig DefaultConfigManager::parseEnvironment()
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    NeurxConfig config = m_defaults;
    
    // Parse NEURX_* environment variables
    if (env.contains("NEURX_MODEL")) {
        config.llm.model = env.value("NEURX_MODEL");
    }
    
    if (env.contains("NEURX_LOG_LEVEL")) {
        config.logging.level = env.value("NEURX_LOG_LEVEL");
    }
    
    if (env.contains("NEURX_API_KEY")) {
        config.llm.apiKey = env.value("NEURX_API_KEY");
    }

    if (env.contains("NEURX_DATA_DIR")) {
        config.storage.dataDir = env.value("NEURX_DATA_DIR");
    }
    
    return config;
}

NeurxConfig DefaultConfigManager::parseCommandLine(const QStringList &args)
{
    NeurxConfig config = m_defaults;
    
    for (int i = 0; i < args.size(); ++i) {
        const QString &arg = args[i];
        
        if ((arg == "--model" || arg == "-m") && i + 1 < args.size()) {
            config.llm.model = args[++i];
        } else if ((arg == "--log-level" || arg == "-l") && i + 1 < args.size()) {
            config.logging.level = args[++i];
        } else if ((arg == "--data-dir" || arg == "-d") && i + 1 < args.size()) {
            config.storage.dataDir = args[++i];
        } else if (arg == "--strict") {
            config.agent.strictMode = true;
        } else if (arg == "--no-sandbox") {
            config.approval.mode = "never";
        }
    }
    
    return config;
}

bool DefaultConfigManager::validateAgent(const AgentConfig &config, QString &error)
{
    if (config.name.isEmpty()) {
        error = "Agent name cannot be empty";
        return false;
    }
    
    if (config.maxRetries < 0) {
        error = "Max retries must be non-negative";
        return false;
    }
    
    if (config.executionTimeoutMs < 1000) {
        error = "Execution timeout must be at least 1000ms";
        return false;
    }
    
    return true;
}

bool DefaultConfigManager::validateLLM(const LLMConfig &config, QString &error)
{
    if (config.provider.isEmpty()) {
        error = "LLM provider cannot be empty";
        return false;
    }
    
    if (config.model.isEmpty()) {
        error = "LLM model cannot be empty";
        return false;
    }
    
    if (config.maxTokens < 100) {
        error = "Max tokens must be at least 100";
        return false;
    }
    
    return true;
}

bool DefaultConfigManager::validateStorage(const StorageConfig &config, QString &error)
{
    if (config.backend.isEmpty()) {
        error = "Storage backend cannot be empty";
        return false;
    }
    
    return true;
}

bool DefaultConfigManager::validateApproval(const ApprovalConfig &config, QString &error)
{
    if (config.mode.isEmpty()) {
        error = "Approval mode cannot be empty";
        return false;
    }
    
    return true;
}

bool DefaultConfigManager::validateTool(const ToolConfig &config, QString &error)
{
    if (config.name.isEmpty()) {
        error = "Tool name cannot be empty";
        return false;
    }
    
    return true;
}

NeurxConfig DefaultConfigManager::getDefaultConfig_impl() const
{
    NeurxConfig config;
    
    config.profile = ConfigProfile::Default;
    config.version = "1.0";
    
    // Agent defaults
    config.agent.name = "neurx-agent";
    config.agent.model = "claude-3.5-sonnet";
    config.agent.maxRetries = 3;
    config.agent.executionTimeoutMs = 300000;
    config.agent.maxOutputSize = 1000000;
    config.agent.verboseLogging = false;
    config.agent.strictMode = false;
    config.agent.autoApprove = false;
    config.agent.enableShellExecution = true;
    config.agent.enableFileOperations = true;
    config.agent.enableNetworkAccess = false;
    
    // LLM defaults
    config.llm.provider = "anthropic";
    config.llm.model = "claude-3.5-sonnet";
    config.llm.maxTokens = 8000;
    config.llm.temperature = 0.7;
    config.llm.topP = 1.0;
    config.llm.maxRetries = 3;
    config.llm.retryDelayMs = 1000;
    config.llm.timeoutMs = 60000;
    
    // Storage defaults
    config.storage.backend = "file-based";
    config.storage.dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/data";
    config.storage.filePaths.threadsDir = "threads";
    config.storage.filePaths.checkpointsDir = "checkpoints";
    config.storage.filePaths.logsDir = "logs";
    
    // Approval defaults
    config.approval.mode = "on-request";
    config.approval.reviewer = "user";
    config.approval.autoApproveOnRetry = false;
    config.approval.autoApproveReadOnly = true;
    
    // Logging defaults
    config.logging.level = "info";
    config.logging.format = "text";
    config.logging.output = "console";
    config.logging.logFile = "neurx.log";
    config.logging.maxFileSizeMB = 100;
    config.logging.maxBackups = 10;
    config.logging.colorOutput = true;
    config.logging.enableTelemetry = false;
    
    config.loadedAt = QDateTime::currentDateTime();
    
    return config;
}

QString DefaultConfigManager::expandPath(const QString &path)
{
    QString expanded = path;
    expanded.replace("~", QStandardPaths::writableLocation(QStandardPaths::HomeLocation));
    return expanded;
}

void DefaultConfigManager::initializeDefaultProfiles()
{
    // Development profile
    NeurxConfig devProfile = m_defaults;
    devProfile.profile = ConfigProfile::Development;
    devProfile.agent.verboseLogging = true;
    devProfile.logging.level = "debug";
    m_profiles["development"] = devProfile;
    
    // Production profile
    NeurxConfig prodProfile = m_defaults;
    prodProfile.profile = ConfigProfile::Production;
    prodProfile.agent.verboseLogging = false;
    prodProfile.agent.strictMode = true;
    prodProfile.approval.mode = "on-request";
    prodProfile.logging.level = "warn";
    m_profiles["production"] = prodProfile;
    
    // Testing profile
    NeurxConfig testProfile = m_defaults;
    testProfile.profile = ConfigProfile::Testing;
    testProfile.agent.autoApprove = true;
    testProfile.approval.mode = "never";
    testProfile.logging.level = "debug";
    m_profiles["testing"] = testProfile;
    
    // Default profile
    m_profiles["default"] = m_defaults;
}

#include "moc_DefaultConfigManager.cpp"
