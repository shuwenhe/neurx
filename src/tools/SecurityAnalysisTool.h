#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>
#include <QJsonObject>

/**
 * @class SecurityAnalysisTool
 * @brief 代码安全分析工具
 * 
 * 功能：
 * - SQL 注入检测
 * - XSS 漏洞检测
 * - 不安全的密码处理
 * - 命令注入风险
 * - 硬编码密钥检测
 * - 不安全的反序列化
 * - 弱密码算法检测
 * 
 * 使用示例：
 * {
 *   "tool": "security_analysis",
 *   "action": "scan_file",
 *   "file_path": "/path/to/code.js",
 *   "language": "javascript"
 * }
 */
class SecurityAnalysisTool : public BaseTool {
public:
    explicit SecurityAnalysisTool(const QString &workspaceRoot, QObject *parent = nullptr);
    ~SecurityAnalysisTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    QString m_workspaceRoot;
    
    // ── 安全扫描 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 扫描单个文件的安全问题
     */
    QJsonArray scanFile(const QString &filePath, const QString &language = QString());
    
    /**
     * @brief 扫描目录中的所有文件
     */
    QJsonObject scanDirectory(const QString &directory, const QString &language = QString());
    
    /**
     * @brief 扫描特定安全模式
     */
    QJsonArray scanForPattern(const QString &content, const QString &language);
    
    /**
     * @brief 检测 SQL 注入风险
     */
    bool hasSqlInjectionRisk(const QString &content);
    
    /**
     * @brief 检测 XSS 风险
     */
    bool hasXssRisk(const QString &content);
    
    /**
     * @brief 检测硬编码密钥
     */
    bool hasHardcodedSecrets(const QString &content);
    
    /**
     * @brief 检测命令注入
     */
    bool hasCommandInjection(const QString &content);
    
    /**
     * @brief 生成安全报告
     */
    QString generateSecurityReport(const QJsonArray &issues);
};
