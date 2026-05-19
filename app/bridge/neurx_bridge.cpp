#include "bridge/neurx_bridge.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QTemporaryFile>
#include <QStandardPaths>
#include <QThread>
#include <QVariantMap>
#include <QtConcurrent/QtConcurrentRun>

namespace {
constexpr const char kDefaultOllamaModel[] = "qwen2.5:0.5b";
constexpr const char kCheckpointRunName[] = "run_20260518_001";
constexpr int kOllamaInstallTimeoutMs = 30 * 60 * 1000;
constexpr int kOllamaPullTimeoutMs = 30 * 60 * 1000;

bool run_diag_enabled() {
    const QString v = qEnvironmentVariable("NEURX_AGENT_DEBUG_RUN").trimmed().toLower();
    return v == "1" || v == "true" || v == "yes" || v == "on";
}
}

NeurxBridge::NeurxBridge(QObject* parent)
    : QObject(parent) {
    const QString env_enabled = qEnvironmentVariable("NEURX_LLM_ENABLED");
    const QString env_backend = qEnvironmentVariable("NEURX_LLM_BACKEND");
    const QString env_base_url = qEnvironmentVariable("NEURX_LLM_BASE_URL");
    const QString env_name = qEnvironmentVariable("NEURX_LLM_MODEL");
    const QString env_chat_path = qEnvironmentVariable("NEURX_LLM_CHAT_PATH");
    const QString env_checkpoint_root = qEnvironmentVariable("NEURX_BACKEND_CHECKPOINT_ROOT");
    const QString env_checkpoint_file = qEnvironmentVariable("NEURX_BACKEND_CHECKPOINT_FILE");

    checkpoint_models_root_ = env_checkpoint_root.trimmed();
    if (checkpoint_models_root_.isEmpty()) {
        const QString repo_root = find_repo_root();
        if (!repo_root.isEmpty()) {
            const QString inferred = QDir(repo_root).filePath("artifacts/checkpoints");
            if (QFileInfo::exists(inferred) && QFileInfo(inferred).isDir()) {
                checkpoint_models_root_ = QDir(inferred).absolutePath();
            }
        }
    }
    if (checkpoint_models_root_.isEmpty()) {
        QDir dir(QDir::currentPath());
        for (int i = 0; i < 8; ++i) {
            const QString inferred = dir.filePath("artifacts/checkpoints");
            if (QFileInfo::exists(inferred) && QFileInfo(inferred).isDir()) {
                checkpoint_models_root_ = QDir(inferred).absolutePath();
                break;
            }
            if (!dir.cdUp()) {
                break;
            }
        }
    }
    checkpoint_model_file_ = resolve_checkpoint_file(checkpoint_models_root_, env_checkpoint_file.trimmed());
    if (!checkpoint_models_root_.isEmpty()) {
        const QDir root_dir(checkpoint_models_root_);
        const QString run_root = root_dir.filePath(kCheckpointRunName);
        if (QFileInfo::exists(run_root) && QFileInfo(run_root).isDir()) {
            checkpoint_models_root_ = QDir(run_root).absolutePath();
            checkpoint_model_file_ = resolve_checkpoint_file(checkpoint_models_root_, env_checkpoint_file.trimmed());
        }
    }
    checkpoint_model_choices_ = checkpoint_choices_for_qml();

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
        local_model_base_url_ = !checkpoint_model_file_.isEmpty()
            ? "http://127.0.0.1:18080"
            : local_model_backend_ == "ollama"
            ? "http://127.0.0.1:11434"
            : "http://127.0.0.1:8000";
    }
    if (!env_name.trimmed().isEmpty()) {
        local_model_name_ = env_name.trimmed();
    } else if (!checkpoint_model_file_.isEmpty()) {
        local_model_name_ = checkpoint_model_file_;
    } else if (local_model_backend_ == "ollama") {
        local_model_name_ = kDefaultOllamaModel;
    }
    if (!env_chat_path.trimmed().isEmpty()) {
        local_model_chat_path_ = env_chat_path.trimmed();
    } else if (!checkpoint_model_file_.isEmpty()) {
        local_model_chat_path_ = "/neurx/api/chat";
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
        if (!checkpoint_model_file_.isEmpty()) {
            local_model_backend_ = "openai";
            local_model_base_url_ = "http://127.0.0.1:18080";
            local_model_name_ = checkpoint_model_file_;
            local_model_chat_path_ = "/neurx/api/chat";
        } else {
            local_model_backend_ = "ollama";
            local_model_base_url_ = "http://127.0.0.1:11434";
            local_model_name_ = kDefaultOllamaModel;
            local_model_chat_path_ = local_model_default_chat_path();
        }
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
        local_model_chat_path_ = !checkpoint_model_file_.isEmpty() ? "/neurx/api/chat" : local_model_default_chat_path();
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

QString NeurxBridge::ensure_local_openai_backend(const QString& repo_root) {
    if (local_model_backend_ != "openai") {
        return QString();
    }

    const QString base_url = local_model_base_url_.trimmed();
    if (!(base_url.contains("127.0.0.1:18080") || base_url.contains("localhost:18080"))) {
        return QString();
    }

    const QString curl = QStandardPaths::findExecutable("curl");
    if (curl.isEmpty()) {
        return "runtime_exec_failed: curl not found";
    }

    QString health_url = base_url;
    if (health_url.endsWith('/')) {
        health_url.chop(1);
    }
    health_url = health_url + "/neurx/health";

    const QString health_probe = run_process(
        curl,
        {"-sS", "--connect-timeout", "1", "--max-time", "2", health_url},
        5000);
    if (!health_probe.startsWith("runtime_")) {
        return QString();
    }

    const QString node = QStandardPaths::findExecutable("node");
    if (node.isEmpty()) {
        return "runtime_exec_failed: node not found";
    }

    const QString backend_dir = QDir(repo_root).filePath("app/web/backend");
    const QFileInfo server_file(QDir(backend_dir).filePath("server.mjs"));
    if (!server_file.exists() || !server_file.isFile()) {
        return "runtime_exec_failed: backend server.mjs not found";
    }

    emit log_message("info", "bridge", "Starting local NeurX backend on 127.0.0.1:18080");
    const bool started = QProcess::startDetached(node, {"server.mjs"}, backend_dir);
    if (!started) {
        return "runtime_exec_failed: failed to start local backend";
    }

    for (int attempt = 0; attempt < 10; ++attempt) {
        QThread::msleep(300);
        const QString probe = run_process(
            curl,
            {"-sS", "--connect-timeout", "1", "--max-time", "2", health_url},
            5000);
        if (!probe.startsWith("runtime_")) {
            return QString();
        }
    }

    return "runtime_timeout: local backend did not become ready";
}

QString NeurxBridge::run_local_model_agent(const QString& prompt, int max_steps) const {
    if (!local_model_enabled_) {
        return "local_model_config_missing: disabled";
    }

    const QString base_url = local_model_base_url_.trimmed();
    const QString chat_path = local_model_chat_path_.trimmed();
    const QString model_name = local_model_name_.trimmed();
    if (base_url.isEmpty() || chat_path.isEmpty() || model_name.isEmpty()) {
        return "local_model_config_missing: base_url, chat_path, or model";
    }

    const QString curl = QStandardPaths::findExecutable("curl");
    if (curl.isEmpty()) {
        return "runtime_exec_failed: curl not found";
    }

    QString url = base_url;
    if (url.endsWith('/')) {
        url.chop(1);
    }
    QString path = chat_path;
    if (!path.startsWith('/')) {
        path.prepend('/');
    }
    url = url + path;

    QJsonObject request_json;
    request_json.insert("model", model_name);
    QJsonObject user_message;
    user_message.insert("role", "user");
    user_message.insert("content", prompt);
    QJsonArray messages;
    messages.append(user_message);
    request_json.insert("messages", messages);
    request_json.insert("max_tokens", max_steps);

    const QString payload = QString::fromUtf8(QJsonDocument(request_json).toJson(QJsonDocument::Compact));
    const QString raw = run_process(
        curl,
        {"-sS", "--connect-timeout", "2", "--max-time", "10", "-X", "POST", "-H", "Content-Type: application/json", "--data", payload, url},
        120000);
    if (raw.startsWith("runtime_")) {
        return raw;
    }

    QJsonParseError parse_error;
    const QJsonDocument response_json = QJsonDocument::fromJson(raw.toUtf8(), &parse_error);
    if (parse_error.error != QJsonParseError::NoError || !response_json.isObject()) {
        return QString("local_model_parse_failed: %1").arg(raw.left(200));
    }

    const QJsonObject response = response_json.object();
    QString content = response.value("content").toString();
    if (content.isEmpty()) {
        content = response.value("completion").toString();
    }
    if (content.isEmpty() && response.value("choices").isArray()) {
        const QJsonArray choices = response.value("choices").toArray();
        if (!choices.isEmpty() && choices.first().isObject()) {
            const QJsonObject message = choices.first().toObject().value("message").toObject();
            content = message.value("content").toString();
        }
    }

    QString backend = response.value("backend").toString();
    if (backend.isEmpty()) {
        backend = response.value("backend_name").toString();
    }
    if (backend.isEmpty()) {
        backend = local_model_backend_;
    }

    QString model = response.value("model").toString();
    if (model.isEmpty()) {
        model = response.value("model_name").toString();
    }
    if (model.isEmpty()) {
        model = model_name;
    }

    int steps = response.value("steps").toInt(max_steps);
    if (steps <= 0) {
        steps = max_steps;
    }

    QJsonObject normalized;
    normalized.insert("backend", backend);
    normalized.insert("model", model);
    normalized.insert("steps", steps);
    normalized.insert("content", content);
    if (response.contains("checkpoint_step")) {
        normalized.insert("checkpoint_step", response.value("checkpoint_step"));
    }
    if (response.contains("artifact_root")) {
        normalized.insert("artifact_root", response.value("artifact_root"));
    }
    if (response.contains("checkpoint_file")) {
        normalized.insert("checkpoint_file", response.value("checkpoint_file"));
    }
    if (response.contains("checkpoint_runtime_layer_states")) {
        normalized.insert("checkpoint_runtime_layer_states", response.value("checkpoint_runtime_layer_states"));
    }
    return QString::fromUtf8(QJsonDocument(normalized).toJson(QJsonDocument::Compact));
}

QString NeurxBridge::local_model_summary() const {
    if (!local_model_enabled_) {
        return "disabled";
    }
    if (local_model_base_url_.trimmed().isEmpty() || local_model_name_.trimmed().isEmpty()) {
        return "enabled config_missing";
    }
    return QString("enabled backend=%1 base_url=%2 model=%3 path=%4 checkpoints=%5")
        .arg(local_model_backend_)
        .arg(local_model_base_url_)
        .arg(local_model_name_)
        .arg(local_model_chat_path_)
        .arg(checkpoint_model_choices_.size());
}

QString NeurxBridge::checkpoint_models_root() const {
    return checkpoint_models_root_;
}

QString NeurxBridge::checkpoint_model_file() const {
    return checkpoint_model_file_;
}

QStringList NeurxBridge::scan_checkpoint_files(const QString& root) const {
    QStringList files;
    if (root.trimmed().isEmpty()) {
        return files;
    }

    QDirIterator iterator(root, {"*.neurx"}, QDir::Files, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        files.append(QDir::cleanPath(iterator.next()));
    }
    files.sort();
    return files;
}

QString NeurxBridge::resolve_latest_checkpoint_file(const QString& root) const {
    const QStringList files = scan_checkpoint_files(root);
    if (files.isEmpty()) {
        return QString();
    }

    QString best_file;
    QDateTime best_time;
    for (const QString& file : files) {
        const QFileInfo info(file);
        const QDateTime modified = info.lastModified();
        if (best_file.isEmpty() || modified > best_time) {
            best_file = file;
            best_time = modified;
        }
    }
    return best_file;
}

QString NeurxBridge::resolve_checkpoint_file(const QString& root, const QString& explicit_file) const {
    const QString explicit_next = explicit_file.trimmed();
    if (!explicit_next.isEmpty()) {
        const QFileInfo explicit_info(explicit_next);
        if (explicit_info.exists() && explicit_info.isFile() && explicit_next.endsWith(".neurx")) {
            return QDir::cleanPath(explicit_info.absoluteFilePath());
        }
        if (explicit_info.exists() && explicit_info.isDir()) {
            const QStringList files = scan_checkpoint_files(explicit_info.absoluteFilePath());
            if (!files.isEmpty()) {
                return files.constLast();
            }
        }
    }

    const QString trimmed_root = root.trimmed();
    if (trimmed_root.isEmpty()) {
        return QString();
    }

    const QStringList files = scan_checkpoint_files(trimmed_root);
    if (files.isEmpty()) {
        return QString();
    }
    return resolve_latest_checkpoint_file(trimmed_root);
}

QVariantList NeurxBridge::checkpoint_choices_for_qml() const {
    QVariantList choices;
    const QString latest = resolve_latest_checkpoint_file(checkpoint_models_root_);
    if (latest.isEmpty()) {
        return choices;
    }

    const QString relative = checkpoint_models_root_.isEmpty()
        ? QFileInfo(latest).fileName()
        : QDir(checkpoint_models_root_).relativeFilePath(latest);
    QVariantMap entry;
    entry.insert("text", relative);
    entry.insert("value", latest);
    entry.insert("checkpoint_file", latest);
    entry.insert("checkpoint_root", checkpoint_models_root_);
    entry.insert("latest", true);
    choices.append(entry);
    return choices;
}

void NeurxBridge::refresh_checkpoint_model_state() {
    if (checkpoint_models_root_.trimmed().isEmpty()) {
        return;
    }

    const QString latest = resolve_latest_checkpoint_file(checkpoint_models_root_);
    if (latest.isEmpty()) {
        return;
    }

    checkpoint_model_file_ = latest;
    checkpoint_model_choices_ = checkpoint_choices_for_qml();

    if (local_model_enabled_ && local_model_backend_ == "openai") {
        local_model_name_ = latest;
        if (local_model_base_url_.trimmed().isEmpty()) {
            local_model_base_url_ = "http://127.0.0.1:18080";
        }
        if (local_model_chat_path_.trimmed().isEmpty() || local_model_chat_path_ == "/v1/chat/completions") {
            local_model_chat_path_ = "/neurx/api/chat";
        }
    }

    emit localModelConfigChanged();
}

QVariantList NeurxBridge::checkpoint_model_choices() const {
    return checkpoint_model_choices_;
}

QString NeurxBridge::run_agent(const QString& prompt, int max_steps) {
    static int run_seq = 0;
    run_seq += 1;

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

    if (run_diag_enabled()) {
        emit log_message("info", "bridge", QString("run_agent seq=%1 steps=%2 prompt_len=%3")
            .arg(run_seq)
            .arg(steps)
            .arg(prompt.size()));
    }

    refresh_checkpoint_model_state();

    if (local_model_enabled_ && !local_model_base_url_.trimmed().isEmpty() && !local_model_name_.trimmed().isEmpty()) {
        const QString backend_ready = ensure_local_openai_backend(root);
        if (!backend_ready.isEmpty()) {
            emit log_message("warning", "bridge", QString("local backend startup failed: %1").arg(backend_ready));
            emit runtime_status_changed("local-backend-failed", local_model_name_);
            return backend_ready;
        }

        const bool allow_ollama_bootstrap = qEnvironmentVariableIntValue("NEURX_AUTO_BOOTSTRAP_OLLAMA") == 1;
        if (local_model_backend_ == "ollama" && !local_ollama_ready_ && allow_ollama_bootstrap) {
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
                QString result = QString("local_ok backend=%1 model=%2 steps=%3")
                    .arg(obj.value("backend").toString())
                    .arg(obj.value("model").toString())
                    .arg(obj.value("steps").toInt(steps));
                const QString checkpoint_file = obj.value("checkpoint_file").toString();
                if (!checkpoint_file.isEmpty()) {
                    result = result + "\ncheckpoint_file=" + checkpoint_file;
                }
                if (obj.contains("checkpoint_step")) {
                    result = result + "\ncheckpoint_step=" + QString::number(obj.value("checkpoint_step").toInt(-1));
                }
                result = result + "\n" + content;
                if (run_diag_enabled()) {
                    emit log_message("info", "bridge", QString("run_agent seq=%1 completed local-json").arg(run_seq));
                }
                emit log_message("info", "agent", result);
                emit runtime_status_changed("local-model", local_model_name_);
                return result;
            }

            if (run_diag_enabled()) {
                emit log_message("info", "bridge", QString("run_agent seq=%1 completed local-text").arg(run_seq));
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
    if (run_diag_enabled()) {
        emit log_message("info", "bridge", QString("run_agent seq=%1 completed probe").arg(run_seq));
    }
    emit log_message("info", "agent", result);
    emit runtime_status_changed("s-runtime", "probe");
    return result;
}

QString NeurxBridge::run_code_assistant(const QString& prompt, const QString& filePath) {
    // Post to local backend /neurx/api/agent/suggest with optional file context
    QString url = local_model_base_url_.trimmed();
    if (url.isEmpty()) {
        url = "http://127.0.0.1:18080";
    }
    if (!url.endsWith('/')) {
        url += '/';
    }
    url += "neurx/api/agent/suggest";

    QJsonObject payload;
    payload.insert("prompt", prompt);
    if (!filePath.trimmed().isEmpty()) {
        payload.insert("filePath", filePath.trimmed());
    }
    if (!local_model_name_.trimmed().isEmpty()) {
        payload.insert("model", local_model_name_.trimmed());
    }
    payload.insert("maxTokens", 128);

    QJsonDocument doc(payload);
    QByteArray body = doc.toJson(QJsonDocument::Compact);

    QTemporaryFile tmp;
    tmp.setAutoRemove(true);
    if (!tmp.open()) {
        return QString("runtime_exec_failed: could not create temp file");
    }
    tmp.write(body);
    tmp.flush();
    tmp.close();

    const QString curlResult = run_process("curl", QStringList()
        << "-s" << "-X" << "POST" << "-H" << "Content-Type: application/json"
        << "--data-binary" << ("@" + tmp.fileName()) << url, 120000);

    return curlResult;
}

void NeurxBridge::run_agent_async(const QString& prompt, int max_steps) {
    if (agent_run_active_) {
        emit log_message("warning", "agent", "agent run already in progress");
        emit runtime_status_changed("busy", local_model_name_);
        return;
    }

    agent_run_active_ = true;
    emit runtime_status_changed("running", local_model_name_);

    auto* watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher]() {
        const QString result = watcher->result();
        watcher->deleteLater();
        agent_run_active_ = false;
        emit agentRunFinished(result);
    });

    watcher->setFuture(QtConcurrent::run([this, prompt, max_steps]() {
        return run_agent(prompt, max_steps);
    }));
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
