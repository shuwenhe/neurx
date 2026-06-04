#include "tools/ClaudeStandardTools.h"
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QRegularExpression>
#include <QDirIterator>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDateTime>

// ═══════════════════════════════════════════════════════════════════════════════
// WriteTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

WriteTool::WriteTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject WriteTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "file_path": {
                "type": "string",
                "description": "Path to the file to create or overwrite"
            },
            "new_text": {
                "type": "string",
                "description": "Content to write to the file"
            }
        },
        "required": ["file_path", "new_text"]
    })JSON").object();
}

ToolResult WriteTool::execute(const QString& callId, const QJsonObject& args)
{
    QString filePath = args.value("file_path").toString();
    QString newText = args.value("new_text").toString();
    
    qDebug() << "[WriteTool] Executing with file_path:" << filePath << "size:" << newText.size();
    
    if (filePath.isEmpty()) {
        qWarning() << "[WriteTool] Error: file_path is empty";
        return {callId, name(), true, "Error: file_path is required"};
    }
    
    // Validate path
    QString absPath = safePath(filePath);
    if (absPath.isEmpty()) {
        qWarning() << "[WriteTool] Error: Path traversal detected for:" << filePath;
        return {callId, name(), true, "Error: Path traversal attack detected"};
    }
    
    qDebug() << "[WriteTool] Resolved absolute path:" << absPath;
    
    // Check sandbox
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
            qWarning() << "[WriteTool] Error: Sandbox denied write access to:" << absPath;
            return {callId, name(), true, "Error: Sandbox policy denied write access to " + filePath};
        }
        qDebug() << "[WriteTool] Sandbox check passed";
    } else {
        qDebug() << "[WriteTool] No sandbox manager, skipping permission check";
    }
    
    // Create parent directories
    QFileInfo fileInfo(absPath);
    QString parentDir = fileInfo.dir().absolutePath();
    if (!ensureDirectoryExists(parentDir)) {
        qWarning() << "[WriteTool] Error: Failed to create parent directory:" << parentDir;
        return {callId, name(), true, "Error: Failed to create parent directories"};
    }
    
    qDebug() << "[WriteTool] Parent directory ensured:" << parentDir;
    
    // Write file
    QFile file(absPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QString error = file.errorString();
        qWarning() << "[WriteTool] Error: Cannot open file for writing:" << absPath << "error:" << error;
        return {callId, name(), true, "Error: Cannot open file for writing: " + error};
    }
    
    QTextStream out(&file);
    out << newText;
    file.close();
    
    qInfo() << "[WriteTool] Successfully wrote" << newText.size() << "bytes to:" << absPath;
    
    // Get relative path for display
    QString relativePath = m_root.relativeFilePath(absPath);
    QString message = QString("Created/Updated file: %1 (%2 bytes)")
                        .arg(relativePath)
                        .arg(newText.size());
    
    return {callId, name(), false, message};
}

QString WriteTool::summary(const QJsonObject& args) const
{
    QString filePath = args.value("file_path").toString();
    return QString("Write file: %1").arg(filePath);
}

QString WriteTool::safePath(const QString& relOrAbsPath) const
{
    QString workspaceRoot = m_root.absolutePath();
    
    // 如果是绝对路径，直接检查是否在工作空间内
    QFileInfo fileInfo(relOrAbsPath);
    if (fileInfo.isAbsolute()) {
        QString absPath = QDir::cleanPath(fileInfo.absoluteFilePath());
        QString cleanRoot = QDir::cleanPath(workspaceRoot);
        
        qDebug() << "[WriteTool::safePath] Absolute path check:";
        qDebug() << "  Input:" << relOrAbsPath;
        qDebug() << "  Cleaned:" << absPath;
        qDebug() << "  Workspace:" << cleanRoot;
        
        if (absPath.startsWith(cleanRoot)) {
            qDebug() << "  ✅ Path is within workspace";
            return absPath;
        } else {
            qWarning() << "  ❌ Path is outside workspace";
            return QString();
        }
    }
    
    // 相对路径：转换为绝对路径
    QString abs = m_root.absoluteFilePath(relOrAbsPath);
    QString cleanAbs = QDir::cleanPath(abs);
    QString cleanRoot = QDir::cleanPath(workspaceRoot);
    
    qDebug() << "[WriteTool::safePath] Relative path check:";
    qDebug() << "  Input:" << relOrAbsPath;
    qDebug() << "  Resolved:" << cleanAbs;
    qDebug() << "  Workspace:" << cleanRoot;
    
    // Prevent path traversal
    if (!cleanAbs.startsWith(cleanRoot)) {
        qWarning() << "  ❌ Path traversal detected";
        return QString();
    }
    
    qDebug() << "  ✅ Path is safe";
    return cleanAbs;
}

bool WriteTool::ensureDirectoryExists(const QString& dirPath)
{
    QDir dir;
    return dir.mkpath(dirPath);
}

// ═══════════════════════════════════════════════════════════════════════════════
// EditTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

EditTool::EditTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject EditTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "file_path": {
                "type": "string",
                "description": "Path to the file to edit"
            },
            "old_text": {
                "type": "string",
                "description": "The exact text to replace (must match exactly)"
            },
            "new_text": {
                "type": "string",
                "description": "The text to replace old_text with"
            }
        },
        "required": ["file_path", "old_text", "new_text"]
    })JSON").object();
}

ToolResult EditTool::execute(const QString& callId, const QJsonObject& args)
{
    QString filePath = args.value("file_path").toString();
    QString oldText = args.value("old_text").toString();
    QString newText = args.value("new_text").toString();
    
    if (filePath.isEmpty() || oldText.isEmpty()) {
        return {callId, name(), true, "Error: file_path and old_text are required"};
    }
    
    // Validate path
    QString absPath = safePath(filePath);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Error: Path traversal attack detected"};
    }
    
    // Check file exists
    if (!QFile::exists(absPath)) {
        return {callId, name(), true, "Error: File does not exist: " + filePath};
    }
    
    // Check sandbox
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
            return {callId, name(), true, "Error: Sandbox policy denied write access"};
        }
    }
    
    // Read file
    QFile file(absPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Error: Cannot open file for reading: " + file.errorString()};
    }
    
    QString content = QString::fromUtf8(file.readAll());
    file.close();
    
    // Count occurrences
    int count = content.count(oldText);
    
    if (count == 0) {
        return {callId, name(), true, "Error: old_text not found in file"};
    }
    
    if (count > 1) {
        return {callId, name(), true, 
                QString("Error: old_text appears %1 times in file. Must appear exactly once.").arg(count)};
    }
    
    // Perform replacement
    QString newContent = content.replace(oldText, newText);
    
    // Write back
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return {callId, name(), true, "Error: Cannot open file for writing: " + file.errorString()};
    }
    
    QTextStream out(&file);
    out << newContent;
    file.close();
    
    QString relativePath = m_root.relativeFilePath(absPath);
    QString message = QString("Edited file: %1 (replaced %2 characters with %3)")
                        .arg(relativePath)
                        .arg(oldText.size())
                        .arg(newText.size());
    
    return {callId, name(), false, message};
}

QString EditTool::summary(const QJsonObject& args) const
{
    QString filePath = args.value("file_path").toString();
    return QString("Edit file: %1").arg(filePath);
}

QString EditTool::safePath(const QString& relOrAbsPath) const
{
    QString workspaceRoot = m_root.absolutePath();
    QFileInfo fileInfo(relOrAbsPath);
    
    if (fileInfo.isAbsolute()) {
        QString absPath = QDir::cleanPath(fileInfo.absoluteFilePath());
        QString cleanRoot = QDir::cleanPath(workspaceRoot);
        return absPath.startsWith(cleanRoot) ? absPath : QString();
    }
    
    QString abs = QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
    QString cleanRoot = QDir::cleanPath(workspaceRoot);
    return abs.startsWith(cleanRoot) ? abs : QString();
}

// ═══════════════════════════════════════════════════════════════════════════════
// MultiEditTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

MultiEditTool::MultiEditTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject MultiEditTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "file_path": {
                "type": "string",
                "description": "Path to the file to edit"
            },
            "edits": {
                "type": "array",
                "description": "Array of edit operations to apply sequentially",
                "items": {
                    "type": "object",
                    "properties": {
                        "old_text": {
                            "type": "string",
                            "description": "Text to replace"
                        },
                        "new_text": {
                            "type": "string",
                            "description": "Replacement text"
                        }
                    },
                    "required": ["old_text", "new_text"]
                }
            }
        },
        "required": ["file_path", "edits"]
    })JSON").object();
}

ToolResult MultiEditTool::execute(const QString& callId, const QJsonObject& args)
{
    QString filePath = args.value("file_path").toString();
    QJsonArray editsArray = args.value("edits").toArray();
    
    if (filePath.isEmpty()) {
        return {callId, name(), true, "Error: file_path is required"};
    }
    
    if (editsArray.isEmpty()) {
        return {callId, name(), true, "Error: edits array is required and cannot be empty"};
    }
    
    // Validate path
    QString absPath = safePath(filePath);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Error: Path traversal attack detected"};
    }
    
    // Check file exists
    if (!QFile::exists(absPath)) {
        return {callId, name(), true, "Error: File does not exist: " + filePath};
    }
    
    // Check sandbox
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
            return {callId, name(), true, "Error: Sandbox policy denied write access"};
        }
    }
    
    // Read file
    QFile file(absPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Error: Cannot open file for reading: " + file.errorString()};
    }
    
    QString content = QString::fromUtf8(file.readAll());
    file.close();
    
    // Store original content for rollback
    QString originalContent = content;
    
    // Apply edits sequentially
    int successCount = 0;
    for (const QJsonValue& editVal : editsArray) {
        QJsonObject edit = editVal.toObject();
        QString oldText = edit.value("old_text").toString();
        QString newText = edit.value("new_text").toString();
        
        if (oldText.isEmpty()) {
            return {callId, name(), true, 
                    QString("Error: Edit %1 has empty old_text").arg(successCount + 1)};
        }
        
        // Check if old_text exists
        if (!content.contains(oldText)) {
            return {callId, name(), true,
                    QString("Error: Edit %1: old_text not found").arg(successCount + 1)};
        }
        
        // Check for multiple occurrences
        int count = content.count(oldText);
        if (count > 1) {
            return {callId, name(), true,
                    QString("Error: Edit %1: old_text appears %2 times (must be unique)")
                        .arg(successCount + 1).arg(count)};
        }
        
        // Apply edit
        content = content.replace(oldText, newText);
        successCount++;
    }
    
    // Write back
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return {callId, name(), true, "Error: Cannot open file for writing: " + file.errorString()};
    }
    
    QTextStream out(&file);
    out << content;
    file.close();
    
    QString relativePath = m_root.relativeFilePath(absPath);
    QString message = QString("Applied %1 edits to: %2")
                        .arg(successCount)
                        .arg(relativePath);
    
    return {callId, name(), false, message};
}

QString MultiEditTool::summary(const QJsonObject& args) const
{
    QString filePath = args.value("file_path").toString();
    int editCount = args.value("edits").toArray().size();
    return QString("MultiEdit file: %1 (%2 edits)").arg(filePath).arg(editCount);
}

QString MultiEditTool::safePath(const QString& relOrAbsPath) const
{
    QString workspaceRoot = m_root.absolutePath();
    QFileInfo fileInfo(relOrAbsPath);
    
    if (fileInfo.isAbsolute()) {
        QString absPath = QDir::cleanPath(fileInfo.absoluteFilePath());
        QString cleanRoot = QDir::cleanPath(workspaceRoot);
        return absPath.startsWith(cleanRoot) ? absPath : QString();
    }
    
    QString abs = QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
    QString cleanRoot = QDir::cleanPath(workspaceRoot);
    return abs.startsWith(cleanRoot) ? abs : QString();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ReadTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

ReadTool::ReadTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject ReadTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "file_path": {
                "type": "string",
                "description": "Path to the file to read"
            },
            "start_line": {
                "type": "integer",
                "description": "Starting line number (1-based, optional)"
            },
            "end_line": {
                "type": "integer",
                "description": "Ending line number (1-based, optional)"
            }
        },
        "required": ["file_path"]
    })JSON").object();
}

ToolResult ReadTool::execute(const QString& callId, const QJsonObject& args)
{
    QString filePath = args.value("file_path").toString();
    int startLine = args.value("start_line").toInt(0);
    int endLine = args.value("end_line").toInt(0);
    
    if (filePath.isEmpty()) {
        return {callId, name(), true, "Error: file_path is required"};
    }
    
    // Validate path
    QString absPath = safePath(filePath);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Error: Path traversal attack detected"};
    }
    
    // Check file exists
    if (!QFile::exists(absPath)) {
        return {callId, name(), true, "Error: File does not exist: " + filePath};
    }
    
    // Check sandbox
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Read)) {
            return {callId, name(), true, "Error: Sandbox policy denied read access"};
        }
    }
    
    // Check if binary
    if (isBinaryFile(absPath)) {
        return {callId, name(), true, "Error: Cannot read binary file: " + filePath};
    }
    
    // Read file
    QFile file(absPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Error: Cannot open file: " + file.errorString()};
    }
    
    if (startLine > 0 || endLine > 0) {
        // Read specific line range
        QTextStream in(&file);
        QStringList lines;
        int currentLine = 1;
        
        while (!in.atEnd()) {
            QString line = in.readLine();
            
            if (currentLine >= startLine && (endLine == 0 || currentLine <= endLine)) {
                lines.append(line);
            }
            
            if (endLine > 0 && currentLine > endLine) {
                break;
            }
            
            currentLine++;
        }
        
        file.close();
        
        QString content = lines.join("\n");
        QString relativePath = m_root.relativeFilePath(absPath);
        QString header = QString("=== %1 (lines %2-%3) ===\n")
                           .arg(relativePath)
                           .arg(startLine > 0 ? startLine : 1)
                           .arg(endLine > 0 ? endLine : currentLine - 1);
        
        return {callId, name(), false, header + content};
    } else {
        // Read entire file
        QString content = QString::fromUtf8(file.readAll());
        file.close();
        
        QString relativePath = m_root.relativeFilePath(absPath);
        QString header = QString("=== %1 ===\n").arg(relativePath);
        
        return {callId, name(), false, header + content};
    }
}

QString ReadTool::summary(const QJsonObject& args) const
{
    QString filePath = args.value("file_path").toString();
    return QString("Read file: %1").arg(filePath);
}

QString ReadTool::safePath(const QString& relOrAbsPath) const
{
    QString workspaceRoot = m_root.absolutePath();
    QFileInfo fileInfo(relOrAbsPath);
    
    if (fileInfo.isAbsolute()) {
        QString absPath = QDir::cleanPath(fileInfo.absoluteFilePath());
        QString cleanRoot = QDir::cleanPath(workspaceRoot);
        return absPath.startsWith(cleanRoot) ? absPath : QString();
    }
    
    QString abs = QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
    QString cleanRoot = QDir::cleanPath(workspaceRoot);
    return abs.startsWith(cleanRoot) ? abs : QString();
}

bool ReadTool::isBinaryFile(const QString& filePath) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    
    // Read first 8192 bytes
    QByteArray data = file.read(8192);
    file.close();
    
    // Check for null bytes (common in binary files)
    return data.contains('\0');
}

// ═══════════════════════════════════════════════════════════════════════════════
// BashTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

BashTool::BashTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject BashTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "command": {
                "type": "string",
                "description": "Shell command to execute"
            },
            "timeout": {
                "type": "integer",
                "description": "Timeout in seconds (default: 30)"
            }
        },
        "required": ["command"]
    })JSON").object();
}

ToolResult BashTool::execute(const QString& callId, const QJsonObject& args)
{
    QString command = args.value("command").toString();
    int timeout = args.value("timeout").toInt(m_defaultTimeoutSec);
    
    if (command.isEmpty()) {
        return {callId, name(), true, "Error: command is required"};
    }
    
    // Check for dangerous commands
    if (isDangerousCommand(command)) {
        QString warning = QString("Warning: Potentially dangerous command: %1\n"
                                "Proceed with caution.").arg(command);
        // Note: In production, you might want to require approval here
    }
    
    // Check sandbox
    if (m_sandboxManager) {
        // Note: You might want more sophisticated command checking here
    }
    
    // Execute command
    QProcess process;
    process.setWorkingDirectory(m_root.absolutePath());
    process.setProcessChannelMode(QProcess::MergedChannels);
    
    QString shell = getShell();
    QStringList shellArgs;
    
#ifdef Q_OS_WIN
    shellArgs << "/c" << command;
#else
    shellArgs << "-c" << command;
#endif
    
    process.start(shell, shellArgs);
    
    if (!process.waitForStarted(5000)) {
        return {callId, name(), true, "Error: Failed to start process"};
    }
    
    if (!process.waitForFinished(timeout * 1000)) {
        process.kill();
        return {callId, name(), true, 
                QString("Error: Command timed out after %1 seconds").arg(timeout)};
    }
    
    int exitCode = process.exitCode();
    QString output = QString::fromUtf8(process.readAll());
    
    QString result = QString("=== Command: %1 ===\n"
                           "Exit code: %2\n"
                           "Output:\n%3")
                       .arg(command)
                       .arg(exitCode)
                       .arg(output);
    
    return {callId, name(), exitCode != 0, result};
}

QString BashTool::summary(const QJsonObject& args) const
{
    QString command = args.value("command").toString();
    // Truncate long commands
    if (command.length() > 50) {
        command = command.left(47) + "...";
    }
    return QString("Bash: %1").arg(command);
}

bool BashTool::isDangerousCommand(const QString& command) const
{
    QStringList dangerousPatterns = {
        "rm -rf",
        "dd if=",
        "mkfs",
        ":(){ :|:& };:",  // Fork bomb
        "chmod 777",
        "chmod -R 777"
    };
    
    for (const QString& pattern : dangerousPatterns) {
        if (command.contains(pattern, Qt::CaseInsensitive)) {
            return true;
        }
    }
    
    return false;
}

QString BashTool::getShell() const
{
#ifdef Q_OS_WIN
    return "cmd.exe";
#else
    return "/bin/bash";
#endif
}

// ═══════════════════════════════════════════════════════════════════════════════
// GrepTool Implementation  
// ═══════════════════════════════════════════════════════════════════════════════

GrepTool::GrepTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject GrepTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "pattern": {
                "type": "string",
                "description": "Search pattern (supports regex)"
            },
            "path": {
                "type": "string",
                "description": "File or directory to search in (default: workspace root)"
            },
            "case_sensitive": {
                "type": "boolean",
                "description": "Case sensitive search (default: false)"
            },
            "max_results": {
                "type": "integer",
                "description": "Maximum number of results to return (default: 100)"
            }
        },
        "required": ["pattern"]
    })JSON").object();
}

ToolResult GrepTool::execute(const QString& callId, const QJsonObject& args)
{
    QString pattern = args.value("pattern").toString();
    QString path = args.value("path").toString(".");
    bool caseSensitive = args.value("case_sensitive").toBool(false);
    int maxResults = args.value("max_results").toInt(100);
    
    if (pattern.isEmpty()) {
        return {callId, name(), true, "Error: pattern is required"};
    }
    
    // Validate path
    QString absPath = safePath(path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Error: Path traversal attack detected"};
    }
    
    // Check path exists
    if (!QFile::exists(absPath)) {
        return {callId, name(), true, "Error: Path does not exist: " + path};
    }
    
    // Create regex
    QRegularExpression regex(pattern);
    if (!caseSensitive) {
        regex.setPatternOptions(QRegularExpression::CaseInsensitiveOption);
    }
    
    if (!regex.isValid()) {
        return {callId, name(), true, "Error: Invalid regex pattern: " + regex.errorString()};
    }
    
    QList<GrepMatch> matches;
    
    QFileInfo fileInfo(absPath);
    if (fileInfo.isFile()) {
        // Search in single file
        matches = searchInFile(absPath, regex, maxResults);
    } else {
        // Search in directory
        QDirIterator it(absPath, QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
        while (it.hasNext() && matches.size() < maxResults) {
            QString filePath = it.next();
            
            // Skip binary files
            if (isBinaryFile(filePath)) {
                continue;
            }
            
            // Skip large files (> 10MB)
            if (QFileInfo(filePath).size() > 10 * 1024 * 1024) {
                continue;
            }
            
            matches.append(searchInFile(filePath, regex, maxResults - matches.size()));
        }
    }
    
    // Format results
    QString result = QString("=== Found %1 matches for pattern: %2 ===\n\n")
                       .arg(matches.size())
                       .arg(pattern);
    
    for (const GrepMatch& match : matches) {
        QString relativePath = m_root.relativeFilePath(match.filePath);
        result += QString("%1:%2: %3\n")
                    .arg(relativePath)
                    .arg(match.lineNumber)
                    .arg(match.line);
    }
    
    if (matches.isEmpty()) {
        result = "No matches found.";
    }
    
    return {callId, name(), false, result};
}

QString GrepTool::summary(const QJsonObject& args) const
{
    QString pattern = args.value("pattern").toString();
    return QString("Grep: %1").arg(pattern);
}

QList<GrepTool::GrepMatch> GrepTool::searchInFile(const QString& filePath,
                                                   const QRegularExpression& regex,
                                                   int maxResults) const
{
    QList<GrepMatch> matches;
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return matches;
    }
    
    QTextStream in(&file);
    int lineNumber = 1;
    
    while (!in.atEnd() && matches.size() < maxResults) {
        QString line = in.readLine();
        
        if (regex.match(line).hasMatch()) {
            GrepMatch match;
            match.filePath = filePath;
            match.lineNumber = lineNumber;
            match.line = line;
            matches.append(match);
        }
        
        lineNumber++;
    }
    
    file.close();
    return matches;
}

QString GrepTool::safePath(const QString& relOrAbsPath) const
{
    QString workspaceRoot = m_root.absolutePath();
    QFileInfo fileInfo(relOrAbsPath);
    
    if (fileInfo.isAbsolute()) {
        QString absPath = QDir::cleanPath(fileInfo.absoluteFilePath());
        QString cleanRoot = QDir::cleanPath(workspaceRoot);
        return absPath.startsWith(cleanRoot) ? absPath : QString();
    }
    
    QString abs = QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
    QString cleanRoot = QDir::cleanPath(workspaceRoot);
    return abs.startsWith(cleanRoot) ? abs : QString();
}

bool GrepTool::isBinaryFile(const QString& filePath) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    
    QByteArray data = file.read(8192);
    file.close();
    
    return data.contains('\0');
}

// ═══════════════════════════════════════════════════════════════════════════════
// GlobTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

GlobTool::GlobTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
{
}

QJsonObject GlobTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "pattern": {
                "type": "string",
                "description": "Glob pattern (e.g., *.cpp, src/**/*.h)"
            },
            "include_hidden": {
                "type": "boolean",
                "description": "Include hidden files (default: false)"
            },
            "max_results": {
                "type": "integer",
                "description": "Maximum number of results (default: 1000)"
            }
        },
        "required": ["pattern"]
    })JSON").object();
}

ToolResult GlobTool::execute(const QString& callId, const QJsonObject& args)
{
    QString pattern = args.value("pattern").toString();
    bool includeHidden = args.value("include_hidden").toBool(false);
    int maxResults = args.value("max_results").toInt(1000);
    
    if (pattern.isEmpty()) {
        return {callId, name(), true, "Error: pattern is required"};
    }
    
    QStringList files = findFiles(pattern, includeHidden, maxResults);
    
    QString result = QString("=== Found %1 files matching pattern: %2 ===\n\n")
                       .arg(files.size())
                       .arg(pattern);
    
    for (const QString& file : files) {
        result += file + "\n";
    }
    
    if (files.isEmpty()) {
        result = QString("No files found matching pattern: %1").arg(pattern);
    }
    
    return {callId, name(), false, result};
}

QString GlobTool::summary(const QJsonObject& args) const
{
    QString pattern = args.value("pattern").toString();
    return QString("Glob: %1").arg(pattern);
}

QStringList GlobTool::findFiles(const QString& pattern, bool includeHidden, int maxResults) const
{
    QStringList results;
    
    QDir::Filters filters = QDir::Files | QDir::NoSymLinks;
    if (includeHidden) {
        filters |= QDir::Hidden;
    }
    
    QDirIterator it(m_root.absolutePath(), filters, QDirIterator::Subdirectories);
    
    while (it.hasNext() && results.size() < maxResults) {
        QString absPath = it.next();
        QString relativePath = m_root.relativeFilePath(absPath);
        
        // Skip excluded directories
        if (shouldExclude(relativePath)) {
            continue;
        }
        
        // Check if matches glob pattern
        if (matchesGlob(relativePath, pattern)) {
            results.append(relativePath);
        }
    }
    
    return results;
}

bool GlobTool::matchesGlob(const QString& path, const QString& pattern) const
{
    // Simple glob matching implementation
    // Convert glob to regex
    QString regexPattern = pattern;
    
    // Escape regex special characters except * and ?
    regexPattern.replace(".", "\\.");
    regexPattern.replace("+", "\\+");
    regexPattern.replace("(", "\\(");
    regexPattern.replace(")", "\\)");
    regexPattern.replace("[", "\\[");
    regexPattern.replace("]", "\\]");
    regexPattern.replace("{", "\\{");
    regexPattern.replace("}", "\\}");
    regexPattern.replace("^", "\\^");
    regexPattern.replace("$", "\\$");
    
    // Convert glob wildcards to regex
    regexPattern.replace("**", "DOUBLE_STAR_PLACEHOLDER");
    regexPattern.replace("*", "[^/]*");
    regexPattern.replace("DOUBLE_STAR_PLACEHOLDER", ".*");
    regexPattern.replace("?", ".");
    
    // Add anchors
    regexPattern = "^" + regexPattern + "$";
    
    QRegularExpression regex(regexPattern);
    return regex.match(path).hasMatch();
}

bool GlobTool::shouldExclude(const QString& path) const
{
    QStringList excludePatterns = {
        ".git",
        "node_modules",
        ".vscode",
        ".idea",
        "build",
        "dist",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache"
    };
    
    for (const QString& pattern : excludePatterns) {
        if (path.contains("/" + pattern + "/") || path.startsWith(pattern + "/")) {
            return true;
        }
    }
    
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ClaudeStandardToolFactory Implementation
// ═══════════════════════════════════════════════════════════════════════════════

void ClaudeStandardToolFactory::registerAllTools(const QString& workspaceRoot,
                                                 AgentToolRegistry* registry,
                                                 SandboxManager* sandboxManager)
{
    if (!registry) return;

    registry->registerTool(createWriteTool(workspaceRoot, sandboxManager));
    registry->registerTool(createEditTool(workspaceRoot, sandboxManager));
    registry->registerTool(createMultiEditTool(workspaceRoot, sandboxManager));
    registry->registerTool(createReadTool(workspaceRoot, sandboxManager));
    registry->registerTool(createBashTool(workspaceRoot, sandboxManager));
    registry->registerTool(createGrepTool(workspaceRoot, sandboxManager));
    registry->registerTool(createGlobTool(workspaceRoot, sandboxManager));
}

WriteTool* ClaudeStandardToolFactory::createWriteTool(const QString& workspaceRoot,
                                                     SandboxManager* sandboxManager)
{
    auto tool = new WriteTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}

EditTool* ClaudeStandardToolFactory::createEditTool(const QString& workspaceRoot,
                                                   SandboxManager* sandboxManager)
{
    auto tool = new EditTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}

MultiEditTool* ClaudeStandardToolFactory::createMultiEditTool(const QString& workspaceRoot,
                                                             SandboxManager* sandboxManager)
{
    auto tool = new MultiEditTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}

ReadTool* ClaudeStandardToolFactory::createReadTool(const QString& workspaceRoot,
                                                   SandboxManager* sandboxManager)
{
    auto tool = new ReadTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}

BashTool* ClaudeStandardToolFactory::createBashTool(const QString& workspaceRoot,
                                                   SandboxManager* sandboxManager)
{
    auto tool = new BashTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}

GrepTool* ClaudeStandardToolFactory::createGrepTool(const QString& workspaceRoot,
                                                   SandboxManager* sandboxManager)
{
    auto tool = new GrepTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}

GlobTool* ClaudeStandardToolFactory::createGlobTool(const QString& workspaceRoot,
                                                   SandboxManager* sandboxManager)
{
    auto tool = new GlobTool(workspaceRoot);
    tool->setSandboxManager(sandboxManager);
    return tool;
}
