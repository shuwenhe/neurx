# Hook 系统 - 快速参考

## 一句话：Hook 是什么？

**Hook 是在工具执行前/后自动运行的脚本，用于验证、拦截或记录操作。**

```
工具调用
    ↓
🔒 PreToolUse Hook (检查是否允许)
    ↓
    ├─ ❌ 拒绝
    ├─ ✅ 允许
    └─ ⚠️ 询问用户
    ↓
执行工具 (如果允许)
    ↓
📋 PostToolUse Hook (记录结果)
```

---

## Hook 的核心作用

| 作用 | 示例 |
|------|------|
| **安全验证** | 拒绝写入 `/etc` 目录 |
| **命令检查** | 阻止 `rm -rf` |
| **敏感文件** | 询问 `.env` 文件修改 |
| **审批流程** | 数据库修改需要批准 |
| **审计日志** | 记录所有操作 |
| **用户通知** | 关键操作发邮件 |

---

## Hook 的两个事件

### 1️⃣ PreToolUse (执行前)

```
Claude: 我要写入 /tmp/app.py
        ↓
    Hook 检查
    ├─ 是否路径遍历? → NO ✅
    ├─ 是否系统目录? → NO ✅
    ├─ 是否敏感文件? → NO ✅
        ↓
    结果: 允许执行
```

**可以返回的决策**：
- `exit 0` = ✅ 允许
- `exit 1` = ⚠️ 询问用户
- `exit 2` = ❌ 拒绝

### 2️⃣ PostToolUse (执行后)

```
工具执行完成
        ↓
    Hook 记录结果
    ├─ 日志: [2024-06-04] Modified /tmp/app.py
    ├─ 通知: 📧 发送通知
    └─ 统计: 📊 记录操作
        ↓
    继续进行
```

---

## 实际 Hook 脚本例子

### 例子 1: 拒绝危险操作（Bash）

```bash
#!/bin/bash
# ~/.claude/hooks/validate.sh

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# ❌ 拒绝删除操作
if [[ "$command" == *"rm -rf"* ]]; then
  exit 2
fi

# ✅ 允许
exit 0
```

### 例子 2: 询问敏感操作（Bash）

```bash
#!/bin/bash

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

# ⚠️ 询问：修改 .env 文件
if [[ "$file_path" == *.env ]]; then
  echo '{"systemMessage": "正在修改 .env 文件，需要确认"}' >&2
  exit 1  # 询问用户
fi

exit 0
```

### 例子 3: 记录日志（Bash）

```bash
#!/bin/bash
# PostToolUse Hook

result=$(cat)
tool_name=$(echo "$result" | jq -r '.tool_name')
file_path=$(echo "$result" | jq -r '.tool_input.file_path // empty')

# 记录到日志
echo "[$(date)] $tool_name: $file_path" >> ~/.claude/audit.log
```

### 例子 4: 企业审批（Python）

```python
#!/usr/bin/env python3

import json, sys

def is_sensitive(tool_input):
    # 检查是否涉及数据库
    return 'database' in tool_input.get('file_path', '')

input_data = json.load(sys.stdin)

if is_sensitive(input_data['tool_input']):
    # 发送审批请求
    print('{"systemMessage": "需要管理员批准"}', file=sys.stderr)
    sys.exit(1)  # 询问

sys.exit(0)  # 允许
```

---

## Hook 的配置

### 配置文件位置

```
~/.claude/config.json
```

### 配置示例

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/validate-bash.sh"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/validate-write.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/audit-log.sh"
          }
        ]
      }
    ]
  }
}
```

**说明**：
- `matcher`: 匹配哪个工具 (`Bash`, `Write`, `*` 等)
- `type`: `command` 或 `prompt`
- `command`: 要执行的脚本路径

---

## Hook 的输入格式

### JSON 输入示例

```json
{
  "session_id": "abc123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/workspace/app.py",
    "content": "print('hello')"
  },
  "cwd": "/workspace",
  "timestamp": "2024-06-04T10:30:00Z"
}
```

**提取方式**：
```bash
tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path')
command=$(echo "$input" | jq -r '.tool_input.command')
```

---

## Hook 的输出格式

### 拒绝

```bash
echo '{"systemMessage": "不允许的操作"}' >&2
exit 2
```

### 询问

```bash
echo '{"systemMessage": "需要用户确认"}' >&2
exit 1
```

### 允许

```bash
exit 0
```

---

## Hook 能做什么

### ✅ 可以做

```
1. 验证路径安全性
   ├─ 检查路径遍历 (..)
   ├─ 检查系统目录 (/etc, /sys)
   └─ 检查权限

2. 检查命令安全
   ├─ 拒绝 rm -rf
   ├─ 拒绝 chmod 777
   └─ 拒绝 dd 操作

3. 记录审计日志
   ├─ 所有操作记录
   ├─ 时间戳
   └─ 操作者信息

4. 发送通知
   ├─ 邮件通知
   ├─ Slack 通知
   └─ SMS 提醒

5. 集成审批系统
   ├─ 请求批准
   ├─ 等待结果
   └─ 记录批准信息

6. 数据安全检查
   ├─ 检查敏感信息泄露
   ├─ 验证加密
   └─ 检查合规性
```

### ❌ 不应该做

```
1. 修改文件或数据
   ❌ rm /tmp/file
   ❌ git push
   
2. 做耗时操作
   ❌ 调用外部 API（太慢）
   ❌ 数据库查询

3. 调用其他 Claude Code 工具
   ❌ 会导致循环

4. 修改 Hook 规则本身
   ❌ 可能导致混乱

5. 忽略错误
   ❌ 应该正确处理异常
```

---

## Hook 的应用场景

### 场景 1: 个人开发者

```
保护自己不犯低级错误
├─ 防止删除整个项目
├─ 防止修改重要文件
└─ 提醒敏感操作
```

### 场景 2: 小团队

```
基本的安全规则
├─ 不能修改 package.json
├─ 不能修改部署脚本
└─ 记录所有改动
```

### 场景 3: 中型公司

```
带审批的企业流程
├─ 数据库改动需要审批
├─ 上线前需要review
└─ 完整的审计日志
```

### 场景 4: 大型企业

```
完整的合规系统
├─ GDPR/HIPAA 检查
├─ 自动化审批工作流
├─ 密钥管理
└─ 实时监控
```

---

## Hook vs 硬编码规则

```
❌ 硬编码规则
if (path.startsWith("/etc")) {
  deny();  // 在源代码里固定
}
问题:
- 用户无法改
- 每次改规则都要改代码
- 所有用户一样的规则

✅ Hook 脚本
if [[ "$path" == /etc/* ]]; then
  exit 2
fi  # 用户自己的脚本
优点:
- 用户完全控制
- 改规则无需改代码
- 每个用户可以有不同规则
```

---

## 快速开始：创建你的第一个 Hook

### Step 1: 创建 Hook 文件

```bash
mkdir -p ~/.claude/hooks
touch ~/.claude/hooks/validate.sh
chmod +x ~/.claude/hooks/validate.sh
```

### Step 2: 写入 Hook 脚本

```bash
cat > ~/.claude/hooks/validate.sh << 'EOF'
#!/bin/bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# 拒绝系统目录
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  exit 2
fi

exit 0
EOF
```

### Step 3: 配置 Claude Code

```bash
cat > ~/.claude/config.json << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/validate.sh"
          }
        ]
      }
    ]
  }
}
EOF
```

### Step 4: 测试

```bash
# 试试让 Claude Code 创建文件
claude
# 输入: Create a file in /tmp/test.py
# 结果: ✅ 允许 (不在受限目录)

# 再试试
# 输入: Create a file in /etc/test.py
# 结果: ❌ 拒绝 (Hook 工作了!)
```

---

## 常见 Hook 错误

### ❌ 错误 1: 忘记 `exit` 命令

```bash
#!/bin/bash
if [[ "$path" == /etc/* ]]; then
  # 问题: 没有 exit，继续执行
fi
# 这会允许操作!
exit 0
```

✅ 正确做法：
```bash
if [[ "$path" == /etc/* ]]; then
  exit 2  # 立即返回，不继续
fi
exit 0
```

### ❌ 错误 2: JSON 格式错误

```bash
# 问题: 无效的 JSON
echo '{"message": "error"}' >&2  # 引号问题
exit 2
```

✅ 正确做法：
```bash
# 使用 jq 或确保 JSON 有效
echo '{"systemMessage": "error"}' >&2
exit 2
```

### ❌ 错误 3: 没有处理空值

```bash
# 问题: 如果没有 file_path
if [[ "$file_path" == /etc/* ]]; then  # 可能出错
```

✅ 正确做法：
```bash
if [ -z "$file_path" ]; then
  exit 0  # 没有路径就允许
fi

if [[ "$file_path" == /etc/* ]]; then
  exit 2
fi
```

---

## 总结

| 概念 | 说明 |
|------|------|
| **Hook 是什么** | 在工具执行前/后运行的脚本 |
| **两种类型** | PreToolUse (检查) + PostToolUse (记录) |
| **核心用途** | 安全验证 + 灵活定制 + 审计日志 |
| **为什么需要** | 让用户完全控制规则，无需改源代码 |
| **与硬编码对比** | Hook 更灵活、更易维护 |
| **最佳实践** | 清晰的错误信息 + 快速失败 + 记录决策 |

**最关键的一点**：Hook 让 Claude Code 对所有用户都通用，但每个用户都能按自己的需求定制！

---

**相关文档**：
- 📘 [完整 Hook 系统详解](./HOOK_SYSTEM_EXPLAINED.md)
- 📗 [架构分析](./WHY_CLAUDE_CODE_ARCHITECTURE.md)
- 📙 [方案对比](./AI_SOLUTIONS_COMPARISON.md)
