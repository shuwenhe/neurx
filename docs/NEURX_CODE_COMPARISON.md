# NeurX Code fileEnglish text

## quickEnglish text

### English textimplementationEnglish text
```
Agent English text → English text English text Tool Use API → toolEnglish text
                          ↓
                    Bash (mkdir -p)
                    Write (filecontent)
                    Edit (English textcontent)
                          ↓
                    Hook English textsafetyEnglish text
                          ↓
                    filesystemEnglish text
```

### NeurX Code English text
```
Agent English text → English texttoolEnglish text → toolEnglish text
                    ↓
              WriteTool (C++)
              EditTool (C++)
              BashTool (C++)
                    ↓
              SandboxManager English text
                    ↓
              Qt fileEnglish text
```

## toolEnglish text

| English text | English textimplementation | NeurX Code |
|------|------------|-----------|
| **English textfile** | Write tool | WriteTool::execute() |
| **English textfile** | Edit tool | EditTool::execute() |
| **English text** | MultiEdit tool | MultiEditTool::execute() |
| **English textdirectory** | Bash: mkdir -p | English text WriteTool English text |
| **English text** | Bash tool | BashTool::execute() |
| **English textfile** | Glob tool | GlobTool::execute() |
| **searchcontent** | Grep tool | GrepTool::execute() |
| **English textfile** | Read tool | ReadTool::execute() |

## English text

### English textfile - English textimplementation

**English text API response**:
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

**English textimplementationEnglish text**:
```bash
# English textdirectoryEnglish text, English textfailure!
echo "print('Hello')" > /workspace/main.py
# Error: /workspace English text

# English textstep
mkdir -p /workspace  # Step 1: English text Bash toolEnglish textdirectory
echo "print('Hello')" > /workspace/main.py  # Step 2: English text Write toolEnglish textfile
```

### English textfile - NeurX Code

**request**:
```python
# Agent English text WriteTool
WriteTool.execute({
    "file_path": "/workspace/main.cpp",
    "new_text": "#include <iostream>\nint main() { }"
})
```

**English textimplementation** (src/tools/NeurXStandardTools.cpp):
```cpp
bool WriteTool::execute(const QJsonObject &parameters, QJsonObject &output) {
    QString filePath = parameters.value("file_path").toString();
    QString content = parameters.value("new_text").toString();

    // ✅ English textdirectory
    QDir dir;
    dir.mkpath(QFileInfo(filePath).absolutePath());

    // English textpathsafety
    QString safePath = safePath(filePath);
    if (safePath.isEmpty()) {
        return false;  // pathEnglish text
    }

    // English textfile
    QFile file(safePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    file.write(content.toUtf8());
    file.close();

    return true;
}
```

## safetyEnglish text

### NeurX Code - Hook system

```python
# /path/to/hook.py - English texttoolEnglish textrun
import json, sys

input_data = json.load(sys.stdin)
tool_name = input_data["tool_name"]
tool_input = input_data["tool_input"]

if tool_name == "Write":
    file_path = tool_input["file_path"]

    # ❌ English textpathEnglish text
    if ".." in file_path:
        sys.exit(2)  # Deny

    # ❌ English textsystemdirectory
    if file_path.startswith("/etc") or file_path.startswith("/sys"):
        sys.exit(2)  # Deny

    # ⚠️ English textfile
    if ".env" in file_path:
        sys.exit(1)  # Ask user

sys.exit(0)  # Allow
```

**configuration**(.neurx/config.json):
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
        // English text
        QString absPath = QDir::cleanPath(QFileInfo(filePath).absoluteFilePath());

        if (!absPath.startsWith(m_workspaceRoot)) {
            qWarning() << "Path outside workspace:" << filePath;
            return false;  // ❌ English text
        }

        return true;  // ✓ English text
    }
};
```

**use**(src/bridge/AgentController.cpp):
```cpp
void AgentController::setWorkspacePath(const QString &workspacePath) {
    m_sandboxManager->setWorkspaceRoot(workspacePath);
    m_sandboxManager->setFileSystemAccessMode(
        SandboxManager::FileSystemAccessMode::Read |
        SandboxManager::FileSystemAccessMode::Write
    );
}
```

## English text

### 1. fileEnglish text

**NeurX Code**:
- ❌ Write toolEnglish textdirectory
- ✅ English textuse `Bash` toolEnglish text `mkdir -p`
- RequiredEnglish textstepEnglish text

```
NeurX Code pipeline:
Bash mkdir -p → Write file
    ↓             ↓
  Step 1       Step 2
```

**NeurX Code**:
- ✅ WriteTool English textdirectory
- ✅ English text
- English text

```
NeurX Code pipeline:
WriteTool (English text mkdir)
    ↓
English textstepEnglish text
```

### 2. safetyEnglish text

**NeurX Code**:
```
toolEnglish text
  ↓ (Hook English text)
Pre Validation
  ↓
English texttool
  ↓ (Hook English text)
Post Validation
```

**NeurX Code**:
```
toolEnglish text
  ↓
SandboxManager English text
  ↓
English texttool
```

### 3. implementationEnglish text

| English text | NeurX Code | NeurX Code |
|------|------------|-----------|
| **language** | JavaScript/Node.js | C++/Qt |
| **runEnglish text** | CLI tool | Qt GUI English text |
| **API English text** | English text API | English textimplementation |
| **English text** | English text Hook English text | C++ SandboxManager |
| **English text** | English text | Qt English text/English text |

## toolEnglish text

### NeurX Code toolEnglish text

```
NeurX output Write toolEnglish text
          ↓
   NeurX Code English text
          ↓
   English text Hook (Python/Bash)
          ↓
   English text ✓
          ↓
   Node.js English textfileEnglish text
          ↓
   fs.writeFileSync()
          ↓
   English textresultEnglish text NeurX
```

### NeurX Code toolEnglish text

```
Agent English text WriteTool
          ↓
AgentToolRegistry English text
          ↓
NeurXStandardToolFactory English texttool
          ↓
WriteTool::execute() English text
          ↓
safePath() English textpath
          ↓
SandboxManager English text
          ↓
QFile English text
          ↓
Agent English textresult
```

## implementationEnglish text

### English text NeurX Code English text

1. ✅ **Hook system** → English textsafetyEnglish text
   - NeurX Code English text SandboxManager implementation

2. ✅ **Bash tool** → English text
   - NeurX Code implementationEnglish text BashTool

3. ✅ **MultiEdit tool** → English text
   - NeurX Code implementationEnglish text MultiEditTool

4. ❌ **English textstepEnglish text** → English text NeurX English text
   - WriteTool English textdirectory(English text!)

### NeurX Code English textoptimize

1. ✅ **English text mkdir** - English textstepEnglish text
2. ✅ **C++ English textimplementation** - English text API
3. ✅ **Qt English text** - English text GUI English text
4. ✅ **SandboxManager** - English textmanagementEnglish text

## completeEnglish textexample

### English text: English text React English text

**NeurX Code English text**(3 step):

```json
Step 1: Bash toolEnglish textdirectory
{
  "tool_name": "Bash",
  "input": {"command": "mkdir -p src/components src/pages"}
}

Step 2: Write toolEnglish text package.json
{
  "tool_name": "Write",
  "input": {
    "file_path": "package.json",
    "content": "{\"name\": \"app\", \"version\": \"1.0\"}"
  }
}

Step 3: Write toolEnglish text src/App.jsx
{
  "tool_name": "Write",
  "input": {
    "file_path": "src/App.jsx",
    "content": "export default function App() { return <div>Hello</div> }"
  }
}
```

**NeurX Code English text**(1 step + English text):

```python
# Agent English text WriteTool 3 English text
# English textRequiredEnglish textdirectory - WriteTool English text

write_tool.execute({
    "file_path": "src/components/Button.cpp",
    "new_text": "..."
})  # ✓ English text src/components directory

write_tool.execute({
    "file_path": "include/Button.h",
    "new_text": "..."
})  # ✓ English text include directory
```

## English text

**NeurX Code**:
- use English text API English text Tool Use English text
- Hook systemEnglish textsafetyEnglish text
- RequiredEnglish text mkdir English textdirectory
- CLI toolEnglish text

**NeurX Code**:
- C++/Qt English textimplementation
- SandboxManager English textsafetyEnglish text
- WriteTool English textdirectory
- GUI English text

English text**toolmodel**, English text NeurX Code **English text**!
