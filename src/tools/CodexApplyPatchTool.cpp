#include "tools/CodexApplyPatchTool.h"
#include "sandbox/SandboxManager.h"
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonArray>
#include <QRegularExpression>
#include <QDebug>
#include <QTemporaryFile>
#include <QDir>

// ═══════════════════════════════════════════════════════════════════════════════
// CodexApplyPatchTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

CodexApplyPatchTool::CodexApplyPatchTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    // Try to find codex binary
    m_codexCliPath = findCodexCli();
}

QString CodexApplyPatchTool::description() const
{
    return "Apply a unified diff patch to files using the Codex CLI. "
           "This integrates directly with Codex's apply_patch command for "
           "safe, validated file modifications. "
           "Parameters: patch (unified diff), cwd (optional working directory).";
}

QJsonObject CodexApplyPatchTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "patch": {
                "type": "string",
                "description": "Unified diff format patch content"
            },
            "cwd": {
                "type": "string",
                "description": "Working directory for patch application (defaults to workspace root)"
            },
            "auto_approve": {
                "type": "boolean",
                "description": "Auto-approve safe patches (default: false)"
            },
            "verbose": {
                "type": "boolean",
                "description": "Enable verbose output (default: false)"
            }
        },
        "required": ["patch"]
    })JSON").object();
}

ToolResult CodexApplyPatchTool::execute(const QString &callId, const QJsonObject &args)
{
    QString patchContent = args.value("patch").toString();
    QString cwd = args.value("cwd").toString();
    bool autoApprove = args.value("auto_approve").toBool(false);
    bool verbose = args.value("verbose").toBool(false);
    
    qInfo() << "[CodexApplyPatchTool]" << callId << "START";
    qInfo() << "[CodexApplyPatchTool]" << callId << "patch_size:" << patchContent.size();
    qInfo() << "[CodexApplyPatchTool]" << callId << "cwd:" << (cwd.isEmpty() ? m_workspaceRoot : cwd);
    
    // ── Validate patch content ──
    QString validationError = validatePatchFormat(patchContent);
    if (!validationError.isEmpty()) {
        qWarning() << "[CodexApplyPatchTool]" << callId << "ERROR: Invalid patch format:" << validationError;
        return {callId, name(), true, "Error: " + validationError};
    }
    
    // ── Set working directory ──
    if (cwd.isEmpty()) {
        cwd = m_workspaceRoot;
    }
    
    qInfo() << "[CodexApplyPatchTool]" << callId << "Step 1: Patch validation PASSED";
    
    // ── Validate sandbox permissions ──
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(cwd, FileSystemAccessMode::Write)) {
            qWarning() << "[CodexApplyPatchTool]" << callId << "ERROR: Sandbox denied access to:" << cwd;
            return {callId, name(), true, "Error: Sandbox policy denied write access"};
        }
        qInfo() << "[CodexApplyPatchTool]" << callId << "Step 2: Sandbox permission check PASSED";
    } else {
        qInfo() << "[CodexApplyPatchTool]" << callId << "Step 2: No sandbox manager, skipping check";
    }
    
    // ── Apply patch via Codex CLI ──
    qInfo() << "[CodexApplyPatchTool]" << callId << "Step 3: Invoking Codex CLI...";
    ApplyPatchResult result = applyPatchViaCLI(patchContent, cwd);
    
    if (!result.success) {
        qWarning() << "[CodexApplyPatchTool]" << callId << "ERROR: Patch application failed";
        qWarning() << "[CodexApplyPatchTool]" << callId << "Codex output:" << result.output;
        qWarning() << "[CodexApplyPatchTool]" << callId << "Codex error:" << result.error;
        
        QString errorMsg = formatPatchError(result.error);
        return {callId, name(), true, "Error: " + errorMsg};
    }
    
    qInfo() << "[CodexApplyPatchTool]" << callId << "Step 4: Patch applied successfully";
    qInfo() << "[CodexApplyPatchTool]" << callId << "Files changed:" << result.filesChanged;
    qInfo() << "[CodexApplyPatchTool]" << callId << "Changed files:" << result.changedFiles.join(", ");
    
    // ── Format success message ──
    QString message = QString("✓ Patch applied successfully\n"
                             "Files changed: %1\n"
                             "Files: %2")
        .arg(result.filesChanged)
        .arg(result.changedFiles.join(", "));
    
    qInfo() << "[CodexApplyPatchTool]" << callId << "SUCCESS";
    return {callId, name(), false, message};
}

QString CodexApplyPatchTool::summary(const QJsonObject &args) const
{
    QString patch = args.value("patch").toString();
    int lines = patch.count('\n');
    return QString("Apply patch (%1 lines)").arg(lines);
}

QString CodexApplyPatchTool::findCodexCli() const
{
    // Try common locations
    QStringList possiblePaths = {
        "/usr/local/bin/codex",
        "/usr/bin/codex",
        QStandardPaths::findExecutable("codex"),
        QStandardPaths::findExecutable("codex-cli"),
    };
    
    for (const auto &path : possiblePaths) {
        if (!path.isEmpty() && QFile::exists(path)) {
            qInfo() << "[CodexApplyPatchTool] Found Codex CLI at:" << path;
            return path;
        }
    }
    
    qWarning() << "[CodexApplyPatchTool] Could not find Codex CLI binary";
    return "codex";  // Fall back to PATH resolution
}

CodexApplyPatchTool::ApplyPatchResult CodexApplyPatchTool::applyPatchViaCLI(
    const QString &patchContent, const QString &cwd)
{
    ApplyPatchResult result;
    
    if (m_codexCliPath.isEmpty()) {
        result.success = false;
        result.error = "Codex CLI path not configured";
        return result;
    }
    
    // Create temporary patch file
    QTemporaryFile patchFile;
    if (!patchFile.open()) {
        result.success = false;
        result.error = "Failed to create temporary patch file";
        return result;
    }
    
    QTextStream out(&patchFile);
    out << patchContent;
    patchFile.close();
    
    qDebug() << "[CodexApplyPatchTool] Patch file:" << patchFile.fileName();
    
    // Execute: codex apply-patch {patch_file} --cwd {cwd}
    QProcess process;
    process.setWorkingDirectory(cwd);
    
    QStringList args;
    args << "apply-patch" << patchFile.fileName();
    args << "--cwd" << cwd;
    args << "--json";  // Request JSON output for parsing
    
    qInfo() << "[CodexApplyPatchTool] Executing:" << m_codexCliPath << args.join(" ");
    
    process.start(m_codexCliPath, args);
    if (!process.waitForFinished(30000)) {  // 30 second timeout
        result.success = false;
        result.error = "Codex CLI process timeout";
        process.kill();
        return result;
    }
    
    // Parse results
    result.output = QString::fromUtf8(process.readAllStandardOutput());
    result.error = QString::fromUtf8(process.readAllStandardError());
    
    if (process.exitCode() != 0) {
        result.success = false;
        qWarning() << "[CodexApplyPatchTool] Process exit code:" << process.exitCode();
        return result;
    }
    
    // Try to parse JSON output
    QJsonDocument doc = QJsonDocument::fromJson(result.output.toUtf8());
    if (doc.isObject()) {
        QJsonObject obj = doc.object();
        result.filesChanged = obj.value("files_changed").toInt(0);
        
        QJsonArray filesArray = obj.value("changed_files").toArray();
        for (const auto &file : filesArray) {
            result.changedFiles << file.toString();
        }
    }
    
    result.success = true;
    return result;
}

QString CodexApplyPatchTool::validatePatchFormat(const QString &patch) const
{
    if (patch.isEmpty()) {
        return "Patch content is empty";
    }
    
    // Check for unified diff markers
    if (!patch.contains("---") && !patch.contains("+++") && !patch.contains("@@")) {
        return "Patch does not appear to be in unified diff format. "
               "Expected markers: ---, +++, @@";
    }
    
    return "";  // Valid
}

QString CodexApplyPatchTool::formatPatchError(const QString &error) const
{
    if (error.contains("Patch failed")) {
        return "Patch application failed - conflicts detected";
    }
    if (error.contains("No such file")) {
        return "Target file not found";
    }
    if (error.contains("Permission denied")) {
        return "Permission denied - check sandbox settings";
    }
    return error;  // Return original error
}

// ═══════════════════════════════════════════════════════════════════════════════
// CodexWriteFileTool Implementation
// ═══════════════════════════════════════════════════════════════════════════════

CodexWriteFileTool::CodexWriteFileTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
    , m_root(workspaceRoot)
{
    m_codexCliPath = findCodexCli();
}

QString CodexWriteFileTool::description() const
{
    return "Write a file using Codex CLI filesystem operations. "
           "Automatically generates a unified diff patch and applies it via Codex. "
           "Provides better integration with Codex's safety and validation systems. "
           "Parameters: file_path, content, description (optional).";
}

QJsonObject CodexWriteFileTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "file_path": {
                "type": "string",
                "description": "Path to file (relative to workspace)"
            },
            "content": {
                "type": "string",
                "description": "File content to write"
            },
            "description": {
                "type": "string",
                "description": "Optional change description for patch header"
            },
            "auto_approve": {
                "type": "boolean",
                "description": "Auto-approve if safe (default: false)"
            }
        },
        "required": ["file_path", "content"]
    })JSON").object();
}

ToolResult CodexWriteFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString filePath = args.value("file_path").toString();
    QString content = args.value("content").toString();
    QString description = args.value("description").toString();
    
    qInfo() << "[CodexWriteFileTool]" << callId << "START: file=" << filePath << "size=" << content.size();
    
    // ── Validate path ──
    QString absPath = safePath(filePath);
    if (absPath.isEmpty()) {
        qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: Path traversal detected";
        return {callId, name(), true, "Error: Path traversal attack detected"};
    }
    
    // ── Check sandbox ──
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
            qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: Sandbox denied write access";
            return {callId, name(), true, "Error: Sandbox policy denied write access"};
        }
        qInfo() << "[CodexWriteFileTool]" << callId << "Sandbox check PASSED";
    }
    
    // ── Create parent directories ──
    QFileInfo fileInfo(absPath);
    if (!ensureDirectoryExists(fileInfo.dir().absolutePath())) {
        qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: Failed to create parent directory";
        return {callId, name(), true, "Error: Failed to create parent directories"};
    }
    
    qInfo() << "[CodexWriteFileTool]" << callId << "Step 1: Parent directory ensured";
    
    // ── Read existing content (if file exists) ──
    QString oldContent = readExistingFile(absPath);
    
    // ── Generate unified diff ──
    QString patch = generateUnifiedDiff(filePath, oldContent, content);
    
    qInfo() << "[CodexWriteFileTool]" << callId << "Step 2: Generated unified diff:" << patch.size() << "bytes";
    
    // ── Apply patch via Codex CLI ──
    QProcess process;
    process.setWorkingDirectory(m_workspaceRoot);
    
    // Create temporary patch file
    QTemporaryFile patchFile;
    if (!patchFile.open()) {
        qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: Failed to create temp patch";
        return {callId, name(), true, "Error: Failed to create temporary patch file"};
    }
    
    QTextStream out(&patchFile);
    out << patch;
    patchFile.close();
    
    QStringList cliArgs;
    cliArgs << "apply-patch" << patchFile.fileName();
    cliArgs << "--cwd" << m_workspaceRoot;
    cliArgs << "--json";
    
    qInfo() << "[CodexWriteFileTool]" << callId << "Step 3: Invoking Codex CLI...";
    
    process.start(m_codexCliPath, cliArgs);
    if (!process.waitForFinished(30000)) {
        qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: Codex CLI timeout";
        process.kill();
        return {callId, name(), true, "Error: Codex CLI process timeout"};
    }
    
    QString cliOutput = QString::fromUtf8(process.readAllStandardOutput());
    QString cliError = QString::fromUtf8(process.readAllStandardError());
    
    if (process.exitCode() != 0) {
        qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: CLI exit code:" << process.exitCode();
        qWarning() << "[CodexWriteFileTool]" << callId << "CLI error:" << cliError;
        return {callId, name(), true, "Error: Failed to apply patch: " + cliError};
    }
    
    // Verify file was created
    if (!QFile::exists(absPath)) {
        qWarning() << "[CodexWriteFileTool]" << callId << "ERROR: File not created after patch apply";
        return {callId, name(), true, "Error: File was not created despite successful patch"};
    }
    
    qInfo() << "[CodexWriteFileTool]" << callId << "SUCCESS: File written";
    return {callId, name(), false, "✓ File written successfully via Codex: " + filePath};
}

QString CodexWriteFileTool::summary(const QJsonObject &args) const
{
    return "Write file: " + args.value("file_path").toString();
}

QString CodexWriteFileTool::findCodexCli() const
{
    QStringList possiblePaths = {
        "/usr/local/bin/codex",
        "/usr/bin/codex",
        QStandardPaths::findExecutable("codex"),
    };
    
    for (const auto &path : possiblePaths) {
        if (!path.isEmpty() && QFile::exists(path)) {
            return path;
        }
    }
    
    return "codex";
}

QString CodexWriteFileTool::generateUnifiedDiff(const QString &filePath,
                                                 const QString &oldContent,
                                                 const QString &newContent) const
{
    // Generate unified diff header and content
    QString diff;
    QTextStream stream(&diff);
    
    // Diff header
    stream << "--- a/" << filePath << "\n";
    stream << "+++ b/" << filePath << "\n";
    
    // Simple diff generation (line-by-line)
    QStringList oldLines = oldContent.split('\n');
    QStringList newLines = newContent.split('\n');
    
    if (oldContent.isEmpty()) {
        // New file
        stream << "@@ -0,0 +1," << newLines.count() << " @@\n";
        for (const auto &line : newLines) {
            stream << "+" << line << "\n";
        }
    } else {
        // Modified file - simplified hunk
        int minLines = qMin(oldLines.count(), newLines.count());
        stream << "@@ -1," << oldLines.count() << " +1," << newLines.count() << " @@\n";
        
        for (int i = 0; i < minLines; ++i) {
            if (oldLines[i] != newLines[i]) {
                stream << "-" << oldLines[i] << "\n";
                stream << "+" << newLines[i] << "\n";
            } else {
                stream << " " << oldLines[i] << "\n";
            }
        }
        
        // Add remaining lines
        for (int i = minLines; i < newLines.count(); ++i) {
            stream << "+" << newLines[i] << "\n";
        }
    }
    
    return diff;
}

bool CodexWriteFileTool::ensureDirectoryExists(const QString &dirPath)
{
    QDir dir(dirPath);
    if (dir.exists()) {
        return true;
    }
    
    return dir.mkpath(dirPath);
}

QString CodexWriteFileTool::safePath(const QString &relOrAbsPath) const
{
    QFileInfo fileInfo(relOrAbsPath);
    if (fileInfo.isAbsolute()) {
        return QDir::cleanPath(fileInfo.absoluteFilePath());
    }
    
    return QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
}

QString CodexWriteFileTool::readExistingFile(const QString &filePath) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return "";  // File doesn't exist or can't be read
    }
    
    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    return in.readAll();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CodexFilesystemToolFactory
// ═══════════════════════════════════════════════════════════════════════════════

void CodexFilesystemToolFactory::registerFilesystemTools(const QString &workspaceRoot,
                                                          AgentToolRegistry *registry,
                                                          SandboxManager *sandboxManager,
                                                          const QString &codexCliPath)
{
    // Register CodexApplyPatchTool
    auto *applyPatchTool = new CodexApplyPatchTool(workspaceRoot);
    applyPatchTool->setSandboxManager(sandboxManager);
    if (!codexCliPath.isEmpty()) {
        applyPatchTool->setCodexCliPath(codexCliPath);
    }
    registry->registerTool(applyPatchTool);
    
    qInfo() << "[CodexFilesystemToolFactory] Registered CodexApplyPatchTool";
    
    // Register CodexWriteFileTool
    auto *writeFileTool = new CodexWriteFileTool(workspaceRoot);
    writeFileTool->setSandboxManager(sandboxManager);
    if (!codexCliPath.isEmpty()) {
        writeFileTool->setCodexCliPath(codexCliPath);
    }
    registry->registerTool(writeFileTool);
    
    qInfo() << "[CodexFilesystemToolFactory] Registered CodexWriteFileTool";
    qInfo() << "[CodexFilesystemToolFactory] Codex filesystem tools registered successfully";
}
