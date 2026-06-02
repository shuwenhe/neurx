#pragma once

#include <QString>
#include <QStringList>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

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
    
    QVector<QString> inputParams; // 输入参数名称
    QVector<QString> outputParams;// 输出参数名称
    
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
    QVector<ToolCapabilityDefinition> capabilities;
    
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

enum class ExecutionStatus {
    Pending,           // 等待中
    Running,           // 执行中
    Completed,         // 已完成
    Failed,            // 失败
    Cancelled,         // 已取消
    Timeout,           // 超时
    Approved,          // 已批准
    Rejected           // 已拒绝
};

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
