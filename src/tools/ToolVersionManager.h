#pragma once

#include <QObject>
#include <QMap>
#include <QVector>
#include <QMutex>
#include "ToolSchemaTypes.h"

/**
 * @class ToolVersionManager
 * @brief 工具版本管理器 - 处理版本控制、兼容性检查和升级
 * 
 * 功能：
 * - 版本注册和管理
 * - 版本兼容性检查
 * - 自动升级和降级
 * - 版本依赖解析
 * - 变更日志和发布说明
 * - API向后兼容性分析
 */
class ToolVersionManager : public QObject {
    Q_OBJECT

public:
    explicit ToolVersionManager(QObject *parent = nullptr);
    ~ToolVersionManager() = default;

    // ── 版本注册 ────────────────────────────────────────

    /// 注册工具版本
    void registerToolVersion(const ToolVersionInfo &versionInfo,
                            std::function<void(bool, const QString&)> callback = nullptr);

    /// 获取工具版本信息
    ToolVersionInfo getVersionInfo(const QString &toolId,
                                   const QString &version) const;

    /// 获取工具的所有版本
    QVector<ToolVersionInfo> getAllVersions(const QString &toolId) const;

    /// 获取最新版本
    ToolVersionInfo getLatestVersion(const QString &toolId) const;

    /// 获取特定tag的版本
    ToolVersionInfo getVersionByTag(const QString &toolId,
                                    const QString &tag) const;

    /// 列出活跃版本（非弃用）
    QVector<ToolVersionInfo> getActiveVersions(const QString &toolId) const;

    /// 列出支持的版本（在支持窗口内）
    QVector<ToolVersionInfo> getSupportedVersions(const QString &toolId) const;

    // ── 版本兼容性 ────────────────────────────────────

    /// 检查版本兼容性
    bool isCompatible(const QString &toolId,
                     const QString &sourceVersion,
                     const QString &targetVersion,
                     QString &incompatibilities) const;

    /// 检查依赖版本兼容性
    bool checkDependencyVersions(const QString &toolId,
                                const QString &version,
                                const QMap<QString, QString> &dependencies,
                                QString &errorMessage) const;

    /// 获取兼容版本列表
    QVector<QString> getCompatibleVersions(const QString &toolId,
                                           const QString &version) const;

    /// 获取最小支持版本
    QString getMinimumSupportedVersion(const QString &toolId) const;

    /// 获取最大支持版本
    QString getMaximumSupportedVersion(const QString &toolId) const;

    /// 检查是否为预发布版本
    bool isPrerelease(const QString &toolId, const QString &version) const;

    /// 检查是否为已弃用版本
    bool isDeprecated(const QString &toolId, const QString &version) const;

    // ── 版本升级/降级 ──────────────────────────────────

    /// 检查是否可升级
    bool canUpgrade(const QString &toolId,
                   const QString &currentVersion,
                   QString &targetVersion,
                   QString &reason) const;

    /// 检查是否可降级
    bool canDowngrade(const QString &toolId,
                     const QString &currentVersion,
                     QString &targetVersion,
                     QString &reason) const;

    /// 获取升级路径
    QVector<QString> getUpgradePath(const QString &toolId,
                                    const QString &fromVersion,
                                    const QString &toVersion) const;

    /// 获取推荐升级版本
    QString getRecommendedUpgradeVersion(const QString &toolId,
                                        const QString &currentVersion) const;

    /// 设置自动升级策略
    void setAutoUpgradePolicy(const QString &toolId,
                             const QString &policy);  // "none", "patch", "minor", "major"

    /// 获取自动升级策略
    QString getAutoUpgradePolicy(const QString &toolId) const;

    // ── 版本依赖 ────────────────────────────────────────

    /// 解析版本约束
    QString resolveVersionConstraint(const QString &toolId,
                                     const ToolVersionConstraint &constraint,
                                     QString &errorMessage) const;

    /// 检查版本约束是否满足
    bool satisfiesConstraint(const QString &toolId,
                            const QString &version,
                            const ToolVersionConstraint &constraint) const;

    /// 计算版本依赖图
    QVariantMap computeVersionDependencyGraph(const QString &toolId,
                                             const QString &version) const;

    /// 检测版本冲突
    bool detectVersionConflicts(const QMap<QString, QString> &toolVersions,
                               QStringList &conflictDescriptions) const;

    /// 解决版本冲突
    bool resolveVersionConflicts(QMap<QString, QString> &toolVersions,
                                QString &errorMessage) const;

    /// 获取推荐的版本组合
    QMap<QString, QString> getRecommendedVersionSet(int scenarioId = 0) const;

    // ── 变更管理 ────────────────────────────────────────

    /// 获取版本之间的变更
    QVariantMap getVersionChanges(const QString &toolId,
                                  const QString &fromVersion,
                                  const QString &toVersion) const;

    /// 检测breaking changes
    QStringList getBreakingChanges(const QString &toolId,
                                   const QString &fromVersion,
                                   const QString &toVersion) const;

    /// 获取弃用列表
    QStringList getDeprecations(const QString &toolId,
                               const QString &version) const;

    /// 检查API兼容性
    bool isAPICompatible(const QString &toolId,
                        const QString &sourceVersion,
                        const QString &targetVersion,
                        QString &incompatibilities) const;

    /// 生成迁移指南
    QString generateMigrationGuide(const QString &toolId,
                                   const QString &fromVersion,
                                   const QString &toVersion) const;

    /// 检查参数兼容性
    bool areParametersCompatible(const QString &toolId,
                                const QString &sourceVersion,
                                const QString &targetVersion,
                                const QStringList &parameterNames,
                                QString &errorMessage) const;

    // ── 版本历史 ────────────────────────────────────────

    /// 获取版本发布历史
    QVector<ToolVersionInfo> getVersionHistory(const QString &toolId,
                                               int limit = 100) const;

    /// 生成版本时间线
    QString generateVersionTimeline(const QString &toolId) const;

    /// 获取版本发布频率
    QVariantMap getVersionReleaseMetrics(const QString &toolId) const;

    /// 追踪版本采用情况
    QVariantMap trackVersionAdoption(const QString &toolId) const;

    // ── 版本检查和验证 ──────────────────────────────────

    /// 验证版本号格式（遵循语义版本控制）
    bool isValidVersion(const QString &version) const;

    /// 比较版本号
    int compareVersions(const QString &version1,
                       const QString &version2) const;  // -1: v1 < v2, 0: equal, 1: v1 > v2

    /// 验证版本信息完整性
    bool validateVersionInfo(const ToolVersionInfo &versionInfo,
                            QString &errorMessage) const;

    /// 生成版本校验和
    QString generateVersionChecksum(const QString &toolId,
                                    const QString &version) const;

    /// 验证版本校验和
    bool verifyVersionChecksum(const QString &toolId,
                              const QString &version,
                              const QString &checksum) const;

    // ── 报告生成 ────────────────────────────────────────

    /// 生成版本兼容性报告
    QString generateCompatibilityReport(const QString &toolId) const;

    /// 生成版本发布说明
    QString generateReleaseNotes(const QString &toolId,
                               const QString &version) const;

    /// 导出版本信息
    QByteArray exportVersionsAsJSON(const QString &toolId) const;

    /// 导入版本信息
    bool importVersionsFromJSON(const QByteArray &jsonData,
                               QString &errorMessage);

    /// 生成版本支持矩阵
    QString generateSupportMatrix(const QString &toolId) const;

    // ── 维护操作 ────────────────────────────────────────

    /// 标记版本为弃用
    void deprecateVersion(const QString &toolId,
                         const QString &version,
                         const QString &reason,
                         std::function<void(bool)> callback = nullptr);

    /// 标记版本为已删除
    void removeVersion(const QString &toolId,
                      const QString &version,
                      std::function<void(bool, const QString&)> callback = nullptr);

    /// 设置版本支持结束日期
    void setEndOfSupportDate(const QString &toolId,
                            const QString &version,
                            const QDateTime &date);

    /// 获取版本支持状态
    QString getVersionSupportStatus(const QString &toolId,
                                   const QString &version) const;

    /// 清理过期版本
    int cleanupExpiredVersions(int daysToKeep = 365);

signals:
    /// 版本注册完成
    void versionRegistered(const QString &toolId, const QString &version);

    /// 版本弃用
    void versionDeprecated(const QString &toolId, const QString &version);

    /// 版本删除
    void versionRemoved(const QString &toolId, const QString &version);

    /// 兼容性检查完成
    void compatibilityCheckCompleted(const QString &toolId,
                                     bool isCompatible);

    /// 发现不兼容问题
    void incompatibilityDetected(const QString &toolId,
                                const QString &issue);

    /// 版本冲突检测
    void versionConflictDetected(const QStringList &conflicts);

    /// 升级路径已更新
    void upgradePathUpdated(const QString &toolId);

private:
    struct VersionRecord {
        ToolVersionInfo info;
        QDateTime registeredAt;
        bool isActive = true;
        QVector<QString> dependentVersions;
    };

    struct UpgradePolicy {
        QString toolId;
        QString policy;  // "none", "patch", "minor", "major"
        QDateTime lastUpdated;
    };

    QMap<QString, QVector<VersionRecord>> m_versions;  // toolId -> versions
    QMap<QString, UpgradePolicy> m_upgradePolicies;
    QMap<QString, QString> m_versionConstraints;

    mutable QMutex m_mutex;

    // 辅助方法
    bool isVersionInRange(const QString &version,
                         const QString &minVersion,
                         const QString &maxVersion) const;
    QVector<int> parseVersionNumbers(const QString &version) const;
    QString normalizeVersion(const QString &version) const;
};
