#include "CompositeToolBridge.h"
#include <QUuid>
#include <QDateTime>

QVector<ToolChainDefinition> CompositeToolBridge::createCompositeTools() {
    QVector<ToolChainDefinition> chains;

    chains.append(createSmartCodeReviewChain());
    chains.append(createAutoRefactorChain());
    chains.append(createIntelligentDebugChain());
    chains.append(createSecureExecutionChain());

    return chains;
}

ToolChainDefinition CompositeToolBridge::createSmartCodeReviewChain() {
    ToolChainDefinition chain;
    chain.chainId = QUuid::createUuid().toString();
    chain.name = "SmartCodeReview";
    chain.description = "Comprehensive code review combining static analysis, LLM analysis, and approval workflow";
    chain.createdAt = QDateTime::currentDateTime();

    // Step 1: 代码分析
    ToolChainStep step1;
    step1.stepId = 1;
    step1.toolId = "code-analyzer";
    step1.capabilityName = "analyze";
    step1.parameters = {{"code", ""}};
    chain.steps.append(step1);

    // Step 2: LLM分析
    ToolChainStep step2;
    step2.stepId = 2;
    step2.toolId = "llm-analyzer";
    step2.capabilityName = "analyze";
    step2.inputFromPrevious = {"code"};
    chain.steps.append(step2);

    // Step 3: 审批
    ToolChainStep step3;
    step3.stepId = 3;
    step3.toolId = "approval";
    step3.capabilityName = "request";
    chain.steps.append(step3);

    return chain;
}

ToolChainDefinition CompositeToolBridge::createAutoRefactorChain() {
    ToolChainDefinition chain;
    chain.chainId = QUuid::createUuid().toString();
    chain.name = "AutoRefactor";
    chain.description = "Automated code refactoring with security and quality checks";
    chain.createdAt = QDateTime::currentDateTime();

    // Step 1: 分析
    ToolChainStep step1;
    step1.stepId = 1;
    step1.toolId = "code-analyzer";
    step1.capabilityName = "analyze";
    step1.parameters = {{"code", ""}};
    chain.steps.append(step1);

    // Step 2: 重构
    ToolChainStep step2;
    step2.stepId = 2;
    step2.toolId = "code-refactor";
    step2.capabilityName = "refactor";
    step2.inputFromPrevious = {"issues"};
    chain.steps.append(step2);

    // Step 3: 安全检查
    ToolChainStep step3;
    step3.stepId = 3;
    step3.toolId = "security-analyzer";
    step3.capabilityName = "analyze";
    step3.inputFromPrevious = {"refactoredCode"};
    chain.steps.append(step3);

    return chain;
}

ToolChainDefinition CompositeToolBridge::createIntelligentDebugChain() {
    ToolChainDefinition chain;
    chain.chainId = QUuid::createUuid().toString();
    chain.name = "IntelligentDebug";
    chain.description = "Intelligent debugging combining analysis, historical knowledge, and performance profiling";
    chain.createdAt = QDateTime::currentDateTime();

    // Step 1: 代码分析
    ToolChainStep step1;
    step1.stepId = 1;
    step1.toolId = "code-analyzer";
    step1.capabilityName = "analyze";
    step1.parameters = {{"code", ""}};
    chain.steps.append(step1);

    // Step 2: Memory搜索
    ToolChainStep step2;
    step2.stepId = 2;
    step2.toolId = "memory-search";
    step2.capabilityName = "search";
    step2.inputFromPrevious = {"issues"};
    chain.steps.append(step2);

    // Step 3: 性能分析
    ToolChainStep step3;
    step3.stepId = 3;
    step3.toolId = "performance-analyzer";
    step3.capabilityName = "analyze";
    step3.inputFromPrevious = {"code"};
    chain.steps.append(step3);

    return chain;
}

ToolChainDefinition CompositeToolBridge::createSecureExecutionChain() {
    ToolChainDefinition chain;
    chain.chainId = QUuid::createUuid().toString();
    chain.name = "SecureExecution";
    chain.description = "Secure tool execution with security checks and approval workflow";
    chain.createdAt = QDateTime::currentDateTime();

    // Step 1: 安全检查
    ToolChainStep step1;
    step1.stepId = 1;
    step1.toolId = "security-analyzer";
    step1.capabilityName = "analyze";
    chain.steps.append(step1);

    // Step 2: 审批
    ToolChainStep step2;
    step2.stepId = 2;
    step2.toolId = "approval";
    step2.capabilityName = "request";
    chain.steps.append(step2);

    return chain;
}
