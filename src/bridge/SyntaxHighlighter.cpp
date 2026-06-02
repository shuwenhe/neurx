// Copyright (C) 2024 NeurX Code
// SPDX-License-Identifier: GPL-3.0-only

#include "SyntaxHighlighter.h"
#include <QFont>

// ── VS Code Dark+ colour palette ──────────────────────────────────────────────
namespace Color {
    static const QColor Keyword  {0x56, 0x9c, 0xd6}; // #569cd6  blue
    static const QColor Type     {0x4e, 0xc9, 0xb0}; // #4ec9b0  teal
    static const QColor String   {0xce, 0x91, 0x78}; // #ce9178  dark orange
    static const QColor Comment  {0x6a, 0x99, 0x55}; // #6a9955  green
    static const QColor Number   {0xb5, 0xce, 0xa8}; // #b5cea8  light green
    static const QColor Function {0xdc, 0xdc, 0xaa}; // #dcdcaa  yellow
    static const QColor Preproc  {0xc5, 0x86, 0xc0}; // #c586c0  magenta
    static const QColor Builtin  {0x9c, 0xdc, 0xfe}; // #9cdcfe  light blue
}

static QTextCharFormat fmt(const QColor &col, bool bold = false)
{
    QTextCharFormat f;
    f.setForeground(col);
    if (bold)
        f.setFontWeight(QFont::Bold);
    return f;
}

// ── Construction / property setters ──────────────────────────────────────────

SyntaxHighlighter::SyntaxHighlighter(QObject *parent)
    : QSyntaxHighlighter(parent)
{}

void SyntaxHighlighter::setTextDocument(QQuickTextDocument *doc)
{
    if (m_quickDoc == doc)
        return;
    m_quickDoc = doc;
    setDocument(doc ? doc->textDocument() : nullptr);
    emit textDocumentChanged();
}

void SyntaxHighlighter::setLanguage(const QString &lang)
{
    const QString l = lang.toLower();
    if (m_language == l)
        return;
    m_language = l;
    emit languageChanged();
    rebuildRules();
    if (document())
        rehighlight();
}

// ── Rule sets ─────────────────────────────────────────────────────────────────

void SyntaxHighlighter::rebuildRules()
{
    m_rules.clear();
    m_hasMultiLine = false;

    const QString &l = m_language;
    if (l == "c" || l == "cpp" || l == "cc" || l == "cxx" || l == "h" || l == "hpp" || l == "hxx")
        setupCpp();
    else if (l == "py" || l == "pyw")
        setupPython();
    else if (l == "js" || l == "mjs" || l == "cjs" ||
             l == "ts" || l == "tsx" || l == "jsx")
        setupJavaScript();
    else if (l == "qml")
        setupQml();
    else if (l == "json" || l == "jsonc")
        setupJson();
    else if (l == "sh" || l == "bash" || l == "zsh" || l == "ksh" || l == "fish")
        setupShell();
    else if (l == "md" || l == "markdown" || l == "mdx")
        setupMarkdown();
    // For all other file types, no rules → plain text (no recolouring)
}

void SyntaxHighlighter::setupCpp()
{
    // Numbers
    m_rules.append({QRegularExpression(
        R"(\b(0x[0-9a-fA-F']+[uUlL]*|0b[01']+[uUlL]*|\d[\d']*\.?[\d']*(?:[eE][+-]?[\d']+)?[fFlLuU]*)\b)"),
        fmt(Color::Number)});

    // Preprocessor directives
    m_rules.append({QRegularExpression(R"(^\s*#\s*\w+)"), fmt(Color::Preproc)});

    // Keywords
    m_rules.append({QRegularExpression(
        R"(\b(alignas|alignof|asm|auto|bool|break|case|catch|char|char8_t|char16_t|char32_t|class|)"
        R"(concept|const|consteval|constexpr|constinit|const_cast|continue|co_await|co_return|co_yield|)"
        R"(decltype|default|delete|do|double|dynamic_cast|else|enum|explicit|export|extern|false|float|)"
        R"(for|friend|goto|if|inline|int|long|mutable|namespace|new|noexcept|nullptr|operator|override|)"
        R"(final|private|protected|public|register|reinterpret_cast|requires|return|short|signed|sizeof|)"
        R"(static|static_assert|static_cast|struct|switch|template|this|thread_local|throw|true|try|)"
        R"(typedef|typeid|typename|union|unsigned|using|virtual|void|volatile|wchar_t|while)\b)"),
        fmt(Color::Keyword)});

    // Common Qt / stdlib type names
    m_rules.append({QRegularExpression(
        R"(\b(Q[A-Z]\w*|std::\w+|size_t|ptrdiff_t|int8_t|int16_t|int32_t|int64_t|)"
        R"(uint8_t|uint16_t|uint32_t|uint64_t|string|vector|map|set|list|deque|)"
        R"(unordered_map|unordered_set|optional|variant|tuple|pair|shared_ptr|unique_ptr|weak_ptr)\b)"),
        fmt(Color::Type)});

    // String and character literals
    m_rules.append({QRegularExpression(
        R"("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*')"),
        fmt(Color::String)});

    // Single-line comment (must come after strings so // inside a string is fine)
    m_rules.append({QRegularExpression(R"(//[^\n]*)"), fmt(Color::Comment)});

    // Function / method calls
    m_rules.append({QRegularExpression(R"(\b([a-zA-Z_]\w*)\s*(?=\())"), fmt(Color::Function)});

    // Multi-line comment
    m_hasMultiLine      = true;
    m_mlCommentFmt      = fmt(Color::Comment);
    m_mlCommentStart    = QRegularExpression(R"(/\*)");
    m_mlCommentEnd      = QRegularExpression(R"(\*/)");
}

void SyntaxHighlighter::setupPython()
{
    // Numbers
    m_rules.append({QRegularExpression(
        R"(\b(0x[0-9a-fA-F_]+|0b[01_]+|0o[0-7_]+|\d[\d_]*\.?[\d_]*(?:[eE][+-]?\d+)?[jJ]?)\b)"),
        fmt(Color::Number)});

    // Decorators
    m_rules.append({QRegularExpression(R"(@[a-zA-Z_][\w.]*)"), fmt(Color::Preproc)});

    // Keywords
    m_rules.append({QRegularExpression(
        R"(\b(False|None|True|and|as|assert|async|await|break|class|continue|def|del|elif|)"
        R"(else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|)"
        R"(raise|return|try|while|with|yield)\b)"),
        fmt(Color::Keyword)});

    // Built-in functions
    m_rules.append({QRegularExpression(
        R"(\b(abs|all|any|bin|bool|bytes|callable|chr|dict|dir|divmod|enumerate|eval|exec|)"
        R"(filter|float|format|frozenset|getattr|globals|hasattr|hash|help|hex|id|input|int|)"
        R"(isinstance|issubclass|iter|len|list|locals|map|max|min|next|object|oct|open|ord|)"
        R"(pow|print|property|range|repr|reversed|round|set|setattr|slice|sorted|staticmethod|)"
        R"(str|sum|super|tuple|type|vars|zip)\b)"),
        fmt(Color::Builtin)});

    // Triple-quoted strings (single-line match — block-state handling omitted for simplicity)
    m_rules.append({QRegularExpression(R"("""[^"\\]*(?:\\.[^"\\]*)*"""|'{3}[^'\\]*(?:\\.[^'\\]*)*'{3})"),
        fmt(Color::String)});

    // Normal strings (including f-strings, r-strings, b-strings)
    m_rules.append({QRegularExpression(
        R"([frbuFRBU]*"[^"\\]*(?:\\.[^"\\]*)*"|[frbuFRBU]*'[^'\\]*(?:\\.[^'\\]*)*')"),
        fmt(Color::String)});

    // Comments
    m_rules.append({QRegularExpression(R"(#[^\n]*)"), fmt(Color::Comment)});

    // Function / class name after keyword
    m_rules.append({QRegularExpression(R"(\b(?:def|class)\s+([a-zA-Z_]\w*))"), fmt(Color::Function)});
}

void SyntaxHighlighter::setupJavaScript()
{
    // Numbers
    m_rules.append({QRegularExpression(
        R"(\b(0x[0-9a-fA-F_]+|0b[01_]+|0o[0-7_]+|\d[\d_]*\.?[\d_]*(?:[eE][+-]?\d+)?n?)\b)"),
        fmt(Color::Number)});

    // Keywords (ES2023 + TypeScript)
    m_rules.append({QRegularExpression(
        R"(\b(abstract|as|async|await|break|case|catch|class|const|constructor|continue|declare|)"
        R"(default|delete|do|else|enum|export|extends|false|finally|for|from|function|get|if|)"
        R"(implements|import|in|instanceof|interface|let|module|namespace|new|null|of|override|)"
        R"(package|private|protected|public|readonly|return|set|static|super|switch|this|throw|)"
        R"(true|try|type|typeof|undefined|using|var|void|while|with|yield)\b)"),
        fmt(Color::Keyword)});

    // Template literals
    m_rules.append({QRegularExpression(R"(`[^`\\]*(?:\\.[^`\\]*)*`)"), fmt(Color::String)});

    // Strings
    m_rules.append({QRegularExpression(
        R"("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*')"),
        fmt(Color::String)});

    // Single-line comment
    m_rules.append({QRegularExpression(R"(//[^\n]*)"), fmt(Color::Comment)});

    // Function / method calls
    m_rules.append({QRegularExpression(R"(\b([a-zA-Z_$][\w$]*)\s*(?=\())"), fmt(Color::Function)});

    // TypeScript type annotations after ':'
    m_rules.append({QRegularExpression(R"(:\s*([A-Z][a-zA-Z0-9_<>\[\]|&]*))"), fmt(Color::Type)});

    // Multi-line comment
    m_hasMultiLine   = true;
    m_mlCommentFmt   = fmt(Color::Comment);
    m_mlCommentStart = QRegularExpression(R"(/\*)");
    m_mlCommentEnd   = QRegularExpression(R"(\*/)");
}

void SyntaxHighlighter::setupQml()
{
    // Numbers
    m_rules.append({QRegularExpression(R"(\b\d+\.?\d*\b)"), fmt(Color::Number)});

    // import statement
    m_rules.append({QRegularExpression(R"(\bimport\b)"), fmt(Color::Preproc)});

    // id property
    m_rules.append({QRegularExpression(R"(\bid\s*:)"), fmt(Color::Builtin)});

    // Keywords
    m_rules.append({QRegularExpression(
        R"(\b(as|break|case|catch|continue|default|delete|do|else|false|finally|for|)"
        R"(function|if|in|instanceof|new|null|property|readonly|required|return|signal|)"
        R"(switch|this|throw|true|try|typeof|undefined|var|void|while|with|on|alias|let|const)\b)"),
        fmt(Color::Keyword)});

    // QML/C++ type names (Capital-letter identifiers before '{')
    m_rules.append({QRegularExpression(R"(\b([A-Z][a-zA-Z0-9_]*)\b)"), fmt(Color::Type)});

    // Primitive QML types
    m_rules.append({QRegularExpression(
        R"(\b(int|real|bool|string|color|url|date|var|list|point|size|rect)\b)"),
        fmt(Color::Type)});

    // Property bindings — identifier before ':'
    m_rules.append({QRegularExpression(R"(\b([a-z][a-zA-Z0-9_]*)\s*:)"), fmt(Color::Builtin)});

    // Strings
    m_rules.append({QRegularExpression(
        R"("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*')"),
        fmt(Color::String)});

    // Single-line comment
    m_rules.append({QRegularExpression(R"(//[^\n]*)"), fmt(Color::Comment)});

    // Multi-line comment
    m_hasMultiLine   = true;
    m_mlCommentFmt   = fmt(Color::Comment);
    m_mlCommentStart = QRegularExpression(R"(/\*)");
    m_mlCommentEnd   = QRegularExpression(R"(\*/)");
}

void SyntaxHighlighter::setupJson()
{
    // Object keys: "key":
    m_rules.append({QRegularExpression(R"re("([^"\\]*)"\s*:)re"), fmt(Color::Builtin)});

    // String values
    m_rules.append({QRegularExpression(R"re("([^"\\]*(?:\\.[^"\\]*)*)")re"), fmt(Color::String)});

    // Numbers
    m_rules.append({QRegularExpression(R"(-?\b\d+\.?\d*(?:[eE][+-]?\d+)?\b)"), fmt(Color::Number)});

    // Keywords
    m_rules.append({QRegularExpression(R"(\b(true|false|null)\b)"), fmt(Color::Keyword)});
}

void SyntaxHighlighter::setupShell()
{
    // Numbers
    m_rules.append({QRegularExpression(R"(\b\d+\b)"), fmt(Color::Number)});

    // Variables: $VAR and ${VAR}
    m_rules.append({QRegularExpression(R"(\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?)"), fmt(Color::Builtin)});

    // Keywords
    m_rules.append({QRegularExpression(
        R"(\b(if|then|else|elif|fi|for|while|until|do|done|case|esac|in|function|)"
        R"(return|exit|break|continue|local|export|declare|readonly|shift|unset|trap|eval|exec|source)\b)"),
        fmt(Color::Keyword)});

    // Common shell built-ins
    m_rules.append({QRegularExpression(
        R"(\b(echo|printf|cd|ls|pwd|mkdir|rm|cp|mv|cat|grep|sed|awk|find|chmod|chown|kill|ps|env|read|test|true|false)\b)"),
        fmt(Color::Type)});

    // Strings
    m_rules.append({QRegularExpression(
        R"("[^"\\]*(?:\\.[^"\\]*)*"|'[^']*')"),
        fmt(Color::String)});

    // Comments
    m_rules.append({QRegularExpression(R"(#[^\n]*)"), fmt(Color::Comment)});
}

void SyntaxHighlighter::setupMarkdown()
{
    // ATX headings (# ... ###### ...)
    m_rules.append({QRegularExpression(R"(^#{1,6}\s+.*)"), fmt(Color::Keyword, true)});

    // Fenced code blocks opening/closing fence
    m_rules.append({QRegularExpression(R"(^```\w*)"), fmt(Color::Preproc)});

    // Inline code
    m_rules.append({QRegularExpression(R"(`[^`]+`)"), fmt(Color::String)});

    // Bold **text** or __text__
    m_rules.append({QRegularExpression(R"(\*\*[^*]+\*\*|__[^_]+__)"),
        []{QTextCharFormat f; f.setFontWeight(QFont::Bold); return f;}()});

    // Italic *text* or _text_ (not inside bold markers)
    m_rules.append({QRegularExpression(R"((?<!\*)\*[^*]+\*(?!\*)|(?<!_)_[^_]+_(?!_))"),
        []{QTextCharFormat f; f.setFontItalic(true); return f;}()});

    // Links: [text](url)
    m_rules.append({QRegularExpression(R"(\[[^\]]*\]\([^\)]*\))"), fmt(Color::Builtin)});

    // Blockquote
    m_rules.append({QRegularExpression(R"(^>\s*.*)"), fmt(Color::Comment)});

    // Horizontal rule
    m_rules.append({QRegularExpression(R"(^[-*_]{3,}\s*$)"), fmt(Color::Comment)});
}

// ── Core highlight routine ────────────────────────────────────────────────────

void SyntaxHighlighter::highlightBlock(const QString &text)
{
    // Apply single-line rules in order
    for (const auto &rule : m_rules) {
        auto it = rule.pattern.globalMatch(text);
        while (it.hasNext()) {
            const auto m = it.next();
            setFormat(m.capturedStart(), m.capturedLength(), rule.format);
        }
    }

    if (!m_hasMultiLine) {
        setCurrentBlockState(0);
        return;
    }

    // Multi-line comment: state 1 = inside comment
    setCurrentBlockState(0);

    int startIdx = 0;
    if (previousBlockState() != 1) {
        auto m = m_mlCommentStart.match(text);
        startIdx = m.capturedStart();
    }

    while (startIdx >= 0) {
        auto endMatch = m_mlCommentEnd.match(text, startIdx);
        int endIdx    = endMatch.capturedStart();
        int len;

        if (endIdx < 0) {
            setCurrentBlockState(1);          // still inside comment on next line
            len = text.length() - startIdx;
        } else {
            len = endIdx - startIdx + endMatch.capturedLength();
        }

        setFormat(startIdx, len, m_mlCommentFmt);

        auto next = m_mlCommentStart.match(text, startIdx + len);
        startIdx  = next.capturedStart();
    }
}
