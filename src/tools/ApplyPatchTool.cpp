#include "tools/ApplyPatchTool.h"

#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSet>
#include <QTextStream>

namespace {

struct PatchLine {
    QChar kind;
    QString text;
};

struct UpdateHunk {
    QString header;
    QList<PatchLine> lines;
    bool explicitEndOfFile{false};
};

struct PatchOperation {
    enum class Kind {
        Add,
        Delete,
        Update,
    };

    Kind kind{Kind::Add};
    QString path;
    QString moveTo;
    QStringList addedLines;
    QList<UpdateHunk> hunks;
};

struct VirtualFileState {
    bool loaded{false};
    bool exists{false};
    bool isDir{false};
    bool trailingNewline{false};
    QString content;
};

QString normalizeLineEndings(QString text)
{
    text.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    text.replace(QChar('\r'), QChar('\n'));
    return text;
}

QString readAllText(const QString &path, QString &error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        error = QStringLiteral("Cannot open %1: %2").arg(path, file.errorString());
        return {};
    }
    return QString::fromUtf8(file.readAll());
}

bool writeAllText(const QString &path, const QString &text, QString &error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        error = QStringLiteral("Cannot write %1: %2").arg(path, file.errorString());
        return false;
    }

    QTextStream out(&file);
    out << text;
    if (!file.commit()) {
        error = QStringLiteral("Failed to commit %1.").arg(path);
        return false;
    }
    return true;
}

QStringList splitLines(const QString &text, bool *trailingNewline)
{
    if (trailingNewline)
        *trailingNewline = text.endsWith(QLatin1Char('\n'));

    if (text.isEmpty())
        return {};

    QString body = text;
    if (body.endsWith(QLatin1Char('\n')))
        body.chop(1);

    if (body.isEmpty())
        return {};

    return body.split(QLatin1Char('\n'), Qt::KeepEmptyParts);
}

QString joinLines(const QStringList &lines, bool trailingNewline)
{
    QString text = lines.join(QLatin1Char('\n'));
    if (trailingNewline && !lines.isEmpty())
        text += QLatin1Char('\n');
    return text;
}

bool isPatchBoundary(const QString &line)
{
    return line.startsWith(QStringLiteral("*** "));
}

bool isRelativeWorkspacePath(const QString &path)
{
    if (path.trimmed().isEmpty())
        return false;
    if (QDir::isAbsolutePath(path))
        return false;

    const QString cleaned = QDir::cleanPath(path);
    return cleaned != QStringLiteral("..")
        && !cleaned.startsWith(QStringLiteral("../"))
        && !cleaned.startsWith(QStringLiteral("..\\"));
}

int findSequence(const QStringList &haystack, const QStringList &needle, int startIndex)
{
    if (needle.isEmpty())
        return qBound(0, startIndex, int(haystack.size()));
    if (needle.size() > haystack.size())
        return -1;

    for (int i = qMax(0, startIndex); i <= haystack.size() - needle.size(); ++i) {
        bool matches = true;
        for (int j = 0; j < needle.size(); ++j) {
            if (haystack.at(i + j) != needle.at(j)) {
                matches = false;
                break;
            }
        }
        if (matches)
            return i;
    }
    return -1;
}

bool applyUpdateHunks(const QString &path,
                      const QList<UpdateHunk> &hunks,
                      const QString &originalText,
                      bool originalTrailingNewline,
                      QString &updatedText,
                      bool &updatedTrailingNewline,
                      QString &error)
{
    QStringList lines = splitLines(originalText, nullptr);
    updatedTrailingNewline = originalTrailingNewline;
    int cursor = 0;

    for (const UpdateHunk &hunk : hunks) {
        QStringList oldLines;
        QStringList newLines;
        for (const PatchLine &line : hunk.lines) {
            if (line.kind != QLatin1Char('+'))
                oldLines.append(line.text);
            if (line.kind != QLatin1Char('-'))
                newLines.append(line.text);
        }

        if (oldLines.isEmpty() && newLines.isEmpty()) {
            error = QStringLiteral("Empty update hunk for %1.").arg(path);
            return false;
        }

        int matchIndex = findSequence(lines, oldLines, cursor);
        if (matchIndex < 0 && cursor > 0)
            matchIndex = findSequence(lines, oldLines, 0);
        if (matchIndex < 0) {
            error = QStringLiteral("Failed to match patch context while updating %1.").arg(path);
            return false;
        }

        lines.erase(lines.begin() + matchIndex, lines.begin() + matchIndex + oldLines.size());
        for (int i = int(newLines.size()) - 1; i >= 0; --i)
            lines.insert(matchIndex, newLines.at(i));
        cursor = matchIndex + int(newLines.size());
    }

    updatedText = joinLines(lines, updatedTrailingNewline);
    return true;
}

bool parsePatch(const QString &rawPatch, QList<PatchOperation> &operations, QString &error)
{
    const QString patch = normalizeLineEndings(rawPatch);
    const QStringList lines = patch.split(QLatin1Char('\n'), Qt::KeepEmptyParts);
    if (lines.isEmpty() || lines.first() != QStringLiteral("*** Begin Patch")) {
        error = QStringLiteral("The first line of the patch must be '*** Begin Patch'.");
        return false;
    }

    int index = 1;
    bool sawEnd = false;
    while (index < lines.size()) {
        const QString line = lines.at(index);
        if (line == QStringLiteral("*** End Patch")) {
            sawEnd = true;
            ++index;
            break;
        }
        if (line.isEmpty()) {
            ++index;
            continue;
        }

        PatchOperation operation;
        if (line.startsWith(QStringLiteral("*** Add File: "))) {
            operation.kind = PatchOperation::Kind::Add;
            operation.path = line.mid(QStringLiteral("*** Add File: ").size()).trimmed();
            ++index;
            while (index < lines.size() && !isPatchBoundary(lines.at(index))) {
                const QString contentLine = lines.at(index);
                if (!contentLine.startsWith(QLatin1Char('+'))) {
                    error = QStringLiteral("Unexpected line in add file hunk: '%1'.").arg(contentLine);
                    return false;
                }
                operation.addedLines.append(contentLine.mid(1));
                ++index;
            }
        } else if (line.startsWith(QStringLiteral("*** Delete File: "))) {
            operation.kind = PatchOperation::Kind::Delete;
            operation.path = line.mid(QStringLiteral("*** Delete File: ").size()).trimmed();
            ++index;
        } else if (line.startsWith(QStringLiteral("*** Update File: "))) {
            operation.kind = PatchOperation::Kind::Update;
            operation.path = line.mid(QStringLiteral("*** Update File: ").size()).trimmed();
            ++index;

            if (index < lines.size() && lines.at(index).startsWith(QStringLiteral("*** Move to: "))) {
                operation.moveTo = lines.at(index).mid(QStringLiteral("*** Move to: ").size()).trimmed();
                ++index;
            }

            while (index < lines.size()) {
                const QString hunkHeader = lines.at(index);
                if (hunkHeader == QStringLiteral("*** End Patch")
                    || hunkHeader.startsWith(QStringLiteral("*** Add File: "))
                    || hunkHeader.startsWith(QStringLiteral("*** Delete File: "))
                    || hunkHeader.startsWith(QStringLiteral("*** Update File: "))) {
                    break;
                }

                if (!hunkHeader.startsWith(QStringLiteral("@@"))) {
                    error = QStringLiteral("Invalid update hunk header: '%1'.").arg(hunkHeader);
                    return false;
                }

                UpdateHunk hunk;
                hunk.header = hunkHeader.mid(2).trimmed();
                ++index;
                while (index < lines.size()) {
                    const QString hunkLine = lines.at(index);
                    if (hunkLine.startsWith(QStringLiteral("@@"))
                        || hunkLine == QStringLiteral("*** End Patch")
                        || hunkLine.startsWith(QStringLiteral("*** Add File: "))
                        || hunkLine.startsWith(QStringLiteral("*** Delete File: "))
                        || hunkLine.startsWith(QStringLiteral("*** Update File: "))) {
                        break;
                    }
                    if (hunkLine == QStringLiteral("*** End of File")) {
                        hunk.explicitEndOfFile = true;
                        ++index;
                        break;
                    }
                    if (hunkLine.isEmpty()
                        || (hunkLine.at(0) != QLatin1Char(' ')
                            && hunkLine.at(0) != QLatin1Char('+')
                            && hunkLine.at(0) != QLatin1Char('-'))) {
                        error = QStringLiteral("Unexpected line found in update hunk: '%1'.").arg(hunkLine);
                        return false;
                    }
                    hunk.lines.append({hunkLine.at(0), hunkLine.mid(1)});
                    ++index;
                }

                if (hunk.lines.isEmpty()) {
                    error = QStringLiteral("Update hunk for %1 cannot be empty.").arg(operation.path);
                    return false;
                }
                operation.hunks.append(hunk);
            }

            if (operation.hunks.isEmpty()) {
                error = QStringLiteral("Update file operation for %1 requires at least one hunk.").arg(operation.path);
                return false;
            }
        } else {
            error = QStringLiteral("Invalid patch hunk header: '%1'.").arg(line);
            return false;
        }

        if (!isRelativeWorkspacePath(operation.path)) {
            error = QStringLiteral("Patch paths must be relative and stay inside the workspace: %1").arg(operation.path);
            return false;
        }
        if (!operation.moveTo.isEmpty() && !isRelativeWorkspacePath(operation.moveTo)) {
            error = QStringLiteral("Patch move targets must be relative and stay inside the workspace: %1").arg(operation.moveTo);
            return false;
        }

        operations.append(operation);
    }

    if (!sawEnd) {
        error = QStringLiteral("Missing '*** End Patch' terminator.");
        return false;
    }

    for (; index < lines.size(); ++index) {
        if (!lines.at(index).trimmed().isEmpty()) {
            error = QStringLiteral("Unexpected content after '*** End Patch'.");
            return false;
        }
    }

    if (operations.isEmpty()) {
        error = QStringLiteral("Patch did not contain any file operations.");
        return false;
    }

    return true;
}

} // namespace

ApplyPatchTool::ApplyPatchTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
    , m_checkpointManager(std::make_unique<CheckpointManager>(workspaceRoot))
{}

QJsonObject ApplyPatchTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "patch": {
                "type": "string",
                "description": "Codex-style patch text beginning with *** Begin Patch."
            },
            "input": {
                "type": "string",
                "description": "Alias for patch."
            }
        }
    })").object();
}

ToolResult ApplyPatchTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString patchText = args.value(QStringLiteral("patch")).toString(
        args.value(QStringLiteral("input")).toString());
    if (patchText.trimmed().isEmpty())
        return {callId, name(), true, "Patch text is required."};

    QList<PatchOperation> operations;
    QString error;
    if (!parsePatch(patchText, operations, error))
        return {callId, name(), true, error};

    QHash<QString, VirtualFileState> initialState;
    QHash<QString, VirtualFileState> finalState;
    QStringList touchedPaths;

    auto loadState = [&](const QString &relPath) -> VirtualFileState {
        if (initialState.contains(relPath))
            return initialState.value(relPath);

        VirtualFileState state;
        state.loaded = true;
        const QString absPath = safePath(relPath);
        const QFileInfo info(absPath);
        state.exists = info.exists();
        state.isDir = info.isDir();
        if (state.exists && info.isFile()) {
            QString readError;
            state.content = normalizeLineEndings(readAllText(absPath, readError));
            if (!readError.isEmpty()) {
                state.loaded = false;
                state.content = readError;
                return state;
            }
            state.trailingNewline = state.content.endsWith(QLatin1Char('\n'));
        }
        initialState.insert(relPath, state);
        finalState.insert(relPath, state);
        return state;
    };

    for (const PatchOperation &operation : operations) {
        const QString sourceAbs = safePath(operation.path);
        if (sourceAbs.isEmpty())
            return {callId, name(), true, QStringLiteral("Path traversal denied: %1").arg(operation.path)};
        touchedPaths.append(operation.path);

        if (!operation.moveTo.isEmpty()) {
            const QString destAbs = safePath(operation.moveTo);
            if (destAbs.isEmpty())
                return {callId, name(), true, QStringLiteral("Path traversal denied: %1").arg(operation.moveTo)};
            touchedPaths.append(operation.moveTo);
        }
    }

    touchedPaths.removeDuplicates();
    if (!canAccessTouchedPaths(touchedPaths))
        return {callId, name(), true, "Sandbox policy denied apply_patch access for one or more paths."};

    for (const QString &path : touchedPaths) {
        const VirtualFileState loaded = loadState(path);
        if (!loaded.loaded)
            return {callId, name(), true, loaded.content};
    }

    for (const PatchOperation &operation : operations) {
        VirtualFileState sourceState = finalState.value(operation.path);
        if (sourceState.isDir)
            return {callId, name(), true, QStringLiteral("Patch target is a directory: %1").arg(operation.path)};

        if (operation.kind == PatchOperation::Kind::Add) {
            if (sourceState.exists)
                return {callId, name(), true, QStringLiteral("Cannot add %1 because it already exists.").arg(operation.path)};

            sourceState.exists = true;
            sourceState.isDir = false;
            sourceState.content = operation.addedLines.join(QLatin1Char('\n'));
            sourceState.trailingNewline = false;
            finalState.insert(operation.path, sourceState);
            continue;
        }

        if (operation.kind == PatchOperation::Kind::Delete) {
            if (!sourceState.exists)
                return {callId, name(), true, QStringLiteral("Cannot delete %1 because it does not exist.").arg(operation.path)};

            sourceState.exists = false;
            sourceState.isDir = false;
            sourceState.content.clear();
            sourceState.trailingNewline = false;
            finalState.insert(operation.path, sourceState);
            continue;
        }

        if (!sourceState.exists)
            return {callId, name(), true, QStringLiteral("Cannot update %1 because it does not exist.").arg(operation.path)};

        QString updatedText;
        bool updatedTrailingNewline = sourceState.trailingNewline;
        if (!applyUpdateHunks(operation.path,
                              operation.hunks,
                              sourceState.content,
                              sourceState.trailingNewline,
                              updatedText,
                              updatedTrailingNewline,
                              error)) {
            return {callId, name(), true, error};
        }

        if (operation.moveTo.isEmpty()) {
            sourceState.content = updatedText;
            sourceState.trailingNewline = updatedTrailingNewline;
            finalState.insert(operation.path, sourceState);
            continue;
        }

        VirtualFileState destState = finalState.value(operation.moveTo);
        if (destState.isDir)
            return {callId, name(), true, QStringLiteral("Patch move target is a directory: %1").arg(operation.moveTo)};
        if (operation.moveTo != operation.path && destState.exists)
            return {callId, name(), true, QStringLiteral("Cannot move %1 to %2 because the destination already exists.").arg(operation.path, operation.moveTo)};

        sourceState.exists = false;
        sourceState.content.clear();
        sourceState.trailingNewline = false;
        finalState.insert(operation.path, sourceState);

        destState.exists = true;
        destState.isDir = false;
        destState.content = updatedText;
        destState.trailingNewline = updatedTrailingNewline;
        finalState.insert(operation.moveTo, destState);
    }

    QString backupId;
    if (!ensureBackup(touchedPaths, backupId, error))
        return {callId, name(), true, error};
    const QString checkpointId = createCheckpoint(touchedPaths);

    for (const QString &path : touchedPaths) {
        const QString absPath = safePath(path);
        const VirtualFileState before = initialState.value(path);
        const VirtualFileState after = finalState.value(path, before);

        if (!after.exists) {
            if (before.exists && !QFile::remove(absPath)) {
                return {callId, name(), true, QStringLiteral("Failed to delete %1.").arg(path)};
            }
            continue;
        }

        QDir().mkpath(QFileInfo(absPath).absolutePath());
        QString writeError;
        if (!writeAllText(absPath, after.content, writeError))
            return {callId, name(), true, writeError};
    }

    QString message = QStringLiteral("Patch applied. Backup id: %1").arg(backupId);
    if (!checkpointId.isEmpty())
        message += QStringLiteral("\nCheckpoint: %1").arg(checkpointId);
    message += QStringLiteral("\nTouched files: %1").arg(touchedPaths.join(QStringLiteral(", ")));
    return {callId, name(), false, message};
}

QString ApplyPatchTool::summary(const QJsonObject &args) const
{
    const QString patchText = args.value(QStringLiteral("patch")).toString(
        args.value(QStringLiteral("input")).toString());
    Q_UNUSED(patchText);
    return QStringLiteral("apply patch");
}

QString ApplyPatchTool::safePath(const QString &relPath) const
{
    if (!isRelativeWorkspacePath(relPath))
        return {};

    const QDir root(m_workspaceRoot);
    const QString abs = root.absoluteFilePath(QDir::cleanPath(relPath));
    if (!QFileInfo(abs).absoluteFilePath().startsWith(root.absolutePath()))
        return {};
    return abs;
}

QString ApplyPatchTool::backupRoot() const
{
    return QDir(m_workspaceRoot).absoluteFilePath(QStringLiteral(".neurx/apply-patch-backups"));
}

QString ApplyPatchTool::lastBackupManifestPath() const
{
    return QDir(backupRoot()).absoluteFilePath(QStringLiteral("last/manifest.json"));
}

bool ApplyPatchTool::ensureBackup(const QStringList &touchedPaths, QString &backupId, QString &error)
{
    backupId = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMddhhmmsszzz"));
    const QString root = QDir(backupRoot()).absoluteFilePath(QStringLiteral("last"));
    if (!QDir().mkpath(root)) {
        error = QStringLiteral("Failed to create apply_patch backup directory.");
        return false;
    }

    QJsonArray entries;
    for (const QString &relPath : touchedPaths) {
        const QString absPath = safePath(relPath);
        if (absPath.isEmpty())
            continue;

        BackupEntry entry;
        entry.relPath = relPath;
        entry.existed = QFileInfo::exists(absPath);
        entry.backupPath = QDir(root).absoluteFilePath(relPath);

        if (entry.existed) {
            QDir().mkpath(QFileInfo(entry.backupPath).absolutePath());
            QFile::remove(entry.backupPath);
            if (!QFile::copy(absPath, entry.backupPath)) {
                error = QStringLiteral("Failed to backup %1.").arg(relPath);
                return false;
            }
        }

        QJsonObject obj;
        obj[QStringLiteral("path")] = entry.relPath;
        obj[QStringLiteral("backup_path")] = entry.backupPath;
        obj[QStringLiteral("existed")] = entry.existed;
        entries.append(obj);
    }

    QJsonObject manifest;
    manifest[QStringLiteral("backup_id")] = backupId;
    manifest[QStringLiteral("entries")] = entries;
    manifest[QStringLiteral("patch_time_utc")] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    const QString manifestText = QString::fromUtf8(QJsonDocument(manifest).toJson(QJsonDocument::Indented));
    if (!writeAllText(QDir(root).absoluteFilePath(QStringLiteral("manifest.json")), manifestText, error))
        return false;
    if (!writeAllText(lastBackupManifestPath(), manifestText, error))
        return false;
    return true;
}

bool ApplyPatchTool::restoreBackup(const QString &manifestPath, QString &error)
{
    const QString manifestText = readAllText(manifestPath, error);
    if (manifestText.isEmpty() && !error.isEmpty())
        return false;

    const QJsonDocument doc = QJsonDocument::fromJson(manifestText.toUtf8());
    if (!doc.isObject()) {
        error = QStringLiteral("Invalid apply_patch backup manifest.");
        return false;
    }

    const QJsonArray entries = doc.object().value(QStringLiteral("entries")).toArray();
    for (const QJsonValue &entryValue : entries) {
        const QJsonObject entry = entryValue.toObject();
        const QString relPath = entry.value(QStringLiteral("path")).toString();
        const QString backupPath = entry.value(QStringLiteral("backup_path")).toString();
        const bool existed = entry.value(QStringLiteral("existed")).toBool();
        const QString absPath = safePath(relPath);
        if (absPath.isEmpty())
            continue;

        if (!existed) {
            QFile::remove(absPath);
            continue;
        }

        QString readError;
        const QString backupText = readAllText(backupPath, readError);
        if (!readError.isEmpty()) {
            error = readError;
            return false;
        }

        QString writeError;
        if (!writeAllText(absPath, backupText, writeError)) {
            error = writeError;
            return false;
        }
    }

    return true;
}

QString ApplyPatchTool::createCheckpoint(const QStringList &touchedPaths) const
{
    if (!m_checkpointManager || !m_checkpointManager->isAvailable() || touchedPaths.isEmpty())
        return {};
    return m_checkpointManager->checkpoint(touchedPaths, QStringLiteral("apply_patch"));
}

bool ApplyPatchTool::canAccessTouchedPaths(const QStringList &paths) const
{
    if (!m_sandboxManager)
        return true;
    if (m_sandboxManager->isReadOnlyMode())
        return false;

    for (const QString &path : paths) {
        const QString abs = safePath(path);
        if (abs.isEmpty())
            return false;
        if (m_sandboxManager->isProtectedMetadata(abs))
            return false;
        if (!m_sandboxManager->canAccess(abs, FileSystemAccessMode::Write))
            return false;
    }
    return true;
}
