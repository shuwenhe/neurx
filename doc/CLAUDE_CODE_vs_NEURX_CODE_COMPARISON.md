# Claude Code vs NeurX Code - 文件创建对比

## 快速总结

### Claude Code 的方式
```
Claude 决定 → 调用 Anthropic Tool Use API → 工具执行
                          ↓
                    Bash (mkdir -p)
                    Write (文件内容)
                    Edit (修改内容)
                          ↓
                    Hook 验证安全性
                          ↓
                    文件系统操作
```

### NeurX Code 的方式
```
Agent 决定 → 本地工具注册表 → 工具执行
                    ↓
              WriteTool (C++)
              EditTool (C++)
              BashTool (C++)
                    ↓
              SandboxManager 验证
                    ↓
              Qt 文件操作
```

## 工具对比表

| 功能 | Claude Code | NeurX Code |
|------|------------|-----------|
| **创建文件** | Write 工具 | WriteTool::execute() |
| **编辑文件** | Edit 工具 | EditTool::execute() |
| **批量编辑** | MultiEdit 工具 | MultiEditTool::execute() |
| **创建目录** | Bash: mkdir -p | 通过 WriteTool 自动创建 |
| **执行命令** | Bash 工具 | BashTool::execute() |
| **查找文件** | Glob 工具 | GlobTool::execute() |
| **搜索内容** | Grep 工具 | GrepTool::execute() |
| **读取文件** | Read 工具 | ReadTool::execute() |

## 代码对比

### 创建文件 - Claude Code

**Anthropic API 响应**：
```json
{
  "type": "tool_use",
  "id": "toolu_...",
  "name": "Write",
  "input": {
    "file_path": "/workspace/main.py",
    "content": "print('Hello')"
  }
}
```

**Claude Code 执行**：
```bash
# 如果父目录不存在，会失败！
echo "print('Hello')" > /workspace/main.py
# Error: /workspace 不存在

# 必须分两步
mkdir -p /workspace  # Step 1: 用 Bash 工具创建目录
echo "print('Hello')" > /workspace/main.py  # Step 2: 用 Write 工具创建文件
```

### 创建文件 - NeurX Code

**请求**：
```python
# Agent 调用 WriteTool
WriteTool.execute({
    "file_path": "/workspace/main.cpp",
    "new_text": "#include <iostream>\nint main() { }"
})
```

**源代码实现** (src/tools/ClaudeStandardTools.cpp)：
```cpp
bool WriteTool::execute(const QJsonObject &parameters, QJsonObject &output) {
    QString filePath = parameters.value("file_path").toString();
    QString content = parameters.value("new_text").toString();
    
    // ✅ 自动创建父目录
    QDir dir;
    dir.mkpath(QFileInfo(filePath).absolutePath());
    
    // 验证路径安全
    QString safePath = safePath(filePath);
    if (safePath.isEmpty()) {
        return false;  // 路径遍历攻击
    }
    
    // 创建文件
    QFile file(safePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    file.write(content.toUtf8());
    file.close();
    
    return true;
}
```

## 安全验证对比

### Claude Code - Hook 系统

```python
# /path/to/hook.py - 在工具执行前运行
import json, sys

input_data = json.load(sys.stdin)
tool_name = input_data["tool_name"]
tool_input = input_data["tool_input"]

if tool_name == "Write":
    file_path = tool_input["file_path"]
    
    # ❌ 检查路径遍历
    if ".." in file_path:
        sys.exit(2)  # Deny
    
    # ❌ 检查系统目录
    if file_path.startswith("/etc") or file_path.startswith("/sys"):
        sys.exit(2)  # Deny
    
    # ⚠️ 检查敏感文件
    if ".env" in file_path:
        sys.exit(1)  # Ask user

sys.exit(0)  # Allow
```

**配置**（.claude/config.json）：
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 /path/to/hook.py"
          }
        ]
      }
    ]
  }
}
```

### NeurX Code - SandboxManager

```cpp
// src/sandbox/SandboxManager.h
class SandboxManager {
public:
    void setWorkspaceRoot(const QString &path) {
        m_workspaceRoot = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    }
    
    bool canWriteFile(const QString &filePath) const {
        // 检查是否在工作空间内
        QString absPath = QDir::cleanPath(QFileInfo(filePath).absoluteFilePath());
        
        if (!absPath.startsWith(m_workspaceRoot)) {
            qWarning() << "Path outside workspace:" << filePath;
            return false;  // ❌ 拒绝
        }
        
        return true;  // ✓ 允许
    }
};
```

**使用**（src/bridge/AgentController.cpp）：
```cpp
void AgentController::setWorkspacePath(const QString &workspacePath) {
    m_sandboxManager->setWorkspaceRoot(workspacePath);
    m_sandboxManager->setFileSystemAccessMode(
        SandboxManager::FileSystemAccessMode::Read | 
        SandboxManager::FileSystemAccessMode::Write
    );
}
```

## 关键差异分析

### 1. 文件夹创建

**Claude Code**：
- ❌ Write 工具不创建父目录
- ✅ 必须显式使用 `Bash` 工具和 `mkdir -p`
- 需要两步操作

```
Claude Code 流程：
Bash mkdir -p → Write file
    ↓             ↓
  Step 1       Step 2
```

**NeurX Code**：
- ✅ WriteTool 自动创建父目录
- ✅ 一次操作完成
- 更方便用户

```
NeurX Code 流程：
WriteTool (自动 mkdir)
    ↓
一步完成
```

### 2. 安全验证时机

**Claude Code**：
```
工具调用
  ↓ (Hook 验证)
Pre Validation
  ↓
执行工具
  ↓ (Hook 反应)
Post Validation
```

**NeurX Code**：
```
工具调用
  ↓
SandboxManager 验证
  ↓
执行工具
```

### 3. 实现方式

| 方面 | Claude Code | NeurX Code |
|------|------------|-----------|
| **语言** | JavaScript/Node.js | C++/Qt |
| **运行方式** | CLI 工具 | Qt GUI 应用 |
| **API 依赖** | Anthropic API | 本地实现 |
| **验证方式** | 外部 Hook 脚本 | C++ SandboxManager |
| **集成方式** | 命令行调用 | Qt 信号/槽 |

## 工具链对比

### Claude Code 工具链

```
Claude 输出 Write 工具调用
          ↓
   Claude Code 接收
          ↓
   验证 Hook (Python/Bash)
          ↓
   检查通过 ✓
          ↓
   Node.js 执行文件操作
          ↓
   fs.writeFileSync()
          ↓
   返回结果给 Claude
```

### NeurX Code 工具链

```
Agent 决定调用 WriteTool
          ↓
AgentToolRegistry 查找
          ↓
ClaudeStandardToolFactory 创建工具
          ↓
WriteTool::execute() 被调用
          ↓
safePath() 验证路径
          ↓
SandboxManager 验证权限
          ↓
QFile 操作
          ↓
Agent 接收结果
```

## 实现建议

### 从 Claude Code 学到的

1. ✅ **Hook 系统** → 灵活的安全验证
   - NeurX Code 用 SandboxManager 实现
   
2. ✅ **Bash 工具** → 保留复杂命令的灵活性
   - NeurX Code 实现了 BashTool
   
3. ✅ **MultiEdit 工具** → 原子性操作
   - NeurX Code 实现了 MultiEditTool
   
4. ❌ **分步创建** → 在 NeurX 中改进
   - WriteTool 自动创建父目录（更好！）

### NeurX Code 的优化

1. ✅ **自动 mkdir** - 减少步骤
2. ✅ **C++ 本地实现** - 不依赖外部 API
3. ✅ **Qt 集成** - 与 GUI 紧密结合
4. ✅ **SandboxManager** - 集中管理权限

## 完整工作流示例

### 场景：创建 React 项目结构

**Claude Code 方式**（3 步）：

```json
Step 1: Bash 工具创建目录
{
  "tool_name": "Bash",
  "input": {"command": "mkdir -p src/components src/pages"}
}

Step 2: Write 工具创建 package.json
{
  "tool_name": "Write",
  "input": {
    "file_path": "package.json",
    "content": "{\"name\": \"app\", \"version\": \"1.0\"}"
  }
}

Step 3: Write 工具创建 src/App.jsx
{
  "tool_name": "Write",
  "input": {
    "file_path": "src/App.jsx",
    "content": "export default function App() { return <div>Hello</div> }"
  }
}
```

**NeurX Code 方式**（1 步 + 自动）：

```python
# Agent 调用 WriteTool 3 次
# 但不需要显式创建目录 - WriteTool 自动处理

write_tool.execute({
    "file_path": "src/components/Button.cpp",
    "new_text": "..."
})  # ✓ 自动创建 src/components 目录

write_tool.execute({
    "file_path": "include/Button.h",
    "new_text": "..."
})  # ✓ 自动创建 include 目录
```

## 总结

**Claude Code**：
- 使用 Anthropic API 的 Tool Use 功能
- Hook 系统做安全验证
- 需要显式 mkdir 创建目录
- CLI 工具形式

**NeurX Code**：
- C++/Qt 本地实现
- SandboxManager 做安全验证
- WriteTool 自动创建目录
- GUI 应用形式

两者都遵循相同的**工具模型**，但 NeurX Code **改进了用户体验**！
