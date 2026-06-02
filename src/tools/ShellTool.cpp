#include "tools/ShellTool.h"
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>
#include <QProcess>
#include <QProcessEnvironment>

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

ToolResult ShellTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString command = args["command"].toString().trimmed();
    if (command.isEmpty())
        return {callId, name(), true, "Empty command."};

    if (!isAllowed(command))
        return {callId, name(), true, "Command not in allowlist: " + command};

    const int timeout = args.value("timeout_ms").toInt(m_defaultTimeoutMs);
    const QString subDir = args.value("working_dir").toString();

    QString cwd = m_workingDir;
    if (!subDir.isEmpty()) {
        QDir d(m_workingDir);
        const QString abs = d.absoluteFilePath(subDir);
        if (QFileInfo(abs).absoluteFilePath().startsWith(QFileInfo(m_workingDir).absoluteFilePath()))
            cwd = abs;
    }

    QProcess proc;
    proc.setWorkingDirectory(cwd);

    auto env = QProcessEnvironment::systemEnvironment();
    const auto extraEnv = args.value("env").toObject();
    for (auto it = extraEnv.begin(); it != extraEnv.end(); ++it)
        env.insert(it.key(), it.value().toString());
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
