# VS Code 核心功能实现指南

本指南说明如何集成 4 个新实现的功能到 neurx-code。

## 📦 已创建的文件清单

### 1. Undo/Redo 功能
```
src/editor/EditorHistory.h         (220 行)
src/editor/EditorHistory.cpp       (65 行)
```

**功能说明**:
- 堆栈式 Undo/Redo 实现
- 最多保存 100 个历史状态
- 自动清空 Redo 堆栈（新操作后）
- 信号通知 UI 更新

**信号**:
- `canUndoChanged(bool)` - Undo 可用状态变化
- `canRedoChanged(bool)` - Redo 可用状态变化
- `stateChanged()` - 状态改变

### 2. 全局搜索功能
```
src/search/GlobalSearchEngine.h    (120 行)
src/search/GlobalSearchEngine.cpp  (280 行)
content/SearchPanel.qml            (200 行)
```

**功能说明**:
- 支持正则表达式
- 支持大小写敏感
- 异步搜索执行
- 支持多文件替换
- 自动跳过 `.git`, `node_modules`, `build` 等目录

**搜索 API**:
```cpp
search(pattern, rootPath, useRegex, caseSensitive);
searchInFile(filePath, pattern, useRegex, caseSensitive);
replace(pattern, replacement, rootPath, useRegex);
```

### 3. 命令管理系统
```
src/commands/CommandManager.h      (100 行)
src/commands/CommandManager.cpp    (200 行)
content/CommandPalette.qml         (250 行)
```

**功能说明**:
- 全局单例命令管理器
- 支持快捷键绑定
- 命令搜索过滤
- 支持命令分类

**快捷键**:
- `Ctrl+Shift+P` - 打开命令面板

### 4. 文件树右键菜单
```
content/FileTreeContextMenu.qml    (120 行)
```

**菜单项**:
- 新建文件 (New File)
- 新建文件夹 (New Folder)
- 重命名 (Rename)
- 删除 (Delete)
- 剪切/复制/粘贴
- 复制路径

---

## 🔧 集成步骤

### 第 1 步：更新 CMakeLists.txt

编辑 `/Users/feifei/agent/neurx-code/CMakeLists.txt`，找到源文件列表部分，添加新文件：

```cmake
set(SOURCES
    # ... 现有文件 ...
    
    # Editor 模块
    src/editor/EditorHistory.h
    src/editor/EditorHistory.cpp
    
    # Search 模块
    src/search/GlobalSearchEngine.h
    src/search/GlobalSearchEngine.cpp
    
    # Commands 模块
    src/commands/CommandManager.h
    src/commands/CommandManager.cpp
    
    # ... 其他文件 ...
)
```

### 第 2 步：在 CMakeLists.txt 中包含 QML 文件

```cmake
set(QML_SOURCES
    # ... 现有 QML 文件 ...
    content/SearchPanel.qml
    content/CommandPalette.qml
    content/FileTreeContextMenu.qml
    # ... 其他文件 ...
)
```

### 第 3 步：修改 EditorPanel.qml 集成 Undo/Redo

在 `content/EditorPanel.qml` 中：

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    // ... 现有代码 ...
    
    // 导入 EditorHistory
    property var editorHistory: null
    
    // 添加键盘快捷键处理
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Z && event.modifiers & Qt.ControlModifier) {
            if (editorHistory && editorHistory.canUndo) {
                var state = editorHistory.undo()
                // 更新编辑器内容
                textEdit.text = state.content
                textEdit.cursorPosition = state.cursorPosition
            }
        }
        if (event.key === Qt.Key_Y && event.modifiers & Qt.ControlModifier) {
            if (editorHistory && editorHistory.canRedo) {
                var state = editorHistory.redo()
                textEdit.text = state.content
                textEdit.cursorPosition = state.cursorPosition
            }
        }
    }
    
    // 捕获文本变化（防抖 500ms）
    TextEdit {
        id: textEdit
        // ... 现有编辑器配置 ...
        
        onTextChanged: {
            historyDebounceTimer.restart()
        }
    }
    
    Timer {
        id: historyDebounceTimer
        interval: 500
        
        onTriggered: {
            if (editorHistory) {
                editorHistory.pushState({
                    content: textEdit.text,
                    cursorPosition: textEdit.cursorPosition,
                    selectionStart: textEdit.selectionStart,
                    selectionEnd: textEdit.selectionEnd
                })
            }
        }
    }
}
```

### 第 4 步：修改 MainWindow.qml 集成搜索和命令面板

在 `content/MainWindow.qml` 中（或主容器）：

```qml
Rectangle {
    id: mainWindow
    
    // ... 现有代码 ...
    
    // 导入新组件
    SearchPanel {
        id: searchPanel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        
        onSearch: (pattern, useRegex, caseSensitive) => {
            // 连接到 GlobalSearchEngine
            searchEngine.search(pattern, projectRoot, useRegex, caseSensitive)
        }
    }
    
    CommandPalette {
        id: commandPalette
        
        Component.onCompleted: {
            // 从 CommandManager 加载命令
            setCommands(commandManager.getAllCommands())
        }
        
        onCommandSelected: (commandId) => {
            commandManager.executeCommand(commandId)
        }
    }
    
    // 快捷键 Ctrl+Shift+F 打开搜索
    Shortcut {
        sequence: "Ctrl+Shift+F"
        onActivated: searchPanel.isVisible = !searchPanel.isVisible
    }
    
    // 快捷键 Ctrl+Shift+P 打开命令面板
    Shortcut {
        sequence: "Ctrl+Shift+P"
        onActivated: commandPalette.show()
    }
}
```

### 第 5 步：修改 FileTreeItem.qml 集成右键菜单

在 `content/FileTreeItem.qml` 中：

```qml
Item {
    id: treeItem
    
    // ... 现有代码 ...
    
    // 导入上下文菜单
    FileTreeContextMenu {
        id: contextMenu
        
        onNewFile: {
            // 实现新建文件
            console.log("Create new file in:", contextMenu.targetPath)
        }
        
        onNewFolder: {
            console.log("Create new folder in:", contextMenu.targetPath)
        }
        
        onDelete: {
            console.log("Delete:", contextMenu.targetPath)
        }
        
        onRename: {
            console.log("Rename:", contextMenu.targetPath)
        }
    }
    
    // 右键点击处理
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.targetPath = model.filePath
                contextMenu.isDirectory = model.isDirectory
                contextMenu.popup()
            }
        }
    }
}
```

### 第 6 步：在 C++ 中初始化组件

编辑 `src/main.cpp` 或相应的主程序文件：

```cpp
#include "editor/EditorHistory.h"
#include "search/GlobalSearchEngine.h"
#include "commands/CommandManager.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    
    // 创建核心管理器
    auto* editorHistory = new EditorHistory();
    auto* searchEngine = new GlobalSearchEngine();
    auto* commandManager = CommandManager::instance();
    
    // 注册基础命令
    commandManager->registerCommand({
        "editor.action.undo",
        "Undo",
        "Editor",
        "Ctrl+Z",
        "Undo last change",
        [editorHistory]() {
            editorHistory->undo();
            return true;
        }
    });
    
    commandManager->registerCommand({
        "editor.action.redo",
        "Redo",
        "Editor",
        "Ctrl+Y",
        "Redo last change",
        [editorHistory]() {
            editorHistory->redo();
            return true;
        }
    });
    
    // ... 注册其他命令 ...
    
    // 创建 QML 引擎
    QQmlApplicationEngine engine;
    
    // 暴露对象到 QML
    engine.rootContext()->setContextProperty("editorHistory", editorHistory);
    engine.rootContext()->setContextProperty("searchEngine", searchEngine);
    engine.rootContext()->setContextProperty("commandManager", commandManager);
    
    const QUrl url(QStringLiteral("qrc:/content/main.qml"));
    engine.load(url);
    
    if (engine.rootObjects().isEmpty())
        return -1;
    
    return app.exec();
}
```

---

## 🚀 编译和运行

### 编译
```bash
cd /Users/feifei/agent/neurx-code/build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j8
```

### 运行
```bash
./neurx-code
```

---

## ✅ 验证清单

- [ ] CMakeLists.txt 已更新，包含所有新文件
- [ ] 编译成功，无错误或警告
- [ ] Ctrl+Z / Ctrl+Y 快捷键生效
- [ ] Ctrl+Shift+F 打开搜索面板
- [ ] Ctrl+Shift+P 打开命令面板
- [ ] 文件树右键菜单正常显示
- [ ] 搜索功能能正确查找文件
- [ ] 命令面板能搜索和执行命令

---

## 📝 下一步建议

1. **优化搜索**
   - 添加搜索结果高亮
   - 实现搜索历史
   - 支持搜索配置保存

2. **增强命令系统**
   - 添加更多内置命令
   - 实现命令快捷键自定义
   - 添加命令历史

3. **完善菜单**
   - 实现完整的文件操作
   - 添加拖放支持
   - 实现文件模板

4. **集成更多功能**
   - Git 集成
   - LSP 支持
   - 代码片段
   - 调试器

---

## 🐛 故障排除

### 编译错误

**问题**: `EditorHistory not found`
- **解决**: 检查 CMakeLists.txt 中的包含路径

**问题**: `GlobalSearchEngine undefined reference`
- **解决**: 确保 cpp 文件在编译列表中

### 运行错误

**问题**: QML 导入失败
- **解决**: 检查 QML 文件路径和 qmldir

**问题**: 快捷键不生效
- **解决**: 确保快捷键在顶级容器中定义

---

## 💡 学习资源

- Qt 官方文档: https://doc.qt.io/
- QML 快速指南: https://doc.qt.io/qt-6/qmlbook/index.html
- C++ 信号槽: https://doc.qt.io/qt-6/signalsandslots.html
- CMake 构建: https://cmake.org/cmake/help/latest/

---

**版本**: 1.0  
**日期**: 2026年6月4日  
**作者**: VS Code 功能实现
