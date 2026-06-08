#include "PatchGeneratorTool.h"
#include <QFile>
#include <QTextStream>
#include <QStringList>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QDateTime>

PatchGeneratorTool::PatchGeneratorTool(QObject *parent)
    : BaseTool(parent)
{
}

PatchGeneratorTool::~PatchGeneratorTool() = default;

QString PatchGeneratorTool::name() const
{
    return QStringLiteral("patch_generator");
}

QString PatchGeneratorTool::description() const
{
    return QStringLiteral("Generate unified diff patches between files or directories");
}

QJsonObject PatchGeneratorTool::parametersSchema() const
{
    QJsonObject schema;
    schema[QStringLiteral("action")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Action: generate_diff, generate_dir_patch, validate_patch")},
        {QStringLiteral("enum"), QJsonArray{
            QStringLiteral("generate_diff"),
            QStringLiteral("generate_dir_patch"),
            QStringLiteral("validate_patch")
        }}
    };
    
    schema[QStringLiteral("original_file")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Path to original file")}
    };
    
    schema[QStringLiteral("modified_file")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Path to modified file")}
    };
    
    schema[QStringLiteral("output_patch")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Output patch file path (optional)")}
    };
    
    schema[QStringLiteral("context_lines")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("integer")},
        {QStringLiteral("description"), QStringLiteral("Number of context lines (default: 3)")},
        {QStringLiteral("default"), 3}
    };
    
    schema[QStringLiteral("patch_content")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Patch content to validate")}
    };
    
    return schema;
}

ToolResult PatchGeneratorTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();
    
    const QString action = args.value(QStringLiteral("action")).toString();
    int contextLines = args.value(QStringLiteral("context_lines")).toInt(3);
    
    if (action == QStringLiteral("generate_diff")) {
        const QString originalFile = args.value(QStringLiteral("original_file")).toString();
        const QString modifiedFile = args.value(QStringLiteral("modified_file")).toString();
        const QString outputPatch = args.value(QStringLiteral("output_patch")).toString();
        
        if (originalFile.isEmpty() || modifiedFile.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: original_file and modified_file are required");
            return result;
        }
        
        const QString patch = generateUnifiedDiff(originalFile, modifiedFile, contextLines);
        
        if (!outputPatch.isEmpty()) {
            QFile patchFile(outputPatch);
            if (!patchFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
                result.isError = true;
                result.content = QStringLiteral("Error: Cannot write to %1").arg(outputPatch);
                return result;
            }
            QTextStream out(&patchFile);
            out << patch;
            patchFile.close();
        }
        
        QJsonObject resp;
        resp[QStringLiteral("patch")] = patch;
        resp[QStringLiteral("lines")] = patch.split('\n').length();
        resp[QStringLiteral("saved")] = !outputPatch.isEmpty();
        result.content = QJsonDocument(resp).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("generate_dir_patch")) {
        const QString originalDir = args.value(QStringLiteral("original_file")).toString();
        const QString modifiedDir = args.value(QStringLiteral("modified_file")).toString();
        const QString outputPatch = args.value(QStringLiteral("output_patch")).toString();
        
        if (originalDir.isEmpty() || modifiedDir.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: original_file and modified_file (as directories) are required");
            return result;
        }
        
        const QString patch = generateDirectoryPatch(originalDir, modifiedDir, contextLines);
        
        if (!outputPatch.isEmpty()) {
            QFile patchFile(outputPatch);
            if (!patchFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
                result.isError = true;
                result.content = QStringLiteral("Error: Cannot write to %1").arg(outputPatch);
                return result;
            }
            QTextStream out(&patchFile);
            out << patch;
            patchFile.close();
        }
        
        QJsonObject resp;
        resp[QStringLiteral("patch")] = patch;
        resp[QStringLiteral("lines")] = patch.split('\n').length();
        result.content = QJsonDocument(resp).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("validate_patch")) {
        const QString patchContent = args.value(QStringLiteral("patch_content")).toString();
        
        if (patchContent.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: patch_content is required");
            return result;
        }
        
        const bool isValid = validatePatch(patchContent);
        
        QJsonObject resp;
        resp[QStringLiteral("valid")] = isValid;
        resp[QStringLiteral("format")] = QStringLiteral("unified");
        result.content = QJsonDocument(resp).toJson(QJsonDocument::Compact);
        return result;
    }
    
    result.isError = true;
    result.content = QStringLiteral("Error: Unknown action: %1").arg(action);
    return result;
}

QString PatchGeneratorTool::summary(const QJsonObject &args) const
{
    const QString action = args.value(QStringLiteral("action")).toString();
    
    if (action == QStringLiteral("generate_diff")) {
        return QStringLiteral("Generate diff patch between %1 and %2")
            .arg(args.value(QStringLiteral("original_file")).toString(),
                 args.value(QStringLiteral("modified_file")).toString());
    } else if (action == QStringLiteral("validate_patch")) {
        return QStringLiteral("Validate patch format");
    }
    
    return action;
}

QString PatchGeneratorTool::generateUnifiedDiff(const QString &originalFile, const QString &modifiedFile, int contextLines)
{
    QFile origFile(originalFile);
    if (!origFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }
    
    QFile modFile(modifiedFile);
    if (!modFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        origFile.close();
        return QString();
    }
    
    const QStringList originalLines = QString(origFile.readAll()).split('\n');
    const QStringList modifiedLines = QString(modFile.readAll()).split('\n');
    
    origFile.close();
    modFile.close();
    
    return generateDiffFromStrings(originalLines.join('\n'), modifiedLines.join('\n'), contextLines);
}

QString PatchGeneratorTool::generateDiffFromStrings(const QString &original, const QString &modified, int contextLines)
{
    const QStringList originalLines = original.split('\n');
    const QStringList modifiedLines = modified.split('\n');
    
    QString patch;
    QTextStream stream(&patch);
    
    // 写入补丁头部
    stream << QStringLiteral("--- a/original\n");
    stream << QStringLiteral("+++ b/modified\n");
    
    // 简单的行差异计算
    int i = 0, j = 0;
    
    while (i < originalLines.length() || j < modifiedLines.length()) {
        // 如果行相同，输出作为上下文
        if (i < originalLines.length() && j < modifiedLines.length() 
            && originalLines[i] == modifiedLines[j]) {
            stream << QStringLiteral(" ") << originalLines[i] << '\n';
            i++;
            j++;
        } else {
            // 输出删除的行
            if (i < originalLines.length()) {
                stream << QStringLiteral("-") << originalLines[i] << '\n';
                i++;
            }
            // 输出添加的行
            if (j < modifiedLines.length() && (i >= originalLines.length() 
                || originalLines[i] != modifiedLines[j])) {
                stream << QStringLiteral("+") << modifiedLines[j] << '\n';
                j++;
            }
        }
    }
    
    return patch;
}

QString PatchGeneratorTool::generateDirectoryPatch(const QString &originalDir, const QString &modifiedDir, int contextLines)
{
    QString patch;
    QTextStream stream(&patch);
    
    stream << QStringLiteral("# Directory patch generated at ") << QDateTime::currentDateTime().toString() << '\n';
    stream << QStringLiteral("# From: ") << originalDir << '\n';
    stream << QStringLiteral("# To: ") << modifiedDir << '\n';
    stream << '\n';
    
    // 递归扫描两个目录
    QDirIterator origIter(originalDir, QDirIterator::Subdirectories);
    QDirIterator modIter(modifiedDir, QDirIterator::Subdirectories);
    
    // 收集所有文件
    QStringList origFiles, modFiles;
    
    while (origIter.hasNext()) {
        origIter.next();
        if (origIter.fileInfo().isFile()) {
            origFiles.append(origIter.filePath());
        }
    }
    
    while (modIter.hasNext()) {
        modIter.next();
        if (modIter.fileInfo().isFile()) {
            modFiles.append(modIter.filePath());
        }
    }
    
    // 比较每对文件
    for (const QString &modFile : modFiles) {
        const QString relativePath = modFile.mid(modifiedDir.length());
        const QString origFile = originalDir + relativePath;
        
        if (QFile::exists(origFile)) {
            stream << generateUnifiedDiff(origFile, modFile, contextLines);
            stream << '\n';
        } else {
            stream << QStringLiteral("# New file: ") << relativePath << '\n';
        }
    }
    
    return patch;
}

QStringList PatchGeneratorTool::computeLineDifferences(const QStringList &originalLines, const QStringList &modifiedLines)
{
    QStringList result;
    
    // 简单的行比对（LCS 简化版）
    int i = 0, j = 0;
    
    while (i < originalLines.length() || j < modifiedLines.length()) {
        if (i < originalLines.length() && j < modifiedLines.length() 
            && originalLines[i] == modifiedLines[j]) {
            // 行相同
            result.append(QStringLiteral(" ") + originalLines[i]);
            i++;
            j++;
        } else if (i < originalLines.length()) {
            // 原文件有，修改文件没有
            result.append(QStringLiteral("-") + originalLines[i]);
            i++;
        } else {
            // 修改文件有，原文件没有
            result.append(QStringLiteral("+") + modifiedLines[j]);
            j++;
        }
    }
    
    return result;
}

bool PatchGeneratorTool::validatePatch(const QString &patchContent)
{
    // 检查是否包含标准 unified diff 标记
    if (!patchContent.contains(QStringLiteral("---")) || !patchContent.contains(QStringLiteral("+++"))) {
        return false;
    }
    
    const QStringList lines = patchContent.split('\n');
    for (const QString &line : lines) {
        if (line.startsWith(QStringLiteral("-")) && !line.startsWith(QStringLiteral("---"))) {
            continue;  // 删除行
        } else if (line.startsWith(QStringLiteral("+"))) {
            if (!line.startsWith(QStringLiteral("+++"))) {
                continue;  // 添加行
            }
        } else if (line.startsWith(' ') || line.startsWith('@')) {
            continue;  // 上下文行或段头
        }
    }
    
    return true;
}
