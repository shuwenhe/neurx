#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QVariant>

/**
 * @class DebugSession
 * @brief Debug adapter protocol (DAP) client
 * 
 * Features:
 * - Debug session management
 * - Breakpoints
 * - Stack trace
 * - Variables inspection
 * - Evaluation
 */

struct Breakpoint {
    QString id;
    QString file;
    int line = 0;
    int column = 0;
    QString condition;
    QString hitCondition;
    bool verified = false;
};

struct StackFrame {
    int id = 0;
    QString name;
    QString file;
    int line = 0;
    int column = 0;
};

struct Variable {
    QString name;
    QString value;
    QString type;
    int variablesReference = 0;
};

struct DebugSessionInfo {
    QString id;
    QString configuration;
    QString program;
    QString state;  // "initialized", "running", "stopped", "exited"
    QList<Breakpoint> breakpoints;
};

class DebugSession : public QObject {
    Q_OBJECT

public:
    static DebugSession* instance();
    
    // Session management
    QString startDebugSession(const QString& configuration);
    void stopDebugSession(const QString& sessionId);
    
    // Control
    bool pause(const QString& sessionId);
    bool continue_(const QString& sessionId);
    bool stepOver(const QString& sessionId);
    bool stepInto(const QString& sessionId);
    bool stepOut(const QString& sessionId);
    
    // Breakpoints
    void setBreakpoint(const QString& sessionId, const Breakpoint& breakpoint);
    void removeBreakpoint(const QString& sessionId, const QString& breakpointId);
    void updateBreakpoint(const QString& sessionId, const Breakpoint& breakpoint);
    QList<Breakpoint> getBreakpoints(const QString& sessionId) const;
    
    // Stack and variables
    QList<StackFrame> getStackTrace(const QString& sessionId) const;
    QList<Variable> getVariables(const QString& sessionId, int frameId) const;
    QString evaluateExpression(const QString& sessionId, const QString& expression);
    
    // Query
    QString getSessionState(const QString& sessionId) const;
    QList<DebugSessionInfo> getActiveSessions() const;

signals:
    void sessionStarted(const QString& sessionId);
    void sessionStopped(const QString& sessionId);
    void sessionPaused(const QString& sessionId);
    void sessionContinued(const QString& sessionId);
    void breakpointHit(const QString& sessionId, const Breakpoint& breakpoint);
    void stackTraceUpdated(const QString& sessionId);
    void variablesUpdated(const QString& sessionId);
    void sessionError(const QString& sessionId, const QString& error);

private:
    DebugSession();
    ~DebugSession() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
