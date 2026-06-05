#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QProcess>

/**
 * @class TerminalService
 * @brief Embedded terminal service
 * 
 * Features:
 * - Multiple terminal instances
 * - Shell integration
 * - Command execution
 * - PTY support
 */

struct Terminal {
    QString id;
    QString name;
    QString shell;
    QString cwd;
    QProcess* process = nullptr;
    bool isRunning = false;
};

class TerminalService : public QObject {
    Q_OBJECT

public:
    static TerminalService* instance();
    
    // Terminal management
    QString createTerminal(const QString& name, const QString& shell = QString(), 
                          const QString& cwd = QString());
    void closeTerminal(const QString& terminalId);
    void closeAll();
    
    // Query
    QList<Terminal> getTerminals() const;
    Terminal getTerminal(const QString& terminalId) const;
    bool hasTerminal(const QString& terminalId) const;
    
    // Operations
    void sendCommand(const QString& terminalId, const QString& command);
    void sendInput(const QString& terminalId, const QString& input);
    
    // Output
    QString getOutput(const QString& terminalId) const;
    QString getLastOutput(const QString& terminalId, int lines = 100) const;
    void clearOutput(const QString& terminalId);
    
    // Control
    bool isTerminalRunning(const QString& terminalId) const;
    void resize(const QString& terminalId, int rows, int cols);

signals:
    void terminalCreated(const QString& terminalId);
    void terminalClosed(const QString& terminalId);
    void terminalOutput(const QString& terminalId, const QString& output);
    void terminalError(const QString& terminalId, const QString& error);

private:
    TerminalService();
    ~TerminalService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
