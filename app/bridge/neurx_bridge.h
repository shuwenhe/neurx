#pragma once

#include <QObject>
#include <QVariantList>
#include <QString>
#include <QStringList>
#include <QFutureWatcher>

class NeurxBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool localModelEnabled READ local_model_enabled WRITE set_local_model_enabled NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelBackend READ local_model_backend WRITE set_local_model_backend NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelBaseUrl READ local_model_base_url WRITE set_local_model_base_url NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelName READ local_model_name WRITE set_local_model_name NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelChatPath READ local_model_chat_path WRITE set_local_model_chat_path NOTIFY localModelConfigChanged)
    Q_PROPERTY(QString localModelSummary READ local_model_summary NOTIFY localModelConfigChanged)
    Q_PROPERTY(QVariantList checkpointModelChoices READ checkpoint_model_choices NOTIFY localModelConfigChanged)

public:
    explicit NeurxBridge(QObject* parent = nullptr);

    Q_INVOKABLE QString ping();
    Q_INVOKABLE QString run_agent(const QString& prompt, int max_steps);
    Q_INVOKABLE QString run_code_assistant(const QString& prompt, const QString& filePath);
    Q_INVOKABLE QString export_agent_skill_snapshot(const QString& prompt, int max_steps);
    Q_INVOKABLE QString export_agent_trajectory(const QString& prompt, int max_steps);
    Q_INVOKABLE void copy_to_clipboard(const QString& text);
    Q_INVOKABLE void run_agent_async(const QString& prompt, int max_steps);
    Q_INVOKABLE void run_code_assistant_async(const QString& prompt, const QString& filePath);
    Q_INVOKABLE void run_agent_auto_async(const QString& prompt, const QString& filePath, int max_steps);
    Q_INVOKABLE QString agent_route_for_prompt(const QString& prompt, const QString& filePath) const;
    Q_INVOKABLE QString local_model_summary() const;

signals:
    void runtime_status_changed(const QString& status, const QString& task);
    void log_message(const QString& level, const QString& tag, const QString& message);
    void agentRunFinished(const QString& result);
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

    QVariantList checkpoint_model_choices() const;

private:
    QString find_repo_root() const;
    QString run_agent_probe(const QString& repo_root) const;
    QString run_process(const QString& program, const QStringList& args, int timeout_ms, const QString& working_dir = QString()) const;
    QString run_http_request(const QString& method, const QString& url, const QString& body_file = QString(), int timeout_ms = 120000) const;
    QString ollama_command() const;
    QString bootstrap_ollama_model();
    QString ensure_local_openai_backend(const QString& repo_root);
    QString run_local_model_agent(const QString& prompt, int max_steps) const;
    QString run_code_assistant_request(const QString& prompt, const QString& filePath);
    QString run_agent_state_export(const QString& prompt, int max_steps, const QString& export_kind);
    QString local_model_default_chat_path() const;
    QString normalize_local_model_backend(const QString& backend) const;
    QString checkpoint_models_root() const;
    QString checkpoint_model_file() const;
    QString resolve_checkpoint_file(const QString& root, const QString& explicit_file) const;
    QString resolve_latest_checkpoint_file(const QString& root) const;
    QStringList scan_checkpoint_files(const QString& root) const;
    QVariantList checkpoint_choices_for_qml() const;
    void refresh_checkpoint_model_state();

    bool local_model_enabled_ {false};
    QString local_model_backend_ {"openai"};
    QString local_model_base_url_;
    QString local_model_name_ {"local-model"};
    QString local_model_chat_path_ {"/v1/chat/completions"};
    QString checkpoint_models_root_;
    QString checkpoint_model_file_;
    QVariantList checkpoint_model_choices_;
    bool agent_run_active_ {false};
    mutable bool local_ollama_ready_ {false};
};
