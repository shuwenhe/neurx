#pragma once

#include <QObject>
#include <QString>
#include <QList>

/**
 * @class OutlineProvider
 * @brief Provides code outline/symbol navigation
 * 
 * Features:
 * - Extract symbols (functions, classes, variables)
 * - Build symbol tree
 * - Navigate to symbol
 * - Breadcrumb navigation
 */

struct Symbol {
    enum Type { Function, Class, Variable, Struct, Union, Enum, Namespace, Unknown };
    
    Type type;
    QString name;
    int line;
    int column;
    int endLine;
    QString signature;  // For functions
    QString detail;     // Type or parent class
    int indent;
    
    QString typeString() const;
};

class OutlineProvider : public QObject {
    Q_OBJECT

public:
    explicit OutlineProvider(QObject* parent = nullptr);
    ~OutlineProvider() override = default;
    
    // Symbol extraction
    QList<Symbol> extractSymbols(const QString& text, const QString& language);
    
    // Query
    Symbol getSymbolAtLine(int line) const;
    QList<Symbol> getSymbolsByType(Symbol::Type type) const;
    QList<Symbol> findSymbols(const QString& pattern) const;
    
    // Navigation
    void goToSymbol(const QString& symbolName);
    QStringList getBreadcrumb(int line) const;
    
    // Caching
    void invalidateCache();
    bool isCacheValid() const;

signals:
    void symbolsUpdated(const QList<Symbol>& symbols);
    void symbolNavigated(int line, int column);

private:
    QList<Symbol> m_symbols;
    bool m_cacheValid = false;
    
    void extractCppSymbols(const QString& text, QList<Symbol>& symbols);
    void extractPythonSymbols(const QString& text, QList<Symbol>& symbols);
    void extractJavaScriptSymbols(const QString& text, QList<Symbol>& symbols);
};
