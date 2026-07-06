# Claude 标准工具系统 - 快速开始

**5 分钟快速集成指南**

---

## 🎯 三步集成

### 步骤 1: 添加到构建系统

在 `CMakeLists.txt` 中添加：

```cmake
# 在 add_library 或 add_executable 的源文件列表中添加
src/tools/ClaudeStandardTools.cpp
```

### 步骤 2: 注册工具

在你的初始化代码中（如 `AgentController::initialize()`）：

```cpp
#include "tools/ClaudeStandardTools.h"

// 一键注册所有 7 个标准工具
ClaudeStandardToolFactory::registerAllTools(
    workspaceRoot,      // QString: 工作空间路径
    m_toolRegistry,     // CoreToolRegistry*: 工具注册表
    m_sandboxManager    // SandboxManager*: 可选，Sandbox 管理器
);
```

### 步骤 3: 在 LLM 提示词中添加工具说明

```cpp
QString systemPrompt = R"(
You are an AI coding assistant with access to these tools:

**File Operations:**
- Write: Create/overwrite files (file_path, new_text)
- Edit: Modify files by text replacement (file_path, old_text, new_text)
- MultiEdit: Apply multiple edits to one file (file_path, edits[])
- Read: Read file contents (file_path, start_line?, end_line?)

**System Operations:**
- Bash: Execute shell commands (command, timeout?)

**Search Operations:**
- Grep: Search for patterns (pattern, path?, case_sensitive?, max_results?)
- Glob: List files matching pattern (pattern, include_hidden?, max_results?)

When you need to use a tool, respond with JSON:
```json
{
  "tool": "ToolName",
  "parameters": {
    "param1": "value1"
  }
}
```
)";
```

---

## 🚀 使用示例

### 示例 1: 创建文件

**用户输入**: "创建一个 C++ 类 MyClass"

**LLM 生成**:
```json
{
  "tool": "Write",
  "parameters": {
    "file_path": "src/MyClass.h",
    "new_text": "#pragma once\n\nclass MyClass {\npublic:\n    MyClass();\n};\n"
  }
}
```

**执行代码**:
```cpp
BaseTool* tool = m_toolRegistry->findTool("Write");
QJsonObject params;
params["file_path"] = "src/MyClass.h";
params["new_text"] = "#pragma once\n\nclass MyClass {\npublic:\n    MyClass();\n};\n";

ToolResult result = tool->execute("call-123", params);
// result.content: "Created/Updated file: src/MyClass.h (50 bytes)"
```

### 示例 2: 编辑文件

**用户输入**: "在 main.cpp 添加日志输出"

**LLM 执行流程**:
```cpp
// 1. 读取文件
tool = findTool("Read");
result = tool->execute("call-1", {{"file_path", "src/main.cpp"}});

// 2. 编辑文件
tool = findTool("Edit");
result = tool->execute("call-2", {
    {"file_path", "src/main.cpp"},
    {"old_text", "int main() {\n    return 0;\n}"},
    {"new_text", "int main() {\n    qDebug() << \"Started\";\n    return 0;\n}"}
});
```

### 示例 3: 批量操作

**用户输入**: "更新版本号和调试标志"

**LLM 生成**:
```json
{
  "tool": "MultiEdit",
  "parameters": {
    "file_path": "src/config.h",
    "edits": [
      {
        "old_text": "#define VERSION \"1.0.0\"",
        "new_text": "#define VERSION \"1.1.0\""
      },
      {
        "old_text": "#define DEBUG 0",
        "new_text": "#define DEBUG 1"
      }
    ]
  }
}
```

### 示例 4: 搜索代码

**用户输入**: "查找所有使用 qDebug 的地方"

**LLM 生成**:
```json
{
  "tool": "Grep",
  "parameters": {
    "pattern": "qDebug\\(",
    "path": "src/",
    "case_sensitive": false,
    "max_results": 50
  }
}
```

---

## 📊 可用工具一览

| 工具 | 功能 | 主要参数 | 返回 |
|------|------|----------|------|
| **Write** | 创建/覆盖文件 | `file_path`, `new_text` | 创建消息 |
| **Edit** | 替换文本 | `file_path`, `old_text`, `new_text` | 编辑消息 |
| **MultiEdit** | 批量编辑 | `file_path`, `edits[]` | 编辑统计 |
| **Read** | 读取文件 | `file_path`, `start_line?`, `end_line?` | 文件内容 |
| **Bash** | 执行命令 | `command`, `timeout?` | 命令输出 |
| **Grep** | 搜索模式 | `pattern`, `path?` | 匹配列表 |
| **Glob** | 列出文件 | `pattern` | 文件列表 |

---

## 🔧 完整集成示例

```cpp
// AgentController.cpp

#include "tools/ClaudeStandardTools.h"

void AgentController::initialize()
{
    // 创建工具注册表
    m_toolRegistry = new DefaultToolRegistry(this);
    
    // 创建 Sandbox 管理器
    m_sandboxManager = new SandboxManager(this);
    m_sandboxManager->allow(m_workspaceRoot, FileSystemAccessMode::ReadWrite);
    
    // 注册 Claude 标准工具
    ClaudeStandardToolFactory::registerAllTools(
        m_workspaceRoot,
        m_toolRegistry,
        m_sandboxManager
    );
    
    qDebug() << "Registered tools:" << m_toolRegistry->listTools();
}

void AgentController::handleLLMResponse(const QString& response)
{
    // 解析 LLM 返回的工具调用
    QJsonObject toolCall = parseToolCallFromResponse(response);
    
    if (toolCall.isEmpty()) {
        // 不是工具调用，是普通回复
        emit messageReceived(response);
        return;
    }
    
    // 执行工具调用
    QString toolName = toolCall["tool"].toString();
    QJsonObject params = toolCall["parameters"].toObject();
    
    BaseTool* tool = m_toolRegistry->findTool(toolName);
    if (!tool) {
        emit errorOccurred("Tool not found: " + toolName);
        return;
    }
    
    // 执行
    QString callId = generateCallId();
    ToolResult result = tool->execute(callId, params);
    
    // 处理结果
    if (result.isError) {
        emit toolExecutionFailed(callId, result.content);
    } else {
        emit toolExecutionSucceeded(callId, result.content);
        
        // 将结果返回给 LLM 继续对话
        appendToolResultToConversation(result);
        continueLLMConversation();
    }
}

QJsonObject AgentController::parseToolCallFromResponse(const QString& response)
{
    // 简单的 JSON 提取（实际可能需要更复杂的解析）
    QRegularExpression jsonRegex(R"(\{[^{}]*"tool"[^{}]*\})");
    QRegularExpressionMatch match = jsonRegex.match(response);
    
    if (match.hasMatch()) {
        QString jsonStr = match.captured(0);
        QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
        return doc.object();
    }
    
    return QJsonObject();
}
```

---

## 🎨 QML 集成示例

```qml
// AgentView.qml

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    
    property var agentController
    
    Column {
        anchors.fill: parent
        spacing: 10
        
        // 用户输入
        TextField {
            id: userInput
            width: parent.width
            placeholderText: "输入你的指令..."
            
            onAccepted: {
                agentController.sendMessage(text)
                text = ""
            }
        }
        
        // 工具执行反馈
        ListView {
            id: toolExecutionList
            width: parent.width
            height: parent.height - userInput.height - 20
            
            model: ListModel {
                id: toolExecutionModel
            }
            
            delegate: Rectangle {
                width: parent.width
                height: 60
                color: model.isError ? "#ffe0e0" : "#e0ffe0"
                
                Column {
                    anchors.fill: parent
                    padding: 5
                    
                    Text {
                        text: "Tool: " + model.toolName
                        font.bold: true
                    }
                    
                    Text {
                        text: model.result
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }
        }
    }
    
    Connections {
        target: agentController
        
        function onToolExecutionSucceeded(callId, result) {
            toolExecutionModel.append({
                toolName: getTool NameFromCallId(callId),
                result: result,
                isError: false
            })
        }
        
        function onToolExecutionFailed(callId, error) {
            toolExecutionModel.append({
                toolName: getToolNameFromCallId(callId),
                result: error,
                isError: true
            })
        }
    }
}
```

---

## ✅ 验证安装

运行这段代码验证工具已正确安装：

```cpp
void testClaudeStandardTools()
{
    // 创建测试环境
    QString testWorkspace = QDir::tempPath() + "/neurx_test";
    QDir().mkpath(testWorkspace);
    
    auto registry = new DefaultToolRegistry();
    ClaudeStandardToolFactory::registerAllTools(testWorkspace, registry, nullptr);
    
    // 测试 Write 工具
    BaseTool* writeTool = registry->findTool("Write");
    QJsonObject writeParams;
    writeParams["file_path"] = "test.txt";
    writeParams["new_text"] = "Hello, Claude!";
    
    ToolResult result = writeTool->execute("test-1", writeParams);
    
    if (!result.isError) {
        qDebug() << "✅ Write tool works!";
    } else {
        qDebug() << "❌ Write tool failed:" << result.content;
    }
    
    // 测试 Read 工具
    BaseTool* readTool = registry->findTool("Read");
    QJsonObject readParams;
    readParams["file_path"] = "test.txt";
    
    result = readTool->execute("test-2", readParams);
    
    if (!result.isError && result.content.contains("Hello, Claude!")) {
        qDebug() << "✅ Read tool works!";
    } else {
        qDebug() << "❌ Read tool failed:" << result.content;
    }
    
    // 测试 Glob 工具
    BaseTool* globTool = registry->findTool("Glob");
    QJsonObject globParams;
    globParams["pattern"] = "*.txt";
    
    result = globTool->execute("test-3", globParams);
    
    if (!result.isError && result.content.contains("test.txt")) {
        qDebug() << "✅ Glob tool works!";
    } else {
        qDebug() << "❌ Glob tool failed:" << result.content;
    }
    
    qDebug() << "All tests completed!";
    
    // 清理
    QDir(testWorkspace).removeRecursively();
}
```

---

## 📚 更多资源

- **完整文档**: [NEURX_STANDARD_TOOLS.md](NEURX_STANDARD_TOOLS.md)
- **头文件**: [src/tools/ClaudeStandardTools.h](../src/tools/ClaudeStandardTools.h)
- **实现**: [src/tools/ClaudeStandardTools.cpp](../src/tools/ClaudeStandardTools.cpp)

---

## 🎉 你已经准备好了！

现在你可以：
1. ✅ 使用 LLM 通过自然语言创建和编辑文件
2. ✅ 执行 Shell 命令自动化任务
3. ✅ 搜索和查找代码
4. ✅ 构建完整的 AI 编码助手

**开始使用 NeurX Code 的 Claude 标准工具系统吧！🚀**
