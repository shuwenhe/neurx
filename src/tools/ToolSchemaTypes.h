#pragma once

#include <QString>
#include <QStringList>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>
#include "execution/ExecutionTypes.h"

/**
 * @file ToolSchemaTypes.h
 * @brief Claude Code工具系统类型定义
 * 
 * 包含：
 * - Tool Schema（工具模式）
 * - Tool Permission（工具权限）
 * - Tool Execution（工具执行）
 */

// ── 权限类型 ─────────────────────────────────────

enum class PermissionLevel {
    Public,           // 公开工具，所有用户可用
    Internal,         // 内部工具，认证用户可用
    Private,          // 私有工具，特定用户可用
    Restricted        // 受限工具，需要特殊权限
};

enum class PermissionScope {
    Global,           // 全局权限
    Workspace,        // 工作空间级权限
    Project,          // 项目级权限
    User,             // 用户级权限
    Session           // 会话级权限
};

// ── 工具权限 ─────────────────────────────────────

struct ToolPermission {
    QString permissionId;
    QString toolId;
    
    PermissionLevel level;        // 权限级别
    PermissionScope scope;        // 权限范围
    
    QStringList allowedUsers;     // 允许的用户列表
    QStringList allowedRoles;     // 允许的角色列表
    QStringList deniedUsers;      // 拒绝的用户列表
    QStringList deniedRoles;      // 拒绝的角色列表
    QStringList allowedCapabilities; // 允许的能力列表

    bool requiresApproval = false;    // 是否需要审批
    bool requiresAuthentication = false;  // 是否需要认证
    bool auditExecutions = false;     // 是否审计执行
    
    QDateTime createdAt;
    QDateTime expiresAt;           // 权限过期时间
    QString createdBy;
};

// ── 工具能力定义 ─────────────────────────────────

struct ToolCapabilityDefinition {
    QString name;                 // 能力名称
    QString description;          // 描述
    
    QStringList inputParams;      // 输入参数名称
    QStringList outputParams;     // 输出参数名称
    
    QString category;             // 能力分类
    QStringList tags;             // 标签
    
    int estimatedDuration = 1000; // 估计执行时间(ms)
    int maxRetries = 3;           // 最大重试次数
    
    bool isAsync = false;         // 是否异步
    bool isCacheable = true;      // 是否可缓存
    bool isDeterministic = true;  // 是否确定性
    
    QString documentation;        // 文档链接
};

// ── 工具模式 ─────────────────────────────────────

struct ToolSchema {
    QString toolId;
    QString name;
    QString version;
    QString description;
    
    // 工具信息
    QString author;
    QString license;
    QStringList tags;
    QString category;
    
    // 能力列表
    QList<ToolCapabilityDefinition> capabilities;
    
    // 权限
    PermissionLevel minPermissionLevel;
    QStringList requiredRoles;
    
    // 配置
    QVariantMap configuration;    // 工具配置
    QMap<QString, QVariant> environment; // 环境变量
    
    // 元数据
    QDateTime createdAt;
    QDateTime updatedAt;
    int downloadCount = 0;
    float rating = 0.0f;
    
    // 依赖
    QStringList dependencies;     // 依赖的其他工具
    QStringList requiredFiles;    // 必需的文件
    QStringList requiredPackages; // 必需的包
};

// ── 工具执行请求 ────────────────────────────────

enum class ExecutionPriority {
    Low,
    Normal,
    High,
    Critical
};

struct ToolExecutionRequest {
    QString executionId;
    QString toolId;
    QString capabilityName;       // 执行的能力名称
    
    QVariantMap parameters;       // 执行参数
    QVariantMap context;          // 执行上下文
    
    ExecutionPriority priority = ExecutionPriority::Normal;
    int timeoutMs = 30000;        // 超时时间
    
    QDateTime requestedAt;
    QString requestedBy;          // 请求者
    
    bool requiresApproval = false;
    QString approvedBy;           // 审批人
};

// ── 工具执行结果 ────────────────────────────────

using ToolExecutionStatus = ExecutionStatus;

struct ToolExecutionResult {
    QString executionId;
    QString toolId;
    
    ExecutionStatus status;
    QVariantMap result;           // 执行结果
    QString error;                // 错误信息
    
    QDateTime startedAt;
    QDateTime completedAt;
    int durationMs = 0;           // 执行耗时
    
    int retryCount = 0;           // 重试次数
    int attemptCount = 1;         // 尝试次数
    
    float costEstimate = 0.0f;    // 成本估算
    bool fromCache = false;       // 是否来自缓存
    
    QVariantMap metadata;         // 额外元数据
};

// ── 工具发现查询 ─────────────────────────────────

struct ToolDiscoveryQuery {
    QString keyword;              // 关键词搜索
    QStringList tags;             // 标签过滤
    QString category;             // 分类过滤
    
    PermissionLevel minLevel;     // 最低权限级别
    
    bool onlyActive = true;       // 只返回活跃工具
    bool sortByPopularity = false;// 按热度排序
    int limit = 50;               // 结果限制
    int offset = 0;               // 结果偏移
};

// ── 工具链定义 ───────────────────────────────────

struct ToolChainStep {
    int stepId;
    QString toolId;
    QString capabilityName;
    
    QVariantMap parameters;
    QStringList inputFromPrevious;// 从前一步的输出获取
    
    bool stopOnError = false;     // 错误时停止
    int maxRetries = 1;           // 最大重试
};

struct ToolChainDefinition {
    QString chainId;
    QString name;
    QString description;
    
    QVector<ToolChainStep> steps;
    
    QVariantMap globals;          // 全局变量
    
    QString createdBy;
    QDateTime createdAt;
};

// ── 回调类型定义 ─────────────────────────────────

using ToolExecutionCallback = std::function<void(const ToolExecutionResult&)>;
using ToolDiscoveryCallback = std::function<void(const QVector<ToolSchema>&)>;
using ToolPermissionCallback = std::function<void(bool granted, const QString& reason)>;
using ToolChainCallback = std::function<void(const QVector<ToolExecutionResult>&)>;

// ── 工具版本管理 ──────────────────────────────────

struct ToolVersionInfo {
    QString toolId;
    QString version;
    QString previousVersion;      // 前一个版本
    QString name;                 // 版本名称
    
    QDateTime releasedAt;
    QDateTime expiresAt;          // 版本过期日期
    QString releaseNotes;         // 发布说明
    
    QStringList breakingChanges;  // 重大更改
    QStringList deprecations;     // 弃用列表
    QStringList newFeatures;      // 新功能
    QStringList bugFixes;         // 错误修复
    QStringList dependencies;     // 依赖列表
    
    QString changeLog;            // 更改日志链接
    
    // 兼容性
    QStringList compatibleVersions;  // 兼容的版本
    QStringList minDependencyVersions; // 最小依赖版本
    
    bool isPrerelease = false;
    bool isDeprecated = false;
    
    QString author;
    QString checksum;             // 版本完整性校验
};

struct ToolVersionConstraint {
    QString toolId;
    QString minVersion;           // 最小版本
    QString maxVersion;           // 最大版本
    QStringList excludedVersions; // 排除版本列表
    
    bool allowPrereleases = false;
    bool autoUpgrade = true;      // 自动升级
};

// ── 缓存管理 ───────────────────────────────────────

enum class CacheInvalidationStrategy {
    TTL,                          // 按时间失效
    LRU,                          // 最少使用优先
    LFU,                          // 最少频繁使用优先
    Manual                        // 手动失效
};

struct CacheEntry {
    QString entryId;
    QString toolId;
    QString capabilityName;
    
    QVariantMap parameters;
    QVariantMap result;
    
    QDateTime createdAt;
    QDateTime expiresAt;
    int accessCount = 0;          // 访问次数
    int hitCount = 0;             // 缓存命中次数
    QDateTime lastAccessedAt;
    
    int sizeBytes = 0;            // 缓存大小
    float confidence = 1.0f;      // 缓存置信度(用于确定性操作)
};

struct CacheStatistics {
    int totalEntries = 0;
    int hitCount = 0;
    int missCount = 0;
    float hitRatio = 0.0f;        // 命中率
    
    int totalSizeBytes = 0;
    int maxSizeBytes = 0;         // 最大缓存大小
    
    float avgAccessTime = 0.0f;   // 平均访问时间
    
    QDateTime lastClearedAt;
    int itemsEvicted = 0;         // 驱逐项数
};

// ── 性能指标 ───────────────────────────────────────

struct ExecutionMetrics {
    QString executionId;
    QString toolId;
    
    qint64 startTimeMs = 0;
    qint64 endTimeMs = 0;
    qint64 durationMs = 0;
    
    // CPU 指标
    float cpuPercent = 0.0f;
    qint64 peakMemoryMB = 0;
    qint64 avgMemoryMB = 0;
    
    // 网络指标
    qint64 bytesIn = 0;
    qint64 bytesOut = 0;
    
    // 磁盘 I/O
    qint64 diskReadsMB = 0;
    qint64 diskWritesMB = 0;
    
    // 成本
    float estimatedCost = 0.0f;
    QString costBreakdown;        // 成本明细
};

struct ToolMetricsSummary {
    QString toolId;
    
    int totalExecutions = 0;
    int successCount = 0;
    int failureCount = 0;
    float successRate = 0.0f;
    
    float avgDurationMs = 0.0f;
    float minDurationMs = 0.0f;
    float maxDurationMs = 0.0f;
    float p95DurationMs = 0.0f;   // 95百分位
    float p99DurationMs = 0.0f;   // 99百分位
    
    float avgCost = 0.0f;
    float totalCost = 0.0f;
    
    // 可靠性
    float reliability = 0.0f;     // 可靠性评分
    int consecutiveFailures = 0;
    
    QDateTime lastExecutedAt;
    QDateTime statsCollectedAt;
};

// ── 工具链验证 ─────────────────────────────────────

struct ChainValidationResult {
    bool isValid = true;
    QStringList errors;           // 验证错误
    QStringList warnings;         // 验证警告
    
    // 依赖检查
    QStringList missingDependencies;
    QStringList versionConflicts;
    
    // 性能估计
    qint64 estimatedDurationMs = 0;
    float estimatedCost = 0.0f;
    
    // 兼容性
    QStringList incompatibleVersions;
    bool canExecute = true;
};

// ── 性能指标回调 ───────────────────────────────────

using ExecutionMetricsCallback = std::function<void(const ExecutionMetrics&)>;
using VersionCallback = std::function<void(bool success, const QString& message)>;
using CacheCallback = std::function<void(const QVariantMap& entry)>;
