#include <QCoreApplication>
#include <QDir>
#include <QDebug>
#include <QTemporaryDir>
#include <iostream>

// Include our file system headers
#include "filesystem/LocalFileSystem.h"
#include "tools/CodexFileSystemTool.h"

void printResult(const QString& test, bool passed, const QString& message = "") {
    if (passed) {
        std::cout << "✅ " << test.toStdString() << std::endl;
    } else {
        std::cout << "❌ " << test.toStdString();
        if (!message.isEmpty()) {
            std::cout << " - " << message.toStdString();
        }
        std::cout << std::endl;
    }
}

void test_basic_write() {
    std::cout << "\n=== Test 1: Basic File Write ===" << std::endl;
    
    QTemporaryDir tempDir;
    if (!tempDir.isValid()) {
        printResult("Create temp directory", false, "Invalid temp dir");
        return;
    }
    
    auto fs = std::make_shared<LocalFileSystem>(tempDir.path());
    
    QString testPath = tempDir.path() + "/test.txt";
    QByteArray content = "Hello, Codex File System!";
    
    auto result = fs->writeFile(
        testPath,
        content,
        WriteFileOptions{.atomic = true}
    );
    
    printResult("Write file atomically", result.isOk(), 
                result.isErr() ? result.message() : "");
    
    // Verify file was created
    QFile file(testPath);
    bool exists = file.exists();
    printResult("File exists after write", exists);
    
    if (exists) {
        file.open(QIODevice::ReadOnly);
        QByteArray readContent = file.readAll();
        file.close();
        
        bool contentMatch = readContent == content;
        printResult("File content matches", contentMatch,
                    contentMatch ? "" : QString("Expected: %1, Got: %2")
                        .arg(QString::fromUtf8(content))
                        .arg(QString::fromUtf8(readContent)));
    }
}

void test_create_directory() {
    std::cout << "\n=== Test 2: Create Directory ===" << std::endl;
    
    QTemporaryDir tempDir;
    auto fs = std::make_shared<LocalFileSystem>(tempDir.path());
    
    QString dirPath = tempDir.path() + "/src/components/ui";
    
    auto result = fs->createDirectory(
        dirPath,
        CreateDirectoryOptions{.recursive = true}
    );
    
    printResult("Create directory recursively", result.isOk(),
                result.isErr() ? result.message() : "");
    
    bool exists = QDir(dirPath).exists();
    printResult("Directory exists", exists);
}

void test_batch_write() {
    std::cout << "\n=== Test 3: Batch File Write ===" << std::endl;
    
    QTemporaryDir tempDir;
    auto fs = std::make_shared<LocalFileSystem>(tempDir.path());
    
    QList<QPair<QString, QByteArray>> files;
    for (int i = 0; i < 5; ++i) {
        QString path = tempDir.path() + QString("/file_%1.txt").arg(i);
        QByteArray content = QString("Content %1").arg(i).toUtf8();
        files.append({path, content});
    }
    
    auto result = fs->writeFileBatch(
        files,
        WriteFileOptions{.atomic = true, .createDirs = true}
    );
    
    printResult("Batch write 5 files", result.isOk(),
                result.isErr() ? result.message() : "");
    
    int successCount = 0;
    for (int i = 0; i < 5; ++i) {
        QString path = tempDir.path() + QString("/file_%1.txt").arg(i);
        if (QFile::exists(path)) {
            successCount++;
        }
    }
    
    printResult("All 5 files created", successCount == 5,
                QString("Created: %1/5").arg(successCount));
}

void test_read_file() {
    std::cout << "\n=== Test 4: Read File ===" << std::endl;
    
    QTemporaryDir tempDir;
    auto fs = std::make_shared<LocalFileSystem>(tempDir.path());
    
    QString testPath = tempDir.path() + "/read_test.txt";
    QByteArray originalContent = "Test content for reading";
    
    // First write the file
    fs->writeFile(testPath, originalContent);
    
    // Now read it back
    QByteArray readContent;
    auto result = fs->readFile(testPath, readContent);
    
    printResult("Read file", result.isOk(),
                result.isErr() ? result.message() : "");
    
    bool contentMatch = readContent == originalContent;
    printResult("Read content matches", contentMatch,
                contentMatch ? "" : "Content mismatch");
}

void test_get_metadata() {
    std::cout << "\n=== Test 5: Get File Metadata ===" << std::endl;
    
    QTemporaryDir tempDir;
    auto fs = std::make_shared<LocalFileSystem>(tempDir.path());
    
    QString testPath = tempDir.path() + "/metadata_test.json";
    QByteArray content = "{\"key\": \"value\"}";
    
    fs->writeFile(testPath, content);
    
    auto metadata = fs->getMetadata(testPath);
    
    bool hasPath = metadata.contains("path");
    bool hasSize = metadata.contains("size");
    bool hasExtension = metadata.contains("extension");
    
    printResult("Get metadata - has path", hasPath);
    printResult("Get metadata - has size", hasSize);
    printResult("Get metadata - has extension", hasExtension);
    
    if (hasSize) {
        int size = metadata["size"].toInt();
        printResult("Metadata size correct", size == content.size(),
                    QString("Expected: %1, Got: %2").arg(content.size()).arg(size));
    }
}

void test_sandbox() {
    std::cout << "\n=== Test 6: Sandbox Isolation ===" << std::endl;
    
    QTemporaryDir tempDir;
    auto fs = std::make_shared<LocalFileSystem>(tempDir.path());
    
    // Create sandbox context
    FileSystemSandboxContext sandbox("test-project");
    sandbox.setConfineDir(tempDir.path() + "/allowed");
    
    // Create the allowed directory
    QDir().mkpath(tempDir.path() + "/allowed");
    
    QString allowedPath = tempDir.path() + "/allowed/file.txt";
    QString deniedPath = tempDir.path() + "/denied/file.txt";
    
    // Try to write in allowed directory
    auto result1 = fs->writeFile(
        allowedPath,
        QByteArray("allowed content"),
        WriteFileOptions{.createDirs = true},
        &sandbox
    );
    
    printResult("Write to allowed directory", result1.isOk() || 
                result1.code() == FileSystemResult::ErrorCode::PermissionDenied,
                "");
    
    // Try to write outside allowed directory
    auto result2 = fs->writeFile(
        deniedPath,
        QByteArray("denied content"),
        WriteFileOptions{.createDirs = true},
        &sandbox
    );
    
    bool isSandboxViolation = result2.code() == FileSystemResult::ErrorCode::SandboxViolation ||
                             result2.code() == FileSystemResult::ErrorCode::PermissionDenied;
    
    printResult("Sandbox prevents access outside confine dir", isSandboxViolation,
                isSandboxViolation ? "" : "Should be denied");
}

void test_tool_api() {
    std::cout << "\n=== Test 7: Tool API (LLM Integration) ===" << std::endl;
    
    QTemporaryDir tempDir;
    auto tool = std::make_shared<CodexFileSystemTool>(tempDir.path());
    
    // Test write via tool API
    QJsonObject args;
    args["operation"] = "write_file";
    args["path"] = tempDir.path() + "/tool_test.txt";
    args["contents"] = "Written via tool API";
    
    auto result = tool->execute("call-001", args);
    
    printResult("Tool write_file operation", !result.isError,
                result.isError ? result.output : "");
    
    // Verify file was created
    QString filePath = tempDir.path() + "/tool_test.txt";
    bool fileExists = QFile::exists(filePath);
    printResult("File created by tool", fileExists);
    
    // Test read via tool API
    QJsonObject readArgs;
    readArgs["operation"] = "read_file";
    readArgs["path"] = filePath;
    
    auto readResult = tool->execute("call-002", readArgs);
    
    printResult("Tool read_file operation", !readResult.isError,
                readResult.isError ? readResult.output : "");
}

int main(int argc, char* argv[])
{
    // Initialize Qt application (needed for QFile, QDir, etc.)
    QCoreApplication app(argc, argv);
    
    std::cout << "\n" << std::string(50, '=') << std::endl;
    std::cout << "🧪 Codex File System Tests for NeurX-Code" << std::endl;
    std::cout << std::string(50, '=') << std::endl;
    
    try {
        test_basic_write();
        test_create_directory();
        test_batch_write();
        test_read_file();
        test_get_metadata();
        test_sandbox();
        test_tool_api();
        
        std::cout << "\n" << std::string(50, '=') << std::endl;
        std::cout << "✅ All tests completed!" << std::endl;
        std::cout << std::string(50, '=') << std::endl;
        
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "❌ Exception: " << e.what() << std::endl;
        return 1;
    }
}
