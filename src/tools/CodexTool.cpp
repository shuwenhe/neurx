#include "tools/CodexTool.h"
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>

namespace {

static QString previewText(const QString &text, int maxLen = 120)
{
    const QString compact = text.simplified();
    if (compact.size() <= maxLen)
        return compact;
    return compact.left(maxLen) + QChar(u'\u2026');
}

static QString normalizeForPromptPath(const QString &path)
{
    return QDir::cleanPath(path);
}

} // namespace

CodexTool::CodexTool(const QString &workingDir, QObject *parent)
    : BaseTool(parent), m_workingDir(workingDir)
{
    // Three-tier binary discovery (first match wins):
    //
    // 1. Beside the running executable / inside the .app bundle (Contents/MacOS/).
    //    Covers packaged builds and post-build dev builds.
    const QString exeDir = QCoreApplication::applicationDirPath();
#ifdef Q_OS_WIN
    const QString localBin = exeDir + QStringLiteral("/codex.exe");
#else
    const QString localBin = exeDir + QStringLiteral("/codex");
#endif
    if (QFileInfo::exists(localBin)) {
        m_codexBin = localBin;
        return;
    }

#ifdef CODEX_CLI_BINARY_PATH
    // 2. Compile-time absolute path baked in by CMake (valid while running from
    //    the build tree, i.e. during development before install).
    const QString buildBin = QStringLiteral(CODEX_CLI_BINARY_PATH);
    if (QFileInfo::exists(buildBin)) {
        m_codexBin = buildBin;
        return;
    }
#endif

    // 3. Fall back to PATH lookup — works if codex is installed globally
    //    (npm install -g @openai/codex  or  brew install --cask codex).
    m_codexBin = QStringLiteral("codex");
}

QJsonObject CodexTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "task": {
                "type": "string",
                "description": "Detailed, self-contained description of what Codex should do. Include relevant file paths, expected behaviour, and success criteria."
            },
            "model": {
                "type": "string",
                "description": "Codex model to use, e.g. 'codex-mini-latest' or 'o4-mini'. Omit to use the Codex CLI default."
            },
            "file_path": {
                "type": "string",
                "description": "Optional target file path to overwrite. When set together with new_text, Codex will write the exact content to this file."
            },
            "new_text": {
                "type": "string",
                "description": "Optional exact file contents to write when file_path is provided."
            },
            "working_dir": {
                "type": "string",
                "description": "Optional sub-directory relative to the workspace root in which to run Codex."
            },
            "timeout_ms": {
                "type": "integer",
                "description": "Maximum time in milliseconds to wait for Codex to finish (default 300000 / 5 min)."
            }
        },
        "required": ["task"]
    })").object();
}

ToolResult CodexTool::execute(const QString &callId, const QJsonObject &args)
{
    QString task = args[QStringLiteral("task")].toString().trimmed();
    const QString filePath = args.value(QStringLiteral("file_path")).toString().trimmed();
    const QString newText = args.value(QStringLiteral("new_text")).toString();

    if (task.isEmpty() && filePath.isEmpty())
        return {callId, name(), /*isError=*/true,
                QStringLiteral("Parameter 'task' must not be empty.")};

    const int     timeout = args.value(QStringLiteral("timeout_ms")).toInt(m_timeoutMs);
    const QString subDir  = args.value(QStringLiteral("working_dir")).toString();
    const QString model   = args.value(QStringLiteral("model")).toString().trimmed();

    // Resolve working directory (optional subdir relative to workspace root).
    QString cwd = m_workingDir;
    if (!subDir.isEmpty()) {
        const QString candidate = QDir(m_workingDir).absoluteFilePath(subDir);
        if (QFileInfo(candidate).isDir())
            cwd = candidate;
    }

    if (!filePath.isEmpty()) {
        task = buildWriteTask(filePath, newText, cwd);
    }

    if (task.isEmpty())
        return {callId, name(), /*isError=*/true,
                QStringLiteral("Unable to build a Codex task.")};

    // Build argv: codex --full-auto [--model <m>] "<task>"
    QStringList argv;
    argv << QStringLiteral("--full-auto");
    if (!model.isEmpty())
        argv << QStringLiteral("--model") << model;
    argv << task;

    QProcess proc;
    proc.setWorkingDirectory(cwd);
    proc.setProcessChannelMode(QProcess::MergedChannels);

    // Inherit the host environment so PATH, OPENAI_API_KEY, etc. are available.
    proc.setProcessEnvironment(QProcessEnvironment::systemEnvironment());

    proc.start(m_codexBin, argv);

    if (!proc.waitForStarted(5000)) {
        return {callId, name(), /*isError=*/true,
                QStringLiteral("Failed to start Codex binary '%1': %2")
                    .arg(m_codexBin, proc.errorString())};
    }

    const bool finished = proc.waitForFinished(timeout);
    const QString output = QString::fromUtf8(proc.readAll()).trimmed();

    if (!finished) {
        proc.kill();
        return {callId, name(), /*isError=*/true,
                QStringLiteral("Codex timed out after %1 ms.\n\nPartial output:\n%2")
                    .arg(timeout)
                    .arg(output.isEmpty() ? QStringLiteral("(none)") : output)};
    }

    const bool hadError = (proc.exitStatus() != QProcess::NormalExit
                           || proc.exitCode() != 0);
    return {callId, name(), hadError,
            output.isEmpty() ? QStringLiteral("(no output)") : output};
}

QString CodexTool::summary(const QJsonObject &args) const
{
    const QString filePath = args.value(QStringLiteral("file_path")).toString().trimmed();
    if (!filePath.isEmpty())
        return QStringLiteral("codex write: ") + filePath;

    const QString task = args.value(QStringLiteral("task")).toString();
    return QStringLiteral("codex: ") + previewText(task, 80);
}

QString CodexTool::buildWriteTask(const QString &filePath, const QString &newText, const QString &cwd) const
{
    const QString normalizedPath = normalizeForPromptPath(filePath);
    const QString cwdPath = normalizeForPromptPath(cwd);

    QString task;
    task += QStringLiteral("Overwrite the target file exactly as requested.\n");
    task += QStringLiteral("Workspace root: %1\n").arg(cwdPath);
    task += QStringLiteral("Target file: %1\n").arg(normalizedPath);
    task += QStringLiteral("Rules:\n");
    task += QStringLiteral("- Write the file contents exactly as provided.\n");
    task += QStringLiteral("- Do not change any other files unless absolutely necessary for the write.\n");
    task += QStringLiteral("- Prefer apply_patch or the filesystem tool for the actual write.\n");
    task += QStringLiteral("- Verify the final file contents match exactly.\n");
    task += QStringLiteral("Exact file contents:\n");
    task += QStringLiteral("<<<NEURX_FILE_CONTENT_START>>>\n");
    task += newText;
    if (!newText.endsWith('\n'))
        task += QChar('\n');
    task += QStringLiteral("<<<NEURX_FILE_CONTENT_END>>>\n");
    return task;
}
