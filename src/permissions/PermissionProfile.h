#pragma once

#include <QString>
#include <QMap>
#include <QSet>
#include <QStringList>
#include <QJsonObject>

/**
 * @brief OperationApprovalRule - 操作批准规则
 */
enum class OperationType {
    FileWrite,                  // 文件写入
    FileDelete,                 // 文件删除
    FileModify,                 // 文件修改
    CommandExecution,           // 命令执行
    ShellCommand,               // Shell命令
    NetworkAccess,              // 网络访问
    EnvironmentModification,    // 环境变量修改
    PluginLoad,                 // 插件加载
    Unknown
};

enum class RiskLevel {
    Low,                        // 低风险 - 自动通过
    Medium,                     // 中风险 - 提示确认
    High                        // 高风险 - 必须批准
};

struct OperationApprovalRule {
    OperationType type;
    RiskLevel riskLevel = RiskLevel::Medium;
    bool requiresApproval = false;

    QStringList whitelist;      // 允许列表 (路径/命令)
    QStringList blacklist;      // 禁止列表

    // 冷却时间（秒）- 相同操作在时间内可自动通过
    int autoApproveCooldown = 0;

    // 最后批准时间和操作
    QString lastApprovedOperation;
    qint64 lastApprovedTime = 0;

    // 转换为/从JSON
    QJsonObject toJson() const;
    static OperationApprovalRule fromJson(const QJsonObject &json);
};

/**
 * @brief PermissionProfile - 权限配置文件
 */
class PermissionProfile {
public:
    explicit PermissionProfile(const QString &name = "default");

    // 配置管理
    static PermissionProfile loadFromFile(const QString &filePath);
    bool saveToFile(const QString &filePath) const;

    // 规则管理
    void setRule(OperationType type, const OperationApprovalRule &rule);
    OperationApprovalRule getRule(OperationType type) const;
    bool hasRule(OperationType type) const;

    // 权限检查
    bool requiresApproval(OperationType type, const QString &target) const;
    bool isAllowed(OperationType type, const QString &target) const;
    bool isBlacklisted(OperationType type, const QString &target) const;
    bool isWhitelisted(OperationType type, const QString &target) const;

    // 临时信任
    void trustOperation(const QString &operationKey, int durationSeconds);
    bool isTrusted(const QString &operationKey) const;
    void clearTrusted(const QString &operationKey);

    // 自动批准阈值
    void setAutoApproveThreshold(RiskLevel threshold);
    RiskLevel getAutoApproveThreshold() const;

    // 获取所有规则
    QMap<OperationType, OperationApprovalRule> getAllRules() const;

    // 转换为JSON
    QJsonObject toJson() const;
    static PermissionProfile fromJson(const QJsonObject &json);

private:
    QString m_name;
    QMap<OperationType, OperationApprovalRule> m_rules;
    RiskLevel m_autoApproveThreshold = RiskLevel::Low;

    // 临时信任：key -> 过期时间戳(ms)
    QMap<QString, qint64> m_trustedOperations;

    OperationType parseOperationType(const QString &typeStr) const;
    QString operationTypeToString(OperationType type) const;
};
