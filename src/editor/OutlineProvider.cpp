#include "editor/OutlineProvider.h"
#include <QDebug>
#include <QRegularExpression>

QString Symbol::typeString() const
{
    switch (type) {
        case Function: return "Function";
        case Class: return "Class";
        case Variable: return "Variable";
        case Struct: return "Struct";
        case Union: return "Union";
        case Enum: return "Enum";
        case Namespace: return "Namespace";
        default: return "Unknown";
    }
}

OutlineProvider::OutlineProvider(QObject* parent)
    : QObject(parent)
{
}

QList<Symbol> OutlineProvider::extractSymbols(const QString& text, const QString& language)
{
    m_symbols.clear();
    
    if (language == "cpp" || language == "c" || language == "h" || language == "hpp") {
        extractCppSymbols(text, m_symbols);
    } else if (language == "python" || language == "py") {
        extractPythonSymbols(text, m_symbols);
    } else if (language == "javascript" || language == "typescript" || language == "js" || language == "ts") {
        extractJavaScriptSymbols(text, m_symbols);
    }
    
    m_cacheValid = true;
    emit symbolsUpdated(m_symbols);
    return m_symbols;
}

void OutlineProvider::extractCppSymbols(const QString& text, QList<Symbol>& symbols)
{
    auto lines = text.split('\n');
    
    QRegularExpression functionPattern(R"(^\s*([\w:]+\s+)*(\w+)\s*\(([^)]*)\)\s*(?:const)?\s*\{)");
    QRegularExpression classPattern(R"(^\s*(class|struct)\s+(\w+))");
    QRegularExpression enumPattern(R"(^\s*enum\s+(\w*))");
    
    for (int i = 0; i < lines.size(); ++i) {
        const QString& line = lines[i];
        
        // Check for functions
        auto funcMatch = functionPattern.match(line);
        if (funcMatch.hasMatch()) {
            Symbol sym;
            sym.type = Symbol::Function;
            sym.name = funcMatch.captured(2);
            sym.signature = line.trimmed();
            sym.line = i;
            sym.column = 0;
            sym.endLine = i;
            symbols.append(sym);
        }
        
        // Check for classes
        auto classMatch = classPattern.match(line);
        if (classMatch.hasMatch()) {
            Symbol sym;
            sym.type = Symbol::Class;
            sym.name = classMatch.captured(2);
            sym.line = i;
            sym.column = 0;
            sym.endLine = i;
            symbols.append(sym);
        }
        
        // Check for enums
        auto enumMatch = enumPattern.match(line);
        if (enumMatch.hasMatch()) {
            Symbol sym;
            sym.type = Symbol::Enum;
            sym.name = enumMatch.captured(1);
            sym.line = i;
            sym.column = 0;
            sym.endLine = i;
            symbols.append(sym);
        }
    }
}

void OutlineProvider::extractPythonSymbols(const QString& text, QList<Symbol>& symbols)
{
    auto lines = text.split('\n');
    
    QRegularExpression defPattern(R"(^\s*def\s+(\w+)\s*\()");
    QRegularExpression classPattern(R"(^\s*class\s+(\w+))");
    
    for (int i = 0; i < lines.size(); ++i) {
        const QString& line = lines[i];
        
        auto defMatch = defPattern.match(line);
        if (defMatch.hasMatch()) {
            Symbol sym;
            sym.type = Symbol::Function;
            sym.name = defMatch.captured(1);
            sym.line = i;
            sym.column = 0;
            symbols.append(sym);
        }
        
        auto classMatch = classPattern.match(line);
        if (classMatch.hasMatch()) {
            Symbol sym;
            sym.type = Symbol::Class;
            sym.name = classMatch.captured(1);
            sym.line = i;
            sym.column = 0;
            symbols.append(sym);
        }
    }
}

void OutlineProvider::extractJavaScriptSymbols(const QString& text, QList<Symbol>& symbols)
{
    auto lines = text.split('\n');
    
    QRegularExpression functionPattern(R"(^\s*(async\s+)?(function\s+)?(\w+)\s*\(|const\s+(\w+)\s*=\s*\([^)]*\)\s*=>|class\s+(\w+))");
    
    for (int i = 0; i < lines.size(); ++i) {
        const QString& line = lines[i];
        
        auto match = functionPattern.match(line);
        if (match.hasMatch()) {
            Symbol sym;
            if (line.contains("class")) {
                sym.type = Symbol::Class;
                sym.name = match.captured(5);
            } else {
                sym.type = Symbol::Function;
                sym.name = match.captured(3).isEmpty() ? match.captured(4) : match.captured(3);
            }
            sym.line = i;
            sym.column = 0;
            symbols.append(sym);
        }
    }
}

Symbol OutlineProvider::getSymbolAtLine(int line) const
{
    for (const auto& symbol : m_symbols) {
        if (symbol.line == line) {
            return symbol;
        }
    }
    return {};
}

QList<Symbol> OutlineProvider::getSymbolsByType(Symbol::Type type) const
{
    QList<Symbol> result;
    for (const auto& symbol : m_symbols) {
        if (symbol.type == type) {
            result.append(symbol);
        }
    }
    return result;
}

QList<Symbol> OutlineProvider::findSymbols(const QString& pattern) const
{
    QList<Symbol> result;
    QString lowerPattern = pattern.toLower();
    
    for (const auto& symbol : m_symbols) {
        if (symbol.name.toLower().contains(lowerPattern)) {
            result.append(symbol);
        }
    }
    
    return result;
}

void OutlineProvider::goToSymbol(const QString& symbolName)
{
    for (const auto& symbol : m_symbols) {
        if (symbol.name == symbolName) {
            emit symbolNavigated(symbol.line, symbol.column);
            return;
        }
    }
}

QStringList OutlineProvider::getBreadcrumb(int line) const
{
    QStringList breadcrumb;
    
    for (const auto& symbol : m_symbols) {
        if (symbol.line <= line && symbol.line <= line) {
            breadcrumb.append(symbol.name);
        }
    }
    
    return breadcrumb;
}

void OutlineProvider::invalidateCache()
{
    m_cacheValid = false;
}

bool OutlineProvider::isCacheValid() const
{
    return m_cacheValid;
}
