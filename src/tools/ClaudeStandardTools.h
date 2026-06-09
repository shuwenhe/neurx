#pragma once

#include "agent/AgentToolRegistry.h"
#include "sandbox/SandboxManager.h"
#include <QObject>
#include <QDir>
#include <QProcess>

// Forward declarations
class ClaudeSkillManager;

/**
 * @file ClaudeStandardTools.h
 * @brief Claude Code 标准工具集
 * 
 * 实现与 Claude Code 完全兼容的标准工具：
 * - Write: 创建新文件或覆盖现有文件
 * - Edit: 修改现有文件（字符串替换）
 * - MultiEdit: 一次执行多个编辑操作
 * - Read: 读取文件内容
 * - Bash: 执行 Shell 命令
 * - Grep: 搜索文件内容
 * - Glob: 列出匹配的文件
 */

// ═══════════════════════════════════════════════════════════════════════════════
// Write Tool - 创建新文件或覆盖现有文件
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class WriteTool
 * @brief 创建新文件或覆盖现有文件
 * 
 * 参数：
 * - file_path: 文件路径（相对或绝对）
 * - new_text: 要写入的内容
 * 
 * 功能：
 * - 自动创建父目录
 * - 支持覆盖现有文件
 * - Sandbox 安全检查
 * - 完整的错误处理
 */
class WriteTool : public BaseTool {
    Q_OBJECT
public:
    explicit WriteTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "Write"; }
    QString description() const override {
        return "Create a new file or overwrite an existing file with the given content. "
               "Automatically creates parent directories if needed.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    QString safePath(const QString& relOrAbsPath) const;
    bool ensureDirectoryExists(const QString& dirPath);
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
};

// ═══════════════════════════════════════════════════════════════════════════════
// Edit Tool - 修改现有文件（字符串替换）
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class EditTool
 * @brief 通过字符串替换修改现有文件
 * 
 * 参数：
 * - file_path: 文件路径
 * - old_text: 要替换的旧文本（必须精确匹配）
 * - new_text: 替换后的新文本
 * 
 * 功能：
 * - 精确字符串匹配
 * - 支持多行文本替换
 * - 自动创建备份
 * - 验证替换次数（防止多次匹配）
 */
class EditTool : public BaseTool {
    Q_OBJECT
public:
    explicit EditTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "Edit"; }
    QString description() const override {
        return "Modify an existing file by replacing old_text with new_text. "
               "The old_text must match exactly (including whitespace). "
               "Returns error if old_text is not found or appears multiple times.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    QString safePath(const QString& relOrAbsPath) const;
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
};

// ═══════════════════════════════════════════════════════════════════════════════
// MultiEdit Tool - 一次执行多个编辑操作
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class MultiEditTool
 * @brief 在一个文件中执行多个编辑操作
 * 
 * 参数：
 * - file_path: 文件路径
 * - edits: 编辑操作数组，每个包含 old_text 和 new_text
 * 
 * 功能：
 * - 批量编辑提高效率
 * - 按顺序应用编辑
 * - 原子性操作（全部成功或全部失败）
 * - 自动创建备份
 */
class MultiEditTool : public BaseTool {
    Q_OBJECT
public:
    explicit MultiEditTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "MultiEdit"; }
    QString description() const override {
        return "Apply multiple text replacements to a single file in one operation. "
               "Edits are applied sequentially. All edits must succeed or the file is unchanged.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    QString safePath(const QString& relOrAbsPath) const;
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
};

// ════════════════════════════════════════════════════════════════════════════
// Read Tool - 读取文件内容
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class ReadTool
 * @brief 读取文件内容
 * 
 * 参数：
 * - file_path: 文件路径
 * - start_line: 起始行（可选，1-based）
 * - end_line: 结束行（可选，1-based）
 * 
 * 功能：
 * - 支持读取完整文件
 * - 支持读取指定行范围
 * - 自动检测文件编码
 * - 二进制文件检测
 */
class ReadTool : public BaseTool {
    Q_OBJECT
public:
    explicit ReadTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "Read"; }
    QString description() const override {
        return "Read the contents of a file. Optionally specify start_line and end_line "
               "to read only a portion of the file (1-based line numbers).";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    QString safePath(const QString& relOrAbsPath) const;
    bool isBinaryFile(const QString& filePath) const;
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
};

// ═══════════════════════════════════════════════════════════════════════════════
// Bash Tool - 执行 Shell 命令
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class BashTool
 * @brief 执行 Shell 命令
 * 
 * 参数：
 * - command: 要执行的命令
 * - timeout: 超时时间（秒，可选）
 * - env: 环境变量（可选）
 * 
 * 功能：
 * - 在工作目录中执行命令
 * - 捕获 stdout 和 stderr
 * - 返回退出码
 * - 支持超时控制
 * - 危险命令警告
 */
class BashTool : public BaseTool {
    Q_OBJECT
public:
    explicit BashTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "Bash"; }
    QString description() const override {
        return "Execute a shell command in the workspace directory. "
               "Returns stdout, stderr, and exit code. "
               "Commands run with a configurable timeout.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }
    void setDefaultTimeoutSec(int sec) { m_defaultTimeoutSec = sec; }

private:
    bool isDangerousCommand(const QString& command) const;
    QString getShell() const;
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
    int m_defaultTimeoutSec{30};
};

// ═══════════════════════════════════════════════════════════════════════════════
// Grep Tool - 搜索文件内容
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class GrepTool
 * @brief 在文件中搜索文本模式
 * 
 * 参数：
 * - pattern: 搜索模式（支持正则表达式）
 * - path: 搜索路径（文件或目录）
 * - case_sensitive: 是否区分大小写（可选）
 * - max_results: 最大结果数（可选）
 * 
 * 功能：
 * - 正则表达式搜索
 * - 递归搜索目录
 * - 显示行号和上下文
 * - 排除二进制文件
 */
class GrepTool : public BaseTool {
    Q_OBJECT
public:
    explicit GrepTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "Grep"; }
    QString description() const override {
        return "Search for a pattern in files within the workspace. "
               "Supports regex patterns. Returns matching lines with file paths and line numbers.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    struct GrepMatch {
        QString filePath;
        int lineNumber;
        QString line;
        QString beforeContext;
        QString afterContext;
    };
    
    QList<GrepMatch> searchInFile(const QString& filePath, 
                                   const QRegularExpression& regex,
                                   int maxResults) const;
    QString safePath(const QString& relOrAbsPath) const;
    bool isBinaryFile(const QString& filePath) const;
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
};

// ═══════════════════════════════════════════════════════════════════════════════
// Glob Tool - 列出匹配的文件
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class GlobTool
 * @brief 使用 glob 模式列出文件
 * 
 * 参数：
 * - pattern: glob 模式（例如 `*.cpp` 或递归头文件匹配）
 * - include_hidden: 是否包含隐藏文件（可选）
 * - max_results: 最大结果数（可选）
 * 
 * 功能：
 * - Glob 模式匹配
 * - 递归搜索（** 支持）
 * - 排除 .git, node_modules 等
 * - 返回相对路径
 */
class GlobTool : public BaseTool {
    Q_OBJECT
public:
    explicit GlobTool(const QString& workspaceRoot, QObject* parent = nullptr);
    
    QString name() const override { return "Glob"; }
    QString description() const override {
        return "List files matching a glob pattern. "
               "Supports ** for recursive directory matching. "
               "Returns file paths relative to workspace root.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager) { m_sandboxManager = manager; }

private:
    QStringList findFiles(const QString& pattern, bool includeHidden, int maxResults) const;
    bool matchesGlob(const QString& path, const QString& pattern) const;
    bool shouldExclude(const QString& path) const;
    
    QDir m_root;
    SandboxManager* m_sandboxManager{nullptr};
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tool Factory - 工具工厂
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class ClaudeStandardToolFactory
 * @brief 创建和注册所有 Claude 标准工具
 */
class ClaudeStandardToolFactory {
public:
    /**
     * @brief 创建所有标准工具并注册到 registry
     * @param workspaceRoot 工作空间根目录
     * @param registry 工具注册表
     * @param sandboxManager Sandbox 管理器（可选）
     */
    static void registerAllTools(const QString& workspaceRoot,
                                 AgentToolRegistry* registry,
                                 SandboxManager* sandboxManager = nullptr);
    
    /**
     * @brief 创建单个工具
     */
    static WriteTool* createWriteTool(const QString& workspaceRoot, 
                                      SandboxManager* sandboxManager = nullptr);
    static EditTool* createEditTool(const QString& workspaceRoot,
                                    SandboxManager* sandboxManager = nullptr);
    static MultiEditTool* createMultiEditTool(const QString& workspaceRoot,
                                             SandboxManager* sandboxManager = nullptr);
    static ReadTool* createReadTool(const QString& workspaceRoot,
                                   SandboxManager* sandboxManager = nullptr);
    static BashTool* createBashTool(const QString& workspaceRoot,
                                   SandboxManager* sandboxManager = nullptr);
    static GrepTool* createGrepTool(const QString& workspaceRoot,
                                   SandboxManager* sandboxManager = nullptr);
    static GlobTool* createGlobTool(const QString& workspaceRoot,
                                   SandboxManager* sandboxManager = nullptr);
    // Adapters for additional Gemini-style file operation tools implemented
    // under src/tools (GeminiListFilesTool, GeminiStatFileTool, etc.).
    static BaseTool* createGeminiListFilesAdapter(const QString& workspaceRoot,
                                                 SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiStatFileAdapter(const QString& workspaceRoot,
                                               SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiRemoveFileAdapter(const QString& workspaceRoot,
                                                 SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiMkdirAdapter(const QString& workspaceRoot,
                                           SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiAppendFileAdapter(const QString& workspaceRoot,
                                                SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiExistsFileAdapter(const QString& workspaceRoot,
                                                SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiRgAdapter(const QString& workspaceRoot,
                                        SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiReadFileAdapter(const QString& workspaceRoot,
                                               SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiWriteFileAdapter(const QString& workspaceRoot,
                                                SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiChmodAdapter(const QString& workspaceRoot,
                                           SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiHashAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiSymlinkAdapter(const QString& workspaceRoot,
                                             SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiMoveFileAdapter(const QString& workspaceRoot,
                                              SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiCopyFileAdapter(const QString& workspaceRoot,
                                              SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiWriteBatchAdapter(const QString& workspaceRoot,
                                                SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiReadManyFilesAdapter(const QString& workspaceRoot,
                                                   SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiGlobAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiEditAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiWriteTodosAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiUpdateTopicAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiAskUserAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiGrepAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiGetInternalDocsAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createGeminiCompleteTaskAdapter(const QString& workspaceRoot,
                                          SandboxManager* sandboxManager = nullptr);
    static BaseTool* createSkillAdapter(const QString& workspaceRoot, 
                                       SandboxManager* sandboxManager = nullptr,
                                       ClaudeSkillManager* skillManager = nullptr);
};
