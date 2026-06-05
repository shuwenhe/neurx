#include "StickyScroll.h"
#include <QDebug>
#include <QRegularExpression>
#include <QFile>
#include <algorithm>

StickyScroll::StickyScroll(QObject* parent)
    : QObject(parent)
{
}

StickyScroll::ScrollState StickyScroll::updateVisibleRange(const QString& filePath, int startLine, int endLine)
{
    ScrollState state;
    state.visibleStartLine = startLine;
    state.visibleEndLine = endLine;

    // Get scopes for the start line (most critical)
    state.scopePath = getScopeHierarchy(filePath, startLine);

    // Limit to max visible scopes
    if (state.scopePath.size() > m_maxVisibleScopes) {
        state.scopePath = state.scopePath.mid(state.scopePath.size() - m_maxVisibleScopes);
    }

    state.displayText = formatScopeDisplay(state.scopePath);
    m_lastState = state;

    emit scrollStateChanged(state);
    return state;
}

QList<StickyScroll::ScopeEntry> StickyScroll::getScopeHierarchy(const QString& filePath, int line)
{
    QList<ScopeEntry> result;

    // Check cache first
    auto it = m_scopeCache.find(filePath);
    if (it != m_scopeCache.end()) {
        // Find all scopes that contain this line
        for (const auto& scope : it->scopes) {
            if (lineInScope(line, scope)) {
                result.append(scope);
            }
        }
        // Sort by indent level
        std::sort(result.begin(), result.end(),
                  [](const ScopeEntry& a, const ScopeEntry& b) {
                      return a.indentLevel < b.indentLevel;
                  });
        return result;
    }

    return result;
}

StickyScroll::ScopeEntry StickyScroll::getParentScope(const QString& filePath, int line)
{
    auto scopes = getScopeHierarchy(filePath, line);
    if (scopes.size() >= 2) {
        return scopes[scopes.size() - 2];
    }
    return ScopeEntry();
}

QList<StickyScroll::ScopeEntry> StickyScroll::getAllScopes(int line) const
{
    QList<ScopeEntry> result;
    for (const auto& entry : m_scopeCache) {
        for (const auto& scope : entry.scopes) {
            if (lineInScope(line, scope)) {
                result.append(scope);
            }
        }
    }
    return result;
}

bool StickyScroll::navigateToScope(const QString& filePath, const QString& scopeName)
{
    auto it = m_scopeCache.find(filePath);
    if (it != m_scopeCache.end()) {
        for (const auto& scope : it->scopes) {
            if (scope.name == scopeName) {
                emit scopeClicked(scope);
                return true;
            }
        }
    }
    return false;
}

QList<StickyScroll::ScopeEntry> StickyScroll::parseScopes(const QString& filePath, const QString& code, const QString& language)
{
    QList<ScopeEntry> scopes;
    QStringList lines = code.split('\n');
    int indentLevel = 0;
    int currentLine = 0;

    for (const auto& line : lines) {
        currentLine++;
        
        // Skip empty lines and comments
        QString trimmed = line.trimmed();
        if (trimmed.isEmpty() || trimmed.startsWith("//") || trimmed.startsWith("#")) {
            continue;
        }

        // Calculate indent level
        int indent = 0;
        for (const auto& ch : line) {
            if (ch == ' ') indent++;
            else if (ch == '\t') indent += 4;
            else break;
        }
        indentLevel = indent / 4;

        // Parse different scope types based on language
        if (language == "cpp" || language == "c" || language == "java" || language == "csharp") {
            // Check for function/method
            if (trimmed.contains(QRegularExpression("^(\\w+\\s+)*\\w+\\s*\\(.*\\)\\s*(?:{|const|override)?.*"))) {
                auto scope = parseFunctionScope(trimmed, currentLine, indentLevel);
                if (!scope.name.isEmpty()) {
                    scopes.append(scope);
                }
            }
            // Check for class/struct
            else if (trimmed.contains(QRegularExpression("^(class|struct|interface)\\s+\\w+"))) {
                auto scope = parseClassScope(trimmed, currentLine, indentLevel);
                if (!scope.name.isEmpty()) {
                    scopes.append(scope);
                }
            }
            // Check for control flow
            else if (trimmed.startsWith("if ") || trimmed.startsWith("for ") || 
                     trimmed.startsWith("while ") || trimmed.startsWith("switch ")) {
                auto scope = parseControlFlowScope(trimmed, currentLine, indentLevel);
                if (!scope.name.isEmpty()) {
                    scopes.append(scope);
                }
            }
        }
    }

    // Cache results
    m_scopeCache[filePath] = {scopes, language};
    return scopes;
}

QString StickyScroll::formatScopeDisplay(const QList<ScopeEntry>& scopes) const
{
    QStringList parts;
    for (const auto& scope : scopes) {
        QString display = scope.name;
        if (!scope.detail.isEmpty()) {
            display += QString(" %1").arg(scope.detail);
        }
        parts.append(display);
    }
    return parts.join(" > ");
}

bool StickyScroll::lineInScope(int line, const ScopeEntry& scope) const
{
    // Simple check: line must be after scope start
    // In reality, would need to track scope end using braces
    return line >= scope.line;
}

int StickyScroll::getScopeDepth(const QString& filePath, int line)
{
    return getScopeHierarchy(filePath, line).size();
}

StickyScroll::ScopeEntry StickyScroll::parseFunctionScope(const QString& line, int lineNum, int indentLevel)
{
    ScopeEntry scope;
    scope.kind = "function";
    scope.line = lineNum;
    scope.indentLevel = indentLevel;
    scope.icon = "function";

    // Extract function name (simplified)
    QRegularExpression funcRegex("(\\w+)\\s*\\(");
    auto match = funcRegex.match(line);
    if (match.hasMatch()) {
        scope.name = match.captured(1);
        // Extract parameters as detail
        int paramStart = line.indexOf('(');
        int paramEnd = line.lastIndexOf(')');
        if (paramStart != -1 && paramEnd != -1) {
            scope.detail = line.mid(paramStart, paramEnd - paramStart + 1);
        }
    }

    return scope;
}

StickyScroll::ScopeEntry StickyScroll::parseClassScope(const QString& line, int lineNum, int indentLevel)
{
    ScopeEntry scope;
    scope.line = lineNum;
    scope.indentLevel = indentLevel;

    if (line.startsWith("class")) {
        scope.kind = "class";
        scope.icon = "class";
    } else if (line.startsWith("struct")) {
        scope.kind = "struct";
        scope.icon = "struct";
    } else if (line.startsWith("interface")) {
        scope.kind = "interface";
        scope.icon = "interface";
    } else {
        return scope;
    }

    // Extract class name
    QRegularExpression classRegex("(?:class|struct|interface)\\s+(\\w+)");
    auto match = classRegex.match(line);
    if (match.hasMatch()) {
        scope.name = match.captured(1);
    }

    return scope;
}

StickyScroll::ScopeEntry StickyScroll::parseControlFlowScope(const QString& line, int lineNum, int indentLevel)
{
    ScopeEntry scope;
    scope.line = lineNum;
    scope.indentLevel = indentLevel;

    if (line.startsWith("if")) {
        scope.kind = "if";
        scope.icon = "if";
        scope.name = "if";
    } else if (line.startsWith("for")) {
        scope.kind = "for";
        scope.icon = "for";
        scope.name = "for";
    } else if (line.startsWith("while")) {
        scope.kind = "while";
        scope.icon = "while";
        scope.name = "while";
    } else if (line.startsWith("switch")) {
        scope.kind = "switch";
        scope.icon = "switch";
        scope.name = "switch";
    }

    // Extract condition as detail
    int condStart = line.indexOf('(');
    int condEnd = line.lastIndexOf(')');
    if (condStart != -1 && condEnd != -1 && condEnd > condStart) {
        scope.detail = line.mid(condStart, condEnd - condStart + 1);
    }

    return scope;
}

QString StickyScroll::extractIdentifier(const QString& line, const QString& prefix) const
{
    QRegularExpression regex(prefix + "\\s+(\\w+)");
    auto match = regex.match(line);
    if (match.hasMatch()) {
        return match.captured(1);
    }
    return QString();
}
