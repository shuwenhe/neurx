# Claude Code English text

## English text Claude Code English text "Anthropic API + Node.js + Hook system" English text?

English text, English text.English text.

## English text

```
English text (CLI)
    ↓
Node.js CLI English text
    ↓
English text LLMRequest
    ├─ toolEnglish text (Write, Edit, Bash, Grep, Read, Glob, MultiEdit)
    └─ English textinformation (fileEnglish text, English text)
    ↓
English text Anthropic API
    ├─ English text: English text + toolEnglish text + English text
    └─ English text: Claude English text (toolEnglish text)
    ↓
English texttool
    ├─ PreToolUse Hook English text
    ├─ English text (fs, bash, English text)
    └─ PostToolUse Hook English text
    ↓
English textresultEnglish text
```

## English textprinciple

### principle 1: AI English text

```
English texttool:
English text → toolEnglish text → result

Claude Code:
English text → Claude(AI) → English text → toolEnglish text → result
```

**English text?**
- Claude English textlanguage, English text
- Claude AllowedinferenceEnglish texttruthfulEnglish text
- Claude English text
- Claude AllowedEnglish text

**English text**:
```
English text: "Create a user authentication system"

English texttool: English text
Claude Code:
  1. English text
  2. English text
  3. English textfile
  4. English text
  5. English textsafetyEnglish text, testEnglish text
```

### principle 2: API English text

```
English textuse Anthropic API English textmodel?
```

| English text | API English text | English textmodel |
|------|---------|---------|
| **English text** | ✅ English textmodel | ❌ English text |
| **English text** | ✅ English textuseEnglish text | ❌ English text |
| **English text** | ✅ English textmodel | ❌ English text |
| **English text** | ✅ Tool Use, Vision English text | ❌ English text |
| **English text** | ✅ English text | ❌ Requiredcompile |
| **English text** | ✅ English text | ❌ English text |

**Claude Code English text**:
1. Claude modelEnglish text, English textmodel
2. Anthropic English text Claude, English text
3. API English texttimeEnglish text
4. English textsupportEnglish text

### principle 3: Tool Use English text

Claude Code English textuse Tool Use English texttool.English text:

```
Tool Use English text:
┌─────────────────────────────┐
│  LLM (Claude)               │
│  ├─ English text            │
│  ├─ English textuseEnglish texttool        │
│  └─ generatetoolparameter            │
└────────┬────────────────────┘
         │
    JSON English text
    {
      "tool_name": "Write",
      "input": {
        "file_path": "...",
        "content": "..."
      }
    }
         │
┌────────┴────────────────────┐
│  English text (Claude Code)       │
│  ├─ English text JSON              │
│  ├─ English textsafetyEnglish text (Hook)      │
│  ├─ English text (fs, bash)    │
│  └─ English textresult              │
└─────────────────────────────┘
```

**English text?**
- English text LLM English textsupport Tool Use (OpenAI, Google English text)
- English textAllowedEnglish text LLM English text
- English texttoolEnglish text
- English textextension

### principle 4: Node.js English textrunEnglish text

```
English text Node.js?
```

**English text**:

| runEnglish text | English text | English text | Claude Code English text |
|------|------|------|------------------|
| **Node.js** | ✅ English text, English textstep I/O, npm | ❌ English text | ✅✅✅ English text |
| **Python** | ✅ English text, dataEnglish text | ❌ GIL, English text | ✅✅ AllowedEnglish text |
| **Rust** | ✅ English text, safety | ❌ compileEnglish text, English text | ❌ English text |
| **Go** | ✅ compileEnglish text, English text | ❌ English text | ✅ AllowedEnglish text |
| **C++** | ✅ English text | ❌ English text, compileEnglish text | ❌ English text |

**Node.js English text**:

1. **English textstep I/O**
   ```javascript
   // Node.js AllowedEnglish textfileEnglish text
   await Promise.all([
     fs.promises.writeFile('file1.js', code1),
     fs.promises.writeFile('file2.js', code2),
     fs.promises.writeFile('file3.js', code3)
   ]);
   ```

2. **quickEnglish text**
   ```javascript
   // English text
   const files = await glob('src/**/*.js');
   const result = await execAsync('npm run build');
   ```

3. **English textmanagement**
   ```bash
   npm install @anthropic-ai/sdk
   # English textcompleteEnglish text SDK
   ```

4. **English text**
   ```bash
   npm install -g @anthropic-ai/claude-code
   # Windows, macOS, Linux English text
   # English textcompile, English textconfigurationEnglish text
   ```

## Hook systemEnglish text

### English textRequired Hook system?

```
English text 1: safetyEnglish text
- Claude English text AI, English text
- English text
- RequiredEnglish text

English text 2: English text
- English textsafetyEnglish text
- English textpipeline
- English text

English text: Hook system
- English textAllowedEnglish text
- English text
- English text + configurationEnglish text
```

### Hook English text

```
toolEnglish text
    ↓
PreToolUse Hook (English text)
    ├─ pathEnglish text
    ├─ English text
    ├─ English textinformationEnglish text
    └─ English text: allow/deny/ask
    ↓
English texttool
    ├─ Write file
    ├─ Edit file
    ├─ Bash English text
    └─ ...
    ↓
PostToolUse Hook (English text)
    ├─ logEnglish text
    ├─ English text
    ├─ statisticsEnglish text
    └─ ...
```

**English text?**

```
English text:
┌──────────────────────────────┐
│ Claude Code English text           │
│ if (file_path.startsWith('/etc')) {
│   deny()
│ }                             │
└──────────────────────────────┘
❌ English text:
- English text
- English text
- English text

Hook English text:
┌──────────────────────────────┐
│ ~/.claude/hooks/validate.py   │
│ if file_path.startswith('/etc'):
│   deny()                      │
└──────────────────────────────┘
✅ English text:
- English text
- English text Claude Code English text
- supportEnglish text
- English textAllowedimplementationEnglish textpipeline
```

### Hook English textexample

```bash
# ~/.claude/hooks/pre-tool-use.sh
#!/bin/bash

# English text JSON stdin English texttoolEnglish text
tool_name=$(echo $input | jq -r '.tool_name')
file_path=$(echo $input | jq -r '.tool_input.file_path')

case "$tool_name" in
  Write|Edit)
    # English textdirectory
    if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /System/* ]]; then
      exit 2  # Deny
    fi
    ;;
  Bash)
    # English text
    if [[ "$command" == *"rm -rf"* ]]; then
      exit 2  # Deny
    fi
    ;;
esac

exit 0  # Allow
```

**English text**:

```javascript
// English text Hook: English textpipeline
class ApprovalHook {
  async onPreToolUse(toolCall) {
    if (toolCall.type === 'Write' && toolCall.path.includes('database')) {
      // dataEnglish textRequiredEnglish text
      const approval = await requestApproval(toolCall);
      return approval ? 'allow' : 'deny';
    }
    return 'allow';
  }

  async onPostToolUse(result) {
    // English textfileEnglish text
    await auditLog.record(result);

    // English textfile, English textmanagementEnglish text
    if (result.affectsSecurityFiles) {
      await notifyAdmins(result);
    }
  }
}
```

## English text

### English text A: English text (NeurX Code English text)

```
English text → English text AI → toolEnglish text → result
        (Ollama/LLaMA)
```

**English text**:
- ✅ English text
- ✅ English text API English text

**English text**:
- ❌ Required GPU(English textconfigurationEnglish text)
- ❌ modelEnglish text Claude
- ❌ English text
- ❌ English textmodel(GB English text)

### English text B: Anthropic API + C++ (NeurX Code English text)

```
English text → Anthropic API → Claude → toolEnglish text → result
       (C++ implementationtool)
```

**English text**:
- ✅ English text Claude model
- ✅ C++ English text
- ✅ English text GUI English text

**English text**:
- ❌ C++ compileEnglish text
- ❌ English text
- ❌ English text
- ❌ English textRequiredcompile

### English text C: Anthropic API + Node.js (Claude Code)

```
English text → Anthropic API → Claude → toolEnglish text → result
       (Node.js implementationtool, English textextension Hook)
```

**English text**:
- ✅ English text Claude model
- ✅ English text(npm install)
- ✅ quickEnglish text
- ✅ English text Hook system
- ✅ CLI English text
- ✅ English textcompile

**English text**:
- ❌ Required Node.js runEnglish text
- ❌ English text C++(English text)
- ❌ RequiredEnglish text

## English text

### English text 1: English text Tool Use English textlanguageEnglish text?

```
English text A: English textlanguage
Claude: "You should create a file app.py with this content..."
App: RequiredEnglish textlanguage, English textparameter
❌ English text, English text, English text

English text B: Tool Use (English text)
{
  "tool_name": "Write",
  "input": {
    "file_path": "app.py",
    "content": "..."
  }
}
App: English text, English text, English text
✅ English text, English text, English text
```

**Claude Code English text**: Tool Use, English text:
1. **English text** - JSON English text
2. **English text** - AllowedEnglish textparameter
3. **English text** - English text LLM English textsupport
4. **English texttest** - English texttoolEnglish texttest

### English text 2: English texttoolEnglish text API English text?

```
English text A: toolEnglish text Anthropic API
Claude Code English textRequiredEnglish texttoolEnglish text
❌ English text, English texthelpfulEnglish texttool

English text B: toolEnglish text (Claude Code)
Claude Code English texttool, English text Claude
✅ English text, English textAllowedEnglish texttool
```

**Claude Code English texttoolEnglish text** (English text):

```javascript
const tools = [
  {
    name: "Write",
    description: "Create or overwrite a file",
    input_schema: {
      type: "object",
      properties: {
        file_path: { type: "string" },
        content: { type: "string" }
      }
    }
  },
  {
    name: "Edit",
    description: "Modify file content",
    input_schema: {
      type: "object",
      properties: {
        file_path: { type: "string" },
        old_string: { type: "string" },
        new_string: { type: "string" }
      }
    }
  },
  // ... English texttool
];

// English text Claude API
const response = await anthropic.messages.create({
  model: "claude-opus",
  tools: tools,
  messages: [...]
});
```

### English text 3: English textsupportpluginsystem?

```
English text (7 English texttool)
          ↓
plugin 1 (security-guidance)
          ↓
plugin 2 (custom-commands)
          ↓
English textplugin
          ↓
completeEnglish textsystem
```

**pluginEnglish text**:

1. **English textextensionEnglish text**
   ```
   English text: Write, Edit, Bash, Read, Grep, Glob
   extension: dataEnglish text, API English text, testEnglish text
   ```

2. **English text**
   ```
   English textAllowedEnglish text ~/.claude/plugins/ English textplugin
   English text Claude Code English text
   ```

3. **English text**
   ```
   English texthelpfulEnglish textplugin
   English text
   English text
   ```

## English text: English text

Claude Code English text, English textimplementationEnglish text **English text**:

```
        Anthropic API
        (English text)
         ↑
         │ toolEnglish text
         │ (JSON)
         ↓
       Hook System
       (English text)
         ↑
         │ English textresult
         │
         ↓
      Node.js
      (English text)
         ├─ file I/O
         ├─ English text
         ├─ systemEnglish text
```

English text:
- **Anthropic API** - AI English text (English text)
- **Hook System** - safetyEnglish text (English text)
- **Node.js** - quickEnglish text (English text, English text)

English text Claude Code Allowed:
1. ✅ English text AI (Claude)
2. ✅ quickEnglish text (npm)
3. ✅ English text (Hook)
4. ✅ supportEnglish textextension (plugin)
5. ✅ English text (English text)

## English text NeurX Code English text

NeurX Code English text **Anthropic API + C++/Qt** English text:

| English text | Claude Code | NeurX Code |
|------|------------|-----------|
| AI English text | ✅ Anthropic API | ✅ Anthropic API |
| runEnglish text | Node.js | C++/Qt |
| English text | CLI | GUI |
| English text | npm (English textcompile) | compileEnglish text |
| Hook system | ✅ English text | 🔄 AllowedEnglish text |
| English textsupport | English text | English text |

**English text NeurX Code English text**:
1. English textimplementation Hook system(English textpluginEnglish text)
2. supportEnglish text
3. English textcompileEnglish textfileEnglish text
4. English text CLI English text
