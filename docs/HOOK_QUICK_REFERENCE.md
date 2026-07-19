# Hook system - quickEnglish text

## English text: Hook English text?

**Hook English texttoolEnglish text/English textrunEnglish text, English text, English text.**

```
toolEnglish text
    ↓
🔒 PreToolUse Hook (English text)
    ↓
    ├─ ❌ English text
    ├─ ✅ English text
    └─ ⚠️ English text
    ↓
English texttool (English text)
    ↓
📋 PostToolUse Hook (English textresult)
```

---

## Hook English text

| English text | example |
|------|------|
| **safetyEnglish text** | English text `/etc` directory |
| **English text** | English text `rm -rf` |
| **English textfile** | English text `.env` fileEnglish text |
| **English textpipeline** | dataEnglish textRequiredEnglish text |
| **English textlog** | English text |
| **English text** | English text |

---

## Hook English text

### 1️⃣ PreToolUse (English text)

```
Claude: English text /tmp/app.py
        ↓
    Hook English text
    ├─ English textpathEnglish text? → NO ✅
    ├─ English textsystemdirectory? → NO ✅
    ├─ English textfile? → NO ✅
        ↓
    result: English text
```

**AllowedEnglish text**:
- `exit 0` = ✅ English text
- `exit 1` = ⚠️ English text
- `exit 2` = ❌ English text

### 2️⃣ PostToolUse (English text)

```
toolEnglish text
        ↓
    Hook English textresult
    ├─ log: [2024-06-04] Modified /tmp/app.py
    ├─ English text: 📧 English text
    └─ statistics: 📊 English text
        ↓
    English text
```

---

## actual Hook English text

### English text 1: English text(Bash)

```bash
#!/bin/bash
# ~/.claude/hooks/validate.sh

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# ❌ English text
if [[ "$command" == *"rm -rf"* ]]; then
  exit 2
fi

# ✅ English text
exit 0
```

### English text 2: English text(Bash)

```bash
#!/bin/bash

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

# ⚠️ English text: English text .env file
if [[ "$file_path" == *.env ]]; then
  echo '{"systemMessage": "English text .env file, RequiredEnglish text"}' >&2
  exit 1  # English text
fi

exit 0
```

### English text 3: English textlog(Bash)

```bash
#!/bin/bash
# PostToolUse Hook

result=$(cat)
tool_name=$(echo "$result" | jq -r '.tool_name')
file_path=$(echo "$result" | jq -r '.tool_input.file_path // empty')

# English textlog
echo "[$(date)] $tool_name: $file_path" >> ~/.claude/audit.log
```

### English text 4: English text(Python)

```python
#!/usr/bin/env python3

import json, sys

def is_sensitive(tool_input):
    # English textdataEnglish text
    return 'database' in tool_input.get('file_path', '')

input_data = json.load(sys.stdin)

if is_sensitive(input_data['tool_input']):
    # English textrequest
    print('{"systemMessage": "RequiredmanagementEnglish text"}', file=sys.stderr)
    sys.exit(1)  # English text

sys.exit(0)  # English text
```

---

## Hook English textconfiguration

### configurationfileEnglish text

```
~/.claude/config.json
```

### configurationexample

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

**explanation**:
- `matcher`: English texttool (`Bash`, `Write`, `*` English text)
- `type`: `command` English text `prompt`
- `command`: English textpath

---

## Hook English textinputEnglish text

### JSON inputexample

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

**English text**:
```bash
tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path')
command=$(echo "$input" | jq -r '.tool_input.command')
```

---

## Hook English textoutputEnglish text

### English text

```bash
echo '{"systemMessage": "English text"}' >&2
exit 2
```

### English text

```bash
echo '{"systemMessage": "RequiredEnglish text"}' >&2
exit 1
```

### English text

```bash
exit 0
```

---

## Hook English text

### ✅ AllowedEnglish text

```
1. English textpathsafetyEnglish text
   ├─ English textpathEnglish text (..)
   ├─ English textsystemdirectory (/etc, /sys)
   └─ English text

2. English textsafety
   ├─ English text rm -rf
   ├─ English text chmod 777
   └─ English text dd English text

3. English textlog
   ├─ English text
   ├─ timeEnglish text
   └─ English textauthorinformation

4. English text
   ├─ English text
   ├─ Slack English text
   └─ SMS English text

5. English textsystem
   ├─ requestEnglish text
   ├─ English textresult
   └─ English textinformation

6. datasafetyEnglish text
   ├─ English textinformationEnglish text
   ├─ English text
   └─ English text
```

### ❌ English text

```
1. English textfileEnglish textdata
   ❌ rm /tmp/file
   ❌ git push

2. English text
   ❌ English text API(English text)
   ❌ dataEnglish textquery

3. English text Claude Code tool
   ❌ English text

4. English text Hook English text
   ❌ English text

5. English texterror
   ❌ English text
```

---

## Hook English text

### English text 1: English text

```
English texterror
├─ English text
├─ English textfile
└─ English text
```

### English text 2: English text

```
English textsafetyEnglish text
├─ English text package.json
├─ English text
└─ English text
```

### English text 3: English text

```
English textpipeline
├─ dataEnglish textRequiredEnglish text
├─ English textRequiredreview
└─ completeEnglish textlog
```

### English text 4: English text

```
completeEnglish textsystem
├─ GDPR/HIPAA English text
├─ English text
├─ English textmanagement
└─ English textmonitoring
```

---

## Hook vs English text

```
❌ English text
if (path.startsWith("/etc")) {
  deny();  // English text
}
English text:
- English text
- English text
- English texthelpfulEnglish text

✅ Hook English text
if [[ "$path" == /etc/* ]]; then
  exit 2
fi  # English text
English text:
- English text
- English text
- English textAllowedEnglish text
```

---

## quickstart: English text Hook

### Step 1: English text Hook file

```bash
mkdir -p ~/.claude/hooks
touch ~/.claude/hooks/validate.sh
chmod +x ~/.claude/hooks/validate.sh
```

### Step 2: English text Hook English text

```bash
cat > ~/.claude/hooks/validate.sh << 'EOF'
#!/bin/bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# English textsystemdirectory
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  exit 2
fi

exit 0
EOF
```

### Step 3: configuration Claude Code

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

### Step 4: test

```bash
# English text Claude Code English textfile
claude
# input: Create a file in /tmp/test.py
# result: ✅ English text (English textdirectory)

# English text
# input: Create a file in /etc/test.py
# result: ❌ English text (Hook English text!)
```

---

## English text Hook error

### ❌ error 1: English text `exit` English text

```bash
#!/bin/bash
if [[ "$path" == /etc/* ]]; then
  # English text: English text exit, English text
fi
# English text!
exit 0
```

✅ English text:
```bash
if [[ "$path" == /etc/* ]]; then
  exit 2  # English text, English text
fi
exit 0
```

### ❌ error 2: JSON English texterror

```bash
# English text: English text JSON
echo '{"message": "error"}' >&2  # English text
exit 2
```

✅ English text:
```bash
# use jq English text JSON English text
echo '{"systemMessage": "error"}' >&2
exit 2
```

### ❌ error 3: English text

```bash
# English text: English text file_path
if [[ "$file_path" == /etc/* ]]; then  # English text
```

✅ English text:
```bash
if [ -z "$file_path" ]; then
  exit 0  # English textpathEnglish text
fi

if [[ "$file_path" == /etc/* ]]; then
  exit 2
fi
```

---

## English text

| English text | explanation |
|------|------|
| **Hook English text** | English texttoolEnglish text/English textrunEnglish text |
| **English text** | PreToolUse (English text) + PostToolUse (English text) |
| **English text** | safetyEnglish text + English text + English textlog |
| **English textRequired** | English text, English text |
| **English text** | Hook English text, English text |
| **English text** | English texterrorinformation + quickfailure + English text |

**English text**: Hook English text Claude Code English texthelpfulEnglish text, English text!

---

**English text**:
- 📘 [complete Hook systemEnglish text](./HOOK_SYSTEM_EXPLAINED.md)
- 📗 [English text](./WHY_CLAUDE_CODE_ARCHITECTURE.md)
- 📙 [English text](./AI_SOLUTIONS_COMPARISON.md)
