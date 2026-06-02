#pragma once

#include <QString>
#include <QVector>
#include <QVariantMap>
#include <QDateTime>

/**
 * @brief PlanStep - 执行计划中的单个步骤
 */
struct PlanStep {
    // 基本信息
    QString stepId;           // 步骤ID
    int stepIndex = 0;        // 步骤序号
    QString action;           // 动作描述 (分析代码/生成修复/运行测试/等)
    QString tool;             // 使用的工具
    QString toolCapability;   // 工具能力

    // 状态和结果
    enum class Status {
        Pending,      // 等待执行
        InProgress,   // 执行中
        Completed,    // 完成
        Blocked,      // 被阻塞
        Failed,       // 失败
        Cancelled     // 取消
    };
    Status status = Status::Pending;

    // 输入输出
    QVariantMap input;         // 输入参数
    QVariantMap output;        // 执行结果
    QString blockedReason;     // 阻塞原因
    QString errorMessage;      // 错误消息

    // 执行信息
    QDateTime startedAt;
    QDateTime completedAt;
    int durationMs = 0;        // 执行耗时
    float costEstimate = 0.0f; // 成本估算

    // 依赖关系
    QVector<int> dependsOn;    // 依赖的步骤索引
};

/**
 * @brief ExecutionPlan - 完整的执行计划
 */
struct ExecutionPlan {
    // 元数据
    QString planId;
    QString goal;              // 目标描述
    QString reason;            // 为什么制定这个计划
    QString strategy;          // 执行策略描述

    // 步骤管理
    QVector<PlanStep> steps;
    int currentStepIndex = 0;  // 当前执行的步骤

    // 时间戳
    QDateTime createdAt;
    QDateTime startedAt;
    QDateTime completedAt;

    // 统计
    int totalSteps() const { return steps.size(); }
    int completedSteps() const;
    float completionPercentage() const;

    // 操作方法
    PlanStep* getCurrentStep();
    const PlanStep* getCurrentStep() const;
    void updateStepStatus(int stepIndex, PlanStep::Status status);
    void recordStepOutput(int stepIndex, const QVariantMap &output);
    void blockStep(int stepIndex, const QString &reason);
    void markStepFailed(int stepIndex, const QString &error);

    // 查询
    QString getStatusSummary() const;
    QVector<QString> getBlockedReasons() const;
};

/**
 * @brief PlanHistory - 规划历史（决策树）
 */
struct PlanHistory {
    QString sessionId;
    QVector<ExecutionPlan> allPlans;    // 所有规划（包括重新规划）
    int currentPlanIndex = 0;
    QDateTime createdAt;

    // 操作
    void addPlan(const ExecutionPlan &plan);
    ExecutionPlan* getCurrentPlan();
    const ExecutionPlan* getCurrentPlan() const;

    // 查询
    int getPlanCount() const { return allPlans.size(); }
    bool hasReplanning() const { return allPlans.size() > 1; }
    QVector<QString> getReplanReasons() const;
};
