# NeurX Code English text

## fileEnglish textfile

### 🔍 fileEnglish text

```
/Users/feifei/agent/neurx-code-reference/
├── plugins/
│   ├── hookify/                          # Hook systemimplementation
│   │   ├── core/
│   │   │   └── rule_engine.py           # English text(English textfileEnglish text)
│   │   └── hooks/
│   │       ├── security_reminder_hook.py # safetyEnglish text
│   │       └── ...
│   │
│   ├── plugin-dev/                       # pluginEnglish text
│   │   ├── skills/hook-development/
│   │   │   └── examples/
│   │   │       ├── validate-write.sh    # ✅ Write toolEnglish text
│   │   │       ├── validate-bash.sh     # ✅ Bash toolEnglish text
│   │   │       └── ...
│   │   └── SKILL.md
│   │
│   ├── security-guidance/                # safetyEnglish textplugin
│   │   └── hooks/
│   │       └── security_reminder_hook.py # ✅ English texttoolinputEnglish textcontent
│   │
│   └── ...
│
├── examples/
│   ├── hooks/
│   │   └── bash_command_validator_example.py  # Bash English text
│   ├── mdm/
│   └── settings/
│
├── scripts/                               # English textdirectory
│   └── ...
│
└── docs/                                  # English text
    └── ...
```

## English text

### 1. Write toolEnglish text - validate-write.sh

**path**: `English text/plugins/plugin-dev/skills/hook-development/examples/validate-write.sh`

**English text**: English text Write toolEnglish text PreToolUse English text

**English text**:
```bash
#!/bin/bash
# English textfilepath
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# English textpathEnglish text
if [[ "$file_path" == *".."* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}}'
  exit 2  # English text
fi

# English textsystemdirectory
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}}'
  exit 2  # English text
fi
```

**English text**:
- ✅ Hook English text JSON stdin English textinput
- ✅ English text `.tool_input.file_path`
- ✅ English text `permissionDecision: "deny"` English text
- ✅ English text 2 English text

### 2. Bash toolEnglish text - validate-bash.sh

**path**: `English text/plugins/plugin-dev/skills/hook-development/examples/validate-bash.sh`

**English text**: English text Bash toolEnglish text

**English text**:
```bash
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# English text
if [[ "$command" == *"rm -rf"* ]]; then
  exit 2  # English text
fi

if [[ "$command" == *"chmod 777"* ]]; then
  exit 2  # English text
fi

if [[ "$command" == *"dd if=/dev/"* ]]; then
  exit 2  # English text
fi

exit 0  # English text
```

**English text**:
- ✅ Bash toolparameterEnglish text `.tool_input.command`
- ✅ English text
- ✅ English text 0 English text

### 3. English text - rule_engine.py

**path**: `English text/plugins/hookify/core/rule_engine.py`

**English text**: implementationEnglish textevaluationEnglish text

**English text**(English text 235 English text):
```python
elif tool_name in ['Write', 'Edit']:
    if field == 'content':
        # Write use 'content', Edit use 'new_string'
        return tool_input.get('content') or tool_input.get('new_string', '')
    elif field == 'new_text' or field == 'new_string':
        return tool_input.get('new_string', '')
    elif field == 'old_text' or field == 'old_string':
        return tool_input.get('old_string', '')
    elif field == 'file_path':
        return tool_input.get('file_path', '')
```

**English text**:
- ✅ Write English text Edit toolEnglish textparameterEnglish text
- ✅ English text tool_input English text
- ✅ English textsupportEnglish text

### 4. safetyEnglish text - security_reminder_hook.py

**path**: `English text/plugins/security-guidance/hooks/security_reminder_hook.py`

**English text**: English textfileEnglish textsafetyEnglish text

**English text**(English text 429 English text):
```python
def extract_content_from_input(tool_name, tool_input):
    """English texttoolinputEnglish textcontentEnglish text"""
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

**English text**:
- ✅ English texttoolEnglish textcontentEnglish text
- ✅ MultiEdit English text edits English text
- ✅ English textcontent

### 5. Bash English textexample - bash_command_validator_example.py

**path**: `English text/examples/hooks/bash_command_validator_example.py`

**English text**: English text Bash English text

**English text**:
```python
def _validate_command(command: str) -> list[str]:
    """English text bash English text"""
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
        sys.exit(2)  # English text
```

**English text**:
- ✅ completeEnglish text
- ✅ English text sys.stdin English text JSON
- ✅ English text sys.stderr outputEnglish text
- ✅ English text(0=English text, 2=English text)

## Hook systemEnglish text

### Hook configurationEnglish text

**English text `.neurx/config.json` English text**:
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

### Hook input/outputEnglish text

**input(English textimplementation)**:
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

**output(English text Hook English text)**:
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "deny"
  },
  "systemMessage": "Path traversal detected"
}
```

## English texttoolparameterEnglish text

### Write toolparameter

```bash
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "string",    # English text
    "content": "string"       # English text
  }
}
```

### Edit toolparameter

```bash
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "string",    # English text
    "old_string": "string",   # English text
    "new_string": "string"    # English text
  }
}
```

### MultiEdit toolparameter

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

### Bash toolparameter

```bash
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "string"       # English text, English text "mkdir -p src/app"
  }
}
```

## English text

### 1. Hook English text

```
toolEnglish textrequest
    ↓
PreToolUse English text
  ├─ English texttoolEnglish text
  ├─ AllowedEnglish text
  └─ English text: allow/deny/ask
    ↓
English texttool (English text)
  └─ actualfileEnglish text
    ↓
PostToolUse English text (English text)
  ├─ English textresult
  └─ English text: log, English text
    ↓
English textresultEnglish text
```

### 2. Hook English text

```bash
exit 0  # ✅ English text - toolEnglish text
exit 1  # ⚠️ English text - RequiredEnglish text(English text stderr)
exit 2  # ❌ English text - English texttoolEnglish text(English text stderr)
```

### 3. safetyEnglish text

```
Layer 1: Hook English text
  - pathEnglish text(.. English text)
  - systemdirectoryEnglish text(/etc, /sys English text)
  - English textfileEnglish text(.env, secrets English text)

Layer 2: English text
  - English text
  - English text(AND/OR)
  - English text(block > warn > allow)

Layer 3: English text
  - English text
  - English textinformation
  - English text
```

## English text

### quickEnglish textfileEnglish textpipeline

1. **English textconfiguration**:
   ```bash
   cat ~/.neurx/config.json
   ```

2. **English text Hook English text**:
   ```bash
   ls English text/plugins/plugin-dev/skills/hook-development/examples/
   ```

3. **runexampleEnglish text**:
   ```bash
   # English texttest Write English text
   echo '{
     "hook_event_name": "PreToolUse",
     "tool_name": "Write",
     "tool_input": {"file_path": "/tmp/test.txt", "content": "hello"}
   }' | bash English text/plugins/plugin-dev/skills/hook-development/examples/validate-write.sh
   ```

4. **English text**:
   ```bash
   grep -r "def _rule_matches" English text/plugins/
   ```

## English text

| file | English text | English text |
|------|------|------|
| validate-write.sh | plugins/plugin-dev/skills/hook-development/examples/ | Write toolEnglish text |
| validate-bash.sh | plugins/plugin-dev/skills/hook-development/examples/ | Bash toolEnglish text |
| rule_engine.py | plugins/hookify/core/ | English text |
| security_reminder_hook.py | plugins/security-guidance/hooks/ | safetyEnglish text |
| bash_command_validator_example.py | examples/hooks/ | Bash English textexample |

## English text

- 📘 [NeurX fileEnglish text](./NEURX_FILE_CREATION_EXPLAINED.md)
- 📗 [NeurX Code English text](./NEURX_CODE_COMPARISON.md)
- 📙 [NeurX Code English texttool](./NEURX_STANDARD_TOOLS.md)
