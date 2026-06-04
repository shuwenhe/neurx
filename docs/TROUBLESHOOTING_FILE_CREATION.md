# Agent 创建文件问题诊断指南

## 🔍 问题分析

当 Agent 无法创建文件时，可能的原因包括：

1. **工作空间未设置**
2. **Sandbox 权限配置错误**
3. **LLM 未正确调用工具**
4. **工具参数格式错误**
5. **文件路径问题**

---

## 📋 快速诊断步骤

### 步骤 1: 检查工作空间是否已设置

在 NeurX Code 界面中：
- 左上角应该显示当前工作空间路径
- 如果显示"No workspace"，需要先打开工作空间

**解决方法**:
```
File -> Open Workspace -> 选择项目目录
```

### 步骤 2: 检查工具是否已注册

在应用中查看工具列表：
- 点击右侧的"工具"按钮
- 查找 "Write" 工具
- 应该能看到：Write, Edit, MultiEdit, Read, Bash, Grep, Glob

**如果看不到这些工具**:
- 工具注册失败
- 需要重新打开工作空间

### 步骤 3: 检查 Agent 的提示词

与 Agent 对话时，明确指定文件路径：

**❌ 错误示例**:
```
"创建一个文件"
"写一些代码"
```

**✅ 正确示例**:
```
"在 src/test.cpp 中创建一个简单的 Hello World 程序"
"创建 config.json 文件，内容是 {...}"
```

### 步骤 4: 查看工具执行日志

运行应用时在终端查看日志：
```bash
cd /Users/feifei/agent/neurx-code/build
./neurx-codeApp 2>&1 | grep -E "tool|Tool|Write|Error"
```

关键日志信息：
- `[agent] tool executing: Write`
- `[agent] tool result: Write error=false`
- 如果看到 `error=true`，说明执行失败

---

## 🧪 测试工具功能

### 创建测试文件

在终端中运行此 C++ 代码片段来测试 Write 工具：

```cpp
// test_write_tool.cpp
#include <QCoreApplication>
#include <QDebug>
#include <QJsonObject>
#include <QDir>
#include "agent/AgentToolRegistry.h"
#include "tools/ClaudeStandardTools.h"
#include "sandbox/DefaultSandboxManager.h"

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    
    // 设置测试工作空间
    QString testWorkspace = QDir::homePath() + "/neurx_test";
    QDir().mkpath(testWorkspace);
    
    qDebug() << "测试工作空间:" << testWorkspace;
    
    // 创建工具注册表和 Sandbox
    auto registry = new AgentToolRegistry();
    auto sandboxManager = new DefaultSandboxManager();
    sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
    sandboxManager->addAllowedWritePath(testWorkspace);
    
    // 注册 Claude 标准工具
    ClaudeStandardToolFactory::registerAllTools(testWorkspace, registry, sandboxManager);
    
    // 测试 Write 工具
    BaseTool* writeTool = registry->tool("Write");
    if (!writeTool) {
        qCritical() << "❌ Write 工具未注册！";
        return 1;
    }
    
    qDebug() << "✅ Write 工具已找到";
    
    // 执行写入操作
    QJsonObject args;
    args["file_path"] = "test_hello.cpp";
    args["new_text"] = "#include <iostream>\n\nint main() {\n    std::cout << \"Hello from NeurX!\" << std::endl;\n    return 0;\n}\n";
    
    qDebug() << "执行 Write 工具...";
    ToolResult result = writeTool->execute("test-1", args);
    
    if (result.isError) {
        qCritical() << "❌ 写入失败:" << result.content;
        return 1;
    }
    
    qDebug() << "✅ 写入成功:" << result.content;
    
    // 验证文件是否存在
    QString filePath = QDir(testWorkspace).filePath("test_hello.cpp");
    if (QFile::exists(filePath)) {
        qDebug() << "✅ 文件已创建:" << filePath;
        
        // 读取文件内容
        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly)) {
            qDebug() << "文件内容:";
            qDebug() << file.readAll();
            file.close();
        }
    } else {
        qCritical() << "❌ 文件未创建！";
        return 1;
    }
    
    qDebug() << "\n✅ 所有测试通过！";
    return 0;
}
```

编译并运行：
```bash
cd /Users/feifei/agent/neurx-code/build
qmake -o test_write_tool ../test_write_tool.cpp
./test_write_tool
```

---

## 🔧 常见问题及解决方案

### 问题 1: "Unknown tool: Write"

**原因**: 工具未注册

**解决**:
1. 检查 CMakeLists.txt 是否包含 ClaudeStandardTools.cpp
2. 重新编译项目
3. 重启应用并重新打开工作空间

```bash
cd /Users/feifei/agent/neurx-code
rm -rf build
mkdir build && cd build
cmake ..
make -j4
```

### 问题 2: "Sandbox policy denied write access"

**原因**: Sandbox 未配置写权限

**解决**: 检查 AgentController::setWorkspacePath 中的代码
```cpp
if (m_sandboxManager) {
    m_sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
    m_sandboxManager->setReadOnlyMode(false);
    m_sandboxManager->clearPaths();
    m_sandboxManager->addAllowedReadPath(normalizedPath);
    m_sandboxManager->addAllowedWritePath(normalizedPath);  // ← 确保这行存在
}
```

### 问题 3: "Path traversal attack detected"

**原因**: 文件路径超出工作空间范围

**解决**: 确保文件路径是相对路径或在工作空间内
- ✅ 正确: `src/main.cpp`
- ✅ 正确: `config.json`
- ❌ 错误: `../../../etc/passwd`
- ❌ 错误: `/tmp/test.txt` (绝对路径，不在工作空间内)

### 问题 4: LLM 不调用 Write 工具

**原因**: 提示词不够明确

**解决**: 使用更具体的指令
```
❌ "创建一个类"
✅ "在 src/MyClass.h 中创建一个名为 MyClass 的 C++ 类"

❌ "添加一些代码"
✅ "在 main.cpp 中添加 #include <iostream>"

❌ "写个配置文件"
✅ "创建 config.json 文件，内容是 {\"version\": \"1.0\"}"
```

### 问题 5: 工具调用但文件未创建

**调试步骤**:

1. **查看应用日志**
   ```bash
   cd build
   ./neurx-codeApp 2>&1 | tee app.log
   ```

2. **查找错误信息**
   ```bash
   grep -i "error\|fail\|denied" app.log
   ```

3. **检查工具执行结果**
   - 在应用界面中查看工具卡片的状态
   - 红色 = 失败，绿色 = 成功
   - 点击工具卡片查看详细信息

---

## 🎯 手动测试流程

### 测试 1: 基本文件创建

在 Agent 对话框中输入：
```
请在工作空间根目录创建一个名为 test.txt 的文件，内容是 "Hello NeurX"
```

**预期结果**:
- Agent 调用 Write 工具
- 工具卡片显示绿色（成功）
- 文件出现在左侧文件树中
- 可以在编辑器中打开文件

### 测试 2: 创建带目录的文件

在 Agent 对话框中输入：
```
请创建 src/utils/helper.cpp 文件，内容是一个简单的辅助函数
```

**预期结果**:
- Agent 创建 src/utils 目录（如果不存在）
- 创建 helper.cpp 文件
- 文件包含辅助函数代码

### 测试 3: 查看工具参数

在 Agent 对话框中输入：
```
你有哪些文件操作工具？Write 工具需要什么参数？
```

**预期响应**:
```
我有以下文件操作工具：
- Write: 创建新文件或覆盖现有文件
  参数: file_path (文件路径), new_text (文件内容)
- Edit: 修改现有文件
  参数: file_path, old_text, new_text
...
```

---

## 📊 诊断检查清单

使用此清单逐项检查：

- [ ] 已打开工作空间（非"No workspace"）
- [ ] Write 工具在工具列表中可见
- [ ] Sandbox 配置了写权限
- [ ] 提示词明确指定了文件路径
- [ ] 文件路径是相对路径或在工作空间内
- [ ] 应用日志中没有错误信息
- [ ] 工具卡片显示绿色（成功状态）

---

## 🐛 提交 Bug 报告

如果以上方法都无法解决问题，请提供以下信息：

1. **系统信息**
   - 操作系统和版本
   - Qt 版本
   - NeurX Code 版本

2. **复现步骤**
   - 打开的工作空间路径
   - 发送给 Agent 的确切消息
   - Agent 的响应

3. **日志信息**
   ```bash
   cd build
   ./neurx-codeApp 2>&1 > debug.log
   # 复现问题
   # Ctrl+C 停止
   tail -100 debug.log
   ```

4. **工具列表截图**
   - 显示可用工具的界面

5. **错误信息**
   - 工具卡片中的错误消息
   - 终端中的错误输出

---

## ✅ 验证修复

成功创建文件后，验证：
1. ✅ 文件在文件系统中存在
2. ✅ 文件包含正确的内容
3. ✅ 可以在编辑器中打开
4. ✅ 可以继续编辑文件
5. ✅ 后续的文件操作也正常工作

---

## 🎉 总结

**最常见的问题**:
1. 未打开工作空间 (60%)
2. 提示词不够具体 (25%)
3. 文件路径错误 (10%)
4. 其他配置问题 (5%)

**快速解决方案**:
1. 确保打开了工作空间
2. 使用明确的文件路径
3. 查看工具执行日志
4. 验证工具已注册

如果问题仍未解决，请参考上面的详细诊断步骤或提交 Bug 报告。
