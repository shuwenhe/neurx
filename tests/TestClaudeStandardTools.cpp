#include "TestClaudeStandardTools.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QJsonObject>
#include <QJsonArray>

// ═══════════════════════════════════════════════════════════════════════════════
// Setup & Teardown
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::initTestCase()
{
    qInfo() << "Initializing Claude Standard Tools test suite";
}

void TestClaudeStandardTools::cleanupTestCase()
{
    qInfo() << "Claude Standard Tools test suite completed";
}

void TestClaudeStandardTools::init()
{
    // Create temporary directory for each test
    m_tempDir = new QTemporaryDir();
    QVERIFY(m_tempDir->isValid());
    m_workspacePath = m_tempDir->path();
    
    // Create registry and sandbox manager
    m_registry = new AgentToolRegistry(this);
    m_sandboxManager = new DefaultSandboxManager(this);
    m_sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
    m_sandboxManager->addAllowedReadPath(m_workspacePath);
    m_sandboxManager->addAllowedWritePath(m_workspacePath);
    
    // Register all Claude Standard Tools
    ClaudeStandardToolFactory::registerAllTools(m_workspacePath, m_registry, m_sandboxManager);
}

void TestClaudeStandardTools::cleanup()
{
    delete m_registry;
    m_registry = nullptr;
    delete m_sandboxManager;
    m_sandboxManager = nullptr;
    delete m_tempDir;
    m_tempDir = nullptr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Methods
// ═══════════════════════════════════════════════════════════════════════════════

QString TestClaudeStandardTools::createTestFile(const QString& relativePath, const QString& content)
{
    QString fullPath = QDir(m_workspacePath).filePath(relativePath);
    QFileInfo fileInfo(fullPath);
    QDir().mkpath(fileInfo.absolutePath());
    
    QFile file(fullPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return QString();
    
    QTextStream out(&file);
    out << content;
    file.close();
    
    return fullPath;
}

bool TestClaudeStandardTools::fileExists(const QString& relativePath)
{
    QString fullPath = QDir(m_workspacePath).filePath(relativePath);
    return QFile::exists(fullPath);
}

QString TestClaudeStandardTools::readFile(const QString& relativePath)
{
    QString fullPath = QDir(m_workspacePath).filePath(relativePath);
    QFile file(fullPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    
    QTextStream in(&file);
    return in.readAll();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Write Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testWriteToolCreateNewFile()
{
    BaseTool* writeTool = m_registry->tool("Write");
    QVERIFY(writeTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "test.txt";
    args["new_text"] = "Hello, World!";
    
    ToolResult result = writeTool->execute("call-1", args);
    
    QVERIFY(!result.isError);
    QVERIFY(fileExists("test.txt"));
    QCOMPARE(readFile("test.txt"), QString("Hello, World!"));
}

void TestClaudeStandardTools::testWriteToolOverwriteExistingFile()
{
    createTestFile("existing.txt", "Old content");
    
    BaseTool* writeTool = m_registry->tool("Write");
    QVERIFY(writeTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "existing.txt";
    args["new_text"] = "New content";
    
    ToolResult result = writeTool->execute("call-2", args);
    
    QVERIFY(!result.isError);
    QCOMPARE(readFile("existing.txt"), QString("New content"));
}

void TestClaudeStandardTools::testWriteToolCreateParentDirectories()
{
    BaseTool* writeTool = m_registry->tool("Write");
    QVERIFY(writeTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "subdir/nested/file.txt";
    args["new_text"] = "Nested file content";
    
    ToolResult result = writeTool->execute("call-3", args);
    
    QVERIFY(!result.isError);
    QVERIFY(fileExists("subdir/nested/file.txt"));
    QCOMPARE(readFile("subdir/nested/file.txt"), QString("Nested file content"));
}

void TestClaudeStandardTools::testWriteToolInvalidPath()
{
    BaseTool* writeTool = m_registry->tool("Write");
    QVERIFY(writeTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "../outside/workspace.txt";
    args["new_text"] = "Should fail";
    
    ToolResult result = writeTool->execute("call-4", args);
    
    // Should be blocked by sandbox or path traversal protection
    QVERIFY(result.isError);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Edit Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testEditToolBasicReplacement()
{
    createTestFile("edit_test.txt", "Line 1\nLine 2\nLine 3");
    
    BaseTool* editTool = m_registry->tool("Edit");
    QVERIFY(editTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "edit_test.txt";
    args["old_text"] = "Line 2";
    args["new_text"] = "Modified Line 2";
    
    ToolResult result = editTool->execute("call-5", args);
    
    QVERIFY(!result.isError);
    QCOMPARE(readFile("edit_test.txt"), QString("Line 1\nModified Line 2\nLine 3"));
}

void TestClaudeStandardTools::testEditToolMultiLineReplacement()
{
    createTestFile("multiline.txt", "Start\nOld Block\nLine 2\nEnd Block\nFinish");
    
    BaseTool* editTool = m_registry->tool("Edit");
    QVERIFY(editTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "multiline.txt";
    args["old_text"] = "Old Block\nLine 2\nEnd Block";
    args["new_text"] = "New Block\nSingle Line\nEnd";
    
    ToolResult result = editTool->execute("call-6", args);
    
    QVERIFY(!result.isError);
    QVERIFY(readFile("multiline.txt").contains("New Block"));
}

void TestClaudeStandardTools::testEditToolOldTextNotFound()
{
    createTestFile("notfound.txt", "Some content");
    
    BaseTool* editTool = m_registry->tool("Edit");
    QVERIFY(editTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "notfound.txt";
    args["old_text"] = "NonExistent";
    args["new_text"] = "Replacement";
    
    ToolResult result = editTool->execute("call-7", args);
    
    QVERIFY(result.isError);
    QVERIFY(result.content.contains("not found") || result.content.contains("0 replacements"));
}

void TestClaudeStandardTools::testEditToolMultipleMatches()
{
    createTestFile("duplicate.txt", "Test\nTest\nTest");
    
    BaseTool* editTool = m_registry->tool("Edit");
    QVERIFY(editTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "duplicate.txt";
    args["old_text"] = "Test";
    args["new_text"] = "Changed";
    
    ToolResult result = editTool->execute("call-8", args);
    
    // Should fail because old_text appears multiple times
    QVERIFY(result.isError);
    QVERIFY(result.content.contains("multiple") || result.content.contains("more than once"));
}

void TestClaudeStandardTools::testEditToolFileNotExists()
{
    BaseTool* editTool = m_registry->tool("Edit");
    QVERIFY(editTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "nonexistent.txt";
    args["old_text"] = "Old";
    args["new_text"] = "New";
    
    ToolResult result = editTool->execute("call-9", args);
    
    QVERIFY(result.isError);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MultiEdit Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testMultiEditToolBatchEdits()
{
    createTestFile("batch.txt", "Version 1.0\nDebug: false\nAuthor: unknown");
    
    BaseTool* multiEditTool = m_registry->tool("MultiEdit");
    QVERIFY(multiEditTool != nullptr);
    
    QJsonArray edits;
    QJsonObject edit1;
    edit1["old_text"] = "Version 1.0";
    edit1["new_text"] = "Version 2.0";
    edits.append(edit1);
    
    QJsonObject edit2;
    edit2["old_text"] = "Debug: false";
    edit2["new_text"] = "Debug: true";
    edits.append(edit2);
    
    QJsonObject args;
    args["file_path"] = "batch.txt";
    args["edits"] = edits;
    
    ToolResult result = multiEditTool->execute("call-10", args);
    
    QVERIFY(!result.isError);
    QString content = readFile("batch.txt");
    QVERIFY(content.contains("Version 2.0"));
    QVERIFY(content.contains("Debug: true"));
}

void TestClaudeStandardTools::testMultiEditToolAtomicRollback()
{
    createTestFile("rollback.txt", "Line A\nLine B\nLine C");
    
    BaseTool* multiEditTool = m_registry->tool("MultiEdit");
    QVERIFY(multiEditTool != nullptr);
    
    QJsonArray edits;
    QJsonObject edit1;
    edit1["old_text"] = "Line A";
    edit1["new_text"] = "Modified A";
    edits.append(edit1);
    
    QJsonObject edit2;
    edit2["old_text"] = "NonExistent";  // This will fail
    edit2["new_text"] = "Should not apply";
    edits.append(edit2);
    
    QJsonObject args;
    args["file_path"] = "rollback.txt";
    args["edits"] = edits;
    
    ToolResult result = multiEditTool->execute("call-11", args);
    
    QVERIFY(result.isError);
    // File should remain unchanged due to atomic rollback
    QCOMPARE(readFile("rollback.txt"), QString("Line A\nLine B\nLine C"));
}

void TestClaudeStandardTools::testMultiEditToolEmptyEditsList()
{
    createTestFile("empty.txt", "Content");
    
    BaseTool* multiEditTool = m_registry->tool("MultiEdit");
    QVERIFY(multiEditTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "empty.txt";
    args["edits"] = QJsonArray();
    
    ToolResult result = multiEditTool->execute("call-12", args);
    
    QVERIFY(result.isError);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Read Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testReadToolFullFile()
{
    QString content = "Line 1\nLine 2\nLine 3\n";
    createTestFile("read.txt", content);
    
    BaseTool* readTool = m_registry->tool("Read");
    QVERIFY(readTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "read.txt";
    
    ToolResult result = readTool->execute("call-13", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("Line 1"));
    QVERIFY(result.content.contains("Line 2"));
    QVERIFY(result.content.contains("Line 3"));
}

void TestClaudeStandardTools::testReadToolLineRange()
{
    createTestFile("range.txt", "Line 1\nLine 2\nLine 3\nLine 4\nLine 5");
    
    BaseTool* readTool = m_registry->tool("Read");
    QVERIFY(readTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "range.txt";
    args["start_line"] = 2;
    args["end_line"] = 4;
    
    ToolResult result = readTool->execute("call-14", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("Line 2"));
    QVERIFY(result.content.contains("Line 3"));
    QVERIFY(result.content.contains("Line 4"));
    QVERIFY(!result.content.contains("Line 1"));
    QVERIFY(!result.content.contains("Line 5"));
}

void TestClaudeStandardTools::testReadToolInvalidRange()
{
    createTestFile("invalid_range.txt", "Line 1\nLine 2");
    
    BaseTool* readTool = m_registry->tool("Read");
    QVERIFY(readTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "invalid_range.txt";
    args["start_line"] = 10;
    args["end_line"] = 20;
    
    ToolResult result = readTool->execute("call-15", args);
    
    // Should handle gracefully, possibly returning empty or clamping to file size
    QVERIFY(!result.isError || result.content.isEmpty());
}

void TestClaudeStandardTools::testReadToolFileNotExists()
{
    BaseTool* readTool = m_registry->tool("Read");
    QVERIFY(readTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "does_not_exist.txt";
    
    ToolResult result = readTool->execute("call-16", args);
    
    QVERIFY(result.isError);
}

void TestClaudeStandardTools::testReadToolBinaryFile()
{
    // Create a binary file
    QString binPath = QDir(m_workspacePath).filePath("binary.dat");
    QFile binFile(binPath);
    QVERIFY(binFile.open(QIODevice::WriteOnly));
    binFile.write(QByteArray("\x00\x01\x02\xFF\xFE", 5));
    binFile.close();
    
    BaseTool* readTool = m_registry->tool("Read");
    QVERIFY(readTool != nullptr);
    
    QJsonObject args;
    args["file_path"] = "binary.dat";
    
    ToolResult result = readTool->execute("call-17", args);
    
    // Should detect binary and refuse or warn
    QVERIFY(result.isError || result.content.contains("binary"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bash Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testBashToolSimpleCommand()
{
    BaseTool* bashTool = m_registry->tool("Bash");
    QVERIFY(bashTool != nullptr);
    
    QJsonObject args;
    args["command"] = "echo 'Hello from Bash'";
    
    ToolResult result = bashTool->execute("call-18", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("Hello from Bash"));
}

void TestClaudeStandardTools::testBashToolWithOutput()
{
    BaseTool* bashTool = m_registry->tool("Bash");
    QVERIFY(bashTool != nullptr);
    
    QJsonObject args;
#ifdef Q_OS_WIN
    args["command"] = "dir";
#else
    args["command"] = "ls";
#endif
    
    ToolResult result = bashTool->execute("call-19", args);
    
    QVERIFY(!result.isError);
    QVERIFY(!result.content.isEmpty());
}

void TestClaudeStandardTools::testBashToolTimeout()
{
    BaseTool* bashTool = m_registry->tool("Bash");
    QVERIFY(bashTool != nullptr);
    
    QJsonObject args;
#ifdef Q_OS_WIN
    args["command"] = "timeout /t 10";
#else
    args["command"] = "sleep 10";
#endif
    args["timeout"] = 1000;  // 1 second timeout
    
    ToolResult result = bashTool->execute("call-20", args);
    
    // Should timeout
    QVERIFY(result.isError || result.content.contains("timeout") || result.content.contains("killed"));
}

void TestClaudeStandardTools::testBashToolDangerousCommand()
{
    BaseTool* bashTool = m_registry->tool("Bash");
    QVERIFY(bashTool != nullptr);
    
    QJsonObject args;
    args["command"] = "rm -rf /";
    
    ToolResult result = bashTool->execute("call-21", args);
    
    // Should be blocked by dangerous command detection
    QVERIFY(result.isError);
    QVERIFY(result.content.contains("dangerous") || result.content.contains("blocked"));
}

void TestClaudeStandardTools::testBashToolFailedCommand()
{
    BaseTool* bashTool = m_registry->tool("Bash");
    QVERIFY(bashTool != nullptr);
    
    QJsonObject args;
    args["command"] = "false";  // Command that always fails
    
    ToolResult result = bashTool->execute("call-22", args);
    
    // Should report failure
    QVERIFY(result.isError || result.content.contains("exit") || result.content.contains("failed"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Grep Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testGrepToolBasicSearch()
{
    createTestFile("src/main.cpp", "#include <iostream>\nint main() {\n  return 0;\n}");
    createTestFile("src/utils.cpp", "#include <string>\nvoid helper() {}");
    
    BaseTool* grepTool = m_registry->tool("Grep");
    QVERIFY(grepTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "include";
    args["path"] = "src/";
    
    ToolResult result = grepTool->execute("call-23", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("main.cpp"));
    QVERIFY(result.content.contains("utils.cpp"));
}

void TestClaudeStandardTools::testGrepToolRegexPattern()
{
    createTestFile("code.txt", "int value = 42;\nstring name = \"test\";\n");
    
    BaseTool* grepTool = m_registry->tool("Grep");
    QVERIFY(grepTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "\\w+\\s*=\\s*\\d+";  // Match variable = number
    
    ToolResult result = grepTool->execute("call-24", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("value = 42"));
}

void TestClaudeStandardTools::testGrepToolCaseSensitive()
{
    createTestFile("case.txt", "Hello\nhello\nHELLO");
    
    BaseTool* grepTool = m_registry->tool("Grep");
    QVERIFY(grepTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "Hello";
    args["case_sensitive"] = true;
    
    ToolResult result = grepTool->execute("call-25", args);
    
    QVERIFY(!result.isError);
    // Should only match exact case
    int helloCount = result.content.count("Hello");
    QVERIFY(helloCount >= 1);
}

void TestClaudeStandardTools::testGrepToolMaxResults()
{
    // Create multiple files
    for (int i = 0; i < 10; ++i) {
        createTestFile(QString("file%1.txt").arg(i), "searchterm");
    }
    
    BaseTool* grepTool = m_registry->tool("Grep");
    QVERIFY(grepTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "searchterm";
    args["max_results"] = 5;
    
    ToolResult result = grepTool->execute("call-26", args);
    
    QVERIFY(!result.isError);
    // Should limit results
    QVERIFY(result.content.count("file") <= 5);
}

void TestClaudeStandardTools::testGrepToolNoMatches()
{
    createTestFile("empty_search.txt", "Some content");
    
    BaseTool* grepTool = m_registry->tool("Grep");
    QVERIFY(grepTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "nonexistent_pattern_xyz";
    
    ToolResult result = grepTool->execute("call-27", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("No matches") || result.content.contains("0 matches"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Glob Tool Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testGlobToolBasicPattern()
{
    createTestFile("file1.txt", "");
    createTestFile("file2.txt", "");
    createTestFile("file3.cpp", "");
    
    BaseTool* globTool = m_registry->tool("Glob");
    QVERIFY(globTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "*.txt";
    
    ToolResult result = globTool->execute("call-28", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("file1.txt"));
    QVERIFY(result.content.contains("file2.txt"));
    QVERIFY(!result.content.contains("file3.cpp"));
}

void TestClaudeStandardTools::testGlobToolRecursivePattern()
{
    createTestFile("src/main.cpp", "");
    createTestFile("src/utils/helper.cpp", "");
    createTestFile("tests/test.cpp", "");
    
    BaseTool* globTool = m_registry->tool("Glob");
    QVERIFY(globTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "**/*.cpp";
    
    ToolResult result = globTool->execute("call-29", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("main.cpp"));
    QVERIFY(result.content.contains("helper.cpp"));
    QVERIFY(result.content.contains("test.cpp"));
}

void TestClaudeStandardTools::testGlobToolHiddenFiles()
{
    createTestFile(".hidden", "");
    createTestFile("visible.txt", "");
    
    BaseTool* globTool = m_registry->tool("Glob");
    QVERIFY(globTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "*";
    args["include_hidden"] = true;
    
    ToolResult result = globTool->execute("call-30", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains(".hidden"));
    QVERIFY(result.content.contains("visible.txt"));
}

void TestClaudeStandardTools::testGlobToolMaxResults()
{
    for (int i = 0; i < 20; ++i) {
        createTestFile(QString("file%1.txt").arg(i), "");
    }
    
    BaseTool* globTool = m_registry->tool("Glob");
    QVERIFY(globTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "*.txt";
    args["max_results"] = 10;
    
    ToolResult result = globTool->execute("call-31", args);
    
    QVERIFY(!result.isError);
    // Should limit results to 10
    QVERIFY(result.content.count("file") <= 10);
}

void TestClaudeStandardTools::testGlobToolNoMatches()
{
    createTestFile("test.txt", "");
    
    BaseTool* globTool = m_registry->tool("Glob");
    QVERIFY(globTool != nullptr);
    
    QJsonObject args;
    args["pattern"] = "*.xyz";
    
    ToolResult result = globTool->execute("call-32", args);
    
    QVERIFY(!result.isError);
    QVERIFY(result.content.contains("No files") || result.content.contains("0 files"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Factory Tests
// ═══════════════════════════════════════════════════════════════════════════════

void TestClaudeStandardTools::testFactoryRegisterAllTools()
{
    // Tools should already be registered in init(), just verify
    QVERIFY(m_registry->tool("Write") != nullptr);
    QVERIFY(m_registry->tool("Edit") != nullptr);
    QVERIFY(m_registry->tool("MultiEdit") != nullptr);
    QVERIFY(m_registry->tool("Read") != nullptr);
    QVERIFY(m_registry->tool("Bash") != nullptr);
    QVERIFY(m_registry->tool("Grep") != nullptr);
    QVERIFY(m_registry->tool("Glob") != nullptr);
}

void TestClaudeStandardTools::testFactoryToolsAvailable()
{
    QList<BaseTool*> allTools = m_registry->allTools();
    
    // Should have at least the 7 Claude standard tools
    QVERIFY(allTools.size() >= 7);
    
    QStringList toolNames;
    for (BaseTool* tool : allTools) {
        toolNames.append(tool->name());
    }
    
    QVERIFY(toolNames.contains("Write"));
    QVERIFY(toolNames.contains("Edit"));
    QVERIFY(toolNames.contains("MultiEdit"));
    QVERIFY(toolNames.contains("Read"));
    QVERIFY(toolNames.contains("Bash"));
    QVERIFY(toolNames.contains("Grep"));
    QVERIFY(toolNames.contains("Glob"));
}

void TestClaudeStandardTools::testFactoryToolSchemas()
{
    // Verify each tool has proper schema
    BaseTool* writeTool = m_registry->tool("Write");
    QJsonObject writeSchema = writeTool->parametersSchema();
    QVERIFY(writeSchema.contains("type"));
    QVERIFY(writeSchema.contains("properties"));
    QVERIFY(writeSchema.value("properties").toObject().contains("file_path"));
    QVERIFY(writeSchema.value("properties").toObject().contains("new_text"));
    
    BaseTool* editTool = m_registry->tool("Edit");
    QJsonObject editSchema = editTool->parametersSchema();
    QVERIFY(editSchema.value("properties").toObject().contains("old_text"));
    QVERIFY(editSchema.value("properties").toObject().contains("new_text"));
    
    BaseTool* bashTool = m_registry->tool("Bash");
    QJsonObject bashSchema = bashTool->parametersSchema();
    QVERIFY(bashSchema.value("properties").toObject().contains("command"));
}

// Register test class with Qt Test framework
QTEST_MAIN(TestClaudeStandardTools)
#include "TestClaudeStandardTools.moc"
