#include "agent/MCPManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <QProcess>
#include <QDateTime>
#include <QProcessEnvironment>

// ── MCPClient Implementation ────────────────────────────────────────────

MCPClient::MCPClient(const MCPServer &server, QObject *parent)
    : QObject(parent), m_server(server)
{
}

MCPClient::~MCPClient() = default;

bool MCPClient::connect()
{
    if (m_server.type == MCPServer::Type::StdIO) {
        m_process = std::make_unique<QProcess>(this);
        
        QStringList args = m_server.args;
        
        m_process->setWorkingDirectory(m_server.workingDir);
        m_process->setProcessEnvironment(QProcessEnvironment::systemEnvironment());
        
        m_process->start(m_server.command, args);
        
        if (!m_process->waitForStarted(m_server.timeout)) {
            qWarning() << "Failed to start MCP server:" << m_server.command;
            return false;
        }
        
        m_connected = true;
        emit connected();
        qDebug() << "Connected to MCP server:" << m_server.name;
        return true;
    }
    
    // TODO: Implement SSE, HTTP, WebSocket connections
    m_connected = true;
    emit connected();
    return true;
}

void MCPClient::disconnect()
{
    if (m_process) {
        m_process->terminate();
        if (!m_process->waitForFinished(5000)) {
            m_process->kill();
        }
        m_process.reset();
    }
    m_connected = false;
    emit disconnected();
}

bool MCPClient::isConnected() const
{
    return m_connected;
}

MCPToolResult MCPClient::callTool(const QString &toolName, const QJsonObject &args)
{
    MCPToolResult result;
    result.success = false;
    
    if (!isConnected()) {
        result.error = "Not connected to server";
        return result;
    }
    
    // TODO: Implement actual MCP tool call protocol
    result.success = true;
    result.result = QJsonObject{{"status", "success"}};
    emit toolCompleted(toolName, result.result);
    
    return result;
}

QJsonObject MCPClient::getCapabilities() const
{
    QJsonObject capabilities;
    capabilities["tools"] = m_server.tools.size();
    capabilities["resources"] = m_server.resources.size();
    return capabilities;
}

QList<MCPServer::Tool> MCPClient::listTools() const
{
    return m_server.tools;
}

QList<MCPServer::Resource> MCPClient::listResources() const
{
    return m_server.resources;
}

QString MCPClient::readResource(const QString &uri)
{
    // TODO: Implement resource reading
    return "";
}

bool MCPClient::writeResource(const QString &uri, const QString &content)
{
    // TODO: Implement resource writing
    return true;
}

// ── MCPManager Implementation ───────────────────────────────────────────

MCPManager::MCPManager(QObject *parent)
    : QObject(parent)
{
}

MCPManager::~MCPManager()
{
    stopAllServers();
}

// ── Server Management ───────────────────────────────────────────────────

void MCPManager::registerServer(const MCPServer &server)
{
    m_servers[server.id] = server;
    emit serverRegistered(server.id);
    qDebug() << "Registered MCP server:" << server.name;
}

bool MCPManager::unregisterServer(const QString &serverId)
{
    stopServer(serverId);
    bool removed = m_servers.remove(serverId) > 0;
    return removed;
}

MCPServer MCPManager::getServer(const QString &serverId) const
{
    auto it = m_servers.find(serverId);
    if (it != m_servers.end()) {
        return *it;
    }
    return MCPServer();
}

QList<MCPServer> MCPManager::allServers() const
{
    return m_servers.values();
}

QList<MCPServer> MCPManager::enabledServers() const
{
    QList<MCPServer> result;
    for (const auto &server : m_servers.values()) {
        if (server.enabled) {
            result.append(server);
        }
    }
    return result;
}

// ── Server Lifecycle ────────────────────────────────────────────────────

bool MCPManager::startServer(const QString &serverId)
{
    auto it = m_servers.find(serverId);
    if (it == m_servers.end()) {
        return false;
    }
    
    auto client = createClient(*it);
    if (client && client->connect()) {
        if (m_clients.contains(serverId)) {
            delete m_clients.take(serverId);
        }
        m_clients[serverId] = client;
        emit serverStarted(serverId);
        return true;
    }
    
    delete client;
    emit serverError(serverId, "Failed to start server");
    return false;
}

bool MCPManager::stopServer(const QString &serverId)
{
    auto it = m_clients.find(serverId);
    if (it != m_clients.end()) {
        if (*it) {
            (*it)->disconnect();
            delete *it;
        }
        m_clients.erase(it);
        emit serverStopped(serverId);
        return true;
    }
    return false;
}

void MCPManager::startAllServers()
{
    for (const auto &server : enabledServers()) {
        startServer(server.id);
    }
}

void MCPManager::stopAllServers()
{
    QStringList serverIds;
    for (auto it = m_clients.begin(); it != m_clients.end(); ++it) {
        serverIds.append(it.key());
    }
    
    for (const auto &id : serverIds) {
        stopServer(id);
    }
}

bool MCPManager::isServerRunning(const QString &serverId) const
{
    auto it = m_clients.find(serverId);
    if (it != m_clients.end()) {
        return *it && (*it)->isConnected();
    }
    return false;
}

// ── Tool Integration ────────────────────────────────────────────────────

MCPToolResult MCPManager::callTool(const MCPToolCall &call)
{
    auto it = m_clients.find(call.serverId);
    if (it == m_clients.end()) {
        MCPToolResult result;
        result.success = false;
        result.error = QString("Server not found: %1").arg(call.serverId);
        return result;
    }
    
    auto result = (*it)->callTool(call.toolName, call.arguments);
    
    m_toolCallCounts[call.toolName]++;
    if (!result.success) {
        m_toolErrorCounts[call.toolName]++;
    }
    
    emit toolExecuted(call.toolName, result);
    return result;
}

MCPToolResult MCPManager::callToolByName(const QString &toolName, const QJsonObject &args)
{
    QString serverId = findServerForTool(toolName);
    if (serverId.isEmpty()) {
        MCPToolResult result;
        result.success = false;
        result.error = QString("Tool not found: %1").arg(toolName);
        return result;
    }
    
    MCPToolCall call;
    call.serverId = serverId;
    call.toolName = toolName;
    call.arguments = args;
    
    return callTool(call);
}

QList<MCPServer::Tool> MCPManager::getAllTools() const
{
    QList<MCPServer::Tool> tools;
    for (const auto &server : m_servers.values()) {
        tools.append(server.tools);
    }
    return tools;
}

QList<MCPServer::Tool> MCPManager::getServerTools(const QString &serverId) const
{
    auto it = m_servers.find(serverId);
    if (it != m_servers.end()) {
        return it->tools;
    }
    return QList<MCPServer::Tool>();
}

QString MCPManager::findServerForTool(const QString &toolName) const
{
    for (const auto &server : m_servers.values()) {
        for (const auto &tool : server.tools) {
            if (tool.name == toolName) {
                return server.id;
            }
        }
    }
    return QString();
}

// ── Resource Management ─────────────────────────────────────────────────

QList<MCPServer::Resource> MCPManager::getAllResources() const
{
    QList<MCPServer::Resource> resources;
    for (const auto &server : m_servers.values()) {
        resources.append(server.resources);
    }
    return resources;
}

QString MCPManager::readResource(const QString &uri)
{
    for (auto it = m_clients.begin(); it != m_clients.end(); ++it) {
        auto *client = it.value();
        auto content = client ? client->readResource(uri) : QString();
        if (!content.isEmpty()) {
            return content;
        }
    }
    return QString();
}

bool MCPManager::writeResource(const QString &uri, const QString &content)
{
    for (auto it = m_clients.begin(); it != m_clients.end(); ++it) {
        auto *client = it.value();
        if (client && client->writeResource(uri, content)) {
            return true;
        }
    }
    return false;
}

// ── Configuration ───────────────────────────────────────────────────────

bool MCPManager::loadServerConfigs(const QString &configPath)
{
    QFile file(configPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open MCP config:" << configPath;
        return false;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        qWarning() << "MCP config is not a JSON object";
        return false;
    }
    
    auto servers = parseMCPConfig(doc.object());
    for (const auto &server : servers) {
        registerServer(server);
    }
    
    return true;
}

bool MCPManager::saveServerConfigs(const QString &configPath) const
{
    QJsonObject config;
    QJsonArray serversArray;
    
    for (const auto &server : m_servers.values()) {
        QJsonObject serverObj;
        serverObj["id"] = server.id;
        serverObj["name"] = server.name;
        serverObj["type"] = static_cast<int>(server.type);
        serverObj["command"] = server.command;
        serverObj["enabled"] = server.enabled;
        
        serversArray.append(serverObj);
    }
    
    config["servers"] = serversArray;
    
    QFile file(configPath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to write MCP config:" << configPath;
        return false;
    }
    
    file.write(QJsonDocument(config).toJson());
    file.close();
    return true;
}

// ── Server Discovery ────────────────────────────────────────────────────

void MCPManager::discoverServers(const QStringList &pluginPaths)
{
    for (const auto &path : pluginPaths) {
        // Look for .mcp.json files in plugin directories
        // TODO: Implement directory scanning
    }
}

// ── Health and Statistics ───────────────────────────────────────────────

QJsonObject MCPManager::getServerHealth(const QString &serverId) const
{
    QJsonObject health;
    health["serverId"] = serverId;
    health["running"] = isServerRunning(serverId);
    
    auto server = getServer(serverId);
    health["enabled"] = server.enabled;
    health["toolCount"] = server.tools.size();
    
    return health;
}

QJsonObject MCPManager::getAllServersHealth() const
{
    QJsonObject health;
    QJsonArray servers;
    
    int runningCount = 0;
    for (const auto &server : m_servers.values()) {
        servers.append(getServerHealth(server.id));
        if (isServerRunning(server.id)) {
            ++runningCount;
        }
    }
    
    health["servers"] = servers;
    health["totalRunning"] = runningCount;
    
    return health;
}

QJsonObject MCPManager::getToolStatistics() const
{
    QJsonObject stats;
    QJsonObject calls;
    QJsonObject errors;
    
    for (auto it = m_toolCallCounts.begin(); it != m_toolCallCounts.end(); ++it) {
        calls[it.key()] = it.value();
        errors[it.key()] = m_toolErrorCounts.value(it.key(), 0);
    }
    
    stats["calls"] = calls;
    stats["errors"] = errors;
    return stats;
}

// ── Private helper methods ──────────────────────────────────────────────

MCPClient *MCPManager::createClient(const MCPServer &server)
{
    return new MCPClient(server, this);
}

QList<MCPServer> MCPManager::parseMCPConfig(const QJsonObject &config) const
{
    QList<MCPServer> servers;
    
    auto serversArray = config["servers"].toArray();
    for (const auto &value : serversArray) {
        if (value.isObject()) {
            auto obj = value.toObject();
            MCPServer server;
            server.id = obj["id"].toString();
            server.name = obj["name"].toString();
            server.type = static_cast<MCPServer::Type>(obj["type"].toInt());
            server.command = obj["command"].toString();
            server.enabled = obj["enabled"].toBool(true);
            
            servers.append(server);
        }
    }
    
    return servers;
}

QString MCPManager::expandEnvVars(const QString &value) const
{
    QString result = value;
    
    // Simple environment variable expansion
    QRegularExpression regex("\\$\\{([^}]+)\\}");
    QRegularExpressionMatch match;
    
    while ((match = regex.match(result)).hasMatch()) {
        QString varName = match.captured(1);
        QString varValue = qEnvironmentVariable(varName.toStdString().c_str(), "");
        result.replace(match.captured(0), varValue);
    }
    
    return result;
}
