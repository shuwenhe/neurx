#pragma once
#include "features/FeatureProviders.h"
#include <QList>
#include <QMap>
#include <QDateTime>
#include <QFileInfo>
#include <QFileSystemWatcher>

/**
 * @brief 面包屑导航提供者
 * 
 * 显示当前代码位置的层级路径
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 1 天
 */
class BreadcrumbProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct Breadcrumb {
        QString symbol;        // 符号名称
        int kind{0};          // 符号类型 (Class/Method/Function等)
        QString icon;         // 图标
        int line{0};          // 行号
        int character{0};     // 列号
        QString signature;    // 签名（如有）
    };

    explicit BreadcrumbProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<Breadcrumb> getBreadcrumbs(const EditorContext& ctx);

private:
    /**
     * 从文档符号生成面包屑
     */
    QList<Breadcrumb> buildBreadcrumbs(const QVariantList& symbols, int line);
};

/**
 * @brief 查找所有引用提供者
 * 
 * 查找符号的所有使用位置
 * 复杂度: ⭐⭐⭐ (中等)
 * 工作量: 1 天
 */
class FindReferencesProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct Reference {
        QString uri;          // 文件 URI
        int line{0};         // 行号
        int startCharacter{0}; // 开始列号
        int endCharacter{0};   // 结束列号
        QString preview;      // 代码预览
        bool isDeclaration{false}; // 是否是声明
    };

    explicit FindReferencesProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<Reference> findReferences(const EditorContext& ctx, bool includeDeclaration = true);

private:
    /**
     * 从 LSP 响应解析引用
     */
    QList<Reference> parseReferences(const QVariant& lspResponse);

    /**
     * 按文件分组引用
     */
    QMap<QString, QList<Reference>> groupByFile(const QList<Reference>& references);
};

/**
 * @brief 面包屑和符号导航
 * 
 * 集成的符号浏览功能
 */
class SymbolNavigationProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct Symbol {
        QString name;
        int kind{0};
        QString icon;
        int line{0};
        int character{0};
        QList<Symbol> children; // 嵌套符号
    };

    explicit SymbolNavigationProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<Symbol> getSymbolTree(const EditorContext& ctx);
    Symbol findSymbolAt(const EditorContext& ctx);

private:
    /**
     * 构建符号树
     */
    QList<Symbol> buildSymbolTree(const QVariantList& symbols);

    /**
     * 查找特定位置的符号
     */
    Symbol findSymbolByPosition(const QList<Symbol>& symbols, int line);
};

/**
 * @brief 工作区符号搜索提供者
 * 
 * 搜索整个工作区的符号
 * 复杂度: ⭐⭐⭐ (中等)
 * 工作量: 1.5 天
 */
class WorkspaceSymbolProvider : public FeatureProvider {
    Q_OBJECT

public:
    struct WorkspaceSymbol {
        QString name;         // 符号名称
        int kind{0};         // 符号类型
        QString icon;        // 图标
        QString location;    // 位置 (file:line:column)
        QString containerName; // 容器名称（类、模块等）
        QString detail;      // 详细信息
    };

    explicit WorkspaceSymbolProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    QList<WorkspaceSymbol> search(const QString& query, int maxResults = 50);

private:
    /**
     * 执行 LSP workspace/symbol 请求
     */
    QList<WorkspaceSymbol> queryLSP(const QString& query);

    /**
     * 从 LSP 响应解析工作区符号
     */
    QList<WorkspaceSymbol> parseWorkspaceSymbols(const QVariant& lspResponse);

    /**
     * 模糊匹配符号
     */
    bool fuzzyMatch(const QString& query, const QString& symbol);
};

/**
 * @brief 文件监视提供者
 * 
 * 监视工作区文件变化
 * 复杂度: ⭐⭐ (简单-中等)
 * 工作量: 1 天
 */
class FileWatcherProvider : public FeatureProvider {
    Q_OBJECT

public:
    enum FileChangeType {
        Created = 1,
        Changed = 2,
        Deleted = 3
    };

    struct FileChange {
        QString uri;
        FileChangeType type;
        QDateTime timestamp;
    };

    explicit FileWatcherProvider(QObject *parent = nullptr);

    Result execute(const EditorContext& ctx) override;
    bool isAvailable(const EditorContext& ctx) const override;

    void startWatching(const QString& path);
    void stopWatching(const QString& path);
    QList<FileChange> getChanges() const { return m_changes; }

signals:
    void fileChanged(const FileChange& change);
    void fileCreated(const QString& path);
    void fileDeleted(const QString& path);

private:
    QList<FileChange> m_changes;
    QStringList m_watchedPaths;

    /**
     * 检测文件变化
     */
    void detectChanges(const QString& path);
};
