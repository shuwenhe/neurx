#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <vector>

/**
 * @class PluginSystemRegistry
 * @brief Comprehensive plugin system management
 * 
 * Features:
 * - Plugin discovery and registration
 * - Dependency resolution
 * - Plugin lifecycle management (load, enable, disable, unload)
 * - Hook system (PreToolUse, PostToolUse, SessionStart, etc.)
 * - Command management
 * - MCP server integration
 * - Skill management
 * - Plugin marketplace support
 * - Automatic version management
 */

class PluginSystemRegistry : public QObject {
    Q_OBJECT

public:
    enum PluginType {
        Command,
        Agent,
        SkillPlugin,
        HookPlugin,
        MCPServer,
        Theme,
        Extension
    };

    enum HookType {
        PreToolUse,
        PostToolUse,
        SessionStart,
        SessionEnd,
        CommandExecuting,
        CommandCompleted,
        ErrorOccurred,
        BeforeSave,
        AfterSave,
        ContextChanged
    };

    enum PluginStatus {
        Discovered,
        Loaded,
        Enabled,
        Disabled,
        Failed,
        Incompatible
    };

    struct PluginMetadata {
        QString id;
        QString name;
        QString version;
        QString description;
        QString author;
        QStringList contributors;
        QString license;
        QString repository;
        QString homepage;
        QString documentation;
        QStringList keywords;
        QStringList compatibleVersions;
        QStringList dependencies;  // Other plugin IDs
        QStringList optionalDeps;
        PluginType type;
        QJsonObject config;
        bool enabled;
        QString installPath;
    };

    struct PluginHook {
        QString id;
        QString pluginId;
        HookType type;
        QString handler;  // Function name or lambda
        int priority;  // 0-100, higher = executed first
        QJsonObject config;
    };

    struct PluginCommand {
        QString id;
        QString pluginId;
        QString name;
        QStringList aliases;
        QString description;
        QStringList parameters;
        QString handler;
        bool enabled;
    };

    struct MCPServerConfig {
        QString id;
        QString pluginId;
        QString name;
        QString command;
        QString url;
        QStringList environment;
        QJsonObject config;
        bool autoStart;
    };

    struct PluginSkill {
        QString id;
        QString pluginId;
        QString name;
        QString description;
        QString content;
        QStringList tags;
        int priority;  // 0-100
        QStringList applicableTasks;
    };

    explicit PluginSystemRegistry(QObject* parent = nullptr);
    ~PluginSystemRegistry();

    // Plugin discovery and registration
    void discoverPlugins(const QString& directory);
    void registerPlugin(const PluginMetadata& metadata);
    bool unregisterPlugin(const QString& pluginId);
    void rescanPlugins();

    // Plugin lifecycle
    bool loadPlugin(const QString& pluginId);
    bool unloadPlugin(const QString& pluginId);
    bool enablePlugin(const QString& pluginId);
    bool disablePlugin(const QString& pluginId);
    bool reloadPlugin(const QString& pluginId);

    // Plugin management
    PluginMetadata getPlugin(const QString& pluginId);
    QVector<PluginMetadata> listAllPlugins();
    QVector<PluginMetadata> listPluginsByType(PluginType type);
    QVector<PluginMetadata> listEnabledPlugins();
    QVector<PluginMetadata> listDisabledPlugins();
    QVector<PluginMetadata> searchPlugins(const QString& query);

    // Dependency resolution
    QStringList resolveDependencies(const QString& pluginId);
    bool checkDependencies(const QString& pluginId);
    bool areDependenciesAvailable(const QString& pluginId);
    QString getDependencyStatus(const QString& pluginId);
    bool canUnload(const QString& pluginId);  // Check if other plugins depend on it

    // Hook management
    void registerHook(const struct PluginHook& hook);
    void unregisterHook(const QString& hookId);
    QVector<struct PluginHook> getHooksByType(HookType type);
    QVector<struct PluginHook> getHooksByPlugin(const QString& pluginId);
    void executeHooks(HookType type, const QJsonObject& context);
    void executeHooksAsync(HookType type, const QJsonObject& context);
    struct PluginHook getHook(const QString& hookId);

    // Command management
    void registerCommand(const PluginCommand& command);
    void unregisterCommand(const QString& commandId);
    PluginCommand getCommand(const QString& commandId);
    QVector<PluginCommand> getCommandsByPlugin(const QString& pluginId);
    QVector<PluginCommand> getAllCommands();
    bool executeCommand(const QString& commandId, const QJsonObject& params);
    QString getCommandHelp(const QString& commandId);

    // MCP Server management
    void registerMCPServer(const MCPServerConfig& config);
    void unregisterMCPServer(const QString& serverId);
    MCPServerConfig getMCPServer(const QString& serverId);
    QVector<MCPServerConfig> getMCPServersByPlugin(const QString& pluginId);
    QVector<MCPServerConfig> getAllMCPServers();
    bool startMCPServer(const QString& serverId);
    bool stopMCPServer(const QString& serverId);
    bool restartMCPServer(const QString& serverId);

    // Skill management
    void registerSkill(const struct PluginSkill& skill);
    void unregisterSkill(const QString& skillId);
    struct PluginSkill getSkill(const QString& skillId);
    QVector<struct PluginSkill> getSkillsByPlugin(const QString& pluginId);
    QVector<struct PluginSkill> getAllSkills();
    QVector<struct PluginSkill> getSkillsByTag(const QString& tag);
    QVector<struct PluginSkill> getSkillsForTask(const QString& taskType);

    // Plugin configuration
    void setPluginConfig(const QString& pluginId, const QJsonObject& config);
    QJsonObject getPluginConfig(const QString& pluginId);
    void resetPluginConfig(const QString& pluginId);
    bool validatePluginConfig(const QString& pluginId);

    // Plugin installation and updates
    bool installPlugin(const QString& pluginSource);  // URL or local path
    bool uninstallPlugin(const QString& pluginId);
    bool updatePlugin(const QString& pluginId);
    bool checkForUpdates(const QString& pluginId);
    QString getLatestVersion(const QString& pluginId);
    QVector<PluginMetadata> getAvailableUpdates();

    // Marketplace integration
    QVector<PluginMetadata> searchMarketplace(const QString& query);
    QVector<PluginMetadata> getMarketplacePlugins(int limit = 50);
    QVector<PluginMetadata> getTrendingPlugins();
    QVector<PluginMetadata> getRecommendedPlugins();
    bool installFromMarketplace(const QString& pluginId);
    QJsonObject getMarketplacePluginInfo(const QString& pluginId);

    // Plugin validation
    bool validatePlugin(const PluginMetadata& metadata);
    bool validatePluginSignature(const QString& pluginPath);
    bool checkCompatibility(const QString& pluginId);
    bool isPluginSecure(const QString& pluginId);

    // Conflict detection
    QStringList detectConflicts();
    QVector<QString> getConflictingPlugins(const QString& pluginId);
    bool canCoexist(const QString& plugin1Id, const QString& plugin2Id);

    // Logging and diagnostics
    QString getPluginErrorLog(const QString& pluginId);
    QString getHookExecutionLog(HookType type);
    void clearPluginLogs(const QString& pluginId);
    void enablePluginDebugMode(const QString& pluginId);
    void disablePluginDebugMode(const QString& pluginId);

    // Statistics
    struct PluginStats {
        int totalPlugins;
        int loadedPlugins;
        int enabledPlugins;
        int disabledPlugins;
        int failedPlugins;
        QMap<PluginType, int> pluginsByType;
        QMap<QString, int> commandsByPlugin;
        QMap<QString, int> hooksByType;
        int totalSkills;
        int totalMCPServers;
    };
    PluginStats getStatistics() const;

    // Export and import
    QJsonObject exportPluginRegistry();
    bool importPluginRegistry(const QJsonObject& registry);
    QString exportPluginConfig(const QString& pluginId);
    bool importPluginConfig(const QString& pluginId, const QString& configJson);

    // Batch operations
    void enableAllPlugins();
    void disableAllPlugins();
    void reloadAllPlugins();
    void unloadAllPlugins();

signals:
    void pluginDiscovered(const QString& pluginId);
    void pluginLoaded(const QString& pluginId);
    void pluginUnloaded(const QString& pluginId);
    void pluginEnabled(const QString& pluginId);
    void pluginDisabled(const QString& pluginId);
    void pluginFailed(const QString& pluginId, const QString& error);
    void commandExecuted(const QString& commandId);
    void hookExecuted(HookType type);
    void dependencyConflict(const QString& pluginId);

private:
    struct PluginInfo {
        PluginMetadata metadata;
        PluginStatus status;
        QVector<struct PluginHook> hooks;
        QVector<PluginCommand> commands;
        QVector<MCPServerConfig> mcpServers;
        QVector<struct PluginSkill> skills;
        QString errorLog;
        bool debugEnabled;
        qint64 loadTime;
    };

    QMap<QString, PluginInfo> m_plugins;
    QMap<HookType, QVector<struct PluginHook>> m_hooksByType;
    QMap<QString, PluginCommand> m_commands;
    QMap<QString, struct PluginSkill> m_skills;
    PluginStats m_statistics;

    QString m_marketplaceUrl;
    bool m_validateSignatures;
    bool m_enforceCompatigility;

    bool loadPluginLibrary(const QString& pluginPath);
    QVector<struct PluginHook> sortHooksByPriority(const QVector<struct PluginHook>& hooks);
    QString generateUniquePluginId();
};
