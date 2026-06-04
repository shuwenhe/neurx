# Claude Code 的 Hook 系统详解

## Hook 是什么？

**Hook 就是在特定时刻自动执行的脚本，用于拦截和验证 AI 工具的执行。**

```
类比：
Hook = 保安
├─ 工具调用 = 访客进入
├─ Hook = 保安检查访客
└─ 结果 = 允许/拒绝/询问用户
```

## Hook 的核心作用

### 1️⃣ 安全验证

Claude Code 执行工具前的最后一道防线：

```
Claude 决定: "我来创建文件 /etc/passwd"
              ↓
        Hook 拦截
              ↓
        检查: /etc 是系统目录吗？
        结果: YES → 拒绝 ❌
              ↓
用户看到: "不允许写入系统文件"
```

### 2️⃣ 灵活定制

**硬编码 vs Hook 的区别**：

❌ **硬编码规则**（不灵活）:
```cpp
// 在源代码里写死
if (path.startsWith("/etc")) {
  deny();
}
// 问题: 用户无法改，所有人都一样
```

✅ **Hook 脚本**（灵活）：
```bash
# ~/.claude/hooks/validate.sh - 用户自己写
if [[ "$path" == /etc/* ]]; then
  exit 2  # Deny
fi
# 优点: 用户完全控制，无需改源代码
```

### 3️⃣ 企业审批流程

```
Hook 不仅可以验证，还能集成企业流程：

工具调用 → Hook 拦截
           ↓
        是否需要审批？
        ├─ 小改动 → 自动允许
        ├─ 普通改动 → 记录日志
        └─ 敏感改动 → 发送审批请求
           ↓
        等待审批结果
        ├─ 批准 → 继续执行
        └─ 拒绝 → 中止
           ↓
        最后记录到审计系统
```

---

## Hook 的生命周期

### 完整流程

```
┌─────────────────────────────────────────┐
│ Claude API 生成工具调用                  │
│ 例如: Write /workspace/app.py            │
└──────────────┬──────────────────────────┘
               │
               ↓
┌──────────────────────────────────────────┐
│ ⏩ PreToolUse Hook (执行前)               │
│                                          │
│ 1. 读取工具信息 (JSON stdin)            │
│ 2. 执行验证脚本 ~/.claude/hooks/pre.sh  │
│ 3. 检查路径、命令、权限                 │
│ 4. 返回决策: allow/deny/ask             │
│                                          │
│ 决策:                                    │
│ ├─ exit 0 = ✅ 允许                      │
│ ├─ exit 1 = ⚠️ 询问用户                │
│ └─ exit 2 = ❌ 拒绝                     │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴──────┐
        │             │
    ❌ 拒绝        ✅ 允许
        │             │
        │             ↓
        │      ┌──────────────────┐
        │      │ 执行工具         │
        │      │ fs.writeFile()  │
        │      │ execSync()      │
        │      └────────┬─────────┘
        │             │
        │             ↓
        │      ┌──────────────────────────┐
        │      │ ⏩ PostToolUse Hook      │
        │      │                         │
        │      │ 1. 接收执行结果         │
        │      │ 2. 执行后处理脚本       │
        │      │ 3. 记录日志             │
        │      │ 4. 发送通知             │
        │      │ 5. 统计分析             │
        │      └────────┬────────────────┘
        │             │
        └─────────────┼──────────┐
                      │          │
                      ↓          ↓
                  返回结果    显示给用户
```

---

## Hook 的输入输出格式

### 📥 输入 (Hook 脚本接收的 JSON)

```json
{
  "session_id": "abc123xyz",
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

### 📤 输出 (Hook 脚本返回的决策)

**示例 1: 允许**
```bash
exit 0  # 允许
```

**示例 2: 拒绝**
```bash
echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "危险操作"}' >&2
exit 2  # 拒绝
```

**示例 3: 询问用户**
```bash
echo '{"hookSpecificOutput": {"permissionDecision": "ask"}, "systemMessage": "需要确认"}' >&2
exit 1  # 询问
```

---

## Hook 的两种类型

### 1. PreToolUse Hook (执行前验证)

**时机**：工具执行前

**用途**：
- ✅ 路径遍历检查
- ✅ 权限验证
- ✅ 敏感文件检查
- ✅ 命令安全检查
- ✅ 审批流程

**示例**：拒绝危险操作
```bash
#!/bin/bash
input=$(cat)

# 检查是否尝试删除文件
command=$(echo "$input" | jq -r '.tool_input.command // empty')
if [[ "$command" == *"rm -rf"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}}' >&2
  exit 2
fi

exit 0
```

### 2. PostToolUse Hook (执行后反应)

**时机**：工具执行后

**用途**：
- ✅ 审计日志
- ✅ 事件通知
- ✅ 统计分析
- ✅ 副作用处理
- ✅ 结果验证

**示例**：记录所有文件修改
```bash
#!/bin/bash
result=$(cat)

# 记录到日志
file_path=$(echo "$result" | jq -r '.tool_input.file_path // empty')
if [ ! -z "$file_path" ]; then
  echo "[$(date)] Modified: $file_path" >> ~/.claude/audit.log
fi
```

---

## 实际 Hook 脚本例子

### 例子 1: 基础安全验证

```bash
#!/bin/bash
# ~/.claude/hooks/validate-write.sh

set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')

if [ "$tool_name" != "Write" ]; then
  exit 0
fi

# 提取文件路径
file_path=$(echo "$tool_input" | jq -r '.file_path // empty')

# ❌ 拒绝：路径遍历
if [[ "$file_path" == *".."* ]]; then
  echo '{"systemMessage": "❌ 拒绝: 检测到路径遍历"}' >&2
  exit 2
fi

# ❌ 拒绝：系统目录
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  echo '{"systemMessage": "❌ 拒绝: 不能修改系统目录"}' >&2
  exit 2
fi

# ⚠️ 询问：敏感文件
if [[ "$file_path" == *.env ]] || [[ "$file_path" == *secret* ]]; then
  echo '{"systemMessage": "⚠️  警告: 正在修改敏感文件，需要确认"}' >&2
  exit 1
fi

# ✅ 允许
exit 0
```

### 例子 2: Bash 命令验证

```bash
#!/bin/bash
# ~/.claude/hooks/validate-bash.sh

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')

# ✅ 快速允许安全命令
if [[ "$command" =~ ^(ls|pwd|echo|cat)(\s|$) ]]; then
  exit 0
fi

# ❌ 阻止危险命令
dangerous_patterns=(
  "rm -rf"
  "dd if=/dev/"
  "chmod 777"
  "> /dev/"
  "mkfs"
)

for pattern in "${dangerous_patterns[@]}"; do
  if [[ "$command" == *"$pattern"* ]]; then
    echo '{"systemMessage": "❌ 危险命令被拒绝"}' >&2
    exit 2
  fi
done

# ⚠️ 询问权限提升
if [[ "$command" == sudo* ]] || [[ "$command" == su* ]]; then
  echo '{"systemMessage": "⚠️ 需要权限提升，需要确认"}' >&2
  exit 1
fi

exit 0
```

### 例子 3: 企业级审批 Hook (Python)

```python
#!/usr/bin/env python3
# ~/.claude/hooks/approval-hook.py

import json
import sys
from datetime import datetime

def is_sensitive_operation(tool_input):
    """判断是否是敏感操作"""
    # 数据库相关的改动
    if 'database' in tool_input.get('file_path', ''):
        return True
    
    # 配置文件
    if tool_input.get('file_path', '').endswith(('.env', '.yml', '.yaml')):
        return True
    
    # 删除操作
    if 'rm' in tool_input.get('command', ''):
        return True
    
    return False

def request_approval(operation_id, details):
    """请求审批（实际应该调用审批系统 API）"""
    # 伪代码：实际应该调用公司的审批系统
    print(f"📨 发送审批请求: {operation_id}", file=sys.stderr)
    print(f"   操作: {details}", file=sys.stderr)
    # 这里应该调用企业的 API 或发送邮件
    return True  # 假设已批准

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    
    tool_name = input_data.get('tool_name', '')
    tool_input = input_data.get('tool_input', {})
    
    # 检查是否是敏感操作
    if is_sensitive_operation(tool_input):
        # 请求审批
        operation_id = f"op_{input_data.get('session_id', 'unknown')}"
        approved = request_approval(operation_id, tool_input)
        
        if not approved:
            print(json.dumps({
                "hookSpecificOutput": {
                    "permissionDecision": "deny"
                },
                "systemMessage": "❌ 审批被拒绝"
            }), file=sys.stderr)
            sys.exit(2)
    
    sys.exit(0)

if __name__ == "__main__":
    main()
```

### 例子 4: 审计日志 Hook (PostToolUse)

```bash
#!/bin/bash
# ~/.claude/hooks/audit-log.sh - PostToolUse Hook

result=$(cat)
tool_name=$(echo "$result" | jq -r '.tool_name')
file_path=$(echo "$result" | jq -r '.tool_input.file_path // empty')
command=$(echo "$result" | jq -r '.tool_input.command // empty')

LOG_FILE="$HOME/.claude/audit.log"

# 记录操作
log_entry() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

case "$tool_name" in
  Write)
    log_entry "✍️  Created/Modified: $file_path"
    ;;
  Edit)
    log_entry "✏️  Edited: $file_path"
    ;;
  Bash)
    log_entry "⚙️  Executed: $command"
    ;;
  *)
    log_entry "🔧 Tool: $tool_name"
    ;;
esac

exit 0
```

---

## Hook 的配置方式

### 标准配置文件

```json
// ~/.claude/config.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/validate-write.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/validate-bash.sh"
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

### 配置说明

```
hooks
├─ PreToolUse
│   ├─ matcher: 匹配的工具名 ("Write|Edit", "Bash", "*" 等)
│   └─ hooks[]
│       ├─ type: "command" 或 "prompt"
│       └─ command: 要执行的脚本路径
│
└─ PostToolUse
    └─ 同上
```

---

## Hook 的应用场景

### 场景 1: 个人开发者

```bash
# 简单的安全检查
~/.claude/hooks/validate.sh
├─ 拒绝 /etc 等系统目录
├─ 拒绝危险命令 (rm -rf)
└─ 询问 .env 等敏感文件
```

### 场景 2: 创意团队

```bash
# 项目特定规则
~/.claude/hooks/validate.sh
├─ 只允许在 src/ 目录修改
├─ 禁止修改 package.json
├─ 禁止 git push
└─ 记录所有修改到 changelog
```

### 场景 3: 企业公司

```python
# 完整的审批流程
~/.claude/hooks/enterprise-hook.py
├─ 检查操作类型
├─ 如果敏感 → 请求审批
├─ 等待审批结果
├─ 记录到审计系统
├─ 发送通知给管理员
└─ 生成合规报告
```

### 场景 4: 数据科学

```bash
# 数据安全检查
~/.claude/hooks/data-safety.sh
├─ 监测数据泄露 (例如 print dataset)
├─ 检查 API Key 使用
├─ 验证数据处理符合 GDPR
└─ 确保结果脱敏
```

---

## Hook vs 其他验证方式

### 对比：Hard-coded vs Hook vs 审批系统

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│              │ 硬编码规则   │ Hook 脚本    │ 完整审批系统 │
├──────────────┼──────────────┼──────────────┼──────────────┤
│ 灵活性       │ ❌ 低        │ ✅ 高        │ ✅✅ 最高     │
│ 用户控制     │ ❌ 无        │ ✅ 完全      │ ✅✅ 完全     │
│ 实现复杂度   │ ✅ 简单      │ ✅ 中等      │ ❌ 复杂      │
│ 维护成本     │ ❌ 高        │ ✅ 低        │ ❌ 高        │
│ 定制能力     │ ❌ 无        │ ✅ 无限      │ ✅✅ 无限    │
│ 企业审批     │ ❌ 无        │ ✅ 可扩展    │ ✅✅ 原生    │
│ 开源友好     │ ✅ 简单      │ ✅ 友好      │ ❌ 复杂      │
│ 小公司适配   │ ✅ 可以      │ ✅ 推荐      │ ❌ 过度      │
│ 大企业适配   │ ❌ 不够      │ ✅✅ 很好    │ ✅ 最佳      │
└──────────────┴──────────────┴──────────────┴──────────────┘

Claude Code 选择 Hook 的原因:
✨ 平衡了简单性和灵活性
✨ 适合所有规模的用户 (从个人到企业)
✨ 无需修改源代码
✨ 社区可以共享 Hook 脚本
```

---

## Hook 的优点 vs 缺点

### ✅ 优点

```
1. 完全由用户控制
   - 不需要改 Claude Code 源代码
   - 可以随意定制规则

2. 灵活无限制
   - 简单检查 vs 复杂审批
   - 个人 vs 企业
   - 完全可扩展

3. 无需重新编译
   - 改一个规则
   - 下次就生效
   - 即时反馈

4. 开发者友好
   - Bash / Python / 任何语言
   - 简单的 JSON 接口
   - 容易测试

5. 社区可共享
   - 好的 Hook 脚本可以共享
   - 别人可以基础上改
   - 形成生态
```

### ❌ 缺点

```
1. 用户需要会编程
   - 不是所有人都会 Bash
   - 但相对来说不难

2. 调试困难
   - Hook 脚本出错不明显
   - 需要手动测试

3. 安全需要自己确保
   - Claude Code 不保证 Hook 的安全性
   - Hook 脚本本身可能有漏洞
   - 用户需要review代码

4. 分散的规则
   - 每个用户可能有不同规则
   - 难以统一管理（企业场景）
```

**总结**：对于中小型团队和个人，Hook 已经足够。对于大企业，可能需要更完整的审批系统。

---

## Hook 的最佳实践

### ✅ DO (应该做)

```bash
# 1. 清晰的错误消息
exit 2  # ❌ 不好：没有说明原因
echo '{"systemMessage": "❌ 不能写入 /etc 目录"}' >&2  # ✅ 好：清楚的原因

# 2. 快速失败
if [[ "$path" == *".."* ]]; then
  exit 2
fi
# 而不是做很多检查再失败

# 3. 记录决策日志
echo "[$(date)] Hook 决策: DENY - $reason" >> /tmp/hook-debug.log

# 4. 处理 edge cases
if [ -z "$file_path" ]; then
  exit 0  # 没有路径就允许
fi

# 5. 用基于规则的检查
patterns=("rm -rf" "chmod 777")  # 而不是硬编码字符串
```

### ❌ DON'T (不应该做)

```bash
# 1. 不要做很耗时的操作
subprocess.call(['curl', 'https://approval-server'])  # ❌ 太慢

# 2. 不要在 Hook 里修改文件
rm /tmp/tempfile  # ❌ 副作用太大

# 3. 不要信任所有输入
if [[ $path == $TRUSTED_DIR ]]  # ❌ 可能被注入

# 4. 不要在 Hook 里调用其他工具
claude-code edit  # ❌ 可能导致循环

# 5. 不要忽略错误
command  # ❌ 应该 || handle_error
```

---

## 总结：Hook 的本质

```
Hook = 拦截器 + 验证器 + 日志系统

               工具调用
                  ↓
           ┌──────────────┐
           │ PreToolUse   │ ← Hook 拦截
           │ Hook         │  ← 验证规则
           └──────┬───────┘
                  ↓
            ✅ 继续执行
             或 ❌ 拒绝
                  ↓
           ┌──────────────┐
           │ 执行工具     │
           └──────┬───────┘
                  ↓
           ┌──────────────┐
           │ PostToolUse  │ ← Hook 反应
           │ Hook         │  ← 日志、通知
           └──────────────┘
```

**Hook 的核心价值**：
- 🔐 安全性 (防止危险操作)
- 🎯 灵活性 (支持任何验证规则)
- 📊 可见性 (审计和日志)
- 🏢 可扩展性 (从个人到企业)

这就是为什么 Claude Code 选择 Hook 系统而不是硬编码规则！

---

**相关文档**：
- 📘 [完整架构分析](./WHY_CLAUDE_CODE_ARCHITECTURE.md)
- 📗 [快速参考](./CLAUDE_CODE_ARCHITECTURE_QUICK_GUIDE.md)
- 📙 [方案对比](./AI_SOLUTIONS_COMPARISON.md)
