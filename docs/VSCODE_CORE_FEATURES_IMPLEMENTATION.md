# VS Code 核心功能在 neurx-code 中的实现清单

## 📊 优先级矩阵 (可行性 × 价值)

```
高价值 ┤
       │  ⭐⭐ Find      ⭐⭐⭐ Folding
       │  ⭐⭐ Snippet   ⭐⭐⭐ Comment
       │  ⭐⭐ Outline   ⭐⭐⭐ QA
       │  ⭐⭐ Keybind   ⭐⭐⭐ LineOps
低价值 ┤
       └─────────────────────────────
         低难度          高难度
```

---

## 🚀 **第 1 轮：极高优先级** (立即实现 - 本周)

### ✅ 1. **文件操作增强** 
**状态**: ✅ 已完成 (Codex FileSystem)
- 创建/删除/重命名文件
- 批量操作
- 原子写入

**代码位置**: 
- [ExecutorFileSystem.h](src/filesystem/ExecutorFileSystem.h)
- [DirectFileSystem.cpp](src/filesystem/DirectFileSystem.cpp)

---

### ✅ 2. **命令系统** 
**状态**: ✅ 已完成 (CommandManager)
- 命令注册/执行
- 快捷键绑定
- 命令搜索

**代码位置**: 
- [CommandManager.h](src/commands/CommandManager.h)
- [CommandManager.cpp](src/commands/CommandManager.cpp)

**快捷键**:
```
Ctrl+Shift+P  → 命令面板
Ctrl+K, Ctrl+S → 快捷键设置
```

---

### ✅ 3. **搜索面板** 
**状态**: ✅ 已完成 (GlobalSearchEngine)
- 全局搜索
- 正则表达式
- 大小写敏感

**代码位置**: 
- [GlobalSearchEngine.h](src/search/GlobalSearchEngine.h)
- [GlobalSearchEngine.cpp](src/search/GlobalSearchEngine.cpp)
- [SearchPanel.qml](content/SearchPanel.qml)

**快捷键**:
```
Ctrl+Shift+F  → 打开搜索面板
```

---

### ✅ 4. **编辑撤销/重做** 
**状态**: ✅ 已完成 (EditorHistory)
- 堆栈式撤销
- 自动 Redo 清空
- 最多 100 条历史

**代码位置**: 
- [EditorHistory.h](src/editor/EditorHistory.h)
- [EditorHistory.cpp](src/editor/EditorHistory.cpp)

**快捷键**:
```
Ctrl+Z        → 撤销
Ctrl+Y        → 重做
```

---

### ✅ 5. **文件树上下文菜单** 
**状态**: ✅ 已完成 (FileTreeContextMenu)
- 新建文件/文件夹
- 删除/重命名
- 复制路径

**代码位置**: 
- [FileTreeContextMenu.qml](content/FileTreeContextMenu.qml)

**操作**:
```
右键点击文件 → 显示上下文菜单
```

---

## ⭐⭐⭐⭐⭐ **第 2 轮：高优先级** (第 1-2 周)

### 📝 6. **行操作** (Line Operations)
**VS Code 源**: `src/vs/editor/contrib/lineOperations`
**复杂度**: ⭐⭐ (1-2 天)
**核心功能**:
- `Ctrl+X` - 删除行
- `Ctrl+C` / `Ctrl+V` - 复制/剪切行
- `Alt+↑` / `Alt+↓` - 上下移动行
- `Ctrl+Shift+K` - 删除行
- `Ctrl+Shift+D` - 复制行
- `Ctrl+Shift+Backspace` - 删除到行首
- `Ctrl+Shift+End` - 删除到行尾

**实现框架**:
```cpp
class LineOperations {
    // 删除行
    void deleteLines(Editor *editor, int startLine, int endLine);
    
    // 复制/剪切行
    void duplicateLines(Editor *editor);
    void deleteLines(Editor *editor);
    
    // 移动行
    void moveLineUp(Editor *editor);
    void moveLineDown(Editor *editor);
    
    // 排序
    void sortLines(Editor *editor, SortOrder order = Ascending);
    void reverseLines(Editor *editor);
    
    // 删除空白
    void deleteDuplicateLines(Editor *editor);
    void removeTrailingWhitespace(Editor *editor);
};
```

**关键代码片段**:
```cpp
void LineOperations::moveLineUp(Editor *editor) {
    int currentLine = editor->currentLine();
    if (currentLine > 0) {
        QString line = editor->getLine(currentLine);
        QString prevLine = editor->getLine(currentLine - 1);
        
        editor->setLine(currentLine - 1, line);
        editor->setLine(currentLine, prevLine);
        editor->setCursor(currentLine - 1, editor->column());
    }
}
```

**UI 集成**: 编辑菜单 + 快捷键

---

### 🔍 7. **搜索和替换** (Find & Replace)
**VS Code 源**: `src/vs/editor/contrib/find/browser` (4,807 行)
**复杂度**: ⭐⭐⭐⭐ (2-3 天)
**核心功能**:
- `Ctrl+F` - 打开搜索
- `Ctrl+H` - 打开替换
- `Ctrl+G` - 转到行
- `Alt+Enter` - 选择所有匹配项
- 正则表达式支持
- 增量搜索
- 替换预览

**实现框架**:
```cpp
class FindService : public QObject {
    Q_OBJECT
    
    struct FindMatch {
        int line;
        int column;
        int length;
        QString preview;
    };
    
    // 搜索接口
    void search(const QString &pattern, SearchOptions options);
    QList<FindMatch> findAll(const QString &pattern);
    
    // 替换接口
    void replace(int matchIndex, const QString &replacement);
    int replaceAll(const QString &pattern, const QString &replacement);
    
    // 高亮
    void highlightMatches(const QList<FindMatch> &matches);
    void clearHighlight();
    
signals:
    void matchesFound(int count);
    void noMatches();
    void replaced(int count);
};
```

**关键算法**:
```cpp
// 增量搜索 (使用 Boyer-Moore 优化)
QList<FindMatch> FindService::findAll(const QString &pattern) {
    QList<FindMatch> matches;
    const QString &text = editor->allText();
    
    int index = 0;
    while ((index = text.indexOf(pattern, index)) != -1) {
        int line = text.left(index).count('\n');
        int col = index - text.lastIndexOf('\n', index - 1) - 1;
        
        matches.append({line, col, pattern.length(), ""});
        index += pattern.length();
    }
    return matches;
}
```

**UI 集成**: 分离的 FindPanel.qml + 编辑器集成显示

---

### 📚 8. **代码折叠** (Code Folding)
**VS Code 源**: `src/vs/editor/contrib/folding` (4,921 行)
**复杂度**: ⭐⭐⭐⭐ (2-3 天)
**核心功能**:
- `Ctrl+Shift+[` - 折叠区块
- `Ctrl+Shift+]` - 展开区块
- `Ctrl+K, Ctrl+0` - 折叠所有
- `Ctrl+K, Ctrl+J` - 展开所有
- 自动识别代码块 (函数、类、注释)

**实现框架**:
```cpp
class FoldingManager : public QObject {
    Q_OBJECT
    
    struct FoldRange {
        int startLine;
        int endLine;
        int indent;
        QString type;  // "function", "class", "comment", etc.
    };
    
    // 计算折叠范围
    QList<FoldRange> computeFoldRanges(const QString &language);
    
    // 折叠操作
    void toggleFold(int line);
    void fold(int line);
    void unfold(int line);
    void foldAll();
    void unfoldAll();
    
    // 查询
    bool isFolded(int line) const;
    FoldRange getFoldRange(int line) const;
};
```

**关键算法**:
```cpp
// 识别代码块边界
QList<FoldRange> FoldingManager::computeFoldRanges(const QString &language) {
    QList<FoldRange> ranges;
    
    auto lines = text.split('\n');
    for (int i = 0; i < lines.size(); ++i) {
        const QString &line = lines[i];
        int indent = getIndentation(line);
        
        // 检测函数/类定义
        if (line.contains(QRegExp("^\\s*(def|class|function)\\s+"))) {
            int endLine = findBlockEnd(i, indent);
            ranges.append({i, endLine, indent, "function"});
            i = endLine;  // 跳过已处理的行
        }
        
        // 检测注释块
        if (line.contains("/*")) {
            int endLine = findCommentEnd(i);
            ranges.append({i, endLine, indent, "comment"});
            i = endLine;
        }
    }
    return ranges;
}
```

**UI 集成**: 行号栏折叠指示器 + 快捷键

---

### 💬 9. **注释切换** (Comment)
**VS Code 源**: `src/vs/editor/contrib/comment` (1,000 行)
**复杂度**: ⭐⭐ (1-2 天)
**核心功能**:
- `Ctrl+/` - 切换行注释
- `Ctrl+Shift+/` - 切换块注释
- 智能缩进

**实现框架**:
```cpp
class CommentManager : public QObject {
    Q_OBJECT
    
    struct CommentSyntax {
        QString lineComment;      // "//"
        QString blockStart;       // "/*"
        QString blockEnd;         // "*/"
    };
    
    // 获取语言特定的注释语法
    CommentSyntax getSyntax(const QString &language);
    
    // 注释操作
    void toggleLineComment(Editor *editor);
    void toggleBlockComment(Editor *editor);
    void addLineComment(Editor *editor);
    void removeLineComment(Editor *editor);
    void uncommentLines(Editor *editor);
};
```

**关键实现**:
```cpp
void CommentManager::toggleLineComment(Editor *editor) {
    auto [startLine, endLine] = editor->getSelectionLines();
    CommentSyntax syntax = getSyntax(editor->language());
    
    bool hasComment = false;
    for (int i = startLine; i <= endLine; ++i) {
        QString line = editor->getLine(i);
        if (line.trimmed().startsWith(syntax.lineComment)) {
            hasComment = true;
            break;
        }
    }
    
    for (int i = startLine; i <= endLine; ++i) {
        QString line = editor->getLine(i);
        if (hasComment) {
            // 移除注释
            line.replace(syntax.lineComment, "");
        } else {
            // 添加注释，保持缩进
            int indent = getIndentation(line);
            line = QString(indent, ' ') + syntax.lineComment + " " + line.trimmed();
        }
        editor->setLine(i, line);
    }
}
```

**UI 集成**: 编辑菜单 + 快捷键

---

### 🔤 10. **代码片段** (Snippets)
**VS Code 源**: `src/vs/editor/contrib/snippet` (2,800 行)
**复杂度**: ⭐⭐⭐ (2-3 天)
**核心功能**:
- 片段定义 (JSON 格式)
- 变量替换 ($0, $1, $name, etc.)
- 占位符编辑
- 自动补全集成

**片段格式**:
```json
{
  "C++ main": {
    "prefix": "main",
    "body": [
      "#include <iostream>",
      "using namespace std;",
      "",
      "int main() {",
      "    ${1:// code here}",
      "    return 0;",
      "}"
    ],
    "description": "C++ main function"
  }
}
```

**实现框架**:
```cpp
class SnippetManager : public QObject {
    Q_OBJECT
    
    struct Snippet {
        QString id;
        QString prefix;
        QStringList body;
        QString description;
        QString language;
    };
    
    struct SnippetVariable {
        int id;           // $0, $1, $2...
        QString name;     // $name
        QString defaultValue;
        int startLine, startCol;
        int endLine, endCol;
    };
    
    // 加载片段
    void loadSnippets(const QString &language);
    
    // 插入片段
    void insertSnippet(const Snippet &snippet, int line, int col);
    
    // 变量解析
    QString resolveVariables(const QString &snippet);
    
    // 占位符管理
    void selectNextPlaceholder();
    void selectPreviousPlaceholder();
};
```

**关键实现**:
```cpp
void SnippetManager::insertSnippet(const Snippet &snippet, int line, int col) {
    QString content = snippet.body.join('\n');
    
    // 替换变量
    content.replace("${TM_FILENAME}", QFileInfo(editor->filePath()).fileName());
    content.replace("${TM_DATE}", QDate::currentDate().toString("yyyy-MM-dd"));
    content.replace("${TM_YEAR}", QString::number(QDate::currentDate().year()));
    
    // 插入内容
    editor->insertText(line, col, content);
    
    // 处理占位符
    QRegExp placeholderPattern(R"(\$\{(\d+)(?::([^}]*))?\})");
    int pos = 0;
    while ((pos = placeholderPattern.indexIn(content, pos)) != -1) {
        // 提取 $1, $2 等并高亮显示
        pos += placeholderPattern.matchedLength();
    }
    
    // 跳转到第一个占位符
    selectNextPlaceholder();
}
```

**UI 集成**: 自动补全触发器 + 占位符导航

---

## ⭐⭐⭐ **第 3 轮：中等优先级** (第 3-4 周)

### 📍 11. **Outline / 符号导航**
**VS Code 源**: `src/vs/workbench/contrib/outline`
**复杂度**: ⭐⭐ (1.5 天)
**核心功能**:
- 快速查看代码结构
- 跳转到函数/类
- 导航面包屑
- `Ctrl+Shift+O` - 显示 Outline

### 📊 12. **诊断显示** (Problems/Markers)
**复杂度**: ⭐⭐ (1.5 天)
**核心功能**:
- 显示编译错误
- 显示 Linter 警告
- 快速跳转到错误行
- 错误面板

### 🔗 13. **全局搜索** (Search in Files)
**VS Code 源**: `src/vs/workbench/contrib/search` (99 个文件)
**复杂度**: ⭐⭐⭐⭐ (3-4 天)
**核心功能**:
- `Ctrl+Shift+F` - 搜索所有文件
- 递归搜索目录
- 排除模式
- 替换预览
- 搜索历史

### ⚙️ 14. **配置系统** (Configuration)
**复杂度**: ⭐⭐ (1 天)
**核心功能**:
- `settings.json` 支持
- 用户/工作区/全局配置
- 配置验证

### 🎨 15. **主题系统** (Themes)
**复杂度**: ⭐⭐ (1 天)
**核心功能**:
- 内置主题
- 自定义主题加载
- 主题切换

---

## ⭐⭐ **第 4 轮：高级功能** (第 5+ 周)

### 📌 16. **快捷键管理** (Keybindings)
- 快捷键查看/编辑
- 快捷键冲突检测
- `Ctrl+K, Ctrl+S` - 打开快捷键编辑器

### 👆 17. **悬停提示** (Hover)
- 变量类型提示
- 文档展示
- 依赖 LSP

### 💡 18. **代码操作** (Code Actions)
- 快速修复
- 重构
- 依赖 LSP

### 🔤 19. **参数提示** (Parameter Hints)
- 函数签名显示
- 参数导航
- 依赖 LSP

### 🌐 20. **LSP 集成** (Language Server Protocol)
- 连接语言服务器
- 代码补全
- 定义跳转
- 引用查找

---

## 📈 **实现时间表** (8 周加速开发)

```
┌─ Week 1-2 ─────────────────────────────────────────┐
│ ✅ Undo/Redo (完成)                                   │
│ ✅ Command System (完成)                              │
│ ✅ Search Panel (完成)                                │
│ ✅ File Operations (完成)                             │
│ ⏳ Line Operations (开始)                             │
└─────────────────────────────────────────────────────┘

┌─ Week 3-4 ─────────────────────────────────────────┐
│ ⏳ Find & Replace (开始)                             │
│ ⏳ Code Folding (开始)                               │
│ ⏳ Snippets (开始)                                   │
│ ⏳ Comment Toggle (开始)                             │
└─────────────────────────────────────────────────────┘

┌─ Week 5-6 ─────────────────────────────────────────┐
│ ⏳ Outline View                                      │
│ ⏳ Problems/Diagnostics                              │
│ ⏳ Global Search                                     │
│ ⏳ Configuration System                              │
└─────────────────────────────────────────────────────┘

┌─ Week 7-8 ─────────────────────────────────────────┐
│ ⏳ Hover Provider                                    │
│ ⏳ Code Actions                                      │
│ ⏳ LSP Integration                                   │
└─────────────────────────────────────────────────────┘
```

---

## 🎯 **立即可做的 (本周)**

### ✅ 已完成（5 个功能）
1. Undo/Redo ✅
2. Command System ✅
3. Search Panel ✅
4. File Operations ✅
5. Context Menu ✅

### 📝 建议下一步实现顺序

#### 优先级 1: **Line Operations** (1-2 天)
```cpp
// src/editor/LineOperations.h (新文件)
class LineOperations {
    void deleteLines(int startLine, int endLine);
    void duplicateLines(int startLine, int endLine);
    void moveLineUp(int line);
    void moveLineDown(int line);
    void sortLines(int startLine, int endLine, bool reverse = false);
    void reverseLines(int startLine, int endLine);
};
```

#### 优先级 2: **Find & Replace** (2-3 天)
```cpp
// src/editor/FindService.h (新文件)
class FindService : public QObject {
    Q_OBJECT
public:
    QList<FindMatch> findAll(const QString &pattern);
    int replaceAll(const QString &pattern, const QString &replacement);
};
```

#### 优先级 3: **Comment Toggle** (1 天)
```cpp
// src/editor/CommentManager.h (新文件)
class CommentManager {
    void toggleLineComment(int startLine, int endLine);
    void toggleBlockComment(int startLine, int endLine);
};
```

---

## 📊 **代码统计预估**

| 功能 | C++ 行数 | QML 行数 | 总计 | 时间 |
|------|---------|---------|------|------|
| 已完成 | 1,200 | 600 | 1,800 | 1 周 |
| Line Ops | 400 | 100 | 500 | 2 天 |
| Find | 800 | 200 | 1,000 | 3 天 |
| Folding | 600 | 200 | 800 | 3 天 |
| Snippet | 700 | 150 | 850 | 3 天 |
| Comment | 300 | 50 | 350 | 1 天 |
| **总计** | **4,000** | **1,300** | **5,300** | **8 周** |

---

## 🔗 **参考资源**

### VS Code 源代码位置
- **Line Ops**: `src/vs/editor/contrib/lineOperations`
- **Find**: `src/vs/editor/contrib/find/browser`
- **Folding**: `src/vs/editor/contrib/folding`
- **Snippets**: `src/vs/editor/contrib/snippet`
- **Comment**: `src/vs/editor/contrib/comment`

### neurx-code 文件结构
```
neurx-code/
├── src/
│   ├── editor/               ← 编辑器功能
│   │   ├── EditorHistory.h   ✅
│   │   ├── LineOperations.h  📝
│   │   ├── FindService.h     📝
│   │   └── ...
│   ├── search/               ← 搜索功能
│   │   ├── GlobalSearchEngine.h ✅
│   │   └── ...
│   ├── commands/             ← 命令系统
│   │   ├── CommandManager.h  ✅
│   │   └── ...
│   └── filesystem/           ← 文件系统
│       ├── ExecutorFileSystem.h ✅
│       └── ...
├── content/
│   ├── SearchPanel.qml       ✅
│   ├── CommandPalette.qml    ✅
│   ├── FileTreeContextMenu.qml ✅
│   └── ...
└── CMakeLists.txt
```

---

## ⚡ **快速开始清单**

- [ ] 审查本文档
- [ ] 选择下一个优先级 1 功能 (Line Operations)
- [ ] 创建 `src/editor/LineOperations.h`
- [ ] 实现核心方法
- [ ] 集成到 EditorPanel.qml
- [ ] 编译测试
- [ ] 迁移到下一个功能

---

**版本**: 1.0  
**日期**: 2026年6月4日  
**作者**: VS Code 功能分析
