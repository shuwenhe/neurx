#pragma once

#include <QObject>
#include <QJsonObject>
#include <memory>

class FileSystemSandboxContext;

/**
 * @file ExecutorFileSystem.h
 * @brief Abstract file system interface inspired by Codex ExecutorFileSystem
 * 
 * Provides a trait-like abstraction for file operations with:
 * - Support for sandboxed and unsandboxed contexts
 * - Async-friendly interface
 * - Type-safe paths and operations
 * - Comprehensive error handling
 * - Metadata preservation
 * 
 * Based on codex-rs/exec-server/src/local_file_system.rs pattern
 */

/**
 * @class FileSystemResult
 * @brief Result type for file system operations
 */
class FileSystemResult {
public:
    enum class ErrorCode {
        Success = 0,
        NotFound = 1,
        PermissionDenied = 2,
        InvalidPath = 3,
        IOError = 4,
        SandboxViolation = 5,
        AlreadyExists = 6,
        NotADirectory = 7,
        NotAFile = 8,
        Unknown = 99
    };

    FileSystemResult() : m_code(ErrorCode::Success) {}
    explicit FileSystemResult(ErrorCode code, const QString& message = "")
        : m_code(code), m_message(message) {}

    bool isOk() const { return m_code == ErrorCode::Success; }
    bool isErr() const { return m_code != ErrorCode::Success; }
    
    ErrorCode code() const { return m_code; }
    QString message() const { return m_message; }
    
    QJsonObject toJson() const {
        QJsonObject obj;
        obj["code"] = static_cast<int>(m_code);
        obj["message"] = m_message;
        return obj;
    }

private:
    ErrorCode m_code;
    QString m_message;
};

/**
 * @struct WriteFileOptions
 * @brief Options for file write operations
 */
struct WriteFileOptions {
    bool atomic{true};              // Use atomic write (temp + rename)
    bool createDirs{true};          // Create parent directories
    QString lineEnding{"auto"};     // Line ending: auto, lf, crlf
    bool preserveMetadata{true};    // Preserve existing file metadata
    bool preserveBOM{true};         // Preserve UTF-8 BOM
};

/**
 * @struct CreateDirectoryOptions
 * @brief Options for directory creation
 */
struct CreateDirectoryOptions {
    bool recursive{true};           // Create parent directories
    bool failIfExists{false};       // Fail if already exists
    int mode{0755};                 // Directory permissions
};

/**
 * @struct WriteFileResult
 * @brief Result data for write operations
 */
struct WriteFileResult {
    int bytesWritten{0};
    bool dirsCreated{false};
    QString filepath;
    QString lineEndingUsed;
    bool hadBOM{false};
    bool preservedBOM{false};
    QJsonObject metadata;
};

/**
 * @class ExecutorFileSystem
 * @brief Abstract interface for file system operations
 * 
 * This is inspired by Codex's ExecutorFileSystem trait and provides
 * a clean separation between:
 * - DirectFileSystem: Unsandboxed file operations
 * - SandboxedFileSystem: Restricted file operations
 * - LocalFileSystem: Router between implementations
 */
class ExecutorFileSystem : public QObject {
    Q_OBJECT

public:
    explicit ExecutorFileSystem(QObject* parent = nullptr) : QObject(parent) {}
    virtual ~ExecutorFileSystem() = default;

    /**
     * @brief Write file with optional metadata preservation
     * @param path Absolute path to file
     * @param contents Raw file contents
     * @param options Write options
     * @param sandbox Optional sandbox context
     * @return Result with metadata
     */
    virtual FileSystemResult writeFile(
        const QString& path,
        const QByteArray& contents,
        const WriteFileOptions& options = WriteFileOptions(),
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

    /**
     * @brief Read file contents
     * @param path Absolute path to file
     * @param sandbox Optional sandbox context
     * @return Contents or error
     */
    virtual FileSystemResult readFile(
        const QString& path,
        QByteArray& outContents,
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

    /**
     * @brief Create directory
     * @param path Directory path
     * @param options Directory creation options
     * @param sandbox Optional sandbox context
     * @return Success or error
     */
    virtual FileSystemResult createDirectory(
        const QString& path,
        const CreateDirectoryOptions& options = CreateDirectoryOptions(),
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

    /**
     * @brief Delete file or directory
     * @param path Path to delete
     * @param recursive Delete recursively
     * @param sandbox Optional sandbox context
     * @return Success or error
     */
    virtual FileSystemResult deleteFile(
        const QString& path,
        bool recursive = false,
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

    /**
     * @brief Check if path exists
     * @param path Path to check
     * @param sandbox Optional sandbox context
     * @return True if exists
     */
    virtual bool exists(
        const QString& path,
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

    /**
     * @brief Get file metadata
     * @param path File path
     * @param sandbox Optional sandbox context
     * @return Metadata as JSON
     */
    virtual QJsonObject getMetadata(
        const QString& path,
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

    /**
     * @brief Write multiple files atomically
     * @param files List of {path, content} pairs
     * @param sandbox Optional sandbox context
     * @return Success or error
     */
    virtual FileSystemResult writeFileBatch(
        const QList<QPair<QString, QByteArray>>& files,
        const WriteFileOptions& options = WriteFileOptions(),
        const FileSystemSandboxContext* sandbox = nullptr
    ) = 0;

signals:
    void fileWritten(const QString& path);
    void error(const QString& message);
};

using ExecutorFileSystemPtr = std::shared_ptr<ExecutorFileSystem>;
