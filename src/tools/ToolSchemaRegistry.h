#pragma once

#include "ToolSchemaTypes.h"
#include <QObject>
#include <memory>

/**
 * @class ToolSchemaRegistry
 * @brief 工具模式管理系统
 * 
 * 功能：
 * - 工具模式定义
 * - 模式验证
 * - 模式版本管理
 * - 模式文档
 */
class ToolSchemaRegistry : public QObject {
    Q_OBJECT
public:
    virtual ~ToolSchemaRegistry() = default;
    
    // ── 模式管理 ───────────────────────────────────────
    
    /// 注册工具模式
    virtual QString registerSchema(const ToolSchema &schema,
                                  std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 更新工具模式
    virtual void updateSchema(const ToolSchema &schema,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 删除工具模式
    virtual void deleteSchema(const QString &toolId,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 获取工具模式
    virtual ToolSchema getSchema(const QString &toolId) const = 0;
    
    /// 获取所有模式
    virtual QVector<ToolSchema> getAllSchemas() const = 0;
    
    /// 获取指定版本的模式
    virtual ToolSchema getSchemaVersion(const QString &toolId,
                                       const QString &version) const = 0;
    
    // ── 能力管理 ───────────────────────────────────────
    
    /// 添加能力定义
    virtual void addCapability(const QString &toolId,
                              const ToolCapabilityDefinition &capability,
                              std::function<void(bool)> callback = nullptr) = 0;
    
    /// 移除能力定义
    virtual void removeCapability(const QString &toolId,
                                 const QString &capabilityName,
                                 std::function<void(bool)> callback = nullptr) = 0;
    
    /// 更新能力定义
    virtual void updateCapability(const QString &toolId,
                                 const ToolCapabilityDefinition &capability,
                                 std::function<void(bool)> callback = nullptr) = 0;
    
    /// 获取能力定义
    virtual ToolCapabilityDefinition getCapability(const QString &toolId,
                                                   const QString &capabilityName) const = 0;
    
    /// 获取所有能力
    virtual QVector<ToolCapabilityDefinition> getAllCapabilities(const QString &toolId) const = 0;
    
    // ── 模式验证 ───────────────────────────────────────
    
    /// 验证工具模式
    virtual bool validateSchema(const ToolSchema &schema,
                               QString &errorMessage) = 0;
    
    /// 验证执行参数
    virtual bool validateParameters(const QString &toolId,
                                   const QString &capabilityName,
                                   const QVariantMap &parameters,
                                   QString &errorMessage) = 0;
    
    /// 验证工具配置
    virtual bool validateConfiguration(const QString &toolId,
                                      const QVariantMap &config,
                                      QString &errorMessage) = 0;
    
    /// 验证执行结果
    virtual bool validateResult(const QString &toolId,
                               const QString &capabilityName,
                               const QVariantMap &result,
                               QString &errorMessage) = 0;
    
    // ── 模式版本控制 ────────────────────────────────────
    
    /// 创建新版本
    virtual QString createVersion(const QString &toolId,
                                 const ToolSchema &schema,
                                 const QString &description = "",
                                 std::function<void(bool)> callback = nullptr) = 0;
    
    /// 获取版本历史
    virtual QVector<QString> getVersionHistory(const QString &toolId) const = 0;
    
    /// 回滚到版本
    virtual void rollbackToVersion(const QString &toolId,
                                  const QString &version,
                                  std::function<void(bool)> callback = nullptr) = 0;
    
    /// 比较两个版本
    virtual QVariantMap compareVersions(const QString &toolId,
                                       const QString &version1,
                                       const QString &version2) const = 0;
    
    // ── 模式搜索和过滤 ──────────────────────────────────
    
    /// 搜索模式
    virtual QVector<ToolSchema> searchSchemas(const QString &keyword) const = 0;
    
    /// 按分类获取模式
    virtual QVector<ToolSchema> getSchemasByCategory(const QString &category) const = 0;
    
    /// 按标签获取模式
    virtual QVector<ToolSchema> getSchemasByTag(const QString &tag) const = 0;
    
    /// 获取具有特定能力的模式
    virtual QVector<ToolSchema> getSchemasByCapability(const QString &capabilityName) const = 0;
    
    // ── 模式依赖分析 ────────────────────────────────────
    
    /// 获取工具的依赖
    virtual QStringList getToolDependencies(const QString &toolId) const = 0;
    
    /// 获取依赖工具的工具
    virtual QStringList getToolDependents(const QString &toolId) const = 0;
    
    /// 检查依赖是否可满足
    virtual bool canResolveDependencies(const QString &toolId) const = 0;
    
    /// 获取完整的依赖树
    virtual QVariantMap getDependencyTree(const QString &toolId) const = 0;
    
    // ── 模式导入导出 ────────────────────────────────────
    
    /// 导出模式为JSON
    virtual QString exportSchemaAsJson(const QString &toolId) const = 0;
    
    /// 从JSON导入模式
    virtual QString importSchemaFromJson(const QString &jsonData,
                                        std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 导出为OpenAPI规范
    virtual QString exportAsOpenAPI(const QString &toolId) const = 0;
    
    // ── 模式统计 ────────────────────────────────────────
    
    /// 获取模式统计
    virtual QVariantMap getSchemaStatistics() const = 0;
    
    /// 获取能力统计
    virtual QVariantMap getCapabilityStatistics(const QString &toolId) const = 0;
    
    /// 获取最受欢迎的模式
    virtual QVector<ToolSchema> getPopularSchemas(int limit = 10) const = 0;

// ── 信号 ──────────────────────────────────────────────
signals:
    /// 模式已注册
    void schemaRegistered(const QString &toolId);
    
    /// 模式已更新
    void schemaUpdated(const QString &toolId);
    
    /// 模式已删除
    void schemaDeleted(const QString &toolId);
    
    /// 能力已添加
    void capabilityAdded(const QString &toolId, const QString &capabilityName);
    
    /// 能力已移除
    void capabilityRemoved(const QString &toolId, const QString &capabilityName);
};

#endif // TOOLSCHEMAREGISTRY_H
