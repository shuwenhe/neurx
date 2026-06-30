# VS Code 服务 QML 使用指南

## 快速开始

所有 VS Code 服务现已集成到 `AgentController` 中，可直接从 QML 调用。

## 通知示例

```qml
import QtQuick
import Agent

AgentView {
    function showNotification() {
        let notifId = controller.notifyInfo("操作完成")
        // controller.notifyWarning("警告")
        // controller.notifyError("错误")
        // controller.notifySuccess("成功")
        
        // 手动关闭（可选）
        controller.dismissNotification(notifId)
    }
}
```

## 进度跟踪示例

```qml
function performLongOperation() {
    let progId = controller.startProgress("正在搜索文件...")
    
    // 模拟操作进度
    for (let i = 0; i <= 100; i += 10) {
        controller.updateProgress(progId, i)
        // 实际操作...
    }
    
    controller.finishProgress(progId)
}
```

## 快速访问（命令面板）示例

```qml
ListView {
    model: controller.searchQuickAccess(searchText)
    
    delegate: ItemDelegate {
        text: model.label
        onClicked: {
            controller.executeQuickAccessItem(model.id)
        }
    }
}
```

## 搜索示例

```qml
Button {
    text: "搜索 TODO"
    onClicked: {
        let results = controller.performSearch("TODO", false)
        console.log("找到 " + results.length + " 个结果")
        
        // results[i] 包含: file, line, column, matchText, lineText
        for (let i = 0; i < results.length; i++) {
            console.log(results[i].file + ":" + results[i].line)
        }
    }
}
```

## Git 示例

```qml
Button {
    text: "提交更改"
    onClicked: {
        // 获取状态
        let status = controller.getGitStatus()
        console.log("Git 状态:", status)
        
        // 获取当前分支
        let branch = controller.getCurrentGitBranch()
        console.log("当前分支:", branch)
        
        // 提交
        if (controller.commitGitChanges("Initial commit")) {
            console.log("提交成功")
            // 推送
            if (controller.pushToGit("origin")) {
                console.log("推送成功")
            }
        }
    }
}
```

## 任务执行示例

```qml
Button {
    text: "运行构建任务"
    onClicked: {
        let execId = controller.executeTask("build-task")
        console.log("任务执行 ID:", execId)
        
        // 稍后获取输出
        let output = controller.getTaskOutput(execId)
        console.log("任务输出:", output)
        
        // 如需中止
        // controller.terminateTask(execId)
    }
}
```

## 终端示例

```qml
Button {
    text: "创建终端"
    onClicked: {
        let termId = controller.createTerminal("Build Terminal")
        
        // 发送命令
        controller.sendTerminalCommand(termId, "make build")
        controller.sendTerminalCommand(termId, "npm start")
        
        // 关闭终端
        // controller.closeTerminal(termId)
    }
}
```

## 调试示例

```qml
Button {
    text: "启动调试"
    onClicked: {
        let sessionId = controller.startDebugSession("cpp-gdb")
        console.log("调试会话:", sessionId)
        
        // 控制调试流程
        // controller.debugPause(sessionId)
        // controller.debugContinue(sessionId)
        
        // 停止调试
        // controller.stopDebugSession(sessionId)
    }
}
```

## 文件和工作区示例

```qml
Button {
    text: "搜索 TypeScript 文件"
    onClicked: {
        let files = controller.findFilesInWorkspace("**/*.ts")
        console.log("找到 " + files.length + " 个 TS 文件")
    }
}

Button {
    text: "获取最近文件"
    onClicked: {
        let recent = controller.getRecentFiles(10)
        console.log("最近打开:", recent)
    }
}
```

## 语言服务器集成示例

```qml
Button {
    text: "注册 Rust LSP"
    onClicked: {
        controller.registerLanguageServer("rust", "/usr/bin/rust-analyzer")
        controller.notifySuccess("Rust 语言服务已注册")
    }
}
```

## 组合使用示例

```qml
Button {
    text: "完整工作流"
    onClicked: {
        // 1. 通知开始
        controller.notifyInfo("开始处理文件...")
        
        // 2. 显示进度
        let progId = controller.startProgress("正在处理...")
        
        // 3. 搜索文件
        let results = controller.performSearch("console.log", false)
        controller.updateProgress(progId, 50)
        
        // 4. Git 提交
        if (results.length > 0) {
            controller.commitGitChanges("Refactor: remove debug logs")
            controller.pushToGit("origin")
            controller.updateProgress(progId, 100)
        }
        
        // 5. 完成通知
        controller.finishProgress(progId)
        controller.notifySuccess("处理完成！")
    }
}
```

## 错误处理

```qml
function safeGitOperation() {
    let branch = controller.getCurrentGitBranch()
    if (branch === "") {
        controller.notifyError("未检测到 Git 仓库")
        return false
    }
    
    if (controller.commitGitChanges("Auto-commit")) {
        controller.notifySuccess("提交成功")
        return true
    } else {
        controller.notifyError("提交失败")
        return false
    }
}
```

## 性能提示

1. **搜索** - 对大型工作区使用正则表达式过滤
2. **进度** - 每 100ms 更新一次进度，避免过于频繁的更新
3. **Git** - 在后台线程执行长操作
4. **终端** - 使用异步命令避免阻塞 UI

## 兼容性

- ✅ Qt 6.0+
- ✅ QML 2.15+
- ✅ 所有方法都是 `Q_INVOKABLE`
- ✅ 支持信号/槽机制

---

**提示**: 所有方法都能从 QML 直接调用，无需额外的 C++ 包装。
