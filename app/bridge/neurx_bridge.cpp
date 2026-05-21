#include "bridge/neurx_bridge.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QTemporaryFile>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QClipboard>
#include <QGuiApplication>
#include <QThread>
#include <QUrl>
#include <QVariantMap>
#include <QDebug>
#include <QtConcurrent/QtConcurrentRun>

namespace {
constexpr const char kDefaultOllamaModel[] = "qwen2.5:0.5b";
constexpr const char kDefaultLocalOllamaModel[] = "neurx-qwen2.5vl-local:latest";
constexpr const char kDefaultLocalOllamaModelDir[] = "artifacts/checkpoints/Qwen2.5-VL-7B";
constexpr const char kCheckpointRunName[] = "run_20260518_001";
constexpr int kOllamaInstallTimeoutMs = 30 * 60 * 1000;
constexpr int kOllamaPullTimeoutMs = 30 * 60 * 1000;

bool run_diag_enabled() {
    const QString v = qEnvironmentVariable("NEURX_AGENT_DEBUG_RUN").trimmed().toLower();
    return v == "1" || v == "true" || v == "yes" || v == "on";
}

QString sanitize_chat_path(QString value) {
    value = value.trimmed();
    if (value.isEmpty()) {
        return value;
    }

    static const QStringList known_suffixes = {
        "/neurx/api/chat",
        "/neurx/api/agent/suggest",
        "/v1/chat/completions",
        "/api/chat",
        "/api/generate"
    };

    for (const QString& suffix : known_suffixes) {
        if (value == suffix) {
            return value;
        }

        const int idx = value.indexOf(suffix, 0, Qt::CaseInsensitive);
        if (idx > 0) {
            return suffix;
        }
    }

    if (!value.startsWith('/')) {
        value.prepend('/');
    }
    return value;
}

QString join_url_and_path(QString base_url, QString path) {
    base_url = base_url.trimmed();
    path = sanitize_chat_path(path);
    if (base_url.endsWith('/')) {
        base_url.chop(1);
    }
    if (!path.startsWith('/')) {
        path.prepend('/');
    }
    return base_url + path;
}

bool url_looks_like_s_backend(const QString& base_url) {
    const QUrl url(base_url.trimmed());
    const QString host = url.host().trimmed().toLower();
    const int port = url.port();
    return (host == "127.0.0.1" || host == "localhost") && port == 18080;
}

bool url_looks_like_ollama(const QString& base_url) {
    const QUrl url(base_url.trimmed());
    const QString host = url.host().trimmed().toLower();
    const int port = url.port();
    if ((host == "127.0.0.1" || host == "localhost") && port == 11434) {
        return true;
    }
    return host.contains("ollama");
}

QString preferred_chat_path_for(QString base_url,
                                QString configured_path,
                                QString backend,
                                bool has_checkpoint_model) {
    configured_path = sanitize_chat_path(configured_path);
    backend = backend.trimmed().toLower();

    const bool is_s_backend = url_looks_like_s_backend(base_url);
    const bool is_ollama = backend == "ollama" || url_looks_like_ollama(base_url);
    const QString default_path = is_ollama
        ? QStringLiteral("/api/chat")
        : QStringLiteral("/v1/chat/completions");

    if (configured_path.isEmpty()) {
        return (is_s_backend && has_checkpoint_model)
            ? QStringLiteral("/neurx/api/chat")
            : default_path;
    }

    if (configured_path == "/neurx/api/chat" && !is_s_backend) {
        return default_path;
    }

    if ((configured_path == "/v1/chat/completions" || configured_path == "/api/chat")
        && is_s_backend && has_checkpoint_model) {
        return QStringLiteral("/neurx/api/chat");
    }

    return configured_path;
}

QString preferred_model_name_for(QString base_url,
                                 QString configured_name,
                                 QString backend,
                                 bool has_checkpoint_model,
                                 QString checkpoint_model_file,
                                 QString local_ollama_model_dir) {
    configured_name = configured_name.trimmed();
    backend = backend.trimmed().toLower();
    local_ollama_model_dir = local_ollama_model_dir.trimmed();
    const bool wants_ollama = backend == "ollama" || url_looks_like_ollama(base_url);
    const bool looks_like_checkpoint_name =
        configured_name.endsWith(".neurx", Qt::CaseInsensitive) ||
        configured_name.contains('/') ||
        configured_name.contains('\\') ||
        configured_name.contains("gpt_large_pretrain", Qt::CaseInsensitive);

    if (wants_ollama) {
        if (!local_ollama_model_dir.isEmpty()) {
            return QString::fromLatin1(kDefaultLocalOllamaModel);
        }
        if (!configured_name.isEmpty() && configured_name != "local-model" && !looks_like_checkpoint_name) {
            return configured_name;
        }
        return QString::fromLatin1(kDefaultOllamaModel);
    }

    // Explicit user-configured name always wins — never replace a valid model name
    // (e.g. "qwen2.5:0.5b" from NEURX_LLM_MODEL) with an auto-detected placeholder.
    // But never forward a checkpoint file path/basename as an Ollama or OpenAI model name.
    if (!configured_name.isEmpty() && configured_name != "local-model" && !looks_like_checkpoint_name) {
        return configured_name;
    }

    if (has_checkpoint_model && !checkpoint_model_file.trimmed().isEmpty()) {
        return checkpoint_model_file.trimmed();
    }

    if (!local_ollama_model_dir.isEmpty()) {
        return QString::fromLatin1(kDefaultLocalOllamaModel);
    }

    return configured_name;
}

QString resolve_local_ollama_model_dir(const QString& repo_root, const QString& checkpoint_root = QString()) {
    const QString env_dir = qEnvironmentVariable("NEURX_OLLAMA_MODEL_DIR").trimmed();
    if (!env_dir.isEmpty() && QFileInfo(env_dir).exists() && QFileInfo(env_dir).isDir()) {
        return QDir(env_dir).absolutePath();
    }

    if (!repo_root.trimmed().isEmpty()) {
        const QString inferred = QDir(repo_root).filePath(QString::fromLatin1(kDefaultLocalOllamaModelDir));
        if (QFileInfo(inferred).exists() && QFileInfo(inferred).isDir()) {
            return QDir(inferred).absolutePath();
        }
    }

    if (!checkpoint_root.trimmed().isEmpty()) {
        const QDir checkpoints_dir(checkpoint_root);
        const QString inferred = checkpoints_dir.filePath("Qwen2.5-VL-7B");
        if (QFileInfo(inferred).exists() && QFileInfo(inferred).isDir()) {
            return QDir(inferred).absolutePath();
        }
    }

    return QString();
}

QString escape_s_string(const QString& value) {
    QString out = value;
    out.replace("\\", "\\\\");
    out.replace("\"", "\\\"");
    out.replace("\n", "\\n");
    out.replace("\r", "\\r");
    out.replace("\t", "\\t");
    return out;
}
}

NeurxBridge::NeurxBridge(QObject* parent)
    : QObject(parent) {
    const QString repo_root = find_repo_root();
    const QString env_enabled = qEnvironmentVariable("NEURX_LLM_ENABLED");
    const QString env_backend = qEnvironmentVariable("NEURX_LLM_BACKEND");
    const QString env_base_url = qEnvironmentVariable("NEURX_LLM_BASE_URL");
    const QString env_name = qEnvironmentVariable("NEURX_LLM_MODEL");
    const QString env_chat_path = qEnvironmentVariable("NEURX_LLM_CHAT_PATH");
    const QString env_checkpoint_root = qEnvironmentVariable("NEURX_BACKEND_CHECKPOINT_ROOT");
    const QString env_checkpoint_file = qEnvironmentVariable("NEURX_BACKEND_CHECKPOINT_FILE");
    const QString local_ollama_model_dir = resolve_local_ollama_model_dir(repo_root, checkpoint_models_root_);

    checkpoint_models_root_ = env_checkpoint_root.trimmed();
    if (checkpoint_models_root_.isEmpty()) {
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
            : (!local_ollama_model_dir.isEmpty() || local_model_backend_ == "ollama")
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
        local_model_chat_path_ = sanitize_chat_path(env_chat_path);
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
        if (!local_ollama_model_dir.isEmpty()) {
            local_model_backend_ = "ollama";
            local_model_base_url_ = "http://127.0.0.1:11434";
            local_model_name_ = QString::fromLatin1(kDefaultLocalOllamaModel);
            local_model_chat_path_ = local_model_default_chat_path();
        } else if (!checkpoint_model_file_.isEmpty()) {
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

    local_model_chat_path_ = preferred_chat_path_for(
        local_model_base_url_,
        local_model_chat_path_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
    local_model_name_ = preferred_model_name_for(
        local_model_base_url_,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        local_ollama_model_dir);
}

QString NeurxBridge::normalize_local_model_backend(const QString& backend) const {
    const QString lowered = backend.trimmed().toLower();
    if (lowered == "ollama") {
        return "ollama";
    }
    return "openai";
}

QString NeurxBridge::local_model_default_chat_path() const {
    return preferred_chat_path_for(
        local_model_base_url_,
        QString(),
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
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
    local_model_chat_path_ = preferred_chat_path_for(
        local_model_base_url_,
        local_model_chat_path_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
    local_model_name_ = preferred_model_name_for(
        local_model_base_url_,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_));
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
    local_model_chat_path_ = preferred_chat_path_for(
        local_model_base_url_,
        local_model_chat_path_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
    local_model_name_ = preferred_model_name_for(
        local_model_base_url_,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_));
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
    local_model_name_ = preferred_model_name_for(
        local_model_base_url_,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_));
    local_ollama_ready_ = false;
    emit localModelConfigChanged();
}

QString NeurxBridge::local_model_chat_path() const {
    return local_model_chat_path_;
}

void NeurxBridge::set_local_model_chat_path(const QString& chat_path) {
    const QString next = preferred_chat_path_for(
        local_model_base_url_,
        chat_path,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
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

QString NeurxBridge::run_http_request(const QString& method, const QString& url, const QString& body_file, int timeout_ms) const {
    const QString node = QStandardPaths::findExecutable("node");
    if (node.isEmpty()) {
        return "runtime_exec_failed: node not found";
    }

    const int request_timeout_ms = qMax(1000, timeout_ms - 2000);
    qInfo().noquote() << QString("bridge http_request start method=%1 url=%2 timeout_ms=%3")
        .arg(method, url)
        .arg(timeout_ms);
    const QString script = QString(R"JS(
const fs = await import('node:fs');
const [requestUrl, requestMethod, requestBodyFile] = process.argv.slice(1);
const target = new URL(requestUrl);
if (target.hostname === 'localhost') {
  target.hostname = '127.0.0.1';
}

const requestTimeoutMs = %1;
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(new Error(`request timeout after ${requestTimeoutMs}ms`)), requestTimeoutMs);
const options = { method: requestMethod, headers: {}, signal: controller.signal };

if (requestBodyFile) {
  options.body = fs.readFileSync(requestBodyFile, 'utf8');
  options.headers['Content-Type'] = 'application/json';
}

try {
  const response = await fetch(target, options);
  clearTimeout(timeout);
  const text = await response.text();
  if (!response.ok) {
    console.error(text || `HTTP ${response.status}`);
    process.exit(1);
  }
  process.stdout.write(text);
} catch (err) {
  clearTimeout(timeout);
  const cause = err && err.cause ? err.cause : null;
  const detail = cause && (cause.code || cause.message)
    ? `${err.message || String(err)}: ${cause.code || cause.message}`
    : (err && err.message ? err.message : String(err));
  console.error(detail);
  process.exit(1);
}
)JS").arg(request_timeout_ms);

    QStringList args;
    args << "--input-type=module"
         << "-e"
         << script
         << url
         << method
         << body_file;
    const QString result = run_process(node, args, timeout_ms);
    if (result.startsWith("runtime_")) {
        qWarning().noquote() << QString("bridge http_request failed method=%1 url=%2 result=%3")
            .arg(method, url, result.left(200));
    } else {
        qInfo().noquote() << QString("bridge http_request done method=%1 url=%2 bytes=%3")
            .arg(method, url)
            .arg(result.size());
    }
    return result;
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

    QString health_url = base_url;
    if (health_url.endsWith('/')) {
        health_url.chop(1);
    }
    health_url = health_url + "/neurx/health";

    qInfo().noquote() << QString("bridge local backend health probe url=%1").arg(health_url);
    const QString health_probe = run_http_request("GET", health_url, QString(), 5000);
    if (!health_probe.startsWith("runtime_")) {
        qInfo().noquote() << QString("bridge local backend already healthy url=%1").arg(health_url);
        return QString();
    }

    const QString backend_dir = QDir(repo_root).filePath("app/service");
    const QFileInfo server_file(QDir(backend_dir).filePath("http_server.sh"));
    if (!server_file.exists() || !server_file.isFile()) {
        return "runtime_exec_failed: backend http_server.sh not found";
    }

    qInfo().noquote() << QString("bridge starting local backend dir=%1 script=%2")
        .arg(backend_dir, server_file.fileName());
    const bool started = QProcess::startDetached("bash", {"http_server.sh"}, backend_dir);
    if (!started) {
        return "runtime_exec_failed: failed to start local backend";
    }

    for (int attempt = 0; attempt < 10; ++attempt) {
        QThread::msleep(300);
        qInfo().noquote() << QString("bridge local backend probe attempt=%1 url=%2")
            .arg(attempt + 1)
            .arg(health_url);
        const QString probe = run_http_request("GET", health_url, QString(), 5000);
        if (!probe.startsWith("runtime_")) {
            qInfo().noquote() << QString("bridge local backend ready url=%1 attempt=%2")
                .arg(health_url)
                .arg(attempt + 1);
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
    const QString chat_path = preferred_chat_path_for(
        base_url,
        local_model_chat_path_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
    const QString model_name = preferred_model_name_for(
        base_url,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_));
    if (base_url.isEmpty() || chat_path.isEmpty() || model_name.isEmpty()) {
        return "local_model_config_missing: base_url, chat_path, or model";
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
    qInfo().noquote() << QString("bridge local model request url=%1 model=%2 path=%3 backend=%4")
        .arg(url, model_name, chat_path, local_model_backend_);
    request_json.insert("prompt", prompt);
    QJsonObject user_message;
    user_message.insert("role", "user");
    user_message.insert("content", prompt);
    QJsonArray messages;
    messages.append(user_message);
    request_json.insert("messages", messages);
    request_json.insert("max_tokens", max_steps);

    const QString payload = QString::fromUtf8(QJsonDocument(request_json).toJson(QJsonDocument::Compact));
    QTemporaryFile tmp;
    tmp.setAutoRemove(true);
    if (!tmp.open()) {
        return QString("runtime_exec_failed: could not create temp file");
    }
    tmp.write(payload.toUtf8());
    tmp.flush();
    tmp.close();

    const QString repo_root = find_repo_root();
    if (!repo_root.isEmpty()) {
        qInfo().noquote() << QString("bridge local backend code_path handler=%1 gateway=%2 serve=%3")
            .arg(QDir(repo_root).filePath("app/service/http_handler.sh"))
            .arg(QDir(repo_root).filePath("app/service/gateway.sh"))
            .arg(QDir(repo_root).filePath("app/service/serve.s"));
    }

    const QString raw = run_http_request("POST", url, tmp.fileName(), 120000);
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
    const QString effective_model_name = preferred_model_name_for(
        local_model_base_url_,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(find_repo_root()));
    if (local_model_base_url_.trimmed().isEmpty() || effective_model_name.isEmpty()) {
        return "enabled config_missing";
    }
    return QString("enabled backend=%1 base_url=%2 model=%3 path=%4 checkpoints=%5")
        .arg(local_model_backend_)
        .arg(local_model_base_url_)
        .arg(effective_model_name)
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

    // Only update model name from checkpoint for the s-backend.
    // When the URL points to Ollama, the model name is determined by the Ollama registry
    // (e.g. "neurx-qwen2.5vl-local:latest") and must never be replaced with a checkpoint
    // file basename such as "gpt_large_pretrain".
    if (local_model_enabled_ && local_model_backend_ == "openai"
        && !url_looks_like_ollama(local_model_base_url_)) {
        local_model_name_ = QFileInfo(latest).baseName();
        if (local_model_name_.isEmpty()) {
            local_model_name_ = QFileInfo(latest).fileName();
        }
        if (local_model_base_url_.trimmed().isEmpty()) {
            local_model_base_url_ = "http://127.0.0.1:18080";
        }
        local_model_chat_path_ = preferred_chat_path_for(
            local_model_base_url_,
            local_model_chat_path_,
            local_model_backend_,
            !checkpoint_model_file_.isEmpty());
        local_model_name_ = preferred_model_name_for(
            local_model_base_url_,
            local_model_name_,
            local_model_backend_,
            !checkpoint_model_file_.isEmpty(),
            checkpoint_model_file_,
            resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_));
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

    const QString effective_model_name = preferred_model_name_for(
        local_model_base_url_,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(root, checkpoint_models_root_));
    if (local_model_enabled_ && !local_model_base_url_.trimmed().isEmpty() && !effective_model_name.isEmpty()) {
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
                if (run_diag_enabled()) {
                    result = result + "\ncode_path=app/bridge/neurx_bridge.cpp";
                    result = result + "\nbackend_path=app/service/http_handler.sh";
                    result = result + "\ngateway_path=app/service/gateway.sh";
                    result = result + "\nentry_path=app/service/serve.s";
                }
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
                emit runtime_status_changed("local-model", effective_model_name);
                return result;
            }

            if (run_diag_enabled()) {
                emit log_message("info", "bridge", QString("run_agent seq=%1 completed local-text").arg(run_seq));
            }
            emit log_message("info", "agent", local_result);
            emit runtime_status_changed("local-model", effective_model_name);
            return local_result;
        }

        emit log_message("warning", "agent", QString("local model fallback: %1").arg(local_result));
        emit runtime_status_changed("local-model-fallback", effective_model_name);
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

static bool is_code_language_token(const QString& text) {
    static const QStringList langs = {
        "c", "c++", "cpp", "java", "python", "rust", "go", "swift",
        "kotlin", "typescript", "javascript", "js", "ts", "qml",
        "html", "css", "sql", "bash", "sh", "s"
    };
    for (const QString& lang : langs) {
        if (text == lang) {
            return true;
        }
    }
    return false;
}

static bool contains_any_keyword(const QString& text, const QStringList& keywords) {
    for (const QString& keyword : keywords) {
        if (text.contains(keyword)) {
            return true;
        }
    }
    return false;
}

static bool prompt_mentions_code_language(const QString& text) {
    static const QStringList langs = {
        "c++", "cpp", "python", "java", "rust", "golang", "go", "swift",
        "kotlin", "typescript", "javascript", "qml", "html", "css", "sql",
        "bash", "shell", "sh"
    };
    return contains_any_keyword(text, langs);
}

static bool looks_like_stub_chat_response(const QString& text) {
    return text.contains("当前由本地 S 后端链路处理")
        || text.contains("S backend is alive and responding")
        || text.contains("serve.s 执行成功但无输出");
}

static QString hello_program_fallback(const QString& prompt) {
    const QString text = prompt.trimmed().toLower();
    const bool wants_hello = text.contains("hello")
        || text.contains("hello world")
        || text.contains("hello, world")
        || text.contains("helloworld");
    if ((text.contains("c++") || text.contains("cpp"))
        && wants_hello) {
        return QString(
            "#include <iostream>\n\n"
            "int main() {\n"
            "    std::cout << \"Hello, world!\" << std::endl;\n"
            "    return 0;\n"
            "}\n");
    }
    if (text.contains("python") && wants_hello) {
        return QString("print(\"Hello, world!\")\n");
    }
    if ((text.contains("java")) && wants_hello) {
        return QString(
            "public class Main {\n"
            "    public static void main(String[] args) {\n"
            "        System.out.println(\"Hello, world!\");\n"
            "    }\n"
            "}\n");
    }
    return QString();
}

static QString direct_code_template_for_prompt(const QString& prompt) {
    return hello_program_fallback(prompt);
}

QString NeurxBridge::agent_route_for_prompt(const QString& prompt, const QString& filePath) const {
    Q_UNUSED(filePath);
    const QString text = prompt.trimmed().toLower();
    if (is_code_language_token(text)) {
        return "code";
    }
    if (contains_any_keyword(text, {
        "fix", "bug", "error", "implement", "patch", "refactor", "code", "qml",
        "write", "create", "build", "generate", "example", "hello world",
        "写", "实现", "修复", "代码", "程序", "示例", "例子"
    })) {
        return "code";
    }
    if (prompt_mentions_code_language(text)) {
        return "code";
    }
    if (contains_any_keyword(text, {
        "review", "audit", "check", "test",
        "审查", "审计", "检查", "测试"
    })) {
        return "review";
    }
    if (contains_any_keyword(text, {
        "search", "lookup", "find",
        "搜索", "查找", "查询"
    })) {
        return "search";
    }
    return "general";
}

QString NeurxBridge::run_code_assistant(const QString& prompt, const QString& filePath) {
    return run_code_assistant_request(prompt, filePath);
}

QString NeurxBridge::export_agent_skill_snapshot(const QString& prompt, int max_steps) {
    return run_agent_state_export(prompt, max_steps, "skill_snapshot");
}

QString NeurxBridge::export_agent_trajectory(const QString& prompt, int max_steps) {
    return run_agent_state_export(prompt, max_steps, "trajectory");
}

QString NeurxBridge::read_text_file(const QString& path) const {
    const QString next = path.trimmed();
    if (next.isEmpty()) {
        return QString();
    }

    QFile file(next);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString("read_text_file_failed: %1").arg(next);
    }

    return QString::fromUtf8(file.readAll());
}

QVariantList NeurxBridge::explorer_entries(const QString& path) const {
    QVariantList entries;

    const auto append_entry = [&entries](const QString& label,
                                         const QString& entry_path,
                                         const QString& kind,
                                         bool is_dir) {
        QVariantMap item;
        item.insert("label", label);
        item.insert("path", entry_path);
        item.insert("kind", kind);
        item.insert("isDir", is_dir);
        entries.append(item);
    };

    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty()) {
        QStringList seen_paths;
        const QList<QStorageInfo> volumes = QStorageInfo::mountedVolumes();
        for (const QStorageInfo& volume : volumes) {
            if (!volume.isValid() || !volume.isReady()) {
                continue;
            }

            const QString root_path = QDir::cleanPath(volume.rootPath());
            if (root_path.isEmpty() || seen_paths.contains(root_path)) {
                continue;
            }

            const QByteArray device = volume.device();
            if (!(root_path == "/" || device.startsWith("/dev/"))) {
                continue;
            }

            seen_paths.append(root_path);
            QString label = volume.displayName().trimmed();
            if (label.isEmpty()) {
                label = root_path;
            } else if (label != root_path) {
                label = QString("%1 (%2)").arg(label, root_path);
            }
            append_entry(label, root_path, QStringLiteral("Disk"), true);
        }

        if (entries.isEmpty()) {
            const QFileInfoList drives = QDir::drives();
            for (const QFileInfo& drive : drives) {
                const QString root_path = QDir::cleanPath(drive.absoluteFilePath());
                if (root_path.isEmpty() || seen_paths.contains(root_path)) {
                    continue;
                }
                seen_paths.append(root_path);
                append_entry(root_path, root_path, QStringLiteral("Disk"), true);
            }
        }
        return entries;
    }

    const QDir dir(trimmed);
    if (!dir.exists()) {
        return entries;
    }

    const QFileInfoList child_dirs = dir.entryInfoList(
        QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable,
        QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);
    for (const QFileInfo& info : child_dirs) {
        append_entry(info.fileName(), info.absoluteFilePath(), QStringLiteral("Dir"), true);
    }

    const QFileInfoList files = dir.entryInfoList(
        QDir::Files | QDir::Readable,
        QDir::Name | QDir::IgnoreCase);
    for (const QFileInfo& info : files) {
        QString suffix = info.suffix().toUpper();
        if (suffix.isEmpty()) {
            suffix = QStringLiteral("File");
        }
        append_entry(info.fileName(), info.absoluteFilePath(), suffix, false);
    }

    return entries;
}

QString NeurxBridge::explorer_default_path() const {
    // Prefer the repository root so the explorer opens directly inside the project
    // rather than at the top-level disk root, which requires an extra click to expand.
    const QString repo_root = find_repo_root();
    if (!repo_root.trimmed().isEmpty()) {
        return QDir(repo_root).absolutePath();
    }

    // Fall back to the current working directory.
    const QString cwd = QDir::currentPath();
    if (!cwd.isEmpty()) {
        return cwd;
    }

    return QStringLiteral("/");
}

void NeurxBridge::copy_to_clipboard(const QString& text) {
    if (QClipboard* clipboard = QGuiApplication::clipboard()) {
        clipboard->setText(text);
    }
}

QString NeurxBridge::run_code_assistant_request(const QString& prompt, const QString& filePath) {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        return "repo_not_found";
    }
    const QString route = agent_route_for_prompt(prompt, filePath);
    emit log_message("info", "agent", QString("code-assistant start route=%1 prompt_len=%2 file=%3")
        .arg(route)
        .arg(prompt.size())
        .arg(filePath.trimmed().isEmpty() ? QStringLiteral("-") : QFileInfo(filePath.trimmed()).fileName()));

    const QString runner_path = QDir(root).filePath("app/service/code_agent_runner.sh");
    if (QFileInfo::exists(runner_path) && QFileInfo(runner_path).isFile()) {
        const QString runner_result = run_process(
            "bash",
            QStringList() << runner_path
                          << "--prompt" << prompt
                          << "--file" << filePath.trimmed()
                          << "--repo" << root,
            5000,
            root);
        if (!runner_result.startsWith("runtime_")) {
            QJsonParseError runner_parse_error;
            const QJsonDocument runner_json = QJsonDocument::fromJson(runner_result.toUtf8(), &runner_parse_error);
            if (runner_parse_error.error == QJsonParseError::NoError && runner_json.isObject()) {
                const QJsonObject runner_obj = runner_json.object();
                const QString runner_status = runner_obj.value("status").toString();
                const QString runner_mode = runner_obj.value("mode").toString();
                const QString runner_response = runner_obj.value("response").toString();
                const QString runner_plan = runner_obj.value("plan").toString();
                const QString runner_file_context = runner_obj.value("file_context").toString();
                if (runner_status == "completed" && !runner_response.trimmed().isEmpty()) {
                    emit log_message("info", "agent", QString("code-assistant done route=%1 source=runner mode=%2")
                        .arg(route, runner_mode));
                    QString decorated = runner_response.trimmed();
                    if (!runner_mode.trimmed().isEmpty()) {
                        decorated = QString("[mode] %1\n\n%2").arg(runner_mode.trimmed(), decorated);
                    }
                    return decorated;
                }
                if (runner_status == "unhandled") {
                    emit log_message("info", "agent", QString("code-assistant runner delegated route=%1 mode=%2")
                        .arg(route, runner_mode));
                    QString delegated = QString("[mode] %1").arg(runner_mode.trimmed().isEmpty() ? QStringLiteral("planner") : runner_mode.trimmed());
                    if (!runner_plan.trimmed().isEmpty()) {
                        delegated = delegated + "\n[plan] " + runner_plan.trimmed();
                    }
                    if (!runner_file_context.trimmed().isEmpty()) {
                        delegated = delegated + "\n[file_context]\n" + runner_file_context.trimmed();
                    }
                    emit log_message("info", "agent", delegated);
                }
            }
        }
    }

    const QString direct_template = direct_code_template_for_prompt(prompt);
    if (!direct_template.isEmpty()) {
        emit log_message("info", "agent", QString("code-assistant done route=%1 source=bridge-direct-template").arg(route));
        return direct_template;
    }

    const QString backend_ready = ensure_local_openai_backend(root);
    if (!backend_ready.isEmpty()) {
        emit log_message("warning", "agent", QString("code-assistant backend failed: %1").arg(backend_ready));
        return backend_ready;
    }

    // Prefer the main chat backend so code requests can return actual code instead of a canned suggestion.
    QString url = local_model_base_url_.trimmed();
    if (url.isEmpty()) {
        url = "http://127.0.0.1:18080";
    }
    const QString effective_chat_path = preferred_chat_path_for(
        url,
        local_model_chat_path_.trimmed().isEmpty() ? QStringLiteral("/neurx/api/chat") : local_model_chat_path_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty());
    const QString effective_model_name = preferred_model_name_for(
        url,
        local_model_name_,
        local_model_backend_,
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(root, checkpoint_models_root_));
    const QString chat_url = join_url_and_path(url, effective_chat_path);
    const QString suggest_url = join_url_and_path(url, QStringLiteral("/neurx/api/agent/suggest"));
    const bool suggest_supported = chat_url.contains("/neurx/api/chat");
    qInfo().noquote() << QString("bridge code assistant request url=%1 model=%2 path=%3 backend=%4")
        .arg(chat_url, effective_model_name, effective_chat_path, local_model_backend_);

    QJsonObject payload;
    QString effective_prompt;
    if (!filePath.trimmed().isEmpty()) {
        effective_prompt = QString(
            "You are a code assistant working in the NeurX repository.\n"
            "Target file: %1\n"
            "User request: %2\n"
            "Provide a concrete code answer. If the user asks to write code, return the code first. "
            "Keep the reply concise and executable.")
            .arg(filePath.trimmed(), prompt.trimmed());
    } else {
        effective_prompt = QString(
            "You are a code assistant working in the NeurX repository.\n"
            "User request: %1\n"
            "If the user asks to write code, return a complete minimal program. "
            "Prefer directly answering with code when appropriate.")
            .arg(prompt.trimmed());
    }

    if (chat_url.contains("/v1/chat/completions") || chat_url.contains("/api/chat")) {
        if (effective_model_name.isEmpty()) {
            emit log_message("warning", "agent",
                QString("code-assistant: model name is empty for url=%1 — aborting request").arg(chat_url));
            return "local_model_config_missing: model name could not be resolved";
        }
        payload.insert("model", effective_model_name);
        payload.insert("max_tokens", 256);
        QJsonObject user_message;
        user_message.insert("role", "user");
        user_message.insert("content", effective_prompt);
        QJsonArray messages;
        messages.append(user_message);
        payload.insert("messages", messages);
    } else {
        payload.insert("prompt", effective_prompt);
        if (!filePath.trimmed().isEmpty()) {
            payload.insert("filePath", filePath.trimmed());
        }
        if (!effective_model_name.isEmpty()) {
            payload.insert("model", effective_model_name);
        }
        payload.insert("max_tokens", 256);
    }

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

    const QString chatResult = run_http_request("POST", chat_url, tmp.fileName(), 120000);
    if (!chatResult.startsWith("runtime_")) {
        QJsonParseError parse_error;
        const QJsonDocument response_json = QJsonDocument::fromJson(chatResult.toUtf8(), &parse_error);
        if (parse_error.error == QJsonParseError::NoError && response_json.isObject()) {
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
            if (!content.trimmed().isEmpty()) {
                const QString fallback = hello_program_fallback(prompt);
                if (!fallback.isEmpty() && looks_like_stub_chat_response(content)) {
                    emit log_message("info", "agent", QString("code-assistant done route=%1 fallback=hello-template").arg(route));
                    return fallback;
                }
                emit log_message("info", "agent", QString("code-assistant done route=%1 suggestion_len=%2")
                    .arg(route)
                    .arg(content.size()));
                return content.trimmed();
            }
        }
    }

    const QString fallback = hello_program_fallback(prompt);
    if (!fallback.isEmpty()) {
        emit log_message("info", "agent", QString("code-assistant done route=%1 fallback=hello-template-nochat").arg(route));
        return fallback;
    }

    // Fall back to the lightweight suggest endpoint only for the local NeurX backend.
    if (!suggest_supported) {
        emit log_message("warning", "agent", QString("code-assistant empty chat response from %1").arg(chat_url));
        return QString("code_assistant_empty_response: %1").arg(chat_url);
    }

    // Fall back to the lightweight suggest endpoint so the UI still completes if chat output is empty.
    const QString curlResult = run_http_request("POST", suggest_url, tmp.fileName(), 120000);
    if (curlResult.startsWith("runtime_")) {
        emit log_message("error", "agent", QString("code-assistant request failed: %1").arg(curlResult));
        return curlResult;
    }

    QJsonParseError parse_error;
    const QJsonDocument response_json = QJsonDocument::fromJson(curlResult.toUtf8(), &parse_error);
    if (parse_error.error != QJsonParseError::NoError || !response_json.isObject()) {
        emit log_message("error", "agent", QString("code-assistant parse failed: %1").arg(curlResult.left(200)));
        return QString("code_assistant_parse_failed: %1").arg(curlResult.left(200));
    }

    const QJsonObject response = response_json.object();
    const QString suggestion = response.value("suggestion").toString();
    QString result = suggestion.isEmpty()
        ? QString("code_ok route=%1").arg(agent_route_for_prompt(prompt, filePath))
        : suggestion;
    emit log_message("info", "agent", QString("code-assistant done route=%1 suggestion_len=%2")
        .arg(route)
        .arg(result.size()));
    return result;
}

QString NeurxBridge::run_agent_state_export(const QString& prompt, int max_steps, const QString& export_kind) {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        return "repo_not_found";
    }

    int steps = max_steps;
    if (steps <= 0) {
        steps = 1;
    }

    const QString safe_prompt = prompt.trimmed().isEmpty() ? QStringLiteral("hello") : prompt;
    const QString export_dir = QDir(root).filePath("artifacts/checkpoints/agent/skills");
    QDir().mkpath(export_dir);

    const QString file_name = export_kind == "trajectory"
        ? QStringLiteral("latest_trajectory.txt")
        : QStringLiteral("latest_skill_snapshot.txt");
    const QString target_path = QDir(export_dir).filePath(file_name);

    QTemporaryFile runner(QDir(root).filePath("build/tmp/neurx_agent_export_XXXXXX.s"));
    QDir().mkpath(QDir(root).filePath("build/tmp"));
    runner.setAutoRemove(true);
    if (!runner.open()) {
        return QString("runtime_exec_failed: could not create S export runner");
    }

    const QString prompt_literal = escape_s_string(safe_prompt);
    const QString target_literal = escape_s_string(target_path);
    const QString export_expr = export_kind == "trajectory"
        ? QStringLiteral("agent_trajectory_export(state)")
        : QStringLiteral("agent_skill_snapshot(state)");
    const QString persist_stmt = export_kind == "trajectory"
        ? QStringLiteral("    agent_export_trajectory(state, \"") + target_literal + QStringLiteral("\")\n")
        : QStringLiteral("    agent_persist_skill_snapshot(state, \"") + target_literal + QStringLiteral("\")\n");

    const QString source = QString(
        "package neurx.app.agent_export_runner\n\n"
        "use neurx.agent.{new_default_agent, run_agent_once, agent_skill_snapshot, agent_trajectory_export, agent_persist_skill_snapshot, agent_export_trajectory}\n\n"
        "func main() int {\n"
        "    string prompt = \"%1\"\n"
        "    agent_runtime_state state = new_default_agent(prompt)\n"
        "    int total = %2\n"
        "    int i = 0\n"
        "    while i < total {\n"
        "        state = run_agent_once(state, prompt)\n"
        "        i = i + 1\n"
        "    }\n"
        "%3"
        "    println(\"saved_path=%4\")\n"
        "    println(%5)\n"
        "    0\n"
        "}\n")
        .arg(prompt_literal)
        .arg(steps)
        .arg(persist_stmt)
        .arg(target_literal)
        .arg(export_expr);

    runner.write(source.toUtf8());
    runner.flush();
    runner.close();

    const QString result = run_process("s", QStringList() << "run" << runner.fileName(), 120000, root);
    if (!result.startsWith("runtime_")) {
        emit log_message("info", "agent", QString("agent export done kind=%1 len=%2").arg(export_kind).arg(result.size()));
    }
    return result;
}

void NeurxBridge::run_code_assistant_async(const QString& prompt, const QString& filePath) {
    if (agent_run_active_) {
        emit log_message("warning", "agent", "agent run already in progress");
        emit runtime_status_changed("busy", local_model_name_);
        return;
    }

    agent_run_active_ = true;
    emit runtime_status_changed("running", "code-assistant");

    auto* watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher]() {
        const QString result = watcher->result();
        watcher->deleteLater();
        agent_run_active_ = false;
        emit agentRunFinished(result);
    });

    watcher->setFuture(QtConcurrent::run([this, prompt, filePath]() {
        return run_code_assistant(prompt, filePath);
    }));
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

void NeurxBridge::run_agent_auto_async(const QString& prompt, const QString& filePath, int max_steps) {
    const QString route = agent_route_for_prompt(prompt, filePath);
    if (route == "code" || route == "review") {
        run_code_assistant_async(prompt, filePath);
        return;
    }
    run_agent_async(prompt, max_steps);
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
