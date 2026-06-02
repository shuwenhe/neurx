#include "tools/DockerShellTool.h"
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>
#include <QProcess>
#include <QUuid>
#include <QDebug>

DockerShellTool::DockerShellTool(const QString &workspacePath, QObject *parent)
    : BaseTool(parent), m_workspacePath(workspacePath)
{
    // Unique container name for this tool instance/session
    m_containerName = "neurx-agent-" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
}

DockerShellTool::~DockerShellTool()
{
    stopContainer();
}

QJsonObject DockerShellTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "command": {
                "type": "string",
                "description": "The shell command to run inside the container."
            },
            "working_dir": {
                "type": "string",
                "description": "Optional sub-directory inside /workspace."
            },
            "timeout_ms": {
                "type": "integer",
                "description": "Maximum time to wait in milliseconds (default 60000)."
            }
        },
        "required": ["command"]
    })").object();
}

bool DockerShellTool::ensureContainerRunning()
{
    if (m_containerInitialized) return true;

    // Check if container already exists (maybe we're reconnecting)
    QProcess check;
    check.start("docker", {"inspect", m_containerName});
    check.waitForFinished();
    if (check.exitCode() == 0) {
        m_containerInitialized = true;
        return true;
    }

    // Start a new persistent container in the background
    // We use a long-running sleep command to keep it alive
    QStringList args;
    args << "run" << "-d" << "--name" << m_containerName;
    args << "-v" << QString("%1:/workspace").arg(m_workspacePath);
    args << "-w" << "/workspace";
    args << m_image;
    args << "tail" << "-f" << "/dev/null";

    QProcess startProc;
    startProc.start("docker", args);
    if (!startProc.waitForFinished(30000) || startProc.exitCode() != 0) {
        qWarning() << "Failed to start Docker container:" << startProc.readAllStandardError();
        return false;
    }

    m_containerInitialized = true;
    return true;
}

void DockerShellTool::stopContainer()
{
    if (!m_containerInitialized) return;

    QProcess::execute("docker", {"rm", "-f", m_containerName});
    m_containerInitialized = false;
}

ToolResult DockerShellTool::execute(const QString &callId, const QJsonObject &args)
{
    if (!ensureContainerRunning()) {
        return {callId, name(), true, "Failed to start or connect to Docker container."};
    }

    const QString command = args["command"].toString().trimmed();
    const int timeout = args.value("timeout_ms").toInt(m_defaultTimeoutMs);
    const QString subDir = args.value("working_dir").toString();

    QString cwd = "/workspace";
    if (!subDir.isEmpty()) {
        // Simple sanitization for container path
        if (!subDir.startsWith("/") && !subDir.contains("..")) {
            cwd += "/" + subDir;
        }
    }

    bool ok = false;
    QString output = execCommand(command, timeout, callId, ok);

    return {callId, name(), !ok, output};
}

QString DockerShellTool::execCommand(const QString &command, int timeoutMs, const QString &callId, bool &ok)
{
    QProcess proc;
    QStringList args;
    args << "exec" << m_containerName << "sh" << "-c" << command;

    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start("docker", args);

    if (!proc.waitForStarted(5000)) {
        ok = false;
        return "Failed to start docker exec process.";
    }

    QString accumulated;
    const qint64 deadline = QDateTime::currentMSecsSinceEpoch() + timeoutMs;

    while (proc.state() != QProcess::NotRunning) {
        if (QDateTime::currentMSecsSinceEpoch() > deadline) {
            proc.kill();
            proc.waitForFinished(1000);
            ok = false;
            return QString("Timeout after %1ms.\nPartial output:\n%2").arg(timeoutMs).arg(accumulated);
        }
        proc.waitForReadyRead(100);
        const QString chunk = QString::fromLocal8Bit(proc.readAll());
        if (!chunk.isEmpty()) {
            accumulated += chunk;
            emit outputChunk(callId, chunk);
        }
    }

    const QString tail = QString::fromLocal8Bit(proc.readAll());
    if (!tail.isEmpty()) {
        accumulated += tail;
        emit outputChunk(callId, tail);
    }

    proc.waitForFinished(500);
    ok = (proc.exitCode() == 0);
    return accumulated;
}

QString DockerShellTool::summary(const QJsonObject &args) const
{
    return "docker exec $ " + args["command"].toString();
}
