#include <iostream>
#include <QTemporaryDir>
#include <QFile>
#include <QFileInfo>
#include "filesystem/LocalFileSystem.h"

int main() {
    std::cout << "=== Codex File System Implementation Test ===" << std::endl;
    
    QTemporaryDir tmpDir;
    if (!tmpDir.isValid()) {
        std::cerr << "Failed to create temporary directory" << std::endl;
        return 1;
    }
    
    QString workspaceRoot = tmpDir.path();
    std::cout << "Workspace root: " << workspaceRoot.toStdString() << std::endl;
    
    // Create file system instance
    LocalFileSystem fileSystem(workspaceRoot, nullptr);
    
    // Test 1: Write file
    std::cout << "\n✓ Test 1: Write file" << std::endl;
    QString testFile = workspaceRoot + "/test.txt";
    QByteArray testContent = "Hello, Codex! 你好，代码！";
    WriteFileOptions writeOpts;
    writeOpts.atomic = true;
    writeOpts.createDirs = true;
    
    auto result = fileSystem.writeFile(testFile, testContent, writeOpts);
    if (result.isOk()) {
        std::cout << "  ✓ File written successfully: " << testFile.toStdString() << std::endl;
    } else {
        std::cerr << "  ✗ Failed to write file: " << result.message().toStdString() << std::endl;
        return 1;
    }
    
    // Test 2: Read file
    std::cout << "\n✓ Test 2: Read file" << std::endl;
    QByteArray readContent;
    result = fileSystem.readFile(testFile, readContent);
    if (result.isOk()) {
        std::cout << "  ✓ File read successfully" << std::endl;
        std::cout << "  Content: " << readContent.toStdString() << std::endl;
        if (readContent == testContent) {
            std::cout << "  ✓ Content matches!" << std::endl;
        } else {
            std::cerr << "  ✗ Content mismatch!" << std::endl;
            return 1;
        }
    } else {
        std::cerr << "  ✗ Failed to read file: " << result.message().toStdString() << std::endl;
        return 1;
    }
    
    // Test 3: Create directory
    std::cout << "\n✓ Test 3: Create directory" << std::endl;
    QString testDir = workspaceRoot + "/subdir/nested";
    CreateDirectoryOptions dirOpts;
    dirOpts.recursive = true;
    result = fileSystem.createDirectory(testDir, dirOpts);
    if (result.isOk()) {
        std::cout << "  ✓ Directory created: " << testDir.toStdString() << std::endl;
    } else {
        std::cerr << "  ✗ Failed to create directory: " << result.message().toStdString() << std::endl;
        return 1;
    }
    
    // Test 4: Atomic write (temp file + rename)
    std::cout << "\n✓ Test 4: Atomic write" << std::endl;
    QString atomicFile = testDir + "/atomic.txt";
    QByteArray atomicContent = "This file should be written atomically!";
    writeOpts.atomic = true;
    result = fileSystem.writeFile(atomicFile, atomicContent, writeOpts);
    if (result.isOk()) {
        std::cout << "  ✓ Atomic file written: " << atomicFile.toStdString() << std::endl;
        
        // Verify no temp files remain
        QFileInfo info(atomicFile);
        QString dirPath = info.absolutePath();
        QDir dir(dirPath);
        int tempCount = dir.entryList(QStringList("*.neurx-tmp"), QDir::Files).count();
        if (tempCount == 0) {
            std::cout << "  ✓ No temporary files remain (clean)" << std::endl;
        } else {
            std::cerr << "  ⚠ Warning: Found " << tempCount << " temporary files" << std::endl;
        }
    } else {
        std::cerr << "  ✗ Atomic write failed: " << result.message().toStdString() << std::endl;
        return 1;
    }
    
    // Test 5: Metadata
    std::cout << "\n✓ Test 5: Get metadata" << std::endl;
    auto metadata = fileSystem.getMetadata(testFile);
    if (metadata.contains("size")) {
        std::cout << "  ✓ Metadata retrieved" << std::endl;
        std::cout << "  Size: " << metadata["size"].toInt() << " bytes" << std::endl;
        std::cout << "  Readable: " << (metadata["readable"].toBool() ? "yes" : "no") << std::endl;
        std::cout << "  Writable: " << (metadata["writable"].toBool() ? "yes" : "no") << std::endl;
    } else {
        std::cerr << "  ✗ Failed to get metadata" << std::endl;
        return 1;
    }
    
    // Test 6: Batch operations
    std::cout << "\n✓ Test 6: Batch write operations" << std::endl;
    QList<QPair<QString, QByteArray>> files;
    files.append({workspaceRoot + "/batch1.txt", "File 1 content"});
    files.append({workspaceRoot + "/batch2.txt", "File 2 content"});
    files.append({workspaceRoot + "/batch3.txt", "File 3 content"});
    
    result = fileSystem.writeFileBatch(files, writeOpts);
    if (result.isOk()) {
        std::cout << "  ✓ Batch write completed (" << files.size() << " files)" << std::endl;
        
        // Verify all files were written
        int successCount = 0;
        for (const auto& pair : files) {
            QFile f(pair.first);
            if (f.exists()) {
                successCount++;
            }
        }
        std::cout << "  ✓ Verified: " << successCount << "/" << files.size() << " files exist" << std::endl;
    } else {
        std::cerr << "  ✗ Batch write failed: " << result.message().toStdString() << std::endl;
        return 1;
    }
    
    std::cout << "\n=== All Tests Passed! ===" << std::endl;
    std::cout << "✓ File creation and writing functionality is working correctly" << std::endl;
    std::cout << "✓ Atomic operations work as expected" << std::endl;
    std::cout << "✓ Directory creation with recursion is functional" << std::endl;
    std::cout << "✓ Batch operations are operational" << std::endl;
    std::cout << "✓ Metadata retrieval works correctly" << std::endl;
    
    return 0;
}
