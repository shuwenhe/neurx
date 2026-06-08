#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>
#include <QJsonObject>

/**
 * @class CompilerIntegrationTool
 * @brief 编译器和类型检查集成工具
 * 
 * 功能：
 * - TypeScript tsc 类型检查
 * - Python 语法验证
 * - 构建命令执行
 * - 编译器错误解析
 * - 诊断结果聚合
 * 
 * 使用示例：
 * {
 *   "tool": "compiler_integration",
 *   "action": "typecheck_typescript",
 *   "tsconfig_path": "/path/to/tsconfig.json"
 * }
 * 
 * {
 *   "tool": "compiler_integration",
 *   "action": "validate_python",
 *   "python_file": "/path/to/script.py"
 * }
 */
class CompilerIntegrationTool : public BaseTool {
public:
    explicit CompilerIntegrationTool(const QString &workspaceRoot, QObject *parent = nullptr);
    ~CompilerIntegrationTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    QString m_workspaceRoot;
    
    // ── 编译器操作 ────────────────────────────────────────────────────────────
    
    /**
     * @brief TypeScript 类型检查
     */
    QJsonObject typecheckTypeScript(const QString &tsconfigPath);
    
    /**
     * @brief Python 语法验证
     */
    QJsonObject validatePython(const QString &pythonFile);
    
    /**
     * @brief 执行构建命令
     */
    QJsonObject runBuildCommand(const QString &command, const QString &workingDir = QString());
    
    /**
     * @brief 运行 eslint
     */
    QJsonObject runEslint(const QString &filePath);
    
    /**
     * @brief 运行 prettier（代码格式化检查）
     */
    QJsonObject checkPrettier(const QString &filePath);
    
    /**
     * @brief 解析编译器错误输出
     */
    QJsonArray parseCompilerErrors(const QString &output, const QString &compiler);
    
    /**
     * @brief 检查编译器是否可用
     */
    bool isCompilerAvailable(const QString &command);
};
