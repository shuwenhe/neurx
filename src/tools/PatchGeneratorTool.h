#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>
#include <QJsonObject>

/**
 * @class PatchGeneratorTool
 * @brief 生成统一格式的 diff 补丁
 * 
 * 功能：
 * - 生成两个文件之间的 unified diff
 * - 生成目录差异的补丁包
 * - 支持 context lines 配置
 * - 生成可应用的补丁文件
 * 
 * 使用示例：
 * {
 *   "tool": "patch_generator",
 *   "action": "generate_diff",
 *   "original_file": "/path/to/original.cpp",
 *   "modified_file": "/path/to/modified.cpp",
 *   "output_patch": "/path/to/output.patch",
 *   "context_lines": 3
 * }
 */
class PatchGeneratorTool : public BaseTool {
public:
    explicit PatchGeneratorTool(QObject *parent = nullptr);
    ~PatchGeneratorTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    // ── 补丁生成 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 生成两个文件之间的 unified diff
     */
    QString generateUnifiedDiff(const QString &originalFile, const QString &modifiedFile, int contextLines = 3);
    
    /**
     * @brief 生成两个字符串之间的 diff
     */
    QString generateDiffFromStrings(const QString &original, const QString &modified, int contextLines = 3);
    
    /**
     * @brief 生成目录差异补丁
     */
    QString generateDirectoryPatch(const QString &originalDir, const QString &modifiedDir, int contextLines = 3);
    
    /**
     * @brief 计算行差异（使用简单算法）
     */
    QStringList computeLineDifferences(const QStringList &originalLines, const QStringList &modifiedLines);
    
    /**
     * @brief 验证补丁是否有效
     */
    bool validatePatch(const QString &patchContent);
};
