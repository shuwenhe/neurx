#include "editor/SnippetManager.h"
#include <QDebug>
#include <QDate>

SnippetManager::SnippetManager(QObject* parent)
    : QObject(parent)
{
    initializeBuiltInSnippets();
}

void SnippetManager::initializeBuiltInSnippets()
{
    // C++ snippets
    m_snippets["cpp"].append({
        "cpp_main", "main",
        {
            "#include <iostream>",
            "using namespace std;",
            "",
            "int main() {",
            "    ${1:// code here}",
            "    return 0;",
            "}"
        },
        "C++ main function"
    });
    
    m_snippets["cpp"].append({
        "cpp_for", "for",
        {
            "for (int i = 0; i < ${1:10}; ++i) {",
            "    ${2:// code}",
            "}"
        },
        "For loop"
    });
    
    m_snippets["cpp"].append({
        "cpp_ifelse", "ifelse",
        {
            "if (${1:condition}) {",
            "    ${2:// true branch}",
            "} else {",
            "    ${3:// false branch}",
            "}"
        },
        "If-else statement"
    });
    
    // Python snippets
    m_snippets["python"].append({
        "py_main", "main",
        {
            "def main():",
            "    ${1:pass}",
            "",
            "if __name__ == '__main__':",
            "    main()"
        },
        "Python main function"
    });
    
    m_snippets["python"].append({
        "py_for", "for",
        {
            "for ${1:item} in ${2:iterable}:",
            "    ${3:pass}"
        },
        "Python for loop"
    });
    
    // JavaScript snippets
    m_snippets["javascript"].append({
        "js_function", "function",
        {
            "function ${1:name}(${2:args}) {",
            "    ${3:// code}",
            "}"
        },
        "JavaScript function"
    });
    
    m_snippets["javascript"].append({
        "js_arrow", "arrow",
        {
            "const ${1:name} = (${2:args}) => {",
            "    ${3:// code}",
            "};"
        },
        "Arrow function"
    });
}

void SnippetManager::loadSnippets(const QString& language)
{
    qDebug() << "Load snippets for" << language;
    if (m_snippets.contains(language)) {
        emit snippetsLoaded(language, m_snippets[language].size());
    }
}

void SnippetManager::registerSnippet(const Snippet& snippet)
{
    m_snippets[snippet.language].append(snippet);
    qDebug() << "Registered snippet:" << snippet.id;
}

void SnippetManager::unregisterSnippet(const QString& snippetId)
{
    for (auto& snippets : m_snippets) {
        snippets.removeIf([&](const Snippet& s) { return s.id == snippetId; });
    }
}

QList<Snippet> SnippetManager::getSnippets(const QString& language) const
{
    return m_snippets.value(language);
}

Snippet SnippetManager::getSnippet(const QString& prefix, const QString& language) const
{
    auto snippets = m_snippets.value(language);
    for (const auto& snippet : snippets) {
        if (snippet.prefix == prefix) {
            return snippet;
        }
    }
    return {};
}

QList<Snippet> SnippetManager::findSnippets(const QString& query) const
{
    QList<Snippet> results;
    QString lowerQuery = query.toLower();
    
    for (const auto& snippets : m_snippets) {
        for (const auto& snippet : snippets) {
            if (snippet.prefix.toLower().contains(lowerQuery) ||
                snippet.description.toLower().contains(lowerQuery)) {
                results.append(snippet);
            }
        }
    }
    
    return results;
}

void SnippetManager::insertSnippet(const Snippet& snippet, int line, int column)
{
    qDebug() << "Insert snippet" << snippet.id << "at" << line << ":" << column;
    emit snippetInserted(line, column);
}

QString SnippetManager::resolveVariables(const QString& snippet)
{
    QString result = snippet;
    
    // Replace date variables
    result.replace("${TM_DATE}", QDate::currentDate().toString("yyyy-MM-dd"));
    result.replace("${TM_YEAR}", QString::number(QDate::currentDate().year()));
    result.replace("${TM_FILENAME}", "");
    result.replace("${CLIPBOARD}", "");
    
    return result;
}

void SnippetManager::selectNextPlaceholder()
{
    qDebug() << "Select next placeholder";
}

void SnippetManager::selectPreviousPlaceholder()
{
    qDebug() << "Select previous placeholder";
}
