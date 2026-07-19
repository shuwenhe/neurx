# FileCreationTool useEnglish text

## quickstart

### 1. toolEnglish text

English text Agent systemEnglish text FileCreationTool:

```cpp
#include "tools/FileCreationTool.h"

// English texttoolEnglish text
auto fileTool = std::make_unique<FileCreationTool>(workspaceRoot);

// English textmanagementEnglish text(English textrecommended)
fileTool->setSandboxManager(sandboxManager);

// English textcheckpointmanagementEnglish text(English text)
fileTool->setCheckpointManager(checkpointManager);

// English texttoolEnglish text
toolRegistry->registerTool(fileTool.get());
```

### 2. English text

#### English textfile

```json
{
  "tool": "file_creation",
  "operation": "create_file",
  "path": "src/main.py",
  "content": "#!/usr/bin/env python3\nprint('Hello, World!')",
  "create_dirs": true,
  "line_ending": "lf"
}
```

**response**:
```json
{
  "bytes_written": 39,
  "dirs_created": true,
  "filepath": "src/main.py",
  "line_ending": "lf",
  "lint": {
    "path": "src/main.py",
    "status": "ok"
  }
}
```

#### English textfile

```json
{
  "tool": "file_creation",
  "operation": "write_file",
  "path": "config.json",
  "content": "{\"version\": \"2.0\"}"
}
```

English text: `write_file` default `overwrite=true`

#### English textfile

```json
{
  "tool": "file_creation",
  "operation": "create_batch",
  "files": [
    {
      "path": ".gitignore",
      "content": "*.pyc\n__pycache__/\n.DS_Store"
    },
    {
      "path": "README.md",
      "content": "# My Project\n\nDescription here."
    },
    {
      "path": "src/app.py",
      "content": "#!/usr/bin/env python3\nimport sys\n\nif __name__ == '__main__':\n    pass"
    }
  ]
}
```

**response**:
```json
{
  "total": 3,
  "succeeded": 3,
  "failed": 0,
  "files": [
    {"filepath": ".gitignore", "bytes_written": 33, "dirs_created": false},
    {"filepath": "README.md", "bytes_written": 30, "dirs_created": false},
    {"filepath": "src/app.py", "bytes_written": 62, "dirs_created": true}
  ]
}
```

---

## parameterEnglish text

### English textparameter

#### `operation` (English text)
- **English text**: string
- **English text**: `"create_file"` | `"write_file"` | `"create_batch"`
- **explanation**: English text

#### `path` (English text, English text create_batch English text)
- **English text**: string
- **example**: `"src/hello.py"`, `"config/app.json"`
- **explanation**: English textdirectoryEnglish textfilepath
- **English text**: English textpathEnglish text

#### `content` (English text)
- **English text**: string
- **example**: `"print('hello')"`
- **explanation**: English textfilecontent
- **English text**: English textfileEnglish text 50MB

#### `overwrite` (English text)
- **English text**: boolean
- **defaultEnglish text**:
  - `create_file`: `false` (English textfile)
  - `write_file`: `true` (defaultEnglish text)
- **explanation**: English textfile

#### `create_dirs` (English text)
- **English text**: boolean
- **defaultEnglish text**: `true`
- **explanation**: English textdirectory
- **example**: English text `"deep/nested/file.txt"` English text `deep/` English text `deep/nested/`

#### `line_ending` (English text)
- **English text**: string
- **English text**: `"auto"` | `"lf"` | `"crlf"`
- **defaultEnglish text**: `"auto"`
- **explanation**:
  - `"auto"`: English textfileEnglish text, defaultuse `"lf"`
  - `"lf"`: Unix English text (`\n`)
  - `"crlf"`: Windows English text (`\r\n`)

#### `preserve_existing` (English text)
- **English text**: boolean
- **defaultEnglish text**: `true`
- **explanation**: English textfileEnglish textdata(English text, English text)

#### `files` (English text)
- **English text**: array of objects
- **English text**:
  ```json
  {
    "path": "string (English text)",
    "content": "string (English text, defaultEnglish text)",
    "overwrite": "boolean (English text)",
    "create_dirs": "boolean (English text)"
  }
  ```
- **explanation**: English textfileEnglish text

---

## responseEnglish text

### successresponse

```json
{
  "filepath": "path/to/file.txt",
  "bytes_written": 1024,
  "dirs_created": true,
  "line_ending": "lf",
  "lint": {
    "path": "path/to/file.txt",
    "status": "ok"
  }
}
```

### English textexplanation

| English text | English text | explanation |
|------|------|------|
| `filepath` | string | actualEnglish textfilepath |
| `bytes_written` | int | English text |
| `dirs_created` | boolean | English textdirectory |
| `line_ending` | string | useEnglish text(`"lf"` English text `"crlf"`)|
| `lint` | object | English textresult |
| `error` | string | errorinformation(English textfailureEnglish text) |

### errorresponse

```json
{
  "error": "File already exists. Use overwrite=true to replace."
}
```

```json
{
  "error": "Path traversal detected"
}
```

```json
{
  "error": "Cannot write to protected path: /etc/passwd"
}
```

---

## English text

### English text 1: English text Python English text

```json
{
  "operation": "create_batch",
  "files": [
    {
      "path": "pyproject.toml",
      "content": "[tool.poetry]\nname = \"my-app\"\nversion = \"0.1.0\"\n"
    },
    {
      "path": "src/__init__.py",
      "content": "\"\"\"My Application\"\"\"\n__version__ = \"0.1.0\"\n"
    },
    {
      "path": "src/main.py",
      "content": "#!/usr/bin/env python3\n\ndef main():\n    print('Hello')\n\nif __name__ == '__main__':\n    main()\n"
    },
    {
      "path": "tests/__init__.py",
      "content": ""
    },
    {
      "path": "tests/test_main.py",
      "content": "import unittest\n\nclass TestMain(unittest.TestCase):\n    pass\n"
    }
  ]
}
```

### English text 2: English textconfigurationfile (JSON)

```json
{
  "operation": "create_file",
  "path": "config.json",
  "content": "{\n  \"version\": \"1.0\",\n  \"debug\": false,\n  \"port\": 8080\n}",
  "line_ending": "lf"
}
```

responseEnglish text JSON English textresult:
```json
{
  "bytes_written": 67,
  "lint": {
    "status": "ok"
  }
}
```

### English text 3: English textfileEnglish text

```json
{
  "operation": "write_file",
  "path": "data.txt",
  "content": "new content",
  "preserve_existing": true
}
```

English text `data.txt` English textuse CRLF, English textcontentEnglish text CRLF.

### English text 4: English textfileEnglish textcheckpoint

```json
{
  "operation": "write_file",
  "path": "src/app.py",
  "content": "# Updated version",
  "overwrite": true
}
```

systemEnglish text:
1. English text `src/app.py` English textcheckpointEnglish text
2. English textcontent
3. English textsuccessresponseEnglish textcheckpoint ID

---

## English text LLM English textexample

### Agent promptEnglish text

```
English textAlloweduse file_creation toolEnglish textfile.

toolsupportEnglish text:
- create_file: English textfile(English text)
- write_file: English textfile
- create_batch: English textfile

example:
1. English text Python file:
   {
     "tool": "file_creation",
     "operation": "create_file",
     "path": "hello.py",
     "content": "print('Hello, World!')"
   }

2. English textfileEnglish text, use create_batch English text:
   {
     "tool": "file_creation",
     "operation": "create_batch",
     "files": [...]
   }

English text:
- pathEnglish textdirectory
- defaultEnglish textdirectory
- English textfileEnglish text
- English textsystemEnglish textfile
```

---

## errorEnglish text

### English texterrorEnglish text

| error | English text | English text |
|-----|------|------|
| "File already exists" | fileEnglish text `overwrite=false` | English text `overwrite: true` English textfile |
| "Path traversal detected" | pathEnglish text | useEnglish textpath, English text `../` |
| "Path write not allowed" | English text | English textconfiguration |
| "Cannot write to protected path" | English textsystempath | English textpath |
| "Failed to create temporary file" | English text | English textfileEnglish text |

### English text

English textlog:
```cpp
// English texttoolEnglish text
fileCreationTool->setVerboseLogging(true);
```

English text `lint` English text:
```json
{
  "lint": {
    "status": "error",
    "error": "JSON Error at 42: Expected '}'"
  }
}
```

---

## English text

### ✅ recommendedEnglish text

1. **useEnglish text**
   ```json
   {"operation": "write_file", "path": "config.json", "content": "..."}
   ```
   English textstepEnglish text

2. **English textfile**
   ```json
   {"operation": "create_batch", "files": [...]}
   ```
   English text

3. **English text**
   ```json
   {"line_ending": "lf"}  // English text Unix/Linux
   {"line_ending": "crlf"}  // English text Windows
   ```

4. **English textcheckpoint**
   ```json
   {"operation": "write_file", "path": "important.txt", "content": "..."}
   // systemEnglish text
   ```

5. **English text**
   ```json
   {"path": "config.json", "content": "{...}"}
   // responseEnglish text lint result
   ```

### ❌ English text

1. **English textpathEnglish text**
   ```json
   {"path": "../../etc/passwd"}  // English text
   ```

2. **English textfile**
   ```json
   {"content": "..."}  // > 50MB English text
   ```

3. **English texterrorresponse**
   ```cpp
   // English text result.isError
   if (result.isError) { handle_error(); }
   ```

4. **English textfileEnglish text**
   ```cpp
   // write_file English text read_file English text
   // useEnglish text bytes_written English textsuccess
   ```

---

## English textoptimize

### English textfileEnglish text

English text 100+ English textfile, use `create_batch`:

```cpp
// ❌ English text: 100 English textrequest
for (int i = 0; i < 100; i++) {
    toolRegistry->execute("file_creation", createFileOp());
}

// ✅ English text: 1 English textrequest
QJsonArray files;
for (int i = 0; i < 100; i++) {
    files.append(fileSpec(i));
}
batchOp["files"] = files;
toolRegistry->execute("file_creation", batchOp);
```

### English textfileEnglish text

English text 50MB English textfile:

```json
{
  "operation": "create_file",
  "path": "large_data.bin",
  "content": "...49MB content..."
}
```

English textfile, English text:
1. useEnglish texttool(`dd`, `split`)
2. English textimplementationEnglish text API(English textimplementation)

---

## English text

### English text

- [ ] filepathEnglish text
- [ ] English textdirectoryEnglish textconfiguration
- [ ] English textmanagementEnglish text(English textuse)
- [ ] English text
- [ ] directoryEnglish text
- [ ] fileEnglish text

### English text

```cpp
// English texttoolEnglish text
fileTool->setDebugLogging(true);

// English text
ToolResult result = fileTool->execute(callId, args);

// English textlogoutput
qDebug() << result.output;
```

---

## English texttool

| tool | English text | English text |
|------|------|------|
| `FileSystemTool` | English textfileEnglish text | English texttool(English text) |
| `CheckpointManager` | fileEnglish text | English text(English text) |
| `SandboxManager` | English text | English textrecommended |

---

## English textlog

### v1.0 (English text)
- ✅ English textfileEnglish text
- ✅ English textdataEnglish text(English text, BOM, English text)
- ✅ English textfileEnglish text
- ✅ pathsafetyEnglish text
- ✅ JSON/Python English text
- ✅ checkpointEnglish text

### English text (v2.0+)
- 🔲 English textstepEnglish text API
- 🔲 English textfileEnglish text
- 🔲 Git English text
- 🔲  English text
- 🔲  English textsupport
- 🔲  English text
