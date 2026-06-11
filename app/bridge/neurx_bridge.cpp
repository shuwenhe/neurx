#include "bridge/neurx_bridge.h"

#include <stdio.h>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryFile>
#include <QTemporaryDir>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QClipboard>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QMetaObject>
#include <QThread>
#include <QUrl>
#include <QVariantMap>
#include <QXmlStreamReader>
#include <QDebug>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QtConcurrent/QtConcurrentRun>

namespace {
constexpr const char kDefaultOllamaModel[] = "qwen2.5:0.5b";
constexpr const char kDefaultLocalOllamaModel[] = "neurx-qwen2.5-0.5b-instruct-local:latest";
constexpr const char kDefaultLocalOllamaModelDir[] = "artifacts/checkpoints/Qwen2.5-0.5B-Instruct";
constexpr const char kDefaultCustomerServiceFallbackModel[] = "neurx-qwen2.5-vl-7b-local:latest";
constexpr const char kDefaultCustomerServiceFallbackModelDir[] = "artifacts/checkpoints/Qwen2.5-VL-7B";
constexpr const char kDefaultCodeAgentLocalBaseUrl[] = "http://127.0.0.1:18080";
constexpr const char kDefaultCodeAgentLocalChatPath[] = "/neurx/api/chat";
constexpr const char kDefaultCodeAgentRemoteBaseUrl[] = "https://api.siliconflow.cn";
constexpr const char kDefaultCodeAgentRemoteChatPath[] = "/v1/chat/completions";
constexpr const char kDefaultCodeAgentRemoteModel[] = "Qwen/Qwen2.5-7B-Instruct";
constexpr const char kDefaultRemoteAppBaseUrl[] = "https://api.siliconflow.cn";
constexpr const char kDefaultRemoteAppChatPath[] = "/v1/chat/completions";
constexpr const char kDefaultRemoteAppModel[] = "Qwen/Qwen2.5-7B-Instruct";
constexpr const char kCheckpointRunName[] = "run_20260518_001";
constexpr const char kDefaultMysqlHost[] = "127.0.0.1";
constexpr int kDefaultMysqlPort = 33061;
constexpr const char kDefaultMysqlDatabase[] = "neurx";
constexpr const char kDefaultMysqlUser[] = "neurx";
constexpr const char kDefaultMysqlPassword[] = "Neurx@_20260523..";
constexpr const char kLoginRememberDays = 30;
constexpr int kOllamaInstallTimeoutMs = 30 * 60 * 1000;
constexpr int kOllamaPullTimeoutMs = 30 * 60 * 1000;
constexpr int kCodeAgentHistoryLimit = 8;
constexpr int kCodeAgentFileCacheLimit = 6;
constexpr int kCodeAgentLoopLimit = 6;

QString bridge_source_file_path() {
    return QDir::cleanPath(QString::fromUtf8(__FILE__));
}

struct CodeAgentRunnerEnvelope {
    bool valid {false};
    QString protocol_version;
    QString status;
    QString mode;
    QString summary;
    QString response;
    QString plan;
    QString file_context;
    QJsonArray action_objects;
    QStringList action_summaries;
    QStringList action_result_summaries;
};

QString env_or_default(const char* name, const char* fallback) {
    const QByteArray value = qgetenv(name);
    if (!value.isEmpty()) {
        return QString::fromUtf8(value);
    }
    return QString::fromUtf8(fallback);
}

QString docx_plain_text_from_xml(const QByteArray& xml_bytes) {
    QXmlStreamReader xml(xml_bytes);
    QString text;
    bool pending_paragraph_break = false;

    const auto append_text = [&](const QString& value) {
        if (value.isEmpty()) {
            return;
        }
        if (pending_paragraph_break && !text.isEmpty() && !text.endsWith('\n')) {
            text.append('\n');
        }
        pending_paragraph_break = false;
        text.append(value);
    };

    while (!xml.atEnd()) {
        xml.readNext();

        if (xml.isStartElement()) {
            const QStringView name = xml.name();
            if (name == u"tab") {
                append_text(QStringLiteral("\t"));
            } else if (name == u"br" || name == u"cr") {
                append_text(QStringLiteral("\n"));
            }
            continue;
        }

        if (xml.isCharacters() && !xml.isWhitespace()) {
            append_text(xml.text().toString());
            continue;
        }

        if (xml.isEndElement() && xml.name() == u"p") {
            pending_paragraph_break = true;
        }
    }

    if (xml.hasError()) {
        return QString();
    }

    QString normalized = text;
    normalized.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    while (normalized.contains(QStringLiteral("\n\n\n"))) {
        normalized.replace(QStringLiteral("\n\n\n"), QStringLiteral("\n\n"));
    }
    return normalized.trimmed();
}

QString quote_powershell_literal(QString value) {
    value.replace(QLatin1Char('\''), QStringLiteral("''"));
    return QStringLiteral("'%1'").arg(value);
}

QByteArray read_docx_document_xml(const QString& path) {
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    Q_UNUSED(path);
    return {};
#elif defined(Q_OS_WIN)
    const QString powershell = QStandardPaths::findExecutable(QStringLiteral("powershell.exe"));
    if (powershell.isEmpty()) {
        return {};
    }

    QTemporaryDir temp_dir;
    if (!temp_dir.isValid()) {
        return {};
    }

    const QString script = QStringLiteral(
        "$ErrorActionPreference='Stop'; "
        "Expand-Archive -LiteralPath %1 -DestinationPath %2 -Force; "
        "Get-Content -LiteralPath %3 -Raw -Encoding UTF8")
        .arg(quote_powershell_literal(path))
        .arg(quote_powershell_literal(temp_dir.path()))
        .arg(quote_powershell_literal(QDir(temp_dir.path()).filePath(QStringLiteral("word/document.xml"))));

    QProcess proc;
    proc.setProgram(powershell);
    proc.setArguments({
        QStringLiteral("-NoProfile"),
        QStringLiteral("-NonInteractive"),
        QStringLiteral("-Command"),
        script
    });
    proc.start();
    if (!proc.waitForStarted(10000) || !proc.waitForFinished(15000)) {
        proc.kill();
        proc.waitForFinished(2000);
        return {};
    }
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        return {};
    }
    return proc.readAllStandardOutput();
#else
    QString extractor = QStandardPaths::findExecutable(QStringLiteral("unzip"));
    QStringList args;
    if (!extractor.isEmpty()) {
        args << QStringLiteral("-p") << path << QStringLiteral("word/document.xml");
    } else {
        extractor = QStandardPaths::findExecutable(QStringLiteral("bsdtar"));
        if (!extractor.isEmpty()) {
            args << QStringLiteral("-xOf") << path << QStringLiteral("word/document.xml");
        }
    }
    if (extractor.isEmpty()) {
        return {};
    }

    QProcess proc;
    proc.setProgram(extractor);
    proc.setArguments(args);
    proc.start();
    if (!proc.waitForStarted(10000) || !proc.waitForFinished(15000)) {
        proc.kill();
        proc.waitForFinished(2000);
        return {};
    }
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        return {};
    }
    return proc.readAllStandardOutput();
#endif
}

QString clip_text(QString text, int max_chars) {
    if (text.size() <= max_chars) {
        return text;
    }
    text.truncate(max_chars);
    return text + QStringLiteral("\n...[truncated]");
}

CodeAgentRunnerEnvelope parse_code_agent_runner_envelope(const QString& runner_result) {
    CodeAgentRunnerEnvelope envelope;
    if (runner_result.startsWith(QStringLiteral("runtime_"))) {
        return envelope;
    }

    QJsonParseError runner_parse_error;
    const QJsonDocument runner_json = QJsonDocument::fromJson(runner_result.toUtf8(), &runner_parse_error);
    if (runner_parse_error.error != QJsonParseError::NoError || !runner_json.isObject()) {
        return envelope;
    }

    const QJsonObject runner_obj = runner_json.object();
    envelope.valid = true;
    envelope.protocol_version = runner_obj.value(QStringLiteral("protocol_version")).toString();
    envelope.status = runner_obj.value(QStringLiteral("status")).toString();
    envelope.mode = runner_obj.value(QStringLiteral("mode")).toString();
    envelope.summary = runner_obj.value(QStringLiteral("summary")).toString();
    envelope.response = runner_obj.value(QStringLiteral("response")).toString();
    envelope.plan = runner_obj.value(QStringLiteral("plan")).toString();
    envelope.file_context = runner_obj.value(QStringLiteral("file_context")).toString();

    if (runner_obj.value(QStringLiteral("actions")).isArray()) {
        const QJsonArray actions = runner_obj.value(QStringLiteral("actions")).toArray();
        envelope.action_objects = actions;
        for (const QJsonValue& value : actions) {
            if (!value.isObject()) {
                continue;
            }
            const QJsonObject action = value.toObject();
            const QString tool = action.value(QStringLiteral("tool")).toString().trimmed();
            const QString summary = action.value(QStringLiteral("summary")).toString().trimmed();
            QString line = tool.isEmpty() ? QStringLiteral("action") : tool;
            if (!summary.isEmpty()) {
                line += QStringLiteral(": ") + summary;
            }
            if (action.value(QStringLiteral("requires_approval")).toBool()) {
                line += QStringLiteral(" [approval]");
            }
            envelope.action_summaries << line;
        }
    }

    if (runner_obj.value(QStringLiteral("action_results")).isArray()) {
        const QJsonArray action_results = runner_obj.value(QStringLiteral("action_results")).toArray();
        for (const QJsonValue& value : action_results) {
            if (!value.isObject()) {
                continue;
            }
            const QJsonObject result = value.toObject();
            const QString tool = result.value(QStringLiteral("tool")).toString().trimmed();
            const QString summary = result.value(QStringLiteral("summary")).toString().trimmed();
            QString line = tool.isEmpty() ? QStringLiteral("result") : tool;
            line += result.value(QStringLiteral("ok")).toBool(true)
                ? QStringLiteral(": ok")
                : QStringLiteral(": failed");
            if (!summary.isEmpty()) {
                line += QStringLiteral(" - ") + summary;
            }
            envelope.action_result_summaries << line;
        }
    }

    return envelope;
}

    QString normalize_newlines(QString text) {
    text.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    text.replace(QChar('\r'), QChar('\n'));
    return text;
}

QString repo_relative_path(const QString& repo_root, const QString& absolute_path) {
    const QDir root_dir(repo_root);
    return QDir::cleanPath(root_dir.relativeFilePath(absolute_path));
}

QString resolve_workspace_path(const QString& repo_root, const QString& raw_path, bool* ok = nullptr) {
    if (ok) *ok = false;
    const QString trimmed_root = QDir::cleanPath(repo_root.trimmed());
    QString rel = raw_path.trimmed();
    if (trimmed_root.isEmpty() || rel.isEmpty()) return QString();

    const auto path_is_within_root = [](const QString& path, const QString& root) {
        const QString clean_root = QDir::cleanPath(root.trimmed());
        if (clean_root.isEmpty()) return false;
        const QString root_prefix = clean_root.endsWith('/') ? clean_root : clean_root + '/';
        return path == clean_root || path.startsWith(root_prefix, Qt::CaseInsensitive);
    };

    if (QFileInfo(rel).isAbsolute()) {
        QString abs = QDir::cleanPath(rel);
        if (path_is_within_root(abs, trimmed_root)) {
            if (ok) *ok = true;
            return abs;
        }
    }

    if (rel.contains("/neurx/", Qt::CaseInsensitive)) {
        rel = rel.mid(rel.indexOf("/neurx/", Qt::CaseInsensitive) + 7);
    } else if (rel.contains("/ne_readx/", Qt::CaseInsensitive)) {
        rel = rel.mid(rel.indexOf("/ne_readx/", Qt::CaseInsensitive) + 10);
    } else if (rel.contains("/code/", Qt::CaseInsensitive)) {
        rel = rel.mid(rel.indexOf("/code/", Qt::CaseInsensitive) + 6);
    }

    while (rel.startsWith('/')) rel.remove(0, 1);

    QString repo_stripped = trimmed_root;
    while (repo_stripped.startsWith('/')) repo_stripped.remove(0, 1);
    if (!repo_stripped.isEmpty() && rel.startsWith(repo_stripped, Qt::CaseInsensitive)) {
        rel = rel.mid(repo_stripped.length());
        while (rel.startsWith('/')) rel.remove(0, 1);
    }

    QString absolute_path = QDir::cleanPath(QDir(trimmed_root).absoluteFilePath(rel));
    if (path_is_within_root(absolute_path, trimmed_root)) {
        if (ok) *ok = true;
        return absolute_path;
    }
    return QString();
}

QString resolve_path_with_allowed_roots(const QString& repo_root,
                                        const QString& raw_path,
                                        const QStringList& allowed_external_roots,
                                        bool* ok = nullptr) {
    if (ok) *ok = false;
    const QString trimmed_root = QDir::cleanPath(repo_root.trimmed());
    QString rel = raw_path.trimmed();
    if (trimmed_root.isEmpty() || rel.isEmpty()) return QString();

    const auto path_is_within_root = [](const QString& path, const QString& root) {
        const QString clean_root = QDir::cleanPath(root.trimmed());
        if (clean_root.isEmpty()) return false;
        const QString root_prefix = clean_root.endsWith('/') ? clean_root : clean_root + '/';
        return path == clean_root || path.startsWith(root_prefix, Qt::CaseInsensitive);
    };

    if (QFileInfo(rel).isAbsolute()) {
        QString abs = QDir::cleanPath(rel);
        if (path_is_within_root(abs, trimmed_root)) {
            if (ok) *ok = true;
            return abs;
        }
        for (const QString& allowed : allowed_external_roots) {
            if (path_is_within_root(abs, allowed)) {
                if (ok) *ok = true;
                return abs;
            }
        }
    }

    if (rel.contains("/neurx/", Qt::CaseInsensitive)) {
        rel = rel.mid(rel.indexOf("/neurx/", Qt::CaseInsensitive) + 7);
    } else if (rel.contains("/ne_readx/", Qt::CaseInsensitive)) {
        rel = rel.mid(rel.indexOf("/ne_readx/", Qt::CaseInsensitive) + 10);
    } else if (rel.contains("/code/", Qt::CaseInsensitive)) {
        rel = rel.mid(rel.indexOf("/code/", Qt::CaseInsensitive) + 6);
    }

    while (rel.startsWith('/')) rel.remove(0, 1);

    QString repo_stripped = trimmed_root;
    while (repo_stripped.startsWith('/')) repo_stripped.remove(0, 1);
    if (!repo_stripped.isEmpty() && rel.startsWith(repo_stripped, Qt::CaseInsensitive)) {
        rel = rel.mid(repo_stripped.length());
        while (rel.startsWith('/')) rel.remove(0, 1);
    }

    QString absolute_path = QDir::cleanPath(QDir(trimmed_root).absoluteFilePath(rel));
    if (path_is_within_root(absolute_path, trimmed_root)) {
        if (ok) *ok = true;
        return absolute_path;
    }
    for (const QString& allowed : allowed_external_roots) {
        if (path_is_within_root(absolute_path, allowed)) {
            if (ok) *ok = true;
            return absolute_path;
        }
    }
    return QString();
}

QString extract_json_object_text(const QString& text) {
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty()) {
        return QString();
    }

    QJsonParseError direct_error;
    const QJsonDocument direct_doc = QJsonDocument::fromJson(trimmed.toUtf8(), &direct_error);
    if (direct_error.error == QJsonParseError::NoError && direct_doc.isObject()) {
        return trimmed;
    }

    const int first_brace = trimmed.indexOf('{');
    const int last_brace = trimmed.lastIndexOf('}');
    if (first_brace >= 0 && last_brace > first_brace) {
        const QString candidate = trimmed.mid(first_brace, last_brace - first_brace + 1);
        QJsonParseError candidate_error;
        const QJsonDocument candidate_doc = QJsonDocument::fromJson(candidate.toUtf8(), &candidate_error);
        if (candidate_error.error == QJsonParseError::NoError && candidate_doc.isObject()) {
            return candidate;
        }
    }
    return QString();
}

QString read_file_window_text(const QString& path, int start_line, int line_count) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QStringLiteral("read_file_failed");
    }

    const QString content = QString::fromUtf8(file.readAll());
    const QStringList lines = normalize_newlines(content).split(QChar('\n'));
    const int first = qMax(1, start_line);
    const int count = qMax(1, line_count);
    const int last = qMin(lines.size(), first + count - 1);
    QStringList window;
    for (int i = first; i <= last; ++i) {
        window.append(QString::number(i) + QStringLiteral(":") + lines.at(i - 1));
    }
    return window.join(QChar('\n'));
}

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

QString preferred_bash_program() {
    static QString cached;
    if (!cached.isEmpty()) {
        return cached;
    }

    const QStringList candidates = {
        QStringLiteral("C:/Program Files/Git/bin/bash.exe"),
        QStringLiteral("C:/Program Files/Git/usr/bin/bash.exe")
    };
    for (const QString& candidate : candidates) {
        if (QFileInfo::exists(candidate) && QFileInfo(candidate).isFile()) {
            cached = candidate;
            return cached;
        }
    }

    cached = QStringLiteral("bash");
    return cached;
}

bool is_windows_script_program(const QString& path) {
    const QString lowered = path.trimmed().toLower();
    return lowered.endsWith(QStringLiteral(".cmd"))
        || lowered.endsWith(QStringLiteral(".bat"));
}

bool is_runnable_s_candidate(const QString& candidate) {
    const QString trimmed = candidate.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }

    if (trimmed.contains('/') || trimmed.contains('\\') || QFileInfo(trimmed).isAbsolute()) {
        return QFileInfo::exists(trimmed) && QFileInfo(trimmed).isFile();
    }

    return !QStandardPaths::findExecutable(trimmed).isEmpty();
}

QString resolved_s_candidate_path(const QString& candidate) {
    const QString trimmed = candidate.trimmed();
    if (trimmed.isEmpty()) {
        return QString();
    }

    if (trimmed.contains('/') || trimmed.contains('\\') || QFileInfo(trimmed).isAbsolute()) {
        return QDir::cleanPath(QFileInfo(trimmed).absoluteFilePath());
    }

    const QString resolved = QStandardPaths::findExecutable(trimmed);
    return resolved.isEmpty() ? trimmed : resolved;
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
    const QUrl env_url(qEnvironmentVariable("NEURX_OLLAMA_URL").trimmed());
    if (env_url.isValid() && !env_url.host().trimmed().isEmpty()) {
        const QString env_host = env_url.host().trimmed().toLower();
        const int env_port = env_url.port();
        if (host == env_host && port == env_port) {
            return true;
        }
    }
    return host.contains("ollama");
}

bool looks_like_checkpoint_model_name(const QString& value) {
    const QString configured_name = value.trimmed();
    return configured_name.endsWith(".neurx", Qt::CaseInsensitive)
        || configured_name.contains('/')
        || configured_name.contains('\\')
        || configured_name.contains("gpt_large_pretrain", Qt::CaseInsensitive);
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
    base_url = base_url.trimmed();
    configured_name = configured_name.trimmed();
    backend = backend.trimmed().toLower();
    local_ollama_model_dir = local_ollama_model_dir.trimmed();
    const bool wants_ollama = backend == "ollama" || url_looks_like_ollama(base_url);
    const bool wants_local_s_backend = url_looks_like_s_backend(base_url);
    const bool looks_like_checkpoint_name = looks_like_checkpoint_model_name(configured_name);

    if (wants_ollama) {
        if (!configured_name.isEmpty() && configured_name != "local-model" && !looks_like_checkpoint_name) {
            return configured_name;
        }
        return QString::fromLatin1(kDefaultOllamaModel);
    }

    // Explicit user-configured name always wins; never replace a valid model name.
    // (e.g. "qwen2.5:0.5b" from NEURX_LLM_MODEL) with an auto-detected placeholder.
    // But never forward a checkpoint file path/basename as an Ollama or OpenAI model name.
    if (!configured_name.isEmpty() && configured_name != "local-model" && !looks_like_checkpoint_name) {
        return configured_name;
    }

    if (wants_local_s_backend && has_checkpoint_model && !checkpoint_model_file.trimmed().isEmpty()) {
        return checkpoint_model_file.trimmed();
    }

    return configured_name;
}

QString remote_code_agent_model_name(QString configured_name) {
    configured_name = configured_name.trimmed();
    if (configured_name.isEmpty() || configured_name == "local-model" || looks_like_checkpoint_model_name(configured_name)) {
        const QString env_vl_model = qEnvironmentVariable("NEURX_VL_MODEL").trimmed();
        if (!env_vl_model.isEmpty()) {
            return env_vl_model;
        }
        return QString::fromLatin1(kDefaultCodeAgentRemoteModel);
    }
    return configured_name;
}

QString remote_code_agent_chat_url() {
    const QString base_url = qEnvironmentVariable(
        "NEURX_CODE_AGENT_REMOTE_BASE_URL", kDefaultCodeAgentRemoteBaseUrl).trimmed();
    const QString chat_path = qEnvironmentVariable(
        "NEURX_CODE_AGENT_REMOTE_CHAT_PATH", kDefaultCodeAgentRemoteChatPath).trimmed();
    return join_url_and_path(base_url, chat_path);
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
        const QString inferred = checkpoints_dir.filePath("Qwen2.5-0.5B-Instruct");
        if (QFileInfo(inferred).exists() && QFileInfo(inferred).isDir()) {
            return QDir(inferred).absolutePath();
        }
    }

    return QString();
}

QString resolve_customer_service_fallback_model_dir(const QString& repo_root, const QString& checkpoint_root = QString()) {
    const QString env_dir = qEnvironmentVariable("NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL_DIR").trimmed();
    if (!env_dir.isEmpty() && QFileInfo(env_dir).exists() && QFileInfo(env_dir).isDir()) {
        return QDir(env_dir).absolutePath();
    }

    const QString compat_env_dir = qEnvironmentVariable("NEURX_OLLAMA_FALLBACK_MODEL_DIR").trimmed();
    if (!compat_env_dir.isEmpty() && QFileInfo(compat_env_dir).exists() && QFileInfo(compat_env_dir).isDir()) {
        return QDir(compat_env_dir).absolutePath();
    }

    if (!repo_root.trimmed().isEmpty()) {
        const QString inferred = QDir(repo_root).filePath(QString::fromLatin1(kDefaultCustomerServiceFallbackModelDir));
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

QString customer_service_fallback_model_name(const QString& repo_root, const QString& checkpoint_root) {
    const QString env_model = qEnvironmentVariable("NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL").trimmed();
    if (!env_model.isEmpty()) {
        return env_model;
    }

    const QString compat_env_model = qEnvironmentVariable("NEURX_OLLAMA_FALLBACK_MODEL").trimmed();
    if (!compat_env_model.isEmpty()) {
        return compat_env_model;
    }

    const QString fallback_dir = resolve_customer_service_fallback_model_dir(repo_root, checkpoint_root);
    if (!fallback_dir.isEmpty()) {
        return QString::fromLatin1(kDefaultCustomerServiceFallbackModel);
    }

    return QString();
}

bool prompt_targets_customer_service(const QString& prompt) {
    const QString text = prompt.trimmed().toLower();
    static const QStringList keywords = {
        "customer service", "customer support", "support ticket", "ticket", "after-sales",
        "after sales", "refund", "complaint", "order issue", "help desk",
        "customer support cn", "after sales cn", "ticket cn", "refund cn", "complaint cn", "order help cn", "support help cn", "service help cn"
    };
    for (const QString& keyword : keywords) {
        if (text.contains(keyword)) {
            return true;
        }
    }
    return false;
}

bool response_needs_customer_service_fallback(const QString& response_text) {
    const QString trimmed = response_text.trimmed();
    if (trimmed.isEmpty()) {
        return true;
    }

    const QString lowered = trimmed.toLower();
    if (lowered.startsWith("runtime_")
        || lowered.startsWith("local_model_")
        || lowered.startsWith("code_assistant_")) {
        return true;
    }

    static const QStringList weak_markers = {
        "i'm sorry", "i am sorry", "can't help", "cannot help", "unable to help",
        "please provide your request", "generic apology", "unable to process", "cannot process", "unable to help", "request more details"
    };
    for (const QString& marker : weak_markers) {
        if (lowered.contains(marker)) {
            return true;
        }
    }

    return trimmed.size() < 24;
}

QString clean_utf8_response(const QString& text) {
    QString cleaned = text;
    // Remove replacement characters and invalid Unicode
    cleaned.remove(QChar(0xFFFD)); // Unicode replacement character
    cleaned.remove(QChar(0xFEFF)); // BOM
    // Remove control characters except newlines and tabs
    QString result;
    result.reserve(cleaned.size());
    for (const QChar& ch : cleaned) {
        const ushort code = ch.unicode();
        if (code >= 32 || code == '\n' || code == '\r' || code == '\t') {
            result.append(ch);
        }
    }
    return result.trimmed();
}

bool response_requests_cleaner_prompt(const QString& response_text) {
    const QString lowered = response_text.trimmed().toLower();
    if (lowered.isEmpty()) {
        return false;
    }

    static const QStringList markers = {
        "too much repeated or noisy text",
        "noisy characters",
        "please rewrite in three lines",
        "background, problem, expected result",
        "please rewrite in three lines",
        "background, problem, expected result",
        "too much repeated or noisy text",
        "noisy characters"
    };
    for (const QString& marker : markers) {
        if (lowered.contains(marker.toLower())) {
            return true;
        }
    }
    return false;
}

bool response_looks_garbled(const QString& response_text) {
    const QString text = response_text.trimmed();
    if (text.isEmpty()) {
        return false;
    }

    const QString lowered = text.toLower();
    int signal_count = 0;

    if (lowered.contains("classclass")
        || lowered.contains("```python\nclass\n")
        || lowered.contains("```cpp\nclass\n")
        || lowered.contains("habiabit")
        || lowered.contains("arious")
        || lowered.contains("definition")
        || lowered.contains("garbled example output")) {
        signal_count += 2;
    }

    static const QStringList noise_markers = {
        "[attr]",
        "user",
        "user-facing garble",
        "s????????rne",
        "equip",
        "garbled unicode",
        "verbatim",
        "wide",
        "class due to",
        "class define"
    };
    for (const QString& marker : noise_markers) {
        if (lowered.contains(marker.toLower())) {
            signal_count += 1;
        }
    }

    const int code_fence_count = text.count("```");
    if (code_fence_count >= 3) {
        signal_count += 1;
    }

    const int colon_count = text.count(':');
    const int newline_count = text.count('\n');
    if (colon_count >= 4 && newline_count <= 8 && code_fence_count >= 2) {
        signal_count += 1;
    }

    return signal_count >= 2;
}

QString sanitize_code_assistant_prompt(const QString& prompt) {
    const QStringList raw_lines = prompt.split('\n');
    QStringList kept_lines;
    QString previous_normalized;
    int dropped_runtime_lines = 0;
    int dropped_html_lines = 0;

    for (QString line : raw_lines) {
        line = line.trimmed();
        if (line.isEmpty()) {
            continue;
        }

        const QString lowered = line.toLower();
        if (lowered.startsWith("bridge ")
            || lowered.startsWith("runtime_")
            || lowered.startsWith("qrc:/")
            || lowered.startsWith("gmake[")
            || lowered.startsWith("cmake:")
            || lowered.startsWith("launching qt application")
            || lowered.startsWith("ollama ")
            || lowered.startsWith("build dir:")
            || lowered.startsWith("checkpoint ")
            || lowered.startsWith("llm backend:")
            || lowered.startsWith("code agent ")
            || lowered.contains("504 gateway time-out")
            || lowered.contains("nginx/1.18.0")
            || lowered.contains("unknown model:")
            || lowered.contains("http_request start")
            || lowered.contains("http_request failed")
            || lowered.contains("http_request done")) {
            ++dropped_runtime_lines;
            continue;
        }

        if (lowered.startsWith("<html")
            || lowered.startsWith("<head>")
            || lowered.startsWith("<body>")
            || lowered.startsWith("<center>")
            || lowered.startsWith("<hr")
            || lowered.startsWith("</")) {
            ++dropped_html_lines;
            continue;
        }

        QString normalized = lowered;
        normalized.replace('\t', ' ');
        while (normalized.contains("  ")) {
            normalized.replace("  ", " ");
        }
        if (normalized == previous_normalized) {
            continue;
        }
        previous_normalized = normalized;
        kept_lines.append(line);
        if (kept_lines.size() >= 12) {
            break;
        }
    }

    QString cleaned = kept_lines.join('\n').trimmed();
    if (cleaned.isEmpty()) {
        cleaned = prompt.trimmed();
    }

    if (cleaned.size() > 1200) {
        cleaned = cleaned.left(1200).trimmed();
    }

    if (dropped_runtime_lines > 0 || dropped_html_lines > 0) {
        cleaned = QString(
            "Background: I am using the NeurX code assistant in the repository.\n"
            "Problem: %1\n"
            "Expected result: Provide a direct technical answer or code change without commenting on input noise.")
            .arg(cleaned);
    }

    return cleaned;
}

bool prompt_requests_delete_operation(const QString& prompt) {
    const QString text = prompt.trimmed();
    if (text.isEmpty()) {
        return false;
    }
    const QString chineseDelete = QString(QChar(0x5220)) + QString(QChar(0x9664));
    return text.contains(QStringLiteral("delete"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("remove"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("cleanup"), Qt::CaseInsensitive)
        || text.contains(chineseDelete, Qt::CaseInsensitive);
}

QString strip_path_like_tokens_from_prompt(const QString& prompt);

bool prompt_requests_rename_operation(const QString& prompt) {
    const QString text = strip_path_like_tokens_from_prompt(prompt);
    if (text.isEmpty()) {
        return false;
    }
    return text.contains(QStringLiteral("rename"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("move"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("rename to"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("改名"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("重命名"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("改成"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("改为"), Qt::CaseInsensitive);
}

QString strip_path_like_tokens_from_prompt(const QString& prompt) {
    QString normalized = prompt;
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\t'), QLatin1Char(' '));
    while (normalized.contains(QStringLiteral("  "))) {
        normalized.replace(QStringLiteral("  "), QStringLiteral(" "));
    }

    QStringList kept;
    const QStringList tokens = normalized.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (QString token : tokens) {
        token = token.trimmed();
        while (!token.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(token.front())) {
            token.remove(0, 1);
        }
        while (!token.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(token.back())) {
            token.chop(1);
        }
        token = QDir::fromNativeSeparators(token);
        if (token.startsWith(QStringLiteral("./"))) {
            token.remove(0, 2);
        }
        if (token.startsWith(QStringLiteral("neurx/"), Qt::CaseInsensitive)) {
            token.remove(0, 6);
        } else if (token.startsWith(QStringLiteral("ne_readx/"), Qt::CaseInsensitive)) {
            token.remove(0, 9);
        } else if (token.startsWith(QStringLiteral("code/"), Qt::CaseInsensitive)) {
            token.remove(0, 5);
        }
        if (token.isEmpty()) {
            continue;
        }
        const bool is_absolute = token.startsWith(QLatin1Char('/'))
            || (token.size() >= 3
                && token.at(1) == QLatin1Char(':')
                && (token.at(2) == QLatin1Char('/') || token.at(2) == QLatin1Char('\\')));
        const bool is_relative_path = token.contains(QLatin1Char('/')) || token.contains(QLatin1Char('\\'));
        if (is_absolute || is_relative_path) {
            continue;
        }
        kept.append(token);
    }
    return kept.join(QChar(' ')).trimmed();
}

bool prompt_requests_create_file_operation(const QString& prompt) {
    const QString text = strip_path_like_tokens_from_prompt(prompt);
    if (text.isEmpty()) {
        return false;
    }
    const QString chineseCreate = QString(QChar(0x521b)) + QString(QChar(0x5efa));
    const QString chineseNew = QString(QChar(0x65b0)) + QString(QChar(0x5efa));
    const QString chineseFile = QString(QChar(0x6587)) + QString(QChar(0x4ef6));
    const bool mentions_create =
        text.contains(QStringLiteral("create file"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("new file"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("add file"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("touch "), Qt::CaseInsensitive)
        || text.contains(chineseCreate + chineseFile, Qt::CaseInsensitive)
        || text.contains(chineseNew + chineseFile, Qt::CaseInsensitive)
        || (text.contains(chineseCreate, Qt::CaseInsensitive)
            && text.contains(chineseFile, Qt::CaseInsensitive));
    if (mentions_create) {
        return true;
    }

    const bool mentions_create_verb =
        text.contains(QStringLiteral("create"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("new"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("add"), Qt::CaseInsensitive)
        || text.contains(chineseCreate, Qt::CaseInsensitive)
        || text.contains(chineseNew, Qt::CaseInsensitive);
    if (!mentions_create_verb) {
        return false;
    }

    static const QRegularExpression kFileLikeNamePattern(
        QStringLiteral("[^\\s/\\\\]+\\.[A-Za-z0-9]{1,16}"));
    return kFileLikeNamePattern.match(text).hasMatch();
}

bool prompt_targets_current_file(const QString& prompt) {
    const QString text = prompt.trimmed();
    if (text.isEmpty()) {
        return false;
    }
    return text.contains(QStringLiteral("this file"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("current file"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("selected file"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("该文件"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("当前文件"), Qt::CaseInsensitive)
        || text.contains(QStringLiteral("这个文件"), Qt::CaseInsensitive);
}

QString normalize_prompt_path_token(QString token) {
    token = token.trimmed();
    while (!token.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(token.front())) {
        token.remove(0, 1);
    }
    while (!token.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(token.back())) {
        token.chop(1);
    }
    token = QDir::fromNativeSeparators(token);
    if (token.startsWith(QStringLiteral("./"))) {
        token.remove(0, 2);
    }
    if (token.startsWith(QStringLiteral("neurx/"), Qt::CaseInsensitive)) {
        token.remove(0, 6);
    } else if (token.startsWith(QStringLiteral("ne_readx/"), Qt::CaseInsensitive)) {
        token.remove(0, 9);
    } else if (token.startsWith(QStringLiteral("code/"), Qt::CaseInsensitive)) {
        token.remove(0, 5);
    }
    return token;
}

QString extract_path_candidate_from_prompt(const QString& prompt) {
    QString normalized = prompt;
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\t'), QLatin1Char(' '));
    while (normalized.contains(QStringLiteral("  "))) {
        normalized.replace(QStringLiteral("  "), QStringLiteral(" "));
    }

    const QStringList tokens = normalized.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (QString token : tokens) {
        token = normalize_prompt_path_token(token);
        if (token.isEmpty()) {
            continue;
        }
        if (token.size() >= 3
            && token.at(1) == QLatin1Char(':')
            && (token.at(2) == QLatin1Char('/') || token.at(2) == QLatin1Char('\\'))) {
            return QDir::cleanPath(token);
        }
        if (token.startsWith(QLatin1Char('/'))) {
            return QDir::cleanPath(token);
        }
        if (token.contains(QLatin1Char('/')) || token.contains(QLatin1Char('\\'))) {
            return QDir::cleanPath(token);
        }
        const int dot_index = token.lastIndexOf(QLatin1Char('.'));
        if (dot_index > 0 && dot_index < token.size() - 1) {
            return token;
        }
    }

    return QString();
}

QString extract_file_name_candidate_from_prompt(const QString& prompt) {
    QString normalized = prompt;
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\t'), QLatin1Char(' '));
    while (normalized.contains(QStringLiteral("  "))) {
        normalized.replace(QStringLiteral("  "), QStringLiteral(" "));
    }

    const QStringList tokens = normalized.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    static const QRegularExpression kFileLikeNamePattern(
        QStringLiteral("([^\\s/\\\\]+\\.[A-Za-z0-9]{1,16})"));
    const auto cleanup_file_name = [](QString name) {
        static const QStringList prefixes = {
            QStringLiteral("创建"),
            QStringLiteral("新建"),
            QStringLiteral("create"),
            QStringLiteral("new"),
            QStringLiteral("add")
        };
        QString next = name.trimmed();
        for (const QString& prefix : prefixes) {
            if (next.startsWith(prefix, Qt::CaseInsensitive) && next.size() > prefix.size()) {
                next = next.mid(prefix.size()).trimmed();
                break;
            }
        }
        while (!next.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(next.front())) {
            next.remove(0, 1);
        }
        while (!next.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(next.back())) {
            next.chop(1);
        }
        return next;
    };
    for (QString token : tokens) {
        token = normalize_prompt_path_token(token);
        if (token.isEmpty()) {
            continue;
        }
        if (token.contains(QLatin1Char('/')) || token.contains(QLatin1Char('\\'))) {
            const QFileInfo info(token);
            const QString name = cleanup_file_name(info.fileName().trimmed());
            if (kFileLikeNamePattern.match(name).hasMatch()) {
                return name;
            }
            continue;
        }
        const QRegularExpressionMatch match = kFileLikeNamePattern.match(cleanup_file_name(token));
        if (match.hasMatch()) {
            return match.captured(1);
        }
    }
    return QString();
}

QStringList extract_file_name_candidates_from_prompt(const QString& prompt) {
    QString normalized = prompt;
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\t'), QLatin1Char(' '));
    while (normalized.contains(QStringLiteral("  "))) {
        normalized.replace(QStringLiteral("  "), QStringLiteral(" "));
    }

    const QStringList tokens = normalized.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    static const QRegularExpression kFileLikeNamePattern(
        QStringLiteral("([^\\s/\\\\]+\\.[A-Za-z0-9]{1,16})"));
    QStringList results;
    const auto cleanup_file_name = [](QString name) {
        static const QStringList prefixes = {
            QStringLiteral("创建"),
            QStringLiteral("新建"),
            QStringLiteral("create"),
            QStringLiteral("new"),
            QStringLiteral("add"),
            QStringLiteral("rename"),
            QStringLiteral("改名为"),
            QStringLiteral("重命名为"),
            QStringLiteral("改成"),
            QStringLiteral("改为")
        };
        QString next = name.trimmed();
        for (const QString& prefix : prefixes) {
            if (next.startsWith(prefix, Qt::CaseInsensitive) && next.size() > prefix.size()) {
                next = next.mid(prefix.size()).trimmed();
                break;
            }
        }
        while (!next.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(next.front())) {
            next.remove(0, 1);
        }
        while (!next.isEmpty() && QStringLiteral("\"'`,;:()[]{}<>").contains(next.back())) {
            next.chop(1);
        }
        return next;
    };
    for (QString token : tokens) {
        token = normalize_prompt_path_token(token);
        if (token.isEmpty()) {
            continue;
        }
        QString candidate;
        if (token.contains(QLatin1Char('/')) || token.contains(QLatin1Char('\\'))) {
            candidate = cleanup_file_name(QFileInfo(token).fileName().trimmed());
        } else {
            const QRegularExpressionMatch match = kFileLikeNamePattern.match(cleanup_file_name(token));
            if (match.hasMatch()) {
                candidate = match.captured(1);
            }
        }
        if (!candidate.isEmpty() && !results.contains(candidate)) {
            results.append(candidate);
        }
    }
    return results;
}

QStringList extract_path_candidates_from_prompt(const QString& prompt) {
    QString normalized = prompt;
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\t'), QLatin1Char(' '));
    while (normalized.contains(QStringLiteral("  "))) {
        normalized.replace(QStringLiteral("  "), QStringLiteral(" "));
    }

    QStringList results;
    const QStringList tokens = normalized.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (QString token : tokens) {
        token = normalize_prompt_path_token(token);
        if (token.isEmpty()) {
            continue;
        }
        if (token.size() >= 3
            && token.at(1) == QLatin1Char(':')
            && (token.at(2) == QLatin1Char('/') || token.at(2) == QLatin1Char('\\'))) {
            results.append(QDir::cleanPath(token));
            continue;
        }
        if (token.startsWith(QLatin1Char('/'))) {
            results.append(QDir::cleanPath(token));
            continue;
        }
        if (token.contains(QLatin1Char('/')) || token.contains(QLatin1Char('\\'))) {
            results.append(QDir::cleanPath(token));
        }
    }
    results.removeDuplicates();
    return results;
}

QString extract_delete_target_path(const QString& prompt, const QString& file_path) {
    const QString explicit_file = QDir::cleanPath(file_path.trimmed());
    if (!explicit_file.isEmpty() && prompt_targets_current_file(prompt)) {
        return explicit_file;
    }
    return extract_path_candidate_from_prompt(prompt);
}

QString extract_create_target_path(const QString& prompt, const QString& file_path) {
    const QString explicit_file = QDir::cleanPath(file_path.trimmed());
    if (!explicit_file.isEmpty() && prompt_targets_current_file(prompt)) {
        return explicit_file;
    }
    const QString path_candidate = extract_path_candidate_from_prompt(prompt);
    const QString file_name_candidate = extract_file_name_candidate_from_prompt(prompt);
    if (!path_candidate.isEmpty()) {
        const QFileInfo info(path_candidate);
        if (!file_name_candidate.isEmpty() && (info.isDir() || (!info.exists() && !path_candidate.contains(QLatin1Char('.'))))) {
            return QDir(path_candidate).filePath(file_name_candidate);
        }
        return path_candidate;
    }
    return file_name_candidate;
}

QString extract_rename_source_path(const QString& prompt, const QString& file_path) {
    const QString explicit_file = QDir::cleanPath(file_path.trimmed());
    if (!explicit_file.isEmpty() && prompt_targets_current_file(prompt)) {
        return explicit_file;
    }
    const QStringList path_candidates = extract_path_candidates_from_prompt(prompt);
    if (!path_candidates.isEmpty()) {
        return path_candidates.first();
    }
    return QString();
}

QString extract_rename_target_path(const QString& prompt,
                                   const QString& file_path,
                                   const QString& source_path) {
    const QStringList path_candidates = extract_path_candidates_from_prompt(prompt);
    if (path_candidates.size() >= 2) {
        return path_candidates.at(1);
    }
    const QStringList file_name_candidates = extract_file_name_candidates_from_prompt(prompt);
    QString target_name;
    if (!file_name_candidates.isEmpty()) {
        const QString source_name = QFileInfo(source_path).fileName().trimmed();
        for (const QString& candidate : file_name_candidates) {
            if (!source_name.isEmpty() && candidate == source_name) {
                continue;
            }
            target_name = candidate;
        }
        if (target_name.isEmpty()) {
            target_name = file_name_candidates.last();
        }
    }
    if (target_name.isEmpty()) {
        return QString();
    }

    const QString explicit_file = QDir::cleanPath(file_path.trimmed());
    if (!explicit_file.isEmpty() && prompt_targets_current_file(prompt)) {
        return QDir(QFileInfo(explicit_file).absolutePath()).filePath(target_name);
    }
    if (!source_path.trimmed().isEmpty()) {
        return QDir(QFileInfo(source_path).absolutePath()).filePath(target_name);
    }
    return target_name;
}

QString extract_create_file_content(const QString& prompt, const QString& target_path = QString()) {
    const int fence_start = prompt.indexOf(QStringLiteral("```"));
    if (fence_start >= 0) {
        const int first_line_end = prompt.indexOf(QChar('\n'), fence_start + 3);
        const int content_start = first_line_end >= 0 ? first_line_end + 1 : fence_start + 3;
        const int fence_end = prompt.indexOf(QStringLiteral("```"), content_start);
        if (fence_end > content_start) {
            return normalize_newlines(prompt.mid(content_start, fence_end - content_start).trimmed());
        }
    }

    const QStringList markers = {
        QStringLiteral("content:"),
        QStringLiteral("contents:"),
        QStringLiteral("with content:"),
        QStringLiteral("内容："),
        QStringLiteral("内容:"),
        QStringLiteral("写入："),
        QStringLiteral("写入:")
    };
    const QString lowered = prompt.toLower();
    for (const QString& marker : markers) {
        const int idx = lowered.indexOf(marker.toLower());
        if (idx >= 0) {
            const QString suffix = prompt.mid(idx + marker.size()).trimmed();
            if (!suffix.isEmpty()) {
                return normalize_newlines(suffix);
            }
        }
    }

    const bool wants_implementation =
        lowered.contains(QStringLiteral("implement"))
        || lowered.contains(QStringLiteral("实现"))
        || lowered.contains(QStringLiteral("编写"))
        || lowered.contains(QStringLiteral("写一个"))
        || lowered.contains(QStringLiteral("用c++实现"))
        || lowered.contains(QStringLiteral("用 c++ 实现"))
        || lowered.contains(QStringLiteral("with c++"));
    const bool wants_cpp =
        lowered.contains(QStringLiteral("c++"))
        || lowered.contains(QStringLiteral("cpp"));
    if (wants_implementation && wants_cpp) {
        const QFileInfo info(target_path.trimmed());
        const QString file_name = info.fileName().trimmed().isEmpty()
            ? target_path.trimmed()
            : info.fileName().trimmed();
        const QString base_name = info.completeBaseName().trimmed().isEmpty()
            ? file_name
            : info.completeBaseName().trimmed();
        const QString suffix = info.suffix().trimmed().toLower();

        if (base_name.compare(QStringLiteral("main"), Qt::CaseInsensitive) == 0
            || base_name.compare(QStringLiteral("hello"), Qt::CaseInsensitive) == 0) {
            return QString(
                "#include <iostream>\n\n"
                "int main() {\n"
                "    std::cout << \"Hello, world!\" << std::endl;\n"
                "    return 0;\n"
                "}\n");
        }

        if (suffix == QStringLiteral("h") || suffix == QStringLiteral("hh")
            || suffix == QStringLiteral("hpp") || suffix == QStringLiteral("hxx")) {
            QString guard = base_name.toUpper();
            guard.replace(QRegularExpression(QStringLiteral("[^A-Z0-9]+")), QStringLiteral("_"));
            if (guard.isEmpty()) {
                guard = QStringLiteral("GENERATED_HEADER");
            }
            guard += QStringLiteral("_H");
            return QString(
                "#ifndef %1\n"
                "#define %1\n\n"
                "class %2 {\n"
                "public:\n"
                "    %2();\n"
                "};\n\n"
                "#endif\n")
                .arg(guard, base_name.left(1).toUpper() + base_name.mid(1));
        }

        const QString class_name = base_name.left(1).toUpper() + base_name.mid(1);
        return QString(
            "#include <iostream>\n\n"
            "void %1() {\n"
            "    std::cout << \"%2\" << std::endl;\n"
            "}\n")
            .arg(base_name.compare(class_name, Qt::CaseSensitive) == 0
                    ? QStringLiteral("run")
                    : base_name,
                 class_name);
    }

    return QString();
}

QString rewrite_code_assistant_prompt_for_noise_retry(const QString& prompt) {
    const QString cleaned = sanitize_code_assistant_prompt(prompt);
    return QString(
        "Answer the user request directly. Do not comment on formatting, noise, repetition, or language choice.\n"
        "Use only Simplified Chinese unless the user explicitly requests another language.\n"
        "Do not invent example code in another language when the request is about an existing file.\n"
        "Background: Working in the NeurX repository.\n"
        "Problem: %1\n"
        "Expected result: If a file path is mentioned, analyze that file only. Give a concise technical answer first, and include code only when the user explicitly asks for code changes.")
        .arg(cleaned);
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

QString stream_content_from_object(const QJsonObject& obj) {
    if (obj.value("message").isObject()) {
        const QString content = obj.value("message").toObject().value("content").toString();
        if (!content.isEmpty()) {
            return content;
        }
    }

    if (obj.value("response").isString()) {
        const QString content = obj.value("response").toString();
        if (!content.isEmpty()) {
            return content;
        }
    }

    if (obj.value("choices").isArray()) {
        const QJsonArray choices = obj.value("choices").toArray();
        if (!choices.isEmpty() && choices.first().isObject()) {
            const QJsonObject first = choices.first().toObject();
            if (first.value("delta").isObject()) {
                const QString content = first.value("delta").toObject().value("content").toString();
                if (!content.isEmpty()) {
                    return content;
                }
            }
            if (first.value("message").isObject()) {
                const QString content = first.value("message").toObject().value("content").toString();
                if (!content.isEmpty()) {
                    return content;
                }
            }
            if (first.value("text").isString()) {
                const QString content = first.value("text").toString();
                if (!content.isEmpty()) {
                    return content;
                }
            }
        }
    }

    return QString();
}

bool stream_done_from_object(const QJsonObject& obj) {
    if (obj.value("done").toBool(false)) {
        return true;
    }

    if (obj.value("choices").isArray()) {
        const QJsonArray choices = obj.value("choices").toArray();
        if (!choices.isEmpty() && choices.first().isObject()) {
            const QString finish_reason = choices.first().toObject().value("finish_reason").toString();
            if (!finish_reason.isEmpty()) {
                return true;
            }
        }
    }

    return false;
}

bool parse_stream_line(const QByteArray& raw_line, QString* chunk, QJsonObject* obj, bool* done) {
    QByteArray line = raw_line.trimmed();
    if (line.isEmpty()) {
        return false;
    }

    if (line.startsWith("data:")) {
        line = line.mid(5).trimmed();
    }

    if (line == "[DONE]") {
        if (done) {
            *done = true;
        }
        if (chunk) {
            chunk->clear();
        }
        if (obj) {
            *obj = QJsonObject();
        }
        return true;
    }

    QJsonParseError parse_error;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &parse_error);
    if (parse_error.error != QJsonParseError::NoError || !doc.isObject()) {
        return false;
    }

    const QJsonObject parsed = doc.object();
    if (obj) {
        *obj = parsed;
    }
    if (chunk) {
        *chunk = stream_content_from_object(parsed);
    }
    if (done) {
        *done = stream_done_from_object(parsed);
    }
    return true;
}

QString run_streaming_chat_request(NeurxBridge* bridge,
                                   const QString& url,
                                   const QString& body_file,
                                   int timeout_ms,
                                   QString* accumulated_content,
                                   QJsonObject* last_object) {
    const QString curl = QStandardPaths::findExecutable("curl");
    if (curl.isEmpty()) {
        return QStringLiteral("runtime_exec_failed: curl not found");
    }

    QProcess proc;
    QStringList args;
    args << "-N" << "-sS"
         << "-X" << "POST"
         << url
         << "-H" << "Content-Type: application/json"
         << "--connect-timeout" << "5"
         << "--max-time" << QString::number(qMax(1, timeout_ms / 1000))
         << "--data-binary" << QString("@%1").arg(body_file);
    proc.setProgram(curl);
    proc.setArguments(args);
    proc.start();

    if (!proc.waitForStarted(10000)) {
        return QStringLiteral("runtime_exec_failed: failed to start curl");
    }

    QByteArray stdout_buffer;
    QByteArray stderr_buffer;
    QString content;
    QJsonObject final_object;
    QElapsedTimer timer;
    timer.start();

    auto flush_stdout = [&]() {
        stdout_buffer.append(proc.readAllStandardOutput());
        stderr_buffer.append(proc.readAllStandardError());

        while (true) {
            const int newline = stdout_buffer.indexOf('\n');
            if (newline < 0) {
                break;
            }

            const QByteArray line = stdout_buffer.left(newline);
            stdout_buffer.remove(0, newline + 1);

            QString chunk;
            QJsonObject parsed;
            bool done = false;
            if (!parse_stream_line(line, &chunk, &parsed, &done)) {
                continue;
            }
            if (!parsed.isEmpty()) {
                final_object = parsed;
            }
            if (!chunk.isEmpty()) {
                content += chunk;
                if (bridge) {
                    QMetaObject::invokeMethod(
                        bridge,
                        [bridge, chunk]() {
                            emit bridge->agentRunChunk(chunk);
                        },
                        Qt::QueuedConnection);
                }
            }
            if (done) {
                continue;
            }
        }
    };

    while (proc.state() != QProcess::NotRunning) {
        const int remaining = timeout_ms - static_cast<int>(timer.elapsed());
        if (remaining <= 0) {
            proc.kill();
            proc.waitForFinished(5000);
            return QStringLiteral("runtime_timeout: curl");
        }
        proc.waitForReadyRead(qMin(200, remaining));
        proc.waitForFinished(0);
        flush_stdout();
    }

    flush_stdout();
    if (!stdout_buffer.trimmed().isEmpty()) {
        QString chunk;
        QJsonObject parsed;
        bool done = false;
        if (parse_stream_line(stdout_buffer, &chunk, &parsed, &done)) {
            if (!parsed.isEmpty()) {
                final_object = parsed;
            }
            if (!chunk.isEmpty()) {
                content += chunk;
                if (bridge) {
                    QMetaObject::invokeMethod(
                        bridge,
                        [bridge, chunk]() {
                            emit bridge->agentRunChunk(chunk);
                        },
                        Qt::QueuedConnection);
                }
            }
        }
    }

    if (accumulated_content) {
        *accumulated_content = content;
    }
    if (last_object) {
        *last_object = final_object;
    }

    const QString stderr_text = QString::fromUtf8(stderr_buffer).trimmed();
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        if (!stderr_text.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(stderr_text.left(200));
        }
        if (!content.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(content.left(200));
        }
        return QStringLiteral("runtime_exec_failed: curl");
    }

    return QString();
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
    const QString env_remote_only = qEnvironmentVariable("NEURX_REMOTE_ONLY").trimmed().toLower();
    const bool remote_only = env_remote_only.isEmpty()
        ? false
        : !(env_remote_only == "0" || env_remote_only == "false" || env_remote_only == "no" || env_remote_only == "off");
    const QString remote_base_url = qEnvironmentVariable(
        "NEURX_REMOTE_BASE_URL", kDefaultCodeAgentRemoteBaseUrl).trimmed();
    const QString remote_chat_path = sanitize_chat_path(qEnvironmentVariable(
        "NEURX_REMOTE_CHAT_PATH", kDefaultCodeAgentRemoteChatPath));
    const QString remote_model_name = remote_code_agent_model_name(
        qEnvironmentVariable("NEURX_REMOTE_MODEL").trimmed());
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
        local_model_enabled_ = remote_only || !env_base_url.trimmed().isEmpty();
    }

    if (!env_backend.trimmed().isEmpty()) {
        local_model_backend_ = normalize_local_model_backend(env_backend);
    }
    if (remote_only) {
        local_model_backend_ = "openai";
        local_model_base_url_ = remote_base_url;
    } else if (!env_base_url.trimmed().isEmpty()) {
        local_model_base_url_ = env_base_url.trimmed();
    } else {
        local_model_base_url_ = !checkpoint_model_file_.isEmpty()
            ? "http://127.0.0.1:18080"
            : (!local_ollama_model_dir.isEmpty() || local_model_backend_ == "ollama")
            ? qEnvironmentVariable("NEURX_OLLAMA_URL", "http://127.0.0.1:11434")
            : "http://127.0.0.1:8000";
    }
    if (remote_only) {
        local_model_name_ = remote_model_name;
    } else if (!env_name.trimmed().isEmpty()) {
        local_model_name_ = env_name.trimmed();
    } else if (!checkpoint_model_file_.isEmpty()) {
        local_model_name_ = checkpoint_model_file_;
    } else if (local_model_backend_ == "ollama") {
        local_model_name_ = local_ollama_model_dir.isEmpty()
            ? QString::fromLatin1(kDefaultOllamaModel)
            : QString::fromLatin1(kDefaultLocalOllamaModel);
    }
    if (remote_only) {
        local_model_chat_path_ = remote_chat_path;
    } else if (!env_chat_path.trimmed().isEmpty()) {
        local_model_chat_path_ = sanitize_chat_path(env_chat_path);
    } else if (!checkpoint_model_file_.isEmpty()) {
        local_model_chat_path_ = "/neurx/api/chat";
    } else {
        local_model_chat_path_ = local_model_default_chat_path();
    }

    const bool has_checkpoint_model = !checkpoint_model_file_.isEmpty();
    const bool env_name_is_checkpoint = looks_like_checkpoint_model_name(env_name.trimmed());
    const bool base_url_is_not_local_s_backend = !url_looks_like_s_backend(local_model_base_url_);
    if (!remote_only && has_checkpoint_model && base_url_is_not_local_s_backend
        && (env_name.trimmed().isEmpty() || env_name_is_checkpoint)) {
        local_model_backend_ = "openai";
        local_model_base_url_ = "http://127.0.0.1:18080";
        local_model_chat_path_ = "/neurx/api/chat";
        local_model_name_ = checkpoint_model_file_;
    }

    const bool default_local_setup = env_enabled.trimmed().isEmpty()
        && env_backend.trimmed().isEmpty()
        && env_base_url.trimmed().isEmpty()
        && env_name.trimmed().isEmpty()
        && env_chat_path.trimmed().isEmpty();
    if (default_local_setup) {
        local_model_enabled_ = true;
        if (remote_only) {
            local_model_backend_ = "openai";
            local_model_base_url_ = remote_base_url;
            local_model_name_ = remote_model_name;
            local_model_chat_path_ = remote_chat_path;
        } else if (!local_ollama_model_dir.isEmpty()) {
            local_model_backend_ = "ollama";
            local_model_base_url_ = qEnvironmentVariable("NEURX_OLLAMA_URL", "http://127.0.0.1:11434");
            local_model_name_ = QString::fromLatin1(kDefaultLocalOllamaModel);
            local_model_chat_path_ = local_model_default_chat_path();
        } else if (!checkpoint_model_file_.isEmpty()) {
            local_model_backend_ = "openai";
            local_model_base_url_ = "http://127.0.0.1:18080";
            local_model_name_ = checkpoint_model_file_;
            local_model_chat_path_ = "/neurx/api/chat";
        } else {
            local_model_backend_ = "ollama";
            local_model_base_url_ = qEnvironmentVariable("NEURX_OLLAMA_URL", "http://127.0.0.1:11434");
            local_model_name_ = QString::fromLatin1(kDefaultOllamaModel);
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
        local_model_name_ = resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_).isEmpty()
            ? QString::fromLatin1(kDefaultOllamaModel)
            : QString::fromLatin1(kDefaultLocalOllamaModel);
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

    QByteArray stdout_data;
    QByteArray stderr_data;
    QElapsedTimer timer;
    timer.start();
    const bool diag = run_diag_enabled();

    while (true) {
        const bool finished = proc.waitForFinished(100);

        const QByteArray out = proc.readAllStandardOutput();
        if (!out.isEmpty()) {
            stdout_data.append(out);
        }

        const QByteArray err = proc.readAllStandardError();
        if (!err.isEmpty()) {
            stderr_data.append(err);
            if (diag) {
                fwrite(err.constData(), 1, err.size(), stderr);
                fflush(stderr);
            }
        }

        if (finished) {
            break;
        }

        if (timer.elapsed() > timeout_ms) {
            proc.kill();
            proc.waitForFinished(5000);
            return QString("runtime_timeout: %1").arg(program);
        }
    }

    const QString stdout_text = QString::fromUtf8(stdout_data).trimmed();
    const QString stderr_text = QString::fromUtf8(stderr_data).trimmed();

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        if (!stderr_text.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(stderr_text.left(500));
        }
        if (!stdout_text.isEmpty()) {
            return QString("runtime_exec_failed: %1").arg(stdout_text.left(500));
        }
        return QString("runtime_exec_failed: %1").arg(program);
    }

    return stdout_text;
}

QString NeurxBridge::resolve_s_binary(const QString& repo_root) const {
    const QStringList env_candidates = {
        qEnvironmentVariable("NEURX_S_BINARY").trimmed(),
        qEnvironmentVariable("S_BINARY").trimmed()
    };
    for (const QString& candidate : env_candidates) {
        if (is_runnable_s_candidate(candidate)) {
            return resolved_s_candidate_path(candidate);
        }
    }

    const QStringList path_candidates = {
        QStringLiteral("s.cmd"),
        QStringLiteral("s.exe"),
        QStringLiteral("s")
    };
    for (const QString& candidate : path_candidates) {
        if (is_runnable_s_candidate(candidate)) {
            return resolved_s_candidate_path(candidate);
        }
    }

    const QString home_dir = QDir::homePath();
    const QStringList file_candidates = {
        qEnvironmentVariable("S_ROOT").trimmed().isEmpty()
            ? QString()
            : QDir(qEnvironmentVariable("S_ROOT").trimmed()).filePath("bin/s.cmd"),
        qEnvironmentVariable("S_ROOT").trimmed().isEmpty()
            ? QString()
            : QDir(qEnvironmentVariable("S_ROOT").trimmed()).filePath("bin/s.exe"),
        qEnvironmentVariable("S_ROOT").trimmed().isEmpty()
            ? QString()
            : QDir(qEnvironmentVariable("S_ROOT").trimmed()).filePath("bin/s"),
        QDir(home_dir).filePath("s/bin/s.cmd"),
        QDir(home_dir).filePath("s/bin/s.exe"),
        QDir(home_dir).filePath("s/bin/s"),
        QDir(repo_root).filePath("../s/bin/s.cmd"),
        QDir(repo_root).filePath("../s/bin/s.exe"),
        QDir(repo_root).filePath("../s/bin/s")
    };
    for (const QString& candidate : file_candidates) {
        if (is_runnable_s_candidate(candidate)) {
            return resolved_s_candidate_path(candidate);
        }
    }

    return QString();
}

QString NeurxBridge::run_s_cli(const QString& s_binary,
                               const QStringList& args,
                               int timeout_ms,
                               const QString& working_dir) const {
    const QString trimmed = s_binary.trimmed();
    if (trimmed.isEmpty()) {
        return QStringLiteral("runtime_exec_failed: no S binary configured");
    }

#ifdef Q_OS_WIN
    if (is_windows_script_program(trimmed)) {
        QStringList cmd_args;
        cmd_args << QStringLiteral("/c") << QDir::toNativeSeparators(trimmed);
        cmd_args.append(args);
        return run_process(QStringLiteral("cmd.exe"), cmd_args, timeout_ms, working_dir);
    }
#endif

    return run_process(trimmed, args, timeout_ms, working_dir);
}

QString NeurxBridge::run_http_request(const QString& method, const QString& url, const QString& body_file, int timeout_ms) const {
    const QString node = QStandardPaths::findExecutable("node");
    if (node.isEmpty()) {
        return "runtime_exec_failed: node not found";
    }

    const int request_timeout_ms = qMax(1000, timeout_ms - 2000);
    const QString api_key = qEnvironmentVariable("NEURX_API_KEY").trimmed();
    qInfo().noquote() << QString("bridge http_request start method=%1 url=%2 timeout_ms=%3 has_api_key=%4")
        .arg(method, url)
        .arg(timeout_ms)
        .arg(api_key.isEmpty() ? "no" : "yes");
    const QString script = QString(R"JS(
const fs = await import('node:fs');
const [requestUrl, requestMethod, requestBodyFile, apiKey] = process.argv.slice(1);
const target = new URL(requestUrl);
if (target.hostname === 'localhost') {
  target.hostname = '127.0.0.1';
}

const requestTimeoutMs = %1;
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(new Error(`request timeout after ${requestTimeoutMs}ms`)), requestTimeoutMs);
const options = { method: requestMethod, headers: {}, signal: controller.signal };

if (apiKey) {
  options.headers['Authorization'] = `Bearer ${apiKey}`;
}

if (requestBodyFile) {
  options.body = fs.readFileSync(requestBodyFile, 'utf8');
  options.headers['Content-Type'] = 'application/json';
}

try {
  const response = await fetch(target, options);
  clearTimeout(timeout);
  const buffer = await response.arrayBuffer();
  const decoder = new TextDecoder('utf-8', { fatal: false, ignoreBOM: true });
  const text = decoder.decode(buffer).replace(/\uFFFD/g, '?');
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
         << body_file
         << api_key;
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
        local_model_name_ = resolve_local_ollama_model_dir(find_repo_root(), checkpoint_models_root_).isEmpty()
            ? QString::fromLatin1(kDefaultOllamaModel)
            : QString::fromLatin1(kDefaultLocalOllamaModel);
        emit localModelConfigChanged();
    }

    // Implement logic to check if the target Ollama model exists
    emit log_message("info", "bridge", QString("Checking for Ollama model %1").arg(local_model_name_));
    const QString show_result = run_process(command, {"show", local_model_name_}, 10000);

    if (show_result.startsWith("runtime_exec_failed")) {
        emit log_message("info", "bridge", QString("Pulling Ollama model %1").arg(local_model_name_));
        const QString pull_result = run_process(command, {"pull", local_model_name_}, kOllamaPullTimeoutMs);
        if (pull_result.startsWith("runtime_")) {
            return pull_result;
        }
    } else {
        emit log_message("info", "bridge", QString("Ollama model %1 is already available").arg(local_model_name_));
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
    const bool started = QProcess::startDetached(preferred_bash_program(), {"http_server.sh"}, backend_dir);
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

QString NeurxBridge::run_local_model_agent(const QString& prompt, int max_steps) {
    if (!local_model_enabled_) {
        return "local_model_config_missing: disabled";
    }

    const QString repo_root = find_repo_root();
    const QString base_url = qEnvironmentVariable(
        "NEURX_REMOTE_BASE_URL", kDefaultCodeAgentRemoteBaseUrl).trimmed();
    const QString chat_path = sanitize_chat_path(qEnvironmentVariable(
        "NEURX_REMOTE_CHAT_PATH", kDefaultCodeAgentRemoteChatPath));
    const QString primary_model_name = remote_code_agent_model_name(
        qEnvironmentVariable("NEURX_REMOTE_MODEL").trimmed());
    if (base_url.isEmpty() || chat_path.isEmpty() || primary_model_name.isEmpty()) {
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

    const bool wants_streaming = url_looks_like_ollama(base_url) && chat_path == "/api/chat";
    if (!repo_root.isEmpty()) {
        qInfo().noquote() << QString("bridge local backend code_path handler=%1 gateway=%2 serve=%3")
            .arg(QDir(repo_root).filePath("app/service/http_handler.sh"))
            .arg(QDir(repo_root).filePath("app/service/gateway.sh"))
            .arg(QDir(repo_root).filePath("app/service/serve.s"));
    }

    auto run_request_for_model = [&](const QString& requested_model_name) -> QString {
        QJsonObject request_json;
        request_json.insert("model", requested_model_name);
        qInfo().noquote() << QString("bridge local model request url=%1 model=%2 path=%3 backend=%4")
            .arg(url, requested_model_name, chat_path, QStringLiteral("openai"));
        request_json.insert("prompt", prompt);
        QJsonObject user_message;
        user_message.insert("role", "user");
        user_message.insert("content", prompt);
        QJsonArray messages;
        messages.append(user_message);
        request_json.insert("messages", messages);
        request_json.insert("max_tokens", max_steps);

        if (wants_streaming) {
            request_json.insert("stream", true);
        }

        const QString payload = QString::fromUtf8(QJsonDocument(request_json).toJson(QJsonDocument::Compact));
        QTemporaryFile tmp;
        tmp.setAutoRemove(true);
        if (!tmp.open()) {
            return QStringLiteral("runtime_exec_failed: could not create temp file");
        }
        tmp.write(payload.toUtf8());
        tmp.flush();
        tmp.close();

        QString raw;
        QString streamed_content;
        QJsonObject streamed_object;
        if (wants_streaming) {
            qInfo().noquote() << QString("bridge http_request stream method=POST url=%1 timeout_ms=%2")
                .arg(url)
                .arg(120000);
            const QString stream_error = run_streaming_chat_request(
                this, url, tmp.fileName(), 120000, &streamed_content, &streamed_object);
            if (!stream_error.isEmpty()) {
                qWarning().noquote() << QString("bridge http_request failed method=POST url=%1 result=%2")
                    .arg(url, stream_error.left(200));
                return stream_error;
            } else {
                QJsonObject normalized_stream = streamed_object;
                if (!streamed_content.isEmpty()) {
                    QJsonObject message = normalized_stream.value("message").toObject();
                    message.insert("content", streamed_content);
                    normalized_stream.insert("message", message);
                    normalized_stream.insert("content", streamed_content);
                }
                if (!normalized_stream.contains("backend")) {
                    normalized_stream.insert("backend", QStringLiteral("openai"));
                }
                if (!normalized_stream.contains("model")) {
                    normalized_stream.insert("model", requested_model_name);
                }
                if (!normalized_stream.contains("steps")) {
                    normalized_stream.insert("steps", max_steps);
                }
                raw = QString::fromUtf8(QJsonDocument(normalized_stream).toJson(QJsonDocument::Compact));
                qInfo().noquote() << QString("bridge http_request done method=POST url=%1 bytes=%2 stream=1 content_len=%3 content_preview=%4")
                    .arg(url)
                    .arg(raw.size())
                    .arg(streamed_content.size())
                    .arg(streamed_content.left(120));
            }
        } else {
            raw = run_http_request("POST", url, tmp.fileName(), 120000);
        }
        if (raw.startsWith("runtime_")) {
            qWarning().noquote() << QString("bridge http_request failed method=POST url=%1 result=%2")
                .arg(url, raw.left(200));
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
        
        // Clean invalid UTF-8 characters from response
        content = clean_utf8_response(content);

        QString backend = response.value("backend").toString();
        if (backend.isEmpty()) {
            backend = response.value("backend_name").toString();
        }
        if (backend.isEmpty()) {
            backend = QStringLiteral("openai");
        }

        QString model = response.value("model").toString();
        if (model.isEmpty()) {
            model = response.value("model_name").toString();
        }
        if (model.isEmpty()) {
            model = requested_model_name;
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
    };

    Q_UNUSED(repo_root);
    return run_request_for_model(primary_model_name);
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

bool NeurxBridge::has_pending_code_agent_changes() const {
    return !code_agent_pending_changes_.isEmpty();
}

QVariantList NeurxBridge::pending_code_agent_changes() const {
    return code_agent_pending_changes_;
}

QString NeurxBridge::pending_code_agent_changes_summary() const {
    if (code_agent_pending_changes_.isEmpty()) {
        return QStringLiteral("no_pending_code_agent_changes");
    }

    QStringList lines;
    lines << QStringLiteral("pending_change_count=") + QString::number(code_agent_pending_changes_.size());
    for (int i = 0; i < code_agent_pending_changes_.size(); ++i) {
        const QVariantMap change = code_agent_pending_changes_.at(i).toMap();
        QString line = QStringLiteral("pending_change[%1].action=").arg(i) + change.value(QStringLiteral("action")).toString();
        const QString path = change.value(QStringLiteral("path")).toString().trimmed();
        if (!path.isEmpty()) {
            line += QStringLiteral(" path=") + path;
        }
        const QString summary = change.value(QStringLiteral("summary")).toString().trimmed();
        if (!summary.isEmpty()) {
            line += QStringLiteral(" summary=") + summary;
        }
        const QString preview = change.value(QStringLiteral("preview")).toString().trimmed();
        if (!preview.isEmpty()) {
            line += QStringLiteral(" preview=") + clip_text(preview, 180).replace(QChar('\n'), QChar(' '));
        }
        lines << line;
    }
    return lines.join(QChar('\n'));
}

QString NeurxBridge::apply_pending_code_agent_changes() {
    if (code_agent_pending_changes_.isEmpty()) {
        return QStringLiteral("no_pending_code_agent_changes");
    }

    QStringList edited_paths;
    QStringList applied_summaries;
    const auto emit_explorer_change = [this](const QString& absolute_path, const QString& action) {
        emit explorerChanged(QDir::cleanPath(absolute_path), action);
    };

    for (const QVariant& item : std::as_const(code_agent_pending_changes_)) {
        const QVariantMap change = item.toMap();
        const QString action = change.value(QStringLiteral("action")).toString();
        const QString raw_path = change.value(QStringLiteral("path")).toString();
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(find_repo_root(), raw_path, &ok);
        if (!ok) {
            applied_summaries << QStringLiteral("tool_error: apply pending change outside workspace");
            continue;
        }

        if (action == QStringLiteral("write_file") || action == QStringLiteral("create_file")) {
            QDir().mkpath(QFileInfo(absolute_path).absolutePath());
            QFile file(absolute_path);
            if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
                applied_summaries << QStringLiteral("tool_error: pending %1 failed").arg(action);
                emit log_message("error", "fs",
                    QString("file_op action=%1 mode=pending-apply result=failed target=%2 handler=%3")
                        .arg(action, absolute_path, bridge_source_file_path()));
                continue;
            }
            const QString content = normalize_newlines(change.value(QStringLiteral("content")).toString());
            const QByteArray bytes = content.toUtf8();
            file.write(bytes);
            file.close();
            edited_paths.append(repo_relative_path(find_repo_root(), absolute_path));
            applied_summaries << QStringLiteral("applied %1 ").arg(action)
                + repo_relative_path(find_repo_root(), absolute_path);
            emit_explorer_change(absolute_path, action == QStringLiteral("create_file")
                ? QStringLiteral("create")
                : QStringLiteral("update"));
            emit log_message("info", "fs",
                QString("file_op action=%1 mode=pending-apply result=ok target=%2 handler=%3")
                    .arg(action, absolute_path, bridge_source_file_path()));
            continue;
        }

        if (action == QStringLiteral("delete_path")) {
            const QVariant recursive_value = change.value(QStringLiteral("recursive"));
            const bool recursive = recursive_value.isValid() ? recursive_value.toBool() : true;
            const QFileInfo info(absolute_path);
            if (!info.exists()) {
                applied_summaries << QStringLiteral("delete_path already absent ") + repo_relative_path(find_repo_root(), absolute_path);
                continue;
            }
            bool removed = false;
            if (info.isDir()) {
                if (recursive) {
                    QDir dir(absolute_path);
                    removed = dir.removeRecursively();
                } else {
                    const QFileInfo dir_info(absolute_path);
                    QDir parent_dir = dir_info.dir();
                    removed = parent_dir.rmdir(dir_info.fileName());
                }
            } else {
                QFile file_to_remove(absolute_path);
                removed = file_to_remove.remove();
            }
            if (!removed) {
                applied_summaries << QStringLiteral("tool_error: pending delete_path failed");
                emit log_message("error", "fs",
                    QString("file_op action=delete_path mode=pending-apply result=failed target=%1 handler=%2")
                        .arg(absolute_path, bridge_source_file_path()));
                continue;
            }
            edited_paths.append(repo_relative_path(find_repo_root(), absolute_path));
            applied_summaries << QStringLiteral("applied delete_path ") + repo_relative_path(find_repo_root(), absolute_path);
            emit_explorer_change(absolute_path, QStringLiteral("delete"));
            emit log_message("info", "fs",
                QString("file_op action=delete_path mode=pending-apply result=ok target=%1 handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            continue;
        }

        QFile file(absolute_path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            applied_summaries << QStringLiteral("tool_error: pending change failed to read file");
            continue;
        }
        QString content = normalize_newlines(QString::fromUtf8(file.readAll()));
        file.close();

        if (action == QStringLiteral("apply_patch")) {
            const QString old_text = normalize_newlines(change.value(QStringLiteral("old_text")).toString());
            const QString new_text = normalize_newlines(change.value(QStringLiteral("new_text")).toString());
            const bool replace_all = change.value(QStringLiteral("replace_all")).toBool();
            if (old_text.isEmpty()) {
                applied_summaries << QStringLiteral("tool_error: pending apply_patch old_text empty");
                continue;
            }
            if (content.indexOf(old_text) < 0) {
                applied_summaries << QStringLiteral("tool_error: pending apply_patch old_text not found");
                continue;
            }
            if (replace_all) {
                content.replace(old_text, new_text, Qt::CaseSensitive);
            } else {
                const int first_match = content.indexOf(old_text);
                const int end = first_match + old_text.size();
                content = content.left(first_match) + new_text + content.mid(end);
            }
        } else if (action == QStringLiteral("replace_range")) {
            const int start_line = change.value(QStringLiteral("start_line")).toInt();
            const int end_line = change.value(QStringLiteral("end_line")).toInt();
            if (start_line < 1 || end_line < start_line - 1) {
                applied_summaries << QStringLiteral("tool_error: pending replace_range invalid span");
                continue;
            }
            QStringList lines = content.split(QChar('\n'));
            const int line_count = lines.size();
            const int start_index = qBound(0, start_line - 1, line_count);
            const int end_index = qBound(0, end_line, line_count);
            QStringList replacement_lines = normalize_newlines(change.value(QStringLiteral("new_text")).toString()).split(QChar('\n'));
            QStringList merged;
            for (int i = 0; i < start_index; ++i) {
                merged.append(lines.at(i));
            }
            for (const QString& line : replacement_lines) {
                merged.append(line);
            }
            for (int i = end_index; i < line_count; ++i) {
                merged.append(lines.at(i));
            }
            content = merged.join(QChar('\n'));
        } else {
            applied_summaries << QStringLiteral("tool_error: unsupported pending action ") + action;
            continue;
        }

        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
            applied_summaries << QStringLiteral("tool_error: pending write failed");
            emit log_message("error", "fs",
                QString("file_op action=%1 mode=pending-apply result=failed target=%2 handler=%3")
                    .arg(action, absolute_path, bridge_source_file_path()));
            continue;
        }
        const QByteArray bytes = content.toUtf8();
        file.write(bytes);
        file.close();

        const QString repo_path = repo_relative_path(find_repo_root(), absolute_path);
        edited_paths.append(repo_path);
        applied_summaries << QStringLiteral("applied ") + action + QStringLiteral(" ") + repo_path;
        emit_explorer_change(absolute_path, QStringLiteral("update"));
        emit log_message("info", "fs",
            QString("file_op action=%1 mode=pending-apply result=ok target=%2 handler=%3")
                .arg(action, absolute_path, bridge_source_file_path()));
    }

    code_agent_pending_changes_.clear();

    QString result = QStringLiteral("applied_pending_change_count=") + QString::number(edited_paths.size());
    for (const QString& path : std::as_const(edited_paths)) {
        result += QStringLiteral("\nedited_path=") + path;
    }
    if (!applied_summaries.isEmpty()) {
        result += QStringLiteral("\nlast_observation=") + clip_text(applied_summaries.join(QStringLiteral("; ")), 300);
    }
    return result;
}

void NeurxBridge::clear_pending_code_agent_changes() {
    code_agent_pending_changes_.clear();
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
    return text.contains("S backend placeholder response")
        || text.contains("S backend is alive and responding")
        || text.contains("serve.s fallback placeholder");
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
        "write", "create", "mkdir", "directory", "folder", "build", "generate", "example", "hello world",
        "write cn", "create cn", "directory cn", "folder cn", "implement cn", "fix cn", "code cn", "example cn", "build cn", "program cn"
    })) {
        return "code";
    }
    if (prompt_mentions_code_language(text)) {
        return "code";
    }
    if (contains_any_keyword(text, {
        "review", "audit", "check", "test",
        "review cn", "audit cn", "check cn", "test cn"
    })) {
        return "review";
    }
    if (contains_any_keyword(text, {
        "search", "lookup", "find",
        "search cn", "lookup cn", "find cn"
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

QString NeurxBridge::ensure_native_s_runtime_compiled(const QString& repo_root, const QString& s_binary) {
    const QString normalized_root = QDir::cleanPath(repo_root.trimmed());
    const QString normalized_binary = QDir::cleanPath(s_binary.trimmed());
    const bool force_recompile = qEnvironmentVariableIntValue("NEURX_S_ALWAYS_COMPILE") == 1;
    if (normalized_root.isEmpty() || normalized_binary.isEmpty()) {
        return QStringLiteral("runtime_exec_failed: missing S runtime compile inputs");
    }

    if (!force_recompile
        && native_s_runtime_ready_repo_root_ == normalized_root
        && native_s_runtime_ready_binary_ == normalized_binary) {
        return QString();
    }

    const QString compile_script = QDir(normalized_root).filePath("workflows/agent/common/compile_runtime.sh");
    if (!QFileInfo::exists(compile_script) || !QFileInfo(compile_script).isFile()) {
        return QStringLiteral("runtime_exec_failed: compile_runtime.sh not found");
    }

    emit log_message("info", "agent",
        QString("native S compile start binary=%1").arg(QFileInfo(normalized_binary).fileName()));
    const QString compile_result = run_process(
        preferred_bash_program(),
        QStringList() << compile_script << QStringLiteral("--s-bin") << normalized_binary,
        10 * 60 * 1000,
        normalized_root);
    if (compile_result.startsWith(QStringLiteral("runtime_"))) {
        return compile_result;
    }

    native_s_runtime_ready_repo_root_ = normalized_root;
    native_s_runtime_ready_binary_ = normalized_binary;
    emit log_message("info", "agent", QString("native S compile done len=%1").arg(compile_result.size()));
    return QString();
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

QString NeurxBridge::read_docx_text_file(const QString& path) const {
    const QString next = path.trimmed();
    if (next.isEmpty()) {
        return QString();
    }

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    Q_UNUSED(next);
    return QStringLiteral("read_docx_text_file_unavailable_on_mobile");
#else
    const QByteArray document_xml = read_docx_document_xml(next);
    if (document_xml.isEmpty()) {
        return QString("read_docx_text_file_failed: %1").arg(next);
    }

    const QString extracted = docx_plain_text_from_xml(document_xml);
    if (extracted.isEmpty()) {
        return QString("read_docx_text_file_failed: %1").arg(next);
    }

    return extracted;
#endif
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
    // Keep the explorer at the virtual "computer" root so mounted disks are
    // visible by default. The QML layer expands "/" automatically when it is
    // the only available volume.
    return QString();
}

QVariantMap NeurxBridge::load_ui_session() const {
    QSettings settings;
    QVariantMap session;
    session.insert("explorerCurrentPath", settings.value("app_shell/explorerCurrentPath", QString()).toString());
    session.insert("selectedFilePath", settings.value("app_shell/selectedFilePath", QString()).toString());
    session.insert("explorerPaneWidth", settings.value("app_shell/explorerPaneWidth", 280).toInt());
    session.insert("agentPaneWidth", settings.value("app_shell/agentPaneWidth", 540).toInt());
    session.insert("uiZoom", settings.value("app_shell/uiZoom", 1.0).toDouble());
    {
        const QByteArray tabsJson = settings.value("app_shell/editorTabs", QByteArray()).toByteArray();
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(tabsJson, &err);
        session.insert("editorTabs", (err.error == QJsonParseError::NoError && doc.isArray())
            ? doc.array().toVariantList() : QVariantList());
    }
    session.insert("activeEditorTabIndex", settings.value("app_shell/activeEditorTabIndex", -1).toInt());
    return session;
}

void NeurxBridge::save_ui_session(const QString& explorerPath,
                                  const QString& selectedFilePath,
                                  int explorerPaneWidth,
                                  int agentPaneWidth,
                                  double uiZoom,
                                  const QVariantList& editorTabs,
                                  int activeEditorTabIndex) {
    QSettings settings;
    settings.setValue("app_shell/explorerCurrentPath", explorerPath.trimmed());
    settings.setValue("app_shell/selectedFilePath", selectedFilePath.trimmed());
    settings.setValue("app_shell/explorerPaneWidth", explorerPaneWidth);
    settings.setValue("app_shell/agentPaneWidth", agentPaneWidth);
    settings.setValue("app_shell/uiZoom", uiZoom);
    {
        const QJsonArray arr = QJsonArray::fromVariantList(editorTabs);
        settings.setValue("app_shell/editorTabs", QJsonDocument(arr).toJson(QJsonDocument::Compact));
    }
    settings.setValue("app_shell/activeEditorTabIndex", activeEditorTabIndex);
}

QVariantMap NeurxBridge::load_login_session() const {
    QSettings settings;
    const QString savedPhone = settings.value("app_shell_login/phone", QString()).toString().trimmed();
    const QString savedToken = settings.value("app_shell_login/rememberToken", QString()).toString().trimmed();
    if (!savedPhone.isEmpty()) {
        const QVariantMap database_session = load_login_session_from_database(savedPhone, savedToken);
        if (!database_session.isEmpty()) {
            settings.setValue("app_shell_login/loggedIn", true);
            settings.setValue("app_shell_login/phone", database_session.value("phone").toString());
            if (database_session.contains("rememberToken")) {
                settings.setValue("app_shell_login/rememberToken", database_session.value("rememberToken").toString());
            }
            return database_session;
        }
    }

    QVariantMap session;
    session.insert("loggedIn", settings.value("app_shell_login/loggedIn", false).toBool());
    session.insert("phone", settings.value("app_shell_login/phone", QString()).toString());
    return session;
}

void NeurxBridge::save_login_session(bool loggedIn,
                                     const QString& phone) {
    QSettings settings;
    const QString normalized_phone = phone.trimmed();
    settings.setValue("app_shell_login/loggedIn", loggedIn);
    settings.setValue("app_shell_login/phone", normalized_phone);

    if (!loggedIn || normalized_phone.isEmpty()) {
        settings.remove("app_shell_login/rememberToken");
        settings.remove("app_shell_login/rememberExpires");
        return;
    }

    const QString remember_token = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QDateTime remember_expires = QDateTime::currentDateTime().addDays(kLoginRememberDays);
    settings.setValue("app_shell_login/rememberToken", remember_token);
    settings.setValue("app_shell_login/rememberExpires", remember_expires);

    const bool persisted = persist_login_session_to_database(normalized_phone,
                                                             remember_token,
                                                             remember_expires);
    if (!persisted) {
        qWarning() << "Failed to persist login session to MySQL for phone" << normalized_phone;
    }
}

QString NeurxBridge::login_database_connection_name() const {
    return QStringLiteral("neurx_login_mysql");
}

QString NeurxBridge::login_database_host() const {
    return env_or_default("NEURX_MYSQL_HOST", kDefaultMysqlHost);
}

int NeurxBridge::login_database_port() const {
    const int port = qEnvironmentVariableIntValue("NEURX_MYSQL_PORT");
    return port > 0 ? port : kDefaultMysqlPort;
}

QString NeurxBridge::login_database_name() const {
    return env_or_default("NEURX_MYSQL_DATABASE", kDefaultMysqlDatabase);
}

QString NeurxBridge::login_database_user() const {
    return env_or_default("NEURX_MYSQL_USER", kDefaultMysqlUser);
}

QString NeurxBridge::login_database_password() const {
    return env_or_default("NEURX_MYSQL_PASSWORD", kDefaultMysqlPassword);
}

bool NeurxBridge::persist_login_session_to_database(const QString& phone,
                                                    const QString& rememberToken,
                                                    const QDateTime& rememberExpires) const {
    const QString normalized_phone = phone.trimmed();
    Q_UNUSED(rememberToken);
    Q_UNUSED(rememberExpires);
    if (normalized_phone.isEmpty()) {
        return false;
    }

    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QMYSQL"))) {
        emit const_cast<NeurxBridge*>(this)->log_message(
            "warning",
            "db",
            QString("MySQL driver unavailable; skipping login session persist handler=%1")
                .arg(bridge_source_file_path()));
        return false;
    }

    const QString connection_name = login_database_connection_name();
    if (QSqlDatabase::contains(connection_name)) {
        {
            QSqlDatabase existing = QSqlDatabase::database(connection_name);
            if (existing.isOpen()) {
                existing.close();
            }
        }
        QSqlDatabase::removeDatabase(connection_name);
    }

    bool ok = false;
    QString error_text;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QMYSQL"), connection_name);
        db.setHostName(login_database_host());
        db.setPort(login_database_port());
        db.setDatabaseName(login_database_name());
        db.setUserName(login_database_user());
        db.setPassword(login_database_password());

        if (db.open()) {
            QSqlQuery query(db);
            query.prepare(R"SQL(
                INSERT INTO `user`
                    (`phone`)
                VALUES
                    (?)
                ON DUPLICATE KEY UPDATE
                    `phone` = VALUES(`phone`)
            )SQL");
            query.addBindValue(normalized_phone);
            ok = query.exec();
            if (!ok) {
                error_text = query.lastError().text();
            }
        } else {
            error_text = db.lastError().text();
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(connection_name);

    if (!ok && !error_text.isEmpty()) {
        qWarning() << "MySQL login session persist failed:" << error_text;
    }
    return ok;
}

QVariantMap NeurxBridge::load_login_session_from_database(const QString& phone,
                                                          const QString& rememberToken) const {
    const QString normalized_phone = phone.trimmed();
    Q_UNUSED(rememberToken);
    if (normalized_phone.isEmpty()) {
        return {};
    }

    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QMYSQL"))) {
        emit const_cast<NeurxBridge*>(this)->log_message(
            "warning",
            "db",
            QString("MySQL driver unavailable; skipping login session load handler=%1")
                .arg(bridge_source_file_path()));
        return {};
    }

    const QString connection_name = login_database_connection_name();
    if (QSqlDatabase::contains(connection_name)) {
        {
            QSqlDatabase existing = QSqlDatabase::database(connection_name);
            if (existing.isOpen()) {
                existing.close();
            }
        }
        QSqlDatabase::removeDatabase(connection_name);
    }

    QVariantMap session;
    QString error_text;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QMYSQL"), connection_name);
        db.setHostName(login_database_host());
        db.setPort(login_database_port());
        db.setDatabaseName(login_database_name());
        db.setUserName(login_database_user());
        db.setPassword(login_database_password());

        if (db.open()) {
            QSqlQuery query(db);
            query.prepare(R"SQL(
                SELECT `phone`
                FROM `user`
                WHERE `phone` = ?
                LIMIT 1
            )SQL");
            query.addBindValue(normalized_phone);

            if (query.exec() && query.next()) {
                session.insert("loggedIn", true);
                session.insert("phone", query.value(0).toString());
                return session;
            }

            error_text = query.lastError().text();
        } else {
            error_text = db.lastError().text();
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(connection_name);

    if (!error_text.isEmpty()) {
        qWarning() << "MySQL login session load failed:" << error_text;
    }
    return {};
}

void NeurxBridge::copy_to_clipboard(const QString& text) {
    if (QClipboard* clipboard = QGuiApplication::clipboard()) {
        clipboard->setText(text);
    }
}

QString NeurxBridge::delete_path(const QString& path, bool recursive) {
    const QString trimmed = QDir::cleanPath(path.trimmed());
    if (trimmed.isEmpty()) {
        return QStringLiteral("delete_path_error: empty path");
    }
    const QFileInfo info(trimmed);
    if (!info.exists()) {
        emit explorerChanged(trimmed, QStringLiteral("delete"));
        emit log_message("info", "fs",
            QString("file_op action=delete_path mode=api result=already_absent target=%1 handler=%2")
                .arg(trimmed, bridge_source_file_path()));
        return QStringLiteral("already_absent");
    }
    bool removed = false;
    if (info.isDir()) {
        if (recursive) {
            QDir dir(trimmed);
            removed = dir.removeRecursively();
        } else {
            QDir parent = info.dir();
            removed = parent.rmdir(info.fileName());
        }
    } else {
        QFile file(trimmed);
        removed = file.remove();
    }
    if (!removed) {
        return QStringLiteral("delete_path_error: failed to remove ") + trimmed;
    }
    qInfo().noquote() << QString("bridge delete_path path=%1 recursive=%2")
        .arg(trimmed)
        .arg(recursive ? "true" : "false");
    emit explorerChanged(trimmed, QStringLiteral("delete"));
    emit log_message(removed ? "info" : "error", "fs",
        QString("file_op action=delete_path mode=api result=%1 target=%2 handler=%3")
            .arg(removed ? QStringLiteral("ok") : QStringLiteral("failed"),
                 trimmed,
                 bridge_source_file_path()));
    return QStringLiteral("deleted");
}

QString NeurxBridge::run_code_assistant_request(const QString& prompt, const QString& filePath) {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        return "repo_not_found";
    }
    QString runner_plan;
    QString runner_file_context;
    QString runner_summary;
    QStringList runner_action_summaries;
    QStringList runner_action_result_summaries;
    QJsonArray runner_action_objects;
    const QString route = agent_route_for_prompt(prompt, filePath);
    const QString full_auto_env = qEnvironmentVariable("NEURX_CODE_AGENT_FULL_AUTO", QStringLiteral("1")).trimmed().toLower();
    const bool auto_apply_pending_changes = full_auto_env == QStringLiteral("1")
        || full_auto_env == QStringLiteral("true")
        || full_auto_env == QStringLiteral("yes");
    emit log_message("info", "agent", QString("code-assistant start route=%1 prompt_len=%2 file=%3")
        .arg(route)
        .arg(prompt.size())
        .arg(filePath.trimmed().isEmpty() ? QStringLiteral("-") : QFileInfo(filePath.trimmed()).fileName()));

    const auto create_workspace_file_direct = [&](const QString& raw_path, const QString& content) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok || absolute_path.isEmpty()) {
            emit log_message("error", "fs",
                QString("file_op action=create_file mode=agent-direct result=failed target=%1 handler=%2")
                    .arg(raw_path.trimmed(), bridge_source_file_path()));
            return QStringLiteral("create_file_error: path outside workspace");
        }
        const QFileInfo info(absolute_path);
        if (info.exists() && info.isDir()) {
            emit log_message("error", "fs",
                QString("file_op action=create_file mode=agent-direct result=failed target=%1 reason=path_is_directory handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("create_file_error: path already exists as directory");
        }
        if (info.exists() && info.isFile()) {
            emit log_message("error", "fs",
                QString("file_op action=create_file mode=agent-direct result=failed target=%1 reason=file_exists handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("create_file_error: file already exists");
        }
        if (!QDir().mkpath(QFileInfo(absolute_path).absolutePath())) {
            emit log_message("error", "fs",
                QString("file_op action=create_file mode=agent-direct result=failed target=%1 reason=mkpath_failed handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("create_file_error: failed to create parent directory");
        }
        QFile file(absolute_path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
            emit log_message("error", "fs",
                QString("file_op action=create_file mode=agent-direct result=failed target=%1 reason=open_failed handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("create_file_error: failed to open file for writing");
        }
        const QByteArray bytes = normalize_newlines(content).toUtf8();
        if (file.write(bytes) < 0) {
            emit log_message("error", "fs",
                QString("file_op action=create_file mode=agent-direct result=failed target=%1 reason=write_failed handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("create_file_error: failed to write file");
        }
        file.close();
        emit explorerChanged(absolute_path, QStringLiteral("create"));
        emit log_message("info", "fs",
            QString("file_op action=create_file mode=agent-direct result=ok target=%1 handler=%2")
                .arg(absolute_path, bridge_source_file_path()));
        return QStringLiteral("Created file: %1").arg(repo_relative_path(root, absolute_path));
    };

    const auto delete_workspace_path_direct = [&](const QString& raw_path) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok || absolute_path.isEmpty()) {
            emit log_message("error", "fs",
                QString("file_op action=delete_path mode=agent-direct result=failed target=%1 handler=%2")
                    .arg(raw_path.trimmed(), bridge_source_file_path()));
            return QStringLiteral("delete_path_error: path outside workspace");
        }
        const QFileInfo info(absolute_path);
        if (!info.exists()) {
            emit log_message("info", "fs",
                QString("file_op action=delete_path mode=agent-direct result=already_absent target=%1 handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("Path already absent: %1").arg(repo_relative_path(root, absolute_path));
        }
        bool removed = false;
        if (info.isDir()) {
            QDir dir(absolute_path);
            removed = dir.removeRecursively();
        } else {
            QFile file(absolute_path);
            removed = file.remove();
        }
        if (!removed) {
            emit log_message("error", "fs",
                QString("file_op action=delete_path mode=agent-direct result=failed target=%1 handler=%2")
                    .arg(absolute_path, bridge_source_file_path()));
            return QStringLiteral("delete_path_error: failed to remove %1")
                .arg(repo_relative_path(root, absolute_path));
        }
        emit explorerChanged(absolute_path, QStringLiteral("delete"));
        emit log_message("info", "fs",
            QString("file_op action=delete_path mode=agent-direct result=ok target=%1 handler=%2")
                .arg(absolute_path, bridge_source_file_path()));
        return QStringLiteral("Deleted path: %1").arg(repo_relative_path(root, absolute_path));
    };

    const auto rename_workspace_path_direct = [&](const QString& raw_source_path,
                                                  const QString& raw_target_path,
                                                  const QString& mode) -> QString {
        bool source_ok = false;
        const QString absolute_source_path = resolve_workspace_path(root, raw_source_path, &source_ok);
        bool target_ok = false;
        const QString absolute_target_path = resolve_workspace_path(root, raw_target_path, &target_ok);
        if (!source_ok || absolute_source_path.isEmpty() || !target_ok || absolute_target_path.isEmpty()) {
            emit log_message("error", "fs",
                QString("file_op action=rename_path mode=%1 result=failed source=%2 target=%3 reason=path_outside_workspace handler=%4")
                    .arg(mode, raw_source_path.trimmed(), raw_target_path.trimmed(), bridge_source_file_path()));
            return QStringLiteral("rename_path_error: path outside workspace");
        }
        const QFileInfo source_info(absolute_source_path);
        if (!source_info.exists()) {
            emit log_message("error", "fs",
                QString("file_op action=rename_path mode=%1 result=failed source=%2 target=%3 reason=source_missing handler=%4")
                    .arg(mode, absolute_source_path, absolute_target_path, bridge_source_file_path()));
            return QStringLiteral("rename_path_error: source path not found");
        }
        const QFileInfo target_info(absolute_target_path);
        if (target_info.exists()) {
            emit log_message("error", "fs",
                QString("file_op action=rename_path mode=%1 result=failed source=%2 target=%3 reason=target_exists handler=%4")
                    .arg(mode, absolute_source_path, absolute_target_path, bridge_source_file_path()));
            return QStringLiteral("rename_path_error: target path already exists");
        }
        if (!QDir().mkpath(QFileInfo(absolute_target_path).absolutePath())) {
            emit log_message("error", "fs",
                QString("file_op action=rename_path mode=%1 result=failed source=%2 target=%3 reason=mkpath_failed handler=%4")
                    .arg(mode, absolute_source_path, absolute_target_path, bridge_source_file_path()));
            return QStringLiteral("rename_path_error: failed to create target parent directory");
        }
        bool renamed = false;
        if (source_info.isDir()) {
            QDir parent_dir = source_info.dir();
            renamed = parent_dir.rename(source_info.fileName(), QFileInfo(absolute_target_path).fileName());
            if (renamed && source_info.dir().absolutePath() != QFileInfo(absolute_target_path).dir().absolutePath()) {
                // Fallback for cross-directory directory moves.
                QDir target_parent(QFileInfo(absolute_target_path).dir().absolutePath());
                renamed = target_parent.rename(absolute_source_path, absolute_target_path);
            }
        } else {
            QFile source_file(absolute_source_path);
            renamed = source_file.rename(absolute_target_path);
        }
        if (!renamed) {
            emit log_message("error", "fs",
                QString("file_op action=rename_path mode=%1 result=failed source=%2 target=%3 reason=rename_failed handler=%4")
                    .arg(mode, absolute_source_path, absolute_target_path, bridge_source_file_path()));
            return QStringLiteral("rename_path_error: failed to rename path");
        }
        emit explorerChanged(absolute_source_path, QStringLiteral("delete"));
        emit explorerChanged(absolute_target_path, QStringLiteral("create"));
        emit log_message("info", "fs",
            QString("file_op action=rename_path mode=%1 result=ok source=%2 target=%3 handler=%4")
                .arg(mode, absolute_source_path, absolute_target_path, bridge_source_file_path()));
        return QStringLiteral("Renamed path: %1 -> %2")
            .arg(repo_relative_path(root, absolute_source_path),
                 repo_relative_path(root, absolute_target_path));
    };

    if (prompt_requests_rename_operation(prompt)) {
        const QString rename_source = extract_rename_source_path(prompt, filePath);
        const QString rename_target = extract_rename_target_path(prompt, filePath, rename_source);
        if (!rename_source.isEmpty() && !rename_target.isEmpty()) {
            const QString rename_result = rename_workspace_path_direct(
                rename_source, rename_target, QStringLiteral("agent-direct"));
            emit log_message("info", "agent",
                QString("code-assistant direct-rename source=%1 target=%2 result=%3")
                    .arg(rename_source, rename_target, rename_result));
            return rename_result;
        }
    }

    if (prompt_requests_create_file_operation(prompt)) {
        const QString create_target = extract_create_target_path(prompt, filePath);
        if (!create_target.isEmpty()) {
            const QString create_content = extract_create_file_content(prompt, create_target);
            const QString create_result = create_workspace_file_direct(create_target, create_content);
            emit log_message("info", "agent",
                QString("code-assistant direct-create path=%1 result=%2")
                    .arg(create_target, create_result));
            return create_result;
        }
    }

    if (prompt_requests_delete_operation(prompt)) {
        const QString delete_target = extract_delete_target_path(prompt, filePath);
        if (!delete_target.isEmpty()) {
            const QString delete_result = delete_workspace_path_direct(delete_target);
            emit log_message("info", "agent",
                QString("code-assistant direct-delete path=%1 result=%2")
                    .arg(delete_target, delete_result));
            return delete_result;
        }
    }

    const QString runner_path = QDir(root).filePath("app/service/code_agent_runner.sh");
    if (QFileInfo::exists(runner_path) && QFileInfo(runner_path).isFile()) {
        const QString runner_result = run_process(
            preferred_bash_program(),
            QStringList() << runner_path
                          << "--prompt" << prompt
                          << "--file" << filePath.trimmed()
                          << "--repo" << root,
            5000,
            root);
        const CodeAgentRunnerEnvelope runner_envelope = parse_code_agent_runner_envelope(runner_result);
        if (runner_envelope.valid) {
                const QString runner_status = runner_envelope.status;
                const QString runner_mode = runner_envelope.mode;
                runner_summary = runner_envelope.summary;
                const QString runner_response = runner_envelope.response;
                runner_plan = runner_envelope.plan;
                runner_file_context = runner_envelope.file_context;
                runner_action_objects = runner_envelope.action_objects;
                runner_action_summaries = runner_envelope.action_summaries;
                runner_action_result_summaries = runner_envelope.action_result_summaries;
                if (runner_status == "completed" && !runner_response.trimmed().isEmpty()) {
                    emit log_message("info", "agent", QString("code-assistant done route=%1 source=runner mode=%2")
                        .arg(route, runner_mode));
                    QString decorated = runner_response.trimmed();
                    if (!runner_mode.trimmed().isEmpty()) {
                        decorated = QString("[mode] %1\n\n%2").arg(runner_mode.trimmed(), decorated);
                    }
                    if (!runner_summary.trimmed().isEmpty()) {
                        decorated = QString("[summary] %1\n\n%2").arg(runner_summary.trimmed(), decorated);
                    }
                    return decorated;
                }
                if (runner_status == "unhandled") {
                    emit log_message("info", "agent", QString("code-assistant runner delegated route=%1 mode=%2")
                        .arg(route, runner_mode));
                    QString delegated = QString("[mode] %1").arg(runner_mode.trimmed().isEmpty() ? QStringLiteral("planner") : runner_mode.trimmed());
                    if (!runner_summary.trimmed().isEmpty()) {
                        delegated += QStringLiteral("\n[summary] ") + runner_summary.trimmed();
                    }
                    if (!runner_plan.trimmed().isEmpty()) {
                        delegated = delegated + "\n[plan] " + runner_plan.trimmed();
                    }
                    if (!runner_action_summaries.isEmpty()) {
                        delegated += QStringLiteral("\n[actions]\n") + runner_action_summaries.join(QChar('\n'));
                    }
                    if (!runner_file_context.trimmed().isEmpty()) {
                        delegated = delegated + "\n[file_context]\n" + runner_file_context.trimmed();
                    }
                    emit log_message("info", "agent", delegated);
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

    const QString cleaned_user_prompt = sanitize_code_assistant_prompt(prompt);
    QString effective_prompt;
    if (!filePath.trimmed().isEmpty()) {
        effective_prompt = QString(
            "You are a code assistant working in the NeurX repository.\n"
            "Target file: %1\n"
            "User request: %2\n"
            "Provide a concrete code answer. If the user asks to write code, return the code first. "
            "Keep the reply concise and executable.")
            .arg(filePath.trimmed(), cleaned_user_prompt);
    } else {
        effective_prompt = QString(
            "You are a code assistant working in the NeurX repository.\n"
            "User request: %1\n"
            "If the user asks to write code, return a complete minimal program. "
            "Prefer directly answering with code when appropriate.")
            .arg(cleaned_user_prompt);
    }

    const QString local_code_base_url = qEnvironmentVariable("NEURX_CODE_AGENT_BASE_URL").trimmed().isEmpty()
        ? QString::fromLatin1(kDefaultCodeAgentLocalBaseUrl)
        : qEnvironmentVariable("NEURX_CODE_AGENT_BASE_URL").trimmed();
    const QString local_code_chat_path = preferred_chat_path_for(
        local_code_base_url,
        qEnvironmentVariable("NEURX_CODE_AGENT_CHAT_PATH", kDefaultCodeAgentLocalChatPath),
        QStringLiteral("openai"),
        !checkpoint_model_file_.isEmpty());
    QString local_code_model = preferred_model_name_for(
        local_code_base_url,
        qEnvironmentVariable("NEURX_CODE_AGENT_MODEL").trimmed().isEmpty()
            ? checkpoint_model_file_
            : qEnvironmentVariable("NEURX_CODE_AGENT_MODEL").trimmed(),
        QStringLiteral("openai"),
        !checkpoint_model_file_.isEmpty(),
        checkpoint_model_file_,
        resolve_local_ollama_model_dir(root, checkpoint_models_root_));

    const QString remote_code_base_url = qEnvironmentVariable(
        "NEURX_CODE_AGENT_REMOTE_BASE_URL", kDefaultCodeAgentRemoteBaseUrl).trimmed();
    const QString remote_code_chat_path = preferred_chat_path_for(
        remote_code_base_url,
        qEnvironmentVariable("NEURX_CODE_AGENT_REMOTE_CHAT_PATH", kDefaultCodeAgentRemoteChatPath),
        QStringLiteral("openai"),
        false);
    const QString remote_code_model = remote_code_agent_model_name(
        qEnvironmentVariable("NEURX_CODE_AGENT_REMOTE_MODEL").trimmed());
    if (local_code_model.trimmed().isEmpty()
        && !url_looks_like_s_backend(local_code_base_url)
        && !url_looks_like_ollama(local_code_base_url)) {
        local_code_model = remote_code_model;
    }
    const bool same_code_chat_target =
        join_url_and_path(local_code_base_url, local_code_chat_path)
            == join_url_and_path(remote_code_base_url, remote_code_chat_path)
        && local_code_model.trimmed() == remote_code_model.trimmed();

    auto extract_chat_content = [](const QString& response_text) -> QString {
        QJsonParseError parse_error;
        const QJsonDocument response_json = QJsonDocument::fromJson(response_text.toUtf8(), &parse_error);
        if (parse_error.error != QJsonParseError::NoError || !response_json.isObject()) {
            return QString();
        }

        const QJsonObject response = response_json.object();
        QString content = response.value("content").toString();
        if (content.isEmpty()) {
            content = response.value("completion").toString();
        }
        if (content.isEmpty() && response.value("choices").isArray()) {
            const QJsonArray choices = response.value("choices").toArray();
            if (!choices.isEmpty() && choices.first().isObject()) {
                const QJsonObject first = choices.first().toObject();
                if (first.value("message").isObject()) {
                    content = first.value("message").toObject().value("content").toString();
                }
                if (content.isEmpty()) {
                    content = first.value("text").toString();
                }
            }
        }
        return content.trimmed();
    };

    auto run_code_chat = [&](const QString& request_prompt,
                             const QString& base_url,
                             const QString& chat_path,
                             const QString& model_name,
                             bool allow_suggest_fallback,
                             const QString& source_label) -> QString {
        const QString chat_url = join_url_and_path(base_url, chat_path);
        const QString suggest_url = join_url_and_path(base_url, QStringLiteral("/neurx/api/agent/suggest"));
        const bool suggest_supported = allow_suggest_fallback && chat_url.contains("/neurx/api/chat");
        const bool wants_streaming = url_looks_like_ollama(base_url) && chat_path == "/api/chat";

        qInfo().noquote() << QString("bridge code assistant request url=%1 model=%2 path=%3 backend=openai source=%4")
            .arg(chat_url, model_name, chat_path, source_label);

        QJsonObject payload;
        if (chat_url.contains("/v1/chat/completions") || chat_url.contains("/api/chat")) {
            if (model_name.isEmpty()) {
                return "local_model_config_missing: model name could not be resolved";
            }
            payload.insert("model", model_name);
            payload.insert("max_tokens", 256);
            if (wants_streaming) {
                payload.insert("stream", true);
            }
            QJsonObject user_message;
            user_message.insert("role", "user");
            user_message.insert("content", request_prompt);
            QJsonArray messages;
            messages.append(user_message);
            payload.insert("messages", messages);
        } else {
            payload.insert("prompt", request_prompt);
            if (!filePath.trimmed().isEmpty()) {
                payload.insert("filePath", filePath.trimmed());
            }
            if (!model_name.isEmpty()) {
                payload.insert("model", model_name);
            }
            payload.insert("max_tokens", 256);
        }

        QTemporaryFile tmp;
        tmp.setAutoRemove(true);
        if (!tmp.open()) {
            return QString("runtime_exec_failed: could not create temp file");
        }
        tmp.write(QJsonDocument(payload).toJson(QJsonDocument::Compact));
        tmp.flush();
        tmp.close();

        QString chat_result;
        if (wants_streaming) {
            qInfo().noquote() << QString("bridge http_request stream method=POST url=%1 timeout_ms=%2")
                .arg(chat_url)
                .arg(120000);
            QString streamed_content;
            QJsonObject streamed_object;
            const QString stream_error = run_streaming_chat_request(
                this, chat_url, tmp.fileName(), 120000, &streamed_content, &streamed_object);
            if (!stream_error.isEmpty()) {
                return stream_error;
            }
            if (!streamed_content.trimmed().isEmpty()) {
                return streamed_content.trimmed();
            }
            chat_result = QString::fromUtf8(QJsonDocument(streamed_object).toJson(QJsonDocument::Compact));
            qInfo().noquote() << QString("bridge http_request done method=POST url=%1 bytes=%2 stream=1")
                .arg(chat_url)
                .arg(chat_result.size());
        } else {
            chat_result = run_http_request("POST", chat_url, tmp.fileName(), 120000);
        }

        const QString content = extract_chat_content(chat_result);
        if (!content.isEmpty()) {
            return content;
        }
        if (!suggest_supported || chat_result.startsWith("runtime_")) {
            return chat_result;
        }

        const QString suggest_result = run_http_request("POST", suggest_url, tmp.fileName(), 120000);
        if (suggest_result.startsWith("runtime_")) {
            return suggest_result;
        }

        QJsonParseError parse_error;
        const QJsonDocument response_json = QJsonDocument::fromJson(suggest_result.toUtf8(), &parse_error);
        if (parse_error.error != QJsonParseError::NoError || !response_json.isObject()) {
            return QString("code_assistant_parse_failed: %1").arg(suggest_result.left(200));
        }
        return response_json.object().value("suggestion").toString().trimmed();
    };

    auto run_code_chat_with_noise_retry = [&](const QString& request_prompt,
                                              const QString& base_url,
                                              const QString& chat_path,
                                              const QString& model_name,
                                              bool allow_suggest_fallback,
                                              const QString& source_label) -> QString {
        const QString first_result = run_code_chat(
            request_prompt,
            base_url,
            chat_path,
            model_name,
            allow_suggest_fallback,
            source_label);
        if (!response_requests_cleaner_prompt(first_result) && !response_looks_garbled(first_result)) {
            return first_result;
        }

        const QString retry_prompt = rewrite_code_assistant_prompt_for_noise_retry(prompt);
        emit log_message("warning", "agent",
            QString("code-assistant retry cleaned_prompt source=%1").arg(source_label));
        return run_code_chat(
            retry_prompt,
            base_url,
            chat_path,
            model_name,
            allow_suggest_fallback,
            source_label + QStringLiteral("-retry"));
    };

    const QString normalized_file_path = filePath.trimmed();
    code_agent_pending_changes_.clear();
    auto remember_recent_action = [&](const QString& summary) {
        const QString trimmed = summary.trimmed();
        if (trimmed.isEmpty()) {
            return;
        }
        code_agent_recent_actions_.append(trimmed);
        while (code_agent_recent_actions_.size() > kCodeAgentHistoryLimit) {
            code_agent_recent_actions_.removeFirst();
        }
    };
    auto remember_recent_file = [&](const QString& absolute_path, const QString& content_preview) {
        const QString cleaned = QDir::cleanPath(absolute_path.trimmed());
        if (cleaned.isEmpty()) {
            return;
        }
        code_agent_recent_files_.removeAll(cleaned);
        code_agent_recent_files_.append(cleaned);
        while (code_agent_recent_files_.size() > kCodeAgentFileCacheLimit) {
            const QString removed = code_agent_recent_files_.takeFirst();
            code_agent_file_cache_.remove(removed);
        }
        code_agent_file_cache_.insert(cleaned, clip_text(content_preview, 4000));
    };
    auto format_tool_response = [&](const QString& action,
                                    const QString& body,
                                    const QString& relative_path = QString()) -> QString {
        QString result = QStringLiteral("tool=") + action;
        if (!relative_path.trimmed().isEmpty()) {
            result += QStringLiteral("\npath=") + relative_path.trimmed();
        }
        result += QStringLiteral("\n") + clip_text(body.trimmed(), 12000);
        return result.trimmed();
    };
    auto read_workspace_file = [&](const QString& raw_path, int start_line, int line_count) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok || !QFileInfo::exists(absolute_path) || !QFileInfo(absolute_path).isFile()) {
            return QStringLiteral("tool_error: read_file path not found");
        }
        const QString text = read_file_window_text(absolute_path, start_line, line_count);
        if (text == QStringLiteral("read_file_failed")) {
            return QStringLiteral("tool_error: read_file failed");
        }
        remember_recent_file(absolute_path, text);
        return format_tool_response(
            QStringLiteral("read_file"),
            text,
            repo_relative_path(root, absolute_path));
    };
    auto list_workspace_files = [&](const QString& raw_dir, int limit) -> QString {
        bool ok = false;
        const QString absolute_dir = resolve_workspace_path(root, raw_dir.trimmed().isEmpty() ? QStringLiteral(".") : raw_dir, &ok);
        if (!ok || !QFileInfo::exists(absolute_dir) || !QFileInfo(absolute_dir).isDir()) {
            return QStringLiteral("tool_error: list_files directory not found");
        }
        QStringList entries;
        QDirIterator it(absolute_dir, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        const int capped_limit = qBound(1, limit, 200);
        while (it.hasNext() && entries.size() < capped_limit) {
            const QString next = QDir::cleanPath(it.next());
            if (next.contains(QStringLiteral("/.git/"), Qt::CaseInsensitive)
                || next.contains(QStringLiteral("/app/build/"), Qt::CaseInsensitive)
                || next.contains(QStringLiteral("/build/"), Qt::CaseInsensitive)) {
                continue;
            }
            entries.append(repo_relative_path(root, next));
        }
        return format_tool_response(QStringLiteral("list_files"), entries.join(QChar('\n')));
    };
    auto search_workspace_files = [&](const QString& query) -> QString {
        const QString script_path = QDir(root).filePath(QStringLiteral("app/service/tools/search.sh"));
        if (!QFileInfo::exists(script_path)) {
            return QStringLiteral("tool_error: search tool unavailable");
        }
        const QString output = run_process(
            preferred_bash_program(),
            QStringList() << script_path << query << root,
            10000,
            root);
        if (output.startsWith(QStringLiteral("runtime_"))) {
            return output;
        }
        return format_tool_response(QStringLiteral("search_files"), output);
    };
    auto create_workspace_directory = [&](const QString& raw_path) -> QString {
        static const QStringList kAllowedExternalRoots = {
            QStringLiteral("C:/Users"),
            QStringLiteral("C:/Users/"),
            QStringLiteral("/home"),
            QStringLiteral("/home/")
        };
        bool ok = false;
        const QString absolute_path = resolve_path_with_allowed_roots(root, raw_path, kAllowedExternalRoots, &ok);
        if (!ok || absolute_path.isEmpty()) {
            return QStringLiteral("tool_error: mkdir path not allowed");
        }
        const QFileInfo info(absolute_path);
        if (info.exists() && info.isFile()) {
            return QStringLiteral("tool_error: mkdir path already exists as file");
        }
        if (info.exists() && info.isDir()) {
            return format_tool_response(QStringLiteral("mkdir"), QStringLiteral("directory already exists"), absolute_path);
        }
        if (!QDir().mkpath(absolute_path)) {
            return QStringLiteral("tool_error: mkdir failed");
        }
        return format_tool_response(QStringLiteral("mkdir"), QStringLiteral("created directory"), absolute_path);
    };
    QStringList staged_paths;
    auto stage_pending_change = [&](const QVariantMap& change) {
        QVariantMap next = change;
        const QString raw_path = next.value(QStringLiteral("path")).toString();
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (ok) {
            next.insert(QStringLiteral("repo_path"), repo_relative_path(root, absolute_path));
            const QString preview = next.value(QStringLiteral("preview")).toString().trimmed();
            if (!preview.isEmpty()) {
                next.insert(QStringLiteral("preview"), clip_text(preview, 600));
            }
            code_agent_pending_changes_.append(next);
            const QString repo_path = next.value(QStringLiteral("repo_path")).toString();
            if (!repo_path.isEmpty() && !staged_paths.contains(repo_path)) {
                staged_paths.append(repo_path);
            }
        }
    };
    auto maybe_apply_pending_changes = [&](const QString& staged_result) -> QString {
        if (!auto_apply_pending_changes) {
            return staged_result;
        }
        const QString apply_result = apply_pending_code_agent_changes();
        if (apply_result.startsWith(QStringLiteral("tool_error:"))
            || apply_result.startsWith(QStringLiteral("runtime_"))) {
            return apply_result;
        }
        return QStringLiteral("%1\nauto_apply=%2")
            .arg(staged_result.trimmed(), clip_text(apply_result.trimmed(), 240));
    };
    auto apply_workspace_patch = [&](const QString& raw_path,
                                     const QString& old_text,
                                     const QString& new_text,
                                     bool replace_all) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok || !QFileInfo::exists(absolute_path) || !QFileInfo(absolute_path).isFile()) {
            return QStringLiteral("tool_error: apply_patch path not found");
        }

        if (old_text.isEmpty()) {
            return QStringLiteral("tool_error: apply_patch old_text is empty");
        }

        QFile file(absolute_path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return QStringLiteral("tool_error: apply_patch failed to read file");
        }
        const QString content = normalize_newlines(QString::fromUtf8(file.readAll()));
        file.close();

        const QString normalized_old_text = normalize_newlines(old_text);
        const QString normalized_new_text = normalize_newlines(new_text);
        if (content.indexOf(normalized_old_text) < 0) {
            return QStringLiteral("tool_error: apply_patch old_text not found");
        }
        if (!replace_all && content.count(normalized_old_text) > 1) {
            return QStringLiteral("tool_error: apply_patch old_text matched multiple locations");
        }

        QVariantMap change;
        change.insert(QStringLiteral("action"), QStringLiteral("apply_patch"));
        change.insert(QStringLiteral("path"), raw_path.trimmed());
        change.insert(QStringLiteral("old_text"), normalized_old_text);
        change.insert(QStringLiteral("new_text"), normalized_new_text);
        change.insert(QStringLiteral("replace_all"), replace_all);
        change.insert(QStringLiteral("summary"), replace_all
            ? QStringLiteral("replace all matches")
            : QStringLiteral("replace focused match"));
        change.insert(QStringLiteral("preview"), QStringLiteral("apply_patch\n--- old ---\n%1\n--- new ---\n%2")
            .arg(clip_text(normalized_old_text, 500), clip_text(normalized_new_text, 500)));
        stage_pending_change(change);
        const QString staged_result = format_tool_response(
            QStringLiteral("apply_patch"),
            QStringLiteral("staged patch preview"),
            repo_relative_path(root, absolute_path));
        return maybe_apply_pending_changes(staged_result);
    };
    auto replace_workspace_range = [&](const QString& raw_path,
                                       int start_line,
                                       int end_line,
                                       const QString& new_text) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok || !QFileInfo::exists(absolute_path) || !QFileInfo(absolute_path).isFile()) {
            return QStringLiteral("tool_error: replace_range path not found");
        }
        if (start_line < 1) {
            return QStringLiteral("tool_error: replace_range invalid start_line");
        }
        if (end_line < 0) {
            return QStringLiteral("tool_error: replace_range invalid end_line");
        }

        QFile file(absolute_path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return QStringLiteral("tool_error: replace_range failed to read file");
        }
        const QString content = normalize_newlines(QString::fromUtf8(file.readAll()));
        file.close();

        QStringList lines = content.split(QChar('\n'));
        const int line_count = lines.size();
        if (start_line > line_count + 1) {
            return QStringLiteral("tool_error: replace_range start_line beyond end of file");
        }
        if (end_line < start_line - 1) {
            return QStringLiteral("tool_error: replace_range invalid line span");
        }

        const int start_index = qBound(0, start_line - 1, line_count);
        const int end_index = qBound(0, end_line, line_count);
        QStringList replacement_lines = normalize_newlines(new_text).split(QChar('\n'));

        QVariantMap change;
        change.insert(QStringLiteral("action"), QStringLiteral("replace_range"));
        change.insert(QStringLiteral("path"), raw_path.trimmed());
        change.insert(QStringLiteral("start_line"), start_line);
        change.insert(QStringLiteral("end_line"), end_line);
        change.insert(QStringLiteral("new_text"), normalize_newlines(new_text));
        change.insert(QStringLiteral("summary"), QStringLiteral("replace lines %1-%2")
            .arg(start_line)
            .arg(qMax(start_line - 1, end_line)));
        change.insert(QStringLiteral("preview"), QStringLiteral("replace_range lines %1-%2\n--- new ---\n%3")
            .arg(start_line)
            .arg(qMax(start_line - 1, end_line))
            .arg(clip_text(normalize_newlines(new_text), 500)));
        stage_pending_change(change);
        const int reported_end_line = end_line >= start_line ? qMin(end_line, line_count) : start_line - 1;
        const QString action_label = end_line >= start_line
            ? QStringLiteral("replaced")
            : QStringLiteral("inserted");
        const QString staged_result = format_tool_response(
            QStringLiteral("replace_range"),
            QStringLiteral("staged %1 lines %2-%3").arg(action_label).arg(start_line).arg(reported_end_line),
            repo_relative_path(root, absolute_path));
        return maybe_apply_pending_changes(staged_result);
    };
    auto write_workspace_file = [&](const QString& raw_path, const QString& content) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok) {
            return QStringLiteral("tool_error: write_file path outside workspace");
        }
        QVariantMap change;
        change.insert(QStringLiteral("action"), QStringLiteral("write_file"));
        change.insert(QStringLiteral("path"), raw_path.trimmed());
        change.insert(QStringLiteral("content"), normalize_newlines(content));
        change.insert(QStringLiteral("summary"), QStringLiteral("replace file content"));
        change.insert(QStringLiteral("preview"), clip_text(normalize_newlines(content), 1000));
        stage_pending_change(change);
        const QString staged_result = format_tool_response(
            QStringLiteral("write_file"),
            QStringLiteral("staged full file replacement"),
            repo_relative_path(root, absolute_path));
        return maybe_apply_pending_changes(staged_result);
    };
    auto create_workspace_file = [&](const QString& raw_path, const QString& content) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok) {
            return QStringLiteral("tool_error: create_file path outside workspace");
        }
        const QFileInfo info(absolute_path);
        if (info.exists() && info.isDir()) {
            return QStringLiteral("tool_error: create_file path already exists as directory");
        }
        if (info.exists() && info.isFile()) {
            return QStringLiteral("tool_error: create_file path already exists as file");
        }
        QVariantMap change;
        change.insert(QStringLiteral("action"), QStringLiteral("create_file"));
        change.insert(QStringLiteral("path"), raw_path.trimmed());
        change.insert(QStringLiteral("content"), normalize_newlines(content));
        change.insert(QStringLiteral("summary"), QStringLiteral("create new file"));
        change.insert(QStringLiteral("preview"), clip_text(normalize_newlines(content), 1000));
        stage_pending_change(change);
        const QString staged_result = format_tool_response(
            QStringLiteral("create_file"),
            QStringLiteral("staged new file creation"),
            repo_relative_path(root, absolute_path));
        return maybe_apply_pending_changes(staged_result);
    };
    auto delete_workspace_path = [&](const QString& raw_path, bool recursive) -> QString {
        bool ok = false;
        const QString absolute_path = resolve_workspace_path(root, raw_path, &ok);
        if (!ok) {
            return QStringLiteral("tool_error: delete_path path outside workspace");
        }
        const QFileInfo info(absolute_path);
        if (!info.exists()) {
            return format_tool_response(
                QStringLiteral("delete_path"),
                QStringLiteral("path already absent"),
                repo_relative_path(root, absolute_path));
        }
        if (info.isDir() && !recursive) {
            QDir dir(absolute_path);
            if (!dir.entryList(QDir::NoDotAndDotDot | QDir::AllEntries).isEmpty()) {
                return QStringLiteral("tool_error: delete_path directory is not empty; set recursive=true");
            }
        }
        QVariantMap change;
        change.insert(QStringLiteral("action"), QStringLiteral("delete_path"));
        change.insert(QStringLiteral("path"), raw_path.trimmed());
        change.insert(QStringLiteral("recursive"), recursive);
        change.insert(QStringLiteral("summary"), info.isDir()
            ? QStringLiteral("delete directory")
            : QStringLiteral("delete file"));
        change.insert(QStringLiteral("preview"), QStringLiteral("delete_path recursive=%1 target=%2")
            .arg(recursive ? QStringLiteral("true") : QStringLiteral("false"),
                 repo_relative_path(root, absolute_path)));
        stage_pending_change(change);
        const QString staged_result = format_tool_response(
            QStringLiteral("delete_path"),
            info.isDir() ? QStringLiteral("staged directory deletion") : QStringLiteral("staged file deletion"),
            repo_relative_path(root, absolute_path));
        return maybe_apply_pending_changes(staged_result);
    };
    auto rename_workspace_path = [&](const QString& raw_source_path, const QString& raw_target_path) -> QString {
        return rename_workspace_path_direct(
            raw_source_path,
            raw_target_path,
            auto_apply_pending_changes ? QStringLiteral("tool-loop-auto") : QStringLiteral("tool-loop"));
    };
    auto summarize_pending_changes = [&]() -> QString {
        if (code_agent_pending_changes_.isEmpty()) {
            return format_tool_response(
                QStringLiteral("show_pending_changes"),
                QStringLiteral("no_pending_code_agent_changes"));
        }
        return format_tool_response(
            QStringLiteral("show_pending_changes"),
            pending_code_agent_changes_summary());
    };
    auto run_workspace_command_tool = [&](const QString& tool_name,
                                          const QString& script_name,
                                          const QString& command_text) -> QString {
        const QString script_path = QDir(root).filePath(QStringLiteral("app/service/tools/") + script_name);
        if (!QFileInfo::exists(script_path) || !QFileInfo(script_path).isFile()) {
            return QStringLiteral("tool_error: %1 tool unavailable").arg(tool_name);
        }

        QStringList args;
        args << script_path << root;
        const QString trimmed_command = command_text.trimmed();
        if (!trimmed_command.isEmpty()) {
            args << trimmed_command;
        }

        const QString output = run_process(
            preferred_bash_program(),
            args,
            120000,
            root);
        if (output.startsWith(QStringLiteral("runtime_"))) {
            return output;
        }

        QString body = trimmed_command.isEmpty()
            ? QStringLiteral("command=default")
            : QStringLiteral("command=%1").arg(trimmed_command);
        if (!code_agent_pending_changes_.isEmpty()) {
            body += QStringLiteral("\npending_changes_note=staged changes were not applied before execution");
        }
        if (!output.trimmed().isEmpty()) {
            body += QStringLiteral("\n") + output.trimmed();
        }
        return format_tool_response(tool_name, body);
    };
    auto summarize_action_result = [&](const QString& action_name, const QString& observation) -> QString {
        QString line = action_name.trimmed().isEmpty() ? QStringLiteral("action") : action_name.trimmed();
        if (observation.startsWith(QStringLiteral("tool_error:")) || observation.startsWith(QStringLiteral("runtime_"))) {
            line += QStringLiteral(": failed - ") + clip_text(observation.trimmed(), 240).replace(QChar('\n'), QChar(' '));
        } else {
            line += QStringLiteral(": ok - ") + clip_text(observation.trimmed(), 240).replace(QChar('\n'), QChar(' '));
        }
        return line;
    };
    auto execute_action_object = [&](const QJsonObject& action_obj, bool allow_mutating_actions) -> QString {
        QString action = action_obj.value(QStringLiteral("action")).toString().trimmed();
        if (action.isEmpty()) {
            action = action_obj.value(QStringLiteral("tool")).toString().trimmed();
        }
        if (action.isEmpty()) {
            return QString();
        }
        const bool is_safe_readonly_action =
            action == QStringLiteral("read_file")
            || action == QStringLiteral("search_files")
            || action == QStringLiteral("list_files")
            || action == QStringLiteral("show_pending_changes");
        if (!allow_mutating_actions && !is_safe_readonly_action) {
            return QStringLiteral("tool_error: deferred runner action requires tool loop");
        }

        if (action == QStringLiteral("read_file")) {
            return read_workspace_file(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.value(QStringLiteral("start_line")).toInt(1),
                action_obj.value(QStringLiteral("line_count")).toInt(120));
        }
        if (action == QStringLiteral("search_files")) {
            return search_workspace_files(action_obj.value(QStringLiteral("query")).toString().trimmed());
        }
        if (action == QStringLiteral("list_files")) {
            return list_workspace_files(
                action_obj.value(QStringLiteral("dir")).toString(),
                action_obj.value(QStringLiteral("limit")).toInt(80));
        }
        if (action == QStringLiteral("show_pending_changes")) {
            return summarize_pending_changes();
        }
        if (action == QStringLiteral("mkdir")) {
            return create_workspace_directory(action_obj.value(QStringLiteral("path")).toString());
        }
        if (action == QStringLiteral("apply_patch")) {
            return apply_workspace_patch(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.value(QStringLiteral("old_text")).toString(),
                action_obj.value(QStringLiteral("new_text")).toString(),
                action_obj.value(QStringLiteral("replace_all")).toBool(false));
        }
        if (action == QStringLiteral("replace_range")) {
            return replace_workspace_range(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.value(QStringLiteral("start_line")).toInt(-1),
                action_obj.value(QStringLiteral("end_line")).toInt(-1),
                action_obj.value(QStringLiteral("new_text")).toString());
        }
        if (action == QStringLiteral("write_file")) {
            return write_workspace_file(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.value(QStringLiteral("content")).toString());
        }
        if (action == QStringLiteral("create_file")) {
            return create_workspace_file(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.value(QStringLiteral("content")).toString());
        }
        if (action == QStringLiteral("delete_path")) {
            return delete_workspace_path(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.contains(QStringLiteral("recursive"))
                    ? action_obj.value(QStringLiteral("recursive")).toBool()
                    : true);
        }
        if (action == QStringLiteral("rename_path")) {
            return rename_workspace_path(
                action_obj.value(QStringLiteral("path")).toString(),
                action_obj.value(QStringLiteral("target_path")).toString());
        }
        if (action == QStringLiteral("run_build")) {
            return run_workspace_command_tool(
                QStringLiteral("run_build"),
                QStringLiteral("build.sh"),
                action_obj.value(QStringLiteral("command")).toString());
        }
        if (action == QStringLiteral("run_test")) {
            return run_workspace_command_tool(
                QStringLiteral("run_test"),
                QStringLiteral("test.sh"),
                action_obj.value(QStringLiteral("command")).toString());
        }
        return QString();
    };
    QStringList initial_tool_observations;
    auto execute_safe_runner_actions = [&]() {
        if (runner_action_objects.isEmpty()) {
            return;
        }
        for (const QJsonValue& value : std::as_const(runner_action_objects)) {
            if (!value.isObject()) {
                continue;
            }
            const QJsonObject action_obj = value.toObject();
            const QString action_name = action_obj.value(QStringLiteral("action")).toString().trimmed().isEmpty()
                ? action_obj.value(QStringLiteral("tool")).toString().trimmed()
                : action_obj.value(QStringLiteral("action")).toString().trimmed();
            const QString observation = execute_action_object(action_obj, false);
            if (observation.isEmpty()) {
                continue;
            }
            if (observation == QStringLiteral("tool_error: deferred runner action requires tool loop")) {
                continue;
            }
            initial_tool_observations << observation;
            runner_action_result_summaries << summarize_action_result(action_name, observation);
            remember_recent_action(action_name);
        }
    };
    execute_safe_runner_actions();
    auto build_agent_context = [&]() -> QString {
        QStringList sections;
        sections << QStringLiteral("repo_root=") + root;
        sections << QStringLiteral("target_file=") + (normalized_file_path.isEmpty() ? QStringLiteral("-") : normalized_file_path);
        if (!runner_plan.trimmed().isEmpty()) {
            sections << QStringLiteral("runner_plan=\n") + runner_plan.trimmed();
        }
        if (!runner_summary.trimmed().isEmpty()) {
            sections << QStringLiteral("runner_summary=") + runner_summary.trimmed();
        }
        if (!runner_action_summaries.isEmpty()) {
            sections << QStringLiteral("runner_actions=\n") + runner_action_summaries.join(QStringLiteral("\n"));
        }
        if (!runner_action_result_summaries.isEmpty()) {
            sections << QStringLiteral("runner_action_results=\n") + runner_action_result_summaries.join(QStringLiteral("\n"));
        }
        if (!runner_file_context.trimmed().isEmpty()) {
            sections << QStringLiteral("initial_file_context=\n") + clip_text(runner_file_context.trimmed(), 4000);
        }
        if (!code_agent_recent_actions_.isEmpty()) {
            sections << QStringLiteral("recent_actions=\n") + code_agent_recent_actions_.join(QStringLiteral("\n---\n"));
        }
        QStringList cached_files;
        for (const QString& cached_path : code_agent_recent_files_) {
            if (!code_agent_file_cache_.contains(cached_path)) {
                continue;
            }
            cached_files << QStringLiteral("[file] ") + repo_relative_path(root, cached_path)
                + QStringLiteral("\n") + code_agent_file_cache_.value(cached_path);
        }
        if (!cached_files.isEmpty()) {
            sections << QStringLiteral("cached_files=\n") + cached_files.join(QStringLiteral("\n\n"));
        }
        return sections.join(QStringLiteral("\n\n"));
    };
    auto try_run_tool_loop = [&](const QString& base_url,
                                 const QString& chat_path,
                                 const QString& model_name,
                                 bool allow_suggest_fallback,
                                 const QString& source_label) -> QString {
        QStringList tool_observations;
        if (!runner_file_context.trimmed().isEmpty()) {
            tool_observations << QStringLiteral("initial_context=\n") + runner_file_context.trimmed();
        }
        if (!runner_action_summaries.isEmpty()) {
            tool_observations << QStringLiteral("runner_actions=\n") + runner_action_summaries.join(QStringLiteral("\n"));
        }
        if (!runner_action_result_summaries.isEmpty()) {
            tool_observations << QStringLiteral("runner_action_results=\n") + runner_action_result_summaries.join(QStringLiteral("\n"));
        }
        tool_observations.append(initial_tool_observations);

        for (int step = 0; step < kCodeAgentLoopLimit; ++step) {
            QStringList prompt_sections;
            prompt_sections << QStringLiteral(
                "You are a coding agent working inside the NeurX repository.\n"
                "Return exactly one JSON object and nothing else.\n"
                "Available actions:\n"
                "{\"action\":\"read_file\",\"path\":\"relative/or/absolute\",\"start_line\":1,\"line_count\":120,\"reason\":\"...\"}\n"
                "{\"action\":\"search_files\",\"query\":\"text to search\",\"reason\":\"...\"}\n"
                "{\"action\":\"list_files\",\"dir\":\"relative/or/absolute\",\"limit\":80,\"reason\":\"...\"}\n"
                "{\"action\":\"show_pending_changes\",\"reason\":\"inspect staged edits\"}\n"
                "{\"action\":\"mkdir\",\"path\":\"C:/Users/hello\",\"reason\":\"create a directory\"}\n"
                "{\"action\":\"create_file\",\"path\":\"relative/or/absolute\",\"content\":\"optional initial file content\",\"summary\":\"what changed\"}\n"
                "{\"action\":\"rename_path\",\"path\":\"relative/or/absolute\",\"target_path\":\"relative/or/absolute\",\"summary\":\"what changed\"}\n"
                "{\"action\":\"replace_range\",\"path\":\"relative/or/absolute\",\"start_line\":1,\"end_line\":20,\"new_text\":\"replacement text\",\"summary\":\"what changed\"}\n"
                "{\"action\":\"apply_patch\",\"path\":\"relative/or/absolute\",\"old_text\":\"exact old text\",\"new_text\":\"replacement text\",\"replace_all\":false,\"summary\":\"what changed\"}\n"
                "{\"action\":\"write_file\",\"path\":\"relative/or/absolute\",\"content\":\"full file content\",\"summary\":\"what changed\"}\n"
                "{\"action\":\"delete_path\",\"path\":\"relative/or/absolute\",\"recursive\":true,\"summary\":\"what was removed\"}\n"
                "{\"action\":\"run_build\",\"command\":\"cmake --build build\",\"reason\":\"validate current workspace\"}\n"
                "{\"action\":\"run_test\",\"command\":\"ctest --output-on-failure\",\"reason\":\"validate current workspace\"}\n"
                "{\"action\":\"final\",\"response\":\"user-facing summary\"}\n"
                "Rules:\n"
                "- for file edits stay within the repository\n"
                "- mkdir may create directories under C:/Users and inside the repository\n"
                "- delete_path may delete files or directories inside the repository only\n"
                "- set recursive=true when deleting a non-empty directory\n"
                "- only delete paths when the user explicitly asked for removal or cleanup\n"
                "- read before editing unless the request is trivial\n"
                "- prefer mkdir for directory creation requests\n"
                "- prefer create_file for new file creation requests, including empty files\n"
                "- use rename_path for rename or move requests inside the repository\n"
                "- prefer replace_range for localized line edits\n"
                "- prefer apply_patch for focused edits\n"
                "- write_file must contain the full replacement file content for an existing file\n"
                "- create_file may use empty content when the user asked for an empty file\n"
                "- run_build and run_test execute against the current workspace state only\n"
                "- staged changes are not auto-applied before run_build or run_test\n"
                "- use show_pending_changes before final when edits were staged\n"
                "- prefer minimal edits\n"
                "- if enough work is done, respond with final");
            prompt_sections << QStringLiteral("User request:\n") + sanitize_code_assistant_prompt(prompt);
            prompt_sections << QStringLiteral("Context:\n") + build_agent_context();
            if (!tool_observations.isEmpty()) {
                prompt_sections << QStringLiteral("Tool observations so far:\n") + tool_observations.join(QStringLiteral("\n\n"));
            }
            prompt_sections << QStringLiteral("Current step: %1 of %2").arg(step + 1).arg(kCodeAgentLoopLimit);

            const QString action_text = run_code_chat_with_noise_retry(
                prompt_sections.join(QStringLiteral("\n\n")),
                base_url,
                chat_path,
                model_name,
                allow_suggest_fallback,
                source_label + QStringLiteral("-tool-loop"));
            const QString json_text = extract_json_object_text(action_text);
            if (json_text.isEmpty()) {
                return QString();
            }

            QJsonParseError action_parse_error;
            const QJsonDocument action_doc = QJsonDocument::fromJson(json_text.toUtf8(), &action_parse_error);
            if (action_parse_error.error != QJsonParseError::NoError || !action_doc.isObject()) {
                return QString();
            }
            const QJsonObject action_obj = action_doc.object();
            const QString action = action_obj.value(QStringLiteral("action")).toString().trimmed();
            if (action.isEmpty()) {
                return QString();
            }

            if (action == QStringLiteral("final")) {
                QString response = action_obj.value(QStringLiteral("response")).toString().trimmed();
                if (response.isEmpty()) {
                    response = QStringLiteral("Agent completed the requested coding task.");
                }
                if (!staged_paths.isEmpty()) {
                    for (const QString& path : std::as_const(staged_paths)) {
                        response += QStringLiteral("\npending_path=") + path;
                    }
                }
                response += QStringLiteral("\npending_change_count=") + QString::number(code_agent_pending_changes_.size());
                if (!code_agent_recent_actions_.isEmpty()) {
                    response += QStringLiteral("\nlast_action=") + code_agent_recent_actions_.constLast();
                }
                if (!tool_observations.isEmpty()) {
                    response += QStringLiteral("\nlast_observation=") + clip_text(tool_observations.constLast(), 200);
                }
                return response.trimmed();
            }

            const QString observation = execute_action_object(action_obj, true);
            if (observation.isEmpty()) {
                return QString();
            }

            const QString summary = action_obj.value(QStringLiteral("summary")).toString().trimmed().isEmpty()
                ? action
                : action + QStringLiteral(": ") + action_obj.value(QStringLiteral("summary")).toString().trimmed();
            remember_recent_action(summary);
            tool_observations << observation;
        }

        return QStringLiteral("runtime_timeout: code agent loop exceeded step limit");
    };

    const bool should_try_tool_loop = !normalized_file_path.isEmpty()
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("edit"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("modify"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("update"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("create"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("mkdir"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("directory"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("folder"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("create cn"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("directory cn"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("folder cn"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("write to file"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("delete"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("remove"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("cleanup"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("delete cn"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("patch"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("fix"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("bug"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("error"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("failing"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("test"), Qt::CaseInsensitive)
        || sanitize_code_assistant_prompt(prompt).contains(QStringLiteral("build"), Qt::CaseInsensitive);

    if (should_try_tool_loop) {
        const QString local_tool_result = try_run_tool_loop(
            local_code_base_url,
            local_code_chat_path,
            local_code_model,
            true,
            QStringLiteral("local"));
        if (!local_tool_result.trimmed().isEmpty()
            && !local_tool_result.startsWith(QStringLiteral("runtime_timeout: code agent loop exceeded step limit"))) {
            emit log_message("info", "agent", QString("code-assistant done route=%1 source=local-tool-loop").arg(route));
            return local_tool_result;
        }
        if (!same_code_chat_target) {
            const QString remote_tool_result = try_run_tool_loop(
                remote_code_base_url,
                remote_code_chat_path,
                remote_code_model,
                false,
                QStringLiteral("remote"));
            if (!remote_tool_result.trimmed().isEmpty()
                && !remote_tool_result.startsWith(QStringLiteral("runtime_timeout: code agent loop exceeded step limit"))) {
                emit log_message("info", "agent", QString("code-assistant done route=%1 source=remote-tool-loop").arg(route));
                return remote_tool_result;
            }
        }
    }

    const QString local_result = run_code_chat_with_noise_retry(
        effective_prompt,
        local_code_base_url,
        local_code_chat_path,
        local_code_model,
        true,
        QStringLiteral("local"));
    const bool local_failed = local_result.startsWith("runtime_")
        || local_result.startsWith("local_model_")
        || local_result.startsWith("code_assistant_");
    const bool local_weak = !local_failed
        && (local_result.isEmpty()
            || looks_like_stub_chat_response(local_result)
            || response_looks_garbled(local_result)
            || response_needs_customer_service_fallback(local_result));
    if (!local_failed && !local_weak) {
        emit log_message("info", "agent", QString("code-assistant done route=%1 source=local suggestion_len=%2")
            .arg(route)
            .arg(local_result.size()));
        return local_result;
    }

    emit log_message("warning", "agent",
        QString("code-assistant local fallback reason=%1")
            .arg(local_failed ? local_result.left(200) : QStringLiteral("weak_response")));

    if (same_code_chat_target) {
        const QString final_error = local_result.startsWith("runtime_")
            ? local_result
            : QStringLiteral("runtime_exec_failed: remote backend returned no usable response");
        emit log_message("error", "agent", QString("code-assistant request failed: %1").arg(final_error.left(200)));
        return final_error;
    }

    const QString remote_result = run_code_chat_with_noise_retry(
        effective_prompt,
        remote_code_base_url,
        remote_code_chat_path,
        remote_code_model,
        false,
        QStringLiteral("remote"));
    const bool remote_failed = remote_result.startsWith("runtime_")
        || remote_result.startsWith("local_model_")
        || remote_result.startsWith("code_assistant_");
    if (!remote_failed && !remote_result.trimmed().isEmpty() && !response_looks_garbled(remote_result)) {
        emit log_message("info", "agent", QString("code-assistant done route=%1 source=remote suggestion_len=%2")
            .arg(route)
            .arg(remote_result.size()));
        return remote_result.trimmed();
    }

    const QString fallback = hello_program_fallback(prompt);
    if (!fallback.isEmpty()) {
        emit log_message("info", "agent", QString("code-assistant done route=%1 fallback=hello-template-nochat").arg(route));
        return fallback;
    }
    const QString final_error = local_failed ? local_result : remote_result;
    emit log_message("error", "agent", QString("code-assistant request failed: %1").arg(final_error.left(200)));
    return final_error;
}

QString NeurxBridge::run_agent_state_export(const QString& prompt, int max_steps, const QString& export_kind) {
    const QString root = find_repo_root();
    if (root.isEmpty()) {
        return "repo_not_found";
    }
    const QString s_binary = resolve_s_binary(root);
    if (s_binary.isEmpty()) {
        return QStringLiteral("runtime_exec_failed: S compiler not found. Set NEURX_S_BINARY or put s/s.cmd on PATH.");
    }
    const QString compile_result = ensure_native_s_runtime_compiled(root, s_binary);
    if (!compile_result.isEmpty()) {
        return compile_result;
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

    const QString result = run_s_cli(s_binary, QStringList() << "run" << runner.fileName(), 120000, root);
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
