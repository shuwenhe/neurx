#pragma once

#include "agent/AgentToolRegistry.h"
#include "llm/LLMProvider.h"
#include <QObject>
#include <QDir>
#include <QVariantMap>
#include <memory>

class SandboxManager;

/**
 * @file SmartFileCreator.h
 * @brief Intelligent file creation tool inspired by Claude Code
 * 
 * Provides enhanced file creation capabilities:
 * - Smart content generation based on file type and context
 * - Template-based file creation
 * - Multi-file batch creation
 * - Directory structure creation
 * - Automatic file headers and metadata
 * - Language-specific boilerplate generation
 */

class SmartFileCreator : public BaseTool {
    Q_OBJECT
    
public:
    explicit SmartFileCreator(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "smart_file_creator"; }
    QString description() const override {
        return "Create files intelligently with auto-generated content, templates, "
               "and boilerplate code. Supports single files, multiple files, and "
               "directory structures with appropriate defaults for each file type.";
    }
    
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    // Set LLM provider for intelligent content generation
    void setLLMProvider(LLMProvider* provider) { m_llmProvider = provider; }
    
    // Set sandbox manager for safety
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }
    
private:
    /**
     * @enum CreationMode
     * @brief File creation modes
     */
    enum class CreationMode {
        Simple,          // Simple file creation with content
        Smart,           // AI-generated content based on intent
        Template,        // Template-based creation
        Batch,           // Multiple files at once
        Structure        // Directory structure with files
    };
    
    /**
     * @struct FileTemplate
     * @brief File template definition
     */
    struct FileTemplate {
        QString name;                   // Template name
        QString description;            // Template description
        QString filePattern;            // File pattern (e.g., "*.cpp")
        QString headerTemplate;         // File header template
        QString bodyTemplate;           // File body template
        QStringList requiredFields;     // Required fields for template
        QVariantMap defaultValues;      // Default values
    };
    
    /**
     * @struct FileCreationRequest
     * @brief Complete file creation request
     */
    struct FileCreationRequest {
        QString path;                   // File path
        QString content;                // File content (if provided)
        QString intent;                 // Creation intent (for smart mode)
        QString templateName;           // Template name
        QVariantMap templateVars;       // Template variables
        QStringList relatedFiles;       // Related files for context
        bool overwrite{false};          // Allow overwriting?
        bool createDirs{true};          // Create parent directories?
        CreationMode mode{CreationMode::Simple}; // Creation mode
    };
    
    /**
     * @struct BatchCreationRequest
     * @brief Batch file creation request
     */
    struct BatchCreationRequest {
        QList<FileCreationRequest> files;  // Files to create
        QString structureIntent;           // Overall structure intent
        bool generateMissing{false};       // Generate missing files?
    };
    
    // Creation operations
    ToolResult createSimpleFile(const QString& callId, const FileCreationRequest& req);
    ToolResult createSmartFile(const QString& callId, const FileCreationRequest& req);
    ToolResult createFromTemplate(const QString& callId, const FileCreationRequest& req);
    ToolResult createBatch(const QString& callId, const BatchCreationRequest& req);
    ToolResult createStructure(const QString& callId, const BatchCreationRequest& req);
    
    // Content generation
    QString generateFileHeader(const QString& filePath, const QVariantMap& metadata);
    QString generateBoilerplate(const QString& filePath, const QString& fileType);
    QString generateSmartContent(const QString& filePath, 
                                const QString& intent,
                                const QStringList& relatedFiles);
    QString applyTemplate(const FileTemplate& tmpl, const QVariantMap& vars);
    
    // File type detection
    QString detectFileType(const QString& filePath) const;
    QString detectLanguage(const QString& filePath) const;
    bool isSourceFile(const QString& filePath) const;
    bool isHeaderFile(const QString& filePath) const;
    bool isTestFile(const QString& filePath) const;
    
    // Templates
    void initializeTemplates();
    FileTemplate getTemplate(const QString& name) const;
    QList<FileTemplate> getTemplatesForFileType(const QString& fileType) const;
    QList<FileTemplate> getAllTemplates() const { return m_templates; }
    
    // Template library
    FileTemplate cppHeaderTemplate() const;
    FileTemplate cppSourceTemplate() const;
    FileTemplate cppClassTemplate() const;
    FileTemplate pythonModuleTemplate() const;
    FileTemplate javascriptModuleTemplate() const;
    FileTemplate markdownTemplate() const;
    FileTemplate jsonConfigTemplate() const;
    FileTemplate cmakeListsTemplate() const;
    FileTemplate gitignoreTemplate() const;
    FileTemplate readmeTemplate() const;
    
    // Smart analysis
    QString analyzeIntent(const QString& filePath, const QString& intent);
    QStringList suggestRelatedFiles(const QString& filePath) const;
    QString inferFileTypeFromIntent(const QString& intent) const;
    
    // Validation
    bool validatePath(const QString& path, QString& error) const;
    bool validateContent(const QString& content, const QString& fileType, QString& error) const;
    bool canOverwrite(const QString& path) const;
    
    // Utilities
    QString safePath(const QString& relOrAbsPath) const;
    bool ensureDirectoryExists(const QString& dirPath);
    QString readFileForContext(const QString& filePath) const;
    QVariantMap extractMetadata(const QString& filePath, const QString& intent) const;
    
    QDir m_root;
    LLMProvider* m_llmProvider;
    SandboxManager* m_sandboxManager;
    QList<FileTemplate> m_templates;
};
