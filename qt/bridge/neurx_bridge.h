#pragma once

#include <QString>

class NeurxBridge {
public:
    QString ping() const;
    QString run_agent(const QString& prompt, int max_steps) const;

private:
    QString find_repo_root() const;
    QString run_agent_probe(const QString& repo_root) const;
    QString run_python_script(const QString& repo_root, const QString& script, const QStringList& args, int timeout_ms) const;
};
