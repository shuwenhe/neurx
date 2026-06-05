#include "tools/FileCreationTool.h"
#include "sandbox/SandboxManager.h"
#include "tools/CheckpointManager.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcess>
#include <QTemporaryFile>
#include <QDateTime>
#include <QSaveFile>

FileCreationTool::FileCreationTool(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
    // Protect sensitive paths
    m_protectedPaths << 
        QDir::homePath() + "/.ssh" <<
        QDir::homePath() + "/.gnupg" <<
        QDir::homePath() + "/.aws" <<
        "/etc/sudoers" <<
        "/etc/passwd" <<
        "/etc/shadow";
}

FileCreationTool::~FileCreationTool() = default;

QJsonObject FileCreationTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject props;
    
    QJsonObject operationProp;
    operationProp["type"] = "string";
    operationProp["enum"] = QJsonArray({"create_file", "write_file", "create_batch"});
    operationProp["description"] = "The file operation to perform";
    props["operation"] = operationProp;
    
    QJsonObject pathProp;
    pathProp["type"] = "string";
    pathProp["description"] = "File path relative to workspace root";
    props["path"] = pathProp;
    
    QJsonObject contentProp;
    contentProp["type"] = "string";
    contentProp["description"] = "File content to write";
    props["content"] = contentProp;
    
    QJsonObject overwriteProp;
    overwriteProp["type"] = "boolean";
    overwriteProp["description"] = "Whether to overwrite existing files";
    overwriteProp["default"] = false;
    props["overwrite"] = overwriteProp;
    
    QJsonObject createDirsProp;
    createDirsProp["type"] = "boolean";
    createDirsProp["description"] = "Automatically create parent directories";
    createDirsProp["default"] = true;
    props["create_dirs"] = createDirsProp;
    
    QJsonObject lineEndingProp;
    lineEndingProp["type"] = "string";
    lineEndingProp["enum"] = QJsonArray({"auto", "lf", "crlf"});
    lineEndingProp["description"] = "Line ending style";
    lineEndingProp["default"] = "auto";
    props["line_ending"] = lineEndingProp;
    
    QJsonObject filesProp;
    filesProp["type"] = "array";
    filesProp["description"] = "Array of files for batch operations";
    props["files"] = filesProp;
    
    schema["properties"] = props;
    
    QJsonArray required;
    required.append("operation");
    schema["required"] = required;
    
    return schema;
}

ToolResult FileCreationTool::execute(const QString& callId, const QJsonObject& args)
{
    const QString operation = args["operation"].toString();
    
    if (operation == "create_file") {
        return opCreateFile(callId, args);
    } else if (operation == "write_file") {
        return opWriteFile(callId, args);
    } else if (operation == "create_batch") {
        return opCreateBatch(callId, args);
    }
    
    return {callId, name(), true, "Unknown operation: " + operation};
}

QString FileCreationTool::summary(const QJsonObject& args) const
{
    const QString op = args["operation"].toString();
    const QString path = args["path"].toString();
    return op + ": " + path;
}

void FileCreationTool::setSandboxManager(SandboxManager* manager)
{
    m_sandboxManager = manager;
}

void FileCreationTool::setCheckpointManager(CheckpointManager* manager)
{
    m_checkpointManager = manager;
}

ToolResult FileCreationTool::opCreateFile(const QString& callId, const QJsonObject& args)
{
    const QString path = args["path"].toString();
    const QString content = args["content"].toString();
    
    if (path.isEmpty()) {
        return {callId, name(), true, "Path cannot be empty"};
    }
    
    FileSpec spec;
    spec.path = path;
    spec.content = content;
    spec.overwrite = args.contains("overwrite") ? args["overwrite"].toBool() : false;
    spec.createDirs = args.contains("create_dirs") ? args["create_dirs"].toBool() : true;
    spec.lineEnding = args.contains("line_ending") ? args["line_ending"].toString() : "auto";
    spec.preserveExisting = true;
    
    const QString absPath = safePath(spec.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected"};
    }
    
    if (QFileInfo::exists(absPath) && !spec.overwrite) {
        return {callId, name(), true, "File already exists. Use overwrite=true to replace."};
    }
    
    if (QFileInfo::exists(absPath)) {
        createCheckpoint(spec.path, "Before file modification");
    }
    
    WriteResultData result = writeFileAtomic(spec);
    
    if (!result.error.isEmpty()) {
        return {callId, name(), true, result.error};
    }
    
    return {callId, name(), false, QJsonDocument(resultToJson(result)).toJson()};
}

ToolResult FileCreationTool::opWriteFile(const QString& callId, const QJsonObject& args)
{
    QJsonObject modifiedArgs = args;
    if (!modifiedArgs.contains("overwrite")) {
        modifiedArgs["overwrite"] = true;
    }
    return opCreateFile(callId, modifiedArgs);
}

ToolResult FileCreationTool::opCreateBatch(const QString& callId, const QJsonObject& args)
{
    const auto filesArray = args["files"].toArray();
    
    if (filesArray.isEmpty()) {
        return {callId, name(), true, "No files specified"};
    }
    
    QJsonArray results;
    int successCount = 0;
    int errorCount = 0;
    
    for (const QJsonValue& fileVal : filesArray) {
        const QJsonObject fileObj = fileVal.toObject();
        
        FileSpec spec;
        spec.path = fileObj["path"].toString();
        spec.content = fileObj["content"].toString();
        spec.overwrite = fileObj.contains("overwrite") ? fileObj["overwrite"].toBool() : false;
        spec.createDirs = fileObj.contains("create_dirs") ? fileObj["create_dirs"].toBool() : true;
        
        if (spec.path.isEmpty()) {
            QJsonObject resultObj;
            resultObj["error"] = "Path cannot be empty";
            results.append(resultObj);
            errorCount++;
            continue;
        }

        WriteResultData result = writeFileAtomic(spec);
        
        QJsonObject resultObj = resultToJson(result);
        if (result.error.isEmpty()) {
            successCount++;
        } else {
            errorCount++;
        }
        
        results.append(resultObj);
    }
    
    QJsonObject summary;
    summary["total"] = filesArray.size();
    summary["succeeded"] = successCount;
    summary["failed"] = errorCount;
    summary["files"] = results;
    
    return {callId, name(), errorCount > 0, QJsonDocument(summary).toJson()};
}

FileCreationTool::WriteResultData FileCreationTool::writeFileAtomic(const FileSpec& spec)
{
    WriteResultData result;
    result.filepath = spec.path;
    
    const QString absPath = safePath(spec.path);
    if (absPath.isEmpty()) {
        result.error = "Invalid path";
        return result;
    }
    
    // Read existing content for metadata
    QString existingContent;
    if (QFileInfo::exists(absPath)) {
        existingContent = readExistingContent(absPath);
    }
    
    // Detect line ending
    QString lineEnding = spec.lineEnding;
    if (lineEnding == "auto") {
        lineEnding = detectLineEnding(absPath, existingContent);
        if (lineEnding.isEmpty()) {
            lineEnding = "lf";
        }
    }
    result.lineEndingDetected = lineEnding;
    
    // Prepare content
    QString content = spec.content;
    content = normalizeLineEndings(content, lineEnding);
    
    // Create parent directories
    QFileInfo fileInfo(absPath);
    if (spec.createDirs) {
        if (!ensureDirectories(fileInfo.dir().absolutePath())) {
            result.error = "Failed to create parent directories";
            return result;
        }
        result.dirsCreated = true;
    }
    
    // Atomic write using QSaveFile (creates a safe temp file and commits atomically)
    bool existed = QFileInfo::exists(absPath);
    QFile::Permissions originalPerms;
    if (existed) {
        originalPerms = QFileInfo(absPath).permissions();
    }

    QSaveFile save(absPath);
    if (!save.open(QIODevice::WriteOnly | QIODevice::Text)) {
        result.error = QString("Failed to open temporary save file: %1").arg(save.errorString());
        return result;
    }

    QTextStream out(&save);
    out.setEncoding(QStringConverter::Utf8);
    out << content;
    out.flush();

    if (!save.commit()) {
        // commit failed, temp file is automatically removed
        result.error = QString("Failed to finalize write: %1").arg(save.errorString());
        return result;
    }

    // If file existed before, try to restore original permissions
    if (existed) {
        QFile::setPermissions(absPath, originalPerms);
    }

    // Report written size
    result.bytesWritten = QFileInfo(absPath).size();

    // Syntax checking
    result.lintResults = checkSyntax(spec.path, content);
    
    return result;
}

bool FileCreationTool::ensureDirectories(const QString& path)
{
    return m_workspaceRoot.mkpath(path);
}

QString FileCreationTool::detectLineEnding(const QString& path, const QString& existingContent)
{
    QString contentToCheck = existingContent;
    
    if (contentToCheck.isEmpty()) {
        const QString absPath = safePath(path);
        if (!absPath.isEmpty() && QFileInfo::exists(absPath)) {
            contentToCheck = readExistingContent(absPath);
        }
    }
    
    if (contentToCheck.contains("\r\n")) {
        return "crlf";
    } else if (contentToCheck.contains("\n")) {
        return "lf";
    }
    
    return "";
}

bool FileCreationTool::detectBOM(const QString& path, const QString& existingContent)
{
    if (existingContent.startsWith(QChar(0xFEFF))) {
        return true;
    }
    
    const QString absPath = safePath(path);
    if (!absPath.isEmpty() && QFileInfo::exists(absPath)) {
        QFile file(absPath);
        if (file.open(QIODevice::ReadOnly)) {
            QByteArray header = file.read(3);
            file.close();
            return header == QByteArray("\xEF\xBB\xBF");
        }
    }
    
    return false;
}

QString FileCreationTool::normalizeLineEndings(const QString& content, const QString& targetEnding)
{
    QString normalized = content;
    normalized.replace("\r\n", "\n");
    normalized.replace("\r", "\n");
    
    if (targetEnding == "crlf") {
        normalized.replace("\n", "\r\n");
    }
    
    return normalized;
}

bool FileCreationTool::copyFilePermissions(const QString& from, const QString& to)
{
    QFileInfo fromInfo(from);
    QFileInfo toInfo(to);
    
    if (fromInfo.exists() && toInfo.exists()) {
        return QFile::setPermissions(to, fromInfo.permissions());
    }
    
    return false;
}

QString FileCreationTool::readExistingContent(const QString& path)
{
    const QString absPath = safePath(path);
    if (absPath.isEmpty()) {
        return "";
    }
    
    QFile file(absPath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString content = file.readAll();
        file.close();
        return content;
    }
    
    return "";
}

bool FileCreationTool::isWriteAllowed(const QString& path)
{
    Q_UNUSED(path)
    return true;
}

bool FileCreationTool::isSensitivePath(const QString& path) const
{
    Q_UNUSED(path)
    return false;
}

QString FileCreationTool::safePath(const QString& relOrAbsPath) const
{
    QFileInfo fi(relOrAbsPath);
    if (fi.isAbsolute())
        return QDir::cleanPath(fi.absoluteFilePath());
    return QDir::cleanPath(m_workspaceRoot.absoluteFilePath(relOrAbsPath));
}

QJsonObject FileCreationTool::checkSyntax(const QString& path, const QString& content)
{
    QJsonObject result;
    result["path"] = path;
    result["status"] = "ok";
    
    const QString ext = QFileInfo(path).suffix().toLower();
    
    if (ext == "json") {
        QString error;
        if (!checkJSONSyntax(content, error)) {
            result["status"] = "error";
            result["error"] = error;
        }
    } else if (ext == "py") {
        QString error;
        if (!checkPythonSyntax(content, error)) {
            result["status"] = "error";
            result["error"] = error;
        }
    }
    
    return result;
}

bool FileCreationTool::checkJSONSyntax(const QString& content, QString& error)
{
    QJsonParseError parseError;
    QJsonDocument::fromJson(content.toUtf8(), &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        error = QString("JSON Error at %1: %2")
            .arg(parseError.offset)
            .arg(parseError.errorString());
        return false;
    }
    
    return true;
}

bool FileCreationTool::checkPythonSyntax(const QString& content, QString& error)
{
    QProcess process;
    process.start("python3", QStringList() << "-m" << "py_compile" << "-");
    process.write(content.toUtf8());
    process.closeWriteChannel();
    process.waitForFinished(5000);
    
    if (process.exitCode() != 0) {
        error = process.readAllStandardError();
        return false;
    }
    
    return true;
}

QString FileCreationTool::createCheckpoint(const QString& path, const QString& description)
{
    if (!m_checkpointManager) {
        return "";
    }
    
    return m_checkpointManager->checkpoint(QStringList() << path, description);
}

QJsonObject FileCreationTool::resultToJson(const WriteResultData& result)
{
    QJsonObject obj;
    obj["filepath"] = result.filepath;
    obj["bytes_written"] = result.bytesWritten;
    obj["dirs_created"] = result.dirsCreated;
    obj["line_ending"] = result.lineEndingDetected;
    
    if (!result.lintResults.isEmpty()) {
        obj["lint"] = result.lintResults;
    }
    
    if (!result.error.isEmpty()) {
        obj["error"] = result.error;
    }
    
    return obj;
}
