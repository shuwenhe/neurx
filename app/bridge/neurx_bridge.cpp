#include "bridge/neurx_bridge.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>
#include <QThread>

namespace {
constexpr const char kDefaultOllamaModel[] = "qwen2.5:0.5b";
constexpr int kOllamaInstallTimeoutMs = 30 * 60 * 1000;
constexpr int kOllamaPullTimeoutMs = 30 * 60 * 1000;
}

NeurxBridge::NeurxBridge(QObject* parent)
    : QObject(parent) {
    const QString env_enabled = qEnvironmentVariable("NEURX_LLM_ENABLED");
    const QString env_backend = qEnvironmentVariable("NEURX_LLM_BACKEND");
    const QString env_base_url = qEnvironmentVariable("NEURX_LLM_BASE_URL");
    const QString env_name = qEnvironmentVariable("NEURX_LLM_MODEL");
    const QString env_chat_path = qEnvironmentVariable("NEURX_LLM_CHAT_PATH");

    if (!env_enabled.isEmpty()) {
        const QString lowered = env_enabled.trimmed().toLower();
        local_model_enabled_ = lowered == "1" || lowered == "true" || lowered == "yes" || lowered == "on";
    } else {
        local_model_enabled_ = !env_base_url.trimmed().isEmpty();
    }

    if (!env_backend.trimmed().isEmpty()) {
        local_model_backend_ = normalize_local_model_backend(env_backend);
    }
    if (!env_base_url.trimmed().isEmpty()) {
        local_model_base_url_ = env_base_url.trimmed();
    } else {
        local_model_base_url_ = local_model_backend_ == "ollama"
            ? "http://127.0.0.1:11434"
            : "http://127.0.0.1:8000";
    }
    if (!env_name.trimmed().isEmpty()) {
        local_model_name_ = env_name.trimmed();
    } else if (local_model_backend_ == "ollama") {
        local_model_name_ = kDefaultOllamaModel;
    }
    if (!env_chat_path.trimmed().isEmpty()) {
        local_model_chat_path_ = env_chat_path.trimmed();
    } else {
        local_model_chat_path_ = local_model_default_chat_path();
    }

    const bool default_local_setup = env_enabled.trimmed().isEmpty()
        && env_backend.trimmed().isEmpty()
        && env_base_url.trimmed().isEmpty()
        && env_name.trimmed().isEmpty()
        && env_chat_path.trimmed().isEmpty();
    if (default_local_setup) {
        local_model_enabled_ = true;
        local_model_backend_ = "ollama";
        local_model_base_url_ = "http://127.0.0.1:11434";
        local_model_name_ = kDefaultOllamaModel;
        local_model_chat_path_ = local_model_default_chat_path();
    }
}

QString NeurxBridge::normalize_local_model_backend(const QString& backend) const {
    const QString lowered = backend.trimmed().toLower();
    if (lowered == "ollama") {
        return "ollama";
    }
    return "openai";
}

QString NeurxBridge::local_model_default_chat_path() const {
    if (local_model_backend_ == "ollama") {
        return "/api/chat";
    }
    return "/v1/chat/completions";
}

bool NeurxBridge::local_model_enabled() const {
    return local_model_enabled_;
}

void NeurxBridge::set_local_model_enabled(bool enabled) {
    if (local_model_enabled_ == enabled) {
        return;
    }
    local_model_enabled_ = enabled;
    emit localModelConfigChanged();
}

QString NeurxBridge::local_model_backend() const {
    return local_model_backend_;
}

void NeurxBridge::set_local_model_backend(const QString& backend) {
    const QString normalized = normalize_local_model_backend(backend);
    if (local_model_backend_ == normalized) {
        return;
    }
    local_model_backend_ = normalized;
    local_ollama_ready_ = false;
    if (local_model_backend_ == "ollama" && (local_model_name_.isEmpty() || local_model_name_ == "local-model")) {
        local_model_name_ = kDefaultOllamaModel;
    }
    if (local_model_chat_path_.isEmpty() || local_model_chat_path_ == "/v1/chat/completions" || local_model_chat_path_ == "/api/chat") {
        local_model_chat_path_ = local_model_default_chat_path();
    }
    emit localModelConfigChanged();
}

QString NeurxBridge::local_model_base_url() const {
    return local_model_base_url_;
}

void NeurxBridge::set_local_model_base_url(const QString& base_url) {
    const QString next = base_url.trimmed();
    if (local_model_base_url_ == next) {
        return;
    }
    local_model_base_url_ = next;
    emit localModelConfigChanged();
}

QString NeurxBridge::local_model_name() const {
    return local_model_name_;
}

void NeurxBridge::set_local_model_name(const QString& name) {
    const QString next = name.trimmed();
    if (local_model_name_ == next) {
        return;
    }
    local_model_name_ = next;
    local_ollama_ready_ = false;
    emit localModelConfigChanged();
}

QString NeurxBridge::local_model_chat_path() const {
    return local_model_chat_path_;
}

void NeurxBridge::set_local_model_chat_path(const QString& chat_path) {
    const QString next = chat_path.trimmed();
    if (local_model_chat_path_ == next) {
        return;
    }
    local_model_chat_path_ = next;
    emit localModelConfigChanged();
}

QString NeurxBridge::run_process(const QString& program, const QStringList& args, int timeout_ms, const QString& working_dir) const {
    QProcess proc;
    proc.setProgram(program);
    proc.setArguments(args);
    if (!working_dir.isEmpty()) {
        proc.setWorkingDirectory(working_dir);
    }
    proc.start();

    if (!proc.waitForStarted(10000)) {
        return QString("runtime_exec_failed: failed to start %1").arg(program);
    }

    if (!proc.waitForFinished(timeout_ms)) {
        proc.kill();
        proc.waitForFinished(5000);
        return QString("runtime_timeout: %1").arg(program);
    }

    const QString stdout_text = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    const QString stderr_text = QString::fromUtf8(proc.readAllStandardError()).trimmed();

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        if (!stderr_text.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(stderr_text.left(200));
        }
        if (!stdout_text.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(stdout_text.left(200));
        }
        return QString("runtime_exec_failed: %1").arg(program);
    }

    return stdout_text;
}

QString NeurxBridge::ollama_command() const {
    const QString from_path = QStandardPaths::findExecutable("ollama");
    if (!from_path.isEmpty()) {
        return from_path;
    }

#ifdef Q_OS_WIN
    const QString local_app_data = qEnvironmentVariable("LOCALAPPDATA");
    if (!local_app_data.isEmpty()) {
        const QString local_program = QDir(local_app_data).filePath("Programs/Ollama/ollama.exe");
        if (QFileInfo::exists(local_program)) {
            return local_program;
        }
    }
#endif

    return QString();
}

QString NeurxBridge::bootstrap_ollama_model() {
    QString command = ollama_command();

    if (command.isEmpty()) {
#ifdef Q_OS_WIN
        emit log_message("info", "bridge", "Ollama was not found. Installing it now.");
        const QString install_result = run_process(
            "powershell.exe",
            {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://ollama.com/install.ps1 | iex"},
            kOllamaInstallTimeoutMs);
        if (install_result.startsWith("runtime_")) {
            return install_result;
        }
#else
        emit log_message("info", "bridge", "Ollama was not found. Installing it now.");
        const QString install_result = run_process(
            "/bin/sh",
            {"-lc", "curl -fsSL https://ollama.com/install.sh | sh"},
            kOllamaInstallTimeoutMs);
        if (install_result.startsWith("runtime_")) {
            return install_result;
        }
#endif

        for (int attempt = 0; attempt < 30; ++attempt) {
            command = ollama_command();
            if (!command.isEmpty()) {
                break;
            }
            QThread::msleep(2000);
        }

        if (command.isEmpty()) {
            return "runtime_exec_failed: ollama install completed but the CLI was not found";
        }
    }

    if (local_model_name_.trimmed().isEmpty() || local_model_name_ == "local-model") {
        local_model_name_ = kDefaultOllamaModel;
        emit localModelConfigChanged();
    }

    emit log_message("info", "bridge", QString("Pulling Ollama model %1").arg(local_model_name_));
    const QString pull_result = run_process(command, {"pull", local_model_name_}, kOllamaPullTimeoutMs);
    if (pull_result.startsWith("runtime_")) {
        return pull_result;
    }

    local_ollama_ready_ = true;
    return QString();
}

QString NeurxBridge::find_repo_root() const {
    QString candidate = qEnvironmentVariable("NEURX_ROOT");
    if (!candidate.isEmpty()) {
        const QFileInfo serving_file(QDir(candidate).filePath("serving/serve/serve.s"));
        const QFileInfo makefile(QDir(candidate).filePath("Makefile"));
        if (serving_file.exists() && serving_file.isFile() && makefile.exists() && makefile.isFile()) {
            return QDir(candidate).absolutePath();
        }
    }

    QDir dir(QDir::currentPath());
    for (int i = 0; i < 8; ++i) {
        const QFileInfo serving_file(dir.filePath("serving/serve/serve.s"));
        const QFileInfo makefile(dir.filePath("Makefile"));
        if (serving_file.exists() && serving_file.isFile() && makefile.exists() && makefile.isFile()) {
            return dir.absolutePath();
        }
        if (!dir.cdUp()) {
            break;
        }
    }
    return QString();
}

QString NeurxBridge::run_agent_probe(const QString& repo_root) const {
    Q_UNUSED(repo_root);
    return "s_runtime_ready";
}

QString NeurxBridge::run_local_model_agent(const QString& prompt, int max_steps) const {
    Q_UNUSED(prompt);
    Q_UNUSED(max_steps);
    return "runtime_exec_failed: local_model_bridge_removed";
}

QString NeurxBridge::local_model_summary() const {
    if (!local_model_enabled_) {
        return "disabled";
    }
    if (local_model_base_url_.trimmed().isEmpty() || local_model_name_.trimmed().isEmpty()) {
        return "enabled config_missing";
    }
    return QString("enabled backend=%1 base_url=%2 model=%3 path=%4")
        .arg(local_model_backend_)
        .arg(local_model_base_url_)
        .arg(local_model_name_)
        .arg(local_model_chat_path_);
}

QString NeurxBridge::run_agent(const QString& prompt, int max_steps) {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        emit log_message("error", "bridge", "Repository root was not found");
        emit runtime_status_changed("repo_not_found", "bootstrap");
        return "repo_not_found";
    }

    int steps = max_steps;
    if (steps <= 0) {
        steps = 1;
    }

    if (local_model_enabled_ && !local_model_base_url_.trimmed().isEmpty() && !local_model_name_.trimmed().isEmpty()) {
        if (local_model_backend_ == "ollama" && !local_ollama_ready_) {
            const QString bootstrap_result = bootstrap_ollama_model();
            if (!bootstrap_result.isEmpty()) {
                emit log_message("warning", "bridge", QString("Ollama bootstrap failed: %1").arg(bootstrap_result));
                emit runtime_status_changed("ollama_bootstrap_failed", local_model_name_);
            }
        }

        const QString local_result = run_local_model_agent(prompt, steps);
        if (!local_result.startsWith("runtime_") && !local_result.startsWith("local_model_config_missing")) {
            QJsonParseError local_parse_error;
            const QJsonDocument local_json = QJsonDocument::fromJson(local_result.toUtf8(), &local_parse_error);
            if (local_parse_error.error == QJsonParseError::NoError && local_json.isObject()) {
                const QJsonObject obj = local_json.object();
                const QString content = obj.value("content").toString();
                const QString result = QString("local_ok backend=%1 model=%2 steps=%3\n%4")
                    .arg(obj.value("backend").toString())
                    .arg(obj.value("model").toString())
                    .arg(obj.value("steps").toInt(steps))
                    .arg(content);
                emit log_message("info", "agent", result);
                emit runtime_status_changed("local-model", local_model_name_);
                return result;
            }

            emit log_message("info", "agent", local_result);
            emit runtime_status_changed("local-model", local_model_name_);
            return local_result;
        }

        emit log_message("warning", "agent", QString("local model fallback: %1").arg(local_result));
        emit runtime_status_changed("local-model-fallback", local_model_name_);
    }

    Q_UNUSED(prompt);
    Q_UNUSED(steps);
    const QString result = run_agent_probe(root);
    emit log_message("info", "agent", result);
    emit runtime_status_changed("s-runtime", "probe");
    return result;
}

QString NeurxBridge::ping() {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        emit log_message("error", "bridge", "Repository root was not found");
        emit runtime_status_changed("repo_not_found", "bootstrap");
        return "repo_not_found";
    }
    const QString result = run_agent_probe(root);
    emit log_message("info", "bridge", QString("Ping result: %1").arg(result));
    emit runtime_status_changed(result, "probe");
    return result;
}
