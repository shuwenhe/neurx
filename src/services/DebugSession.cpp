#include "DebugSession.h"
#include <QUuid>
#include <QProcess>

class DebugSession::Impl {
public:
    QMap<QString, DebugSessionInfo> sessions;
    QMap<QString, QProcess*> debugAdapters;
    
    QString generateId() {
        return QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
};

DebugSession* DebugSession::instance() {
    static DebugSession s_instance;
    return &s_instance;
}

DebugSession::DebugSession()
    : m_impl(std::make_unique<Impl>()) {
}

DebugSession::~DebugSession() = default;

QString DebugSession::startDebugSession(const QString& configuration) {
    QString sessionId = m_impl->generateId();
    
    DebugSessionInfo session;
    session.id = sessionId;
    session.configuration = configuration;
    session.state = "initialized";
    
    m_impl->sessions[sessionId] = session;
    
    emit sessionStarted(sessionId);
    return sessionId;
}

void DebugSession::stopDebugSession(const QString& sessionId) {
    auto it = m_impl->sessions.find(sessionId);
    if (it == m_impl->sessions.end()) {
        return;
    }
    
    auto adapterIt = m_impl->debugAdapters.find(sessionId);
    if (adapterIt != m_impl->debugAdapters.end()) {
        auto process = adapterIt.value();
        process->terminate();
        if (!process->waitForFinished(3000)) {
            process->kill();
        }
        delete process;
        m_impl->debugAdapters.erase(adapterIt);
    }
    
    m_impl->sessions.erase(it);
    emit sessionStopped(sessionId);
}

bool DebugSession::pause(const QString& sessionId) {
    auto it = m_impl->sessions.find(sessionId);
    if (it == m_impl->sessions.end()) {
        return false;
    }
    
    it->state = "stopped";
    emit sessionPaused(sessionId);
    return true;
}

bool DebugSession::continue_(const QString& sessionId) {
    auto it = m_impl->sessions.find(sessionId);
    if (it == m_impl->sessions.end()) {
        return false;
    }
    
    it->state = "running";
    emit sessionContinued(sessionId);
    return true;
}

bool DebugSession::stepOver(const QString& sessionId) {
    // Send step-over request to debug adapter
    return true;
}

bool DebugSession::stepInto(const QString& sessionId) {
    // Send step-into request to debug adapter
    return true;
}

bool DebugSession::stepOut(const QString& sessionId) {
    // Send step-out request to debug adapter
    return true;
}

void DebugSession::setBreakpoint(const QString& sessionId, const Breakpoint& breakpoint) {
    auto it = m_impl->sessions.find(sessionId);
    if (it == m_impl->sessions.end()) {
        return;
    }
    
    Breakpoint bp = breakpoint;
    bp.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    it->breakpoints.append(bp);
}

void DebugSession::removeBreakpoint(const QString& sessionId, const QString& breakpointId) {
    auto it = m_impl->sessions.find(sessionId);
    if (it == m_impl->sessions.end()) {
        return;
    }
    
    it->breakpoints.erase(
        std::remove_if(it->breakpoints.begin(), it->breakpoints.end(),
                      [&breakpointId](const Breakpoint& bp) {
                          return bp.id == breakpointId;
                      }),
        it->breakpoints.end()
    );
}

void DebugSession::updateBreakpoint(const QString& sessionId, const Breakpoint& breakpoint) {
    auto it = m_impl->sessions.find(sessionId);
    if (it == m_impl->sessions.end()) {
        return;
    }
    
    for (auto& bp : it->breakpoints) {
        if (bp.id == breakpoint.id) {
            bp = breakpoint;
            return;
        }
    }
}

QList<Breakpoint> DebugSession::getBreakpoints(const QString& sessionId) const {
    auto it = m_impl->sessions.find(sessionId);
    return it != m_impl->sessions.end() ? it->breakpoints : QList<Breakpoint>();
}

QList<StackFrame> DebugSession::getStackTrace(const QString& sessionId) const {
    // Request stackTrace from debug adapter
    return QList<StackFrame>();
}

QList<Variable> DebugSession::getVariables(const QString& sessionId, int frameId) const {
    // Request variables from debug adapter
    return QList<Variable>();
}

QString DebugSession::evaluateExpression(const QString& sessionId, const QString& expression) {
    // Send evaluate request to debug adapter
    return QString();
}

QString DebugSession::getSessionState(const QString& sessionId) const {
    auto it = m_impl->sessions.find(sessionId);
    return it != m_impl->sessions.end() ? it->state : QString();
}

QList<DebugSessionInfo> DebugSession::getActiveSessions() const {
    return m_impl->sessions.values();
}
