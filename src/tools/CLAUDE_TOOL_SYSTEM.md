# Claude Code工具系统 - neurx完整实现

## 概述

在neurx框架中实现了Claude Code的完整工具系统，包括：
- ✅ Tool Registry - 工具注册表
- ✅ Tool Discovery - 智能工具发现
- ✅ Tool Schema - 工具模式定义
- ✅ Tool Permission - 权限管理系统
- ✅ Tool Execution - 工具执行引擎

## 系统架构

```
┌─────────────────────────────────────────────────────────┐
│           ClaudeToolSystem (统一工具系统)              │
└────────────┬───────────────────────────────────────────┘
             │
    ┌────────┼────────┬──────────┬──────────┐
    │        │        │          │          │
    ▼        ▼        ▼          ▼          ▼
┌──────┐ ┌──────┐ ┌───────┐ ┌──────┐ ┌──────┐
│权限  │ │模式  │ │智能   │ │执行  │ │链接  │
│管理  │ │注册  │ │发现   │ │引擎  │ │管理  │
└──────┘ └──────┘ └───────┘ └──────┘ └──────┘
   │        │        │         │        │
   └────────┴────────┴─────────┴────────┘
           工具执行流程
```

## 核心功能模块

### 1. Tool Schema（工具模式）- ToolSchemaRegistry

#### 功能
- 定义工具的结构和能力
- 管理工具版本
- 验证工具参数
- 跟踪工具依赖

#### 核心方法
```cpp
// 注册工具模式
QString registerSchema(const ToolSchema &schema);

// 添加能力定义
void addCapability(const QString &toolId, 
                   const ToolCapabilityDefinition &capability);

// 验证工具
bool validateSchema(const ToolSchema &schema, QString &errorMessage);

// 版本管理
QString createVersion(const QString &toolId, const ToolSchema &schema);
```

#### 使用示例
```cpp
// 定义工具能力
ToolCapabilityDefinition capability;
capability.name = "analyze_code";
capability.description = "分析代码质量";
capability.inputParams = {"code", "language"};
capability.outputParams = {"issues", "score"};
capability.estimatedDuration = 2000;

// 注册工具模式
ToolSchema schema;
schema.toolId = "code_analyzer";
schema.name = "Code Analyzer";
schema.description = "AI代码分析工具";
schema.capabilities = {capability};

system->getSchemaRegistry()->registerSchema(schema);
```

### 2. Tool Permission（权限管理）- ToolPermissionManager

#### 功能
- 控制工具访问权限
- 管理用户和角色
- 执行审批流程
- 审计日志记录

#### 权限级别
```
Public      → 所有用户可用
Internal    → 认证用户可用
Private     → 特定用户可用
Restricted  → 需要特殊权限
```

#### 权限范围
```
Global      → 全局适用
Workspace   → 工作空间级
Project     → 项目级
User        → 用户级
Session     → 会话级
```

#### 核心方法
```cpp
// 设置权限
void setToolPermission(const ToolPermission &permission);

// 检查访问权限
void checkToolAccess(const QString &toolId, const QString &userId,
                    ToolPermissionCallback callback);

// 管理用户
void addAllowedUser(const QString &toolId, const QString &userId);
void addAllowedRole(const QString &toolId, const QString &role);

// 审批流程
void approveExecution(const QString &executionId, const QString &approverId);
void rejectExecution(const QString &executionId, const QString &rejectorId);
```

#### 使用示例
```cpp
// 设置工具权限
ToolPermission perm;
perm.toolId = "code_analyzer";
perm.level = PermissionLevel::Internal;
perm.scope = PermissionScope::Workspace;
perm.allowedRoles = {"developer", "reviewer"};
perm.requiresApproval = true;  // 需要审批

system->getPermissionManager()->setToolPermission(perm);

// 检查权限
system->getPermissionManager()->checkToolAccess(
    "code_analyzer", "user123",
    [](bool granted, const QString& reason) {
        if (!granted) {
            qDebug() << "Access denied:" << reason;
        }
    }
);
```

### 3. Tool Discovery（智能发现）- ToolDiscovery

#### 功能
- 搜索和浏览工具
- 智能推荐工具
- 能力匹配
- 工具评价

#### 核心方法
```cpp
// 基础搜索
void searchTools(const ToolDiscoveryQuery &query,
                ToolDiscoveryCallback callback);

// 智能推荐
void recommendTools(const QString &description,
                   ToolDiscoveryCallback callback);

// 能力查询
QVector<ToolSchema> findByCapability(const QString &capabilityName);

// 工具链查询
QVector<QVector<ToolSchema>> searchToolChains(const QString &description);
```

#### 使用示例
```cpp
// 搜索工具
ToolDiscoveryQuery query;
query.keyword = "code analyzer";
query.tags = {"analysis", "quality"};
query.category = "CodeAnalysis";

system->getToolDiscovery()->searchTools(query,
    [](const QVector<ToolSchema> &results) {
        for (const auto &tool : results) {
            qDebug() << "Found:" << tool.name;
        }
    }
);

// 推荐工具
system->getToolDiscovery()->recommendTools(
    "我需要一个能分析Python代码的工具",
    [](const QVector<ToolSchema> &results) {
        qDebug() << "Recommended tools:" << results.size();
    }
);

// 能力匹配
auto tools = system->getToolDiscovery()->findByCapability("analyze_code");
```

### 4. Tool Execution（执行引擎）- ToolExecutor

#### 功能
- 单个工具执行
- 工具链执行
- 执行缓存
- 执行监控

#### 执行状态
```
Pending     → 等待中
Running     → 执行中
Completed   → 已完成
Failed      → 失败
Cancelled   → 已取消
Timeout     → 超时
```

#### 核心方法
```cpp
// 单个工具执行
QString executeTool(const ToolExecutionRequest &request,
                   ToolExecutionCallback callback);

// 工具链执行
void executeToolChain(const ToolChainDefinition &chain,
                     const QVariantMap &globalParams,
                     ToolChainCallback callback);

// 执行管理
ExecutionStatus getExecutionStatus(const QString &executionId);
void cancelExecution(const QString &executionId);
void retryExecution(const QString &executionId);
```

#### 使用示例
```cpp
// 创建执行请求
ToolExecutionRequest request;
request.executionId = QUuid::createUuid().toString();
request.toolId = "code_analyzer";
request.capabilityName = "analyze_code";
request.parameters = {
    {"code", "def hello(): print('world')"},
    {"language", "python"}
};
request.timeoutMs = 30000;

// 执行工具
system->getToolExecutor()->executeTool(request,
    [](const ToolExecutionResult &result) {
        if (result.status == ExecutionStatus::Completed) {
            qDebug() << "Issues found:" << result.result["issues"];
        } else {
            qDebug() << "Error:" << result.error;
        }
    }
);

// 监听执行进度
connect(system->getToolExecutor(), &ToolExecutor::executionProgress,
    [](const QString &executionId, int progress) {
        qDebug() << "Progress:" << progress << "%";
    }
);
```

### 5. Tool Chain（工具链）

#### 定义工具链
```cpp
// 创建工具链步骤
ToolChainStep step1;
step1.stepId = 1;
step1.toolId = "code_analyzer";
step1.capabilityName = "analyze_code";
step1.parameters = {{"language", "python"}};

ToolChainStep step2;
step2.stepId = 2;
step2.toolId = "fix_generator";
step2.capabilityName = "generate_fixes";
step2.inputFromPrevious = {"issues"};  // 使用第一步的输出

// 定义工具链
ToolChainDefinition chain;
chain.chainId = "analyze_and_fix";
chain.name = "分析并修复代码";
chain.description = "分析代码问题并生成修复方案";
chain.steps = {step1, step2};

// 创建工具链
system->getToolExecutor()->createToolChain(chain);
```

#### 执行工具链
```cpp
// 获取工具链
auto chain = system->getToolExecutor()->getToolChain("analyze_and_fix");

// 执行链
system->getToolExecutor()->executeToolChain(chain, 
    {{"code", "def hello():\n    print('world')"}},
    [](const QVector<ToolExecutionResult> &results) {
        qDebug() << "Chain completed, steps:" << results.size();
        for (const auto &result : results) {
            qDebug() << "Step result:" << result.result;
        }
    }
);
```

## 完整集成示例

### 场景1：基本工具注册和执行

```cpp
// 初始化系统
auto system = std::make_unique<ClaudeToolSystem>();
system->initialize();

// 定义工具能力
ToolCapabilityDefinition capability;
capability.name = "analyze_python";
capability.description = "分析Python代码";
capability.inputParams = {"code", "check_types"};
capability.outputParams = {"issues", "quality_score"};

// 定义工具模式
ToolSchema schema;
schema.toolId = "python_analyzer";
schema.name = "Python代码分析器";
schema.author = "myteam";
schema.capabilities = {capability};

// 定义权限
ToolPermission permission;
permission.toolId = "python_analyzer";
permission.level = PermissionLevel::Internal;
permission.allowedRoles = {"developer"};

// 一步到位注册工具
system->registerTool(schema, permission);

// 执行工具
auto result = system->executeTool("python_analyzer", "analyze_python",
    {{"code", "x = 1"}, {"check_types", true}}, "user123");

qDebug() << "Quality:" << result.result["quality_score"];
```

### 场景2：智能工具推荐和执行

```cpp
// 根据自然语言查找工具
system->getToolDiscovery()->recommendTools(
    "我想分析Java代码的性能问题",
    [system](const QVector<ToolSchema> &recommendations) {
        if (!recommendations.isEmpty()) {
            auto bestTool = recommendations.first();
            
            // 执行推荐的工具
            ToolExecutionRequest request;
            request.toolId = bestTool.toolId;
            request.capabilityName = bestTool.capabilities.first().name;
            request.parameters = {{"code", myCode}};
            
            system->getToolExecutor()->executeTool(request);
        }
    }
);
```

### 场景3：权限检查和审批工作流

```cpp
// 检查执行权限
system->getPermissionManager()->checkExecutionPermission(
    "sensitive_tool", "user456",
    [system](bool granted, const QString &reason) {
        if (!granted) {
            qDebug() << "Permission denied:" << reason;
            // 如果需要审批
            if (reason.contains("requires approval")) {
                // 发送审批请求
                ToolExecutionRequest request;
                request.toolId = "sensitive_tool";
                request.requiresApproval = true;
                // ...
            }
        } else {
            // 有权限，继续执行
        }
    }
);

// 管理员批准执行
system->getPermissionManager()->approveExecution(
    "execution_id_123", "admin_user", "Approved for testing");
```

### 场景4：执行工具链

```cpp
// 创建分析→修复→测试的工具链
ToolChainDefinition analysisChain;
analysisChain.name = "完整代码优化流程";

// 第一步：分析
ToolChainStep analyzeStep;
analyzeStep.stepId = 1;
analyzeStep.toolId = "code_analyzer";
analyzeStep.capabilityName = "analyze";

// 第二步：生成修复
ToolChainStep fixStep;
fixStep.stepId = 2;
fixStep.toolId = "fix_generator";
fixStep.inputFromPrevious = {"issues"};

// 第三步：测试修复
ToolChainStep testStep;
testStep.stepId = 3;
testStep.toolId = "test_runner";
testStep.inputFromPrevious = {"fixed_code"};

analysisChain.steps = {analyzeStep, fixStep, testStep};

// 执行完整流程
system->getToolExecutor()->executeToolChain(analysisChain,
    {{"code", myCode}, {"language", "python"}},
    [](const QVector<ToolExecutionResult> &results) {
        qDebug() << "Analysis complete";
        qDebug() << "Step 1 - Issues:" << results[0].result;
        qDebug() << "Step 2 - Fixes:" << results[1].result;
        qDebug() << "Step 3 - Tests:" << results[2].result;
    }
);
```

## 关键特性

### 1. 智能推荐
- 基于自然语言理解推荐工具
- 推荐补充工具和工具链
- 热度和评分排序

### 2. 权限管理
- 多层级权限模型
- 审批工作流
- 完整审计日志

### 3. 执行管理
- 执行队列管理
- 并发控制
- 错误重试

### 4. 执行缓存
- 智能结果缓存
- 缓存命中率监控
- 成本优化

### 5. 监控和报告
- 实时执行监控
- 性能指标收集
- 审计报告生成

## 最佳实践

### 1. 工具注册
```cpp
// ✓ 好的做法
ToolSchema schema;
schema.toolId = "unique_id";
schema.description = "清晰的工具描述";
schema.tags = {"analysis", "quality"};
schema.minPermissionLevel = PermissionLevel::Public;

// ✗ 避免
// 不要注册没有清晰描述的工具
// 不要使用模糊的工具ID
```

### 2. 权限设置
```cpp
// ✓ 好的做法
ToolPermission perm;
perm.level = PermissionLevel::Internal;
perm.requiresApproval = true;  // 敏感操作需要批准

// ✗ 避免
// 不要给所有工具分配Public权限
// 不要忽视权限审计
```

### 3. 执行管理
```cpp
// ✓ 好的做法
request.timeoutMs = 30000;  // 合理的超时
request.priority = ExecutionPriority::Normal;
system->getToolExecutor()->executeToolAsync(request, callback);

// ✗ 避免
// 不要设置过长的超时
// 不要忽视执行错误
```

## 性能优化

### 1. 缓存策略
```cpp
// 启用执行缓存
system->getToolExecutor()->enableCache(true);
system->getToolExecutor()->setCacheExpiry(3600);  // 1小时

// 查看缓存统计
auto stats = system->getToolExecutor()->getCacheStatistics();
```

### 2. 并发执行
```cpp
// 并行执行多个工具
QVector<ToolExecutionRequest> requests;
// ... 构建请求列表

system->getToolExecutor()->setMaxConcurrency(4);
system->getToolExecutor()->executeToolsInParallel(requests, callback);
```

### 3. 优先级队列
```cpp
// 优先级执行
request.priority = ExecutionPriority::High;
system->getToolExecutor()->queueExecution(request, callback);
```

## 故障排查

### 权限被拒绝
```cpp
// 检查用户是否在允许列表中
auto allowed = system->getPermissionManager()->getAllowedUsers(toolId);

// 检查用户角色
auto roles = system->getPermissionManager()->getAllowedRoles(toolId);

// 查看拒绝原因的审计日志
auto logs = system->getPermissionManager()->getPermissionChangeLog(toolId);
```

### 执行超时
```cpp
// 增加超时时间
request.timeoutMs = 60000;  // 60秒

// 检查性能数据
auto perf = system->getToolExecutor()->getPerformanceMetrics(toolId);
```

### 执行失败重试
```cpp
// 自动重试
system->getToolExecutor()->setRetryPolicy(3, 1000, 2.0);

// 手动重试
system->getToolExecutor()->retryExecution(failedExecutionId);

// 分析失败原因
auto analysis = system->getToolExecutor()->analyzeFailure(executionId);
```

## 统计和报告

```cpp
// 系统统计
auto stats = system->getSystemStatistics();
qDebug() << "Total tools:" << stats["total_tools"];
qDebug() << "Active executions:" << stats["active_executions"];

// 工具统计
auto toolStats = system->getToolStatistics("code_analyzer");
qDebug() << "Success rate:" << toolStats["success_rate"];
qDebug() << "Avg execution time:" << toolStats["avg_duration"];

// 生成报告
auto report = system->generateSystemReport();
```

## 总结

Claude Code工具系统在neurx中的完整实现包括：

✅ **工具模式** - 定义和版本管理  
✅ **权限管理** - 多层级访问控制  
✅ **智能发现** - 推荐和匹配  
✅ **执行引擎** - 单个和链式执行  
✅ **监控报告** - 完整的观察性  

整个系统设计灵活、可扩展，支持企业级的工具生态系统。
