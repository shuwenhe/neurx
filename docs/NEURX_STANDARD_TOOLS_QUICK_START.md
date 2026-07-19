# NeurX English texttoolsystem - quickstart

**5 English textquickEnglish text**

---

## 🎯 English textstepEnglish text

### stepEnglish text 1: English textsystem

English text `CMakeLists.txt` English text:

```cmake
# English text add_library English text add_executable English textfileEnglish text
src/tools/NeurXStandardTools.cpp
```

### stepEnglish text 2: English texttool

English textinitializeEnglish text(English text `AgentController::initialize()`):

```cpp
#include "tools/NeurXStandardTools.h"

// English text 7 English texttool
NeurXStandardToolFactory::registerAllTools(
    workspaceRoot,      // QString: English textpath
    m_toolRegistry,     // CoreToolRegistry*: toolEnglish text
    m_sandboxManager    // SandboxManager*: English text, Sandbox managementEnglish text
);
```

### stepEnglish text 3: English text LLM promptEnglish texttoolexplanation

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

## 🚀 useexample

### example 1: English textfile

**English textinput**: "English text C++ English text MyClass"

**LLM generate**:
```json
{
  "tool": "Write",
  "parameters": {
    "file_path": "src/MyClass.h",
    "new_text": "#pragma once\n\nclass MyClass {\npublic:\n    MyClass();\n};\n"
  }
}
```

**English text**:
```cpp
BaseTool* tool = m_toolRegistry->findTool("Write");
QJsonObject params;
params["file_path"] = "src/MyClass.h";
params["new_text"] = "#pragma once\n\nclass MyClass {\npublic:\n    MyClass();\n};\n";

ToolResult result = tool->execute("call-123", params);
// result.content: "Created/Updated file: src/MyClass.h (50 bytes)"
```

### example 2: English textfile

**English textinput**: "English text main.cpp English textlogoutput"

**LLM English textpipeline**:
```cpp
// 1. English textfile
tool = findTool("Read");
result = tool->execute("call-1", {{"file_path", "src/main.cpp"}});

// 2. English textfile
tool = findTool("Edit");
result = tool->execute("call-2", {
    {"file_path", "src/main.cpp"},
    {"old_text", "int main() {\n    return 0;\n}"},
    {"new_text", "int main() {\n    qDebug() << \"Started\";\n    return 0;\n}"}
});
```

### example 3: English text

**English textinput**: "English text"

**LLM generate**:
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

### example 4: searchEnglish text

**English textinput**: "English textuse qDebug English text"

**LLM generate**:
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

## 📊 English texttoolEnglish text

| tool | English text | mainEnglish textparameter | English text |
|------|------|----------|------|
| **Write** | English text/English textfile | `file_path`, `new_text` | English text |
| **Edit** | English text | `file_path`, `old_text`, `new_text` | English text |
| **MultiEdit** | English text | `file_path`, `edits[]` | English textstatistics |
| **Read** | English textfile | `file_path`, `start_line?`, `end_line?` | filecontent |
| **Bash** | English text | `command`, `timeout?` | English textoutput |
| **Grep** | searchEnglish text | `pattern`, `path?` | English text |
| **Glob** | English textfile | `pattern` | fileEnglish text |

---

## 🔧 completeEnglish textexample

```cpp
// AgentController.cpp

#include "tools/NeurXStandardTools.h"

void AgentController::initialize()
{
    // English texttoolEnglish text
    m_toolRegistry = new DefaultToolRegistry(this);

    // English text Sandbox managementEnglish text
    m_sandboxManager = new SandboxManager(this);
    m_sandboxManager->allow(m_workspaceRoot, FileSystemAccessMode::ReadWrite);

    // English text NeurX English texttool
    NeurXStandardToolFactory::registerAllTools(
        m_workspaceRoot,
        m_toolRegistry,
        m_sandboxManager
    );

    qDebug() << "Registered tools:" << m_toolRegistry->listTools();
}

void AgentController::handleLLMResponse(const QString& response)
{
    // English text LLM English texttoolEnglish text
    QJsonObject toolCall = parseToolCallFromResponse(response);

    if (toolCall.isEmpty()) {
        // English texttoolEnglish text, English text
        emit messageReceived(response);
        return;
    }

    // English texttoolEnglish text
    QString toolName = toolCall["tool"].toString();
    QJsonObject params = toolCall["parameters"].toObject();

    BaseTool* tool = m_toolRegistry->findTool(toolName);
    if (!tool) {
        emit errorOccurred("Tool not found: " + toolName);
        return;
    }

    // English text
    QString callId = generateCallId();
    ToolResult result = tool->execute(callId, params);

    // English textresult
    if (result.isError) {
        emit toolExecutionFailed(callId, result.content);
    } else {
        emit toolExecutionSucceeded(callId, result.content);

        // English textresultEnglish text LLM English text
        appendToolResultToConversation(result);
        continueLLMConversation();
    }
}

QJsonObject AgentController::parseToolCallFromResponse(const QString& response)
{
    // English text JSON English text(actualEnglish textRequiredEnglish text)
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

## 🎨 QML English textexample

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

        // English textinput
        TextField {
            id: userInput
            width: parent.width
            placeholderText: "inputEnglish text..."

            onAccepted: {
                agentController.sendMessage(text)
                text = ""
            }
        }

        // toolEnglish text
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

## ✅ English text

runEnglish texttoolEnglish text:

```cpp
void testNeurXStandardTools()
{
    // English texttestEnglish text
    QString testWorkspace = QDir::tempPath() + "/neurx_test";
    QDir().mkpath(testWorkspace);

    auto registry = new DefaultToolRegistry();
    NeurXStandardToolFactory::registerAllTools(testWorkspace, registry, nullptr);

    // test Write tool
    BaseTool* writeTool = registry->findTool("Write");
    QJsonObject writeParams;
    writeParams["file_path"] = "test.txt";
    writeParams["new_text"] = "Hello, NeurX!";

    ToolResult result = writeTool->execute("test-1", writeParams);

    if (!result.isError) {
        qDebug() << "✅ Write tool works!";
    } else {
        qDebug() << "❌ Write tool failed:" << result.content;
    }

    // test Read tool
    BaseTool* readTool = registry->findTool("Read");
    QJsonObject readParams;
    readParams["file_path"] = "test.txt";

    result = readTool->execute("test-2", readParams);

    if (!result.isError && result.content.contains("Hello, NeurX!")) {
        qDebug() << "✅ Read tool works!";
    } else {
        qDebug() << "❌ Read tool failed:" << result.content;
    }

    // test Glob tool
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

    // English text
    QDir(testWorkspace).removeRecursively();
}
```

---

## 📚 English text

- **completeEnglish text**: [NEURX_STANDARD_TOOLS.md](NEURX_STANDARD_TOOLS.md)
- **English textfile**: [src/tools/NeurXStandardTools.h](../src/tools/NeurXStandardTools.h)
- **implementation**: [src/tools/NeurXStandardTools.cpp](../src/tools/NeurXStandardTools.cpp)

---

## 🎉 English text!

English textAllowed:
1. ✅ use LLM English textlanguageEnglish textfile
2. ✅ English text Shell English text
3. ✅ searchEnglish text
4. ✅ English textcompleteEnglish text AI English text

**startuse NeurX Code English text NeurX English texttoolsystemEnglish text!🚀**
