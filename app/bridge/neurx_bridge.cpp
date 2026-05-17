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

QString NeurxBridge::run_python_script(const QString& repo_root, const QString& script, const QStringList& args, int timeout_ms) const {
    const QString python_bin = qEnvironmentVariable("NEURX_PYTHON", "python3");
    QProcess proc;
    proc.setProgram(python_bin);

    QStringList proc_args;
    proc_args << "-c" << script << repo_root;
    for (const QString& arg : args) {
        proc_args << arg;
    }

    proc.setArguments(proc_args);
    proc.setWorkingDirectory(repo_root);
    proc.start();

    if (!proc.waitForFinished(timeout_ms)) {
        proc.kill();
        return "runtime_timeout";
    }

    const QString stdout_text = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    const QString stderr_text = QString::fromUtf8(proc.readAllStandardError()).trimmed();

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        if (!stderr_text.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(stderr_text.left(200));
        }
        return "runtime_exec_failed";
    }
    return stdout_text;
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
        const QFileInfo runtime_file(QDir(candidate).filePath("runtime/runtime.py"));
        if (runtime_file.exists() && runtime_file.isFile()) {
            return QDir(candidate).absolutePath();
        }
    }

    QDir dir(QDir::currentPath());
    for (int i = 0; i < 8; ++i) {
        const QFileInfo runtime_file(dir.filePath("runtime/runtime.py"));
        if (runtime_file.exists() && runtime_file.isFile()) {
            return dir.absolutePath();
        }
        if (!dir.cdUp()) {
            break;
        }
    }
    return QString();
}

QString NeurxBridge::run_agent_probe(const QString& repo_root) const {
    const QString probe_script =
        "import importlib.util, json, pathlib, sys\n"
        "root = pathlib.Path(sys.argv[1])\n"
        "runtime_path = root / 'runtime' / 'runtime.py'\n"
        "spec = importlib.util.spec_from_file_location('neurx_runtime', runtime_path)\n"
        "module = importlib.util.module_from_spec(spec)\n"
        "spec.loader.exec_module(module)\n"
        "if not module.supports_runtime_function('agent/runtime', 'new_agent_runtime_state'):\n"
        "    print('agent_ir_missing')\n"
        "    raise SystemExit(0)\n"
        "state = module.invoke_runtime_function('agent/runtime', 'new_agent_runtime_state', 'qt bridge', 'analyze', 3)\n"
        "next_state = module.invoke_runtime_function('agent/runtime', 'agent_runtime_step', state, 'from_qt')\n"
        "payload = {\n"
        "    'steps': int(next_state.get('steps', 0)),\n"
        "    'finished': bool(next_state.get('finished', False)),\n"
        "    'last_action': str(next_state.get('last_action', '')),\n"
        "    'last_observation': str(next_state.get('last_observation', '')),\n"
        "}\n"
        "print(json.dumps(payload))\n";

    const QString stdout_text = run_python_script(repo_root, probe_script, {}, 12000);
    if (stdout_text.startsWith("runtime_")) {
        return stdout_text;
    }

    if (stdout_text == "agent_ir_missing") {
        return "agent_ir_missing";
    }

    QJsonParseError parse_error;
    const QJsonDocument json = QJsonDocument::fromJson(stdout_text.toUtf8(), &parse_error);
    if (parse_error.error != QJsonParseError::NoError || !json.isObject()) {
        return QString("runtime_unexpected_output: %1").arg(stdout_text.left(120));
    }

    const QJsonObject obj = json.object();
    const int steps = obj.value("steps").toInt(0);
    const bool finished = obj.value("finished").toBool(false);
    const QString action = obj.value("last_action").toString();
    const QString observation = obj.value("last_observation").toString();

    return QString("agent_ready steps=%1 finished=%2 action=%3 obs=%4")
        .arg(steps)
        .arg(finished ? "true" : "false")
        .arg(action)
        .arg(observation);
}

QString NeurxBridge::run_local_model_agent(const QString& prompt, int max_steps) const {
    const QString base_url = local_model_base_url_.trimmed();
    const QString model = local_model_name_.trimmed();
    const QString chat_path = local_model_chat_path_.trimmed().isEmpty()
        ? local_model_default_chat_path()
        : local_model_chat_path_.trimmed();
    if (base_url.isEmpty() || model.isEmpty()) {
        return "local_model_config_missing";
    }

    const QString local_script =
        "import json, sys, urllib.error, urllib.request\n"
        "base_url = sys.argv[1].rstrip('/')\n"
        "chat_path = sys.argv[2]\n"
        "model = sys.argv[3]\n"
        "prompt = sys.argv[4]\n"
        "max_steps = int(sys.argv[5])\n"
        "backend = sys.argv[6]\n"
        "api_key = sys.argv[7]\n"
        "system_prompt = sys.argv[8]\n"
        "messages = [\n"
        "    {'role': 'system', 'content': system_prompt},\n"
        "    {'role': 'user', 'content': prompt},\n"
        "]\n"
        "if backend == 'ollama':\n"
        "    payload = {\n"
        "        'model': model,\n"
        "        'messages': messages,\n"
        "        'stream': False,\n"
        "        'options': {'temperature': 0.2},\n"
        "    }\n"
        "else:\n"
        "    payload = {\n"
        "        'model': model,\n"
        "        'messages': messages,\n"
        "        'temperature': 0.2,\n"
        "        'max_tokens': 512,\n"
        "    }\n"
        "data = json.dumps(payload).encode('utf-8')\n"
        "request = urllib.request.Request(base_url + chat_path, data=data, headers={'Content-Type': 'application/json'})\n"
        "if api_key:\n"
        "    request.add_header('Authorization', 'Bearer ' + api_key)\n"
        "try:\n"
        "    with urllib.request.urlopen(request, timeout=30) as response:\n"
        "        raw = response.read().decode('utf-8')\n"
        "    decoded = json.loads(raw)\n"
        "    content = ''\n"
        "    if backend == 'ollama':\n"
        "        content = decoded.get('message', {}).get('content', '') or decoded.get('response', '')\n"
        "    else:\n"
        "        choices = decoded.get('choices', [])\n"
        "        if choices:\n"
        "            message = choices[0].get('message', {})\n"
        "            content = message.get('content', '') or choices[0].get('text', '')\n"
        "    if not content:\n"
        "        print('runtime_exec_failed: empty_model_response')\n"
        "        raise SystemExit(1)\n"
        "    print(json.dumps({'backend': backend, 'model': model, 'steps': max_steps, 'content': content}))\n"
        "except Exception as exc:\n"
        "    print('runtime_exec_failed: ' + str(exc))\n"
        "    raise SystemExit(1)\n";

    const QString api_key = qEnvironmentVariable("NEURX_LLM_API_KEY");
    const QString system_prompt =
        QString("You are Neurx Agent. Solve the user's request in at most %1 step(s). "
                "Return concise, actionable output.").arg(max_steps);

    return run_python_script(find_repo_root(), local_script, {
        base_url,
        chat_path,
        model,
        prompt,
        QString::number(max_steps),
        local_model_backend_,
        api_key,
        system_prompt,
    }, 30000);
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

    const QString run_script =
        "import importlib.util, json, pathlib, sys\n"
        "root = pathlib.Path(sys.argv[1])\n"
        "prompt = sys.argv[2]\n"
        "max_steps = int(sys.argv[3])\n"
        "runtime_path = root / 'runtime' / 'runtime.py'\n"
        "spec = importlib.util.spec_from_file_location('neurx_runtime', runtime_path)\n"
        "module = importlib.util.module_from_spec(spec)\n"
        "spec.loader.exec_module(module)\n"
        "need = [('agent', 'run_agent_with_goal'), ('agent', 'agent_status'), ('agent', 'agent_current_task')]\n"
        "for m, f in need:\n"
        "    if not module.supports_runtime_function(m, f):\n"
        "        print('agent_ir_missing')\n"
        "        raise SystemExit(0)\n"
        "done = module.invoke_runtime_function('agent', 'run_agent_with_goal', 'qt_request', prompt, max_steps)\n"
        "payload = {\n"
        "    'steps': int(done.get('steps', 0)),\n"
        "    'finished': bool(done.get('finished', False)),\n"
        "    'last_action': str(done.get('last_action', '')),\n"
        "    'last_observation': str(done.get('last_observation', '')),\n"
        "    'status': str(done.get('plan', {}).get('status', '')),\n"
        "    'task': str(done.get('plan', {}).get('current_task', '')),\n"
        "}\n"
        "print(json.dumps(payload))\n";

    const QString stdout_text = run_python_script(root, run_script, {prompt, QString::number(steps)}, 20000);
    if (stdout_text.startsWith("runtime_") || stdout_text == "agent_ir_missing") {
        emit log_message("warning", "agent", stdout_text);
        emit runtime_status_changed(stdout_text, "run");
        return stdout_text;
    }

    QJsonParseError parse_error;
    const QJsonDocument json = QJsonDocument::fromJson(stdout_text.toUtf8(), &parse_error);
    if (parse_error.error != QJsonParseError::NoError || !json.isObject()) {
        const QString unexpected = QString("runtime_unexpected_output: %1").arg(stdout_text.left(120));
        emit log_message("error", "agent", unexpected);
        emit runtime_status_changed("unexpected_output", "run");
        return unexpected;
    }

    const QJsonObject obj = json.object();
    const QString result = QString("run_ok steps=%1 finished=%2 action=%3 obs=%4")
        .arg(obj.value("steps").toInt(0))
        .arg(obj.value("finished").toBool(false) ? "true" : "false")
        .arg(obj.value("last_action").toString())
        .arg(obj.value("last_observation").toString())
        + QString(" status=%1 task=%2")
            .arg(obj.value("status").toString())
            .arg(obj.value("task").toString());
    emit log_message("info", "agent", result);
    emit runtime_status_changed(obj.value("status").toString(), obj.value("task").toString());
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
