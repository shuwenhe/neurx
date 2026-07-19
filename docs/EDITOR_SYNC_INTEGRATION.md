# NeurX-Code Editor File Synchronization Integration

## implementationEnglish text

English textfileEnglish text(English text WriteTool English texttool), English textstepEnglish textcontent.

## English textstepEnglish text

### 1. AgentController.h English text

```cpp
#pragma once

// English text
#include "editor/FileWatcher.h"

class AgentController : public QObject {
    Q_OBJECT
    // ... English text ...

private slots:
    // English textfileEnglish text
    void onWatchedFileModified(const QString &filePath);

private:
    FileWatcher *m_fileWatcher;
};
```

### 2. AgentController.cpp English textimplementation

```cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
    // ... English textinitialize ...
{
    // initializefileEnglish text
    m_fileWatcher = new FileWatcher(this);

    // English textfileEnglish text
    connect(m_fileWatcher, &FileWatcher::fileModified,
            this, &AgentController::onWatchedFileModified);
}

void AgentController::onOpenFileRequested(const QString &filePath)
{
    // English textfileEnglish text...
    m_currentFilePath = filePath;

    // startEnglish textfile
    m_fileWatcher->watchFile(filePath);

    // ... loadfilecontent ...
}

void AgentController::onWatchedFileModified(const QString &filePath)
{
    // English textfileEnglish text
    if (filePath == m_currentFilePath) {
        // English textloadfilecontent
        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = QString::fromUtf8(file.readAll());
            file.close();

            // English textcontent(English text currentFileContentChanged English text)
            if (content != m_currentFileContent) {
                m_currentFileContent = content;
                emit currentFileContentChanged();

                qDebug() << "[AgentController] File updated from disk:" << filePath;
            }
        }
    }
}

void AgentController::setCurrentFilePath(const QString &newPath)
{
    if (m_currentFilePath != newPath) {
        // English textfile
        if (!m_currentFilePath.isEmpty()) {
            m_fileWatcher->unwatchFile(m_currentFilePath);
        }

        m_currentFilePath = newPath;
        emit currentFilePathChanged();

        // startEnglish textfile
        if (!newPath.isEmpty()) {
            m_fileWatcher->watchFile(newPath);
        }
    }
}

void AgentController::setWorkspacePath(const QString &newPath)
{
    if (m_workspacePath != newPath) {
        // English text
        m_fileWatcher->clear();

        m_workspacePath = newPath;
        emit workspacePathChanged();

        // English text(English text: English textfile)
        // English text: English text, English textfile
    }
}
```

### 3. EditorPanel.qml English text

EditorPanel English textstepEnglish text:

```qml
Connections {
    target: agent

    // English textfilepathEnglish text(English textfile)
    function onCurrentFilePathChanged() {
        root.syncFromAgent(true)  // English text agent English textloadcontent
    }

    // English textfilecontentEnglish text(English textload)
    function onCurrentFileContentChanged() {
        root.syncFromAgent()  // English textstepEnglish text
    }

    // English textfileEnglish text
    function onOpenFilesChanged() {
        if (agent.currentFilePath)
            root.syncFromAgent()
    }
}
```

## English textpipeline

1. **English textfile**
   ```
   User → Agent.openFile(path) → FileWatcher.watchFile(path) → Editor displays content
   ```

2. **English textfile(English text WriteTool)**
   ```
   WriteTool → writes to disk → FileWatcher detects change
   ```

3. **English textstep**
   ```
   FileWatcher detects → onWatchedFileModified() → reload content from disk
   → update Agent.currentFileContent → sync EditorPanel.qml → Editor shows new content
   ```

## English text

✓ **English text** - English textfilesystemEnglish text
✓ **English text** - 500ms English text, English textload
✓ **pathsafety** - English textfileEnglish text
✓ **English text** - supportdirectoryEnglish text(English text)
✓ **English textcache** - English textfileEnglish texttime, English text
✓ **errorEnglish text** - completeEnglish textlogEnglish text

## configurationEnglish text

English text AgentController English textconfiguration:

```cpp
// English texttime(English text)
m_fileWatcher->setDebounceInterval(1000);  // English text 1 English text

// English text/English textfileEnglish text
m_fileWatcher->watchFile(filePath);
m_fileWatcher->unwatchFile(filePath);

// English textdirectory(English textuse, English text)
m_fileWatcher->watchDirectory(dirPath, true);
```

## English text

- **English textfileEnglish text** - English text(recommended)
- **English textfileEnglish text** - English textfileEnglish text
- **directoryEnglish text** - English text, English textdirectoryEnglish text

## testEnglish text

```bash
# 1. English text hello.cc English text
# 2. run WriteTool English texttoolEnglish text hello.cc
# 3. English textcontent

# exampletest:
cat >> /path/to/file.cc << 'EOF'
// Added by external tool
EOF

# English textcontent
```

## English text

- [ ] configurationfileEnglish text(English text .git)
- [ ] supportfileEnglish text
- [ ] supportEnglish textfileEnglish text
- [ ] English text
- [ ] English text(English textfileEnglish textprompt)
