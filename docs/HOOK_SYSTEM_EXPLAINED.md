# Claude Code English text Hook systemEnglish text

## Hook English text?

**Hook English text, English text AI toolEnglish text.**

```
English text:
Hook = English text
├─ toolEnglish text = English text
├─ Hook = English text
└─ result = English text/English text/English text
```

## Hook English text

### 1️⃣ safetyEnglish text

Claude Code English texttoolEnglish text:

```
Claude English text: "English textfile /etc/passwd"
              ↓
        Hook English text
              ↓
        English text: /etc English textsystemdirectoryEnglish text?
        result: YES → English text ❌
              ↓
English text: "English textsystemfile"
```

### 2️⃣ English text

**English text vs Hook English text**:

❌ **English text**(English text):
```cpp
// English text
if (path.startsWith("/etc")) {
  deny();
}
// English text: English text, English text
```

✅ **Hook English text**(English text):
```bash
# ~/.claude/hooks/validate.sh - English text
if [[ "$path" == /etc/* ]]; then
  exit 2  # Deny
fi
# English text: English text, English text
```

### 3️⃣ English textpipeline

```
Hook English textAllowedEnglish text, English textpipeline:

toolEnglish text → Hook English text
           ↓
        English textRequiredEnglish text?
        ├─ English text → English text
        ├─ English text → English textlog
        └─ English text → English textrequest
           ↓
        English textresult
        ├─ English text → English text
        └─ English text → English text
           ↓
        English textsystem
```

---

## Hook English text

### completepipeline

```
┌─────────────────────────────────────────┐
│ Claude API generatetoolEnglish text                  │
│ English text: Write /workspace/app.py            │
└──────────────┬──────────────────────────┘
               │
               ↓
┌──────────────────────────────────────────┐
│ ⏩ PreToolUse Hook (English text)               │
│                                          │
│ 1. English texttoolinformation (JSON stdin)            │
│ 2. English text ~/.claude/hooks/pre.sh  │
│ 3. English textpath, English text, English text                 │
│ 4. English text: allow/deny/ask             │
│                                          │
│ English text:                                    │
│ ├─ exit 0 = ✅ English text                      │
│ ├─ exit 1 = ⚠️ English text                │
│ └─ exit 2 = ❌ English text                     │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴──────┐
        │             │
    ❌ English text        ✅ English text
        │             │
        │             ↓
        │      ┌──────────────────┐
        │      │ English texttool         │
        │      │ fs.writeFile()  │
        │      │ execSync()      │
        │      └────────┬─────────┘
        │             │
        │             ↓
        │      ┌──────────────────────────┐
        │      │ ⏩ PostToolUse Hook      │
        │      │                         │
        │      │ 1. English textresult         │
        │      │ 2. English text       │
        │      │ 3. English textlog             │
        │      │ 4. English text             │
        │      │ 5. statisticsEnglish text             │
        │      └────────┬────────────────┘
        │             │
        └─────────────┼──────────┐
                      │          │
                      ↓          ↓
                  English textresult    English text
```

---

## Hook English textinputoutputEnglish text

### 📥 input (Hook English text JSON)

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

### 📤 output (Hook English text)

**example 1: English text**
```bash
exit 0  # English text
```

**example 2: English text**
```bash
echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "English text"}' >&2
exit 2  # English text
```

**example 3: English text**
```bash
echo '{"hookSpecificOutput": {"permissionDecision": "ask"}, "systemMessage": "RequiredEnglish text"}' >&2
exit 1  # English text
```

---

## Hook English text

### 1. PreToolUse Hook (English text)

**English text**: toolEnglish text

**English text**:
- ✅ pathEnglish text
- ✅ English text
- ✅ English textfileEnglish text
- ✅ English textsafetyEnglish text
- ✅ English textpipeline

**example**: English text
```bash
#!/bin/bash
input=$(cat)

# English textfile
command=$(echo "$input" | jq -r '.tool_input.command // empty')
if [[ "$command" == *"rm -rf"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}}' >&2
  exit 2
fi

exit 0
```

### 2. PostToolUse Hook (English text)

**English text**: toolEnglish text

**English text**:
- ✅ English textlog
- ✅ English text
- ✅ statisticsEnglish text
- ✅ English text
- ✅ resultEnglish text

**example**: English textfileEnglish text
```bash
#!/bin/bash
result=$(cat)

# English textlog
file_path=$(echo "$result" | jq -r '.tool_input.file_path // empty')
if [ ! -z "$file_path" ]; then
  echo "[$(date)] Modified: $file_path" >> ~/.claude/audit.log
fi
```

---

## actual Hook English text

### English text 1: English textsafetyEnglish text

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

# English textfilepath
file_path=$(echo "$tool_input" | jq -r '.file_path // empty')

# ❌ English text: pathEnglish text
if [[ "$file_path" == *".."* ]]; then
  echo '{"systemMessage": "❌ English text: English textpathEnglish text"}' >&2
  exit 2
fi

# ❌ English text: systemdirectory
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  echo '{"systemMessage": "❌ English text: English textsystemdirectory"}' >&2
  exit 2
fi

# ⚠️ English text: English textfile
if [[ "$file_path" == *.env ]] || [[ "$file_path" == *secret* ]]; then
  echo '{"systemMessage": "⚠️  English text: English textfile, RequiredEnglish text"}' >&2
  exit 1
fi

# ✅ English text
exit 0
```

### English text 2: Bash English text

```bash
#!/bin/bash
# ~/.claude/hooks/validate-bash.sh

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')

# ✅ quickEnglish textsafetyEnglish text
if [[ "$command" =~ ^(ls|pwd|echo|cat)(\s|$) ]]; then
  exit 0
fi

# ❌ English text
dangerous_patterns=(
  "rm -rf"
  "dd if=/dev/"
  "chmod 777"
  "> /dev/"
  "mkfs"
)

for pattern in "${dangerous_patterns[@]}"; do
  if [[ "$command" == *"$pattern"* ]]; then
    echo '{"systemMessage": "❌ English text"}' >&2
    exit 2
  fi
done

# ⚠️ English text
if [[ "$command" == sudo* ]] || [[ "$command" == su* ]]; then
  echo '{"systemMessage": "⚠️ RequiredEnglish text, RequiredEnglish text"}' >&2
  exit 1
fi

exit 0
```

### English text 3: English text Hook (Python)

```python
#!/usr/bin/env python3
# ~/.claude/hooks/approval-hook.py

import json
import sys
from datetime import datetime

def is_sensitive_operation(tool_input):
    """English text"""
    # dataEnglish text
    if 'database' in tool_input.get('file_path', ''):
        return True

    # configurationfile
    if tool_input.get('file_path', '').endswith(('.env', '.yml', '.yaml')):
        return True

    # English text
    if 'rm' in tool_input.get('command', ''):
        return True

    return False

def request_approval(operation_id, details):
    """requestEnglish text(actualEnglish textsystem API)"""
    # English text: actualEnglish textsystem
    print(f"📨 English textrequest: {operation_id}", file=sys.stderr)
    print(f"   English text: {details}", file=sys.stderr)
    # English text API English text
    return True  # English text

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get('tool_name', '')
    tool_input = input_data.get('tool_input', {})

    # English text
    if is_sensitive_operation(tool_input):
        # requestEnglish text
        operation_id = f"op_{input_data.get('session_id', 'unknown')}"
        approved = request_approval(operation_id, tool_input)

        if not approved:
            print(json.dumps({
                "hookSpecificOutput": {
                    "permissionDecision": "deny"
                },
                "systemMessage": "❌ English text"
            }), file=sys.stderr)
            sys.exit(2)

    sys.exit(0)

if __name__ == "__main__":
    main()
```

### English text 4: English textlog Hook (PostToolUse)

```bash
#!/bin/bash
# ~/.claude/hooks/audit-log.sh - PostToolUse Hook

result=$(cat)
tool_name=$(echo "$result" | jq -r '.tool_name')
file_path=$(echo "$result" | jq -r '.tool_input.file_path // empty')
command=$(echo "$result" | jq -r '.tool_input.command // empty')

LOG_FILE="$HOME/.claude/audit.log"

# English text
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

## Hook English textconfigurationEnglish text

### English textconfigurationfile

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

### configurationexplanation

```
hooks
├─ PreToolUse
│   ├─ matcher: English texttoolEnglish text ("Write|Edit", "Bash", "*" English text)
│   └─ hooks[]
│       ├─ type: "command" English text "prompt"
│       └─ command: English textpath
│
└─ PostToolUse
    └─ English text
```

---

## Hook English text

### English text 1: English text

```bash
# English textsafetyEnglish text
~/.claude/hooks/validate.sh
├─ English text /etc English textsystemdirectory
├─ English text (rm -rf)
└─ English text .env English textfile
```

### English text 2: English text

```bash
# English text
~/.claude/hooks/validate.sh
├─ English text src/ directoryEnglish text
├─ English text package.json
├─ English text git push
└─ English text changelog
```

### English text 3: English text

```python
# completeEnglish textpipeline
~/.claude/hooks/enterprise-hook.py
├─ English text
├─ English text → requestEnglish text
├─ English textresult
├─ English textsystem
├─ English textmanagementEnglish text
└─ generateEnglish text
```

### English text 4: dataEnglish text

```bash
# datasafetyEnglish text
~/.claude/hooks/data-safety.sh
├─ English textdataEnglish text (English text print dataset)
├─ English text API Key use
├─ English textdataEnglish text GDPR
└─ English textresultEnglish text
```

---

## Hook vs English text

### English text: Hard-coded vs Hook vs English textsystem

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│              │ English text   │ Hook English text    │ completeEnglish textsystem │
├──────────────┼──────────────┼──────────────┼──────────────┤
│ English text       │ ❌ English text        │ ✅ English text        │ ✅✅ English text     │
│ English text     │ ❌ English text        │ ✅ English text      │ ✅✅ English text     │
│ implementationEnglish text   │ ✅ English text      │ ✅ English text      │ ❌ English text      │
│ English text     │ ❌ English text        │ ✅ English text        │ ❌ English text        │
│ English text     │ ❌ English text        │ ✅ English text      │ ✅✅ English text    │
│ English text     │ ❌ English text        │ ✅ English textextension    │ ✅✅ English text    │
│ English text     │ ✅ English text      │ ✅ English text      │ ❌ English text      │
│ English text   │ ✅ Allowed      │ ✅ recommended      │ ❌ English text      │
│ English text   │ ❌ English text      │ ✅✅ English text    │ ✅ English text      │
└──────────────┴──────────────┴──────────────┴──────────────┘

Claude Code English text Hook English text:
✨ English text
✨ English text (English text)
✨ English text
✨ English textAllowedEnglish text Hook English text
```

---

## Hook English text vs English text

### ✅ English text

```
1. English text
   - English textRequiredEnglish text Claude Code English text
   - AllowedEnglish text

2. English text
   - English text vs English text
   - English text vs English text
   - English textextension

3. English textcompile
   - English text
   - English text
   - English text

4. English text
   - Bash / Python / English textlanguage
   - English text JSON English text
   - English texttest

5. English text
   - English text Hook English textAllowedEnglish text
   - English textAllowedEnglish text
   - English text
```

### ❌ English text

```
1. English textRequiredEnglish text
   - English text Bash
   - English text

2. English text
   - Hook English text
   - RequiredEnglish texttest

3. safetyRequiredEnglish text
   - Claude Code No Warranty Hook English textsafetyEnglish text
   - Hook English text
   - English textRequiredreviewEnglish text

4. English text
   - English text
   - English textmanagement(English text)
```

**English text**: English text, Hook English text.English text, English textRequiredEnglish textcompleteEnglish textsystem.

---

## Hook English text

### ✅ DO (English text)

```bash
# 1. English texterrorEnglish text
exit 2  # ❌ English text: English textexplanationEnglish text
echo '{"systemMessage": "❌ English text /etc directory"}' >&2  # ✅ English text: English text

# 2. quickfailure
if [[ "$path" == *".."* ]]; then
  exit 2
fi
# English textfailure

# 3. English textlog
echo "[$(date)] Hook English text: DENY - $reason" >> /tmp/hook-debug.log

# 4. English text edge cases
if [ -z "$file_path" ]; then
  exit 0  # English textpathEnglish text
fi

# 5. English text
patterns=("rm -rf" "chmod 777")  # English text
```

### ❌ DON'T (English text)

```bash
# 1. English text
subprocess.call(['curl', 'https://approval-server'])  # ❌ English text

# 2. English text Hook English textfile
rm /tmp/tempfile  # ❌ English text

# 3. English textinput
if [[ $path == $TRUSTED_DIR ]]  # ❌ English text

# 4. English text Hook English texttool
claude-code edit  # ❌ English text

# 5. English texterror
command  # ❌ English text || handle_error
```

---

## English text: Hook English text

```
Hook = English text + English text + logsystem

               toolEnglish text
                  ↓
           ┌──────────────┐
           │ PreToolUse   │ ← Hook English text
           │ Hook         │  ← English text
           └──────┬───────┘
                  ↓
            ✅ English text
             English text ❌ English text
                  ↓
           ┌──────────────┐
           │ English texttool     │
           └──────┬───────┘
                  ↓
           ┌──────────────┐
           │ PostToolUse  │ ← Hook English text
           │ Hook         │  ← log, English text
           └──────────────┘
```

**Hook English text**:
- 🔐 safetyEnglish text (English text)
- 🎯 English text (supportEnglish text)
- 📊 English text (English textlog)
- 🏢 English textextensionEnglish text (English text)

English text Claude Code English text Hook systemEnglish text!

---

**English text**:
- 📘 [completeEnglish text](./WHY_CLAUDE_CODE_ARCHITECTURE.md)
- 📗 [quickEnglish text](./CLAUDE_CODE_ARCHITECTURE_QUICK_GUIDE.md)
- 📙 [English text](./AI_SOLUTIONS_COMPARISON.md)
