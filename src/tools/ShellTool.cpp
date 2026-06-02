#include "tools/ShellTool.h"
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>

static bool matchesAny(const QString &text, const QStringList &patterns)
{
    const QString normalized = text.trimmed().toLower();
    for (const auto &pattern : patterns) {
        const QRegularExpression re(pattern, QRegularExpression::CaseInsensitiveOption);
        if (re.match(normalized).hasMatch())
            return true;
    }
    return false;
}

ShellTool::ShellTool(const QString &workingDir, QObject *parent)
    : BaseTool(parent), m_workingDir(workingDir)
{}

QJsonObject ShellTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "command": {
                "type": "string",
                "description": "The shell command to run. Runs via /bin/sh -c on Unix or cmd /C on Windows."
            },
            "working_dir": {
                "type": "string",
                "description": "Optional sub-directory relative to workspace root."
            },
            "timeout_ms": {
                "type": "integer",
                "description": "Maximum time to wait in milliseconds (default 30000)."
            },
            "env": {
                "type": "object",
                "description": "Extra environment variables as key-value pairs."
            }
        },
        "required": ["command"]
    })").object();
}

bool ShellTool::isAllowed(const QString &command) const
{
    if (m_allowlist.isEmpty()) return true;
    for (const auto &prefix : m_allowlist) {
        if (command.startsWith(prefix)) return true;
    }
    return false;
}

bool ShellTool::isDestructiveCommand(const QString &command) const
{
    return matchesAny(command, {
        QStringLiteral(R"(\brm\b.*\s-rf\b)"),
        QStringLiteral(R"(\bgit\b.*\breset\b.*\b--hard\b)"),
        QStringLiteral(R"(\bgit\b.*\bclean\b.*\b-f\b)"),
        QStringLiteral(R"(\bchmod\b.*\b-R\b.*\b777\b)"),
        QStringLiteral(R"(\bchown\b.*\b-R\b)"),
        QStringLiteral(R"(\bdd\b.*\bof=/dev/\w+\b)"),
        QStringLiteral(R"(\bmkfs\w*\b)"),
        QStringLiteral(R"(\bshutdown\b|\breboot\b|\bhalt\b)"),
        QStringLiteral(R"(\bpowershell\b.*\bremove-item\b.*\b-recurse\b)"),
        QStringLiteral(R"(\bdel\b.*\s\/s\b.*\s\/q\b)")
    });
}

ToolResult ShellTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString command = args["command"].toString().trimmed();
    if (command.isEmpty())
        return {callId, name(), true, "Empty command."};

    if (!isAllowed(command))
        return {callId, name(), true, "Command not in allowlist: " + command};

    if (m_sandboxManager && m_sandboxManager->isReadOnlyMode() && isDestructiveCommand(command))
        return {callId, name(), true, "Read-only sandbox mode blocks destructive shell commands."};

    if (m_sandboxManager) {
        for (const auto &meta : m_sandboxManager->protectedMetadataPaths()) {
            if (!meta.isEmpty() && command.contains(meta))
                return {callId, name(), true, "Command touches protected metadata: " + meta};
        }
    }

    const int timeout = args.value("timeout_ms").toInt(m_defaultTimeoutMs);
    const QString subDir = args.value("working_dir").toString();

    QString cwd = m_workingDir;
    if (!subDir.isEmpty()) {
        QDir d(m_workingDir);
        const QString abs = d.absoluteFilePath(subDir);
        if (QFileInfo(abs).absoluteFilePath().startsWith(QFileInfo(m_workingDir).absoluteFilePath()))
            cwd = abs;
    }

    auto env = QProcessEnvironment::systemEnvironment();
    const auto extraEnv = args.value("env").toObject();
    for (auto it = extraEnv.begin(); it != extraEnv.end(); ++it)
        env.insert(it.key(), it.value().toString());

    if (m_sandboxManager && extraEnv.isEmpty()) {
        SandboxExecRequest request;
        request.commandLine = command;
        request.workingDirectory = cwd;
        request.sandboxMode = m_sandboxManager->isReadOnlyMode() ? SandboxMode::ReadOnly : SandboxMode::WorkspaceWrite;
        request.fsPolicy = m_sandboxManager->getFileSystemPolicy();
        request.netPolicy = m_sandboxManager->getNetworkPolicy();
        request.timeoutMs = timeout;

        QString output;
        QString error;
        int exitCode = -1;
        m_sandboxManager->executeInSandbox(request, [&](int code, const QString &out, const QString &err) {
            exitCode = code;
            output = out;
            error = err;
        });

        if (!output.isEmpty())
            emit outputChunk(callId, output);

        const bool failed = exitCode != 0;
        const QString result = QString("Exit code: %1\n%2%3")
                                   .arg(exitCode)
                                   .arg(output)
                                   .arg(error.isEmpty() ? QString() : QString("\n") + error);
        return {callId, name(), failed, result};
    }

    QProcess proc;
    proc.setWorkingDirectory(cwd);
    proc.setProcessEnvironment(env);
    proc.setProcessChannelMode(QProcess::MergedChannels);

#ifdef Q_OS_WIN
    proc.start("cmd.exe", {"/C", command});
#else
    proc.start("/bin/sh", {"-c", command});
#endif

    if (!proc.waitForStarted(5000))
        return {callId, name(), true, "Process failed to start."};

    // Stream stdout/stderr incrementally while the process runs.
    QString accumulated;
    const qint64 deadline = QDateTime::currentMSecsSinceEpoch() + timeout;

    while (proc.state() != QProcess::NotRunning) {
        if (QDateTime::currentMSecsSinceEpoch() > deadline) {
            proc.kill();
            proc.waitForFinished(1000);
            return {callId, name(), true,
                    QString("Timeout after %1ms.\nPartial output:\n%2")
                        .arg(timeout).arg(accumulated)};
        }
        proc.waitForReadyRead(100);
        const QString chunk = QString::fromLocal8Bit(proc.readAll());
        if (!chunk.isEmpty()) {
            accumulated += chunk;
            emit outputChunk(callId, chunk);
        }
    }

    // Drain any remaining bytes after the process exits.
    const QString tail = QString::fromLocal8Bit(proc.readAll());
    if (!tail.isEmpty()) {
        accumulated += tail;
        emit outputChunk(callId, tail);
    }

    proc.waitForFinished(500);
    const int exitCode = proc.exitCode();
    return {callId, name(), exitCode != 0,
            QString("Exit code: %1\n%2").arg(exitCode).arg(accumulated)};
}

QString ShellTool::summary(const QJsonObject &args) const
{
    return "$ " + args["command"].toString();
}
