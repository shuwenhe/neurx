#include "PlanStructure.h"
#include <QDebug>

// ExecutionPlan 实现

int ExecutionPlan::completedSteps() const {
    int count = 0;
    for (const auto &step : steps) {
        if (step.status == PlanStep::Status::Completed) {
            count++;
        }
    }
    return count;
}

float ExecutionPlan::completionPercentage() const {
    if (steps.isEmpty()) return 0.0f;
    return (float)completedSteps() / steps.size() * 100.0f;
}

PlanStep* ExecutionPlan::getCurrentStep() {
    if (currentStepIndex >= 0 && currentStepIndex < steps.size()) {
        return &steps[currentStepIndex];
    }
    return nullptr;
}

const PlanStep* ExecutionPlan::getCurrentStep() const {
    if (currentStepIndex >= 0 && currentStepIndex < steps.size()) {
        return &steps[currentStepIndex];
    }
    return nullptr;
}

void ExecutionPlan::updateStepStatus(int stepIndex, PlanStep::Status status) {
    if (stepIndex >= 0 && stepIndex < steps.size()) {
        auto &step = steps[stepIndex];
        step.status = status;

        if (status == PlanStep::Status::InProgress && step.startedAt.isNull()) {
            step.startedAt = QDateTime::currentDateTime();
        } else if (status == PlanStep::Status::Completed || 
                   status == PlanStep::Status::Failed ||
                   status == PlanStep::Status::Cancelled) {
            step.completedAt = QDateTime::currentDateTime();
            step.durationMs = step.startedAt.msecsTo(step.completedAt);
        }

        qDebug() << "Step" << stepIndex << "status:" << static_cast<int>(status);
    }
}

void ExecutionPlan::recordStepOutput(int stepIndex, const QVariantMap &output) {
    if (stepIndex >= 0 && stepIndex < steps.size()) {
        steps[stepIndex].output = output;
        steps[stepIndex].status = PlanStep::Status::Completed;
        qDebug() << "Step" << stepIndex << "completed with output";
    }
}

void ExecutionPlan::blockStep(int stepIndex, const QString &reason) {
    if (stepIndex >= 0 && stepIndex < steps.size()) {
        steps[stepIndex].status = PlanStep::Status::Blocked;
        steps[stepIndex].blockedReason = reason;
        qWarning() << "Step" << stepIndex << "blocked:" << reason;
    }
}

void ExecutionPlan::markStepFailed(int stepIndex, const QString &error) {
    if (stepIndex >= 0 && stepIndex < steps.size()) {
        steps[stepIndex].status = PlanStep::Status::Failed;
        steps[stepIndex].errorMessage = error;
        qCritical() << "Step" << stepIndex << "failed:" << error;
    }
}

QString ExecutionPlan::getStatusSummary() const {
    int completed = completedSteps();
    int total = totalSteps();
    QString summary = QString("Plan: %1/%2 steps completed (%3%)")
        .arg(completed).arg(total).arg(static_cast<int>(completionPercentage()));

    // 添加阻塞步骤信息
    for (int i = 0; i < steps.size(); ++i) {
        if (steps[i].status == PlanStep::Status::Blocked) {
            summary += QString("\n⚠️  Step %1 blocked: %2").arg(i).arg(steps[i].blockedReason);
        } else if (steps[i].status == PlanStep::Status::Failed) {
            summary += QString("\n❌ Step %1 failed: %2").arg(i).arg(steps[i].errorMessage);
        }
    }

    return summary;
}

QVector<QString> ExecutionPlan::getBlockedReasons() const {
    QVector<QString> reasons;
    for (const auto &step : steps) {
        if (step.status == PlanStep::Status::Blocked) {
            reasons.append(QString("Step %1: %2").arg(step.stepIndex).arg(step.blockedReason));
        }
    }
    return reasons;
}

// PlanHistory 实现

void PlanHistory::addPlan(const ExecutionPlan &plan) {
    allPlans.append(plan);
    currentPlanIndex = allPlans.size() - 1;
}

ExecutionPlan* PlanHistory::getCurrentPlan() {
    if (currentPlanIndex >= 0 && currentPlanIndex < allPlans.size()) {
        return &allPlans[currentPlanIndex];
    }
    return nullptr;
}

const ExecutionPlan* PlanHistory::getCurrentPlan() const {
    if (currentPlanIndex >= 0 && currentPlanIndex < allPlans.size()) {
        return &allPlans[currentPlanIndex];
    }
    return nullptr;
}

QVector<QString> PlanHistory::getReplanReasons() const {
    QVector<QString> reasons;
    // 理想情况下，这里会存储重新规划的原因
    return reasons;
}
