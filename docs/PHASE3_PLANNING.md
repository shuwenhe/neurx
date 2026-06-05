# Phase 3: 高优先级编辑器功能实现计划

**状态**: 已实现并编译，作为规划参考保留  
**目标**: 记录 Phase 3 核心编辑器功能的设计与落地路径  
**预计时长**: 已完成  
**难度**: 中等 (2-4/5)

---

## 🎯 Phase 3 目标概述

基于 Phase 2 的 16 个功能提供者基础，Phase 3 将实现 5 个**极高优先级**的编辑器功能模块，这些功能是 VS Code 编辑体验的核心。

### Phase 3 包含的功能

| # | 功能名称 | 代码量 | 难度 | 依赖 | 状态 |
|---|---------|-------|------|------|------|
| 1 | 快速命令面板 | 400-600 | 2/5 | CommandSystem | ✅ 已实现 |
| 2 | 搜索和替换 | 1,500-2,000 | 4/5 | EditorProvider | ✅ 已实现 |
| 3 | 代码折叠 | 2,000-2,500 | 4/5 | LanguageService | ✅ 已实现 |
| 4 | 代码片段 | 1,200-1,500 | 3/5 | EditorProvider | ⚠️ 仍待 UI 继续打磨 |
| 5 | 注释切换 | 600-800 | 2/5 | EditorProvider | ✅ 已实现 |

**总代码行数**: ~6,000-7,500 行  
**总工作量**: 10-15 天  

---

## 📋 Phase 3.1: 快速命令面板 (Quick Access Manager)

### 功能描述

快速命令面板是用户快速访问所有命令的入口。用户按 `Ctrl+P` 或 `Cmd+P` 打开面板，输入命令名称进行搜索和执行。

### 关键特性

✅ 模糊搜索 (Fuzzy Search)  
✅ 命令分类显示  
✅ 最近使用记录  
✅ 快捷键提示  
✅ 实时过滤  

### 核心 API

```cpp
// src/workbench/QuickAccessManager.h

class QuickAccessManager : public QObject {
    Q_OBJECT
    
public:
    struct QuickAccessItem {
        QString id;           // 命令 ID
        QString label;        // 显示文本
        QString description;  // 描述
        QString detail;       // 详情
        QString iconPath;     // 图标路径
        int score;           // 匹配分数
    };
    
    struct QuickAccessResult {
        QList<QuickAccessItem> items;
        int totalCount;
        bool hasMore;
    };
    
    // 搜索命令
    Q_INVOKABLE QuickAccessResult search(const QString& query, int limit = 50);
    
    // 获取最近使用的命令
    Q_INVOKABLE QList<QuickAccessItem> getRecentItems(int count = 10);
    
    // 执行命令
    Q_INVOKABLE bool executeCommand(const QString& commandId);
    
    // 模糊匹配计分
    Q_INVOKABLE int calculateMatchScore(const QString& query, const QString& text);
    
    // 注册快速访问提供者
    void registerProvider(const QString& prefix, QuickAccessProvider* provider);
    
signals:
    void itemsLoaded(const QuickAccessResult& result);
    void commandExecuted(const QString& commandId);
    void error(const QString& message);
};
```

### 实现步骤

1. **第 1 天**:
   - [ ] 创建 QuickAccessManager 类骨架
   - [ ] 设计模糊搜索算法
   - [ ] 实现命令搜索逻辑

2. **第 1.5 天**:
   - [ ] 实现最近使用记录
   - [ ] 添加快捷键提示
   - [ ] 实现命令执行

3. **第 0.5 天**:
   - [ ] 集成到 AgentController
   - [ ] 编写单元测试

### 代码文件

```
src/workbench/
├── QuickAccessManager.h        (120 行)
├── QuickAccessManager.cpp      (300-400 行)
├── QuickAccessProvider.h       (50 行)
└── QuickAccessProvider.cpp     (100 行)
```

### 编译目标

已添加到 `CMakeLists.txt` 的 `neurx_ui` 库

---

## 📋 Phase 3.2: 搜索和替换 (Find & Replace Service)

### 功能描述

在当前文件或整个工作区搜索文本，支持大小写敏感、正则表达式、全字匹配等选项，并支持替换功能。

### 关键特性

✅ 大小写敏感/不敏感  
✅ 正则表达式搜索  
✅ 全字匹配  
✅ 增量搜索  
✅ 高亮显示  
✅ 替换单个/全部  
✅ 搜索历史  

### 核心 API

```cpp
// src/editor/FindService.h

class FindService : public QObject {
    Q_OBJECT
    
public:
    struct FindMatch {
        int line;
        int column;
        int endLine;
        int endColumn;
        QString text;
        int resultIndex;
    };
    
    struct FindOptions {
        bool caseSensitive = false;
        bool regexMode = false;
        bool wholeWord = false;
        bool backwards = false;
    };
    
    struct ReplaceResult {
        int replacedCount;
        QList<FindMatch> matches;
        bool success;
    };
    
    // 查找所有匹配
    Q_INVOKABLE QList<FindMatch> findAll(const QString& query, const FindOptions& options);
    
    // 查找下一个
    Q_INVOKABLE FindMatch findNext(const QString& query, int currentLine, int currentColumn, const FindOptions& options);
    
    // 查找上一个
    Q_INVOKABLE FindMatch findPrevious(const QString& query, int currentLine, int currentColumn, const FindOptions& options);
    
    // 高亮匹配
    Q_INVOKABLE void highlightMatches(const QList<FindMatch>& matches);
    
    // 替换单个
    Q_INVOKABLE bool replaceSingle(const QString& pattern, const QString& replacement, const FindMatch& match, const FindOptions& options);
    
    // 替换全部
    Q_INVOKABLE ReplaceResult replaceAll(const QString& pattern, const QString& replacement, const FindOptions& options);
    
    // 获取搜索历史
    Q_INVOKABLE QStringList getSearchHistory(int limit = 10);
    
signals:
    void matchesFound(const QList<FindMatch>& matches);
    void matchesHighlighted(int count);
    void replacementDone(int count);
    void error(const QString& message);
    
private:
    int calculateScore(const QString& query, const QString& line);
    QList<FindMatch> applyRegex(const QString& pattern, const QString& text, const FindOptions& options);
};
```

### 实现步骤

1. **第 1-1.5 天**:
   - [ ] 创建 FindService 类
   - [ ] 实现基础文本搜索
   - [ ] 实现大小写/全字匹配

2. **第 1-1.5 天**:
   - [ ] 实现正则表达式支持
   - [ ] 实现增量搜索
   - [ ] 实现高亮显示

3. **第 1 天**:
   - [ ] 实现替换逻辑
   - [ ] 实现搜索历史
   - [ ] 集成到 AgentController

### 代码文件

```
src/editor/
├── FindService.h          (150 行)
├── FindService.cpp        (700-900 行)
└── RegexMatcher.h/cpp     (200 行)
```

---

## 📋 Phase 3.3: 代码折叠 (Code Folding Manager)

### 功能描述

允许用户折叠和展开代码块 (函数、类、注释块等)，以专注于特定代码段。

### 关键特性

✅ 语言特定的折叠规则  
✅ 用户手动折叠  
✅ 全部折叠/展开  
✅ 按级别折叠  
✅ 记住折叠状态  

### 核心 API

```cpp
// src/editor/FoldingManager.h

class FoldingManager : public QObject {
    Q_OBJECT
    
public:
    struct FoldRange {
        int startLine;
        int endLine;
        int level;          // 嵌套级别
        QString type;       // function, class, block, etc.
        bool isCollapsed;
    };
    
    // 计算折叠范围
    Q_INVOKABLE QList<FoldRange> computeFoldRanges(const QString& code, const QString& language);
    
    // 切换折叠
    Q_INVOKABLE void toggleFold(int line);
    
    // 全部折叠
    Q_INVOKABLE void foldAll();
    
    // 全部展开
    Q_INVOKABLE void unfoldAll();
    
    // 按级别折叠
    Q_INVOKABLE void foldLevel(int level);
    
    // 获取当前折叠状态
    Q_INVOKABLE QList<FoldRange> getFoldRanges();
    
signals:
    void foldRangesUpdated(const QList<FoldRange>& ranges);
    void foldStateChanged(int line, bool isCollapsed);
};
```

### 实现步骤

1. **第 1-1.5 天**:
   - [ ] 创建 FoldingManager 类
   - [ ] 实现语法树分析
   - [ ] 实现基础折叠范围计算

2. **第 1-1.5 天**:
   - [ ] 实现用户交互逻辑
   - [ ] 实现状态记忆
   - [ ] 多语言支持

### 代码文件

```
src/editor/
├── FoldingManager.h          (120 行)
├── FoldingManager.cpp        (600-800 行)
├── FoldingStrategy.h         (100 行)
├── language/
│   ├── CPPFoldingStrategy.h/cpp
│   ├── JavaScriptFoldingStrategy.h/cpp
│   └── PythonFoldingStrategy.h/cpp
```

---

## 📋 Phase 3.4: 代码片段 (Snippet Manager)

### 功能描述

用户可以快速插入预定义的代码片段，支持占位符、变量替换和 Tab 间导航。

### 关键特性

✅ 片段变量替换  
✅ 占位符导航  
✅ 默认片段库  
✅ 用户自定义片段  
✅ 语言特定片段  

### 核心 API

```cpp
// src/editor/SnippetManager.h

class SnippetManager : public QObject {
    Q_OBJECT
    
public:
    struct Snippet {
        QString prefix;      // 触发前缀
        QString body;        // 片段体
        QStringList scopes;  // 适用的语言
        QString description; // 描述
    };
    
    // 获取适用的片段
    Q_INVOKABLE QList<Snippet> getSnippets(const QString& language);
    
    // 查找片段
    Q_INVOKABLE QList<Snippet> searchSnippets(const QString& query);
    
    // 插入片段
    Q_INVOKABLE bool insertSnippet(const Snippet& snippet, int line, int column);
    
    // 解析变量
    Q_INVOKABLE QString resolveVariables(const QString& snippet);
    
    // 获取可用的变量和函数
    Q_INVOKABLE QStringList getAvailableVariables();
    
    // 用户注册自定义片段
    Q_INVOKABLE void registerCustomSnippet(const Snippet& snippet);
    
signals:
    void snippetInserted(const Snippet& snippet);
    void snippetsUpdated();
};
```

### 实现步骤

1. **第 1 天**:
   - [ ] 创建 SnippetManager 类
   - [ ] 实现片段解析
   - [ ] 创建默认片段库

2. **第 1 天**:
   - [ ] 实现变量替换
   - [ ] 实现占位符导航
   - [ ] 用户自定义片段支持

### 代码文件

```
src/editor/
├── SnippetManager.h          (120 行)
├── SnippetManager.cpp        (600-800 行)
├── Snippet.h                 (80 行)
└── snippets/
    ├── cpp.json
    ├── javascript.json
    ├── python.json
    └── ...
```

---

## 📋 Phase 3.5: 注释切换 (Comment Manager)

### 功能描述

快速切换单行或块注释，支持多种语言的注释语法。

### 关键特性

✅ 行注释 (Toggle Line Comment)  
✅ 块注释 (Toggle Block Comment)  
✅ 多行选择  
✅ 语言特定注释语法  

### 核心 API

```cpp
// src/editor/CommentManager.h

class CommentManager : public QObject {
    Q_OBJECT
    
public:
    struct CommentStyle {
        QString lineComment;   // e.g., "//"
        QString blockStart;    // e.g., "/*"
        QString blockEnd;      // e.g., "*/"
    };
    
    // 切换行注释
    Q_INVOKABLE void toggleLineComment(int line, int column);
    
    // 切换块注释
    Q_INVOKABLE void toggleBlockComment(int startLine, int endLine);
    
    // 添加行注释
    Q_INVOKABLE void addLineComment(const QList<int>& lines);
    
    // 移除行注释
    Q_INVOKABLE void removeLineComment(const QList<int>& lines);
    
    // 获取注释风格
    Q_INVOKABLE CommentStyle getCommentStyle(const QString& language);
    
signals:
    void commentToggled(int line, bool isCommented);
    void commentsAdded(int count);
    void commentsRemoved(int count);
};
```

### 实现步骤

1. **第 0.5 天**:
   - [ ] 创建 CommentManager 类
   - [ ] 实现行注释逻辑

2. **第 0.5 天**:
   - [ ] 实现块注释逻辑
   - [ ] 添加语言注释规则

### 代码文件

```
src/editor/
├── CommentManager.h          (80 行)
├── CommentManager.cpp        (300-400 行)
└── language/
    ├── CommentRules.h        (150 行)
    └── CommentRules.cpp      (200 行)
```

---

## 🔗 集成计划

### AgentController 修改

```cpp
// src/bridge/AgentController.h - 新增成员

class AgentController : public QObject {
    Q_OBJECT
    
private:
    // Phase 3 新增
    std::unique_ptr<QuickAccessManager> m_quickAccessManager;
    std::unique_ptr<FindService> m_findService;
    std::unique_ptr<FoldingManager> m_foldingManager;
    std::unique_ptr<SnippetManager> m_snippetManager;
    std::unique_ptr<CommentManager> m_commentManager;
    
public:
    // Phase 3 新增 Q_INVOKABLE 方法 (~40+ 个)
    
    // Quick Access
    Q_INVOKABLE QVariantList quickAccessSearch(const QString& query, int limit);
    Q_INVOKABLE QVariantList getRecentCommands(int count);
    Q_INVOKABLE bool executeQuickCommand(const QString& commandId);
    
    // Find & Replace
    Q_INVOKABLE QVariantList findMatches(const QString& query, const QJsonObject& options);
    Q_INVOKABLE QVariantMap findNext(const QString& query, int line, int column);
    Q_INVOKABLE QVariantMap replaceSingle(const QString& pattern, const QString& replacement);
    Q_INVOKABLE int replaceAll(const QString& pattern, const QString& replacement);
    
    // Code Folding
    Q_INVOKABLE QVariantList computeFoldRanges(const QString& code, const QString& language);
    Q_INVOKABLE void toggleFold(int line);
    Q_INVOKABLE void foldAll();
    
    // Snippets
    Q_INVOKABLE QVariantList getSnippets(const QString& language);
    Q_INVOKABLE bool insertSnippet(const QJsonObject& snippet);
    
    // Comments
    Q_INVOKABLE void toggleLineComment(int line);
    Q_INVOKABLE void toggleBlockComment(int startLine, int endLine);
};
```

### CMakeLists.txt 修改

```cmake
# 添加 Phase 3 源文件到 neurx_ui 库

set(PHASE3_SOURCES
    src/workbench/QuickAccessManager.cpp
    src/workbench/QuickAccessProvider.cpp
    src/editor/FindService.cpp
    src/editor/FoldingManager.cpp
    src/editor/SnippetManager.cpp
    src/editor/CommentManager.cpp
    src/editor/language/CommentRules.cpp
)

list(APPEND NEURX_UI_SOURCES ${PHASE3_SOURCES})
```

---

## 📅 时间表

### Week 1
| 日期 | 任务 | 进度 |
|------|------|------|
| Day 1-2 | Quick Access Manager | ▓▓░░░░░░░░ |
| Day 3 | Find & Replace (Part 1) | ▓░░░░░░░░░ |

### Week 2
| 日期 | 任务 | 进度 |
|------|------|------|
| Day 4-5 | Find & Replace (Part 2) | ▓▓░░░░░░░░ |
| Day 6 | Code Folding (Part 1) | ▓░░░░░░░░░ |

### Week 3
| 日期 | 任务 | 进度 |
|------|------|------|
| Day 7-8 | Code Folding (Part 2) | ▓▓░░░░░░░░ |
| Day 9 | Snippets | ▓░░░░░░░░░ |
| Day 10 | Comments + Integration | ▓▓░░░░░░░░ |

---

## ✅ 验收标准

### 功能完成度
- [ ] 5 个模块全部实现
- [ ] 所有核心 API 可用
- [ ] 所有 Q_INVOKABLE 方法声明和实现
- [ ] 代码编译无错误

### 编译和集成
- [ ] neurx_ui 库编译成功
- [ ] neurx_core 库编译成功
- [ ] AgentController 集成成功
- [ ] 所有 QML 方法可访问

### 质量指标
- [ ] 代码风格一致
- [ ] 错误处理完善
- [ ] 输入验证完善
- [ ] 无内存泄漏

### 单元测试
- [ ] Quick Access: 5+ 测试
- [ ] Find Service: 10+ 测试
- [ ] Code Folding: 5+ 测试
- [ ] Snippets: 5+ 测试
- [ ] Comments: 3+ 测试

---

## 🚀 里程碑

| 里程碑 | 目标 | 预计时间 |
|--------|------|----------|
| M1 | Quick Access 完成 | Day 2 |
| M2 | Find & Replace 完成 | Day 5 |
| M3 | Code Folding 完成 | Day 8 |
| M4 | Snippets + Comments 完成 | Day 10 |
| M5 | 集成和测试完成 | Day 10 |
| M6 | Phase 3 最终报告 | Day 11 |

---

## 📚 依赖和前置条件

### Phase 2 依赖
✅ FeatureProviders (已完成)  
✅ NavigationProviders (已完成)  
✅ EditingProviders (已完成)  
✅ AgentController 集成 (已完成)  

### 编译依赖
- Qt 6.x (Qt Core, Qt Gui)
- CMake 4.3.3+
- C++17 编译器

### 库依赖
- neurx_core 库 (基础)
- neurx_ui 库 (UI 组件)

---

## 📊 预期成果

### 代码统计

| 模块 | 行数 | 复杂度 |
|------|------|--------|
| Quick Access | 500-700 | 中 |
| Find & Replace | 900-1,200 | 高 |
| Code Folding | 800-1,000 | 高 |
| Snippets | 700-900 | 中 |
| Comments | 400-500 | 低 |
| 集成 | 500-800 | 中 |
| **总计** | **~6,000-7,500** | **中-高** |

### API 统计

| 模块 | Q_INVOKABLE 方法数 |
|------|------------------|
| Quick Access | 5-6 |
| Find & Replace | 8-10 |
| Code Folding | 6-8 |
| Snippets | 6-8 |
| Comments | 4-6 |
| **总计** | **~30-40** |

### 库大小估计

```
libneurx_ui.a (Phase 3): +2-3 MB
libneurx_core.a: +1-2 MB
```

---

## 🎓 关键设计决策

### 1. 搜索优化
使用增量搜索而非全文搜索，以提高性能。

### 2. 代码折叠策略
优先使用 AST 分析而非正则表达式，以保证准确性。

### 3. 片段变量
使用 Vim 风格的变量替换 (`$variable`, `${variable:default}`)。

### 4. 注释规则
每种语言维护独立的注释风格配置。

---

## 📖 参考资源

- VS Code Find API: https://github.com/microsoft/vscode/tree/main/src/vs/editor/contrib/find
- Folding Rules: https://github.com/microsoft/vscode/tree/main/src/vs/editor/contrib/folding
- Snippet Format: https://code.visualstudio.com/docs/editor/userdefinedsnippets

---

## 🔄 下一步

1. ✅ 完成 Phase 3 规划文档 (本文件)
2. ⏳ 创建各模块的详细设计文档
3. ⏳ 开始实现 Quick Access Manager
4. ⏳ 逐步实现其他 4 个模块
5. ⏳ 集成到 AgentController
6. ⏳ 编译验证和单元测试
7. ⏳ 生成 Phase 3 完成报告

---

**创建时间**: 2026-06-05  
**版本**: 1.0  
**状态**: 📋 规划中  

**下一步**: 👉 开始实现 Phase 3.1 - Quick Access Manager
