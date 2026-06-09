#pragma once

#include <QString>
#include <QMap>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <functional>
#include <QObject>

/**
 * @class ToolDiscoveryManager
 * @brief Automatically discovers, catalogs, and manages available tools
 *
 * Features:
 * - Auto-discovery of available tools from registry
 * - Tool filtering and searching
 * - Tool metadata caching
 * - Category-based organization
 * - Capability matching
 * - Performance metrics tracking
 * - Tool compatibility checking
 *
 * Usage:
 *   ToolDiscoveryManager discovery;
 *   discovery.discoverAllTools();
 *   auto tools = discovery.findToolsByCapability("file_write");
 *   auto info = discovery.getToolInfo("WriteTool");
 */

class ToolDiscoveryManager : public QObject {
    Q_OBJECT

public:
    explicit ToolDiscoveryManager(QObject *parent = nullptr);
    ~ToolDiscoveryManager();

    /// Tool metadata structure
    struct ToolMetadata {
        QString id;                           // Unique tool ID
        QString name;                         // Human-readable name
        QString description;                  // Tool description
        QString category;                     // Category (e.g., "file_ops", "code_gen")
        QStringList capabilities;             // List of capabilities
        QStringList aliases;                  // Tool aliases
        QJsonObject schema;                   // Parameter schema
        QMap<QString, QVariant> config;       // Configuration options
        int priority = 50;                    // Tool priority (0-100)
        bool enabled = true;                  // Whether tool is enabled
        int estimatedExecutionTime = -1;      // Estimated execution time (ms, -1 = unknown)
        QString version;                      // Tool version
        QStringList dependencies;             // Tool dependencies
        int usageCount = 0;                   // Number of uses
        double successRate = 1.0;             // Success rate (0.0-1.0)
        QDateTime lastUsed;                   // Last usage timestamp
    };

    /// Discovery filter structure
    struct DiscoveryFilter {
        QStringList categories;               // Filter by categories
        QStringList capabilities;             // Filter by capabilities
        bool enabledOnly = true;              // Only enabled tools
        int minPriority = 0;                  // Minimum priority threshold
        QStringList excludeIds;               // Tool IDs to exclude
        QString searchText;                   // Text search
    };

    // Discovery operations
    /**
     * Discover all available tools in the system
     * @return Number of tools discovered
     */
    int discoverAllTools();

    /**
     * Discover tools in a specific directory
     * @param directory Path to search for tool definitions
     * @return Number of tools discovered
     */
    int discoverFromDirectory(const QString &directory);

    /**
     * Register a manually created tool
     * @param metadata Tool metadata to register
     * @return Success flag
     */
    bool registerTool(const ToolMetadata &metadata);

    /**
     * Unregister a tool
     * @param toolId Tool identifier
     * @return Success flag
     */
    bool unregisterTool(const QString &toolId);

    /**
     * Refresh tool information (re-scan for updates)
     * @param toolId Tool ID (empty = refresh all)
     * @return Number of tools refreshed
     */
    int refreshTools(const QString &toolId = "");

    // Discovery queries
    /**
     * Find tools by capability
     * @param capability Capability to search for
     * @return List of matching tool IDs
     */
    QStringList findToolsByCapability(const QString &capability) const;

    /**
     * Find tools by category
     * @param category Category to search for
     * @return List of matching tool IDs
     */
    QStringList findToolsByCategory(const QString &category);

    /**
     * Find tools by text search
     * @param searchText Text to search for
     * @param includeDescription Include description in search
     * @return List of matching tool IDs
     */
    QStringList findToolsBySearch(const QString &searchText, bool includeDescription = true);

    /**
     * Find tools matching filter
     * @param filter Discovery filter
     * @return List of matching tool IDs
     */
    QStringList findToolsByFilter(const DiscoveryFilter &filter);

    /**
     * Check if tool exists
     * @param toolId Tool identifier
     * @return True if tool is registered
     */
    bool hasTool(const QString &toolId) const;

    /**
     * Get tool metadata
     * @param toolId Tool identifier
     * @return Tool metadata (null if not found)
     */
    const ToolMetadata *getToolInfo(const QString &toolId) const;

    /**
     * Get tool metadata by alias
     * @param alias Tool alias
     * @return Tool metadata (null if not found)
     */
    const ToolMetadata *getToolByAlias(const QString &alias) const;

    // Capability operations
    /**
     * Get list of all available capabilities
     * @return List of capability strings
     */
    QStringList getAllCapabilities() const;

    /**
     * Get list of all tool categories
     * @return List of category strings
     */
    QStringList getAllCategories() const;

    /**
     * Check if tool has capability
     * @param toolId Tool identifier
     * @param capability Capability to check
     * @return True if tool has capability
     */
    bool hasCapability(const QString &toolId, const QString &capability) const;

    /**
     * Get all tools with specific capability
     * @param capability Capability to match
     * @return List of tool IDs
     */
    QStringList getToolsWithCapability(const QString &capability) const;

    /**
     * Find best tool for task
     * @param requiredCapabilities Required capabilities
     * @param preferredCapabilities Preferred additional capabilities
     * @return Best matching tool ID or empty string
     */
    QString findBestTool(const QStringList &requiredCapabilities,
                         const QStringList &preferredCapabilities = {}) const;

    // Statistics and metrics
    /**
     * Get discovery statistics
     * @return Statistics as JSON object
     */
    QJsonObject getStatistics() const;

    /**
     * Get tool usage statistics
     * @param toolId Tool identifier
     * @return Usage stats: { "uses": int, "success_rate": double, "last_used": string }
     */
    QJsonObject getToolStats(const QString &toolId) const;

    /**
     * Update tool usage statistics
     * @param toolId Tool identifier
     * @param success Whether execution succeeded
     */
    void recordToolUsage(const QString &toolId, bool success);

    /**
     * Get performance report
     * @return Performance data as JSON
     */
    QJsonObject getPerformanceReport() const;

    // Tool compatibility
    /**
     * Check tool compatibility with environment
     * @param toolId Tool identifier
     * @return Compatibility score (0.0-1.0)
     */
    double checkCompatibility(const QString &toolId) const;

    /**
     * Resolve tool dependencies
     * @param toolId Tool identifier
     * @return List of required dependency tool IDs
     */
    QStringList resolveDependencies(const QString &toolId) const;

    /**
     * Check if dependencies are available
     * @param toolId Tool identifier
     * @return True if all dependencies are available
     */
    bool areDependenciesAvailable(const QString &toolId) const;

    // Organization
    /**
     * Get all available tool categories
     * @return Map of category to tool IDs
     */
    QMap<QString, QStringList> getCategorizedTools() const;

    /**
     * Get tools in priority order
     * @param descending True for highest priority first
     * @return Sorted list of tool IDs
     */
    QStringList getToolsByPriority(bool descending = true) const;

    /**
     * Get recommended tools for common tasks
     * @return Map of task name to recommended tool IDs
     */
    QMap<QString, QStringList> getRecommendedTools() const;

    /**
     * Sort tools by metric
     * @param toolIds List of tool IDs to sort
     * @param metric Metric name ("priority", "success_rate", "speed", "usage")
     * @return Sorted tool IDs
     */
    QStringList sortToolsByMetric(const QStringList &toolIds, const QString &metric) const;

    // Import/Export
    /**
     * Export tool catalog to JSON
     * @return JSON representation of all tools
     */
    QJsonObject exportCatalog() const;

    /**
     * Import tool catalog from JSON
     * @param catalogJson JSON catalog data
     * @return Number of tools imported
     */
    int importCatalog(const QJsonObject &catalogJson);

    /**
     * Export tool configuration
     * @param toolId Tool identifier
     * @return Tool configuration as JSON
     */
    QJsonObject exportToolConfig(const QString &toolId) const;

    /**
     * Import tool configuration
     * @param toolId Tool identifier
     * @param config Configuration JSON
     * @return Success flag
     */
    bool importToolConfig(const QString &toolId, const QJsonObject &config);

    // Cache management
    /**
     * Clear discovery cache
     */
    void clearCache();

    /**
     * Force re-discovery on next query
     */
    void invalidateCache();

    /**
     * Get cache statistics
     * @return Cache stats: { "hits": int, "misses": int, "size": int }
     */
    QJsonObject getCacheStats() const;

signals:
    /// Emitted when tool is discovered
    void toolDiscovered(const QString &toolId);

    /// Emitted when tool is registered
    void toolRegistered(const QString &toolId);

    /// Emitted when tool is unregistered
    void toolUnregistered(const QString &toolId);

    /// Emitted when discovery is complete
    void discoveryComplete(int toolCount);

    /// Emitted when tool statistics are updated
    void toolStatsUpdated(const QString &toolId);

private:
    struct DiscoveryContext {
        QMap<QString, ToolMetadata> tools;
        QMap<QString, QString> aliasMap;          // alias -> tool ID
        QMap<QString, QStringList> capabilityMap;  // capability -> tool IDs
        QMap<QString, QStringList> categoryMap;    // category -> tool IDs
        bool cacheValid = false;
        int cacheHits = 0;
        int cacheMisses = 0;
    };

    DiscoveryContext m_context;
    std::map<QString, int> m_usageStats;
    std::map<QString, double> m_successRates;

    // Helper methods
    void _buildCaches();
    void _scanToolDefinitions();
    bool _isCompatible(const ToolMetadata &metadata) const;
    double _calculateScore(const ToolMetadata &metadata,
                          const QStringList &required,
                          const QStringList &preferred) const;
};
