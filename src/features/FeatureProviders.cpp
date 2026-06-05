#include "features/FeatureProviders.h"
#include <QRegularExpression>
#include <QDir>
#include <QFileInfo>

// ── FeatureProvider 基类实现 ──────────────────────────────────────────────

FeatureProvider::FeatureProvider(QObject *parent)
    : QObject(parent)
{
}

// ── TrimTrailingWhitespaceProvider 实现 ────────────────────────────────────

TrimTrailingWhitespaceProvider::TrimTrailingWhitespaceProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

QString TrimTrailingWhitespaceProvider::trimLine(const QString& line)
{
    // 删除行尾的空格和 Tab
    QString result = line;
    QRegularExpression trailingWhitespace(QStringLiteral("\\s+$"));
    return result.replace(trailingWhitespace, QString());
}

QString TrimTrailingWhitespaceProvider::trimAllLines(const QString& text)
{
    QStringList lines = text.split(QLatin1Char('\n'));
    QStringList trimmedLines;
    
    for (const auto& line : lines) {
        trimmedLines.append(trimLine(line));
    }
    
    return trimmedLines.join(QLatin1Char('\n'));
}

FeatureProvider::Result TrimTrailingWhitespaceProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("trim-whitespace");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QString trimmedText = trimAllLines(ctx.text);
        
        // 计算改动行数
        QStringList origLines = ctx.text.split(QLatin1Char('\n'));
        QStringList trimmedLines = trimmedText.split(QLatin1Char('\n'));
        
        int linesChanged = 0;
        for (int i = 0; i < origLines.size() && i < trimmedLines.size(); ++i) {
            if (origLines[i] != trimmedLines[i]) {
                ++linesChanged;
            }
        }
        
        QVariantMap resultData;
        resultData[QStringLiteral("text")] = trimmedText;
        resultData[QStringLiteral("linesChanged")] = linesChanged;
        resultData[QStringLiteral("replacements")] = linesChanged;
        
        result.data = resultData;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool TrimTrailingWhitespaceProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查文本是否包含行尾空格
    QRegularExpression hasTrailingWhitespace(QStringLiteral("\\s+$"), QRegularExpression::MultilineOption);
    return hasTrailingWhitespace.match(ctx.text).hasMatch();
}

// ── FormatDocumentProvider 实现 ────────────────────────────────────────────

FormatDocumentProvider::FormatDocumentProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result FormatDocumentProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("format-document");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        // 这里应该调用 LSP 的 textDocument/formatting 请求
        // 对于现在的实现，我们返回格式化选项
        QVariantMap resultData;
        resultData[QStringLiteral("tabSize")] = m_formatOptions.tabSize;
        resultData[QStringLiteral("insertSpaces")] = m_formatOptions.insertSpaces;
        resultData[QStringLiteral("trimFinalNewlines")] = m_formatOptions.trimFinalNewlines;
        resultData[QStringLiteral("insertFinalNewline")] = m_formatOptions.insertFinalNewline;
        
        // 应用基本的格式化
        QString formatted = ctx.text;
        
        // 应用缩进选项
        if (!m_formatOptions.insertSpaces) {
            // 用 Tab 替换空格
            QString indent(m_formatOptions.tabSize, QLatin1Char(' '));
            formatted = formatted.replace(indent, QStringLiteral("\t"));
        }
        
        resultData[QStringLiteral("formattedText")] = formatted;
        result.data = resultData;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool FormatDocumentProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查文件是否是可格式化的类型
    static const QStringList formattableExtensions{
        QStringLiteral(".cpp"), QStringLiteral(".h"), 
        QStringLiteral(".c"), QStringLiteral(".js"),
        QStringLiteral(".ts"), QStringLiteral(".json"),
        QStringLiteral(".xml"), QStringLiteral(".html")
    };
    
    for (const auto& ext : formattableExtensions) {
        if (ctx.filePath.endsWith(ext)) {
            return true;
        }
    }
    return false;
}

QString FormatDocumentProvider::requestLSPFormat(const QString& filePath)
{
    // 本应连接到 LanguageClient 发送 LSP 请求
    // 这里是占位符
    return filePath;
}

QVariantList FormatDocumentProvider::parseFormatEdits(const QVariant& lspResponse)
{
    QVariantList edits;
    // 解析 LSP textDocument/formatting 响应
    return edits;
}

// ── TypeDefinitionProvider 实现 ────────────────────────────────────────────

TypeDefinitionProvider::TypeDefinitionProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result TypeDefinitionProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("type-definition");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        // 调用 LSP textDocument/typeDefinition
        // 这里应该通过 LanguageClient 实现
        QVariantMap resultData;
        resultData[QStringLiteral("uri")] = ctx.filePath;
        resultData[QStringLiteral("line")] = ctx.line;
        resultData[QStringLiteral("character")] = ctx.column;
        
        result.data = resultData;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool TypeDefinitionProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查语言是否支持类型定义
    static const QStringList supportedLanguages{
        QStringLiteral("cpp"), QStringLiteral("c"),
        QStringLiteral("typescript"), QStringLiteral("javascript"),
        QStringLiteral("python"), QStringLiteral("rust")
    };
    
    for (const auto& lang : supportedLanguages) {
        if (ctx.filePath.contains(lang)) {
            return true;
        }
    }
    return false;
}

TypeDefinitionProvider::TypeDefinition TypeDefinitionProvider::parseTypeDefinition(const QVariant& lspResponse)
{
    TypeDefinition typeDef;
    if (lspResponse.type() == QVariant::Map) {
        const QVariantMap& map = lspResponse.toMap();
        typeDef.line = map.value(QStringLiteral("line")).toInt();
        typeDef.character = map.value(QStringLiteral("character")).toInt();
        typeDef.typeName = map.value(QStringLiteral("name")).toString();
    }
    return typeDef;
}

// ── GoToDeclarationProvider 实现 ────────────────────────────────────────────

GoToDeclarationProvider::GoToDeclarationProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result GoToDeclarationProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("go-to-declaration");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        // 调用 LSP textDocument/declaration
        QVariantMap resultData;
        resultData[QStringLiteral("uri")] = ctx.filePath;
        resultData[QStringLiteral("line")] = ctx.line;
        resultData[QStringLiteral("character")] = ctx.column;
        
        result.data = resultData;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool GoToDeclarationProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查光标下是否有有效的符号
    return !ctx.selectedText.isEmpty() || ctx.column >= 0;
}

GoToDeclarationProvider::Declaration GoToDeclarationProvider::parseDeclaration(const QVariant& lspResponse)
{
    Declaration decl;
    if (lspResponse.type() == QVariant::Map) {
        const QVariantMap& map = lspResponse.toMap();
        decl.uri = map.value(QStringLiteral("uri")).toString();
        decl.line = map.value(QStringLiteral("line")).toInt();
        decl.character = map.value(QStringLiteral("character")).toInt();
    }
    return decl;
}

// ── PathCompletionProvider 实现 ────────────────────────────────────────────

PathCompletionProvider::PathCompletionProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result PathCompletionProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("path-completion");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QString pathPrefix = extractPathPrefix(ctx);
        QList<PathCompletion> completions = getCompletions(
            QFileInfo(ctx.filePath).absolutePath(),
            pathPrefix
        );
        
        QVariantList completionList;
        for (const auto& completion : completions) {
            QVariantMap item;
            item[QStringLiteral("path")] = completion.path;
            item[QStringLiteral("label")] = completion.label;
            item[QStringLiteral("icon")] = completion.icon;
            item[QStringLiteral("isDirectory")] = completion.isDirectory;
            item[QStringLiteral("detail")] = completion.detail;
            completionList.append(item);
        }
        
        result.data = completionList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool PathCompletionProvider::isAvailable(const EditorContext& ctx) const
{
    // 检查光标是否在字符串中
    // 简单的检查：查看前面是否有引号
    if (ctx.column > 0) {
        QString beforeCursor = ctx.selectedText.left(ctx.column);
        return beforeCursor.contains(QLatin1Char('\"')) || beforeCursor.contains(QLatin1Char('\''));
    }
    return false;
}

QString PathCompletionProvider::extractPathPrefix(const EditorContext& ctx)
{
    // 从编辑器上下文中提取路径前缀
    // 查找最后一个引号之后的文本
    int quoteIndex = ctx.selectedText.lastIndexOf(QLatin1Char('\"'), ctx.column);
    if (quoteIndex == -1) {
        quoteIndex = ctx.selectedText.lastIndexOf(QLatin1Char('\''), ctx.column);
    }
    
    if (quoteIndex >= 0 && quoteIndex < ctx.column) {
        return ctx.selectedText.mid(quoteIndex + 1, ctx.column - quoteIndex - 1);
    }
    
    return QString();
}

QList<PathCompletionProvider::PathCompletion> PathCompletionProvider::getCompletions(
    const QString& basePath, const QString& prefix)
{
    QList<PathCompletion> completions;
    
    QDir dir(basePath);
    if (prefix.contains(QLatin1Char('/'))) {
        QString subPath = prefix.section(QLatin1Char('/'), 0, -2);
        dir.cd(subPath);
    }
    
    // 列举目录中的项
    for (const auto& entry : dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot)) {
        // 过滤隐藏文件
        if (entry.startsWith(QLatin1Char('.'))) {
            continue;
        }
        
        QFileInfo info(dir.absoluteFilePath(entry));
        PathCompletion completion;
        completion.path = entry;
        completion.label = entry;
        completion.isDirectory = info.isDir();
        completion.icon = completion.isDirectory ? QStringLiteral("folder") : QStringLiteral("file");
        completion.detail = completion.isDirectory ? QStringLiteral("Folder") : QStringLiteral("File");
        
        completions.append(completion);
    }
    
    return completions;
}
