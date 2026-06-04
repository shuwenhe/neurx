#include "tools/SmartFileCreator.h"
#include "sandbox/SandboxManager.h"
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDateTime>
#include <QRegularExpression>

static QString toPascalCase(QString text)
{
    text.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9]+")), QStringLiteral(" "));
    const QStringList parts = text.split(' ', Qt::SkipEmptyParts);
    QString result;
    for (const QString &part : parts) {
        if (part.isEmpty())
            continue;
        result += part.left(1).toUpper() + part.mid(1);
    }
    return result.isEmpty() ? QStringLiteral("GeneratedClass") : result;
}

static QString toMacroCase(QString text)
{
    text.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9]+")), QStringLiteral("_"));
    text = text.toUpper();
    text.replace(QRegularExpression(QStringLiteral("_+")), QStringLiteral("_"));
    return text.isEmpty() ? QStringLiteral("GENERATED_FILE") : text;
}

SmartFileCreator::SmartFileCreator(const QString& workspaceRoot, QObject* parent)
    : BaseTool(parent)
    , m_root(workspaceRoot)
    , m_llmProvider(nullptr)
    , m_sandboxManager(nullptr)
{
    initializeTemplates();
}

QJsonObject SmartFileCreator::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "mode": {
                "type": "string",
                "enum": ["simple", "smart", "template", "batch", "structure"],
                "description": "Creation mode: simple (basic), smart (AI-generated), template (from template), batch (multiple files), structure (directory structure)",
                "default": "simple"
            },
            "path": {
                "type": "string",
                "description": "File path relative to workspace root"
            },
            "content": {
                "type": "string",
                "description": "File content (for simple mode)"
            },
            "intent": {
                "type": "string",
                "description": "Description of what the file should contain (for smart mode)"
            },
            "template": {
                "type": "string",
                "description": "Template name to use (for template mode)"
            },
            "template_vars": {
                "type": "object",
                "description": "Variables to fill in template"
            },
            "files": {
                "type": "array",
                "description": "Array of file specifications (for batch/structure mode)",
                "items": {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string"},
                        "content": {"type": "string"},
                        "intent": {"type": "string"},
                        "template": {"type": "string"}
                    }
                }
            },
            "structure_intent": {
                "type": "string",
                "description": "Description of overall structure (for structure mode)"
            },
            "related_files": {
                "type": "array",
                "description": "Related files for context",
                "items": {"type": "string"}
            },
            "overwrite": {
                "type": "boolean",
                "description": "Allow overwriting existing files",
                "default": false
            },
            "create_dirs": {
                "type": "boolean",
                "description": "Create parent directories if needed",
                "default": true
            },
            "generate_missing": {
                "type": "boolean",
                "description": "Generate missing related files (batch/structure mode)",
                "default": false
            }
        }
    })JSON").object();
}

ToolResult SmartFileCreator::execute(const QString& callId, const QJsonObject& args)
{
    const QString modeStr = args.value("mode").toString("simple");
    CreationMode mode = CreationMode::Simple;
    
    if (modeStr == "smart") mode = CreationMode::Smart;
    else if (modeStr == "template") mode = CreationMode::Template;
    else if (modeStr == "batch") mode = CreationMode::Batch;
    else if (modeStr == "structure") mode = CreationMode::Structure;
    
    // Handle batch and structure modes
    if (mode == CreationMode::Batch || mode == CreationMode::Structure) {
        BatchCreationRequest batchReq;
        batchReq.structureIntent = args.value("structure_intent").toString();
        batchReq.generateMissing = args.value("generate_missing").toBool(false);
        const bool defaultOverwrite = args.value("overwrite").toBool(false);
        const bool defaultCreateDirs = args.value("create_dirs").toBool(true);
        
        QJsonArray filesArray = args.value("files").toArray();
        for (const QJsonValue& fileVal : filesArray) {
            QJsonObject fileObj = fileVal.toObject();
            FileCreationRequest fileReq;
            fileReq.path = fileObj.value("path").toString();
            fileReq.content = fileObj.value("content").toString();
            fileReq.intent = fileObj.value("intent").toString();
            fileReq.templateName = fileObj.value("template").toString();
            fileReq.templateVars = fileObj.value("template_vars").toObject().toVariantMap();
            fileReq.overwrite = fileObj.contains("overwrite")
                ? fileObj.value("overwrite").toBool(false)
                : defaultOverwrite;
            fileReq.createDirs = fileObj.contains("create_dirs")
                ? fileObj.value("create_dirs").toBool(true)
                : defaultCreateDirs;
            if (!fileReq.intent.isEmpty()) fileReq.mode = CreationMode::Smart;
            else if (!fileReq.templateName.isEmpty()) fileReq.mode = CreationMode::Template;

            const QJsonArray relatedArray = fileObj.value("related_files").toArray();
            for (const QJsonValue &relatedVal : relatedArray)
                fileReq.relatedFiles.append(relatedVal.toString());
            
            batchReq.files.append(fileReq);
        }

        if (batchReq.files.isEmpty())
            return {callId, name(), true, "No files were provided for batch creation."};
        
        if (mode == CreationMode::Structure)
            return createStructure(callId, batchReq);
        else
            return createBatch(callId, batchReq);
    }
    
    // Handle single file creation
    FileCreationRequest req;
    req.path = args.value("path").toString();
    req.content = args.value("content").toString();
    req.intent = args.value("intent").toString();
    req.templateName = args.value("template").toString();
    req.templateVars = args.value("template_vars").toObject().toVariantMap();
    req.overwrite = args.value("overwrite").toBool(false);
    req.createDirs = args.value("create_dirs").toBool(true);
    req.mode = mode;

    if (req.path.trimmed().isEmpty())
        return {callId, name(), true, "Path cannot be empty."};
    
    QJsonArray relatedArray = args.value("related_files").toArray();
    for (const QJsonValue& val : relatedArray) {
        req.relatedFiles.append(val.toString());
    }
    
    // Validate path
    QString error;
    if (!validatePath(req.path, error)) {
        return {callId, name(), true, error};
    }
    
    // Check sandbox
    QString absPath = safePath(req.path);
    if (absPath.isEmpty()) {
        return {callId, name(), true, "Path traversal denied."};
    }
    
    if (m_sandboxManager) {
        if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
            return {callId, name(), true, "Sandbox policy denied write access."};
        }
    }
    
    // Check overwrite
    if (QFile::exists(absPath) && !req.overwrite) {
        return {callId, name(), true, "File already exists. Use overwrite=true to replace."};
    }
    
    // Execute based on mode
    switch (mode) {
        case CreationMode::Simple:
            return createSimpleFile(callId, req);
        case CreationMode::Smart:
            return createSmartFile(callId, req);
        case CreationMode::Template:
            return createFromTemplate(callId, req);
        default:
            return {callId, name(), true, "Invalid creation mode."};
    }
}

QString SmartFileCreator::summary(const QJsonObject& args) const
{
    const QString mode = args.value("mode").toString("simple");
    const QString path = args.value("path").toString();
    return QString("Create file (%1): %2").arg(mode, path);
}

// ─────────────────────────────────────────────────────────────────────────────
// Creation Operations
// ─────────────────────────────────────────────────────────────────────────────

ToolResult SmartFileCreator::createSimpleFile(const QString& callId, const FileCreationRequest& req)
{
    const QString absPath = safePath(req.path);
    if (absPath.isEmpty())
        return {callId, name(), true, "Path traversal denied."};
    if (m_sandboxManager && !m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write))
        return {callId, name(), true, "Sandbox policy denied write access."};
    if (QFile::exists(absPath) && !req.overwrite)
        return {callId, name(), true, "File already exists. Use overwrite=true to replace."};
    
    // Create parent directories
    if (req.createDirs) {
        QFileInfo fi(absPath);
        if (!ensureDirectoryExists(fi.dir().absolutePath())) {
            return {callId, name(), true, "Failed to create parent directories."};
        }
    }
    
    // Write file atomically
    QSaveFile file(absPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return {callId, name(), true, "Cannot open file for writing: " + file.errorString()};
    }

    QTextStream out(&file);
    
    // Add header if appropriate
    if (isSourceFile(req.path) || isHeaderFile(req.path)) {
        QVariantMap metadata;
        metadata["created"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        metadata["tool"] = "SmartFileCreator";
        out << generateFileHeader(req.path, metadata);
        out << "\n\n";
    }
    
    // Write content
    if (!req.content.isEmpty()) {
        out << req.content;
    } else {
        // Generate basic boilerplate
        QString boilerplate = generateBoilerplate(req.path, detectFileType(req.path));
        out << boilerplate;
    }
    out.flush();
    if (!file.commit()) {
        return {callId, name(), true, "Failed to commit file write."};
    }
    
    return {callId, name(), false, QString("Created: %1").arg(req.path)};
}

ToolResult SmartFileCreator::createSmartFile(const QString& callId, const FileCreationRequest& req)
{
    if (!m_llmProvider) {
        // Fallback to simple creation with boilerplate
        return createSimpleFile(callId, req);
    }
    
    // Generate intelligent content
    QString smartContent = generateSmartContent(req.path, req.intent, req.relatedFiles);
    
    if (smartContent.isEmpty()) {
        return {callId, name(), true, "Failed to generate intelligent content."};
    }
    
    // Create request with generated content
    FileCreationRequest modifiedReq = req;
    modifiedReq.content = smartContent;
    modifiedReq.mode = CreationMode::Simple;
    
    return createSimpleFile(callId, modifiedReq);
}

ToolResult SmartFileCreator::createFromTemplate(const QString& callId, const FileCreationRequest& req)
{
    // Get template
    FileTemplate tmpl = getTemplate(req.templateName);
    
    if (tmpl.name.isEmpty()) {
        return {callId, name(), true, QString("Template not found: %1").arg(req.templateName)};
    }
    
    // Apply template
    QString content = applyTemplate(tmpl, req.templateVars);
    
    // Create request with template content
    FileCreationRequest modifiedReq = req;
    modifiedReq.content = content;
    modifiedReq.mode = CreationMode::Simple;
    
    return createSimpleFile(callId, modifiedReq);
}

ToolResult SmartFileCreator::createBatch(const QString& callId, const BatchCreationRequest& req)
{
    QStringList created;
    QStringList failed;
    
    for (const FileCreationRequest& fileReq : req.files) {
        ToolResult result;
        
        switch (fileReq.mode) {
            case CreationMode::Smart:
                result = createSmartFile(callId, fileReq);
                break;
            case CreationMode::Template:
                result = createFromTemplate(callId, fileReq);
                break;
            default:
                result = createSimpleFile(callId, fileReq);
                break;
        }
        
        if (result.isError) {
            failed.append(QString("%1: %2").arg(fileReq.path, result.content));
        } else {
            created.append(fileReq.path);
        }
    }
    
    QString summary = QString("Created %1 files").arg(created.size());
    if (!failed.isEmpty()) {
        summary += QString(", %1 failed").arg(failed.size());
    }
    
    QString details = "Created:\n" + created.join("\n");
    if (!failed.isEmpty()) {
        details += "\n\nFailed:\n" + failed.join("\n");
    }
    
    return {callId, name(), !failed.isEmpty(), details};
}

ToolResult SmartFileCreator::createStructure(const QString& callId, const BatchCreationRequest& req)
{
    // For structure mode, first analyze the intent and suggest additional files
    if (req.generateMissing && !req.structureIntent.isEmpty()) {
        // TODO: Use LLM to analyze structure intent and suggest missing files
    }
    
    // Create all files in the structure
    return createBatch(callId, req);
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Generation
// ─────────────────────────────────────────────────────────────────────────────

QString SmartFileCreator::generateFileHeader(const QString& filePath, const QVariantMap& metadata)
{
    QFileInfo fi(filePath);
    QString fileName = fi.fileName();
    QString lang = detectLanguage(filePath);
    
    QString header;
    QString commentStart, commentEnd, commentLine;
    
    // Determine comment style
    if (lang == "cpp" || lang == "c" || lang == "java" || lang == "javascript") {
        commentStart = "/**";
        commentEnd = " */";
        commentLine = " * ";
    } else if (lang == "python") {
        commentStart = "\"\"\"";
        commentEnd = "\"\"\"";
        commentLine = "";
    } else if (lang == "shell") {
        commentStart = "#";
        commentEnd = "";
        commentLine = "# ";
    } else {
        return "";  // No header for unknown types
    }
    
    header += commentStart + "\n";
    header += commentLine + "@file " + fileName + "\n";
    
    if (metadata.contains("description")) {
        header += commentLine + "@brief " + metadata["description"].toString() + "\n";
    }
    
    if (metadata.contains("author")) {
        header += commentLine + "@author " + metadata["author"].toString() + "\n";
    }
    
    if (metadata.contains("created")) {
        header += commentLine + "@date " + metadata["created"].toString() + "\n";
    }
    
    header += commentEnd;
    
    return header;
}

QString SmartFileCreator::generateBoilerplate(const QString& filePath, const QString& fileType)
{
    QFileInfo fi(filePath);
    QString baseName = fi.completeBaseName();
    QString ext = fi.suffix().toLower();
    
    if (ext == "h" || ext == "hpp") {
        // C++ header
        QString guard = baseName.toUpper() + "_H";
        QString boilerplate = QString(
            "#pragma once\n\n"
            "#ifndef %1\n"
            "#define %1\n\n"
            "// TODO: Add declarations here\n\n"
            "#endif // %1\n"
        ).arg(guard);
        return boilerplate;
    }
    
    if (ext == "cpp" || ext == "cc") {
        // C++ source
        QString headerName = baseName + ".h";
        QString boilerplate = QString(
            "#include \"%1\"\n\n"
            "// TODO: Add implementations here\n"
        ).arg(headerName);
        return boilerplate;
    }
    
    if (ext == "py") {
        // Python module
        return QString(
            "#!/usr/bin/env python3\n"
            "# -*- coding: utf-8 -*-\n\n"
            "\"\"\"Module docstring.\"\"\"\n\n"
            "# TODO: Add code here\n"
        );
    }
    
    if (ext == "js" || ext == "ts") {
        // JavaScript/TypeScript
        return QString(
            "/**\n"
            " * Module: %1\n"
            " */\n\n"
            "// TODO: Add code here\n"
        ).arg(baseName);
    }
    
    if (ext == "md") {
        // Markdown
        return QString("# %1\n\n").arg(baseName);
    }
    
    return "// TODO: Add content\n";
}

QString SmartFileCreator::generateSmartContent(const QString& filePath, 
                                               const QString& intent,
                                               const QStringList& relatedFiles)
{
    QString fileType = detectFileType(filePath);
    QVariantMap metadata = extractMetadata(filePath, intent);
    metadata["brief"] = intent.isEmpty() ? QStringLiteral("Auto-generated file") : intent;
    metadata["description"] = intent;
    metadata["project_name"] = QFileInfo(m_root.absolutePath()).fileName();
    metadata["title"] = metadata.value("baseName").toString().isEmpty()
        ? QFileInfo(filePath).fileName()
        : metadata.value("baseName").toString();
    metadata["module_name"] = metadata.value("baseName").toString();

    const QString inferredType = inferFileTypeFromIntent(intent);
    if (fileType == QStringLiteral("header") || inferredType == QStringLiteral("header")) {
        metadata["classname"] = toPascalCase(metadata.value("baseName").toString());
        metadata["class_brief"] = intent.isEmpty() ? QStringLiteral("Class declaration") : intent;
        return applyTemplate(cppClassTemplate(), metadata);
    }

    if (fileType == QStringLiteral("source") || inferredType == QStringLiteral("source")) {
        metadata["header"] = QFileInfo(filePath).completeBaseName() + QStringLiteral(".h");
        QString content = applyTemplate(cppSourceTemplate(), metadata);
        if (!relatedFiles.isEmpty()) {
            content += QStringLiteral("\n\n// Related files:\n");
            for (const QString &related : relatedFiles)
                content += QStringLiteral("// - %1\n").arg(related);
        }
        return content;
    }

    if (QFileInfo(filePath).fileName().compare(QStringLiteral("README.md"), Qt::CaseInsensitive) == 0)
        return applyTemplate(readmeTemplate(), metadata);
    if (QFileInfo(filePath).fileName() == QStringLiteral("CMakeLists.txt"))
        return applyTemplate(cmakeListsTemplate(), metadata);
    if (QFileInfo(filePath).fileName() == QStringLiteral(".gitignore"))
        return applyTemplate(gitignoreTemplate(), metadata);
    if (fileType == QStringLiteral("python"))
        return applyTemplate(pythonModuleTemplate(), metadata);
    if (fileType == QStringLiteral("javascript") || fileType == QStringLiteral("typescript"))
        return applyTemplate(javascriptModuleTemplate(), metadata);
    if (fileType == QStringLiteral("markdown"))
        return applyTemplate(markdownTemplate(), metadata);
    if (fileType == QStringLiteral("json"))
        return applyTemplate(jsonConfigTemplate(), metadata);

    QString content = generateBoilerplate(filePath, fileType);
    if (!intent.isEmpty()) {
        const QString commentPrefix = detectLanguage(filePath) == QStringLiteral("python")
            ? QStringLiteral("# ")
            : QStringLiteral("// ");
        content.prepend(commentPrefix + intent + QStringLiteral("\n\n"));
    }
    return content;
}

QString SmartFileCreator::applyTemplate(const FileTemplate& tmpl, const QVariantMap& vars)
{
    QString content = tmpl.headerTemplate + "\n\n" + tmpl.bodyTemplate;
    
    // Replace template variables
    for (auto it = vars.constBegin(); it != vars.constEnd(); ++it) {
        QString placeholder = QString("{{%1}}").arg(it.key());
        content.replace(placeholder, it.value().toString());
    }
    
    // Replace default values for missing variables
    for (auto it = tmpl.defaultValues.constBegin(); it != tmpl.defaultValues.constEnd(); ++it) {
        QString placeholder = QString("{{%1}}").arg(it.key());
        if (content.contains(placeholder)) {
            content.replace(placeholder, it.value().toString());
        }
    }
    
    return content;
}

// ─────────────────────────────────────────────────────────────────────────────
// File Type Detection
// ─────────────────────────────────────────────────────────────────────────────

QString SmartFileCreator::detectFileType(const QString& filePath) const
{
    QFileInfo fi(filePath);
    QString ext = fi.suffix().toLower();
    
    if (ext == "h" || ext == "hpp" || ext == "hxx") return "header";
    if (ext == "cpp" || ext == "cc" || ext == "cxx") return "source";
    if (ext == "py") return "python";
    if (ext == "js") return "javascript";
    if (ext == "ts") return "typescript";
    if (ext == "java") return "java";
    if (ext == "md") return "markdown";
    if (ext == "json") return "json";
    if (ext == "xml") return "xml";
    if (ext == "yaml" || ext == "yml") return "yaml";
    if (ext == "toml") return "toml";
    if (ext == "sh" || ext == "bash") return "shell";
    
    return "text";
}

QString SmartFileCreator::detectLanguage(const QString& filePath) const
{
    QFileInfo fi(filePath);
    QString ext = fi.suffix().toLower();
    
    if (ext == "cpp" || ext == "cc" || ext == "cxx" || ext == "h" || ext == "hpp") return "cpp";
    if (ext == "c") return "c";
    if (ext == "py") return "python";
    if (ext == "js") return "javascript";
    if (ext == "ts") return "typescript";
    if (ext == "java") return "java";
    if (ext == "go") return "go";
    if (ext == "rs") return "rust";
    if (ext == "sh" || ext == "bash") return "shell";
    
    return "unknown";
}

bool SmartFileCreator::isSourceFile(const QString& filePath) const
{
    QString ext = QFileInfo(filePath).suffix().toLower();
    return ext == "cpp" || ext == "cc" || ext == "cxx" || ext == "c" || 
           ext == "py" || ext == "js" || ext == "ts" || ext == "java";
}

bool SmartFileCreator::isHeaderFile(const QString& filePath) const
{
    QString ext = QFileInfo(filePath).suffix().toLower();
    return ext == "h" || ext == "hpp" || ext == "hxx";
}

bool SmartFileCreator::isTestFile(const QString& filePath) const
{
    QString path = filePath.toLower();
    return path.contains("test") || path.contains("spec");
}

// ─────────────────────────────────────────────────────────────────────────────
// Templates
// ─────────────────────────────────────────────────────────────────────────────

void SmartFileCreator::initializeTemplates()
{
    m_templates.clear();
    m_templates.append(cppHeaderTemplate());
    m_templates.append(cppSourceTemplate());
    m_templates.append(cppClassTemplate());
    m_templates.append(pythonModuleTemplate());
    m_templates.append(javascriptModuleTemplate());
    m_templates.append(markdownTemplate());
    m_templates.append(jsonConfigTemplate());
    m_templates.append(cmakeListsTemplate());
    m_templates.append(gitignoreTemplate());
    m_templates.append(readmeTemplate());
}

SmartFileCreator::FileTemplate SmartFileCreator::getTemplate(const QString& name) const
{
    for (const FileTemplate& tmpl : m_templates) {
        if (tmpl.name == name) {
            return tmpl;
        }
    }
    return FileTemplate();  // Empty template
}

QList<SmartFileCreator::FileTemplate> SmartFileCreator::getTemplatesForFileType(const QString& fileType) const
{
    QList<FileTemplate> matching;
    for (const FileTemplate& tmpl : m_templates) {
        if (tmpl.filePattern.contains(fileType, Qt::CaseInsensitive)) {
            matching.append(tmpl);
        }
    }
    return matching;
}

SmartFileCreator::FileTemplate SmartFileCreator::cppHeaderTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "cpp-header";
    tmpl.description = "C++ header file with include guard";
    tmpl.filePattern = "*.h,*.hpp";
    
    tmpl.headerTemplate = R"(/**
 * @file {{filename}}
 * @brief {{brief}}
 * @author {{author}}
 * @date {{date}}
 */

#pragma once

#ifndef {{guard}}
#define {{guard}})";
    
    tmpl.bodyTemplate = R"(
// TODO: Add declarations here

#endif // {{guard}})";
    
    tmpl.requiredFields = QStringList{"filename", "brief", "guard"};
    tmpl.defaultValues["author"] = "Auto-generated";
    tmpl.defaultValues["date"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::cppSourceTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "cpp-source";
    tmpl.description = "C++ source file";
    tmpl.filePattern = "*.cpp,*.cc";
    
    tmpl.headerTemplate = R"(/**
 * @file {{filename}}
 * @brief {{brief}}
 */

#include "{{header}}")";
    
    tmpl.bodyTemplate = R"(
// TODO: Add implementations here)";
    
    tmpl.requiredFields = QStringList{"filename", "header"};
    tmpl.defaultValues["brief"] = "Implementation file";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::cppClassTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "cpp-class";
    tmpl.description = "C++ class declaration";
    tmpl.filePattern = "*.h,*.hpp";
    
    tmpl.headerTemplate = R"(/**
 * @file {{filename}}
 * @brief {{brief}}
 */

#pragma once

#include <QObject>)";
    
    tmpl.bodyTemplate = R"(
/**
 * @class {{classname}}
 * @brief {{class_brief}}
 */
class {{classname}} : public QObject {
)" + QStringLiteral("    Q_OBJECT\n") + R"(
public:
    explicit {{classname}}(QObject* parent = nullptr);
    ~{{classname}}() override = default;
    
signals:
    // Add signals here
    
private:
    // Add members here
};)";
    
    tmpl.requiredFields = QStringList{"classname"};
    tmpl.defaultValues["class_brief"] = "Class description";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::pythonModuleTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "python-module";
    tmpl.description = "Python module file";
    tmpl.filePattern = "*.py";
    
    tmpl.headerTemplate = R"(#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
{{module_name}}: {{brief}}

{{description}}
""")";
    
    tmpl.bodyTemplate = R"(
# TODO: Add code here)";
    
    tmpl.requiredFields = QStringList{"module_name"};
    tmpl.defaultValues["brief"] = "Module description";
    tmpl.defaultValues["description"] = "";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::javascriptModuleTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "javascript-module";
    tmpl.description = "JavaScript/TypeScript module";
    tmpl.filePattern = "*.js,*.ts";
    
    tmpl.headerTemplate = R"(/**
 * @module {{module_name}}
 * @description {{brief}}
 */)";
    
    tmpl.bodyTemplate = R"(
// TODO: Add code here

export {};)";
    
    tmpl.requiredFields = QStringList{"module_name"};
    tmpl.defaultValues["brief"] = "Module description";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::markdownTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "markdown";
    tmpl.description = "Markdown document";
    tmpl.filePattern = "*.md";
    
    tmpl.headerTemplate = "# {{title}}";
    tmpl.bodyTemplate = "\n\n{{content}}";
    
    tmpl.requiredFields = QStringList{"title"};
    tmpl.defaultValues["content"] = "Document content goes here.";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::jsonConfigTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "json-config";
    tmpl.description = "JSON configuration file";
    tmpl.filePattern = "*.json";
    
    tmpl.headerTemplate = "";
    tmpl.bodyTemplate = R"({
  "name": "{{name}}",
  "version": "{{version}}",
  "description": "{{description}}"
})";
    
    tmpl.defaultValues["name"] = "config";
    tmpl.defaultValues["version"] = "1.0.0";
    tmpl.defaultValues["description"] = "Configuration file";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::cmakeListsTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "cmakelists";
    tmpl.description = "CMakeLists.txt file";
    tmpl.filePattern = "CMakeLists.txt";
    
    tmpl.headerTemplate = "";
    tmpl.bodyTemplate = R"(cmake_minimum_required(VERSION 3.16)

project({{project_name}} VERSION {{version}} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add your targets here)";
    
    tmpl.requiredFields = QStringList{"project_name"};
    tmpl.defaultValues["version"] = "1.0.0";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::gitignoreTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "gitignore";
    tmpl.description = ".gitignore file";
    tmpl.filePattern = ".gitignore";
    
    tmpl.headerTemplate = "# {{project_name}} .gitignore";
    tmpl.bodyTemplate = R"(
# Build directories
build/
dist/
*.o
*.a
*.so

# IDE files
.vscode/
.idea/
*.swp

# OS files
.DS_Store
Thumbs.db)";
    
    tmpl.defaultValues["project_name"] = "Project";
    
    return tmpl;
}

SmartFileCreator::FileTemplate SmartFileCreator::readmeTemplate() const
{
    FileTemplate tmpl;
    tmpl.name = "readme";
    tmpl.description = "README.md file";
    tmpl.filePattern = "README.md";
    
    tmpl.headerTemplate = "# {{project_name}}";
    tmpl.bodyTemplate = R"(
## Overview

{{description}}

## Installation

```bash
# Installation instructions
```

## Usage

```bash
# Usage examples
```

## License

{{license}})";
    
    tmpl.requiredFields = QStringList{"project_name"};
    tmpl.defaultValues["description"] = "Project description";
    tmpl.defaultValues["license"] = "MIT";
    
    return tmpl;
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation and Utilities
// ─────────────────────────────────────────────────────────────────────────────

bool SmartFileCreator::validatePath(const QString& path, QString& error) const
{
    if (path.trimmed().isEmpty()) {
        error = "Path cannot be empty.";
        return false;
    }
    
    if (path.contains("..")) {
        error = "Path cannot contain parent directory references (..).";
        return false;
    }
    
    return true;
}

bool SmartFileCreator::validateContent(const QString& content, const QString& fileType, QString& error) const
{
    // Basic validation
    // TODO: Add more sophisticated validation
    Q_UNUSED(content)
    Q_UNUSED(fileType)
    Q_UNUSED(error)
    return true;
}

bool SmartFileCreator::canOverwrite(const QString& path) const
{
    // Check if file exists and is writable
    QFileInfo fi(path);
    return !fi.exists() || fi.isWritable();
}

QString SmartFileCreator::safePath(const QString& relOrAbsPath) const
{
    if (relOrAbsPath.trimmed().isEmpty())
        return QString();
    const QString abs = QFileInfo(m_root.absoluteFilePath(relOrAbsPath)).absoluteFilePath();
    // Prevent path traversal
    const QString workspaceRoot = QFileInfo(m_root.absolutePath()).absoluteFilePath();
    if (abs != workspaceRoot && !abs.startsWith(workspaceRoot + QStringLiteral("/"))) {
        return QString();
    }
    return abs;
}

bool SmartFileCreator::ensureDirectoryExists(const QString& dirPath)
{
    QDir dir;
    return dir.mkpath(dirPath);
}

QString SmartFileCreator::readFileForContext(const QString& filePath) const
{
    QString absPath = safePath(filePath);
    if (absPath.isEmpty()) return QString();
    
    QFile file(absPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }
    
    // Read first 1000 lines for context
    QTextStream in(&file);
    QString content;
    int lineCount = 0;
    while (!in.atEnd() && lineCount < 1000) {
        content += in.readLine() + "\n";
        ++lineCount;
    }
    
    return content;
}

QVariantMap SmartFileCreator::extractMetadata(const QString& filePath, const QString& intent) const
{
    QVariantMap metadata;
    
    QFileInfo fi(filePath);
    metadata["filename"] = fi.fileName();
    metadata["baseName"] = fi.completeBaseName();
    metadata["extension"] = fi.suffix();
    metadata["path"] = filePath;
    
    if (!intent.isEmpty()) {
        metadata["description"] = intent;
        metadata["brief"] = intent;
    }
    
    metadata["created"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    metadata["tool"] = "SmartFileCreator";
    
    // Generate guard for headers
    if (isHeaderFile(filePath)) {
        const QString guard = toMacroCase(fi.completeBaseName() + "_" + fi.suffix());
        metadata["guard"] = guard;
    }

    metadata["classname"] = toPascalCase(fi.completeBaseName());
    metadata["module_name"] = fi.completeBaseName();
    metadata["title"] = fi.completeBaseName();
    metadata["project_name"] = QFileInfo(m_root.absolutePath()).fileName();
    
    return metadata;
}

QString SmartFileCreator::analyzeIntent(const QString& filePath, const QString& intent)
{
    // TODO: Use LLM to analyze intent and provide suggestions
    Q_UNUSED(filePath)
    return intent;
}

QStringList SmartFileCreator::suggestRelatedFiles(const QString& filePath) const
{
    QStringList suggestions;
    QFileInfo fi(filePath);
    
    // For headers, suggest source file
    if (isHeaderFile(filePath)) {
        QString sourceName = fi.completeBaseName() + ".cpp";
        suggestions.append(fi.dir().filePath(sourceName));
    }
    
    // For sources, suggest header file
    if (isSourceFile(filePath)) {
        QString headerName = fi.completeBaseName() + ".h";
        suggestions.append(fi.dir().filePath(headerName));
    }
    
    // For test files, suggest main file
    if (isTestFile(filePath)) {
        QString mainName = fi.completeBaseName().remove(QRegularExpression("_?test$")) + ".cpp";
        suggestions.append(fi.dir().filePath(mainName));
    }
    
    return suggestions;
}

QString SmartFileCreator::inferFileTypeFromIntent(const QString& intent) const
{
    QString lower = intent.toLower();
    
    if (lower.contains("header") || lower.contains(".h")) return "header";
    if (lower.contains("source") || lower.contains(".cpp")) return "source";
    if (lower.contains("python") || lower.contains(".py")) return "python";
    if (lower.contains("javascript") || lower.contains(".js")) return "javascript";
    if (lower.contains("test")) return "test";
    if (lower.contains("readme")) return "markdown";
    if (lower.contains("config")) return "json";
    
    return "text";
}
