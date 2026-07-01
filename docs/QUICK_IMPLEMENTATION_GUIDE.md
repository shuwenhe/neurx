# neurx-code VS Code 功能快速实现指南

## 🚀 立即开始 - 5 分钟设置

### 1. 项目结构
```
neurx-code/
├── src/
│   ├── filesystem/          ✅ 文件系统 (已完成)
│   ├── tools/               ✅ 工具集
│   ├── editor/              ⏳ 编辑器增强 (新增)
│   ├── search/              ⏳ 搜索功能 (新增)
│   └── commands/            ⏳ 命令系统 (新增)
├── content/
│   ├── EditorPanel.qml      ✅ 基础编辑器
│   ├── FileTreePanel.qml    ✅ 文件树
│   ├── SearchPanel.qml      ⏳ 搜索面板 (新增)
│   ├── CommandPalette.qml   ⏳ 命令面板 (新增)
│   └── TerminalPanel.qml    ⏳ 终端 (新增)
└── docs/
    ├── VSCODE_FEATURES_ANALYSIS.md
    ├── IMPLEMENTATION_ROADMAP.md
    └── THIS_FILE
```

---

## 🔧 第一个功能: Undo/Redo

### 第 1 步: 创建历史管理器

**文件**: `src/editor/EditorHistory.h`

```cpp
#pragma once

#include <QObject>
#include <QStack>
#include <QString>

struct EditorState {
    QString content;
    int cursorPosition;
    int selectionStart;
    int selectionEnd;
};

class EditorHistory : public QObject {
    Q_OBJECT

public:
    explicit EditorHistory(QObject* parent = nullptr);
    
    // 记录状态变化
    void pushState(const EditorState& state);
    
    // Undo/Redo 操作
    bool canUndo() const;
    bool canRedo() const;
    EditorState undo();
    EditorState redo();
    
    // 清空历史
    void clear();
    
    // 配置最大历史条目数
    void setMaxHistorySize(int size) { m_maxSize = size; }

signals:
    void canUndoChanged(bool canUndo);
    void canRedoChanged(bool canRedo);

private:
    QStack<EditorState> m_undoStack;
    QStack<EditorState> m_redoStack;
    int m_maxSize = 100;
};
```

**文件**: `src/editor/EditorHistory.cpp`

```cpp
#include "editor/EditorHistory.h"

EditorHistory::EditorHistory(QObject* parent)
    : QObject(parent)
{
}

void EditorHistory::pushState(const EditorState& state)
{
    // 新操作后清空 redo 栈
    m_redoStack.clear();
    
    // 控制栈大小
    if (m_undoStack.size() >= m_maxSize) {
        m_undoStack.removeFirst();
    }
    
    m_undoStack.push(state);
    emit canUndoChanged(true);
    emit canRedoChanged(false);
}

bool EditorHistory::canUndo() const
{
    return !m_undoStack.isEmpty();
}

bool EditorHistory::canRedo() const
{
    return !m_redoStack.isEmpty();
}

EditorState EditorHistory::undo()
{
    if (!canUndo()) {
        return EditorState();
    }
    
    EditorState state = m_undoStack.pop();
    emit canUndoChanged(canUndo());
    emit canRedoChanged(true);
    return state;
}

EditorState EditorHistory::redo()
{
    if (!canRedo()) {
        return EditorState();
    }
    
    EditorState state = m_redoStack.pop();
    emit canRedoChanged(canRedo());
    emit canUndoChanged(true);
    return state;
}

void EditorHistory::clear()
{
    m_undoStack.clear();
    m_redoStack.clear();
}
```

### 第 2 步: 集成到 EditorPanel

**修改**: `content/EditorPanel.qml`

```qml
import QtQuick
import QtQuick.Controls
import NeurXCode

Rectangle {
    id: root
    
    // ... 现有代码 ...
    
    // 快捷键处理
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Z && event.modifiers & Qt.ControlModifier) {
            editorHistory.undo()
            event.accepted = true
        }
        else if (event.key === Qt.Key_Y && event.modifiers & Qt.ControlModifier) {
            editorHistory.redo()
            event.accepted = true
        }
    }
    
    TextEdit {
        id: textEdit
        onTextChanged: {
            // 延迟保存状态（避免每个字符都保存）
            saveStateTimer.restart()
        }
    }
    
    Timer {
        id: saveStateTimer
        interval: 500
        onTriggered: {
            editorHistory.pushState({
                content: textEdit.text,
                cursorPosition: textEdit.cursorPosition,
                selectionStart: textEdit.selectionStart,
                selectionEnd: textEdit.selectionEnd
            })
        }
    }
}
```

### 第 3 步: 在 C++ 中连接

**修改**: `src/bridge/AgentController.cpp`

```cpp
#include "editor/EditorHistory.h"

class AgentController {
private:
    EditorHistory* m_editorHistory = nullptr;

public:
    void init() {
        // ... 现有初始化 ...
        
        // 创建历史管理器
        m_editorHistory = new EditorHistory(this);
        
        // 暴露给 QML
        rootContext()->setContextProperty("editorHistory", m_editorHistory);
    }
};
```

---

## 🔎 第二个功能: 全局搜索

### 第 1 步: 搜索引擎

**文件**: `src/search/GlobalSearchEngine.h`

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QList>

struct SearchResult {
    QString filePath;
    int lineNumber;
    int columnNumber;
    QString lineContent;
    int matchStart;
    int matchLength;
};

class GlobalSearchEngine : public QObject {
    Q_OBJECT

public:
    explicit GlobalSearchEngine(QObject* parent = nullptr);
    
    // 执行搜索
    void search(const QString& pattern, const QString& rootPath, 
                bool useRegex = false, bool caseSensitive = false);
    
    // 替换
    void replace(const QString& pattern, const QString& replacement,
                 const QString& rootPath);

signals:
    void resultsFound(const QList<SearchResult>& results);
    void searchFinished();
    void error(const QString& message);

private:
    void searchInFile(const QString& filePath, const QString& pattern,
                      bool useRegex, bool caseSensitive,
                      QList<SearchResult>& results);
};
```

### 第 2 步: SearchPanel QML

**文件**: `content/SearchPanel.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: Theme.backgroundColor
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        
        // 搜索输入
        RowLayout {
            Layout.fillWidth: true
            
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "搜索..."
                onTextChanged: {
                    if (text.length > 2) {
                        searchEngine.search(text, agent.workspacePath)
                    }
                }
            }
            
            Button {
                text: "匹配大小写"
                checkable: true
            }
            
            Button {
                text: "正则表达式"
                checkable: true
            }
        }
        
        // 搜索结果
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            model: searchResults
            
            delegate: Rectangle {
                width: resultsList.width
                height: 50
                color: index % 2 ? Theme.altBackgroundColor : Theme.backgroundColor
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    
                    Text {
                        text: modelData.filePath
                        color: Theme.textColor
                    }
                    
                    Text {
                        text: `Line ${modelData.lineNumber}: ${modelData.lineContent}`
                        color: Theme.accentColor
                        font.family: "monospace"
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        agent.openFile(modelData.filePath, modelData.lineNumber)
                    }
                }
            }
        }
        
        // 替换区域
        RowLayout {
            Layout.fillWidth: true
            
            TextField {
                id: replaceField
                Layout.fillWidth: true
                placeholderText: "替换为..."
            }
            
            Button {
                text: "替换"
                onClicked: {
                    searchEngine.replace(searchField.text, replaceField.text,
                                       agent.workspacePath)
                }
            }
            
            Button {
                text: "替换全部"
                onClicked: {
                    searchEngine.replace(searchField.text, replaceField.text,
                                       agent.workspacePath)
                }
            }
        }
    }
}
```

---

## ⌨️ 第三个功能: 命令面板

### 第 1 步: 命令管理器

**文件**: `src/commands/CommandManager.h`

```cpp
#pragma once

#include <QObject>
#include <QMap>
#include <functional>

struct Command {
    QString id;
    QString title;
    QString category;
    QString keybinding;
    QString description;
    std::function<void()> handler;
};

class CommandManager : public QObject {
    Q_OBJECT

public:
    explicit CommandManager(QObject* parent = nullptr);
    
    // 注册命令
    void registerCommand(const Command& cmd);
    
    // 执行命令
    void executeCommand(const QString& id);
    
    // 获取所有命令
    QList<Command> getAllCommands() const;
    
    // 搜索命令
    QList<Command> searchCommands(const QString& query) const;

signals:
    void commandExecuted(const QString& id);

private:
    QMap<QString, Command> m_commands;
};
```

### 第 2 步: CommandPalette QML

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: palette
    width: 600
    height: 400
    
    ColumnLayout {
        anchors.fill: parent
        
        TextField {
            id: commandInput
            Layout.fillWidth: true
            placeholderText: "输入命令..."
            focus: true
            
            onTextChanged: {
                filteredCommands = commandManager.searchCommands(text)
            }
        }
        
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            model: filteredCommands
            
            delegate: Rectangle {
                width: parent.width
                height: 40
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        commandManager.executeCommand(modelData.id)
                        palette.close()
                    }
                }
                
                Text {
                    text: modelData.title + " (" + modelData.keybinding + ")"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                }
            }
        }
    }
}
```

---

## 📋 快速集成清单

### ✅ 今日任务
- [ ] 创建 `EditorHistory.h/cpp`
- [ ] 修改 `EditorPanel.qml` 集成 Undo/Redo
- [ ] 连接快捷键 (Ctrl+Z, Ctrl+Y)
- [ ] 测试基本功能

### ✅ 明日任务
- [ ] 创建 `GlobalSearchEngine.h/cpp`
- [ ] 创建 `SearchPanel.qml`
- [ ] 集成 grep 搜索
- [ ] 实现搜索结果导航

### ✅ 本周任务
- [ ] 创建 `CommandManager.h/cpp`
- [ ] 创建 `CommandPalette.qml`
- [ ] 注册基础命令
- [ ] Ctrl+Shift+P 快捷键

---

## 🔗 文件树右键菜单实现

**修改**: `content/FileTreeItem.qml`

```qml
Rectangle {
    id: item
    width: parent.width
    height: 30
    
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            }
        }
    }
    
    Menu {
        id: contextMenu
        
        MenuItem {
            text: "新建文件"
            onTriggered: createFile(item.filePath)
        }
        
        MenuItem {
            text: "新建文件夹"
            onTriggered: createFolder(item.filePath)
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "删除"
            onTriggered: deleteFile(item.filePath)
        }
        
        MenuItem {
            text: "重命名"
            onTriggered: startRename(item.filePath)
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "复制路径"
            onTriggered: copyToClipboard(item.filePath)
        }
    }
}
```

---

## 🎯 代码折叠实现概览

**文件**: `src/editor/CodeFolder.h`

```cpp
struct FoldRegion {
    int startLine;
    int endLine;
    QString type;  // "function", "class", "if", "for", etc
    bool isFolded = false;
};

class CodeFolder {
public:
    QVector<FoldRegion> detectFolds(const QString& code);
    QString foldCode(const QString& code, const FoldRegion& region);
    QString unfoldCode(const QString& code, const FoldRegion& region);
};
```

---

## 📚 学习资源

### Qt 相关
- [Qt QML 官方文档](https://doc.qt.io/qt-6/qml-index.html)
- [Qt C++ API](https://doc.qt.io/qt-6/classes.html)
- [Qt Creator 示例](https://doc.qt.io/qtcreator/creator-examples.html)

### VS Code 相关
- [VS Code 文档](https://code.visualstudio.com/docs)
- [VS Code 扩展 API](https://code.visualstudio.com/api)
- [VS Code 源码](https://github.com/microsoft/vscode)

### 相关技术
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
- [Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)

---

## 🚀 执行步骤

### 第 1 天: Undo/Redo
```bash
1. 创建 EditorHistory.h/cpp (200 行)
2. 修改 EditorPanel.qml (100 行)
3. 修改 AgentController.cpp (20 行)
4. 测试快捷键
预计时间: 2-3 小时
```

### 第 2 天: 全局搜索
```bash
1. 创建 GlobalSearchEngine.h/cpp (300 行)
2. 创建 SearchPanel.qml (400 行)
3. 集成到 App.qml (50 行)
4. 测试搜索功能
预计时间: 4-5 小时
```

### 第 3 天: 命令面板
```bash
1. 创建 CommandManager.h/cpp (200 行)
2. 创建 CommandPalette.qml (250 行)
3. 注册基础命令 (100 行)
4. 集成快捷键
预计时间: 3-4 小时
```

---

## ✨ 总结

**可在本周完成**:
- ✅ Undo/Redo (编辑器必需)
- ✅ 全局搜索 (基本功能)  
- ✅ 命令面板 (效率工具)
- ✅ 右键菜单 (用户体验)

**预计代码新增**: ~1,500 行  
**预计时间**: 1-2 周

---

**版本**: 1.0  
**更新**: 2026年6月4日  
**下一个指南**: `ADVANCED_FEATURES.md` (LSP, 调试器, Git)
