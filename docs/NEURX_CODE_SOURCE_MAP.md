# NeurX Code 源代码导航指南

## 文件创建相关的关键文件

### 🔍 文件位置地图

```
/Users/feifei/agent/neurx-code-reference/
├── plugins/
│   ├── hookify/                          # Hook 系统实现
│   │   ├── core/
│   │   │   └── rule_engine.py           # 规则引擎（验证文件操作）
│   │   └── hooks/
│   │       ├── security_reminder_hook.py # 安全提醒
│   │       └── ...
│   │
│   ├── plugin-dev/                       # 插件开发文档
│   │   ├── skills/hook-development/
│   │   │   └── examples/
│   │   │       ├── validate-write.sh    # ✅ Write 工具验证例子
│   │   │       ├── validate-bash.sh     # ✅ Bash 工具验证例子
│   │   │       └── ...
│   │   └── SKILL.md
│   │
│   ├── security-guidance/                # 安全指导插件
│   │   └── hooks/
│   │       └── security_reminder_hook.py # ✅ 从工具输入提取内容
│   │
│   └── ...
│
├── examples/
│   ├── hooks/
│   │   └── bash_command_validator_example.py  # Bash 命令验证
│   ├── mdm/
│   └── settings/
│
├── scripts/                               # 脚本目录
│   └── ...
│
└── docs/                                  # 文档
    └── ...
```

## 关键代码片段及其位置

### 1. Write 工具验证 - validate-write.sh

**路径**：`外部参考仓库/plugins/plugin-dev/skills/hook-development/examples/validate-write.sh`

**功能**：演示 Write 工具的 PreToolUse 钩子

**关键代码**：
```bash
#!/bin/bash
# 提取文件路径
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# 检查路径遍历
if [[ "$file_path" == *".."* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}}'
  exit 2  # 拒绝
fi

# 检查系统目录
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}}'
  exit 2  # 拒绝
fi
```

**学到的**：
- ✅ Hook 从 JSON stdin 接收输入
- ✅ 提取 `.tool_input.file_path`
- ✅ 返回 `permissionDecision: "deny"` 拒绝
- ✅ 退出码 2 表示拒绝

### 2. Bash 工具验证 - validate-bash.sh

**路径**：`外部参考仓库/plugins/plugin-dev/skills/hook-development/examples/validate-bash.sh`

**功能**：演示 Bash 工具的验证

**关键代码**：
```bash
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# 拒绝危险命令
if [[ "$command" == *"rm -rf"* ]]; then
  exit 2  # 拒绝
fi

if [[ "$command" == *"chmod 777"* ]]; then
  exit 2  # 拒绝
fi

if [[ "$command" == *"dd if=/dev/"* ]]; then
  exit 2  # 拒绝
fi

exit 0  # 允许
```

**学到的**：
- ✅ Bash 工具参数是 `.tool_input.command`
- ✅ 检查危险命令模式
- ✅ 退出码 0 表示允许

### 3. 规则引擎 - rule_engine.py

**路径**：`外部参考仓库/plugins/hookify/core/rule_engine.py`

**功能**：实现规则匹配和评估逻辑

**关键代码片段**（约 235 行附近）：
```python
elif tool_name in ['Write', 'Edit']:
    if field == 'content':
        # Write 使用 'content'，Edit 使用 'new_string'
        return tool_input.get('content') or tool_input.get('new_string', '')
    elif field == 'new_text' or field == 'new_string':
        return tool_input.get('new_string', '')
    elif field == 'old_text' or field == 'old_string':
        return tool_input.get('old_string', '')
    elif field == 'file_path':
        return tool_input.get('file_path', '')
```

**学到的**：
- ✅ Write 和 Edit 工具的参数字段
- ✅ 如何从 tool_input 提取字段
- ✅ 规则引擎支持正则表达式匹配

### 4. 安全提醒钩子 - security_reminder_hook.py

**路径**：`外部参考仓库/plugins/security-guidance/hooks/security_reminder_hook.py`

**功能**：为文件操作提供安全提醒

**关键代码片段**（约 429 行附近）：
```python
def extract_content_from_input(tool_name, tool_input):
    """从工具输入提取内容用于检查"""
    if tool_name == "Write":
        return tool_input.get("content", "")
    elif tool_name == "Edit":
        return tool_input.get("new_string", "")
    elif tool_name == "MultiEdit":
        edits = tool_input.get("edits", [])
        if edits:
            return " ".join(edit.get("new_string", "") for edit in edits)
        return ""
    return ""
```

**学到的**：
- ✅ 不同工具的内容字段不同
- ✅ MultiEdit 有 edits 数组
- ✅ 如何统一提取内容

### 5. Bash 命令验证器示例 - bash_command_validator_example.py

**路径**：`外部参考仓库/examples/hooks/bash_command_validator_example.py`

**功能**：演示如何创建自定义 Bash 命令验证

**关键代码**：
```python
def _validate_command(command: str) -> list[str]:
    """验证 bash 命令"""
    issues = []
    for pattern, message in _VALIDATION_RULES:
        if re.search(pattern, command):
            issues.append(message)
    return issues

def main():
    input_data = json.load(sys.stdin)
    tool_name = input_data.get("tool_name", "")
    if tool_name != "Bash":
        sys.exit(0)
    
    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")
    
    issues = _validate_command(command)
    if issues:
        for message in issues:
            print(f"• {message}", file=sys.stderr)
        sys.exit(2)  # 拒绝
```

**学到的**：
- ✅ 完整的钩子脚本结构
- ✅ 通过 sys.stdin 读取 JSON
- ✅ 通过 sys.stderr 输出消息
- ✅ 退出码控制决策（0=允许，2=拒绝）

## Hook 系统的工作流

### Hook 配置格式

**在 `.neurx/config.json` 中**：
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Validate file write safety..."
          },
          {
            "type": "command",
            "command": "python3 /path/to/validate-write.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/validate-bash.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook 输入/输出格式

**输入（来自外部参考实现）**：
```json
{
  "session_id": "abc123...",
  "cwd": "/workspace",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/workspace/app.py",
    "content": "print('hello')"
  }
}
```

**输出（从 Hook 脚本）**：
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "deny"
  },
  "systemMessage": "Path traversal detected"
}
```

## 关键工具参数参考

### Write 工具参数

```bash
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "string",    # 必需
    "content": "string"       # 必需
  }
}
```

### Edit 工具参数

```bash
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "string",    # 必需
    "old_string": "string",   # 必需
    "new_string": "string"    # 必需
  }
}
```

### MultiEdit 工具参数

```bash
{
  "tool_name": "MultiEdit",
  "tool_input": {
    "edits": [
      {
        "file_path": "string",
        "old_string": "string",
        "new_string": "string"
      }
    ]
  }
}
```

### Bash 工具参数

```bash
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "string"       # 必需，例如 "mkdir -p src/app"
  }
}
```

## 关键概念

### 1. Hook 事件生命周期

```
工具调用请求
    ↓
PreToolUse 钩子
  ├─ 验证工具调用
  ├─ 可以修改或拒绝
  └─ 决策：allow/deny/ask
    ↓
执行工具 (如果允许)
  └─ 实际文件操作
    ↓
PostToolUse 钩子 (可选)
  ├─ 反应到执行结果
  └─ 例如：日志、通知
    ↓
返回结果给调用方
```

### 2. Hook 脚本的三种决策

```bash
exit 0  # ✅ 允许 - 工具继续执行
exit 1  # ⚠️ 询问 - 需要用户确认（显示在 stderr）
exit 2  # ❌ 拒绝 - 阻止工具执行（显示在 stderr）
```

### 3. 安全验证的三层

```
Layer 1: Hook 预验证
  - 路径遍历检查（.. 不允许）
  - 系统目录检查（/etc, /sys 不允许）
  - 敏感文件检查（.env, secrets 警告）

Layer 2: 规则引擎
  - 正则表达式匹配
  - 条件组合（AND/OR）
  - 优先级处理（block > warn > allow）

Layer 3: 用户确认
  - 可疑操作询问用户
  - 显示详细信息
  - 用户决定是否继续
```

## 实用参考

### 快速查看文件创建流程

1. **打开对应配置**：
   ```bash
   cat ~/.neurx/config.json
   ```

2. **查看 Hook 脚本**：
   ```bash
   ls 外部参考仓库/plugins/plugin-dev/skills/hook-development/examples/
   ```

3. **运行示例验证**：
   ```bash
   # 手动测试 Write 钩子
   echo '{
     "hook_event_name": "PreToolUse",
     "tool_name": "Write",
     "tool_input": {"file_path": "/tmp/test.txt", "content": "hello"}
   }' | bash 外部参考仓库/plugins/plugin-dev/skills/hook-development/examples/validate-write.sh
   ```

4. **查看规则定义**：
   ```bash
   grep -r "def _rule_matches" 外部参考仓库/plugins/
   ```

## 总结

| 文件 | 位置 | 功能 |
|------|------|------|
| validate-write.sh | plugins/plugin-dev/skills/hook-development/examples/ | Write 工具验证 |
| validate-bash.sh | plugins/plugin-dev/skills/hook-development/examples/ | Bash 工具验证 |
| rule_engine.py | plugins/hookify/core/ | 规则匹配引擎 |
| security_reminder_hook.py | plugins/security-guidance/hooks/ | 安全提醒 |
| bash_command_validator_example.py | examples/hooks/ | Bash 验证示例 |

## 相关文档

- 📘 [NeurX 文件创建详解](./NEURX_FILE_CREATION_EXPLAINED.md)
- 📗 [NeurX Code 对比](./NEURX_CODE_COMPARISON.md)
- 📙 [NeurX Code 标准工具](./NEURX_STANDARD_TOOLS.md)
