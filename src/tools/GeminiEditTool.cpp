#include "GeminiEditTool.h"
#include "agent/JitContext.h"
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>

GeminiEditTool::GeminiEditTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
}

QString GeminiEditTool::name() const
{
    return "gemini_edit";
}

QString GeminiEditTool::description() const
{
    return "Robust file editing via string replacement. Supports whitespace-insensitive matching.";
}

QJsonObject GeminiEditTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject filePathProp;
    filePathProp["type"] = "string";
    filePathProp["description"] = "The path of the file to edit.";
    properties["file_path"] = filePathProp;
    
    QJsonObject oldStringProp;
    oldStringProp["type"] = "string";
    oldStringProp["description"] = "The text to replace. Can be slightly different in whitespace/indentation.";
    properties["old_string"] = oldStringProp;
    
    QJsonObject newStringProp;
    newStringProp["type"] = "string";
    newStringProp["description"] = "The replacement text.";
    properties["new_string"] = newStringProp;
    
    QJsonObject allowMultipleProp;
    allowMultipleProp["type"] = "boolean";
    allowMultipleProp["description"] = "If true, replace all matches. If false, fail unless exactly one match is found.";
    allowMultipleProp["default"] = false;
    properties["allow_multiple"] = allowMultipleProp;
    
    schema["properties"] = properties;
    
    QJsonArray required;
    required.append("file_path");
    required.append("old_string");
    required.append("new_string");
    schema["required"] = required;
    
    return schema;
}

ToolResult GeminiEditTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString filePath = args["file_path"].toString();
    const QString oldString = args["old_string"].toString();
    const QString newString = args["new_string"].toString();
    const bool allowMultiple = args["allow_multiple"].toBool(false);

    if (filePath.isEmpty()) return {callId, name(), true, "Missing file_path."};

    QFile file(filePath);
    if (!file.exists()) return {callId, name(), true, "File not found: " + filePath};

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Failed to open file: " + file.errorString()};
    }

    QTextStream in(&file);
    const QString content = in.readAll();
    file.close();

    ToolResult res;
    res.callId = callId;
    res.name = name();
    res.isError = false;

    QString finalNewContent;
    int totalOccurrences = 0;
    QString strategy;

    // 1. Try Exact match first
    int count = content.count(oldString);
    if (count > 0) {
        if (!allowMultiple && count > 1) {
            return {callId, name(), true, QString("Found %1 exact matches, but allow_multiple is false.").arg(count)};
        }
        finalNewContent = content;
        finalNewContent.replace(oldString, newString);
        totalOccurrences = count;
        strategy = "exact";
    } else {
        // 2. Try Flexible match (whitespace-insensitive)
        int flexCount = 0;
        QString flexContent = applyFlexibleReplacement(content, oldString, newString, &flexCount);

        if (flexCount > 0) {
            if (!allowMultiple && flexCount > 1) {
                return {callId, name(), true, QString("Found %1 flexible matches, but allow_multiple is false.").arg(flexCount)};
            }
            finalNewContent = flexContent;
            totalOccurrences = flexCount;
            strategy = "flexible";
        } else {
            // 3. Try Regex match
            int regCount = 0;
            QString regContent = applyRegexReplacement(content, oldString, newString, &regCount, allowMultiple);

            if (regCount > 0) {
                if (!allowMultiple && regCount > 1) {
                    return {callId, name(), true, QString("Found %1 regex matches, but allow_multiple is false.").arg(regCount)};
                }
                finalNewContent = regContent;
                totalOccurrences = regCount;
                strategy = "regex";
            }
        }
    }

    if (totalOccurrences > 0) {
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            return {callId, name(), true, "Failed to write file: " + file.errorString()};
        }
        QTextStream out(&file);
        out << finalNewContent;
        file.close();

        QString message = QString("Successfully applied %1 %2 replacement(s) to %3.")
                .arg(totalOccurrences).arg(strategy).arg(filePath);

        // Append JIT context if available
        QString jit = JitContext::discoverContext(filePath, m_workspaceRoot);
        if (!jit.isEmpty()) {
            message = JitContext::appendJitContext(message, jit);
        }

        return {callId, name(), false, message};
    }

    return {callId, name(), true, "Could not find old_string in file (no exact, flexible, or regex matches)."};
}

QString GeminiEditTool::stripLine(const QString &line)
{
    return line.trimmed().simplified().replace(" ", "");
}

QString GeminiEditTool::applyFlexibleReplacement(const QString &content, const QString &oldString, const QString &newString, int *occurrences)
{
    QStringList sourceLines = content.split('\n');
    QStringList searchLines = oldString.split('\n');

    if (searchLines.isEmpty()) return content;

    QString result;
    int i = 0;
    int foundCount = 0;

    while (i < sourceLines.size()) {
        bool match = false;
        if (i + searchLines.size() <= sourceLines.size()) {
            match = true;
            for (int j = 0; j < searchLines.size(); ++j) {
                if (stripLine(sourceLines[i + j]) != stripLine(searchLines[j])) {
                    match = false;
                    break;
                }
            }
        }

        if (match) {
            foundCount++;
            // Preserve indentation of the first line
            QRegularExpression indentRx("^(\\s*)");
            auto matchObj = indentRx.match(sourceLines[i]);
            QString indentation = matchObj.captured(1);

            QStringList replacementLines = newString.split('\n');
            for (int k = 0; k < replacementLines.size(); ++k) {
                result += indentation + replacementLines[k].trimmed() + "\n";
            }
            i += searchLines.size();
        } else {
            result += sourceLines[i] + "\n";
            i++;
        }
    }

    // Remote trailing newline added by loop if content didn't have it
    if (!content.endsWith('\n') && result.endsWith('\n')) {
        result.chop(1);
    }

    *occurrences = foundCount;
    return result;
}

QString GeminiEditTool::escapeRegex(const QString &str)
{
    QString escaped = str;
    static const QRegularExpression specialChars("([\\.\\*\\+\\?\\^\\$\\(\\)\\[\\]\\{\\}\\>\\<\\=\\|\\\\])");
    escaped.replace(specialChars, "\\\\1"); // In Qt6 replace(regex, "\\1") works if it's a QRegularExpression
    // Wait, Qt's replace with regex is: escaped.replace(regex, "\\1");
    // Actually, simple way:
    return QRegularExpression::escape(str);
}

QStringList GeminiEditTool::applyIndentation(const QStringList &lines, const QString &targetIndentation)
{
    if (lines.isEmpty()) return {};

    QString refIndent;
    QRegularExpression indentRx("^([ \\t]*)");
    auto match = indentRx.match(lines[0]);
    if (match.hasMatch()) {
        refIndent = match.captured(1);
    }

    QStringList result;
    for (const QString &line : lines) {
        if (line.trimmed().isEmpty()) {
            result << "";
            continue;
        }
        if (line.startsWith(refIndent)) {
            result << targetIndentation + line.mid(refIndent.length());
        } else {
            result << targetIndentation + line.trimmed();
        }
    }
    return result;
}

QString GeminiEditTool::applyRegexReplacement(const QString &content, const QString &oldString, const QString &newString, int *occurrences, bool allowMultiple)
{
    QString processedSearch = oldString.trimmed();
    QStringList delimiters = {"(", ")", ":", "[", "]", "{", "}", ">", "<", "="};
    for (const QString &delim : delimiters) {
        processedSearch.replace(delim, " " + delim + " ");
    }

    QStringList tokens = processedSearch.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    if (tokens.isEmpty()) return content;

    QStringList escapedTokens;
    for (const QString &token : tokens) {
        escapedTokens << QRegularExpression::escape(token);
    }

    QString pattern = escapedTokens.join("\\s*");
    // Capture leading whitespace (indentation)
    QString finalPattern = "^([ \\t]*)" + pattern;

    QRegularExpression regex(finalPattern, QRegularExpression::MultilineOption);

    int count = 0;
    auto it = regex.globalMatch(content);
    while (it.hasNext()) {
        it.next();
        count++;
    }
    *occurrences = count;

    if (count == 0 || (!allowMultiple && count > 1)) {
        return content;
    }

    QStringList newLines = newString.split('\n');
    QString result = content;

    // Replace from bottom to top to avoid offset issues
    QList<QRegularExpressionMatch> matches;
    it = regex.globalMatch(content);
    while (it.hasNext()) {
        matches << it.next();
    }

    for (int i = matches.size() - 1; i >= 0; --i) {
        const auto &match = matches[i];
        QString indentation = match.captured(1);
        QString replacement = applyIndentation(newLines, indentation).join('\n');

        // Preserve trailing newline if match had it
        // and if it's not a new file (though applyRegexReplacement only for existing files)
        result.replace(match.capturedStart(), match.capturedLength(), replacement);
    }

    return result;
}
