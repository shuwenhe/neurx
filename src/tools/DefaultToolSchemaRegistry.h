#pragma once

#include "ToolSchemaRegistry.h"
#include <QMap>
#include <QSet>
#include <QMutex>

/**
 * @class DefaultToolSchemaRegistry
 * @brief 工具模式注册表默认实现
 * 
 * 功能：
 * - 工具模式存储和管理
 * - 版本控制
 * - 模式验证
 * - 依赖分析
 */
class DefaultToolSchemaRegistry : public ToolSchemaRegistry {
    Q_OBJECT
public:
    explicit DefaultToolSchemaRegistry(QObject *parent = nullptr);
    ~DefaultToolSchemaRegistry() = default;
    
    // ── 模式管理 ───────────────────────────────────────
    QString registerSchema(const ToolSchema &schema,
                          std::function<void(bool success)> callback = nullptr) override;
    
    void updateSchema(const ToolSchema &schema,
                     std::function<void(bool success)> callback = nullptr) override;
    
    void deleteSchema(const QString &toolId,
                     std::function<void(bool success)> callback = nullptr) override;
    
    ToolSchema getSchema(const QString &toolId) const override;
    
    QVector<ToolSchema> getAllSchemas() const override;
    
    ToolSchema getSchemaVersion(const QString &toolId,
                               const QString &version) const override;
    
    // ── 能力管理 ───────────────────────────────────────
    void addCapability(const QString &toolId,
                      const ToolCapabilityDefinition &capability,
                      std::function<void(bool)> callback = nullptr) override;
    
    void removeCapability(const QString &toolId,
                         const QString &capabilityName,
                         std::function<void(bool)> callback = nullptr) override;
    
    void updateCapability(const QString &toolId,
                         const ToolCapabilityDefinition &capability,
                         std::function<void(bool)> callback = nullptr) override;
    
    ToolCapabilityDefinition getCapability(const QString &toolId,
                                          const QString &capabilityName) const override;
    
    QVector<ToolCapabilityDefinition> getAllCapabilities(const QString &toolId) const override;
    
    // ── 模式验证 ───────────────────────────────────────
    bool validateSchema(const ToolSchema &schema,
                       QString &errorMessage) override;
    
    bool validateParameters(const QString &toolId,
                           const QString &capabilityName,
                           const QVariantMap &parameters,
                           QString &errorMessage) override;
    
    bool validateConfiguration(const QString &toolId,
                              const QVariantMap &config,
                              QString &errorMessage) override;
    
    bool validateResult(const QString &toolId,
                       const QString &capabilityName,
                       const QVariantMap &result,
                       QString &errorMessage) override;
    
    // ── 模式版本控制 ────────────────────────────────────
    QString createVersion(const QString &toolId,
                         const ToolSchema &schema,
                         const QString &description = "",
                         std::function<void(bool)> callback = nullptr) override;
    
    QVector<QString> getVersionHistory(const QString &toolId) const override;
    
    void rollbackToVersion(const QString &toolId,
                          const QString &version,
                          std::function<void(bool)> callback = nullptr) override;
    
    QVariantMap compareVersions(const QString &toolId,
                               const QString &version1,
                               const QString &version2) const override;
    
    // ── 模式搜索和过滤 ──────────────────────────────────
    QVector<ToolSchema> searchSchemas(const QString &keyword) const override;
    
    QVector<ToolSchema> getSchemasByCategory(const QString &category) const override;
    
    QVector<ToolSchema> getSchemasByTag(const QString &tag) const override;
    
    QVector<ToolSchema> getSchemasByCapability(const QString &capabilityName) const override;
    
    // ── 模式依赖分析 ────────────────────────────────────
    QStringList getToolDependencies(const QString &toolId) const override;
    
    QStringList getToolDependents(const QString &toolId) const override;
    
    bool canResolveDependencies(const QString &toolId) const override;
    
    QVariantMap getDependencyTree(const QString &toolId) const override;
    
    // ── 模式导入导出 ────────────────────────────────────
    QString exportSchemaAsJson(const QString &toolId) const override;
    
    QString importSchemaFromJson(const QString &jsonData,
                                std::function<void(bool success)> callback = nullptr) override;
    
    QString exportAsOpenAPI(const QString &toolId) const override;
    
    // ── 模式统计 ────────────────────────────────────────
    QVariantMap getSchemaStatistics() const override;
    
    QVariantMap getCapabilityStatistics(const QString &toolId) const override;
    
    QVector<ToolSchema> getPopularSchemas(int limit = 10) const override;

private:
    struct SchemaVersion {
        QString version;
        ToolSchema schema;
        QDateTime createdAt;
        QString description;
    };
    
    // 存储
    QMap<QString, ToolSchema> m_schemas;
    QMap<QString, QVector<SchemaVersion>> m_versions;
    QMap<QString, QVector<ToolCapabilityDefinition>> m_capabilities;
    QMap<QString, int> m_usageCount;
    
    // 依赖追踪
    QMap<QString, QStringList> m_dependencies;  // toolId -> dependencies
    QMap<QString, QStringList> m_dependents;    // toolId -> dependents
    
    mutable QMutex m_mutex;
    
    // 辅助方法
    QString generateVersion();
    
    bool validateToolId(const QString &toolId);
    
    void updateDependencyGraph(const QString &toolId);
    
    bool hasCircularDependency(const QString &toolId,
                               QSet<QString> &visited);
};
