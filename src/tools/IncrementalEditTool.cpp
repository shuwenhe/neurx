#include "tools/IncrementalEditTool.h"
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>
#include <algorithm>

IncrementalEditTool::IncrementalEditTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_root(workspaceRoot)
{
    qInfo() << "[IncrementalEditTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject IncrementalEditTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject operation;
    operation["type"] = "string";
    QJsonArray operationEnum;
    operationEnum.append("insert");
    operationEnum.append("replace");
    operationEnum.append("delete");
    operationEnum.append("append");
    operationEnum.append("batch");
    operation["enum"] = operationEnum;
    operation["description"] = "Edit operation type";
    properties["operation"] = operation;
    
    QJsonObject file;
    file["type"] = "string";
    file["description"] = "File path relative to workspace";
    properties["file"] = file;
    
    QJsonObject startLine;
    startLine["type"] = "integer";
    startLine["description"] = "Start line (1-based)";
    startLine["minimum"] = 1;
    properties["start_line"] = startLine;
    
    QJsonObject endLine;
    endLine["type"] = "integer";
    endLine["description"] = "End line (1-based, inclusive)";
    properties["end_line"] = endLine;
    
    QJsonObject content;
    content["type"] = "string";
    content["description"] = "Content to insert/replace/append";
    properties["content"] = content;
    
    QJsonObject createIfMissing;
    createIfMissing["type"] = "boolean";
    createIfMissing["description"] = "Create file if it doesn't exist";
    createIfMissing["default"] = false;
    properties["create_if_missing"] = createIfMissing;
    
    QJsonObject edits;
    edits["type"] = "array";
    edits["description"] = "Array of edit operations for batch mode";
    QJsonObject itemsSchema;
    itemsSchema["type"] = "object";
    edits["items"] = itemsSchema;
    properties["edits"] = edits;
    
    schema["properties"] = properties;
    
    QJsonArray required;
    required.append("operation");
    required.append("file");
    schema["required"] = required;
    
    return schema;
}

ToolResult IncrementalEditTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString operation = args["operation"].toString();

    if (operation == "batch") {
        return opBatchEdit(callId, args);
    }

    EditOperation op;
    op.filepath = args["file"].toString();
    op.startLine = args.value("start_line").toInt(1);
    op.endLine = args.value("end_line").toInt(op.startLine);
    op.content = args["content"].toString("");
    op.createIfMissing = args.value("create_if_missing").toBool(false);

    if (op.filepath.isEmpty()) {
        return {callId, name(), true, "File path cannot be empty"};
    }

    if (operation == "insert") {
        op.type = EditOperation::Insert;
    } else if (operation == "replace") {
        op.type = EditOperation::Replace;
    } else if (operation == "delete") {
        op.type = EditOperation::Delete;
    } else if (operation == "append") {
        op.type = EditOperation::Append;
    } else {
        return {callId, name(), true, "Unknown operation: " + operation};
    }

    EditResult result;
    switch (op.type) {
        case EditOperation::Insert:
            result = opInsertLines(op);
            break;
        case EditOperation::Replace:
            result = opReplaceLines(op);
            break;
        case EditOperation::Delete:
            result = opDeleteLines(op);
            break;
        case EditOperation::Append:
            result = opAppendLines(op);
            break;
    }

    QJsonObject response;
    response["file"] = result.filepath;
    response["success"] = result.success;
    response["lines_modified"] = result.linesModified;
    response["lines_added"] = result.linesAdded;
    response["lines_removed"] = result.linesRemoved;

    if (!result.preview.isEmpty()) {
        response["preview"] = result.preview;
    }

    if (!result.error.isEmpty()) {
        response["error"] = result.error;
    }

    return {callId, name(), !result.success, QJsonDocument(response).toJson(QJsonDocument::Compact)};
}

QString IncrementalEditTool::summary(const QJsonObject &args) const
{
    return args["operation"].toString() + " in " + args["file"].toString();
}

IncrementalEditTool::EditResult IncrementalEditTool::opInsertLines(const EditOperation &op)
{
    EditResult result;
    result.filepath = m_root.relativeFilePath(safePath(op.filepath));

    const QString absPath = safePath(op.filepath);
    if (absPath.isEmpty()) {
        result.error = "Invalid file path";
        return result;
    }

    QStringList lines = readFileLines(absPath);
    if (lines.isEmpty() && op.createIfMissing) {
        lines.clear();  // Start with empty file
    } else if (lines.isEmpty()) {
        result.error = "File does not exist";
        return result;
    }

    // Validate insertion point
    if (op.startLine < 1 || op.startLine > lines.count() + 1) {
        result.error = QString("Invalid insertion line %1 (file has %2 lines)")
                           .arg(op.startLine)
                           .arg(lines.count());
        return result;
    }

    // Insert content
    QStringList contentLines = op.content.split('\n', Qt::KeepEmptyParts);
    if (!contentLines.isEmpty() && contentLines.back().isEmpty()) {
        contentLines.pop_back();
    }

    int insertPos = op.startLine - 1;
    for (const QString& line : contentLines) {
        lines.insert(insertPos++, line);
    }
    result.linesAdded = contentLines.count();
    result.linesModified = contentLines.count();

    if (writeFileLines(absPath, lines)) {
        result.success = true;
        result.preview = QString("Inserted %1 lines at line %2")
                             .arg(contentLines.count())
                             .arg(op.startLine);
    } else {
        result.error = "Failed to write file";
    }

    return result;
}

IncrementalEditTool::EditResult IncrementalEditTool::opReplaceLines(const EditOperation &op)
{
    EditResult result;
    result.filepath = m_root.relativeFilePath(safePath(op.filepath));

    const QString absPath = safePath(op.filepath);
    if (absPath.isEmpty()) {
        result.error = "Invalid file path";
        return result;
    }

    QStringList lines = readFileLines(absPath);
    if (lines.isEmpty()) {
        result.error = "File does not exist or is empty";
        return result;
    }

    // Validate line range
    if (!validateLineRange(absPath, op.startLine, op.endLine)) {
        result.error = QString("Invalid line range %1-%2 (file has %3 lines)")
                           .arg(op.startLine)
                           .arg(op.endLine)
                           .arg(lines.count());
        return result;
    }

    // Get old lines for preview
    QStringList oldLines;
    for (int i = op.startLine - 1; i < op.endLine && i < lines.count(); ++i) {
        oldLines.append(lines[i]);
    }

    // Replace content
    QStringList newLines = op.content.split('\n', Qt::KeepEmptyParts);
    if (!newLines.isEmpty() && newLines.back().isEmpty()) {
        newLines.pop_back();
    }

    // Remove old lines
    for (int i = 0; i < op.endLine - op.startLine + 1 && !lines.isEmpty(); ++i) {
        lines.removeAt(op.startLine - 1);
    }

    // Insert new lines
    for (int i = 0; i < newLines.count(); ++i) {
        lines.insert(op.startLine - 1 + i, newLines[i]);
    }

    result.linesRemoved = oldLines.count();
    result.linesAdded = newLines.count();
    result.linesModified = qMax(result.linesAdded, result.linesRemoved);

    if (writeFileLines(absPath, lines)) {
        result.success = true;
        result.preview = QString("Replaced %1 lines at line %2 with %3 lines")
                             .arg(oldLines.count())
                             .arg(op.startLine)
                             .arg(newLines.count());
    } else {
        result.error = "Failed to write file";
    }

    return result;
}

IncrementalEditTool::EditResult IncrementalEditTool::opDeleteLines(const EditOperation &op)
{
    EditResult result;
    result.filepath = m_root.relativeFilePath(safePath(op.filepath));

    const QString absPath = safePath(op.filepath);
    if (absPath.isEmpty()) {
        result.error = "Invalid file path";
        return result;
    }

    QStringList lines = readFileLines(absPath);
    if (lines.isEmpty()) {
        result.error = "File is empty";
        return result;
    }

    // Validate line range
    if (!validateLineRange(absPath, op.startLine, op.endLine)) {
        result.error = QString("Invalid line range %1-%2 (file has %3 lines)")
                           .arg(op.startLine)
                           .arg(op.endLine)
                           .arg(lines.count());
        return result;
    }

    // Delete lines
    int linesToDelete = op.endLine - op.startLine + 1;
    for (int i = 0; i < linesToDelete && !lines.isEmpty(); ++i) {
        lines.removeAt(op.startLine - 1);
    }

    result.linesRemoved = linesToDelete;
    result.linesModified = linesToDelete;

    if (writeFileLines(absPath, lines)) {
        result.success = true;
        result.preview = QString("Deleted %1 lines at line %2")
                             .arg(linesToDelete)
                             .arg(op.startLine);
    } else {
        result.error = "Failed to write file";
    }

    return result;
}

IncrementalEditTool::EditResult IncrementalEditTool::opAppendLines(const EditOperation &op)
{
    EditResult result;
    result.filepath = m_root.relativeFilePath(safePath(op.filepath));

    const QString absPath = safePath(op.filepath);
    if (absPath.isEmpty()) {
        result.error = "Invalid file path";
        return result;
    }

    QStringList lines = readFileLines(absPath);
    if (lines.isEmpty() && !op.createIfMissing) {
        result.error = "File does not exist";
        return result;
    }

    // Append content
    QStringList contentLines = op.content.split('\n', Qt::KeepEmptyParts);
    if (!contentLines.isEmpty() && contentLines.back().isEmpty()) {
        contentLines.pop_back();
    }

    lines.append(contentLines);
    result.linesAdded = contentLines.count();
    result.linesModified = contentLines.count();

    if (writeFileLines(absPath, lines)) {
        result.success = true;
        result.preview = QString("Appended %1 lines to end of file")
                             .arg(contentLines.count());
    } else {
        result.error = "Failed to write file";
    }

    return result;
}

ToolResult IncrementalEditTool::opBatchEdit(const QString &callId, const QJsonObject &args)
{
    const auto editsArray = args["edits"].toArray();

    if (editsArray.isEmpty()) {
        return {callId, name(), true, "No edits specified"};
    }

    if (editsArray.count() > MAX_BATCH_EDITS) {
        return {callId, name(), true, QString("Too many edits (max %1)").arg(MAX_BATCH_EDITS)};
    }

    QJsonArray results;
    int successCount = 0;
    int errorCount = 0;

    for (const QJsonValue &editVal : editsArray) {
        const QJsonObject editObj = editVal.toObject();

        EditOperation op;
        op.filepath = editObj["file"].toString();
        op.startLine = editObj.value("start_line").toInt(1);
        op.endLine = editObj.value("end_line").toInt(op.startLine);
        op.content = editObj["content"].toString("");
        op.createIfMissing = editObj.value("create_if_missing").toBool(false);

        const QString opType = editObj["operation"].toString();
        if (opType == "insert") op.type = EditOperation::Insert;
        else if (opType == "replace") op.type = EditOperation::Replace;
        else if (opType == "delete") op.type = EditOperation::Delete;
        else if (opType == "append") op.type = EditOperation::Append;
        else continue;

        EditResult result;
        switch (op.type) {
            case EditOperation::Insert:
                result = opInsertLines(op);
                break;
            case EditOperation::Replace:
                result = opReplaceLines(op);
                break;
            case EditOperation::Delete:
                result = opDeleteLines(op);
                break;
            case EditOperation::Append:
                result = opAppendLines(op);
                break;
        }

        QJsonObject resultObj;
        resultObj["file"] = result.filepath;
        resultObj["success"] = result.success;
        resultObj["lines_modified"] = result.linesModified;

        if (result.success) {
            successCount++;
        } else {
            errorCount++;
        }

        results.append(resultObj);
    }

    QJsonObject summary;
    summary["total"] = editsArray.size();
    summary["succeeded"] = successCount;
    summary["failed"] = errorCount;
    summary["edits"] = results;

    return {callId, name(), errorCount > 0, QJsonDocument(summary).toJson(QJsonDocument::Compact)};
}

bool IncrementalEditTool::validateLineRange(const QString &filepath, int startLine, int endLine) const
{
    const QStringList lines = readFileLines(filepath);
    return startLine >= 1 && startLine <= lines.count() && endLine >= startLine && endLine <= lines.count();
}

bool IncrementalEditTool::validateContent(const QString &content) const
{
    // Ensure content is not too large
    return content.length() < 10 * 1024 * 1024;  // 10 MB limit
}

QString IncrementalEditTool::detectConflicts(const QString &filepath, int startLine, int endLine) const
{
    Q_UNUSED(filepath);
    Q_UNUSED(startLine);
    Q_UNUSED(endLine);
    return "";  // No conflict detection for now
}

QStringList IncrementalEditTool::readFileLines(const QString &filepath) const
{
    QFile file(filepath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    QTextStream in(&file);
    QStringList lines;
    while (!in.atEnd()) {
        lines.append(in.readLine());
    }
    file.close();

    return lines;
}

bool IncrementalEditTool::writeFileLines(const QString &filepath, const QStringList &lines) const
{
    QFile file(filepath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream out(&file);
    for (int i = 0; i < lines.count(); ++i) {
        out << lines[i];
        if (i < lines.count() - 1) {
            out << "\n";
        }
    }
    file.close();

    return true;
}

QString IncrementalEditTool::safePath(const QString &relOrAbsPath) const
{
    QFileInfo fi(relOrAbsPath);
    if (fi.isAbsolute()) {
        return QDir::cleanPath(fi.absoluteFilePath());
    }
    return QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
}

QString IncrementalEditTool::generatePreview(
    const QStringList &oldLines,
    const QStringList &newLines,
    int contextLines) const
{
    Q_UNUSED(oldLines);
    Q_UNUSED(newLines);
    Q_UNUSED(contextLines);
    return "";  // Preview generation can be expanded later
}
