#pragma once

#include <QString>
#include <QVector>
#include <QVariantMap>
#include <memory>

#include "tools/ClaudeToolSystem.h"
#include "tools/ToolSchemaTypes.h"
#include "code/DefaultCodeMagic.h"

/**
 * @brief CodeMagicToolBridge - 将CodeMagic系统集成到工具系统
 * 
 * 功能：
 * - 将CodeMagic的各项功能注册为标准工具
 * - 将工具执行请求映射到CodeMagic操作
 * - 缓存和结果追踪
 * 
 * 注册的工具：
 * 1. code-analyzer - 代码分析和问题检测
 * 2. code-refactor - 代码重构建议
 * 3. code-generator - 代码生成
 * 4. complexity-checker - 代码复杂度分析
 * 5. security-analyzer - 安全问题检测
 * 6. performance-analyzer - 性能问题检测
 */
class CodeMagicToolBridge {
public:
    explicit CodeMagicToolBridge(
        std::shared_ptr<ClaudeToolSystem> toolSystem,
        std::shared_ptr<DefaultCodeMagic> codeMagic);

    ~CodeMagicToolBridge() = default;

    /**
     * @brief 注册所有CodeMagic工具
     */
    bool registerAllTools();

    /**
     * @brief 注册单个工具
     */
    bool registerTool(const QString &toolId);

    // ── 工具执行方法 ────────────────────────────────────

    /**
     * @brief 代码分析工具
     * 参数: code (QString), language (QString)
     */
    ToolExecutionResult executeCodeAnalyzer(const QVariantMap &parameters);

    /**
     * @brief 代码重构工具
     * 参数: code (QString), language (QString), refactorType (QString)
     */
    ToolExecutionResult executeCodeRefactor(const QVariantMap &parameters);

    /**
     * @brief 代码生成工具
     * 参数: description (QString), language (QString), context (QVariantMap)
     */
    ToolExecutionResult executeCodeGenerator(const QVariantMap &parameters);

    /**
     * @brief 复杂度检查工具
     * 参数: code (QString), language (QString)
     */
    ToolExecutionResult executeComplexityChecker(const QVariantMap &parameters);

    /**
     * @brief 安全分析工具
     * 参数: code (QString), language (QString)
     */
    ToolExecutionResult executeSecurityAnalyzer(const QVariantMap &parameters);

    /**
     * @brief 性能分析工具
     * 参数: code (QString), language (QString)
     */
    ToolExecutionResult executePerformanceAnalyzer(const QVariantMap &parameters);

    // ── 统计和管理 ────────────────────────────────────

    /**
     * @brief 获取统计信息
     */
    QVariantMap getStatistics() const;

    /**
     * @brief 清空缓存
     */
    void clearCache();

private:
    // ── 辅助方法 ────────────────────────────────────────

    /**
     * @brief 创建工具Schema
     */
    ToolSchema createToolSchema(
        const QString &toolId,
        const QString &name,
        const QString &description,
        const QVector<ToolCapabilityDefinition> &capabilities);

    /**
     * @brief 转换CodeMagic结果为执行结果
     */
    ToolExecutionResult convertResult(
        const QString &executionId,
        const QString &toolId,
        const QVariantMap &codeMagicResult);

    /**
     * @brief 缓存键生成
     */
    QString generateCacheKey(const QString &toolId, const QVariantMap &parameters);

    /**
     * @brief 是否有缓存
     */
    bool hasCache(const QString &cacheKey);

    /**
     * @brief 获取缓存
     */
    QVariantMap getCache(const QString &cacheKey);

    /**
     * @brief 设置缓存
     */
    void setCache(const QString &cacheKey, const QVariantMap &result);

    // ── 成员变量 ────────────────────────────────────────

    std::shared_ptr<ClaudeToolSystem> m_toolSystem;
    std::shared_ptr<DefaultCodeMagic> m_codeMagic;

    // 缓存: cacheKey -> result
    QMap<QString, QVariantMap> m_cache;

    // 统计
    int m_totalExecutions = 0;
    int m_cacheHits = 0;
    int m_cacheMisses = 0;

    // 工具注册状态
    QSet<QString> m_registeredTools;
};
