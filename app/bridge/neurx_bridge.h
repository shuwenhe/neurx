#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class NeurxBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool localModelEnabled READ local_model_enabled WRITE set_local_model_enabled NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelBackend READ local_model_backend WRITE set_local_model_backend NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelBaseUrl READ local_model_base_url WRITE set_local_model_base_url NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelName READ local_model_name WRITE set_local_model_name NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelChatPath READ local_model_chat_path WRITE set_local_model_chat_path NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelSummary READ local_model_summary NOTIFY localModelConfigChanged)

public:
    explicit NeurxBridge(QObject* parent = nullptr);

    Q_INVOKABLE QString ping();
    Q_INVOKABLE QString run_agent(const QString& prompt, int max_steps);
    Q_INVOKABLE QString local_model_summary() const;

signals:
    void runtime_status_changed(const QString& status, const QString& task);
    void log_message(const QString& level, const QString& tag, const QString& message);
    void localModelConfigChanged();

public:
    bool local_model_enabled() const;
    void set_local_model_enabled(bool enabled);

    QString local_model_backend() const;
    void set_local_model_backend(const QString& backend);

    QString local_model_base_url() const;
    void set_local_model_base_url(const QString& base_url);

    QString local_model_name() const;
    void set_local_model_name(const QString& name);

    QString local_model_chat_path() const;
    void set_local_model_chat_path(const QString& chat_path);

private:
    QString find_repo_root() const;
    QString run_agent_probe(const QString& repo_root) const;
    QString run_python_script(const QString& repo_root, const QString& script, const QStringList& args, int timeout_ms) const;
    QString run_local_model_agent(const QString& prompt, int max_steps) const;
    QString local_model_default_chat_path() const;
    QString normalize_local_model_backend(const QString& backend) const;

    bool local_model_enabled_ {false};
    QString local_model_backend_ {"openai"};
    QString local_model_base_url_;
    QString local_model_name_ {"local-model"};
    QString local_model_chat_path_ {"/v1/chat/completions"};
};
