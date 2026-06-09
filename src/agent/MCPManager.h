#pragma once

#include <QString>
#include <QMap>
#include <QList>
#include <QJsonObject>
#include <QJsonArray>
#include <QObject>
#include <QProcess>
#include <memory>

/**
 * @class MCPServer
 * @brief Represents a Model Context Protocol server
 */
struct MCPServer {
    QString id;                      ///< Server ID
    QString name;                    ///< Server name
    QString description;             ///< Server description
    
    enum class Type {
        StdIO,                       ///< Standard input/output (local)
        SSE,                         ///< Server-sent events (hosted)
        HTTP,                        ///< HTTP/REST (REST APIs)
        WebSocket                    ///< WebSocket (real-time)
    } type{Type::StdIO};
    
    // Configuration
    QString command;                 ///< Command to execute (for StdIO)
    QString url;                     ///< URL (for SSE, HTTP, WebSocket)
    QStringList args;               ///< Command arguments
    QString workingDir;             ///< Working directory
    int timeout{30000};             ///< Timeout in ms
    
    // Environment and authentication
    QMap<QString, QString> env;     ///< Environment variables
    QString authToken;              ///< Authentication token
    QString oauthConfig;            ///< OAuth configuration
    
    // Tools provided by this server
    struct Tool {
        QString name;               ///< Tool name
        QString description;        ///< Tool description
        QJsonObject inputSchema;    ///< JSON Schema for inputs
    };
    QList<Tool> tools;
    
    // Resource management
    struct Resource {
        QString uri;                ///< Resource URI
        QString name;               ///< Resource name
        QString mimeType;           ///< MIME type
        bool readable{true};
        bool writable{false};
    };
    QList<Resource> resources;
    
    // Metadata
    bool enabled{true};
    QString version;
    QString author;
};

/**
 * @class MCPToolCall
 * @brief Call to an MCP server tool
 */
struct MCPToolCall {
    QString serverId;               ///< Server ID
    QString toolName;               ///< Tool name
    QJsonObject arguments;          ///< Tool arguments
    int timeout{30000};             ///< Call timeout
};

/**
 * @class MCPToolResult
 * @brief Result from MCP tool execution
 */
struct MCPToolResult {
    bool success;
    QJsonObject result;
    QString error;
    int executionTime{0};
    QJsonObject metadata;
};

/**
 * @class MCPClient
 * @brief Client for communicating with an MCP server
 */
class MCPClient : public QObject {
    Q_OBJECT

public:
    explicit MCPClient(const MCPServer &server, QObject *parent = nullptr);
    ~MCPClient();
    
    /**
     * @brief Connect to the server
     */
    bool connect();
    
    /**
     * @brief Disconnect from server
     */
    void disconnect();
    
    /**
     * @brief Check if connected
     */
    bool isConnected() const;
    
    /**
     * @brief Call a tool
     */
    MCPToolResult callTool(const QString &toolName, const QJsonObject &args);
    
    /**
     * @brief Get server capabilities
     */
    QJsonObject getCapabilities() const;
    
    /**
     * @brief List available tools
     */
    QList<MCPServer::Tool> listTools() const;
    
    /**
     * @brief List available resources
     */
    QList<MCPServer::Resource> listResources() const;
    
    /**
     * @brief Read a resource
     */
    QString readResource(const QString &uri);
    
    /**
     * @brief Write to a resource
     */
    bool writeResource(const QString &uri, const QString &content);

signals:
    void connected();
    void disconnected();
    void error(const QString &message);
    void toolCompleted(const QString &toolName, const QJsonObject &result);

private:
    MCPServer m_server;
    std::unique_ptr<QProcess> m_process;
    bool m_connected{false};
};

/**
 * @class MCPManager
 * @brief Manages MCP server lifecycle and tool integration
 * 
 * Features:
 * - Server discovery and registration
 * - Connection lifecycle management
 * - Tool invocation
 * - Resource access
 * - Error handling and recovery
 */
class MCPManager : public QObject {
    Q_OBJECT

public:
    explicit MCPManager(QObject *parent = nullptr);
    ~MCPManager();

    // ── Server Management ───────────────────────────────────────────────────
    
    /**
     * @brief Register an MCP server
     */
    void registerServer(const MCPServer &server);
    
    /**
     * @brief Unregister an MCP server
     */
    bool unregisterServer(const QString &serverId);
    
    /**
     * @brief Get server configuration
     */
    MCPServer getServer(const QString &serverId) const;
    
    /**
     * @brief List all registered servers
     */
    QList<MCPServer> allServers() const;
    
    /**
     * @brief List enabled servers
     */
    QList<MCPServer> enabledServers() const;

    // ── Server Lifecycle ────────────────────────────────────────────────────
    
    /**
     * @brief Start a server
     */
    bool startServer(const QString &serverId);
    
    /**
     * @brief Stop a server
     */
    bool stopServer(const QString &serverId);
    
    /**
     * @brief Start all servers
     */
    void startAllServers();
    
    /**
     * @brief Stop all servers
     */
    void stopAllServers();
    
    /**
     * @brief Check if server is running
     */
    bool isServerRunning(const QString &serverId) const;

    // ── Tool Integration ────────────────────────────────────────────────────
    
    /**
     * @brief Call an MCP tool
     */
    MCPToolResult callTool(const MCPToolCall &call);
    
    /**
     * @brief Call a tool by name (searches all servers)
     */
    MCPToolResult callToolByName(const QString &toolName, const QJsonObject &args);
    
    /**
     * @brief Get all available tools from all servers
     */
    QList<MCPServer::Tool> getAllTools() const;
    
    /**
     * @brief Get tools from a specific server
     */
    QList<MCPServer::Tool> getServerTools(const QString &serverId) const;
    
    /**
     * @brief Find server providing a tool
     */
    QString findServerForTool(const QString &toolName) const;

    // ── Resource Management ─────────────────────────────────────────────────
    
    /**
     * @brief List all available resources
     */
    QList<MCPServer::Resource> getAllResources() const;
    
    /**
     * @brief Read a resource
     */
    QString readResource(const QString &uri);
    
    /**
     * @brief Write to a resource
     */
    bool writeResource(const QString &uri, const QString &content);

    // ── Configuration ───────────────────────────────────────────────────────
    
    /**
     * @brief Load server configurations from .mcp.json files
     */
    bool loadServerConfigs(const QString &configPath);
    
    /**
     * @brief Save server configurations
     */
    bool saveServerConfigs(const QString &configPath) const;

    // ── Server Discovery ────────────────────────────────────────────────────
    
    /**
     * @brief Discover MCP servers in plugin directories
     */
    void discoverServers(const QStringList &pluginPaths);

    // ── Health and Statistics ───────────────────────────────────────────────
    
    /**
     * @brief Get server health status
     */
    QJsonObject getServerHealth(const QString &serverId) const;
    
    /**
     * @brief Get all servers health
     */
    QJsonObject getAllServersHealth() const;
    
    /**
     * @brief Get tool call statistics
     */
    QJsonObject getToolStatistics() const;

signals:
    /**
     * @brief Emitted when a server is registered
     */
    void serverRegistered(const QString &serverId);
    
    /**
     * @brief Emitted when server starts
     */
    void serverStarted(const QString &serverId);
    
    /**
     * @brief Emitted when server stops
     */
    void serverStopped(const QString &serverId);
    
    /**
     * @brief Emitted when server encounters error
     */
    void serverError(const QString &serverId, const QString &error);
    
    /**
     * @brief Emitted after tool execution
     */
    void toolExecuted(const QString &toolName, const MCPToolResult &result);

private:
    /**
     * @brief Create MCP client for server
     */
    MCPClient *createClient(const MCPServer &server);
    
    /**
     * @brief Parse .mcp.json configuration
     */
    QList<MCPServer> parseMCPConfig(const QJsonObject &config) const;
    
    /**
     * @brief Expand environment variables in configuration
     */
    QString expandEnvVars(const QString &value) const;

    // ── Data members ────────────────────────────────────────────────────────
    QMap<QString, MCPServer> m_servers;
    QMap<QString, MCPClient*> m_clients;
    QMap<QString, int> m_toolCallCounts;  // Statistics
    QMap<QString, int> m_toolErrorCounts;
};
