#pragma once

#include <QObject>
#include <QTest>
#include <QTemporaryDir>
#include "src/agent/AgentToolRegistry.h"
#include "src/tools/ClaudeStandardTools.h"
#include "src/sandbox/DefaultSandboxManager.h"

/**
 * @class TestClaudeStandardTools
 * @brief Unit tests for Claude Standard Tools (Write, Edit, MultiEdit, Read, Bash, Grep, Glob)
 */
class TestClaudeStandardTools : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void init();
    void cleanup();
    
    // Write Tool Tests
    void testWriteToolCreateNewFile();
    void testWriteToolOverwriteExistingFile();
    void testWriteToolCreateParentDirectories();
    void testWriteToolInvalidPath();
    
    // Edit Tool Tests
    void testEditToolBasicReplacement();
    void testEditToolMultiLineReplacement();
    void testEditToolOldTextNotFound();
    void testEditToolMultipleMatches();
    void testEditToolFileNotExists();
    
    // MultiEdit Tool Tests
    void testMultiEditToolBatchEdits();
    void testMultiEditToolAtomicRollback();
    void testMultiEditToolEmptyEditsList();
    
    // Read Tool Tests
    void testReadToolFullFile();
    void testReadToolLineRange();
    void testReadToolInvalidRange();
    void testReadToolFileNotExists();
    void testReadToolBinaryFile();
    
    // Bash Tool Tests
    void testBashToolSimpleCommand();
    void testBashToolWithOutput();
    void testBashToolTimeout();
    void testBashToolDangerousCommand();
    void testBashToolFailedCommand();
    
    // Grep Tool Tests
    void testGrepToolBasicSearch();
    void testGrepToolRegexPattern();
    void testGrepToolCaseSensitive();
    void testGrepToolMaxResults();
    void testGrepToolNoMatches();
    
    // Glob Tool Tests
    void testGlobToolBasicPattern();
    void testGlobToolRecursivePattern();
    void testGlobToolHiddenFiles();
    void testGlobToolMaxResults();
    void testGlobToolNoMatches();
    
    // Factory Tests
    void testFactoryRegisterAllTools();
    void testFactoryToolsAvailable();
    void testFactoryToolSchemas();

private:
    QTemporaryDir* m_tempDir;
    AgentToolRegistry* m_registry;
    DefaultSandboxManager* m_sandboxManager;
    QString m_workspacePath;
    
    // Helper methods
    QString createTestFile(const QString& relativePath, const QString& content);
    bool fileExists(const QString& relativePath);
    QString readFile(const QString& relativePath);
};
