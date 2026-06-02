#include "tools/PatchTool.h"
#include "tools/CheckpointManager.h"

#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QTemporaryFile>
#include <QTextStream>
#include <QRegularExpression>

namespace {

QString readAllText(const QString &path, QString &error)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        error = "Cannot open: " + f.errorString();
        return {};
    }
    return QString::fromUtf8(f.readAll());
}

bool writeAllText(const QString &path, const QString &text, QString &error)
{
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        error = "Cannot write: " + f.errorString();
        return false;
    }
    QTextStream out(&f);
    out << text;
    if (!f.commit()) {
        error = "Failed to commit file.";
        return false;
    }
    return true;
}

QString trimPatchHeaderPath(QString rawPath)
{
    rawPath = rawPath.trimmed();
    const int tab = rawPath.indexOf('\t');
    if (tab >= 0) rawPath = rawPath.left(tab);
    const int sp = rawPath.indexOf(' ');
    if (sp >= 0) rawPath = rawPath.left(sp);
    return rawPath.trimmed();
}

} // namespace

PatchTool::PatchTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
    , m_checkpointManager(std::make_unique<CheckpointManager>(workspaceRoot))
{}

QJsonObject PatchTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "operation": {
                "type": "string",
                "enum": ["preview_diff", "apply_diff", "revert_last"],
                "description": "Unified diff operations."
            },
            "patch": {
                "type": "string",
                "description": "Unified diff text for preview/apply."
            }
        },
        "required": ["operation"]
    })").object();
}

ToolResult PatchTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString op = args["operation"].toString();
    if (op == "preview_diff") return previewDiff(callId, args);
    if (op == "apply_diff")   return applyDiff(callId, args);
    if (op == "revert_last")  return revertLast(callId);
    return {callId, name(), true, "Unknown operation: " + op};
}

QString PatchTool::summary(const QJsonObject &args) const
{
    const QString op = args["operation"].toString();
    if (op == "preview_diff" || op == "apply_diff") return op + " unified diff";
    if (op == "revert_last") return "revert last patch";
    return op;
}

QString PatchTool::safePath(const QString &rel) const
{
    const QDir root(m_workspaceRoot);
    const QString abs = root.absoluteFilePath(rel);
    if (!QFileInfo(abs).absoluteFilePath().startsWith(root.absolutePath()))
        return {};
    return abs;
}

QString PatchTool::backupRoot() const
{
    return QDir(m_workspaceRoot).absoluteFilePath(".neurx/patch-backups");
}

QString PatchTool::lastBackupManifestPath() const
{
    return QDir(backupRoot()).absoluteFilePath("last/manifest.json");
}

bool PatchTool::isGitRepo() const
{
    QProcess proc;
    proc.setWorkingDirectory(m_workspaceRoot);
    proc.start("git", {"rev-parse", "--is-inside-work-tree"});
    if (!proc.waitForFinished(3000)) return false;
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) return false;
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed() == "true";
}

QString PatchTool::normalizePatchPath(QString rawPath)
{
    rawPath = trimPatchHeaderPath(rawPath);
    if (rawPath == "/dev/null") return rawPath;
    if (rawPath.startsWith("a/") || rawPath.startsWith("b/"))
        rawPath = rawPath.mid(2);
    return rawPath;
}

QStringList PatchTool::parseTouchedPaths(const QString &patchText)
{
    QStringList touched;
    const QStringList lines = patchText.split('\n');
    for (const QString &line : lines) {
        if (line.startsWith("--- ") || line.startsWith("+++ ")) {
            const QString path = normalizePatchPath(line.mid(4));
            if (path.isEmpty() || path == "/dev/null")
                continue;
            if (!touched.contains(path))
                touched << path;
        }
    }
    return touched;
}

ToolResult PatchTool::previewDiff(const QString &callId, const QJsonObject &args) const
{
    const QString patchText = args.value("patch").toString();
    if (patchText.trimmed().isEmpty())
        return {callId, name(), true, "Empty patch."};
    if (!isGitRepo())
        return {callId, name(), true, "Workspace is not a git repository."};

    QTemporaryFile tmp(QDir(m_workspaceRoot).absoluteFilePath(".neurx-patch-XXXXXX.diff"));
    if (!tmp.open())
        return {callId, name(), true, "Failed to create temp patch file."};
    tmp.write(patchText.toUtf8());
    tmp.flush();

    QString output;
    if (!runGitApply({"--check", "--verbose"}, tmp.fileName(), output)) {
        return {callId, name(), true, output.isEmpty() ? "Patch preview failed." : output};
    }
    return {callId, name(), false,
            QString("Patch is applicable.\n\n%1").arg(patchText.trimmed())};
}

bool PatchTool::runGitApply(const QStringList &args, const QString &patchPath, QString &output) const
{
    QProcess proc;
    proc.setWorkingDirectory(m_workspaceRoot);
    QStringList fullArgs = args;
    fullArgs << patchPath;
    proc.start("git", fullArgs);
    if (!proc.waitForStarted(5000)) {
        output = "Failed to start git apply.";
        return false;
    }
    if (!proc.waitForFinished(30000)) {
        proc.kill();
        output = "git apply timed out.";
        return false;
    }
    output = QString::fromUtf8(proc.readAllStandardOutput()) + QString::fromUtf8(proc.readAllStandardError());
    return proc.exitCode() == 0 && proc.exitStatus() == QProcess::NormalExit;
}

QString PatchTool::createCheckpoint(const QStringList &touchedPaths) const
{
    if (!m_checkpointManager || !m_checkpointManager->isAvailable() || touchedPaths.isEmpty())
        return {};
    return m_checkpointManager->checkpoint(touchedPaths, QStringLiteral("patch apply_diff"));
}

bool PatchTool::ensureBackup(const QStringList &touchedPaths, QString &backupId, QString &error)
{
    backupId = QDateTime::currentDateTimeUtc().toString("yyyyMMddhhmmsszzz");
    const QString root = QDir(backupRoot()).absoluteFilePath("last");
    if (!QDir().mkpath(root)) {
        error = "Failed to create backup directory.";
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
            QString copyError;
            if (!QFile::copy(absPath, entry.backupPath)) {
                copyError = "Failed to backup: " + relPath;
                error = copyError;
                return false;
            }
        }

        QJsonObject obj;
        obj["path"] = entry.relPath;
        obj["backup_path"] = entry.backupPath;
        obj["existed"] = entry.existed;
        entries.append(obj);
    }

    QJsonObject manifest;
    manifest["backup_id"] = backupId;
    manifest["entries"] = entries;
    manifest["patch_time_utc"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QString manifestError;
    if (!writeAllText(QDir(root).absoluteFilePath("manifest.json"),
                      QString::fromUtf8(QJsonDocument(manifest).toJson(QJsonDocument::Indented)),
                      manifestError)) {
        error = manifestError;
        return false;
    }

    QString lastError;
    if (!writeAllText(lastBackupManifestPath(),
                      QString::fromUtf8(QJsonDocument(manifest).toJson(QJsonDocument::Indented)),
                      lastError)) {
        error = lastError;
        return false;
    }

    m_lastBackupId = backupId;
    return true;
}

ToolResult PatchTool::applyDiff(const QString &callId, const QJsonObject &args)
{
    const QString patchText = args.value("patch").toString();
    if (patchText.trimmed().isEmpty())
        return {callId, name(), true, "Empty patch."};
    if (!isGitRepo())
        return {callId, name(), true, "Workspace is not a git repository."};

    const QStringList touchedPaths = parseTouchedPaths(patchText);
    QString backupId;
    QString error;
    if (!ensureBackup(touchedPaths, backupId, error))
        return {callId, name(), true, error};
    const QString checkpointId = createCheckpoint(touchedPaths);

    QTemporaryFile tmp(QDir(m_workspaceRoot).absoluteFilePath(".neurx-patch-XXXXXX.diff"));
    if (!tmp.open())
        return {callId, name(), true, "Failed to create temp patch file."};
    tmp.write(patchText.toUtf8());
    tmp.flush();

    QString output;
    if (!runGitApply({"apply", "--whitespace=nowarn"}, tmp.fileName(), output)) {
        return {callId, name(), true, output.isEmpty() ? "Patch application failed." : output};
    }

    return {callId, name(), false,
            QString("Patch applied. Backup id: %1%2\nTouched files: %3\n%4")
                .arg(backupId,
                     checkpointId.isEmpty() ? QString() : QString("\nCheckpoint: %1").arg(checkpointId),
                     touchedPaths.join(", "),
                     output.trimmed())};
}

bool PatchTool::restoreBackup(const QString &manifestPath, QString &error)
{
    const QString manifestText = readAllText(manifestPath, error);
    if (manifestText.isEmpty() && !error.isEmpty())
        return false;

    const QJsonDocument doc = QJsonDocument::fromJson(manifestText.toUtf8());
    if (!doc.isObject()) {
        error = "Invalid backup manifest.";
        return false;
    }

    const QJsonArray entries = doc.object().value("entries").toArray();
    for (const auto &entryVal : entries) {
        const QJsonObject entry = entryVal.toObject();
        const QString relPath = entry.value("path").toString();
        const QString backupPath = entry.value("backup_path").toString();
        const bool existed = entry.value("existed").toBool();
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

ToolResult PatchTool::revertLast(const QString &callId)
{
    const QString manifestPath = lastBackupManifestPath();
    if (!QFileInfo::exists(manifestPath))
        return {callId, name(), true, "No backup manifest found."};

    QString error;
    if (!restoreBackup(manifestPath, error))
        return {callId, name(), true, error};

    return {callId, name(), false, "Restored last patch backup."};
}
