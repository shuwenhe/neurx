#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QHash>
#include <QRegularExpression>
#include <QJsonObject>

/**
 * @class SecurityScanner
 * @brief 安全模式扫描器 - 检测代码中的危险模式
 * 
 * 实现三层安全防护（参考 claude-code security-guidance 插件）：
 * - Layer 1: Pattern Warnings（模式警告 - 基于正则）
 * - Layer 2: LLM Diff Review（LLM 差异审查 - 待实现）
 * - Layer 3: Agentic Commit Review（Agent 提交审查 - 待实现）
 * 
 * 监控 25+ 种危险模式：
 * - 不安全反序列化（yaml.load, pickle.load）
 * - 代码注入（eval, exec, os.system）
 * - XSS 风险（innerHTML, dangerouslySetInnerHTML）
 * - SQL 注入
 * - 命令注入
 * - 硬编码密钥
 * 等
 */
class SecurityScanner : public QObject {
    Q_OBJECT

public:
    /**
     * @brief 安全问题严重程度
     */
    enum class Severity {
        Info,        ///< 信息提示
        Warning,     ///< 警告
        Critical     ///< 严重
    };
    Q_ENUM(Severity)

    /**
     * @brief 安全问题
     */
    struct SecurityIssue {
        QString filePath;        ///< 文件路径
        int lineNumber;          ///< 行号（1-based）
        QString pattern;         ///< 匹配的模式名称
        Severity severity;       ///< 严重程度
        QString message;         ///< 问题描述
        QString cweId;           ///< CWE 编号（可选）
        QString recommendation;  ///< 修复建议
        QString matchedText;     ///< 匹配的代码片段

        SecurityIssue() : lineNumber(0), severity(Severity::Warning) {}
    };

    explicit SecurityScanner(QObject *parent = nullptr);
    ~SecurityScanner();

    // ── Layer 1: 模式扫描 ───────────────────────────────────────────────────
    
    /**
     * @brief 扫描文件
     */
    QList<SecurityIssue> scanFile(const QString& filePath);
    
    /**
     * @brief 扫描文本内容
     */
    QList<SecurityIssue> scanContent(const QString& content, const QString& filePath = QString());
    
    /**
     * @brief 扫描 diff
     */
    QList<SecurityIssue> scanDiff(const QString& diff);

    // ── 模式管理 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 启用/禁用特定模式
     */
    void setPatternEnabled(const QString& patternName, bool enabled);
    
    /**
     * @brief 获取所有模式
     */
    QHash<QString, QRegularExpression> allPatterns() const { return m_patterns; }
    
    /**
     * @brief 获取模式的元数据
     */
    QJsonObject getPatternMetadata(const QString& patternName) const;

    // ── 配置 ────────────────────────────────────────────────────────────────
    
    /**
     * @brief 设置严重程度阈值（只报告 >= threshold 的问题）
     */
    void setSeverityThreshold(Severity threshold);
    
    /**
     * @brief 设置是否启用层 1（模式扫描）
     */
    void setLayer1Enabled(bool enabled) { m_layer1Enabled = enabled; }

signals:
    /**
     * @brief 发现安全问题
     */
    void issueFound(const SecurityIssue& issue);

private:
    /**
     * @brief 模式元数据
     */
    struct PatternMetadata {
        QString name;
        QString description;
        Severity severity;
        QString cweId;
        QString recommendation;
        QStringList tags;
        bool enabled;

        PatternMetadata() : severity(Severity::Warning), enabled(true) {}
        PatternMetadata(const QString &name,
                        const QString &description,
                        Severity severity,
                        const QString &cweId,
                        const QString &recommendation,
                        const QStringList &tags,
                        bool enabled)
            : name(name)
            , description(description)
            , severity(severity)
            , cweId(cweId)
            , recommendation(recommendation)
            , tags(tags)
            , enabled(enabled)
        {}
    };

    // ── 初始化 ──────────────────────────────────────────────────────────────
    void initDangerousPatterns();
    void initPythonPatterns();
    void initJavaScriptPatterns();
    void initShellPatterns();
    void initSecretPatterns();
    void initSQLPatterns();
    void initXSSPatterns();

    // ── 扫描辅助 ────────────────────────────────────────────────────────────
    QList<SecurityIssue> scanLines(const QStringList& lines, const QString& filePath);
    Severity getPatternSeverity(const QString& patternName) const;
    QString getPatternMessage(const QString& patternName) const;
    QString getPatternCWE(const QString& patternName) const;
    QString getPatternRecommendation(const QString& patternName) const;

    // ── 数据成员 ────────────────────────────────────────────────────────────
    QHash<QString, QRegularExpression> m_patterns;      ///< 危险模式正则库
    QHash<QString, PatternMetadata> m_metadata;         ///< 模式元数据
    Severity m_severityThreshold;                       ///< 严重程度阈值
    bool m_layer1Enabled;                               ///< Layer 1 是否启用
};

// ── 辅助函数 ────────────────────────────────────────────────────────────────

/**
 * @brief 将 Severity 转换为字符串
 */
QString severityToString(SecurityScanner::Severity severity);

/**
 * @brief 将 Severity 转换为颜色（用于 UI）
 */
QString severityToColor(SecurityScanner::Severity severity);
