# TIER 2 - Claude工具系统集成计划

## 📋 目标

将TIER 1完成的Claude工具系统与neurx现有的5个核心系统进行深度集成。

**集成目标系统**：
1. CodeMagic - 代码分析和生成
2. LLMCodeAnalyzer - 混合LLM分析
3. Memory - 长期记忆存储
4. Approval - 执行批准管理
5. Plugin - 插件系统

---

## 🏗️ 集成架构

```
┌─────────────────────────────────────────────────────┐
│          AgentController (QML-C++桥接)              │
├─────────────────────────────────────────────────────┤
│     ToolBridge (新增 - 工具系统核心集成层)           │
├────┬────────┬────────┬────────┬────────┬──────┐     │
│ CM │ Memory │Approval│ Plugin │  LLM   │ Comp │    │
│    │ Bridge │ Bridge │ Bridge │ Bridge │  Bridge│   │
└────┴────────┴────────┴────────┴────────┴──────┘     │
     ↓ 
┌─────────────────────────────────────────────────────┐
│   CodeMagic │ Memory │ Approval │ Plugin │ LLMAnalyzer│
│  (现有系统)                                          │
└─────────────────────────────────────────────────────┘
     ↓
┌─────────────────────────────────────────────────────┐
│       ClaudeToolSystem (TIER 1核心 - 7050行)        │
├─────────────────────────────────────────────────────┤
│ DefaultToolPermissionManager    (权限管理)          │
│ DefaultToolSchemaRegistry       (模式管理)          │
│ DefaultToolDiscovery            (工具发现)          │
│ DefaultToolExecutor             (执行引擎)          │
│ ClaudeToolSystem                (统一接口)          │
└─────────────────────────────────────────────────────┘
```

---

## 📝 集成任务分解

### 第1阶段：核心桥接层 (2天)

#### Task 1.1: ToolBridge基础框架 (~400行)
**文件**：`src/bridge/ToolBridge.h/cpp`

**目标**：
- 创建工具系统与AgentController的中间适配层
- 统一异步回调接口
- 任务队列管理

**关键接口**：
```cpp
class ToolBridge : public QObject {
public:
    // 初始化
    bool initialize(AgentController *controller);
    
    // 工具执行入口
    QString executeTool(const QString &toolId, 
                       const QString &capability,
                       const QVariantMap &params);
    
    // 推荐和发现
    void recommendTools(const QString &description);
    
    // 统计和报告
    QVariantMap getStatistics();
    
signals:
    void toolExecuted(const QString &executionId);
    void toolError(const QString &error);
};
```

**实现要点**：
- 获取AgentController中的所有5个系统指针
- 创建内部执行队列
- 实现异步->同步适配

---

#### Task 1.2: CodeMagic工具桥接 (~300行)
**文件**：`src/bridge/CodeMagicToolBridge.h/cpp`

**功能**：
- 注册代码分析工具到工具系统
- 工具执行→CodeMagic分析
- 结果缓存和追踪

**关键方法**：
```cpp
class CodeMagicToolBridge {
    void registerCodeAnalysisTools(ClaudeToolSystem *system);
    ToolExecutionResult analyzeCodeTool(const QVariantMap &params);
    ToolExecutionResult refactorCodeTool(const QVariantMap &params);
    ToolExecutionResult generateCodeTool(const QVariantMap &params);
    
    void onCodeAnalysisCompleted(const CodeAnalysisResult &result);
};
```

**工具注册**：
1. `code-analyzer` - 分析代码问题
2. `code-refactor` - 重构建议
3. `code-generator` - 代码生成
4. `complexity-checker` - 复杂度分析

---

#### Task 1.3: Memory工具桥接 (~250行)
**文件**：`src/bridge/MemoryToolBridge.h/cpp`

**功能**：
- 工具元数据→Memory存储
- 工具使用历史→Episodic Memory
- 工具知识库→Semantic Memory

**关键方法**：
```cpp
class MemoryToolBridge {
    void storeToolMetadata(const ToolSchema &schema);
    void storeExecutionHistory(const ToolExecutionResult &result);
    void storeToolKnowledge(const QString &toolId, const QVariantMap &knowledge);
    
    void onMemoryReady(const QString &memoryId);
    void retrieveRelatedTools(const QString &query);
};
```

**存储策略**：
- Semantic: 工具定义、功能、依赖关系
- Episodic: 执行历史、成本、性能数据
- Working: 当前活跃工具、任务上下文

---

#### Task 1.4: Approval工具桥接 (~250行)
**文件**：`src/bridge/ApprovalToolBridge.h/cpp`

**功能**：
- 高权限工具→审批流
- 敏感操作→Guardian评估
- 审计日志→完全追踪

**关键方法**：
```cpp
class ApprovalToolBridge {
    bool checkToolPermission(const QString &toolId, const QString &userId);
    void requestApproval(const ToolExecutionRequest &request);
    void recordAuditLog(const ToolExecutionResult &result);
    
    void onApprovalDecision(const QString &executionId, bool approved);
};
```

**关键工具**（需要审批）：
- 系统命令执行
- 网络访问
- 文件系统写入

---

#### Task 1.5: Plugin工具桥接 (~200行)
**文件**：`src/bridge/PluginToolBridge.h/cpp`

**功能**：
- 第三方工具→Plugin管理
- 动态工具加载
- 插件市场集成

**关键方法**：
```cpp
class PluginToolBridge {
    void discoverPluginTools();
    void registerPluginTool(const PluginInstance &plugin);
    void loadToolPlugin(const QString &pluginId);
    
    void onPluginLoaded(const QString &pluginId);
    void onPluginError(const QString &pluginId, const QString &error);
};
```

---

### 第2阶段：高级集成 (2天)

#### Task 2.1: LLMCodeAnalyzer集成 (~200行)
**文件**：`src/bridge/LLMToolBridge.h/cpp`

**功能**：
- 工具推荐→LLM分析
- 混合策略应用
- 智能缓存利用

**关键方法**：
```cpp
class LLMToolBridge {
    void recommendToolsWithLLM(const QString &description);
    void validateToolChainWithLLM(const ToolChainDefinition &chain);
    QVector<ToolSchema> getRefinedRecommendations();
};
```

---

#### Task 2.2: AgentController增强 (~300行)
**文件**：`src/bridge/AgentController.cpp`（修改现有文件）

**新增方法**：
```cpp
// 工具系统入口
Q_INVOKABLE QString executeTool(const QString &toolId, 
                                 const QString &capability,
                                 const QVariantMap &parameters);

Q_INVOKABLE void recommendTools(const QString &description);

Q_INVOKABLE QVariantMap getToolStatistics(const QString &toolId);

// QML属性
Q_PROPERTY(QVariantMap toolSystemStatus READ getToolSystemStatus NOTIFY toolSystemStatusChanged)

signals:
    void toolExecuted(const QString &executionId);
    void toolRecommended(const QVector<ToolSchema> &tools);
    void toolSystemStatusChanged();
```

**集成工作**：
- 初始化ToolBridge
- 注册所有6个集成桥接
- 暴露工具系统到QML
- 连接信号-槽

---

#### Task 2.3: 复合工具注册 (~150行)
**文件**：`src/bridge/CompositeToolBridge.h/cpp`

**功能**：
- 跨系统复合工具
- 工作流定义

**预定义的复合工具**：
1. `SmartCodeReview` - CodeMagic + LLMAnalyzer + Approval
2. `AutoRefactor` - CodeMagic分析 + 代码生成 + 单元测试
3. `IntelligentDebug` - 代码分析 + Memory历史 + 推荐修复
4. `SecureExecution` - 权限检查 + Approval + 审计日志

---

#### Task 2.4: 集成测试框架 (~200行)
**文件**：`tests/IntegrationTests.cpp`

**测试覆盖**：
- ✅ 工具执行→CodeMagic
- ✅ 工具历史→Memory存储
- ✅ 权限检查→Approval流
- ✅ 插件加载→Plugin系统
- ✅ 推荐生成→LLMAnalyzer
- ✅ 复合工具执行

---

### 第3阶段：优化和文档 (1天)

#### Task 3.1: 性能优化 (~100行)
- 工具执行缓存优化
- 异步处理优化
- 内存管理

#### Task 3.2: 用户文档 (~200行)
- 集成架构文档
- API参考
- 使用示例
- 最佳实践

#### Task 3.3: 开发者文档 (~150行)
- 桥接层扩展指南
- 新工具集成步骤
- 调试技巧

---

## 📊 工作量统计

| 任务 | 文件 | 行数 | 天数 |
|------|------|------|------|
| 1.1 ToolBridge基础 | 2 | 400 | 0.5 |
| 1.2 CodeMagic桥接 | 2 | 300 | 0.5 |
| 1.3 Memory桥接 | 2 | 250 | 0.5 |
| 1.4 Approval桥接 | 2 | 250 | 0.5 |
| 1.5 Plugin桥接 | 2 | 200 | 0.5 |
| 2.1 LLM桥接 | 2 | 200 | 0.5 |
| 2.2 AgentController | 1 | 300 | 0.5 |
| 2.3 复合工具 | 2 | 150 | 0.5 |
| 2.4 集成测试 | 1 | 200 | 0.5 |
| 3.x 优化文档 | 3 | 450 | 0.5 |
| **总计** | **21** | **2700** | **5** |

---

## 🎯 关键里程碑

- **Day 1-1.5**：核心桥接层完成 (1400行代码)
- **Day 2**：高级集成完成 (750行代码)
- **Day 3**：测试、优化、文档 (550行代码)
- **Day 5**：完全可生产就绪

---

## 💡 集成优势

✅ **完整工具链**：发现→审批→执行→记忆→分析  
✅ **智能推荐**：基于LLM和历史的工具推荐  
✅ **安全执行**：权限检查 + 审批流 + 审计日志  
✅ **学习能力**：工具使用历史存储为长期记忆  
✅ **可扩展**：新工具和插件可无缝集成  
✅ **高可用**：异步处理 + 错误恢复 + 降级方案  

---

## 🚀 快速开始

执行顺序：
```
1. src/bridge/ToolBridge.h/cpp ← 基础框架
2. src/bridge/CodeMagicToolBridge.h/cpp ← 第一个集成
3. src/bridge/MemoryToolBridge.h/cpp ← 第二个集成
4. src/bridge/ApprovalToolBridge.h/cpp ← 第三个集成
5. src/bridge/PluginToolBridge.h/cpp ← 第四个集成
6. src/bridge/LLMToolBridge.h/cpp ← 第五个集成
7. src/bridge/CompositeToolBridge.h/cpp ← 复合工具
8. src/bridge/AgentController.cpp (修改) ← 主集成
9. tests/IntegrationTests.cpp ← 验证
10. 文档更新 ← 完成
```

---

## ✨ 预期成果

完成TIER 2后，Claude工具系统将：

1. **完全集成**到neurx生态系统
2. **与所有现有系统**无缝协作
3. **提供统一QML接口**用于UI控制
4. **支持复杂工作流**和智能推荐
5. **具备完整的审计**和权限管理
6. **可用于生产环境**的企业级系统
