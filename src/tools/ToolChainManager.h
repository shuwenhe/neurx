#pragma once

#include <QObject>
#include <QMap>
#include <QVector>
#include <QMutex>
#include "ToolSchemaTypes.h"

/**
 * @class ToolChainManager
 * @brief 工具链管理器 - 处理工具链的生命周期、验证和可视化
 * 
 * 功能：
 * - 工具链创建、编辑、删除
 * - 工具链验证（依赖检查、版本兼容性）
 * - 工具链可视化和流程图生成
 * - 工具链复用和模板管理
 */
class ToolChainManager : public QObject {
    Q_OBJECT

public:
    explicit ToolChainManager(QObject *parent = nullptr);
    ~ToolChainManager() = default;

    // ── 工具链管理 ────────────────────────────────────

    /// 创建新工具链
    QString createChain(const ToolChainDefinition &chain,
                       std::function<void(bool, const QString&)> callback = nullptr);

    /// 获取工具链
    ToolChainDefinition getChain(const QString &chainId) const;

    /// 更新工具链
    void updateChain(const ToolChainDefinition &chain,
                    std::function<void(bool, const QString&)> callback = nullptr);

    /// 删除工具链
    void deleteChain(const QString &chainId,
                    std::function<void(bool, const QString&)> callback = nullptr);

    /// 列出所有工具链
    QVector<ToolChainDefinition> listChains() const;

    /// 按标签搜索工具链
    QVector<ToolChainDefinition> searchChains(const QString &keyword) const;

    // ── 链验证 ─────────────────────────────────────────

    /// 验证工具链
    ChainValidationResult validateChain(const ToolChainDefinition &chain) const;

    /// 验证步骤依赖
    bool validateStepDependencies(const ToolChainStep &step,
                                   const QVector<ToolExecutionResult> &previousResults,
                                   QString &errorMessage) const;

    /// 检查版本兼容性
    bool checkVersionCompatibility(const QString &toolId,
                                   const QString &version,
                                   QString &errorMessage) const;

    /// 检查缺失依赖
    QStringList getMissingDependencies(const ToolChainDefinition &chain) const;

    /// 估算链执行时间
    qint64 estimateChainDuration(const ToolChainDefinition &chain) const;

    /// 估算链执行成本
    float estimateChainCost(const ToolChainDefinition &chain) const;

    // ── 链分析 ─────────────────────────────────────────

    /// 检测链中的循环依赖
    bool hasCyclicDependencies(const ToolChainDefinition &chain,
                               QString &errorMessage) const;

    /// 获取链的关键路径
    QVector<int> getCriticalPath(const ToolChainDefinition &chain) const;

    /// 分析链的并行机会
    QVector<QVector<int>> findParallelizableSteps(const ToolChainDefinition &chain) const;

    /// 优化链的执行顺序
    ToolChainDefinition optimizeChainExecution(const ToolChainDefinition &chain) const;

    // ── 链模板 ─────────────────────────────────────────

    /// 保存为模板
    QString saveAsTemplate(const ToolChainDefinition &chain,
                          const QString &templateName,
                          std::function<void(bool, const QString&)> callback = nullptr);

    /// 从模板创建
    ToolChainDefinition createFromTemplate(const QString &templateId,
                                          const QVariantMap &parameters = QVariantMap()) const;

    /// 列出所有模板
    QVector<ToolChainDefinition> listTemplates() const;

    /// 删除模板
    void deleteTemplate(const QString &templateId,
                       std::function<void(bool, const QString&)> callback = nullptr);

    // ── 链历史 ─────────────────────────────────────────

    /// 获取链的执行历史
    QVector<QVector<ToolExecutionResult>> getChainExecutionHistory(
        const QString &chainId,
        int limit = 50) const;

    /// 获取链执行统计
    QVariantMap getChainStatistics(const QString &chainId) const;

    /// 克隆链
    QString cloneChain(const QString &sourceChainId,
                      const QString &newName,
                      std::function<void(bool, const QString&)> callback = nullptr);

    // ── 可视化和导出 ──────────────────────────────────

    /// 生成链的流程图（DOT格式）
    QString generateFlowDiagram(const ToolChainDefinition &chain) const;

    /// 生成链的JSON表示
    QByteArray exportChainAsJson(const ToolChainDefinition &chain) const;

    /// 从JSON导入链
    ToolChainDefinition importChainFromJson(const QByteArray &jsonData,
                                            QString &errorMessage) const;

    /// 生成链的执行报告
    QString generateExecutionReport(const QString &chainId,
                                    const QString &executionId) const;

signals:
    /// 链创建完成
    void chainCreated(const QString &chainId);

    /// 链更新完成
    void chainUpdated(const QString &chainId);

    /// 链删除完成
    void chainDeleted(const QString &chainId);

    /// 验证完成
    void validationCompleted(const QString &chainId, const ChainValidationResult &result);

    /// 执行完成
    void executionCompleted(const QString &chainId, const QVector<ToolExecutionResult> &results);

private:
    struct ChainMetadata {
        QString chainId;
        QDateTime createdAt;
        QDateTime lastModifiedAt;
        int executionCount = 0;
        float averageSuccessRate = 0.0f;
    };

    QMap<QString, ToolChainDefinition> m_chains;
    QMap<QString, ToolChainDefinition> m_templates;
    QMap<QString, ChainMetadata> m_metadata;
    QMap<QString, QVector<QVector<ToolExecutionResult>>> m_executionHistory;

    mutable QMutex m_mutex;

    // 辅助方法
    QString generateChainId() const;
    bool validateChainInternal(const ToolChainDefinition &chain,
                               ChainValidationResult &result) const;
    void recordChainExecution(const QString &chainId,
                            const QVector<ToolExecutionResult> &results);
};
