# NeurX-Code Editor File Synchronization Integration

## 实现概述

当编辑的文件在外部被修改时（例如通过 WriteTool 或其他工具），编辑器会自动同步更新内容。

## 集成步骤

### 1. AgentController.h 中的添加

```cpp
#pragma once

// 在包含头部添加
#include "editor/FileWatcher.h"

class AgentController : public QObject {
    Q_OBJECT
    // ... 现有代码 ...

private slots:
    // 当监听的文件被外部修改时
    void onWatchedFileModified(const QString &filePath);
    
private:
    FileWatcher *m_fileWatcher;
};
```

### 2. AgentController.cpp 中的实现

```cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
    // ... 现有初始化 ...
{
    // 初始化文件监听
    m_fileWatcher = new FileWatcher(this);
    
    // 连接文件修改信号
    connect(m_fileWatcher, &FileWatcher::fileModified,
            this, &AgentController::onWatchedFileModified);
}

void AgentController::onOpenFileRequested(const QString &filePath)
{
    // 打开文件的现有代码...
    m_currentFilePath = filePath;
    
    // 开始监听这个文件
    m_fileWatcher->watchFile(filePath);
    
    // ... 加载文件内容 ...
}

void AgentController::onWatchedFileModified(const QString &filePath)
{
    // 只在当前打开的文件被修改时更新
    if (filePath == m_currentFilePath) {
        // 从磁盘重新加载文件内容
        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = QString::fromUtf8(file.readAll());
            file.close();
            
            // 更新内容（会触发 currentFileContentChanged 信号）
            if (content != m_currentFileContent) {
                m_currentFileContent = content;
                emit currentFileContentChanged();
                
                qDebug() << "[AgentController] File updated from disk:" << filePath;
            }
        }
    }
}

void AgentController::setCurrentFilePath(const QString &newPath)
{
    if (m_currentFilePath != newPath) {
        // 停止监听旧文件
        if (!m_currentFilePath.isEmpty()) {
            m_fileWatcher->unwatchFile(m_currentFilePath);
        }
        
        m_currentFilePath = newPath;
        emit currentFilePathChanged();
        
        // 开始监听新文件
        if (!newPath.isEmpty()) {
            m_fileWatcher->watchFile(newPath);
        }
    }
}

void AgentController::setWorkspacePath(const QString &newPath)
{
    if (m_workspacePath != newPath) {
        // 停止监听旧工作空间
        m_fileWatcher->clear();
        
        m_workspacePath = newPath;
        emit workspacePathChanged();
        
        // 监听新工作空间（可选：递归监听所有文件）
        // 注意：这可能会很消耗资源，建议只监听当前打开的文件
    }
}
```

### 3. EditorPanel.qml 中的增强

EditorPanel 中已经有了自动同步机制：

```qml
Connections {
    target: agent
    
    // 当文件路径改变时（例如打开新文件）
    function onCurrentFilePathChanged() { 
        root.syncFromAgent(true)  // 从 agent 重新加载内容
    }
    
    // 当文件内容改变时（例如外部修改被加载）
    function onCurrentFileContentChanged() { 
        root.syncFromAgent()  // 同步编辑器显示
    }
    
    // 当打开的文件列表改变时
    function onOpenFilesChanged() {
        if (agent.currentFilePath)
            root.syncFromAgent()
    }
}
```

## 工作流程

1. **用户打开文件**
   ```
   User → Agent.openFile(path) → FileWatcher.watchFile(path) → Editor displays content
   ```

2. **外部修改文件（例如 WriteTool）**
   ```
   WriteTool → writes to disk → FileWatcher detects change
   ```

3. **编辑器自动同步**
   ```
   FileWatcher detects → onWatchedFileModified() → reload content from disk
   → update Agent.currentFileContent → sync EditorPanel.qml → Editor shows new content
   ```

## 功能特性

✓ **实时监听** - 立即检测文件系统变化
✓ **防抖动** - 500ms 防抖，避免多次重复加载
✓ **路径安全** - 验证文件存在和权限
✓ **递归监听** - 支持目录级别的递归监听（可选）
✓ **自动缓存** - 追踪文件修改时间，避免重复更新
✓ **错误处理** - 完整的异常处理和日志记录

## 配置选项

在 AgentController 中可配置：

```cpp
// 修改防抖时间（毫秒）
m_fileWatcher->setDebounceInterval(1000);  // 改为 1 秒

// 启用/禁用特定文件的监听
m_fileWatcher->watchFile(filePath);
m_fileWatcher->unwatchFile(filePath);

// 监听整个目录（谨慎使用，可能性能影响）
m_fileWatcher->watchDirectory(dirPath, true);
```

## 性能考虑

- **单个文件监听** - 极小资源占用（推荐）
- **多文件监听** - 为每个打开的文件启用监听
- **目录监听** - 仅在必要时启用，监听深层目录可能影响性能

## 测试验证

```bash
# 1. 打开 hello.cc 在编辑器中
# 2. 运行 WriteTool 或其他工具修改 hello.cc
# 3. 编辑器应该自动显示更新的内容

# 示例测试：
cat >> /path/to/file.cc << 'EOF'
// Added by external tool
EOF

# 编辑器应该立即显示新内容
```

## 未来增强

- [ ] 配置文件排除模式（例如排除 .git）
- [ ] 支持文件重命名检测
- [ ] 支持新建文件检测
- [ ] 与版本控制集成
- [ ] 冲突检测（编辑器有改动且文件被外部修改时的提示）
