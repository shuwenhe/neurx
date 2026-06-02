#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVector>
#include <QQueue>
#include <QMutex>
#include <memory>
#include <functional>

#include "tools/ClaudeToolSystem.h"
#include "code/DefaultCodeMagic.h"
#include "memory/DefaultMemoryManager.h"
#include "approvals/DefaultApprovalManager.h"
#include "plugins/DefaultPluginManager.h"

class AgentController;

/**
 * @brief ToolBridge - Claude工具系统与AgentController的核心适配层
 * 
 * 功能：
 * - 统一工具系统与neurx所有核心系统的接口
 * - 管理异步任务队列和并发执行
 * - 协调多个系统的集成点
 * - 提供信号-槽和回调两种异步模式
 */
class ToolBridge : public QObject {
    Q_OBJECT

public:
    explicit ToolBridge(QObject *parent = nullptr);
    ~ToolBridge();

    // ── 初始化 ────────────────────────────────────────

    /**
     * @brief 初始化工具桥接
     * @param controller AgentController指针
     * @return 是否成功初始化
     */
    bool initialize(AgentController *controller);

    /**
     * @brief 是否已初始化
     */
    bool isInitialized() const;

    /**
     * @brief 关闭桥接
     */
    void shutdown();

    // ── 系统访问 ────────────────────────────────────────

    /**
     * @brief 获取Claude工具系统
     */
    std::shared_ptr<ClaudeToolSystem> getToolSystem() const;

    /**
     * @brief 获取CodeMagic系统
     */
    std::shared_ptr<DefaultCodeMagic> getCodeMagic() const;

    /**
     * @brief 获取Memory系统
     */
    std::shared_ptr<DefaultMemoryManager> getMemory() const;

    /**
     * @brief 获取Approval系统
     */
    std::shared_ptr<DefaultApprovalManager> getApproval() const;

    /**
     * @brief 获取Plugin系统
     */
    std::shared_ptr<DefaultPluginManager> getPlugins() const;

    // ── 工具执行 ────────────────────────────────────────

    /**
     * @brief 执行单个工具
     * @param toolId 工具ID
     * @param capabilityName 能力名称
     * @param parameters 参数
     * @param userId 用户ID
     * @return 执行ID
     */
    QString executeTool(
        const QString &toolId,
        const QString &capabilityName,
        const QVariantMap &parameters,
        const QString &userId = "");

    /**
     * @brief 异步执行工具
     * @param toolId 工具ID
     * @param capabilityName 能力名称
     * @param parameters 参数
     * @param callback 完成回调
     * @return 执行ID
     */
    QString executeToolAsync(
        const QString &toolId,
        const QString &capabilityName,
        const QVariantMap &parameters,
        std::function<void(const ToolExecutionResult&)> callback);

    /**
     * @brief 执行工具链
     * @param chainId 链ID或描述
     * @param parameters 全局参数
     * @param callback 完成回调
     */
    void executeToolChain(
        const QString &chainId,
        const QVariantMap &parameters,
        std::function<void(const QVector<ToolExecutionResult>&)> callback);

    /**
     * @brief 获取执行状态
     */
    ExecutionStatus getExecutionStatus(const QString &executionId) const;

    /**
     * @brief 获取执行结果
     */
    ToolExecutionResult getExecutionResult(const QString &executionId) const;

    /**
     * @brief 取消执行
     */
    void cancelExecution(const QString &executionId);

    // ── 工具发现和推荐 ────────────────────────────────────────

    /**
     * @brief 搜索工具
     * @param keywords 关键词
     * @param category 分类（可选）
     * @return 搜索结果
     */
    QVector<ToolSchema> searchTools(
        const QString &keywords,
        const QString &category = "");

    /**
     * @brief 推荐工具
     * @param description 需求描述
     * @return 推荐工具列表
     */
    QVector<ToolSchema> recommendTools(const QString &description);

    /**
     * @brief 异步推荐工具
     * @param description 需求描述
     * @param callback 完成回调
     */
    void recommendToolsAsync(
        const QString &description,
        std::function<void(const QVector<ToolSchema>&)> callback);

    /**
     * @brief 获取工具详情
     */
    ToolSchema getToolDetails(const QString &toolId) const;

    /**
     * @brief 获取工具的兼容链
     */
    QVector<QVector<ToolSchema>> getCompatibleChains(const QString &toolId) const;

    // ── 统计和监控 ────────────────────────────────────────

    /**
     * @brief 获取工具统计信息
     */
    QVariantMap getToolStatistics(const QString &toolId) const;

    /**
     * @brief 获取系统统计信息
     */
    QVariantMap getSystemStatistics() const;

    /**
     * @brief 获取执行历史
     */
    QVector<ToolExecutionResult> getExecutionHistory(
        const QString &toolId = "",
        int limit = 100) const;

    /**
     * @brief 获取失败的执行
     */
    QVector<ToolExecutionResult> getFailedExecutions(int limit = 50) const;

    /**
     * @brief 获取性能指标
     */
    QVariantMap getPerformanceMetrics(const QString &toolId = "") const;

    // ── 权限和审批 ────────────────────────────────────────

    /**
     * @brief 检查工具访问权限
     */
    bool checkToolAccess(
        const QString &toolId,
        const QString &userId) const;

    /**
     * @brief 检查执行权限
     */
    bool checkExecutionPermission(
        const ToolExecutionRequest &request,
        const QString &userId) const;

    /**
     * @brief 请求执行批准
     */
    void requestExecutionApproval(
        const ToolExecutionRequest &request,
        std::function<void(bool approved)> callback);

    /**
     * @brief 获取审计日志
     */
    QVector<QVariantMap> getAuditLog(
        const QString &toolId = "",
        int limit = 100) const;

    // ── 队列管理 ────────────────────────────────────────

    /**
     * @brief 获取执行队列
     */
    QVector<ToolExecutionRequest> getExecutionQueue() const;

    /**
     * @brief 获取活跃执行
     */
    QVector<QString> getActiveExecutions() const;

    /**
     * @brief 获取最大并发数
     */
    int getMaxConcurrency() const;

    /**
     * @brief 设置最大并发数
     */
    void setMaxConcurrency(int maxConcurrent);

    /**
     * @brief 获取队列大小
     */
    int getQueueSize() const;

    /**
     * @brief 清空队列
     */
    void clearQueue();

    // ── 缓存管理 ────────────────────────────────────────

    /**
     * @brief 启用/禁用执行缓存
     */
    void enableCache(bool enable);

    /**
     * @brief 设置缓存过期时间
     */
    void setCacheExpiry(int seconds);

    /**
     * @brief 清空缓存
     */
    void clearCache(const QString &toolId = "");

    /**
     * @brief 获取缓存统计
     */
    QVariantMap getCacheStatistics() const;

    // ── 复合操作 ────────────────────────────────────────

    /**
     * @brief 智能执行 - 自动推荐并执行合适的工具
     */
    QString smartExecute(
        const QString &description,
        const QVariantMap &parameters = QVariantMap(),
        const QString &userId = "");

    /**
     * @brief 智能工作流 - 自动构建和执行工具链
     */
    void smartWorkflow(
        const QString &description,
        const QVariantMap &parameters,
        std::function<void(const QVector<ToolExecutionResult>&)> callback);

    /**
     * @brief 获取系统健康状态
     */
    QVariantMap getSystemHealth() const;

signals:
    // 执行事件
    void toolExecutionStarted(const QString &executionId);
    void toolExecutionCompleted(const QString &executionId, const ToolExecutionResult &result);
    void toolExecutionFailed(const QString &executionId, const QString &error);
    void toolExecutionCancelled(const QString &executionId);

    // 推荐事件
    void toolsRecommended(const QVector<ToolSchema> &tools);
    void recommendationError(const QString &error);

    // 队列事件
    void queueChanged();
    void executionStarted(const QString &executionId);

    // 系统事件
    void systemStatusChanged();
    void cacheCleared();

    // 权限事件
    void approvalRequested(const QString &requestId);
    void approvalApproved(const QString &requestId);
    void approvalRejected(const QString &requestId);

private slots:
    // 内部槽处理工具系统事件
    void onToolExecutionCompleted(const QString &executionId);
    void onToolExecutionFailed(const QString &executionId);

    // 权限系统事件处理
    void onPermissionChanged();

    // 推荐系统事件处理
    void onRecommendationCompleted();

private:
    // ── 内部帮助方法 ────────────────────────────────────────

    /**
     * @brief 处理待处理的任务
     */
    void processQueue();

    /**
     * @brief 记录执行到Memory系统
     */
    void logExecutionToMemory(const ToolExecutionResult &result);

    /**
     * @brief 记录审计日志
     */
    void logAuditEntry(
        const QString &action,
        const QString &toolId,
        const QString &userId,
        const QString &details);

    /**
     * @brief 转换为权限请求
     */
    ExecutionApprovalRequest createApprovalRequest(
        const ToolExecutionRequest &toolRequest);

    /**
     * @brief 检查工具是否需要审批
     */
    bool toolRequiresApproval(const ToolSchema &schema) const;

    // ── 成员变量 ────────────────────────────────────────

    mutable QMutex m_mutex;
    bool m_initialized = false;

    // 系统指针
    AgentController *m_controller = nullptr;
    std::shared_ptr<ClaudeToolSystem> m_toolSystem;
    std::shared_ptr<DefaultCodeMagic> m_codeMagic;
    std::shared_ptr<DefaultMemoryManager> m_memory;
    std::shared_ptr<DefaultApprovalManager> m_approval;
    std::shared_ptr<DefaultPluginManager> m_plugins;

    // 任务队列
    QQueue<std::pair<ToolExecutionRequest, std::function<void(const ToolExecutionResult&)>>> m_taskQueue;
    QVector<QString> m_activeExecutions;
    int m_maxConcurrency = 4;

    // 统计数据
    int m_totalExecutions = 0;
    int m_successfulExecutions = 0;
    int m_failedExecutions = 0;
    float m_totalExecutionTime = 0.0f;

    // 缓存设置
    bool m_cacheEnabled = true;
    int m_cacheExpirySeconds = 3600;

    // 审计日志
    QVector<QVariantMap> m_auditLog;
    static const int MAX_AUDIT_LOG_SIZE = 10000;
};
