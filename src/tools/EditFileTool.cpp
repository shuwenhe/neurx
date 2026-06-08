#include "tools/EditFileTool.h"
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QDir>
#include <QDateTime>
#include <QRegularExpression>
#include <QDebug>
#include <QJsonArray>

EditFileTool::EditFileTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[EditFileTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject EditFileTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({"find_replace", "edit_lines", "apply_patch"});
    typeObj["description"] = "Type of edit operation";
    properties["type"] = typeObj;
    
    QJsonObject pathObj;
    pathObj["type"] = "string";
    pathObj["description"] = "Relative path to file from workspace root";
    properties["path"] = pathObj;
    
    QJsonObject searchObj;
    searchObj["type"] = "string";
    searchObj["description"] = "Text or regex pattern to search for";
    properties["search"] = searchObj;
    
    QJsonObject replaceObj;
    replaceObj["type"] = "string";
    replaceObj["description"] = "Replacement text";
    properties["replace"] = replaceObj;
    
    QJsonObject regexObj;
    regexObj["type"] = "boolean";
    regexObj["description"] = "Use regex for search pattern";
    regexObj["default"] = false;
    properties["regex"] = regexObj;
    
    QJsonObject caseObj;
    caseObj["type"] = "boolean";
    caseObj["description"] = "Case sensitive search";
    caseObj["default"] = true;
    properties["case_sensitive"] = caseObj;
    
    QJsonObject previewObj;
    previewObj["type"] = "boolean";
    previewObj["description"] = "Preview changes without writing";
    previewObj["default"] = false;
    properties["preview"] = previewObj;
    
    QJsonObject lineStartObj;
    lineStartObj["type"] = "integer";
    lineStartObj["description"] = "Start line (1-based, for edit_lines)";
    properties["line_start"] = lineStartObj;
    
    QJsonObject lineEndObj;
    lineEndObj["type"] = "integer";
    lineEndObj["description"] = "End line (1-based, for edit_lines)";
    properties["line_end"] = lineEndObj;
    
    QJsonObject lineContentObj;
    lineContentObj["type"] = "string";
    lineContentObj["description"] = "New content for the line range";
    properties["line_content"] = lineContentObj;
    
    QJsonObject backupObj;
    backupObj["type"] = "boolean";
    backupObj["description"] = "Create backup before editing";
    backupObj["default"] = true;
    properties["backup"] = backupObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type", "path"});
    
    return schema;
}

ToolResult EditFileTool::execute(const QString &callId, const QJsonObject &args)
{
    EditOperation op = parseEditOp(args);
    
    if (op.type == "find_replace") {
        return opFindReplace(callId, op);
    } else if (op.type == "edit_lines") {
        return opEditLines(callId, op);
    } else if (op.type == "apply_patch") {
        return opApplyPatch(callId, op);
    }
    
    return {callId, name(), true, "Unknown edit type: " + op.type};
}

QString EditFileTool::summary(const QJsonObject &args) const
{
    return QString("%1 %2 in %3")
        .arg(args["type"].toString())
        .arg(args["search"].toString().left(20))
        .arg(args["path"].toString());
}

EditFileTool::EditOperation EditFileTool::parseEditOp(const QJsonObject &args)
{
    EditOperation op;
    op.type = args["type"].toString();
    op.filePath = args["path"].toString();
    op.searchPattern = args["search"].toString();
    op.replacement = args["replace"].toString();
    op.useRegex = args["regex"].toBool(false);
    op.caseSensitive = args["case_sensitive"].toBool(true);
    op.preview = args["preview"].toBool(false);
    op.lineStart = args["line_start"].toInt(0);
    op.lineEnd = args["line_end"].toInt(0);
    op.lineContent = args["line_content"].toString();
    return op;
}

QString EditFileTool::safePath(const QString &relPath) const
{
    QFileInfo info(relPath);
    if (info.isAbsolute()) {
        return QDir::cleanPath(info.absoluteFilePath());
    }
    
    QString absPath = QDir::cleanPath(m_workspaceRoot + "/" + relPath);
    QString relative = QDir(m_workspaceRoot).relativeFilePath(absPath);
    
    // 防止路径遍历
    if (relative.startsWith("..")) {
        return QString();
    }
    
    return absPath;
}

QString EditFileTool::createBackup(const QString &filePath)
{
    QString backupPath = filePath + ".bak-" + 
                        QDateTime::currentDateTime().toString("yyyyMMdd-hhmmss");
    
    if (!QFile::copy(filePath, backupPath)) {
        qWarning() << "[EditFileTool] Failed to create backup:" << backupPath;
        return QString();
    }
    
    qInfo() << "[EditFileTool] Created backup:" << backupPath;
    return backupPath;
}

ToolResult EditFileTool::opFindReplace(const QString &callId, const EditOperation &op)
{
    QString absPath = safePath(op.filePath);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected: " + op.filePath};
    }
    
    QFile file(absPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Failed to open file: " + absPath};
    }
    
    QString content = file.readAll();
    file.close();
    
    bool success = false;
    QString newContent = performFindReplace(content, op, &success);
    
    if (!success) {
        return {callId, name(), true, "Find/Replace operation failed"};
    }
    
    if (content == newContent) {
        return {callId, name(), false, "No matches found for pattern: " + op.searchPattern};
    }
    
    if (op.preview) {
        // 只返回预览，不写入
        QJsonObject preview;
        preview["matched"] = newContent != content;
        preview["preview"] = newContent.left(500) + (newContent.length() > 500 ? "..." : "");
        preview["changes"] = (int)std::count(content.begin(), content.end(), '\n') -
                            (int)std::count(newContent.begin(), newContent.end(), '\n');
        
        QJsonObject result;
        result["preview"] = preview;
        return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
    }
    
    // 创建备份
    QString backup = createBackup(absPath);
    if (backup.isEmpty()) {
        return {callId, name(), true, "Failed to create backup before edit"};
    }
    
    // 写入新内容
    QFile outFile(absPath);
    if (!outFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return {callId, name(), true, "Failed to write file: " + absPath};
    }
    
    QTextStream out(&outFile);
    out << newContent;
    outFile.close();
    
    return {callId, name(), false, 
            "Find & Replace completed. Backup: " + QFileInfo(backup).fileName()};
}

ToolResult EditFileTool::opEditLines(const QString &callId, const EditOperation &op)
{
    if (op.lineStart <= 0 || op.lineEnd <= 0 || op.lineStart > op.lineEnd) {
        return {callId, name(), true, "Invalid line range"};
    }
    
    QString absPath = safePath(op.filePath);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal detected: " + op.filePath};
    }
    
    QFile file(absPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Failed to open file: " + absPath};
    }
    
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) {
        lines.append(in.readLine());
    }
    file.close();
    
    // 检查行号
    if (op.lineStart > lines.count() || op.lineEnd > lines.count()) {
        return {callId, name(), true, 
                QString("Invalid line range: file has %1 lines").arg(lines.count())};
    }
    
    // 编辑指定行（1-based 转换为 0-based）
    for (int i = op.lineStart - 1; i < op.lineEnd; ++i) {
        lines[i] = op.lineContent;
    }
    
    QString newContent = lines.join('\n');
    
    if (op.preview) {
        return {callId, name(), false, newContent.left(500)};
    }
    
    // 创建备份
    QString backup = createBackup(absPath);
    if (backup.isEmpty()) {
        return {callId, name(), true, "Failed to create backup"};
    }
    
    // 写入
    QFile outFile(absPath);
    if (!outFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return {callId, name(), true, "Failed to write file"};
    }
    
    QTextStream out(&outFile);
    out << newContent;
    outFile.close();
    
    return {callId, name(), false, 
            QString("Edited lines %1-%2. Backup: %3")
                .arg(op.lineStart).arg(op.lineEnd).arg(QFileInfo(backup).fileName())};
}

ToolResult EditFileTool::opApplyPatch(const QString &callId, const EditOperation &op)
{
    // TODO: 实现 patch 应用逻辑
    return {callId, name(), false, "Patch application stub - to be implemented"};
}

QString EditFileTool::performFindReplace(const QString &content, const EditOperation &op, bool *success)
{
    *success = true;
    QString result = content;
    
    if (op.useRegex) {
        QRegularExpression::PatternOptions options = QRegularExpression::NoPatternOption;
        if (!op.caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }
        
        QRegularExpression regex(op.searchPattern, options);
        if (!regex.isValid()) {
            *success = false;
            qWarning() << "[EditFileTool] Invalid regex:" << op.searchPattern;
            return content;
        }
        
        return result.replace(regex, op.replacement);
    } else {
        // 手动实现大小写敏感的文本替换
        if (op.caseSensitive) {
            result.replace(op.searchPattern, op.replacement);
        } else {
            // 不区分大小写的替换需要手动处理
            int idx = 0;
            while ((idx = result.indexOf(op.searchPattern, idx, Qt::CaseInsensitive)) != -1) {
                result.replace(idx, op.searchPattern.length(), op.replacement);
                idx += op.replacement.length();
            }
        }
        
        return result;
    }
}

QString EditFileTool::performLineEdit(const QString &content, const EditOperation &op, bool *success)
{
    *success = true;
    
    QStringList lines = content.split('\n');
    if (op.lineStart < 1 || op.lineEnd < 1 || op.lineStart > lines.count()) {
        *success = false;
        return content;
    }
    
    for (int i = op.lineStart - 1; i < qMin(op.lineEnd, lines.count()); ++i) {
        lines[i] = op.lineContent;
    }
    
    return lines.join('\n');
}
