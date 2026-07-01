# 推荐实现的 15 个 VS Code 功能 - 详细计划

**阶段**: 第 2 阶段（推荐）  
**预计时间**: 2-3 周  
**优先级**: 🔴 高价值、快速收益

---

## 📋 功能详细说明

### A. 编辑增强功能 (5 个) - 1 周

#### 1. 内联完成 (Inline Completions)
**功能说明**: 在编辑器中显示代码完成建议，支持 Tab/Enter 选择  
**VS Code 模块**: `vs/editor/contrib/inlineCompletions`  
**复杂度**: ⭐⭐⭐ (中等)  
**优先级**: 🔴 高  
**依赖**: LanguageClient, DiagnosticsService  
**实现步骤**:
1. 创建 InlineCompletionProvider 类
2. 连接 LSP completionItem/resolve
3. 创建完成显示 widget
4. 处理 Tab/Enter 键事件
5. 集成 CostToken 限制

**估计时间**: 2-3 天  
**代码行数**: ~500 行

**示例代码架构**:
```cpp
class InlineCompletionProvider : public QObject {
    Q_OBJECT
public:
    struct CompletionItem {
        QString label;
        QString insertText;
        QString documentation;
        int sortText;
    };
    
    QList<CompletionItem> getCompletions(
        const QString& filePath,
        int line, int column
    );
};
```

---

#### 2. 参数提示 (Parameter Hints)
**功能说明**: 显示函数参数提示，高亮当前参数  
**VS Code 模块**: `vs/editor/contrib/parameterHints`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🔴 高  
**依赖**: LanguageClient  
**实现步骤**:
1. 创建 ParameterHintProvider
2. 实现 SignatureHelp LSP 请求
3. 创建参数提示显示 widget
4. 实现参数高亮逻辑
5. 处理光标移动事件

**估计时间**: 1-2 天  
**代码行数**: ~400 行

---

#### 3. 代码动作 (Code Actions)
**功能说明**: 显示 Quickfix 和 Refactoring 动作  
**VS Code 模块**: `vs/editor/contrib/codeAction`  
**复杂度**: ⭐⭐⭐ (中等)  
**优先级**: 🔴 高  
**依赖**: LanguageClient, Diagnostics  
**实现步骤**:
1. 创建 CodeActionProvider
2. 实现 CodeAction LSP 请求
3. 创建动作菜单 UI
4. 处理动作执行
5. 支持快捷键触发

**估计时间**: 2 天  
**代码行数**: ~600 行

---

#### 4. 格式化文档 (Format Document)
**功能说明**: 快捷键或菜单触发整个文档格式化  
**VS Code 模块**: `vs/editor/contrib/format`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🟡 中  
**依赖**: LanguageClient  
**实现步骤**:
1. 创建 FormattingProvider
2. 实现 formatting LSP 请求
3. 应用格式化编辑
4. 显示格式化进度
5. 处理格式化错误

**估计时间**: 1 天  
**代码行数**: ~300 行

**快捷键**: Ctrl+Shift+I (Windows/Linux) / Cmd+Shift+I (macOS)

---

#### 5. 语义高亮 (Semantic Highlighting)
**功能说明**: 基于语言服务的语法高亮，支持类型、变量等区分  
**VS Code 模块**: `vs/editor/contrib/semanticTokens`  
**复杂度**: ⭐⭐⭐ (中等)  
**优先级**: 🟡 中  
**依赖**: LanguageClient, ThemeService  
**实现步骤**:
1. 创建 SemanticTokenProvider
2. 实现 semanticTokens LSP 请求
3. 定义语义令牌类型
4. 实现增量更新机制
5. 配置主题颜色映射

**估计时间**: 2-3 天  
**代码行数**: ~700 行

---

### B. 代码导航功能 (4 个) - 1 周

#### 6. 面包屑导航 (Breadcrumbs)
**功能说明**: 显示当前位置的代码结构路径  
**VS Code 模块**: `vs/editor/contrib/documentSymbols` + breadcrumbs  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🟡 中  
**依赖**: OutlineProvider, DocumentSymbols  
**实现步骤**:
1. 创建 BreadcrumbProvider
2. 实现符号路径构建
3. 创建面包屑 UI 组件
4. 处理点击事件（跳转）
5. 实现实时更新

**估计时间**: 1-2 天  
**代码行数**: ~400 行

---

#### 7. 查找所有引用 (Find All References)
**功能说明**: 查找符号的所有使用位置  
**VS Code 模块**: `vs/editor/contrib/gotoSymbol` (references)  
**复杂度**: ⭐⭐⭐ (中等)  
**优先级**: 🟡 中  
**依赖**: LanguageClient, SearchService  
**实现步骤**:
1. 创建 ReferencesProvider
2. 实现 references LSP 请求
3. 创建引用列表 UI
4. 支持过滤和分组
5. 支持快速导航

**估计时间**: 1-2 天  
**代码行数**: ~500 行

**快捷键**: Shift+F12

---

#### 8. 转到声明 (Go to Declaration)
**功能说明**: 跳转到符号声明位置  
**VS Code 模块**: `vs/editor/contrib/gotoSymbol`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🟡 中  
**依赖**: LanguageClient, GoToDefinition  
**实现步骤**:
1. 创建 DeclarationProvider
2. 实现 declaration LSP 请求
3. 处理跳转逻辑
4. 显示历史记录
5. 支持返回快捷键

**估计时间**: 1 天  
**代码行数**: ~300 行

**快捷键**: Ctrl+Shift+F12

---

#### 9. 类型定义 (Type Definition)
**功能说明**: 跳转到符号的类型定义  
**VS Code 模块**: `vs/editor/contrib/gotoSymbol`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🟢 低  
**依赖**: LanguageClient  
**实现步骤**:
1. 创建 TypeDefinitionProvider
2. 实现 typeDefinition LSP 请求
3. 集成跳转逻辑
4. 显示类型信息

**估计时间**: 1 天  
**代码行数**: ~250 行

---

### C. 工作区增强功能 (4 个) - 1 周

#### 10. 工作区符号搜索 (Workspace Symbols)
**功能说明**: 搜索整个工作区的符号（类、方法、变量等）  
**VS Code 模块**: `vs/workbench/contrib/search` + workspace symbols  
**复杂度**: ⭐⭐⭐ (中等)  
**优先级**: 🔴 高  
**依赖**: WorkspaceService, LanguageClient  
**实现步骤**:
1. 创建 WorkspaceSymbolProvider
2. 实现 workspaceSymbol LSP 请求
3. 创建符号搜索 UI（集成到快速访问）
4. 支持模糊匹配
5. 实现缓存机制

**估计时间**: 2 天  
**代码行数**: ~600 行

**快捷键**: Ctrl+T

**示例**:
```cpp
controller->searchWorkspaceSymbols("MyClass")
// 返回: [{file: "Main.cpp", line: 10, symbol: "class MyClass"}]
```

---

#### 11. 文件监视 (File Watcher)
**功能说明**: 监视工作区文件变化，自动重新加载  
**VS Code 模块**: `vs/workbench/contrib/files`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🔴 高  
**依赖**: FileService  
**实现步骤**:
1. 实现深度文件系统监视
2. 检测添加/删除/修改
3. 更新文件树
4. 处理编辑器打开文件刷新
5. 配置忽略模式

**估计时间**: 1-2 天  
**代码行数**: ~400 行

---

#### 12. 路径自动完成 (Path Completion)
**功能说明**: 在字符串中显示文件路径完成建议  
**VS Code 模块**: `vs/editor/contrib/suggest`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🟡 中  
**依赖**: FileService, WorkspaceService  
**实现步骤**:
1. 创建 PathCompletionProvider
2. 检测字符串上下文
3. 列举工作区文件
4. 过滤相关路径
5. 返回完成项

**估计时间**: 1-2 天  
**代码行数**: ~350 行

---

#### 13. 工作区文件搜索优化
**功能说明**: 增强文件搜索性能和功能  
**VS Code 模块**: `vs/workbench/services/search`  
**复杂度**: ⭐⭐⭐ (中等)  
**优先级**: 🟡 中  
**依赖**: SearchService, FileService  
**实现步骤**:
1. 实现并行搜索
2. 添加正则表达式过滤
3. 支持包含/排除模式
4. 实现搜索缓存
5. 显示搜索统计

**估计时间**: 1-2 天  
**代码行数**: ~450 行

---

### D. 文本编辑增强功能 (2 个) - 2-3 天

#### 14. 链接编辑 (Linked Editing)
**功能说明**: 同时编辑匹配的标记（如 HTML 标签）  
**VS Code 模块**: `vs/editor/contrib/linkedEditing`  
**复杂度**: ⭐⭐ (简单-中等)  
**优先级**: 🟡 中  
**依赖**: LanguageClient  
**实现步骤**:
1. 创建 LinkedEditingProvider
2. 实现 linkedEditing LSP 请求
3. 创建多光标绑定
4. 同步编辑逻辑
5. 处理冲突和验证

**估计时间**: 1-2 天  
**代码行数**: ~400 行

---

#### 15. 删除行尾空格 (Trim Trailing Whitespace)
**功能说明**: 自动删除行尾的空格字符  
**VS Code 模块**: `vs/editor/contrib/insertFinalNewLine`  
**复杂度**: ⭐ (简单)  
**优先级**: 🟢 低  
**依赖**: 无  
**实现步骤**:
1. 创建 TrimTrailingWhitespaceProvider
2. 实现正则表达式替换
3. 支持保存时自动触发
4. 支持手动命令
5. 配置选项

**估计时间**: 1 天  
**代码行数**: ~200 行

---

## 📊 实现时间表

### 周 1: 编辑功能 (5 个)
| 天 | 任务 | 功能 | 状态 |
|----|------|------|------|
| Day 1-2 | 内联完成 | Inline Completions | ⏳ |
| Day 2-3 | 参数提示 | Parameter Hints | ⏳ |
| Day 3 | 代码动作 | Code Actions | ⏳ |
| Day 4 | 格式化 | Format Document | ⏳ |
| Day 4-5 | 语义高亮 | Semantic Highlighting | ⏳ |

### 周 2: 导航和工作区 (6-7 个)
| 天 | 任务 | 功能 | 状态 |
|----|------|------|------|
| Day 1 | 面包屑 | Breadcrumbs | ⏳ |
| Day 2 | 查找引用 | Find References | ⏳ |
| Day 2-3 | 转到声明 | Go to Declaration | ⏳ |
| Day 3 | 类型定义 | Type Definition | ⏳ |
| Day 3-4 | 工作区符号 | Workspace Symbols | ⏳ |
| Day 4-5 | 文件监视 | File Watcher | ⏳ |
| Day 5 | 路径完成 | Path Completion | ⏳ |

### 周 3: 优化和收尾 (3-4 个)
| 天 | 任务 | 功能 | 状态 |
|----|------|------|------|
| Day 1-2 | 搜索优化 | Search Optimization | ⏳ |
| Day 2-3 | 链接编辑 | Linked Editing | ⏳ |
| Day 4 | 删除空格 | Trim Whitespace | ⏳ |
| Day 4-5 | 测试和集成 | Testing & Integration | ⏳ |

---

## 🔧 技术架构

### 通用实现模式

```cpp
// 所有功能遵循的模式

class FeatureProvider : public QObject {
    Q_OBJECT
public:
    struct Result {
        QString id;
        QVariant data;
        QString error;
    };
    
    virtual Result execute(const FeatureContext& ctx) = 0;
    
signals:
    void resultReady(const Result& result);
    
protected:
    LanguageClient* m_lsp{nullptr};
    FileService* m_fs{nullptr};
};
```

### LSP 集成模式

```cpp
// 所有 LSP 特性使用统一的请求模式

class LSPFeature {
    // 1. 准备请求
    QJsonObject prepareRequest(const EditorContext& ctx);
    
    // 2. 发送请求
    void sendLSPRequest(const QString& method, const QJsonObject& params);
    
    // 3. 处理响应
    void onLSPResponse(const QJsonObject& response);
    
    // 4. 应用结果
    void applyResult(const QVariant& result);
};
```

---

## 🧪 测试计划

### 单元测试
- 每个功能独立测试 (15 个测试模块)
- 关键路径覆盖率 > 80%

### 集成测试
- 跨功能交互测试
- LSP 服务器集成测试
- 文件系统操作测试

### 性能测试
- 大型文件处理
- 工作区符号搜索性能
- 实时更新延迟

---

## 📝 后续步骤

1. **确认优先级** - 与团队确认实现顺序
2. **分配资源** - 分配开发人员和时间
3. **创建分支** - 为每个功能创建开发分支
4. **增量集成** - 每天集成一个功能
5. **每周审查** - 评估进度和质量

---

## 💡 关键建议

1. **并行开发** - 后端和 UI 可以并行开发
2. **模块化测试** - 功能完成后立即测试
3. **文档同步** - 同步更新 API 文档
4. **社区反馈** - 发布 beta 版本收集反馈
5. **性能监控** - 持续监控新功能性能

---

**预期结果**: 实现这 15 个功能后，neurx-code 的代码编辑体验将与 VS Code 90% 相似，成为一个高效的开发环境。
