#ifndef RISKASSESSOR_H
#define RISKASSESSOR_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>

/**
 * @class RiskAssessor
 * @brief 风险评估引擎 - 分析工具操作的安全风险
 * 
 * 功能：
 * - 文件系统操作风险 (读/写/删除权限)
 * - 网络操作风险 (协议、主机、端口)
 * - 系统命令风险 (shell权限、系统调用)
 * - 数据库操作风险 (连接、修改权限)
 * - 秘密信息泄露风险
 * - 资源耗尽风险 (CPU/内存/磁盘)
 * 
 * 风险等级: CRITICAL(5) -> HIGH(4) -> MEDIUM(3) -> LOW(2) -> MINIMAL(1)
 */

class RiskAssessor : public QObject
{
    Q_OBJECT

public:
    enum RiskLevel {
        MINIMAL = 1,
        LOW = 2,
        MEDIUM = 3,
        HIGH = 4,
        CRITICAL = 5
    };

    enum RiskCategory {
        FileSystem,     // 文件系统操作
        Network,        // 网络操作
        SystemCommand,  // 系统命令
        Database,       // 数据库操作
        Secrets,        // 秘密信息
        Resources       // 资源耗尽
    };

    struct RiskFinding {
        RiskCategory category;
        RiskLevel level;
        QString riskType;
        QString description;
        QString affectedResource;
        QStringList recommendations;
        QJsonObject metadata;
    };

    explicit RiskAssessor(QObject *parent = nullptr);
    ~RiskAssessor();

    // 工具操作的风险评估
    QList<RiskFinding> assessToolOperation(
        const QString &toolName,
        const QString &action,
        const QJsonObject &parameters);

    // 获取最高风险等级
    RiskLevel getMaxRiskLevel(const QList<RiskFinding> &findings);

    // 生成风险报告 (JSON格式)
    QJsonObject generateRiskReport(const QList<RiskFinding> &findings);

    // 检查是否需要批准
    bool requiresApproval(RiskLevel level, const QString &approvalPolicy);

    // 获取风险等级的人类可读名称
    static QString riskLevelName(RiskLevel level);
    static QString riskCategoryName(RiskCategory category);

private:
    // 具体的风险评估方法
    QList<RiskFinding> assessFileSystemRisk(
        const QString &action,
        const QJsonObject &params);

    QList<RiskFinding> assessNetworkRisk(
        const QString &action,
        const QJsonObject &params);

    QList<RiskFinding> assessSystemCommandRisk(
        const QString &action,
        const QJsonObject &params);

    QList<RiskFinding> assessDatabaseRisk(
        const QString &action,
        const QJsonObject &params);

    QList<RiskFinding> assessSecretsRisk(
        const QString &action,
        const QJsonObject &params);

    QList<RiskFinding> assessResourcesRisk(
        const QString &action,
        const QJsonObject &params);

    // 辅助方法
    bool isPathTraversalAttempt(const QString &path);
    bool containsSensitivePatterns(const QString &content);
    int estimateResourceUsage(const QJsonObject &params);

    // 风险模式匹配
    QMap<QString, RiskLevel> m_dangerousFilePatterns;
    QMap<QString, RiskLevel> m_dangerousNetworkPatterns;
    QMap<QString, RiskLevel> m_dangerousCommandPatterns;
    QMap<QString, RiskLevel> m_secretPatterns;

    void initializePatterns();
};

#endif // RISKASSESSOR_H
