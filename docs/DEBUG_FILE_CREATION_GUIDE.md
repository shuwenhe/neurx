# 调试 Agent 文件创建功能 - 完整指南

## 🎯 问题诊断

已添加详细的调试日志来追踪工具注册和传递过程。现在可以清楚地看到：
1. 工具何时被注册
2. 有哪些工具可用
3. 工具是否被传递给 LLM
4. 工具执行的每一步

---

## 🚀 运行应用并查看日志

### 步骤 1: 在终端中运行应用

```bash
cd /Users/feifei/agent/neurx-code/build

# 运行应用并捕获所有日志
./neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | tee debug.log
```

或者使用过滤版本，只看相关日志：

```bash
cd /Users/feifei/agent/neurx-code/build

# 只显示工具和错误相关的日志
./neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | grep -E "Tool|Write|error|Error|registry|Planner|Anthropic"
```

### 步骤 2: 打开工作空间

在应用中：
1. 点击 `File -> Open Workspace`
2. 选择一个项目目录（比如 `/Users/feifei/agent/test_workspace`）

**预期日志**（应该看到）：
```
[AgentToolRegistry] Registering tool: Write
[AgentToolRegistry] Registering tool: Edit
[AgentToolRegistry] Registering tool: MultiEdit
[AgentToolRegistry] Registering tool: Read
[AgentToolRegistry] Registering tool: Bash
[AgentToolRegistry] Registering tool: Grep
[AgentToolRegistry] Registering tool: Glob
[AgentToolRegistry] Registering tool: file_system
[AgentToolRegistry] Registering tool: smart_file_creator
... (其他工具)
```

✅ 如果看到 "Registering tool: Write"，说明工具已成功注册。

---

## 🧪 测试文件创建

### 测试 1: 简单文件创建

在 Agent 对话框中输入：

```
请在工作空间根目录创建一个名为 hello.txt 的文件，内容是:

Hello from NeurX Code!
This is a test file.
```

**预期日志**（关键步骤）：

```
[agent] request start: provider=anthropic model=claude-sonnet-4-5 iteration=1 messages=2 tools=20
[Planner] Built 20 tools for provider: anthropic
[AgentToolRegistry] Building Anthropic schema for 20 tools
  - Tool: Write
  - Tool: Edit
  - Tool: MultiEdit
  - Tool: Read
  - Tool: Bash
  ... (其他工具)
[AnthropicProvider] Adding 20 tools to request
  - Tool 0: Write
  - Tool 1: Edit
  ... (其他工具)
[agent] response received: content="..." toolCalls=1
[agent] tool executing: Write
[WriteTool] Executing with file_path: hello.txt size: 58
[WriteTool] Resolved absolute path: /Users/xxx/test_workspace/hello.txt
[WriteTool] Sandbox check passed
[WriteTool] Parent directory ensured: /Users/xxx/test_workspace
[WriteTool] Successfully wrote 58 bytes to: /Users/xxx/test_workspace/hello.txt
[agent] tool result: Write callId=toolu_xxx error=false
```

### 测试 2: 带目录的文件

```
请创建 src/main.cpp 文件，内容是一个简单的 C++ Hello World 程序
```

**预期日志**：
```
[WriteTool] Executing with file_path: src/main.cpp size: ...
[WriteTool] Resolved absolute path: /Users/xxx/test_workspace/src/main.cpp
[WriteTool] Parent directory ensured: /Users/xxx/test_workspace/src
[WriteTool] Successfully wrote ... bytes
```

### 测试 3: 绝对路径（应该失败）

```
请创建 /tmp/test.txt 文件
```

**预期日志**（应该看到错误）：
```
[WriteTool] Executing with file_path: /tmp/test.txt
[WriteTool] Error: Path traversal detected for: /tmp/test.txt
```

---

## 📊 关键日志解读

### ✅ 成功的日志模式

1. **工具注册成功**：
   ```
   [AgentToolRegistry] Registering tool: Write
   ```

2. **工具被传递给 LLM**：
   ```
   [AnthropicProvider] Adding 20 tools to request
     - Tool 0: Write
   ```

3. **LLM 调用了工具**：
   ```
   [agent] tool executing: Write
   ```

4. **工具执行成功**：
   ```
   [WriteTool] Successfully wrote ... bytes
   [agent] tool result: Write error=false
   ```

### ❌ 失败的日志模式

1. **没有工具被注册**：
   ```
   # 缺少 "Registering tool: Write" 日志
   ```
   **原因**：工作空间未设置，或 ClaudeStandardToolFactory::registerAllTools 未被调用
   **解决**：确保打开了工作空间

2. **工具未传递给 LLM**：
   ```
   [AnthropicProvider] No tools in request!
   ```
   **原因**：Planner::buildTools 返回空数组
   **解决**：检查 providerId 是否正确

3. **LLM 未调用工具**：
   ```
   [agent] response received: toolCalls=0
   ```
   **原因**：
   - 提示词不够明确
   - LLM 不理解工具用法
   - 系统提示词缺失工具说明
   **解决**：使用更明确的指令，包含完整文件路径

4. **工具执行失败**：
   ```
   [WriteTool] Error: Path traversal detected
   或
   [WriteTool] Error: Sandbox policy denied
   或
   [WriteTool] Error: Cannot open file
   ```
   **原因**：
   - 文件路径超出工作空间（Path traversal）
   - Sandbox 拒绝访问（Sandbox denied）
   - 文件权限问题（Cannot open）
   **解决**：检查文件路径是否在工作空间内，检查文件权限

---

## 🔍 诊断决策树

```
1. 打开工作空间后，日志中有 "Registering tool: Write"?
   ├─ 是 → 继续下一步
   └─ 否 → 工具未注册
        └─ 检查 AgentController::setWorkspacePath
        └─ 确认 ClaudeStandardToolFactory::registerAllTools 被调用

2. 发送请求时，日志中有 "Adding X tools to request"?
   ├─ 是 → 工具数量 > 0? → 继续下一步
   │                      └─ 否 → registry 为空或 buildTools 失败
   └─ 否 → req.tools 为空
        └─ 检查 Planner::buildRequest

3. 日志中有 "- Tool 0: Write"?
   ├─ 是 → Write 工具已传递给 LLM → 继续下一步
   └─ 否 → Write 工具未在工具列表中
        └─ 检查工具注册是否在发送请求之前完成

4. LLM 响应后，日志中有 "tool executing: Write"?
   ├─ 是 → LLM 调用了工具 → 继续下一步
   └─ 否 → LLM 未调用工具
        └─ 提示词不够明确
        └─ 检查系统提示词是否包含工具说明
        └─ 尝试更明确的指令（包含完整文件路径）

5. WriteTool 日志显示 "Successfully wrote"?
   ├─ 是 → ✅ 成功！
   └─ 否 → 查看具体错误消息
        ├─ "Path traversal" → 文件路径超出工作空间
        ├─ "Sandbox denied" → 权限被拒绝
        ├─ "Cannot open" → 文件系统错误
        └─ "file_path is empty" → 参数缺失
```

---

## 🛠️ 常见问题及解决方案

### 问题 1: "No tools in request"

**日志**：
```
[AnthropicProvider] No tools in request!
```

**原因**：Planner::buildTools 返回空数组

**诊断**：
```bash
# 在日志中搜索
grep "Built.*tools for provider" debug.log
```

如果看到：
```
[Planner] Built 0 tools for provider: anthropic
```

**可能原因**：
1. registry 为 nullptr
2. providerId 不是 "anthropic"、"openai" 或 "gemini"
3. registry 中没有任何工具

**解决**：
1. 确保在发送请求前打开了工作空间
2. 检查 LLM provider 设置
3. 重启应用

### 问题 2: LLM 不调用 Write 工具

**症状**：
- 工具已注册
- 工具已传递给 LLM
- 但 LLM 只返回文本，不调用工具

**日志**：
```
[agent] response received: toolCalls=0
```

**原因**：
1. 提示词不够明确
2. LLM 认为不需要使用工具
3. 系统提示词没有说明如何使用工具

**解决方案**：

#### A. 使用更明确的指令

❌ 不明确：
```
"创建一个文件"
"写点代码"
```

✅ 明确：
```
"使用 Write 工具在工作空间根目录创建一个名为 test.txt 的文件，内容是 'Hello World'"
"请调用 Write 工具创建 src/main.cpp 文件"
```

#### B. 检查系统提示词

在 [AgentController.cpp](neurx-code/src/bridge/AgentController.cpp#L58-L119) 中确认系统提示词包含工具说明：

```cpp
**Claude Standard File Operations:**
- Write: Create a new file or overwrite existing file (file_path, new_text)
- Edit: Modify files by text replacement ...
```

#### C. 强制工具使用

暂时的调试方法，在提示词中明确要求：
```
请一定要使用 Write 工具来创建文件，不要只是描述如何创建。
```

### 问题 3: "Path traversal attack detected"

**原因**：请求的文件路径不在工作空间内

**解决**：
- 确保使用相对路径：`src/test.cpp`
- 不要使用 `../`: `../test.cpp` ❌
- 不要使用绝对路径：`/tmp/test.txt` ❌

### 问题 4: "Sandbox policy denied write access"

**原因**：Sandbox 未配置工作空间写权限

**诊断**：检查 [AgentController.cpp](neurx-code/src/bridge/AgentController.cpp#L2591-L2605)：
```cpp
m_sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
m_sandboxManager->addAllowedWritePath(normalizedPath);
```

**解决**：重新打开工作空间以重新初始化 sandbox

---

## 📝 实际测试会话示例

### 会话 1: 成功创建文件

**用户**：
```
在工作空间根目录创建 config.json 文件，内容是 {"version": "1.0"}
```

**日志输出**：
```
[agent] request start: provider=anthropic model=claude-sonnet-4-5 tools=20
[Planner] Built 20 tools for provider: anthropic
[AgentToolRegistry] Building Anthropic schema for 20 tools
  - Tool: Write
  ...
[AnthropicProvider] Adding 20 tools to request
  - Tool 0: Write
  ...
[agent] response received: toolCalls=1
[agent] tool executing: Write
[WriteTool] Executing with file_path: config.json size: 18
[WriteTool] Resolved absolute path: /Users/feifei/workspace/config.json
[WriteTool] Sandbox check passed
[WriteTool] Successfully wrote 18 bytes to: /Users/feifei/workspace/config.json
[agent] tool result: Write error=false
```

**Agent 响应**：
```
✅ 我已经创建了 config.json 文件，内容是 {"version": "1.0"}。
文件位于工作空间根目录。
```

### 会话 2: 失败 - 路径超出工作空间

**用户**：
```
创建 /tmp/test.txt 文件
```

**日志输出**：
```
[agent] tool executing: Write
[WriteTool] Executing with file_path: /tmp/test.txt size: 0
[WriteTool] Error: Path traversal detected for: /tmp/test.txt
[agent] tool result: Write error=true
```

**Agent 响应**：
```
❌ 无法创建文件：路径超出工作空间范围。
只能在当前工作空间内创建文件。请使用相对路径。
```

---

## 📊 日志收集命令

### 收集完整日志

```bash
cd /Users/feifei/agent/neurx-code/build
./neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | tee full_debug.log
```

### 只看工具相关日志

```bash
./neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | grep -E "\[.*Tool.*\]|\[agent\]|\[Planner\]|\[Anthropic\]"
```

### 只看错误和警告

```bash
./neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | grep -i "error\|warning\|fail"
```

### 实时追踪 Write 工具

```bash
./neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | grep -i "write"
```

---

## ✅ 验证检查清单

运行应用后，逐项检查：

- [ ] 打开工作空间后看到 `[AgentToolRegistry] Registering tool: Write`
- [ ] 发送消息后看到 `[Planner] Built X tools` (X > 0)
- [ ] 看到 `[AnthropicProvider] Adding X tools to request`
- [ ] 工具列表中包含 `- Tool 0: Write` 或类似
- [ ] Agent 收到创建文件指令
- [ ] 看到 `[agent] tool executing: Write`
- [ ] 看到 `[WriteTool] Executing with file_path: ...`
- [ ] 看到 `[WriteTool] Successfully wrote ... bytes`
- [ ] 看到 `[agent] tool result: Write error=false`
- [ ] 文件在文件系统中存在
- [ ] 文件内容正确

---

## 🎓 下一步

1. **运行应用**：使用上述命令启动应用并查看日志
2. **打开工作空间**：确认看到工具注册日志
3. **测试文件创建**：使用明确的指令测试
4. **分析日志**：根据上述模式分析问题
5. **反馈**：如果仍有问题，提供完整的日志输出

---

**重要提示**：
- 所有调试日志都已添加到代码中
- 编译已完成，可以直接运行
- 日志会清楚地显示每一步的状态
- 根据日志输出可以准确定位问题所在

现在运行应用并测试吧！🚀
