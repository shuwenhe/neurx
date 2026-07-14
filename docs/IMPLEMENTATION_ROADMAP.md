# neurx-code 特性实现路线图

## 快速参考

### ✅ 已完成功能 (可立即使用)
- **文件系统**: 读写、批量、原子操作、沙箱隔离
- **编辑器基础**: 文本编辑、语法高亮
- **文件浏览**: 树形展示、刷新
- **主题系统**: 浅色/深色切换
- **设置面板**: 编辑器配置
- **聊天界面**: 与 agent 交互

### 🔄 进行中 (设计/部分实现)
- **任务运行**: TaskPlanPanel 框架存在
- **调试面板**: 设计中
- **终端**: 基础设施准备中

### ⏳ 待实现 (已规划)
- **搜索/替换**
- **代码导航** (Goto, References)
- **快捷键系统**
- **Git 集成**
- **调试器**

---

## 立即可实现的 5 个功能 (< 1 周)

### 1️⃣ **编辑器 Undo/Redo**

**当前状态**: EditorPanel.qml 有文本编辑，但缺少历史记录

**实现步骤**:
```cpp
// 1. 在 EditorPanel.cpp 中添加历史栈
class EditorHistory {
    QStack<EditorState> undoStack;
    QStack<EditorState> redoStack;
};

// 2. 侦听文本变化
onTextChanged: {
    editorHistory.push(currentState)
}

// 3. 快捷键绑定
Ctrl+Z  → undo()
Ctrl+Y  → redo()
```

**代码量**: ~200 行 C++ + ~100 行 QML  
**复杂度**: ⭐⭐ (简单)  
**收益**: 高 (用户期望)

---

### 2️⃣ **全局搜索/替换**

**当前状态**: Grep 工具存在，缺少 UI

**实现步骤**:
```cpp
// 1. 创建 SearchPanel.qml
SearchPanel {
    TextField { placeholder: "搜索..." }
    TextField { placeholder: "替换..." }
    ListView { model: searchResults }
}

// 2. 后端搜索引擎
class GlobalSearchEngine {
    QStringList search(QString pattern, QString path);
    void replace(QString pattern, QString replacement, QString path);
};

// 3. 集成 Bash Grep
agentController.executeCommand("grep -r " + pattern + " " + path);
```

**代码量**: ~400 行 C++ + ~300 行 QML  
**复杂度**: ⭐⭐⭐ (中等)  
**收益**: 很高 (基本需求)

---

### 3️⃣ **文件树右键菜单**

**当前状态**: FileTreePanel 存在，缺少上下文菜单

**实现步骤**:
```qml
// FileTreeItem.qml
FileTreeItem {
    MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            }
        }
    }
    
    Menu {
        id: contextMenu
        MenuItem { text: "打开" }
        MenuItem { text: "新建文件" }
        MenuItem { text: "新建文件夹" }
        MenuItem { text: "删除" }
        MenuItem { text: "重命名" }
        MenuItem { text: "复制路径" }
    }
}
```

**代码量**: ~200 行 QML  
**复杂度**: ⭐⭐ (简单)  
**收益**: 高 (用户体验)

---

### 4️⃣ **代码折叠/展开**

**当前状态**: 需要实现

**实现步骤**:
```cpp
// 1. 词法分析识别块 (函数、类、if/for等)
class CodeFolder {
    QVector<FoldRegion> detectFolds(const QString& code);
};

// 2. 渲染折叠指示器
QML:
Rectangle {
    width: 20
    height: lineHeight
    MouseArea {
        onClicked: toggleFold()
    }
    Text { text: isFolded ? "▶" : "▼" }
}

// 3. 切换代码可见性
textEdit.setFoldRegion(region, isFolded);
```

**代码量**: ~300 行 C++ + ~150 行 QML  
**复杂度**: ⭐⭐⭐ (中等)  
**收益**: 中等 (代码导航)

---

### 5️⃣ **命令面板** (Ctrl+Shift+P)

**当前状态**: 命令系统框架存在

**实现步骤**:
```qml
// CommandPalette.qml
Rectangle {
    TextField {
        id: searchField
        onTextChanged: {
            filteredCommands = allCommands.filter(cmd => 
                cmd.name.includes(searchField.text)
            )
        }
    }
    
    ListView {
        model: filteredCommands
        delegate: CommandItem {
            onClicked: executeCommand()
        }
    }
}
```

```cpp
// 注册命令
registerCommand("editor.formatDocument", 
    [this]() { 
        currentEditor->formatDocument(); 
    }
);

registerCommand("file.newFile",
    [this]() {
        createNewFile();
    }
);
```

**代码量**: ~250 行 C++ + ~200 行 QML  
**复杂度**: ⭐⭐⭐ (中等)  
**收益**: 很高 (效率提升)

---

## 中期实现 (2-4 周)

### 6️⃣ **快捷键绑定系统**

```cpp
class KeyBindingManager {
    // keybindings.json 支持
    struct KeyBinding {
        QString key;        // "Ctrl+S"
        QString command;    // "file.save"
        QString when;       // "editorTextFocus"
    };
    
    void loadBindings(const QString& path);
    void registerBinding(const KeyBinding& binding);
    void executeBinding(const QString& keySequence);
};
```

**代码量**: ~500 行  
**复杂度**: ⭐⭐⭐  
**收益**: 高

---

### 7️⃣ **LSP 集成** (语言服务器)

```cpp
class LanguageServerClient {
    // 支持任意 LSP 服务器
    void initialize(const QString& serverPath);
    
    // 基本 LSP 方法
    void hover(const Position& pos);           // 悬停提示
    void completion(const Position& pos);       // 自动完成
    void definition(const Position& pos);       // 转到定义
    void references(const Position& pos);       // 查找引用
    void rename(const Position& pos, QString newName);
    void documentSymbol();                      // 大纲
};
```

**支持的服务器**:
- clangd (C/C++)
- pylsp (Python)
- ts-language-server (TypeScript/JavaScript)
- gopls (Go)
- rust-analyzer (Rust)

**代码量**: ~800-1000 行  
**复杂度**: ⭐⭐⭐⭐  
**收益**: 很高

---

### 8️⃣ **代码片段支持**

```json
// snippets.json
{
  "for-loop": {
    "prefix": "for",
    "body": [
      "for (int i = 0; i < ${1:count}; i++) {",
      "    ${2:// code}",
      "}"
    ],
    "description": "for 循环"
  }
}
```

```cpp
class SnippetEngine {
    void expandSnippet(const QString& trigger);
    void nextPlaceholder();  // Tab 跳转
    void insertSnippet(const SnippetDefinition& snippet);
};
```

**代码量**: ~400 行  
**复杂度**: ⭐⭐⭐  
**收益**: 中等

---

### 9️⃣ **Git 集成** (基础)

```cpp
class GitManager {
    // 基础 Git 操作
    void status();              // 显示变更
    void commit(const QString& message);
    void push();
    void pull();
    
    // Git Diff
    void showDiff(const QString& file);
    
    // 分支管理
    QStringList getBranches();
    void createBranch(const QString& name);
    void switchBranch(const QString& name);
};

// 集成到 FileTreePanel
// - 文件旁显示 Git 状态 (M = 修改, + = 新增, etc)
// - 右键菜单: Commit, Push, Pull
```

**代码量**: ~600-800 行  
**复杂度**: ⭐⭐⭐⭐  
**收益**: 很高

---

### 🔟 **内嵌终端**

```cpp
class TerminalPanel : public QWidget {
    // 使用 QProcess 或 PTY 库
    QProcess* process;
    QPlainTextEdit* terminalDisplay;
    
    void executeCommand(const QString& cmd);
    void sendInput(const QString& input);
    void resizeTerminal(int cols, int rows);
};
```

```qml
// TerminalPanel.qml
TerminalPanel {
    id: terminal
    Layout.fillWidth: true
    Layout.fillHeight: true
}
```

**代码量**: ~400-600 行  
**复杂度**: ⭐⭐⭐⭐  
**收益**: 很高

---

## 长期规划 (1-3 月)

### 调试器 (DAP)
```cpp
class DebugAdapter {
    // Debug Adapter Protocol
    void launch(const DebugConfig& config);
    void setBreakpoint(const QString& file, int line);
    void step();
    void continue_();
    void getVariables(int frameId);
};
```

### 扩展系统
```cpp
class ExtensionHost {
    void loadExtension(const QString& path);
    void registerCommand(const QString& cmd, Callback cb);
    void registerLanguage(const LanguageDefinition& lang);
};
```

### 测试框架集成
```cpp
class TestRunner {
    void discoverTests();
    void runTests(const QStringList& patterns);
    void debugTest(const QString& testName);
};
```

---

## 🎯 按开发优先级排序

### 优先级 1 - 立即做 (这周)
1. ✅ **Undo/Redo** - 编辑器必需
2. ✅ **全局搜索** - 基本功能
3. ✅ **右键菜单** - 用户体验
4. ✅ **命令面板** - 效率提升

### 优先级 2 - 短期 (2-4 周)
5. ⏳ **快捷键系统** - 定制化需求
6. ⏳ **代码折叠** - 代码导航
7. ⏳ **LSP 集成** - 智能补全
8. ⏳ **代码片段** - 代码生成

### 优先级 3 - 中期 (1-2 月)
9. ⏳ **Git 集成** - 版本控制
10. ⏳ **内嵌终端** - 开发流程
11. ⏳ **调试器** - 调试需求
12. ⏳ **测试集成** - 质量保证

### 优先级 4 - 长期 (2-3 月+)
13. ⏳ **扩展系统** - 生态建设
14. ⏳ **高级搜索** - AI 增强
15. ⏳ **协作编辑** - 多人开发

---

## 📊 实现成本估算

| 功能 | 代码量 | 时间 | 难度 | 优先级 |
|------|-------|------|------|--------|
| Undo/Redo | 300 | 2小时 | ⭐⭐ | 1 |
| 全局搜索 | 700 | 1天 | ⭐⭐⭐ | 1 |
| 右键菜单 | 200 | 3小时 | ⭐⭐ | 1 |
| 命令面板 | 450 | 1天 | ⭐⭐⭐ | 1 |
| 快捷键系统 | 500 | 2天 | ⭐⭐⭐ | 2 |
| 代码折叠 | 450 | 1.5天 | ⭐⭐⭐ | 2 |
| LSP 集成 | 1000 | 3天 | ⭐⭐⭐⭐ | 2 |
| 代码片段 | 400 | 1.5天 | ⭐⭐⭐ | 2 |
| Git 集成 | 700 | 2天 | ⭐⭐⭐⭐ | 3 |
| 内嵌终端 | 500 | 2天 | ⭐⭐⭐⭐ | 3 |
| 调试器 | 1200 | 5天 | ⭐⭐⭐⭐⭐ | 3 |
| 扩展系统 | 800 | 3天 | ⭐⭐⭐⭐ | 4 |
| **总计** | **8,300** | **25天** | | |

---

## 代码复用来源

### 直接复用
- ✅ Qt 官方文档 (编辑器、主题、快捷键)
- ✅ VS Code 源码 (算法、架构)
- ✅ 现有 neurx-code (EditorPanel, FileTreePanel)

### 外部库
- 📦 Qt (UI 框架)
- 📦 libgit2 (Git 操作)
- 📦 Hunspell (拼写检查)
- 📦 Protocol Buffers (LSP 通信)

### 参考实现
- 🔗 VS Code: `/src/vs/workbench/contrib/`
- 🔗 Monaco Editor: 开源编辑器
- 🔗 Qt Creator: IDE 参考

---

## 下一步行动计划

### 📋 本周任务
- [ ] 实现 Undo/Redo
- [ ] 添加全局搜索 UI
- [ ] 实现文件树右键菜单
- [ ] 完成命令面板基础

### 📋 下周任务
- [ ] 集成 grep 搜索引擎
- [ ] 快捷键绑定系统框架
- [ ] 代码折叠识别器
- [ ] LSP 客户端框架

### 📋 2 周后
- [ ] LSP 集成完成
- [ ] 代码片段引擎
- [ ] Git 基础集成
- [ ] 内嵌终端框架

---

**更新时间**: 2026年6月4日  
**作者**: neurx-code 开发团队  
**关联**: VSCODE_FEATURES_ANALYSIS.md
