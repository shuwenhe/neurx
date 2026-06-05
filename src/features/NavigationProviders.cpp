#include "features/NavigationProviders.h"
#include <QFileSystemWatcher>
#include <QFileInfo>
#include <QRegularExpression>
#include <algorithm>

// ── BreadcrumbProvider 实现 ──────────────────────────────────────────────

BreadcrumbProvider::BreadcrumbProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result BreadcrumbProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("breadcrumbs");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<Breadcrumb> breadcrumbs = getBreadcrumbs(ctx);
        
        QVariantList breadcrumbList;
        for (const auto& breadcrumb : breadcrumbs) {
            QVariantMap item;
            item[QStringLiteral("symbol")] = breadcrumb.symbol;
            item[QStringLiteral("kind")] = breadcrumb.kind;
            item[QStringLiteral("icon")] = breadcrumb.icon;
            item[QStringLiteral("line")] = breadcrumb.line;
            item[QStringLiteral("character")] = breadcrumb.character;
            breadcrumbList.append(item);
        }
        
        result.data = breadcrumbList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool BreadcrumbProvider::isAvailable(const EditorContext& ctx) const
{
    return !ctx.filePath.isEmpty() && ctx.line >= 0;
}

QList<BreadcrumbProvider::Breadcrumb> BreadcrumbProvider::getBreadcrumbs(const EditorContext& ctx)
{
    QList<Breadcrumb> breadcrumbs;
    
    // 添加文件作为根节点
    Breadcrumb fileBreadcrumb;
    fileBreadcrumb.symbol = QFileInfo(ctx.filePath).fileName();
    fileBreadcrumb.kind = 1; // File
    fileBreadcrumb.icon = QStringLiteral("file");
    breadcrumbs.append(fileBreadcrumb);
    
    // 这里应该调用 LSP 获取符号树
    // 然后根据当前行号构建面包屑路径
    
    return breadcrumbs;
}

QList<BreadcrumbProvider::Breadcrumb> BreadcrumbProvider::buildBreadcrumbs(
    const QVariantList& symbols, int line)
{
    QList<Breadcrumb> breadcrumbs;
    
    for (const auto& symbolVar : symbols) {
        if (symbolVar.typeId() != QMetaType::QVariantMap) continue;
        
        const QVariantMap& symbolMap = symbolVar.toMap();
        int symbolLine = symbolMap.value(QStringLiteral("line")).toInt();
        
        if (symbolLine <= line) {
            Breadcrumb breadcrumb;
            breadcrumb.symbol = symbolMap.value(QStringLiteral("name")).toString();
            breadcrumb.kind = symbolMap.value(QStringLiteral("kind")).toInt();
            breadcrumb.line = symbolLine;
            breadcrumbs.append(breadcrumb);
        }
    }
    
    return breadcrumbs;
}

// ── FindReferencesProvider 实现 ──────────────────────────────────────────

FindReferencesProvider::FindReferencesProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result FindReferencesProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("find-references");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<Reference> references = findReferences(ctx, true);
        
        // 按文件分组
        QMap<QString, QList<Reference>> grouped = groupByFile(references);
        
        QVariantList referencesList;
        for (const auto& uri : grouped.keys()) {
            QVariantMap group;
            group[QStringLiteral("uri")] = uri;
            
            QVariantList items;
            for (const auto& ref : grouped[uri]) {
                QVariantMap item;
                item[QStringLiteral("line")] = ref.line;
                item[QStringLiteral("startCharacter")] = ref.startCharacter;
                item[QStringLiteral("endCharacter")] = ref.endCharacter;
                item[QStringLiteral("preview")] = ref.preview;
                item[QStringLiteral("isDeclaration")] = ref.isDeclaration;
                items.append(item);
            }
            
            group[QStringLiteral("references")] = items;
            referencesList.append(group);
        }
        
        result.data = referencesList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool FindReferencesProvider::isAvailable(const EditorContext& ctx) const
{
    return !ctx.selectedText.isEmpty() || ctx.column >= 0;
}

QList<FindReferencesProvider::Reference> FindReferencesProvider::findReferences(
    const EditorContext& ctx, bool includeDeclaration)
{
    QList<Reference> references;
    
    // 应该调用 LSP textDocument/references
    // 这里是占位符实现
    
    return references;
}

QList<FindReferencesProvider::Reference> FindReferencesProvider::parseReferences(const QVariant& lspResponse)
{
    QList<Reference> references;
    
    if (lspResponse.typeId() == QMetaType::QVariantList) {
        const QVariantList& list = lspResponse.toList();
        for (const auto& item : list) {
            if (item.typeId() == QMetaType::QVariantMap) {
                const QVariantMap& map = item.toMap();
                Reference ref;
                ref.uri = map.value(QStringLiteral("uri")).toString();
                ref.line = map.value(QStringLiteral("line")).toInt();
                references.append(ref);
            }
        }
    }
    
    return references;
}

QMap<QString, QList<FindReferencesProvider::Reference>> FindReferencesProvider::groupByFile(
    const QList<Reference>& references)
{
    QMap<QString, QList<Reference>> grouped;
    
    for (const auto& ref : references) {
        grouped[ref.uri].append(ref);
    }
    
    return grouped;
}

// ── SymbolNavigationProvider 实现 ────────────────────────────────────────

SymbolNavigationProvider::SymbolNavigationProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result SymbolNavigationProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("symbol-navigation");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QList<Symbol> symbolTree = getSymbolTree(ctx);
        Symbol currentSymbol = findSymbolAt(ctx);
        
        QVariantMap resultData;
        // 构建符号树 QVariant
        resultData[QStringLiteral("currentSymbol")] = currentSymbol.name;
        resultData[QStringLiteral("line")] = ctx.line;
        
        result.data = resultData;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool SymbolNavigationProvider::isAvailable(const EditorContext& ctx) const
{
    return !ctx.filePath.isEmpty();
}

QList<SymbolNavigationProvider::Symbol> SymbolNavigationProvider::getSymbolTree(const EditorContext& ctx)
{
    QList<Symbol> symbolTree;
    
    // 应该调用 LSP textDocument/documentSymbol
    // 这里是占位符实现
    
    return symbolTree;
}

SymbolNavigationProvider::Symbol SymbolNavigationProvider::findSymbolAt(const EditorContext& ctx)
{
    Symbol symbol;
    // 应该根据行号找到符号
    return symbol;
}

QList<SymbolNavigationProvider::Symbol> SymbolNavigationProvider::buildSymbolTree(const QVariantList& symbols)
{
    QList<Symbol> tree;
    
    for (const auto& symbolVar : symbols) {
        if (symbolVar.typeId() != QMetaType::QVariantMap) continue;
        
        const QVariantMap& symbolMap = symbolVar.toMap();
        Symbol symbol;
        symbol.name = symbolMap.value(QStringLiteral("name")).toString();
        symbol.kind = symbolMap.value(QStringLiteral("kind")).toInt();
        symbol.line = symbolMap.value(QStringLiteral("line")).toInt();
        
        tree.append(symbol);
    }
    
    return tree;
}

SymbolNavigationProvider::Symbol SymbolNavigationProvider::findSymbolByPosition(
    const QList<Symbol>& symbols, int line)
{
    Symbol result;
    
    for (const auto& symbol : symbols) {
        if (symbol.line <= line) {
            result = symbol;
        }
    }
    
    return result;
}

// ── WorkspaceSymbolProvider 实现 ────────────────────────────────────────

WorkspaceSymbolProvider::WorkspaceSymbolProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result WorkspaceSymbolProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("workspace-symbols");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        QString query = ctx.selectedText;
        if (query.isEmpty()) {
            query = ctx.text.mid(ctx.column - 10, 20).trimmed();
        }
        
        QList<WorkspaceSymbol> symbols = search(query);
        
        QVariantList symbolList;
        for (const auto& symbol : symbols) {
            QVariantMap item;
            item[QStringLiteral("name")] = symbol.name;
            item[QStringLiteral("kind")] = symbol.kind;
            item[QStringLiteral("location")] = symbol.location;
            item[QStringLiteral("containerName")] = symbol.containerName;
            item[QStringLiteral("detail")] = symbol.detail;
            symbolList.append(item);
        }
        
        result.data = symbolList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool WorkspaceSymbolProvider::isAvailable(const EditorContext& ctx) const
{
    return true; // 总是可用
}

QList<WorkspaceSymbolProvider::WorkspaceSymbol> WorkspaceSymbolProvider::search(
    const QString& query, int maxResults)
{
    QList<WorkspaceSymbol> symbols = queryLSP(query);
    
    // 限制结果数量
    if (symbols.size() > maxResults) {
        symbols = symbols.mid(0, maxResults);
    }
    
    return symbols;
}

QList<WorkspaceSymbolProvider::WorkspaceSymbol> WorkspaceSymbolProvider::queryLSP(const QString& query)
{
    QList<WorkspaceSymbol> symbols;
    
    // 应该调用 LSP workspace/symbol
    // 这里是占位符实现
    
    return symbols;
}

QList<WorkspaceSymbolProvider::WorkspaceSymbol> WorkspaceSymbolProvider::parseWorkspaceSymbols(
    const QVariant& lspResponse)
{
    QList<WorkspaceSymbol> symbols;
    
    if (lspResponse.typeId() == QMetaType::QVariantList) {
        const QVariantList& list = lspResponse.toList();
        for (const auto& item : list) {
            if (item.typeId() == QMetaType::QVariantMap) {
                const QVariantMap& map = item.toMap();
                WorkspaceSymbol symbol;
                symbol.name = map.value(QStringLiteral("name")).toString();
                symbol.kind = map.value(QStringLiteral("kind")).toInt();
                symbols.append(symbol);
            }
        }
    }
    
    return symbols;
}

bool WorkspaceSymbolProvider::fuzzyMatch(const QString& query, const QString& symbol)
{
    if (query.isEmpty()) return true;
    if (symbol.isEmpty()) return false;
    
    int queryIndex = 0;
    int symbolIndex = 0;
    
    while (queryIndex < query.size() && symbolIndex < symbol.size()) {
        if (query[queryIndex].toLower() == symbol[symbolIndex].toLower()) {
            queryIndex++;
        }
        symbolIndex++;
    }
    
    return queryIndex == query.size();
}

// ── FileWatcherProvider 实现 ─────────────────────────────────────────────

FileWatcherProvider::FileWatcherProvider(QObject *parent)
    : FeatureProvider(parent)
{
}

FeatureProvider::Result FileWatcherProvider::execute(const EditorContext& ctx)
{
    Result result;
    result.id = QStringLiteral("file-watcher");
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    
    try {
        startWatching(QFileInfo(ctx.filePath).absolutePath());
        
        QVariantList changesList;
        for (const auto& change : m_changes) {
            QVariantMap item;
            item[QStringLiteral("uri")] = change.uri;
            item[QStringLiteral("type")] = static_cast<int>(change.type);
            changesList.append(item);
        }
        
        result.data = changesList;
        result.success = true;
    } catch (const std::exception& e) {
        result.error = QString::fromStdString(e.what());
        result.success = false;
    }
    
    return result;
}

bool FileWatcherProvider::isAvailable(const EditorContext& ctx) const
{
    return !ctx.filePath.isEmpty();
}

void FileWatcherProvider::startWatching(const QString& path)
{
    if (!m_watchedPaths.contains(path)) {
        m_watchedPaths.append(path);
    }
}

void FileWatcherProvider::stopWatching(const QString& path)
{
    m_watchedPaths.removeAll(path);
}

void FileWatcherProvider::detectChanges(const QString& path)
{
    // 实现文件变化检测逻辑
    // 这里应该比较文件的修改时间或内容
}
