#include "TerminalService.h"
#include <QUuid>
#include <QMap>
#include <QStandardPaths>

class TerminalService::Impl {
public:
    QMap<QString, Terminal> terminals;
    
    QString generateId() {
        return QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
    
    QString getDefaultShell() {
        #ifdef Q_OS_WIN
        return "cmd.exe";
        #else
        return "/bin/bash";
        #endif
    }
};

TerminalService* TerminalService::instance() {
    static TerminalService s_instance;
    return &s_instance;
}

TerminalService::TerminalService()
    : m_impl(std::make_unique<Impl>()) {
}

TerminalService::~TerminalService() = default;

QString TerminalService::createTerminal(const QString& name, const QString& shell,
                                       const QString& cwd) {
    QString terminalId = m_impl->generateId();
    
    Terminal terminal;
    terminal.id = terminalId;
    terminal.name = name.isEmpty() ? ("Terminal " + QString::number(m_impl->terminals.size() + 1)) : name;
    terminal.shell = shell.isEmpty() ? m_impl->getDefaultShell() : shell;
    terminal.cwd = cwd.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::HomeLocation) : cwd;
    
    auto process = new QProcess();
    process->setWorkingDirectory(terminal.cwd);
    process->start(terminal.shell);
    
    if (!process->waitForStarted()) {
        emit terminalError(terminalId, "Failed to start terminal");
        delete process;
        return QString();
    }
    
    terminal.process = process;
    terminal.isRunning = true;
    m_impl->terminals[terminalId] = terminal;
    
    // Connect signals
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, terminalId](int, QProcess::ExitStatus) {
        if (m_impl->terminals.contains(terminalId)) {
            auto& term = m_impl->terminals[terminalId];
            term.isRunning = false;
            emit terminalClosed(terminalId);
        }
    });
    
    connect(process, &QProcess::readyReadStandardOutput,
            this, [this, terminalId]() {
        if (m_impl->terminals.contains(terminalId)) {
            auto& term = m_impl->terminals[terminalId];
            QString output = QString::fromUtf8(term.process->readAllStandardOutput());
            emit terminalOutput(terminalId, output);
        }
    });
    
    emit terminalCreated(terminalId);
    return terminalId;
}

void TerminalService::closeTerminal(const QString& terminalId) {
    auto it = m_impl->terminals.find(terminalId);
    if (it == m_impl->terminals.end()) {
        return;
    }
    
    if (it->process) {
        it->process->terminate();
        if (!it->process->waitForFinished(3000)) {
            it->process->kill();
        }
        delete it->process;
    }
    
    m_impl->terminals.erase(it);
    emit terminalClosed(terminalId);
}

void TerminalService::closeAll() {
    auto terminalIds = m_impl->terminals.keys();
    for (const auto& id : terminalIds) {
        closeTerminal(id);
    }
}

QList<Terminal> TerminalService::getTerminals() const {
    return m_impl->terminals.values();
}

Terminal TerminalService::getTerminal(const QString& terminalId) const {
    return m_impl->terminals.value(terminalId);
}

bool TerminalService::hasTerminal(const QString& terminalId) const {
    return m_impl->terminals.contains(terminalId);
}

void TerminalService::sendCommand(const QString& terminalId, const QString& command) {
    auto it = m_impl->terminals.find(terminalId);
    if (it == m_impl->terminals.end() || !it->process) {
        return;
    }
    
    it->process->write((command + "\n").toUtf8());
}

void TerminalService::sendInput(const QString& terminalId, const QString& input) {
    auto it = m_impl->terminals.find(terminalId);
    if (it == m_impl->terminals.end() || !it->process) {
        return;
    }
    
    it->process->write(input.toUtf8());
}

QString TerminalService::getOutput(const QString& terminalId) const {
    auto it = m_impl->terminals.find(terminalId);
    if (it == m_impl->terminals.end() || !it->process) {
        return QString();
    }
    
    return QString::fromUtf8(it->process->readAllStandardOutput());
}

QString TerminalService::getLastOutput(const QString& terminalId, int lines) const {
    // Placeholder - would need output buffering
    return QString();
}

void TerminalService::clearOutput(const QString& terminalId) {
    // Placeholder - would clear terminal
}

bool TerminalService::isTerminalRunning(const QString& terminalId) const {
    auto it = m_impl->terminals.find(terminalId);
    return it != m_impl->terminals.end() && it->isRunning;
}

void TerminalService::resize(const QString& terminalId, int rows, int cols) {
    // Placeholder - PTY resize
}
