#include "CodeMigrationTool.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDirIterator>
#include <QRegularExpression>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>

CodeMigrationTool::CodeMigrationTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
}

CodeMigrationTool::~CodeMigrationTool() = default;

QString CodeMigrationTool::name() const
{
    return QStringLiteral("code_migration");
}

QString CodeMigrationTool::description() const
{
    return QStringLiteral("Large-scale code migration and refactoring (find/replace, API migration, import updates)");
}

QJsonObject CodeMigrationTool::parametersSchema() const
{
    QJsonObject schema;
    schema[QStringLiteral("action")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Action: find_and_replace, migrate_imports, migrate_api_calls")},
        {QStringLiteral("enum"), QJsonArray{
            QStringLiteral("find_and_replace"),
            QStringLiteral("migrate_imports"),
            QStringLiteral("migrate_api_calls")
        }}
    };
    
    schema[QStringLiteral("directory")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Root directory for migration")}
    };
    
    schema[QStringLiteral("pattern")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Search pattern (regex or literal text)")}
    };
    
    schema[QStringLiteral("replacement")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Replacement text")}
    };
    
    schema[QStringLiteral("file_pattern")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("File glob pattern (e.g., '*.js', '*.ts')")}
    };
    
    schema[QStringLiteral("dry_run")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("boolean")},
        {QStringLiteral("description"), QStringLiteral("Preview changes without applying (default: true)")}
    };
    
    schema[QStringLiteral("use_regex")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("boolean")},
        {QStringLiteral("description"), QStringLiteral("Use regular expression for pattern (default: false)")}
    };
    
    return schema;
}

ToolResult CodeMigrationTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();
    
    const QString action = args.value(QStringLiteral("action")).toString();
    const QString directory = args.value(QStringLiteral("directory")).toString();
    
    if (action == QStringLiteral("find_and_replace")) {
        const QString pattern = args.value(QStringLiteral("pattern")).toString();
        const QString replacement = args.value(QStringLiteral("replacement")).toString();
        const QString filePattern = args.value(QStringLiteral("file_pattern")).toString(QStringLiteral("*"));
        const bool dryRun = args.value(QStringLiteral("dry_run")).toBool(true);
        const bool useRegex = args.value(QStringLiteral("use_regex")).toBool(false);
        
        if (directory.isEmpty() || pattern.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: directory and pattern are required");
            return result;
        }
        
        const QJsonObject response = findAndReplace(directory, pattern, replacement, filePattern, dryRun, useRegex);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("migrate_imports")) {
        const QString oldPath = args.value(QStringLiteral("pattern")).toString();  // Use pattern for oldPath
        const QString newPath = args.value(QStringLiteral("replacement")).toString();
        const QString filePattern = args.value(QStringLiteral("file_pattern")).toString(QStringLiteral("*"));
        
        if (directory.isEmpty() || oldPath.isEmpty() || newPath.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: directory, oldPath (pattern), and newPath (replacement) are required");
            return result;
        }
        
        const QJsonObject response = migrateImports(directory, oldPath, newPath, filePattern);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("migrate_api_calls")) {
        const QJsonObject mappings = args.value(QStringLiteral("mappings")).toObject();
        const QString filePattern = args.value(QStringLiteral("file_pattern")).toString(QStringLiteral("*"));
        
        if (directory.isEmpty() || mappings.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: directory and mappings are required");
            return result;
        }
        
        const QJsonObject response = migrateApiCalls(directory, mappings, filePattern);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
    }
    
    result.isError = true;
    result.content = QStringLiteral("Error: Unknown action: %1").arg(action);
    return result;
}

QString CodeMigrationTool::summary(const QJsonObject &args) const
{
    const QString action = args.value(QStringLiteral("action")).toString();
    
    if (action == QStringLiteral("find_and_replace")) {
        return QStringLiteral("Migrate: Find '%1' -> Replace '%2'")
            .arg(args.value(QStringLiteral("pattern")).toString().left(30),
                 args.value(QStringLiteral("replacement")).toString().left(30));
    } else if (action == QStringLiteral("migrate_imports")) {
        return QStringLiteral("Migrate imports: %1 -> %2")
            .arg(args.value(QStringLiteral("pattern")).toString(),
                 args.value(QStringLiteral("replacement")).toString());
    }
    
    return action;
}

QJsonObject CodeMigrationTool::findAndReplace(const QString &directory, const QString &pattern,
                                               const QString &replacement, const QString &filePattern,
                                               bool dryRun, bool useRegex)
{
    QJsonObject result;
    QJsonArray changes;
    int filesMatched = 0;
    int replacementsCount = 0;
    
    // 构建文件模式匹配器
    QString fPattern = filePattern;
    QRegularExpression fileRegex(QStringLiteral(".*") + fPattern.replace('*', QStringLiteral(".*")) + '$');

    QDirIterator it(directory, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        
        if (!it.fileInfo().isFile()) continue;
        if (!fileRegex.match(it.fileName()).hasMatch()) continue;
        
        // 读取文件
        QFile file(it.filePath());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        
        QString content = QString::fromUtf8(file.readAll());
        file.close();
        
        // 执行替换
        QString modified = content;
        int count = 0;
        
        if (useRegex) {
            QRegularExpression regex(pattern);
            if (regex.isValid()) {
                QStringList lines = modified.split('\n');
                for (QString &line : lines) {
                    int beforeLen = line.length();
                    line.replace(regex, replacement);
                    if (line.length() != beforeLen) {
                        count++;
                    }
                }
                modified = lines.join('\n');
            }
        } else {
            // 字面量替换
            count = modified.count(pattern);
            modified.replace(pattern, replacement);
        }
        
        if (count > 0) {
            filesMatched++;
            replacementsCount += count;
            
            if (!dryRun) {
                // 写回文件
                if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                    QTextStream out(&file);
                    out << modified;
                    file.close();
                }
            }
            
            // 记录变更
            QJsonObject change;
            change[QStringLiteral("file")] = it.filePath();
            change[QStringLiteral("replacements")] = count;
            change[QStringLiteral("applied")] = !dryRun;
            changes.append(change);
        }
    }
    
    result[QStringLiteral("pattern")] = pattern;
    result[QStringLiteral("replacement")] = replacement;
    result[QStringLiteral("files_matched")] = filesMatched;
    result[QStringLiteral("total_replacements")] = replacementsCount;
    result[QStringLiteral("dry_run")] = dryRun;
    result[QStringLiteral("changes")] = changes;
    
    return result;
}

QJsonObject CodeMigrationTool::migrateImports(const QString &directory, const QString &oldPath,
                                               const QString &newPath, const QString &filePattern)
{
    QJsonObject result;
    QJsonArray changes;
    
    // 构建导入模式
    const QString importPatterns[] = {
        QStringLiteral("import.*from ['\"]%1['\"]"),
        QStringLiteral("require(['\"]%1['\"])"),
        QStringLiteral("import.*['\"]%1['\"]")
    };
    
    QDirIterator it(directory, {filePattern}, QDir::Files, QDirIterator::Subdirectories);
    int filesUpdated = 0;
    
    while (it.hasNext()) {
        it.next();
        
        QFile file(it.filePath());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        
        QString content = QString::fromUtf8(file.readAll());
        file.close();
        
        QString modified = content;
        int replacements = 0;
        
        for (const QString &pattern : importPatterns) {
            QRegularExpression regex(pattern.arg(QRegularExpression::escape(oldPath)));
            if (regex.isValid()) {
                const QString oldMatch = modified;
                modified.replace(regex, pattern.arg(newPath));
                replacements += (oldMatch.count(oldPath) - modified.count(oldPath));
            }
        }
        
        if (replacements > 0) {
            filesUpdated++;
            
            // 写回文件
            if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                QTextStream out(&file);
                out << modified;
                file.close();
            }
            
            QJsonObject change;
            change[QStringLiteral("file")] = it.filePath();
            change[QStringLiteral("replacements")] = replacements;
            changes.append(change);
        }
    }
    
    result[QStringLiteral("old_path")] = oldPath;
    result[QStringLiteral("new_path")] = newPath;
    result[QStringLiteral("files_updated")] = filesUpdated;
    result[QStringLiteral("changes")] = changes;
    
    return result;
}

QJsonObject CodeMigrationTool::migrateApiCalls(const QString &directory, const QJsonObject &mappings,
                                                const QString &filePattern)
{
    QJsonObject result;
    QJsonArray changes;
    int filesModified = 0;
    int totalReplacements = 0;
    
    QDirIterator it(directory, {filePattern}, QDir::Files, QDirIterator::Subdirectories);
    
    while (it.hasNext()) {
        it.next();
        
        QFile file(it.filePath());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        
        QString content = QString::fromUtf8(file.readAll());
        file.close();
        
        QString modified = content;
        int fileReplacements = 0;
        
        // 应用所有 API 映射
        for (auto it = mappings.begin(); it != mappings.end(); ++it) {
            const QString oldApi = it.key();
            const QString newApi = it.value().toString();
            
            const int beforeCount = modified.count(oldApi);
            modified.replace(oldApi, newApi);
            const int afterCount = modified.count(newApi);
            
            fileReplacements += beforeCount;
        }
        
        if (fileReplacements > 0) {
            filesModified++;
            totalReplacements += fileReplacements;
            
            // 写回文件
            if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                QTextStream out(&file);
                out << modified;
                file.close();
            }
            
            QJsonObject change;
            change[QStringLiteral("file")] = it.filePath();
            change[QStringLiteral("replacements")] = fileReplacements;
            changes.append(change);
        }
    }
    
    result[QStringLiteral("files_modified")] = filesModified;
    result[QStringLiteral("total_replacements")] = totalReplacements;
    result[QStringLiteral("mappings_count")] = mappings.size();
    result[QStringLiteral("changes")] = changes;
    
    return result;
}

QString CodeMigrationTool::generateMigrationReport(const QJsonArray &changes)
{
    QString report;
    QTextStream stream(&report);
    
    stream << QStringLiteral("Migration Report\n");
    stream << QStringLiteral("================\n\n");
    
    stream << QStringLiteral("Total files modified: ") << changes.size() << '\n';
    
    for (const QJsonValue &val : changes) {
        const QJsonObject change = val.toObject();
        stream << QStringLiteral("\n  File: ") << change.value(QStringLiteral("file")).toString() << '\n';
        stream << QStringLiteral("  Replacements: ") << change.value(QStringLiteral("replacements")).toInt() << '\n';
    }
    
    return report;
}

bool CodeMigrationTool::applyChanges(const QJsonArray &changes)
{
    // 已在执行中应用
    return true;
}
