#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QHash>

/**
 * @class StickyScroll
 * @brief Show breadcrumb trail of code hierarchy as you scroll
 * 
 * Ported from VS Code: /src/vs/editor/contrib/stickyScroll/
 * 
 * Features:
 * - Display current scope hierarchy
 * - Navigate by clicking scope
 * - Show function/class names as you scroll
 * - Update on code changes
 */

class StickyScroll : public QObject {
    Q_OBJECT

public:
    explicit StickyScroll(QObject* parent = nullptr);
    ~StickyScroll() override = default;

    // Scope entry in the hierarchy
    struct ScopeEntry {
        QString name;        // Function/class/block name
        QString kind;        // "function", "class", "if", "for", "while", etc.
        int line{0};         // Line where scope starts
        int column{0};       // Column where scope starts
        int indentLevel{0};  // Nesting level
        QString icon;        // Icon type
        QString detail;      // Additional detail (e.g., parameters)
    };

    // Sticky scroll state for a line range
    struct ScrollState {
        int visibleStartLine{0};
        int visibleEndLine{0};
        QList<ScopeEntry> scopePath;  // Stack of scopes
        QString displayText;          // Human-readable display
    };

    /**
     * @brief Update sticky scroll for visible range
     * @param filePath File path
     * @param startLine First visible line
     * @param endLine Last visible line
     * @return Scroll state with scope information
     */
    ScrollState updateVisibleRange(const QString& filePath, int startLine, int endLine);

    /**
     * @brief Get scope hierarchy at line
     * @param filePath File path
     * @param line Line number
     * @return List of scopes (from root to current)
     */
    QList<ScopeEntry> getScopeHierarchy(const QString& filePath, int line);

    /**
     * @brief Get parent scope
     * @param filePath File path
     * @param line Line number
     * @return Parent scope entry (if exists)
     */
    ScopeEntry getParentScope(const QString& filePath, int line);

    /**
     * @brief Get all scopes at line
     * @param line Line number
     * @return List of scopes
     */
    QList<ScopeEntry> getAllScopes(int line) const;

    /**
     * @brief Navigate to scope
     * @param filePath File path
     * @param scopeName Scope name to navigate to
     * @return True if navigation successful
     */
    bool navigateToScope(const QString& filePath, const QString& scopeName);

    /**
     * @brief Parse scopes from code (AST-based)
     * @param filePath File path
     * @param code Code content
     * @param language Programming language
     * @return List of scopes found
     */
    QList<ScopeEntry> parseScopes(const QString& filePath, const QString& code, const QString& language);

    /**
     * @brief Get scope display text
     * @param scopes List of scopes
     * @return Formatted display text
     */
    QString formatScopeDisplay(const QList<ScopeEntry>& scopes) const;

    /**
     * @brief Check if line is in scope
     * @param line Line number
     * @param scope Scope entry
     * @return True if line is within scope
     */
    bool lineInScope(int line, const ScopeEntry& scope) const;

    /**
     * @brief Get scope depth at line
     * @param filePath File path
     * @param line Line number
     * @return Nesting depth
     */
    int getScopeDepth(const QString& filePath, int line);

    /**
     * @brief Enable/disable sticky scroll
     */
    void setEnabled(bool enabled) { m_enabled = enabled; }
    bool isEnabled() const { return m_enabled; }

    /**
     * @brief Set maximum number of visible scopes
     */
    void setMaxVisibleScopes(int count) { m_maxVisibleScopes = count; }

    /**
     * @brief Clear cache
     */
    void clearCache() { m_scopeCache.clear(); }

signals:
    /**
     * @brief Emitted when scroll state updated
     */
    void scrollStateChanged(const ScrollState& state);

    /**
     * @brief Emitted when scope clicked
     */
    void scopeClicked(const ScopeEntry& scope);

    /**
     * @brief Emitted when scope hovered
     */
    void scopeHovered(const ScopeEntry& scope);

private:
    // Parse function scope
    ScopeEntry parseFunctionScope(const QString& line, int lineNum, int indentLevel);

    // Parse class scope
    ScopeEntry parseClassScope(const QString& line, int lineNum, int indentLevel);

    // Parse control flow scope (if, for, while, etc.)
    ScopeEntry parseControlFlowScope(const QString& line, int lineNum, int indentLevel);

    // Extract identifier name from code line
    QString extractIdentifier(const QString& line, const QString& prefix) const;

    // Cache structure
    struct CacheEntry {
        QList<ScopeEntry> scopes;
        QString language;
    };

    bool m_enabled{true};
    int m_maxVisibleScopes{5};
    QHash<QString, CacheEntry> m_scopeCache;
    ScrollState m_lastState;
};

Q_DECLARE_METATYPE(StickyScroll::ScopeEntry)
Q_DECLARE_METATYPE(StickyScroll::ScrollState)
