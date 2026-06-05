#include "features/EditingProviders.h"
#include <QRegularExpression>
#include <QStringList>
#include <QDateTime>
#include <algorithm>

// ── InlineCompletionProvider 实现 ──────────────────────────────────────

InlineCompletionProvider::InlineCompletionProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result InlineCompletionProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("inline-completions");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<CompletionItem> completions = getCompletions(ctx);
        
        QVariantList completionList;
        for (const auto& item : completions) {
            QVariantMap completion;
            completion[QStringLiteral("label")] = item.label;
            completion[QStringLiteral("insertText")] = item.insertText;
            completion[QStringLiteral("detail")] = item.detail;
            completion[QStringLiteral("kind")] = item.kind;
            completionList.append(completion);
        }
        
        result.data = completionList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool InlineCompletionProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查是否在编辑文本（非注释、非字符串）
    return ctx.line >= 0 && ctx.column > 0;
}

QList<InlineCompletionProvider::CompletionItem> InlineCompletionProvider::getCompletions(
    const EditorContext& ctx)
{
    QList<CompletionItem> completions;
    
    // 应该调用 LSP textDocument/completion
    // 这里是占位符实现
    
    return completions;
}

QString InlineCompletionProvider::resolveCompletion(const CompletionItem& item)
{
    // 应该调用 LSP completionItem/resolve
    return item.insertText;
}

QList<InlineCompletionProvider::CompletionItem> InlineCompletionProvider::parseCompletions(
    const QVariant& lspResponse)
{
    QList<CompletionItem> completions;
    
    if (lspResponse.typeId() == QMetaType::QVariantMap) {
        const QVariantMap& map = lspResponse.toMap();
        const QVariantList& items = map.value(QStringLiteral("items")).toList();
        
        for (const auto& itemVar : items) {
            if (itemVar.typeId() != QMetaType::QVariantMap) continue;
            
            const QVariantMap& itemMap = itemVar.toMap();
            CompletionItem item;
            item.label = itemMap.value(QStringLiteral("label")).toString();
            item.insertText = itemMap.value(QStringLiteral("insertText")).toString();
            item.detail = itemMap.value(QStringLiteral("detail")).toString();
            item.kind = itemMap.value(QStringLiteral("kind")).toInt();
            
            completions.append(item);
        }
    }
    
    return completions;
}

QList<InlineCompletionProvider::CompletionItem> InlineCompletionProvider::filterCompletions(
    const QList<CompletionItem>& items, const QString& prefix)
{
    QList<CompletionItem> filtered;
    
    for (const auto& item : items) {
        if (item.label.startsWith(prefix, Qt::CaseInsensitive)) {
            filtered.append(item);
        }
    }
    
    return filtered;
}

QList<InlineCompletionProvider::CompletionItem> InlineCompletionProvider::sortCompletions(
    const QList<CompletionItem>& items)
{
    QList<CompletionItem> sorted = items;
    
    std::stable_sort(sorted.begin(), sorted.end(),
        [](const CompletionItem& a, const CompletionItem& b) {
            return a.sortText < b.sortText;
        }
    );
    
    return sorted;
}

// ── ParameterHintProvider 实现 ─────────────────────────────────────────

ParameterHintProvider::ParameterHintProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result ParameterHintProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("parameter-hints");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        SignatureHelp help = getSignatureHelp(ctx);
        
        QVariantMap resultData;
        QVariantList signatures;
        for (const auto& sig : help.signatures) {
            signatures.append(sig);
        }
        resultData[QStringLiteral("signatures")] = signatures;
        resultData[QStringLiteral("activeSignature")] = help.activeSignature;
        resultData[QStringLiteral("activeParameter")] = help.activeParameter;
        resultData[QStringLiteral("documentation")] = help.documentation;
        
        result.data = resultData;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool ParameterHintProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查是否在函数调用中（括号内）
    return ctx.text.contains(QLatin1Char('(')) && ctx.text.contains(QLatin1Char(')'));
}

ParameterHintProvider::SignatureHelp ParameterHintProvider::getSignatureHelp(const EditorContext& ctx)
{
    SignatureHelp help;
    
    // 应该调用 LSP textDocument/signatureHelp
    // 这里是占位符实现
    
    return help;
}

ParameterHintProvider::SignatureHelp ParameterHintProvider::parseSignatureHelp(const QVariant& lspResponse)
{
    SignatureHelp help;
    
    if (lspResponse.typeId() == QMetaType::QVariantMap) {
        const QVariantMap& map = lspResponse.toMap();
        help.activeSignature = map.value(QStringLiteral("activeSignature")).toInt();
        help.activeParameter = map.value(QStringLiteral("activeParameter")).toInt();
        
        const QVariantList& sigs = map.value(QStringLiteral("signatures")).toList();
        for (const auto& sig : sigs) {
            help.signatures.append(sig.toString());
        }
    }
    
    return help;
}

int ParameterHintProvider::identifyActiveParameter(const EditorContext& ctx)
{
    // 计算光标前有多少个逗号
    int activeParam = 0;
    for (int i = 0; i < ctx.column && i < ctx.text.length(); ++i) {
        if (ctx.text[i] == QLatin1Char(',')) {
            activeParam++;
        }
    }
    return activeParam;
}

// ── CodeActionProvider 实现 ────────────────────────────────────────────

CodeActionProvider::CodeActionProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result CodeActionProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("code-actions");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<CodeAction> actions = getCodeActions(ctx);
        
        QVariantList actionList;
        for (const auto& action : actions) {
            QVariantMap item;
            item[QStringLiteral("title")] = action.title;
            item[QStringLiteral("kind")] = action.kind;
            item[QStringLiteral("command")] = action.command;
            item[QStringLiteral("description")] = action.description;
            actionList.append(item);
        }
        
        result.data = actionList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool CodeActionProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查是否有诊断或选择
    return !ctx.selectedText.isEmpty() || ctx.column >= 0;
}

QList<CodeActionProvider::CodeAction> CodeActionProvider::getCodeActions(const EditorContext& ctx)
{
    QList<CodeAction> actions;
    
    // 获取诊断相关的动作
    actions.append(getDiagnosticActions(ctx));
    
    // 获取上下文相关的动作
    actions.append(getContextualActions(ctx));
    
    return actions;
}

bool CodeActionProvider::applyCodeAction(const CodeAction& action)
{
    // 应该执行代码动作
    return true;
}

QList<CodeActionProvider::CodeAction> CodeActionProvider::parseCodeActions(const QVariant& lspResponse)
{
    QList<CodeAction> actions;
    
    if (lspResponse.typeId() == QMetaType::QVariantList) {
        const QVariantList& list = lspResponse.toList();
        for (const auto& item : list) {
            if (item.typeId() == QMetaType::QVariantMap) {
                const QVariantMap& map = item.toMap();
                CodeAction action;
                action.title = map.value(QStringLiteral("title")).toString();
                action.kind = map.value(QStringLiteral("kind")).toInt();
                actions.append(action);
            }
        }
    }
    
    return actions;
}

QList<CodeActionProvider::CodeAction> CodeActionProvider::getDiagnosticActions(const EditorContext& ctx)
{
    QList<CodeAction> actions;
    // 基于诊断信息的快速修复
    return actions;
}

QList<CodeActionProvider::CodeAction> CodeActionProvider::getContextualActions(const EditorContext& ctx)
{
    QList<CodeAction> actions;
    // 基于上下文的重构建议
    return actions;
}

// ── SemanticHighlightProvider 实现 ─────────────────────────────────────

SemanticHighlightProvider::SemanticHighlightProvider(QObject *parent)
    : FeatureProvider(parent)
{
    buildTokenTypeMap();
}

FeatureProvider::Result SemanticHighlightProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("semantic-highlighting");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<SemanticToken> tokens = getSemanticTokens(ctx);
        
        QVariantList tokenList;
        for (const auto& token : tokens) {
            QVariantMap item;
            item[QStringLiteral("line")] = token.line;
            item[QStringLiteral("startChar")] = token.startChar;
            item[QStringLiteral("length")] = token.length;
            item[QStringLiteral("type")] = token.type;
            item[QStringLiteral("color")] = token.color;
            tokenList.append(item);
        }
        
        result.data = tokenList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool SemanticHighlightProvider::isAvailable(const EditorContext& ctx) const
{
    return !ctx.filePath.isEmpty();
}

QList<SemanticHighlightProvider::SemanticToken> SemanticHighlightProvider::getSemanticTokens(
    const EditorContext& ctx)
{
    QList<SemanticToken> tokens;
    
    // 应该调用 LSP textDocument/semanticTokens/full
    // 这里是占位符实现
    
    return tokens;
}

QList<SemanticHighlightProvider::SemanticToken> SemanticHighlightProvider::getSemanticTokensRange(
    const EditorContext& ctx, int startLine, int endLine)
{
    QList<SemanticToken> tokens;
    
    // 应该调用 LSP textDocument/semanticTokens/range
    // 这里是占位符实现
    
    return tokens;
}

QList<SemanticHighlightProvider::SemanticToken> SemanticHighlightProvider::parseSemanticTokens(
    const QVariant& lspResponse)
{
    QList<SemanticToken> tokens;
    
    if (lspResponse.typeId() == QMetaType::QVariantMap) {
        const QVariantMap& map = lspResponse.toMap();
        const QVariantList& data = map.value(QStringLiteral("data")).toList();
        
        int line = 0, startChar = 0;
        for (int i = 0; i < data.size(); i += 5) {
            SemanticToken token;
            token.line = line + data[i].toInt();
            if (token.line != line) {
                startChar = 0;
            }
            token.startChar = startChar + data[i + 1].toInt();
            token.length = data[i + 2].toInt();
            
            line = token.line;
            startChar = token.startChar;
            
            tokens.append(token);
        }
    }
    
    return tokens;
}

QString SemanticHighlightProvider::mapTokenTypeToColor(const QString& type)
{
    return m_tokenTypeMap.value(type, QStringLiteral("#000000"));
}

void SemanticHighlightProvider::buildTokenTypeMap()
{
    m_tokenTypeMap[QStringLiteral("class")] = QStringLiteral("#267CB9");
    m_tokenTypeMap[QStringLiteral("struct")] = QStringLiteral("#267CB9");
    m_tokenTypeMap[QStringLiteral("function")] = QStringLiteral("#795E26");
    m_tokenTypeMap[QStringLiteral("method")] = QStringLiteral("#795E26");
    m_tokenTypeMap[QStringLiteral("variable")] = QStringLiteral("#001080");
    m_tokenTypeMap[QStringLiteral("property")] = QStringLiteral("#001080");
    m_tokenTypeMap[QStringLiteral("keyword")] = QStringLiteral("#0000FF");
    m_tokenTypeMap[QStringLiteral("comment")] = QStringLiteral("#008000");
    m_tokenTypeMap[QStringLiteral("string")] = QStringLiteral("#A31515");
    m_tokenTypeMap[QStringLiteral("number")] = QStringLiteral("#098658");
}

// ── LinkedEditingProvider 实现 ─────────────────────────────────────────

LinkedEditingProvider::LinkedEditingProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result LinkedEditingProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("linked-editing");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<LinkedRange> ranges = getLinkedRanges(ctx);
        
        QVariantList rangeList;
        for (const auto& range : ranges) {
            QVariantMap item;
            item[QStringLiteral("startLine")] = range.startLine;
            item[QStringLiteral("startCharacter")] = range.startCharacter;
            item[QStringLiteral("endLine")] = range.endLine;
            item[QStringLiteral("endCharacter")] = range.endCharacter;
            rangeList.append(item);
        }
        
        result.data = rangeList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool LinkedEditingProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查是否是 HTML 或 XML 类文件
    return ctx.filePath.endsWith(QStringLiteral(".html")) ||
           ctx.filePath.endsWith(QStringLiteral(".xml")) ||
           ctx.filePath.endsWith(QStringLiteral(".jsx")) ||
           ctx.filePath.endsWith(QStringLiteral(".tsx"));
}

QList<LinkedEditingProvider::LinkedRange> LinkedEditingProvider::getLinkedRanges(
    const EditorContext& ctx)
{
    QList<LinkedRange> ranges;
    
    // 应该调用 LSP textDocument/linkedEditing
    // 或识别匹配的标记
    ranges = identifyMatchingPairs(ctx);
    
    return ranges;
}

QList<LinkedEditingProvider::LinkedRange> LinkedEditingProvider::parseLinkedRanges(
    const QVariant& lspResponse)
{
    QList<LinkedRange> ranges;
    
    if (lspResponse.typeId() == QMetaType::QVariantList) {
        const QVariantList& list = lspResponse.toList();
        for (const auto& item : list) {
            if (item.typeId() == QMetaType::QVariantMap) {
                const QVariantMap& map = item.toMap();
                LinkedRange range;
                range.startLine = map.value(QStringLiteral("startLine")).toInt();
                range.startCharacter = map.value(QStringLiteral("startCharacter")).toInt();
                range.endLine = map.value(QStringLiteral("endLine")).toInt();
                range.endCharacter = map.value(QStringLiteral("endCharacter")).toInt();
                ranges.append(range);
            }
        }
    }
    
    return ranges;
}

QList<LinkedEditingProvider::LinkedRange> LinkedEditingProvider::identifyMatchingPairs(
    const EditorContext& ctx)
{
    QList<LinkedRange> ranges;
    
    // 识别配对的 HTML 标签或其他匹配的标记
    // 这里是简化的占位符实现
    
    return ranges;
}

// ── SearchOptimizerProvider 实现 ───────────────────────────────────────

SearchOptimizerProvider::SearchOptimizerProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result SearchOptimizerProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("search-optimizer");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        SearchOptions options;
        QList<SearchResult> results = search(ctx.text, options);
        
        QVariantList resultList;
        for (const auto& searchResult : results) {
            QVariantMap item;
            item[QStringLiteral("file")] = searchResult.file;
            item[QStringLiteral("line")] = searchResult.line;
            item[QStringLiteral("column")] = searchResult.column;
            item[QStringLiteral("matchLength")] = searchResult.matchLength;
            item[QStringLiteral("preview")] = searchResult.preview;
            resultList.append(item);
        }
        
        result.data = resultList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool SearchOptimizerProvider::isAvailable(const EditorContext& ctx) const
{
    return !ctx.text.isEmpty();
}

QList<SearchOptimizerProvider::SearchResult> SearchOptimizerProvider::search(
    const QString& pattern, const SearchOptions& options, int maxResults)
{
    QList<SearchResult> results;
    
    // 检查缓存
    if (m_cache.contains(pattern)) {
        results = m_cache[pattern];
    } else {
        results = parallelSearch(pattern, options);
        cacheResults(pattern, results);
    }
    
    // 限制结果数量
    if (results.size() > maxResults) {
        results = results.mid(0, maxResults);
    }
    
    return results;
}

QList<SearchOptimizerProvider::SearchResult> SearchOptimizerProvider::searchAndReplace(
    const QString& pattern, const QString& replacement, const SearchOptions& options)
{
    QList<SearchResult> results = search(pattern, options);
    
    // 应该应用替换
    
    return results;
}

QList<SearchOptimizerProvider::SearchResult> SearchOptimizerProvider::parallelSearch(
    const QString& pattern, const SearchOptions& options)
{
    QList<SearchResult> results;
    
    // 这里应该实现并行搜索逻辑
    // 使用 QtConcurrent 或线程池
    
    return results;
}

int SearchOptimizerProvider::calculateScore(const SearchResult& result)
{
    return result.score;
}

void SearchOptimizerProvider::cacheResults(const QString& key, const QList<SearchResult>& results)
{
    m_cache[key] = results;
    
    // 限制缓存大小
    if (m_cache.size() > 20) {
        auto it = m_cache.begin();
        m_cache.erase(it);
    }
}
