#pragma once
#include "features/FeatureProviders.h"
#include <QList>
#include <QDateTime>
#include <QRegularExpression>

/**
 * @brief 内联完成提供者
 * 
 * 在编辑器中显示代码完成建议
 * 复杂度: ⭐⭐⭐ (复杂)
 * 工作量: 2 天
 */
class InlineCompletionProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct CompletionItem {
        QString label;        // 完成项标签
        QString insertText;   // 插入文本
        QString detail;       // 详细信息
        QString documentation; // 文档
        int kind{1};         // 类型 (1=Text, 2=Method, 3=Function等)
        int sortText{0};     // 排序权重
        QString filterText;  // 过滤文本
        bool preselect{false}; // 是否预选
    };

    explicit InlineCompletionProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<CompletionItem> getCompletions(const EditorContext& ctx);
    QString resolveCompletion(const CompletionItem& item);

private:
    /**
     * 从 LSP 响应解析完成项
     */
    QList<CompletionItem> parseCompletions(const QVariant& lspResponse);

    /**
     * 过滤完成项
     */
    QList<CompletionItem> filterCompletions(
        const QList<CompletionItem>& items,
        const QString& prefix
    );

    /**
     * 排序完成项
     */
    QList<CompletionItem> sortCompletions(const QList<CompletionItem>& items);
};

/**
 * @brief 参数提示提供者
 * 
 * 显示函数参数提示
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 1.5 天
 */
class ParameterHintProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct SignatureHelp {
        QList<QString> signatures; // 签名列表
        int activeSignature{0};    // 当前活跃签名
        int activeParameter{0};    // 当前参数
        QString documentation;     // 文档
    };

    explicit ParameterHintProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    SignatureHelp getSignatureHelp(const EditorContext& ctx);

private:
    /**
     * 从 LSP 响应解析签名帮助
     */
    SignatureHelp parseSignatureHelp(const QVariant& lspResponse);

    /**
     * 识别当前参数
     */
    int identifyActiveParameter(const EditorContext& ctx);
};

/**
 * @brief 代码动作提供者
 * 
 * 显示快速修复和重构动作
 * 复杂度: ⭐⭐⭐ (中等)
 * 工作量: 1.5 天
 */
class CodeActionProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct CodeAction {
        QString title;        // 动作标题
        int kind{0};         // 动作类型 (QuickFix/Refactor等)
        QString diagnosticId; // 诊断 ID
        QString command;      // 命令
        QVariantMap edit;    // 文本编辑
        QString description; // 描述
    };

    explicit CodeActionProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<CodeAction> getCodeActions(const EditorContext& ctx);
    bool applyCodeAction(const CodeAction& action);

private:
    /**
     * 从 LSP 响应解析代码动作
     */
    QList<CodeAction> parseCodeActions(const QVariant& lspResponse);

    /**
     * 获取诊断相关的动作
     */
    QList<CodeAction> getDiagnosticActions(const EditorContext& ctx);

    /**
     * 获取上下文相关的动作
     */
    QList<CodeAction> getContextualActions(const EditorContext& ctx);
};

/**
 * @brief 语义高亮提供者
 * 
 * 基于语言服务的高级语法高亮
 * 复杂度: ⭐⭐⭐ (中等)
 * 工作量: 1.5 天
 */
class SemanticHighlightProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct SemanticToken {
        int line{0};          // 行号
        int startChar{0};    // 开始列
        int length{0};       // 长度
        QString type;        // 令牌类型
        QList<QString> modifiers; // 修饰符
        QString color;       // 颜色
    };

    explicit SemanticHighlightProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<SemanticToken> getSemanticTokens(const EditorContext& ctx);
    QList<SemanticToken> getSemanticTokensRange(
        const EditorContext& ctx,
        int startLine,
        int endLine
    );

private:
    /**
     * 从 LSP 响应解析语义令牌
     */
    QList<SemanticToken> parseSemanticTokens(const QVariant& lspResponse);

    /**
     * 将令牌类型映射到颜色
     */
    QString mapTokenTypeToColor(const QString& type);

    /**
     * 构建令牌类型映射
     */
    void buildTokenTypeMap();

    QMap<QString, QString> m_tokenTypeMap; // 令牌类型到颜色的映射
};

/**
 * @brief 链接编辑提供者
 * 
 * 同时编辑匹配的标记
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 1 天
 */
class LinkedEditingProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct LinkedRange {
        int startLine{0};
        int startCharacter{0};
        int endLine{0};
        int endCharacter{0};
    };

    explicit LinkedEditingProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<LinkedRange> getLinkedRanges(const EditorContext& ctx);

private:
    /**
     * 从 LSP 响应解析链接范围
     */
    QList<LinkedRange> parseLinkedRanges(const QVariant& lspResponse);

    /**
     * 识别配对的标记（如 HTML 标签）
     */
    QList<LinkedRange> identifyMatchingPairs(const EditorContext& ctx);
};

/**
 * @brief 搜索优化提供者
 * 
 * 优化全局搜索性能和功能
 * 复杂度: ⭐⭐⭐ (中等)
 * 工作量: 1.5 天
 */
class SearchOptimizerProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct SearchResult {
        QString file;
        int line{0};
        int column{0};
        int matchLength{0};
        QString lineText;
        QString preview;
        int score{0};
    };

    struct SearchOptions {
        bool useRegex{false};
        bool caseSensitive{false};
        bool wholeWord{false};
        QStringList includePatterns; // 包含模式
        QStringList excludePatterns; // 排除模式
    };

    explicit SearchOptimizerProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<SearchResult> search(
        const QString& pattern,
        const SearchOptions& options,
        int maxResults = 1000
    );

    QList<SearchResult> searchAndReplace(
        const QString& pattern,
        const QString& replacement,
        const SearchOptions& options
    );

private:
    /**
     * 执行并行搜索
     */
    QList<SearchResult> parallelSearch(
        const QString& pattern,
        const SearchOptions& options
    );

    /**
     * 计算搜索结果的相关性分数
     */
    int calculateScore(const SearchResult& result);

    /**
     * 缓存搜索结果
     */
    void cacheResults(const QString& key, const QList<SearchResult>& results);

    QMap<QString, QList<SearchResult>> m_cache; // 搜索缓存
};
