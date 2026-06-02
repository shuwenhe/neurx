#pragma once

#include <QString>
#include <QVector>
#include <memory>
#include "tools/ToolSchemaTypes.h"

/**
 * @brief CompositeToolBridge - 定义和管理复合工具
 * 
 * 复合工具是多个基础工具的组合，提供高级功能。
 * 例如: 代码审查 = CodeAnalyzer + LLMAnalyzer + Approval
 */
class CompositeToolBridge {
public:
    /**
     * @brief 创建所有预定义的复合工具
     */
    static QVector<ToolChainDefinition> createCompositeTools();

    /**
     * @brief SmartCodeReview工具链
     * 组件：code-analyzer + llm-analyzer + approval
     * 流程：
     *   1. 使用code-analyzer分析代码
     *   2. 使用llm-analyzer进行LLM分析
     *   3. 合并结果并请求批准
     */
    static ToolChainDefinition createSmartCodeReviewChain();

    /**
     * @brief AutoRefactor工具链
     * 组件：code-analyzer + code-refactor + security-analyzer
     * 流程：
     *   1. 分析代码问题
     *   2. 生成重构建议
     *   3. 检查安全性
     */
    static ToolChainDefinition createAutoRefactorChain();

    /**
     * @brief IntelligentDebug工具链
     * 组件：code-analyzer + memory-search + performance-analyzer
     * 流程：
     *   1. 分析代码
     *   2. 从Memory中搜索相似问题
     *   3. 进行性能分析
     */
    static ToolChainDefinition createIntelligentDebugChain();

    /**
     * @brief SecureExecution工具链
     * 组件：security-analyzer + approval + (执行工具)
     * 流程：
     *   1. 安全检查
     *   2. 请求批准
     *   3. 执行工具
     */
    static ToolChainDefinition createSecureExecutionChain();
};
