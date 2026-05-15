#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class NeurxBridge : public QObject {
    Q_OBJECT

public:
    explicit NeurxBridge(QObject* parent = nullptr);

    Q_INVOKABLE QString ping();
    Q_INVOKABLE QString run_agent(const QString& prompt, int max_steps);

signals:
    void runtime_status_changed(const QString& status, const QString& task);
    void log_message(const QString& level, const QString& tag, const QString& message);

private:
    QString find_repo_root() const;
    QString run_agent_probe(const QString& repo_root) const;
    QString run_python_script(const QString& repo_root, const QString& script, const QStringList& args, int timeout_ms) const;
};
