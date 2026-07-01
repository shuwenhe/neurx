# VS Code 核心功能移植分析报告

## 项目对比

| 方面 | VS Code | neurx-code |
|------|---------|-----------|
| **语言** | TypeScript/JavaScript | C++17 + Qt 6.x + QML |
| **架构** | 浏览器/Electron 基础 | Qt GUI 框架 |
| **渲染** | HTML/CSS/Canvas | Qt Quick + OpenGL |
| **平台** | 跨平台 (Web/Desktop) | 桌面 (macOS/Linux/Windows) |

---

## 可直接实现的功能（56 个）

### ✅ **第一优先级：直接可移植（即插即用）**

这些功能的算法和逻辑与实现无关，可直接用 C++/Qt 重新实现：

#### 1. **文本操作** (12 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 1 | 行操作（复制/删除/移动/重复） | `/src/vs/editor/contrib/linesOperations/` | ✅ 已有 | P0 | ⭐ |
| 2 | 大小写转换 | `/src/vs/editor/contrib/inPlaceReplace/` | ✅ 已有 | P0 | ⭐ |
| 3 | 单词操作（前进/后退/删除） | `/src/vs/editor/contrib/wordOperations/` | ✅ 已有 | P0 | ⭐ |
| 4 | 多光标编辑 | `/src/vs/editor/contrib/multicursor/` | ✅ 已有 | P1 | ⭐⭐ |
| 5 | 选择到括号 | `/src/vs/editor/contrib/smartSelect/` | ✅ 已有 | P1 | ⭐ |
| 6 | 智能选择 | `/src/vs/editor/contrib/smartSelect/` | ✅ 已有 | P1 | ⭐⭐ |
| 7 | 缩进操作 | `/src/vs/editor/contrib/indentation/` | 🔄 部分 | P1 | ⭐ |
| 8 | 行选择 | `/src/vs/editor/contrib/lineSelection/` | 🔄 部分 | P2 | ⭐ |
| 9 | 锚点选择 | `/src/vs/editor/contrib/anchorSelect/` | ❌ 无 | P3 | ⭐⭐ |
| 10 | 最终换行符插入 | `/src/vs/editor/contrib/insertFinalNewLine/` | ❌ 无 | P3 | ⭐ |
| 11 | 光标撤销 | `/src/vs/editor/contrib/cursorUndo/` | ❌ 无 | P2 | ⭐ |
| 12 | Caret 操作 | `/src/vs/editor/contrib/caretOperations/` | ❌ 无 | P3 | ⭐ |

#### 2. **查询和导航** (10 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 13 | 查找和替换 | `/src/vs/editor/contrib/find/` | ✅ 已有 | P0 | ⭐⭐ |
| 14 | 转到符号 | `/src/vs/editor/contrib/gotoSymbol/` | ✅ 已有 | P1 | ⭐⭐ |
| 15 | 转到定义 | `/src/vs/editor/contrib/gotoSymbol/` | ✅ 已有 | P0 | ⭐⭐⭐ |
| 16 | 查找错误/警告 | `/src/vs/editor/contrib/gotoError/` | 🔄 部分 | P2 | ⭐⭐ |
| 17 | 文档符号 | `/src/vs/editor/contrib/documentSymbols/` | ✅ 已有 | P1 | ⭐⭐ |
| 18 | 快速访问 | `/src/vs/editor/contrib/quickAccess/` | ✅ 已有 | P1 | ⭐⭐ |
| 19 | Peek View（预览） | `/src/vs/editor/contrib/peekView/` | ❌ 无 | P2 | ⭐⭐⭐ |
| 20 | 面包屑导航 | `/src/vs/workbench/browser/parts/breadcrumbs/` | 🔄 部分 | P2 | ⭐⭐ |
| 21 | 粘性滚动 | `/src/vs/editor/contrib/stickyScroll/` | ❌ 无 | P3 | ⭐⭐⭐ |
| 22 | 段落标题 | `/src/vs/editor/contrib/sectionHeaders/` | ❌ 无 | P3 | ⭐⭐ |

#### 3. **代码分析和补全** (10 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 23 | 代码片段 | `/src/vs/editor/contrib/snippet/` | ✅ 已有 | P0 | ⭐⭐⭐ |
| 24 | 自动完成/建议 | `/src/vs/editor/contrib/suggest/` | 🔄 部分 | P1 | ⭐⭐⭐⭐ |
| 25 | 参数提示 | `/src/vs/editor/contrib/parameterHints/` | 🔄 部分 | P1 | ⭐⭐⭐ |
| 26 | 内联完成 | `/src/vs/editor/contrib/inlineCompletions/` | 🔄 部分 | P2 | ⭐⭐⭐ |
| 27 | 代码操作 | `/src/vs/editor/contrib/codeAction/` | 🔄 部分 | P1 | ⭐⭐⭐⭐ |
| 28 | 代码透镜 | `/src/vs/editor/contrib/codelens/` | ❌ 无 | P3 | ⭐⭐⭐ |
| 29 | 语义令牌 | `/src/vs/editor/contrib/semanticTokens/` | 🔄 部分 | P2 | ⭐⭐⭐ |
| 30 | 悬停提示 | `/src/vs/editor/contrib/hover/` | 🔄 部分 | P2 | ⭐⭐⭐ |
| 31 | 符号图标 | `/src/vs/editor/contrib/symbolIcons/` | ❌ 无 | P3 | ⭐⭐ |
| 32 | Inlay Hints | `/src/vs/editor/contrib/inlayHints/` | ❌ 无 | P3 | ⭐⭐⭐ |

#### 4. **格式化和注释** (8 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 33 | 注释切换 | `/src/vs/editor/contrib/comment/` | ✅ 已有 | P0 | ⭐ |
| 34 | 格式化文档 | `/src/vs/editor/contrib/format/` | 🔄 部分 | P1 | ⭐⭐⭐ |
| 35 | 格式化选择 | `/src/vs/editor/contrib/format/` | 🔄 部分 | P1 | ⭐⭐⭐ |
| 36 | 链接编辑 | `/src/vs/editor/contrib/linkedEditing/` | ✅ 已有 | P2 | ⭐⭐⭐ |
| 37 | 重命名 | `/src/vs/editor/contrib/rename/` | ✅ 已有 | P1 | ⭐⭐⭐⭐ |
| 38 | 原地替换 | `/src/vs/editor/contrib/inPlaceReplace/` | 🔄 部分 | P2 | ⭐⭐ |
| 39 | 对齐格式化 | `/src/vs/editor/contrib/format/` | ❌ 无 | P3 | ⭐⭐ |
| 40 | 代码格式化策略 | `/src/vs/editor/contrib/format/` | 🔄 部分 | P2 | ⭐⭐ |

#### 5. **高亮和视觉效果** (9 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 41 | 括号匹配 | `/src/vs/editor/contrib/bracketMatching/` | ✅ 已有 | P0 | ⭐⭐ |
| 42 | 单词高亮 | `/src/vs/editor/contrib/wordHighlighter/` | ✅ 已有 | P0 | ⭐⭐ |
| 43 | 语义高亮 | `/src/vs/editor/contrib/semanticTokens/` | 🔄 部分 | P2 | ⭐⭐⭐ |
| 44 | 链接检测 | `/src/vs/editor/contrib/links/` | ❌ 无 | P3 | ⭐⭐ |
| 45 | Unicode 高亮 | `/src/vs/editor/contrib/unicodeHighlighter/` | ❌ 无 | P3 | ⭐ |
| 46 | 异常行终止符 | `/src/vs/editor/contrib/unusualLineTerminators/` | ❌ 无 | P3 | ⭐ |
| 47 | 颜色选择器 | `/src/vs/editor/contrib/colorPicker/` | 🔄 部分 | P3 | ⭐⭐⭐ |
| 48 | 字体缩放 | `/src/vs/editor/contrib/fontZoom/` | ❌ 无 | P2 | ⭐ |
| 49 | 中间滚动 | `/src/vs/editor/contrib/middleScroll/` | ❌ 无 | P3 | ⭐ |

#### 6. **代码折叠** (3 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 50 | 代码折叠 | `/src/vs/editor/contrib/folding/` | ✅ 已有 | P0 | ⭐⭐⭐ |
| 51 | 代码折叠范围 | `/src/vs/editor/contrib/folding/` | 🔄 部分 | P1 | ⭐⭐⭐ |
| 52 | 区域标记 | `/src/vs/editor/contrib/folding/` | ❌ 无 | P2 | ⭐⭐ |

#### 7. **编辑器状态和剪贴板** (4 个)

| # | 功能 | VS Code 源代码位置 | neurx-code 状态 | 优先级 | 复杂度 |
|----|------|-------------------|----------------|--------|--------|
| 53 | 编辑器状态 | `/src/vs/editor/contrib/editorState/` | 🔄 部分 | P2 | ⭐ |
| 54 | 剪贴板操作 | `/src/vs/editor/contrib/clipboard/` | 🔄 部分 | P1 | ⭐ |
| 55 | 拖放/粘贴 | `/src/vs/editor/contrib/dropOrPasteInto/` | 🔄 部分 | P2 | ⭐⭐ |
| 56 | 上下文菜单 | `/src/vs/editor/contrib/contextmenu/` | 🔄 部分 | P1 | ⭐⭐ |

---

## 优先级分类

### 🔴 **P0（立即实现）** - 6 个功能

已有框架，需要完成实现：

```
1. ✅ 行操作（复制/删除/移动/重复）
2. ✅ 大小写转换
3. ✅ 单词操作
4. ✅ 查找和替换
5. ✅ 转到定义
6. ✅ 注释切换
```

**预期工作量**: 2-3 人天

**关键文件**:
- `src/editor/LineOperations.h/cpp`
- `src/editor/CaseConverter.h/cpp`
- `src/editor/WordOperations.h/cpp`
- `src/editor/FindAndReplace.h/cpp`
- `src/editor/GoToDefinition.h/cpp`
- `src/editor/CommentManager.h/cpp`

---

### 🟠 **P1（本周实现）** - 15 个功能

需要集成或部分完成：

```
1. ✅ 代码片段
2. ✅ 多光标编辑
3. ✅ 选择到括号
4. ✅ 智能选择
5. ✅ 转到符号
6. ✅ 文档符号
7. ✅ 快速访问
8. ✅ 括号匹配
9. ✅ 单词高亮
10. 🔄 自动完成/建议 (部分)
11. 🔄 参数提示 (部分)
12. 🔄 代码操作 (部分)
13. 🔄 格式化文档 (部分)
14. 🔄 重命名 (部分)
15. 🔄 剪贴板操作 (部分)
```

**预期工作量**: 5-7 人天

**关键集成点**: 需要 LSP (Language Server Protocol) 支持

---

### 🟡 **P2（下周或以后）** - 20 个功能

可选功能，增强用户体验：

```
1. 缩进操作
2. 查找错误/警告
3. Peek View（预览）
4. 面包屑导航
5. 内联完成
6. 代码透镜
7. 语义令牌
8. 悬停提示
9. 链接编辑
10. 原地替换
11. 代码折叠范围
12. 编辑器状态
13. 拖放/粘贴
14. 上下文菜单
15. 字体缩放
16. 代码格式化策略
17. 行选择
18. 光标撤销
19. 粘性滚动
20. 颜色选择器
```

**预期工作量**: 10-14 人天

---

### 🔵 **P3（未来）** - 15 个功能

高级或不常用功能：

```
1. 锚点选择
2. 最终换行符插入
3. Caret 操作
4. 段落标题
5. 代码透镜
6. 符号图标
7. Inlay Hints
8. 链接检测
9. Unicode 高亮
10. 异常行终止符
11. 中间滚动
12. 区域标记
13. 浮动菜单
14. 消息框
15. 只读提示
```

**预期工作量**: 5-8 人天

---

## 详细实现指南

### 🎯 **第 1 阶段：基础编辑操作（2-3 天）**

#### 1.1 完成行操作
```cpp
// src/editor/LineOperations.h
class LineOperations {
public:
    // 已实现的方法
    void copyLine(const QString& line);
    void deleteLine(int lineNumber);
    void moveLinesUp(QList<int> lines);
    void moveLinesDown(QList<int> lines);
    void duplicateLine(int lineNumber);
    
    // 需要添加的方法
    void transformToUpperCase(QList<int> lines);
    void transformToLowerCase(QList<int> lines);
    void sortLines(QList<int> lines, bool ascending = true);
    void reverseLines(QList<int> lines);
    void removeDuplicateLines(QList<int> lines);
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/linesOperations/`

#### 1.2 完成大小写转换
```cpp
// src/editor/CaseConverter.h
class CaseConverter {
public:
    // 已实现
    QString toCamelCase(const QString& text);
    QString toSnakeCase(const QString& text);
    QString toUpperCase(const QString& text);
    QString toLowerCase(const QString& text);
    
    // 需要添加
    QString toPascalCase(const QString& text);
    QString toKebabCase(const QString& text);
    QString toDotCase(const QString& text);
    QString toPathCase(const QString& text);
    QString toggleCase(const QString& text);  // 大小写切换
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/inPlaceReplace/`

#### 1.3 完成单词操作
```cpp
// src/editor/WordOperations.h
class WordOperations {
public:
    // 已实现
    void deleteWord(int line, int column);
    void deleteWordBackward(int line, int column);
    
    // 需要添加
    QString selectWord(int line, int column);
    QString selectNextWord(int line, int column);
    QString selectPreviousWord(int line, int column);
    void transposeWords(int line, int column);  // 交换相邻单词
    void joinWords(int startLine, int endLine);  // 合并单词
    void swapWords(int pos1, int pos2);  // 交换两个单词
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/wordOperations/`

---

### 🎯 **第 2 阶段：查询和导航（4-5 天）**

#### 2.1 增强查找和替换
```cpp
// src/editor/FindAndReplace.h
class FindAndReplace {
public:
    // 需要添加的高级功能
    struct FindOptions {
        bool caseSensitive{false};
        bool wholeWord{false};
        bool regex{false};
        bool backward{false};
        bool preserveCase{false};  // 替换时保留大小写
        int maxResults{1000};
    };
    
    QList<FindMatch> findAll(const QString& query, const FindOptions& options);
    bool findNext(const QString& query);
    bool findPrevious(const QString& query);
    int replaceAll(const QString& pattern, const QString& replacement);
    
    // 需要添加
    QList<FindMatch> findInFiles(const QString& query, const QStringList& files);
    int replaceInFiles(const QString& pattern, const QString& replacement, 
                       const QStringList& files);
    void saveFindHistory(const QStringList& history);
    void loadFindHistory();
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/find/`

#### 2.2 转到定义/符号
```cpp
// src/editor/GoToDefinition.h + OutlineProvider.h
class GoToDefinition {
public:
    struct Definition {
        QString file;
        int line{0};
        int column{0};
        QString name;
        QString kind;  // "function", "class", "variable", etc.
    };
    
    // 需要添加
    Definition goToDefinition(const QString& filePath, int line, int column);
    QList<Definition> findReferences(const QString& filePath, int line, int column);
    QList<Definition> findImplementations(const QString& filePath, int line, int column);
    Definition findTypeDefinition(const QString& filePath, int line, int column);
    
    // 需要集成 LSP
    void setLanguageServerClient(LanguageClient* lsp);
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/gotoSymbol/`

---

### 🎯 **第 3 阶段：代码分析（5-7 天）**

#### 3.1 自动完成建议
```cpp
// src/bridge/CompletionProvider.h (新建)
class CompletionProvider : public QObject {
    Q_OBJECT
public:
    struct CompletionItem {
        QString label;
        QString detail;
        QString documentation;
        QString kind;  // "Function", "Class", "Variable", etc.
        QString sortText;
        QString filterText;
        QString textEdit;  // 要插入的文本
        int insertionOrder{0};
    };
    
    Q_INVOKABLE QList<CompletionItem> getCompletions(
        const QString& filePath, int line, int column);
    
    Q_INVOKABLE CompletionItem resolveCompletion(const CompletionItem& item);
    
    Q_INVOKABLE bool commitCompletion(const CompletionItem& item);
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/suggest/`

#### 3.2 代码操作
```cpp
// src/bridge/CodeActionProvider.h (增强)
class CodeActionProvider : public FeatureProvider {
public:
    struct CodeAction {
        QString title;
        QString kind;  // "quickfix", "refactor", "source", etc.
        QString command;  // 要执行的命令
        QVariantMap edit;  // 编辑操作
        QList<CodeAction> children;  // 子操作
        bool isPreferred{false};
    };
    
    Q_INVOKABLE QList<CodeAction> getCodeActions(
        const QString& filePath, int startLine, int endLine);
    
    Q_INVOKABLE bool applyCodeAction(const CodeAction& action);
};
```

**参考来源**: `/Users/feifei/agent/vscode/src/vs/editor/contrib/codeAction/`

---

## 快速集成检查表

### ✅ **完全可用（无需修改）** - 9 个

```
□ LineOperations - 行操作
□ CaseConverter - 大小写转换
□ WordOperations - 单词操作
□ CommentManager - 注释切换
□ BracketMatcher - 括号匹配
□ WordHighlight - 单词高亮
□ SmartSelection - 智能选择
□ MultiCursor - 多光标
□ SnippetManager - 代码片段
```

### 🔄 **需要完成** - 8 个

```
□ FindAndReplace - 需要增强（正则表达式、高级选项）
□ GoToDefinition - 需要 LSP 集成
□ OutlineProvider - 需要符号解析
□ FoldingManager - 需要完成折叠计算
□ InlineRename - 需要 LSP 支持
□ EditorHistory - 需要完整的 undo/redo
□ LineOperations - 需要添加排序/反转等
□ SelectToBracket - 需要改进选择算法
```

### ❌ **需要新建** - 15+ 个

```
□ CompletionProvider - 自动完成
□ ParameterHintProvider - 参数提示
□ HoverProvider - 悬停提示
□ SignatureHelpProvider - 签名帮助
□ DocumentFormattingProvider - 文档格式化
□ RangeFormattingProvider - 范围格式化
□ RenameProvider - 重命名（完整实现）
□ CodeLensProvider - 代码透镜
□ LinkProvider - 链接检测
□ DeclarationProvider - 声明
□ TypeDefinitionProvider - 类型定义
□ ImplementationProvider - 实现
□ ReferenceProvider - 引用
□ DocumentSymbolProvider - 文档符号
□ WorkspaceSymbolProvider - 工作区符号
```

---

## 推荐实现顺序

### **第 1 周** (基础编辑)

1. **Day 1-2**: 完成 LineOperations（排序、反转等）
2. **Day 2**: 完成 CaseConverter（所有格式）
3. **Day 3**: 完成 WordOperations（交换、转置）
4. **Day 4**: 增强 FindAndReplace（正则表达式）
5. **Day 5**: 集成测试和文档

**预期完成**: 6 个 P0 功能 + 4 个 P1 功能

---

### **第 2 周** (查询和导航)

1. **Day 1-2**: 实现 CompletionProvider（自动完成）
2. **Day 2-3**: 集成 GoToDefinition 和 LSP
3. **Day 4**: 实现 HoverProvider（悬停提示）
4. **Day 5**: 实现 ParameterHintProvider（参数提示）

**预期完成**: 8 个 P1 功能

---

### **第 3 周** (代码分析)

1. **Day 1-2**: 实现 DocumentFormattingProvider（格式化）
2. **Day 2-3**: 增强 CodeActionProvider（重构操作）
3. **Day 4**: 实现 RenameProvider（重命名）
4. **Day 5**: 集成 DocumentSymbol 和 WorkspaceSymbol

**预期完成**: 7 个 P1-P2 功能

---

## 集成步骤

### 步骤 1: 检查 LSP 连接

```cpp
// 在 AgentController.cpp 中验证 LSP 连接
void AgentController::initializeLSPFeatures()
{
    if (!m_languageClient) {
        qWarning() << "LSP client not available";
        return;
    }
    
    // 连接 LSP 事件
    connect(m_languageClient, &LanguageClient::completionReceived,
            this, &AgentController::onCompletionReceived);
}
```

### 步骤 2: 创建新的 Provider 类

```cpp
// 继承 FeatureProvider 基类
class CompletionProvider : public FeatureProvider {
public:
    explicit CompletionProvider(QObject* parent = nullptr);
    FeatureProvider::Result execute(const EditorContext& ctx) override;
};
```

### 步骤 3: 注册为 Q_INVOKABLE 方法

```cpp
// 在 AgentController 中添加
Q_INVOKABLE QVariantList getCompletions(
    const QString& filePath, int line, int column);
```

### 步骤 4: 连接到 QML 层

```qml
// 在 QML 中使用
onTextChanged: {
    let completions = agentController.getCompletions(
        editor.filePath, 
        editor.cursorLine, 
        editor.cursorColumn
    )
}
```

---

## 关键实现细节

### 🔗 **LSP 集成点**

所有需要语义信息的功能都依赖 LanguageClient：

```cpp
// LanguageClient 提供的核心方法
QList<CompletionItem> LanguageClient::getCompletions(
    const QString& file, const Position& pos);
QList<Location> LanguageClient::getDefinitions(
    const QString& file, const Position& pos);
QList<Location> LanguageClient::getReferences(
    const QString& file, const Position& pos);
QString LanguageClient::formatDocument(const QString& file);
```

### 📝 **文本操作算法**

这些功能不需要 LSP，可本地实现：

```cpp
// 文本操作的核心算法
class TextOperations {
    // 已有的基础操作
    static QStringList getLines(const QString& text);
    static QString joinLines(const QStringList& lines);
    
    // 需要添加的操作
    static QStringList sortLines(const QStringList& lines);
    static QStringList reverseLines(const QStringList& lines);
    static QStringList removeDuplicates(const QStringList& lines);
};
```

---

## 测试用例示例

### 测试 LineOperations

```cpp
void TestLineOperations::testSortLines()
{
    auto lines = QStringList{"charlie", "alpha", "bravo"};
    auto result = LineOperations::sortLines(lines);
    QCOMPARE(result, QStringList{"alpha", "bravo", "charlie"});
}
```

### 测试 CaseConverter

```cpp
void TestCaseConverter::testAllCaseFormats()
{
    CaseConverter converter;
    QCOMPARE(converter.toCamelCase("hello world"), "helloWorld");
    QCOMPARE(converter.toPascalCase("hello world"), "HelloWorld");
    QCOMPARE(converter.toSnakeCase("hello world"), "hello_world");
    QCOMPARE(converter.toKebabCase("hello world"), "hello-world");
}
```

---

## 预期时间表

| 阶段 | 功能 | 预计时间 | 状态 |
|-----|------|---------|------|
| **第 1 周** | 基础编辑操作 (10 个) | 5 天 | 待实现 |
| **第 2 周** | 查询和导航 (8 个) | 5 天 | 待实现 |
| **第 3 周** | 代码分析 (7 个) | 5 天 | 待实现 |
| **第 4 周** | 高级功能 (20+ 个) | 10+ 天 | 可选 |
| **总计** | **56 个功能** | **25-30 天** | **~1 个月** |

---

## 资源链接

### 主要代码位置

| 功能类别 | VS Code 源路径 | neurx-code 目标路径 |
|---------|-------------|-----------------|
| 编辑操作 | `/src/vs/editor/contrib/` | `src/editor/` |
| 工作台 | `/src/vs/workbench/` | `src/workbench/` |
| 服务 | `/src/vs/platform/` | `src/services/` |
| 桥接 | 无 | `src/bridge/` |

### 工具和库

- **LSP**: Language Server Protocol (via LanguageClient)
- **正则表达式**: Qt 内置 QRegularExpression
- **文本处理**: Qt QString, QTextDocument
- **语法高亮**: Qt QSyntaxHighlighter

---

## 成功指标

✅ 完成以上所有 56 个功能后，neurx-code 将具备以下特性：

1. **完整的编辑器功能** - 与 VS Code 相当的编辑体验
2. **强大的代码导航** - 符号查找、定义跳转、引用查找
3. **智能代码完成** - 上下文感知的自动完成和建议
4. **代码分析** - 诊断、修复建议、重构操作
5. **格式化和样式** - 自动格式化、代码样式检查
6. **生产力工具** - 多光标、代码片段、快速访问

---

## 总结

**VS Code 中可直接移植到 neurx-code 的功能多达 56 个**。通过系统地实现这些功能，neurx-code 可以在 3-4 周内达到专业编辑器级别的功能完整性。

**建议优先顺序**: P0 → P1 → P2 → P3

**快速胜利**: 先完成已有框架的功能（P0），然后集成 LSP 支持（P1），最后实现高级功能（P2-P3）。
