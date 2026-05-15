#include "bridge/neurx_bridge.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>

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

QString NeurxBridge::run_agent(const QString& prompt, int max_steps) const {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        return "repo_not_found";
    }

    int steps = max_steps;
    if (steps <= 0) {
        steps = 1;
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
        return stdout_text;
    }

    QJsonParseError parse_error;
    const QJsonDocument json = QJsonDocument::fromJson(stdout_text.toUtf8(), &parse_error);
    if (parse_error.error != QJsonParseError::NoError || !json.isObject()) {
        return QString("runtime_unexpected_output: %1").arg(stdout_text.left(120));
    }

    const QJsonObject obj = json.object();
    return QString("run_ok steps=%1 finished=%2 action=%3 obs=%4")
        .arg(obj.value("steps").toInt(0))
        .arg(obj.value("finished").toBool(false) ? "true" : "false")
        .arg(obj.value("last_action").toString())
        .arg(obj.value("last_observation").toString())
        + QString(" status=%1 task=%2")
            .arg(obj.value("status").toString())
            .arg(obj.value("task").toString());
}

QString NeurxBridge::ping() const {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        return "repo_not_found";
    }
    return run_agent_probe(root);
}
