#include "PluginSystemRegistry.h"
#include <QDebug>
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonArray>
#include <QLibrary>
#include <QUuid>
#include <algorithm>

PluginSystemRegistry::PluginSystemRegistry(QObject* parent)
    : QObject(parent),
      m_validateSignatures(true),
      m_enforceCompatigility(true)
{
    m_statistics.totalPlugins = 0;
    m_statistics.loadedPlugins = 0;
    m_statistics.enabledPlugins = 0;
    m_statistics.disabledPlugins = 0;
    m_statistics.failedPlugins = 0;
    m_statistics.totalSkills = 0;
    m_statistics.totalMCPServers = 0;
}

PluginSystemRegistry::~PluginSystemRegistry() = default;

void PluginSystemRegistry::discoverPlugins(const QString& directory)
{
    QDir dir(directory);
    QStringList filters;
    filters << "*.so" << "*.dll" << "*.dylib";
    dir.setNameFilters(filters);

    QFileInfoList files = dir.entryInfoList(QDir::Files);

    for (const auto& file : files) {
        PluginMetadata metadata;
        metadata.id = file.baseName();
        metadata.name = file.baseName();
        metadata.installPath = file.filePath();
        metadata.enabled = false;

        registerPlugin(metadata);
        m_statistics.totalPlugins++;
        
        emit pluginDiscovered(metadata.id);
    }
}

void PluginSystemRegistry::registerPlugin(const PluginMetadata& metadata)
{
    PluginInfo info;
    info.metadata = metadata;
    info.status = Discovered;
    info.debugEnabled = false;
    info.loadTime = 0;

    m_plugins[metadata.id] = info;
}

bool PluginSystemRegistry::unregisterPlugin(const QString& pluginId)
{
    if (!m_plugins.contains(pluginId)) {
        return false;
    }

    // Check if other plugins depend on it
    if (!canUnload(pluginId)) {
        return false;
    }

    m_plugins.remove(pluginId);
    m_statistics.totalPlugins--;

    return true;
}

void PluginSystemRegistry::rescanPlugins()
{
    m_plugins.clear();
}

bool PluginSystemRegistry::loadPlugin(const QString& pluginId)
{
    if (!m_plugins.contains(pluginId)) {
        return false;
    }

    auto& plugin = m_plugins[pluginId];

    if (plugin.status == Loaded || plugin.status == Enabled) {
        return true;
    }

    // Load plugin library
    if (!loadPluginLibrary(plugin.metadata.installPath)) {
        plugin.status = Failed;
        m_statistics.failedPlugins++;
        emit pluginFailed(pluginId, "Failed to load plugin library");
        return false;
    }

    plugin.status = Loaded;
    plugin.loadTime = QDateTime::currentMSecsSinceEpoch();
    m_statistics.loadedPlugins++;

    emit pluginLoaded(pluginId);

    return true;
}

bool PluginSystemRegistry::unloadPlugin(const QString& pluginId)
{
    if (!m_plugins.contains(pluginId)) {
        return false;
    }

    auto& plugin = m_plugins[pluginId];

    if (plugin.status == Discovered) {
        return true;
    }

    plugin.status = Discovered;
    m_statistics.loadedPlugins--;
    if (plugin.metadata.enabled) {
        m_statistics.enabledPlugins--;
    }

    emit pluginUnloaded(pluginId);

    return true;
}

bool PluginSystemRegistry::enablePlugin(const QString& pluginId)
{
    if (!m_plugins.contains(pluginId)) {
        return false;
    }

    auto& plugin = m_plugins[pluginId];

    // Load if not already loaded
    if (plugin.status == Discovered) {
        if (!loadPlugin(pluginId)) {
            return false;
        }
    }

    plugin.metadata.enabled = true;
    plugin.status = Enabled;
    m_statistics.enabledPlugins++;

    emit pluginEnabled(pluginId);

    return true;
}

bool PluginSystemRegistry::disablePlugin(const QString& pluginId)
{
    if (!m_plugins.contains(pluginId)) {
        return false;
    }

    auto& plugin = m_plugins[pluginId];

    plugin.metadata.enabled = false;
    plugin.status = Disabled;
    m_statistics.enabledPlugins--;

    emit pluginDisabled(pluginId);

    return true;
}

bool PluginSystemRegistry::reloadPlugin(const QString& pluginId)
{
    if (!unloadPlugin(pluginId)) {
        return false;
    }

    return loadPlugin(pluginId);
}

PluginSystemRegistry::PluginMetadata PluginSystemRegistry::getPlugin(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].metadata;
    }
    return PluginMetadata();
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::listAllPlugins()
{
    QVector<PluginMetadata> plugins;
    for (const auto& plugin : m_plugins) {
        plugins.append(plugin.metadata);
    }
    return plugins;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::listPluginsByType(PluginType type)
{
    QVector<PluginMetadata> plugins;
    for (const auto& plugin : m_plugins) {
        if (plugin.metadata.type == type) {
            plugins.append(plugin.metadata);
        }
    }
    return plugins;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::listEnabledPlugins()
{
    QVector<PluginMetadata> plugins;
    for (const auto& plugin : m_plugins) {
        if (plugin.metadata.enabled) {
            plugins.append(plugin.metadata);
        }
    }
    return plugins;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::listDisabledPlugins()
{
    QVector<PluginMetadata> plugins;
    for (const auto& plugin : m_plugins) {
        if (!plugin.metadata.enabled) {
            plugins.append(plugin.metadata);
        }
    }
    return plugins;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::searchPlugins(const QString& query)
{
    QVector<PluginMetadata> results;
    QString lowerQuery = query.toLower();

    for (const auto& plugin : m_plugins) {
        if (plugin.metadata.name.toLower().contains(lowerQuery) ||
            plugin.metadata.description.toLower().contains(lowerQuery)) {
            results.append(plugin.metadata);
        }
    }

    return results;
}

QStringList PluginSystemRegistry::resolveDependencies(const QString& pluginId)
{
    QStringList resolved;

    if (!m_plugins.contains(pluginId)) {
        return resolved;
    }

    const auto& plugin = m_plugins[pluginId];

    for (const auto& depId : plugin.metadata.dependencies) {
        if (m_plugins.contains(depId)) {
            resolved.append(depId);
        }
    }

    return resolved;
}

bool PluginSystemRegistry::checkDependencies(const QString& pluginId)
{
    QStringList deps = resolveDependencies(pluginId);

    if (deps.length() != m_plugins[pluginId].metadata.dependencies.length()) {
        emit dependencyConflict(pluginId);
        return false;
    }

    return true;
}

bool PluginSystemRegistry::areDependenciesAvailable(const QString& pluginId)
{
    return checkDependencies(pluginId);
}

QString PluginSystemRegistry::getDependencyStatus(const QString& pluginId)
{
    if (checkDependencies(pluginId)) {
        return "All dependencies satisfied";
    }
    return "Missing dependencies";
}

bool PluginSystemRegistry::canUnload(const QString& pluginId)
{
    // Check if other plugins depend on this one
    for (const auto& plugin : m_plugins) {
        if (plugin.metadata.dependencies.contains(pluginId)) {
            return false;
        }
    }
    return true;
}

void PluginSystemRegistry::registerHook(const PluginHook& hook)
{
    m_hooksByType[hook.type].append(hook);

    if (m_plugins.contains(hook.pluginId)) {
        m_plugins[hook.pluginId].hooks.append(hook);
    }
}

void PluginSystemRegistry::unregisterHook(const QString& hookId)
{
    for (auto& hooks : m_hooksByType) {
        hooks.erase(
            std::remove_if(hooks.begin(), hooks.end(),
                          [&](const PluginHook& h) { return h.id == hookId; }),
            hooks.end()
        );
    }
}

QVector<PluginSystemRegistry::PluginHook> PluginSystemRegistry::getHooksByType(HookType type)
{
    if (m_hooksByType.contains(type)) {
        return sortHooksByPriority(m_hooksByType[type]);
    }
    return QVector<PluginHook>();
}

QVector<PluginSystemRegistry::PluginHook> PluginSystemRegistry::getHooksByPlugin(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].hooks;
    }
    return QVector<PluginHook>();
}

void PluginSystemRegistry::executeHooks(HookType type, const QJsonObject& context)
{
    auto hooks = getHooksByType(type);
    for (const auto& hook : hooks) {
        // Execute hook synchronously
        emit hookExecuted(type);
    }
}

void PluginSystemRegistry::executeHooksAsync(HookType type, const QJsonObject& context)
{
    auto hooks = getHooksByType(type);
    for (const auto& hook : hooks) {
        // Execute hook asynchronously
        emit hookExecuted(type);
    }
}

PluginSystemRegistry::PluginHook PluginSystemRegistry::getHook(const QString& hookId)
{
    for (const auto& hooks : m_hooksByType) {
        for (const auto& hook : hooks) {
            if (hook.id == hookId) {
                return hook;
            }
        }
    }
    return PluginHook();
}

void PluginSystemRegistry::registerCommand(const PluginCommand& command)
{
    m_commands[command.id] = command;

    if (m_plugins.contains(command.pluginId)) {
        m_plugins[command.pluginId].commands.append(command);
        m_statistics.commandsByPlugin[command.pluginId]++;
    }
}

void PluginSystemRegistry::unregisterCommand(const QString& commandId)
{
    if (m_commands.contains(commandId)) {
        m_commands.remove(commandId);
    }
}

PluginSystemRegistry::PluginCommand PluginSystemRegistry::getCommand(const QString& commandId)
{
    return m_commands.value(commandId, PluginCommand());
}

QVector<PluginSystemRegistry::PluginCommand> PluginSystemRegistry::getCommandsByPlugin(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].commands;
    }
    return QVector<PluginCommand>();
}

QVector<PluginSystemRegistry::PluginCommand> PluginSystemRegistry::getAllCommands()
{
    return m_commands.values().toVector();
}

bool PluginSystemRegistry::executeCommand(const QString& commandId, const QJsonObject& params)
{
    if (!m_commands.contains(commandId)) {
        return false;
    }

    const auto& command = m_commands[commandId];

    if (!command.enabled) {
        return false;
    }

    // Execute command handler
    emit commandExecuted(commandId);

    return true;
}

QString PluginSystemRegistry::getCommandHelp(const QString& commandId)
{
    if (m_commands.contains(commandId)) {
        return m_commands[commandId].description;
    }
    return "";
}

void PluginSystemRegistry::registerMCPServer(const MCPServerConfig& config)
{
    if (m_plugins.contains(config.pluginId)) {
        m_plugins[config.pluginId].mcpServers.append(config);
        m_statistics.totalMCPServers++;
    }
}

void PluginSystemRegistry::unregisterMCPServer(const QString& serverId)
{
    for (auto& plugin : m_plugins) {
        plugin.mcpServers.erase(
            std::remove_if(plugin.mcpServers.begin(), plugin.mcpServers.end(),
                          [&](const MCPServerConfig& s) { return s.id == serverId; }),
            plugin.mcpServers.end()
        );
    }
    m_statistics.totalMCPServers--;
}

PluginSystemRegistry::MCPServerConfig PluginSystemRegistry::getMCPServer(const QString& serverId)
{
    for (const auto& plugin : m_plugins) {
        for (const auto& server : plugin.mcpServers) {
            if (server.id == serverId) {
                return server;
            }
        }
    }
    return MCPServerConfig();
}

QVector<PluginSystemRegistry::MCPServerConfig> PluginSystemRegistry::getMCPServersByPlugin(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].mcpServers;
    }
    return QVector<MCPServerConfig>();
}

QVector<PluginSystemRegistry::MCPServerConfig> PluginSystemRegistry::getAllMCPServers()
{
    QVector<MCPServerConfig> servers;
    for (const auto& plugin : m_plugins) {
        servers.append(plugin.mcpServers);
    }
    return servers;
}

bool PluginSystemRegistry::startMCPServer(const QString& serverId)
{
    return true;
}

bool PluginSystemRegistry::stopMCPServer(const QString& serverId)
{
    return true;
}

bool PluginSystemRegistry::restartMCPServer(const QString& serverId)
{
    stopMCPServer(serverId);
    return startMCPServer(serverId);
}

void PluginSystemRegistry::registerSkill(const PluginSkill& skill)
{
    m_skills[skill.id] = skill;

    if (m_plugins.contains(skill.pluginId)) {
        m_plugins[skill.pluginId].skills.append(skill);
        m_statistics.totalSkills++;
    }
}

void PluginSystemRegistry::unregisterSkill(const QString& skillId)
{
    if (m_skills.contains(skillId)) {
        m_skills.remove(skillId);
        m_statistics.totalSkills--;
    }
}

PluginSystemRegistry::PluginSkill PluginSystemRegistry::getSkill(const QString& skillId)
{
    return m_skills.value(skillId, PluginSkill());
}

QVector<PluginSystemRegistry::PluginSkill> PluginSystemRegistry::getSkillsByPlugin(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].skills;
    }
    return QVector<PluginSkill>();
}

QVector<PluginSystemRegistry::PluginSkill> PluginSystemRegistry::getAllSkills()
{
    return m_skills.values().toVector();
}

QVector<PluginSystemRegistry::PluginSkill> PluginSystemRegistry::getSkillsByTag(const QString& tag)
{
    QVector<PluginSkill> results;
    for (const auto& skill : m_skills) {
        if (skill.tags.contains(tag)) {
            results.append(skill);
        }
    }
    return results;
}

QVector<PluginSystemRegistry::PluginSkill> PluginSystemRegistry::getSkillsForTask(const QString& taskType)
{
    QVector<PluginSkill> results;
    for (const auto& skill : m_skills) {
        if (skill.applicableTasks.contains(taskType)) {
            results.append(skill);
        }
    }
    return results;
}

void PluginSystemRegistry::setPluginConfig(const QString& pluginId, const QJsonObject& config)
{
    if (m_plugins.contains(pluginId)) {
        m_plugins[pluginId].metadata.config = config;
    }
}

QJsonObject PluginSystemRegistry::getPluginConfig(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].metadata.config;
    }
    return QJsonObject();
}

void PluginSystemRegistry::resetPluginConfig(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        m_plugins[pluginId].metadata.config = QJsonObject();
    }
}

bool PluginSystemRegistry::validatePluginConfig(const QString& pluginId)
{
    return true;
}

bool PluginSystemRegistry::installPlugin(const QString& pluginSource)
{
    return true;
}

bool PluginSystemRegistry::uninstallPlugin(const QString& pluginId)
{
    return unregisterPlugin(pluginId);
}

bool PluginSystemRegistry::updatePlugin(const QString& pluginId)
{
    return reloadPlugin(pluginId);
}

bool PluginSystemRegistry::checkForUpdates(const QString& pluginId)
{
    return false;
}

QString PluginSystemRegistry::getLatestVersion(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].metadata.version;
    }
    return "";
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::getAvailableUpdates()
{
    QVector<PluginMetadata> updates;
    return updates;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::searchMarketplace(const QString& query)
{
    QVector<PluginMetadata> results;
    return results;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::getMarketplacePlugins(int limit)
{
    QVector<PluginMetadata> plugins;
    return plugins;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::getTrendingPlugins()
{
    QVector<PluginMetadata> plugins;
    return plugins;
}

QVector<PluginSystemRegistry::PluginMetadata> PluginSystemRegistry::getRecommendedPlugins()
{
    QVector<PluginMetadata> plugins;
    return plugins;
}

bool PluginSystemRegistry::installFromMarketplace(const QString& pluginId)
{
    return true;
}

QJsonObject PluginSystemRegistry::getMarketplacePluginInfo(const QString& pluginId)
{
    QJsonObject info;
    return info;
}

bool PluginSystemRegistry::validatePlugin(const PluginMetadata& metadata)
{
    return true;
}

bool PluginSystemRegistry::validatePluginSignature(const QString& pluginPath)
{
    return !m_validateSignatures;
}

bool PluginSystemRegistry::checkCompatibility(const QString& pluginId)
{
    return true;
}

bool PluginSystemRegistry::isPluginSecure(const QString& pluginId)
{
    return true;
}

QStringList PluginSystemRegistry::detectConflicts()
{
    QStringList conflicts;
    return conflicts;
}

QVector<QString> PluginSystemRegistry::getConflictingPlugins(const QString& pluginId)
{
    QVector<QString> conflicting;
    return conflicting;
}

bool PluginSystemRegistry::canCoexist(const QString& plugin1Id, const QString& plugin2Id)
{
    return true;
}

QString PluginSystemRegistry::getPluginErrorLog(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        return m_plugins[pluginId].errorLog;
    }
    return "";
}

QString PluginSystemRegistry::getHookExecutionLog(HookType type)
{
    return "Hook execution log";
}

void PluginSystemRegistry::clearPluginLogs(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        m_plugins[pluginId].errorLog.clear();
    }
}

void PluginSystemRegistry::enablePluginDebugMode(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        m_plugins[pluginId].debugEnabled = true;
    }
}

void PluginSystemRegistry::disablePluginDebugMode(const QString& pluginId)
{
    if (m_plugins.contains(pluginId)) {
        m_plugins[pluginId].debugEnabled = false;
    }
}

PluginSystemRegistry::PluginStats PluginSystemRegistry::getStatistics() const
{
    return m_statistics;
}

QJsonObject PluginSystemRegistry::exportPluginRegistry()
{
    QJsonObject root;
    QJsonArray pluginsArray;

    for (const auto& plugin : m_plugins) {
        QJsonObject pluginObj;
        pluginObj["id"] = plugin.metadata.id;
        pluginObj["name"] = plugin.metadata.name;
        pluginObj["version"] = plugin.metadata.version;
        pluginObj["enabled"] = plugin.metadata.enabled;
        pluginsArray.append(pluginObj);
    }

    root["plugins"] = pluginsArray;
    return root;
}

bool PluginSystemRegistry::importPluginRegistry(const QJsonObject& registry)
{
    if (!registry.contains("plugins")) {
        return false;
    }

    QJsonArray pluginsArray = registry.value(QLatin1String("plugins")).toArray();
    for (const auto& plugin : pluginsArray) {
        if (plugin.isObject()) {
            PluginMetadata metadata;
            metadata.id = plugin.toObject().value(QLatin1String("id")).toString();
            metadata.name = plugin.toObject().value(QLatin1String("name")).toString();
            metadata.version = plugin.toObject().value(QLatin1String("version")).toString();
            metadata.enabled = plugin.toObject().value(QLatin1String("enabled")).toBool();

            registerPlugin(metadata);
        }
    }

    return true;
}

QString PluginSystemRegistry::exportPluginConfig(const QString& pluginId)
{
    QJsonObject config = getPluginConfig(pluginId);
    return QJsonDocument(config).toJson();
}

bool PluginSystemRegistry::importPluginConfig(const QString& pluginId, const QString& configJson)
{
    QJsonDocument doc = QJsonDocument::fromJson(configJson.toUtf8());
    if (doc.isObject()) {
        setPluginConfig(pluginId, doc.object());
        return true;
    }
    return false;
}

void PluginSystemRegistry::enableAllPlugins()
{
    for (const auto& pluginId : m_plugins.keys()) {
        enablePlugin(pluginId);
    }
}

void PluginSystemRegistry::disableAllPlugins()
{
    for (const auto& pluginId : m_plugins.keys()) {
        disablePlugin(pluginId);
    }
}

void PluginSystemRegistry::reloadAllPlugins()
{
    for (const auto& pluginId : m_plugins.keys()) {
        reloadPlugin(pluginId);
    }
}

void PluginSystemRegistry::unloadAllPlugins()
{
    for (const auto& pluginId : m_plugins.keys()) {
        unloadPlugin(pluginId);
    }
}

bool PluginSystemRegistry::loadPluginLibrary(const QString& pluginPath)
{
    QLibrary lib(pluginPath);
    return lib.load();
}

QVector<PluginSystemRegistry::PluginHook> PluginSystemRegistry::sortHooksByPriority(const QVector<PluginHook>& hooks)
{
    QVector<PluginHook> sorted = hooks;
    std::sort(sorted.begin(), sorted.end(),
             [](const PluginHook& a, const PluginHook& b) { return a.priority > b.priority; });
    return sorted;
}

QString PluginSystemRegistry::generateUniquePluginId()
{
    return QUuid::createUuid().toString();
}
