# Claude Code 文件和文件夹创建机制详解

## 概述

Claude Code 是一个基于 Node.js 的 AI 编程工具，使用 **Anthropic API 的内置工具（Tool Use）** 来创建文件和文件夹。它不是自己实现这些工具，而是通过调用标准工具来完成操作。

## 架构图

```
Claude API
    ↓
Tool Use Response
    ├─ Write Tool
    ├─ Edit Tool
    ├─ Bash Tool (mkdir -p)
    └─ Glob Tool
    ↓
Claude Code 执行工具
    ↓
文件系统操作
```

## 工具系统

### 1. Write 工具 - 创建/覆盖文件

**用途**：创建新文件或覆盖现有文件

**参数**：
- `file_path` (string): 要创建的文件路径
- `content` (string): 文件内容

**JSON 格式**：
```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/workspace/app.py",
    "content": "import os\n\ndef main():\n    print('Hello')"
  }
}
```

**执行流程**：
1. Claude 决定需要创建文件
2. 调用 Write 工具，传递文件路径和内容
3. Claude Code 接收工具响应
4. **关键**：检查路径安全性（Hook 系统验证）
5. 执行文件写入操作
6. 返回结果给 Claude

**特点**：
- ✅ 自动创建文件
- ❌ **不自动创建父目录**（必须用 Bash mkdir）
- ✅ 会覆盖已存在的文件

### 2. Edit 工具 - 编辑文件内容

**用途**：修改文件中的特定内容

**参数**：
- `file_path` (string): 要编辑的文件路径
- `old_string` (string): 要替换的原始文本
- `new_string` (string): 新的文本

**JSON 格式**：
```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/workspace/app.py",
    "old_string": "def main():\n    print('Hello')",
    "new_string": "def main():\n    print('Hello, World!')\n    print('Updated')"
  }
}
```

### 3. Bash 工具 - 执行 Shell 命令（创建文件夹）

**用途**：执行任意 shell 命令，包括创建目录

**参数**：
- `command` (string): 要执行的 bash 命令

**JSON 格式**：
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "mkdir -p /workspace/src/components/ui"
  }
}
```

**创建文件夹的标准方式**：
```bash
# 创建单个文件夹
mkdir /workspace/src

# 创建嵌套文件夹（推荐）
mkdir -p /workspace/src/components/ui/buttons
```

### 4. MultiEdit 工具 - 原子性批量编辑

**用途**：同时编辑多个文件，保证原子性（全部成功或全部失败）

**参数**：
- `edits` (array): 编辑操作数组
  - 每个编辑包含：`file_path`, `old_string`, `new_string`

**JSON 格式**：
```json
{
  "tool_name": "MultiEdit",
  "tool_input": {
    "edits": [
      {
        "file_path": "/workspace/app.py",
        "old_string": "import os",
        "new_string": "import os\nimport sys"
      },
      {
        "file_path": "/workspace/main.py",
        "old_string": "VERSION = '1.0'",
        "new_string": "VERSION = '1.1'"
      }
    ]
  }
}
```

## 创建文件夹和文件的完整流程

### 场景 1：创建单个文件

```
用户: "Create a file main.py with hello world code"
     ↓
Claude 决定：需要用 Write 工具
     ↓
调用 Write 工具:
{
  "file_path": "/workspace/main.py",
  "content": "print('Hello, World!')"
}
     ↓
Hook 系统验证 (PreToolUse):
  • 检查路径遍历: main.py - ✓ 安全
  • 检查系统目录: /workspace - ✓ 安全
  • 检查敏感文件: main.py - ✓ 安全
     ↓
Claude Code 执行:
  1. 创建文件 /workspace/main.py
  2. 写入内容
  3. 返回成功
     ↓
显示结果: "✓ Created main.py"
```

### 场景 2：创建嵌套文件夹结构

```
用户: "Create a new project structure with src/models/user.py"
     ↓
Claude 决定：需要分两步
  
Step 1: 创建目录结构
  调用 Bash 工具:
  {
    "command": "mkdir -p /workspace/src/models"
  }
       ↓
  Hook 验证:
    • 检查危险命令: mkdir -p - ✓ 安全
    • 检查路径: /workspace/src/models - ✓ 安全
       ↓
  执行结果: ✓ Directories created
  
Step 2: 创建文件
  调用 Write 工具:
  {
    "file_path": "/workspace/src/models/user.py",
    "content": "class User:\n    def __init__(self, name):\n        self.name = name"
  }
       ↓
  Hook 验证: ✓ 通过
       ↓
  执行结果: ✓ File created
```

### 场景 3：批量创建多个文件和目录

```
用户: "Set up a Python project with requirements, src, and tests"
     ↓
Claude 执行多步操作:

1. 创建目录:
   Bash: mkdir -p /workspace/src tests

2. 创建 requirements.txt:
   Write: {
     "file_path": "/workspace/requirements.txt",
     "content": "requests==2.28.0\npython-dotenv==0.20.0"
   }

3. 创建 src/__init__.py:
   Write: {
     "file_path": "/workspace/src/__init__.py",
     "content": "\"\"\"Package initialization\"\"\"\n__version__ = '1.0.0'"
   }

4. 创建 tests/__init__.py:
   Write: {
     "file_path": "/workspace/tests/__init__.py",
     "content": ""
   }

5. 创建 src/app.py:
   Write: {
     "file_path": "/workspace/src/app.py",
     "content": "def run():\n    print('App running')"
   }
```

## Hook 系统 - 安全验证

Claude Code 在执行任何文件操作前都会通过 **Hook 系统** 进行验证。

### Hook 事件流

```
工具调用
  ↓
PreToolUse 钩子
  ├─ 路径遍历检查: ".." → ❌ 拒绝
  ├─ 系统目录检查: /etc, /sys, /usr → ❌ 拒绝
  ├─ 敏感文件检查: .env, credentials → ⚠️ 询问用户
  └─ 危险命令检查: rm -rf, chmod 777 → ❌ 拒绝
  ↓
通过验证 ✓
  ↓
执行工具
  ↓
PostToolUse 钩子
  └─ 反应到结果 (可选)
```

### 验证规则示例

```bash
# validate-write.sh 中的检查
if [[ "$file_path" == *".."* ]]; then
  # ❌ 拒绝路径遍历
  deny "Path traversal detected"
fi

if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  # ❌ 拒绝系统目录
  deny "Cannot write to system directory"
fi

if [[ "$file_path" == *.env ]] || [[ "$file_path" == *secret* ]]; then
  # ⚠️ 警告敏感文件
  ask "Writing to sensitive file - proceed?"
fi
```

## 关键差异对比

| 特性 | Claude Code | NeurX Code |
|------|------------|-----------|
| 文件创建 | Write 工具 | WriteTool (自实现) |
| 文件夹创建 | Bash + mkdir | 无专用工具（也用 Bash） |
| 自动 mkdir | ❌ 否 | ✅ 是 |
| 路径验证 | Hook 系统 | SandboxManager |
| 编辑文件 | Edit 工具 | EditTool (自实现) |
| 批量编辑 | MultiEdit | MultiEditTool (自实现) |

## 完整工具参考

| 工具 | 参数 | 功能 |
|------|------|------|
| **Write** | file_path, content | 创建/覆盖文件 |
| **Edit** | file_path, old_string, new_string | 修改文件内容 |
| **MultiEdit** | edits[] | 原子性批量编辑 |
| **Read** | file_path, [start_line, end_line] | 读取文件 |
| **Bash** | command | 执行 shell 命令 |
| **Glob** | pattern | 列出匹配文件 |
| **Grep** | pattern, [file_path] | 搜索文件内容 |

## 工具实现的关键要点

### 1. 不自动创建父目录

```python
# Claude Code 的 Write 工具 - 不创建父目录
def execute_write(file_path, content):
    # 如果父目录不存在，会失败
    with open(file_path, 'w') as f:
        f.write(content)
    # → 如果 /workspace/src/main.py，src 不存在则失败

# NeurX Code 的 WriteTool - 自动创建
def execute_write(file_path, content):
    # 确保目录存在
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as f:
        f.write(content)
    # → 自动创建 src 目录
```

### 2. Hook 系统的安全验证

Claude Code 在**执行前**通过 Hook 验证：

```python
# 执行流程
input_data = {
    "hook_event_name": "PreToolUse",
    "tool_name": "Write",
    "tool_input": {
        "file_path": "/workspace/app.py",
        "content": "..."
    },
    "cwd": "/workspace"
}

# Hook 脚本接收上述 JSON，进行验证
# 返回: {"continue": true} 或 {"permissionDecision": "deny"}
```

### 3. Bash 工具用于文件夹创建

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "mkdir -p /workspace/src/components/ui/buttons"
  }
}
```

Hook 验证危险命令：
```bash
if [[ "$command" == *"rm -rf"* ]]; then deny; fi
if [[ "$command" == *"chmod 777"* ]]; then deny; fi
```

## 总结

**Claude Code 的文件创建方式**：

1. **Write 工具** → 创建/覆盖单个文件
2. **Bash 工具** → 创建目录结构 (`mkdir -p`)
3. **Edit 工具** → 修改文件内容
4. **Hook 系统** → 安全验证（路径遍历、系统目录、敏感文件）
5. **无自动 mkdir** → 必须显式调用 `mkdir -p` 来创建父目录

**NeurX Code 的改进**：

✅ 实现了 7 个 Claude 兼容工具  
✅ WriteTool 自动创建父目录  
✅ SandboxManager 替代 Hook 系统做安全验证  
✅ 增加了 absolute path 支持  

## 参考

- Claude Code 文档：https://code.claude.com/docs
- Hook 系统：https://docs.anthropic.com/en/docs/claude-code/hooks
- Tool Use API：https://docs.anthropic.com/en/docs/build-a-bot/tool-use
