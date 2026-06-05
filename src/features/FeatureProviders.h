#pragma once
#include <QObject>
#include <QVariant>
#include <QString>
#include <QDateTime>
#include <QRegularExpression>
#include <QList>

/**
 * @brief 基础功能提供者接口
 * 
 * 所有 Phase 2 功能提供者的基类，定义通用的功能接口
 */
class FeatureProvider : public QObject {
    Q_OBJECT

public:
    /**
     * 通用结果结构
     */
    struct Result {
        QString id;              // 结果唯一标识
        QVariant data;          // 结果数据
        QString error;          // 错误信息（如有）
        bool success{true};     // 操作是否成功
        qint64 timestamp{0};    // 时间戳
    };

    /**
     * 编辑上下文结构
     */
    struct EditorContext {
        QString filePath;       // 文件路径
        int line{0};           // 行号（0-based）
        int column{0};         // 列号（0-based）
        QString text;          // 文本内容
        QString selectedText;  // 选中的文本
        int selectionStart{-1}; // 选择开始
        int selectionEnd{-1};   // 选择结束
    };

    explicit FeatureProvider(QObject *parent = nullptr);
    virtual ~FeatureProvider() = default;

    /**
     * 执行功能
     */
    virtual Result execute(const EditorContext& ctx) = 0;

    /**
     * 检查功能是否可用
     */
    virtual bool isAvailable(const EditorContext& ctx) const {
        return true;
    }

signals:
    void resultReady(const Result& result);
    void progressUpdated(int current, int total);
    void errorOccurred(const QString& error);
};

/**
 * @brief 删除行尾空格提供者
 * 
 * 自动删除行尾的空格字符
 * 复杂度: ⭐ (简单)
 * 工作量: 0.5 天
 */
class TrimTrailingWhitespaceProvider : public FeatureProvider {
    Q_OBJECT

public:
    explicit TrimTrailingWhitespaceProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

private:
    /**
     * 删除单行末尾空格
     */
    QString trimLine(const QString& line);

    /**
     * 删除整个文本末尾空格
     */
    QString trimAllLines(const QString& text);
};

/**
 * @brief 格式化文档提供者
 * 
 * 通过 LSP 格式化整个文档
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 1 天
 */
class FormatDocumentProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct FormatOptions {
        int tabSize{4};
        bool insertSpaces{true};
        bool trimFinalNewlines{true};
        bool insertFinalNewline{true};
    };

    explicit FormatDocumentProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    void setFormatOptions(const FormatOptions& options) {
        m_formatOptions = options;
    }

private:
    FormatOptions m_formatOptions;

    /**
     * 通过 LSP 请求格式化
     */
    QString requestLSPFormat(const QString& filePath);

    /**
     * 应用格式化编辑
     */
    QVariantList parseFormatEdits(const QVariant& lspResponse);
};

/**
 * @brief 类型定义提供者
 * 
 * 跳转到符号的类型定义
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 0.5 天
 */
class TypeDefinitionProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct TypeDefinition {
        QString uri;           // 文件 URI
        int line{0};          // 行号
        int character{0};     // 列号
        QString typeName;     // 类型名
    };

    explicit TypeDefinitionProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

private:
    /**
     * 从 LSP 响应解析类型定义
     */
    TypeDefinition parseTypeDefinition(const QVariant& lspResponse);
};

/**
 * @brief 转到声明提供者
 * 
 * 跳转到符号的声明位置
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 0.5 天
 */
class GoToDeclarationProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct Declaration {
        QString uri;
        int line{0};
        int character{0};
    };

    explicit GoToDeclarationProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

private:
    /**
     * 从 LSP 响应解析声明位置
     */
    Declaration parseDeclaration(const QVariant& lspResponse);
};

/**
 * @brief 路径自动完成提供者
 * 
 * 在字符串中显示文件路径完成建议
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 1 天
 */
class PathCompletionProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct PathCompletion {
        QString path;          // 完成的路径
        QString label;         // 显示标签
        QString icon;          // 图标名称
        bool isDirectory{false}; // 是否是目录
        QString detail;        // 详细信息
    };

    explicit PathCompletionProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<PathCompletion> getCompletions(const QString& basePath, const QString& prefix);

private:
    /**
     * 从编辑器上下文提取路径前缀
     */
    QString extractPathPrefix(const EditorContext& ctx);

    /**
     * 列举工作区文件
     */
    QList<PathCompletion> enumerateFiles(const QString& basePath, const QString& prefix);
};
