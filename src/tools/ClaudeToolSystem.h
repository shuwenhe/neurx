#pragma once

#include "ToolSchemaTypes.h"
#include "ToolPermissionManager.h"
#include "ToolSchemaRegistry.h"
#include "ToolDiscovery.h"
#include "ToolExecutor.h"
#include <QObject>
#include <QMap>
#include <QQueue>
#include <QMutex>
#include <memory>

/**
 * @class ClaudeToolSystem
 * @brief Claude Code统一工具系统
 * 
 * 集成：
 * - 工具权限管理
 * - 工具模式注册表
 * - 工具智能发现
 * - 工具执行引擎
 */
class ClaudeToolSystem : public QObject {
    Q_OBJECT
public:
    explicit ClaudeToolSystem(QObject *parent = nullptr);
    virtual ~ClaudeToolSystem();
    
    // ── 系统初始化 ─────────────────────────────────────
    
    /// 初始化工具系统
    bool initialize();
    
    /// 关闭工具系统
    void shutdown();
    
    /// 检查系统状态
    bool isInitialized() const;
    
    // ── 子系统访问 ─────────────────────────────────────
    
    /// 获取权限管理器
    std::shared_ptr<ToolPermissionManager> getPermissionManager() const;
    
    /// 获取模式注册表
    std::shared_ptr<ToolSchemaRegistry> getSchemaRegistry() const;
    
    /// 获取工具发现系统
    std::shared_ptr<ToolDiscovery> getToolDiscovery() const;
    
    /// 获取工具执行引擎
    std::shared_ptr<ToolExecutor> getToolExecutor() const;
    
    // ── 便利方法 ───────────────────────────────────────
    
    /// 注册工具（一步到位）
    QString registerTool(const ToolSchema &schema,
                        const ToolPermission &permission = ToolPermission());
    
    /// 执行工具（一步到位）
    ToolExecutionResult executeTool(const QString &toolId,
                                   const QString &capabilityName,
                                   const QVariantMap &parameters,
                                   const QString &userId);
    
    /// 搜索并执行工具
    void smartExecute(const QString &description,
                     const QVariantMap &parameters,
                     const QString &userId,
                     std::function<void(const ToolExecutionResult&)> callback);
    
    /// 创建和执行工具链
    void executeSmartChain(const QString &description,
                          const QVariantMap &parameters,
                          const QString &userId,
                          std::function<void(const QVector<ToolExecutionResult>&)> callback);
    
    // ── 统计和报告 ─────────────────────────────────────
    
    /// 获取系统统计
    QVariantMap getSystemStatistics() const;
    
    /// 获取工具统计
    QVariantMap getToolStatistics(const QString &toolId) const;
    
    /// 生成系统报告
    QString generateSystemReport() const;
    
    /// 生成审计报告
    QString generateAuditReport(const QDateTime &from,
                               const QDateTime &to) const;

private:
    std::shared_ptr<ToolPermissionManager> m_permissionManager;
    std::shared_ptr<ToolSchemaRegistry> m_schemaRegistry;
    std::shared_ptr<ToolDiscovery> m_toolDiscovery;
    std::shared_ptr<ToolExecutor> m_toolExecutor;
    
    bool m_initialized;
    mutable QMutex m_mutex;
};
