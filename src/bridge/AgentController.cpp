#include "bridge/AgentController.h"
#include "llm/AnthropicProvider.h"
#include "llm/GeminiProvider.h"
#include "llm/OpenAIProvider.h"
#include "llm/OllamaProvider.h"
#include "tools/FileSystemTool.h"
#include "tools/PatchTool.h"
#include "tools/ShellTool.h"
#include "tools/DockerShellTool.h"
#include "tools/GitHubTool.h"
#include "tools/GitLabTool.h"
#include "tools/JiraTool.h"
#include "tools/SearchTool.h"
#include "tools/WebFetchTool.h"
#include "tools/WebSearchTool.h"
#include "tools/GeminiGroundingTool.h"
#include "tools/CodexTool.h"
#include "tools/DelegationTool.h"
#include "tools/CheckpointTool.h"
#include "tools/KnowledgeTool.h"
#include "tools/McpProxyTool.h"
#include "tools/ReminderTool.h"
#include "tools/LocalGatewayServer.h"
#include "tools/MemoryTool.h"
#include "tools/SessionStore.h"
#include "tools/TodoTool.h"
#include "tools/CustomScriptTool.h"
#include "tools/SkillTool.h"
#include <QFile>
#include <QGuiApplication>
#include <QClipboard>
#include <QBuffer>
#include <QImage>
#include <QImageReader>
#include <QMimeDatabase>
#include <QTextStream>
#include <QFileInfo>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDir>
#include <QDirIterator>
#include <QList>
#include <QProcessEnvironment>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>
#include <QRegularExpression>
#include <QSet>
#include <QUuid>
#include <QDebug>
#include <algorithm>
#include <limits>

static const QString kControllerSystemPrompt = R"(
You are NeurX Code, an expert software engineering AI assistant.
You are operating as a code agent, not a chat assistant.
You have access to tools that let you read and write files, apply patches,
run shell commands (both local and sandboxed Docker), and search the codebase.

Agentic Lifecycle:
1. PERCEIVE: Use 'search' (grep/find) or 'knowledge' to index and read relevant code files. If using Gemini, you can read large sets of files to build a massive context.
2. REASON & GROUND: Understand the logic. Use 'google_search' (native grounding) to verify API usage or documentation facts.
3. PLAN: Use the 'todo' tool to maintain an active step-by-step plan for the task.
4. ACTION: Apply changes using 'patch'. Use 'run_docker_command' to run builds, tests, or scripts in a safe, persistent sandbox.
5. OBSERVE: Read the output from the sandbox. If available, use multimodal input (attached images) to verify UI changes. Iterate until the goal is achieved.

Guidelines:
- For every coding task, form a concise plan before editing.
- For non-trivial tasks, use the todo tool to maintain a current step list.
- Always read relevant files before making changes.
- Prefer targeted patch edits over rewriting entire files.
- Use run_docker_command for builds, tests, or running any untrusted code to ensure isolation and state persistence.
- Use the github, gitlab, or jira tools to read issues, list tasks, or post updates to remote repositories and project management systems.
- For high-precision web queries, use google_search to leverage native grounding.
- Use web_search for general search or web_fetch to read the exact page.
- Use delegate_task for complex sub-patterns:
    - ARCHITECTURE-FIRST: Design headers, then delegate implementation details.
    - PARALLEL-TESTING: Delegate test suite creation while you develop logic.
    - POST-DEV CLEANUP: Delegate workspace-wide linting and doc improvements.
- Leverage the long-context capabilities of Gemini models by reading all relevant files and documentation for complex architectural tasks.
- Use knowledge to index and search local workspace documents or notes before reaching for external search.
- After any edit, verify the result with tests, build commands, or a focused check.
- If verification fails, inspect the failure and iterate until fixed.
- Explain your reasoning briefly before each significant action.
- Ask for clarification if the task is ambiguous.
)";

static const char kSiliconFlowOpenAIEndpoint[] = "https://api.siliconflow.cn/v1/chat/completions";
static const char kSettingsGroup[] = "neurx_code";
static const char kSettingsCurrentProvider[] = "current_provider";
static const char kSettingsCurrentModel[] = "current_model";
static const char kSettingsAnthropicEndpoint[] = "anthropic_endpoint";
static const char kSettingsOpenAIEndpoint[] = "openai_endpoint";
static const char kSettingsAnthropicApiKey[] = "anthropic_api_key";
static const char kSettingsOpenAIApiKey[]    = "openai_api_key";
static const char kSettingsGeminiApiKey[]    = "gemini_api_key";
static const char kSettingsBraveApiKey[]     = "brave_api_key";
static const char kSettingsAutoApproveTools[] = "auto_approve_tools";
static const char kSettingsWorkspacePath[] = "workspace_path";
static const char kSettingsCurrentFilePath[] = "current_file_path";

static QString envValue(const char *name)
{
    return QProcessEnvironment::systemEnvironment().value(name).trimmed();
}

static QString firstNonEmptyEnvValue(std::initializer_list<const char *> names)
{
    for (const char *name : names) {
        const QString value = envValue(name);
        if (!value.isEmpty())
            return value;
    }
    return {};
}

static bool hasAnyEnvValue(std::initializer_list<const char *> names)
{
    const auto env = QProcessEnvironment::systemEnvironment();
    for (const char *name : names) {
        if (!env.value(name).trimmed().isEmpty())
            return true;
    }
    return false;
}

static QVariantList messagesToVariantList(const QList<AgentMessage> &messages)
{
    QVariantList list;
    for (const auto &message : messages)
        list.append(message.toJson().toVariantMap());
    return list;
}

static QString askForApprovalToString(AskForApproval value)
{
    switch (value) {
    case AskForApproval::Never: return QStringLiteral("never");
    case AskForApproval::OnFailure: return QStringLiteral("on-failure");
    case AskForApproval::OnRequest: return QStringLiteral("on-request");
    case AskForApproval::Granular: return QStringLiteral("granular");
    case AskForApproval::UnlessTrusted: return QStringLiteral("unless-trusted");
    }
    return QStringLiteral("on-request");
}

static AskForApproval askForApprovalFromString(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("never")) return AskForApproval::Never;
    if (normalized == QStringLiteral("on-failure")) return AskForApproval::OnFailure;
    if (normalized == QStringLiteral("granular")) return AskForApproval::Granular;
    if (normalized == QStringLiteral("unless-trusted")) return AskForApproval::UnlessTrusted;
    return AskForApproval::OnRequest;
}

static QString reviewerToString(ApprovalsReviewer value)
{
    switch (value) {
    case ApprovalsReviewer::User: return QStringLiteral("user");
    case ApprovalsReviewer::AutoReview: return QStringLiteral("auto-review");
    case ApprovalsReviewer::Guardian: return QStringLiteral("guardian");
    }
    return QStringLiteral("user");
}

static ApprovalsReviewer reviewerFromString(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("auto-review")) return ApprovalsReviewer::AutoReview;
    if (normalized == QStringLiteral("guardian")) return ApprovalsReviewer::Guardian;
    return ApprovalsReviewer::User;
}

static QVariantMap approvalPolicyToVariantMap(const ApprovalPolicy &policy)
{
    QVariantMap map;
    map[QStringLiteral("defaultPolicy")] = askForApprovalToString(policy.defaultPolicy);
    map[QStringLiteral("defaultReviewer")] = reviewerToString(policy.defaultReviewer);
    map[QStringLiteral("requireNetworkApproval")] = policy.requireNetworkApproval;
    map[QStringLiteral("restrictedProtocols")] = QVariantList();
    {
        QVariantList protocols;
        for (const auto &protocol : policy.restrictedProtocols)
            protocols.append(static_cast<int>(protocol));
        map[QStringLiteral("restrictedProtocols")] = protocols;
    }
    map[QStringLiteral("doubleConfirmPatterns")] = policy.doubleConfirmPatterns;
    map[QStringLiteral("readOnlyMode")] = policy.readOnlyMode;
    map[QStringLiteral("autoApproveOnRetry")] = policy.autoApproveOnRetry;

    QVariantList rules;
    for (const auto &rule : policy.granularRules) {
        QVariantMap ruleMap;
        ruleMap[QStringLiteral("resourcePattern")] = rule.resourcePattern;
        ruleMap[QStringLiteral("approval")] = askForApprovalToString(rule.approval);
        ruleMap[QStringLiteral("action")] = rule.action;
        ruleMap[QStringLiteral("toolNames")] = rule.toolNames;
        ruleMap[QStringLiteral("permanent")] = rule.permanent;
        rules.append(ruleMap);
    }
    map[QStringLiteral("granularRules")] = rules;
    return map;
}

static ApprovalPolicy approvalPolicyFromVariantMap(const QVariantMap &map)
{
    ApprovalPolicy policy;
    policy.defaultPolicy = askForApprovalFromString(map.value(QStringLiteral("defaultPolicy")).toString());
    policy.defaultReviewer = reviewerFromString(map.value(QStringLiteral("defaultReviewer")).toString());
    policy.requireNetworkApproval = map.value(QStringLiteral("requireNetworkApproval"), true).toBool();
    policy.readOnlyMode = map.value(QStringLiteral("readOnlyMode"), false).toBool();
    policy.autoApproveOnRetry = map.value(QStringLiteral("autoApproveOnRetry"), false).toBool();

    const QVariantList protocols = map.value(QStringLiteral("restrictedProtocols")).toList();
    for (const auto &protocol : protocols)
        policy.restrictedProtocols.append(static_cast<NetworkApprovalProtocol>(protocol.toInt()));

    policy.doubleConfirmPatterns = map.value(QStringLiteral("doubleConfirmPatterns")).toStringList();

    const QVariantList rules = map.value(QStringLiteral("granularRules")).toList();
    for (const auto &item : rules) {
        const QVariantMap ruleMap = item.toMap();
        GranularApprovalConfig rule;
        rule.resourcePattern = ruleMap.value(QStringLiteral("resourcePattern")).toString();
        rule.approval = askForApprovalFromString(ruleMap.value(QStringLiteral("approval")).toString());
        rule.action = ruleMap.value(QStringLiteral("action")).toString();
        rule.toolNames = ruleMap.value(QStringLiteral("toolNames")).toStringList();
        rule.permanent = ruleMap.value(QStringLiteral("permanent"), false).toBool();
        if (!rule.resourcePattern.trimmed().isEmpty())
            policy.granularRules.append(rule);
    }

    return policy;
}

static QString defaultSecretsEnvPath()
{
    return QDir::homePath() + QStringLiteral("/.config/neurx-code/secrets.env");
}

static QString secretsEnvPathIfExists()
{
    const QString p1 = defaultSecretsEnvPath();
    if (QFileInfo::exists(p1))
        return p1;

    const QString appCfg = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (!appCfg.isEmpty()) {
        const QString p2 = QDir(appCfg).filePath(QStringLiteral("secrets.env"));
        if (QFileInfo::exists(p2))
            return p2;
    }
    return {};
}

static QHash<QString, QString> loadDotenvFile(const QString &path)
{
    QHash<QString, QString> out;
    if (path.trimmed().isEmpty())
        return out;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return out;

    QTextStream ts(&f);
    while (!ts.atEnd()) {
        QString line = ts.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        if (line.startsWith(QStringLiteral("export ")))
            line = line.mid(7).trimmed();

        const int eq = line.indexOf('=');
        if (eq <= 0)
            continue;

        const QString key = line.left(eq).trimmed();
        QString value = line.mid(eq + 1).trimmed();
        if (value.size() >= 2) {
            const QChar q = value.front();
            if ((q == QLatin1Char('\"') || q == QLatin1Char('\'')) && value.back() == q)
                value = value.mid(1, value.size() - 2);
        }
        if (!key.isEmpty() && !value.isEmpty())
            out.insert(key, value);
    }
    return out;
}

static QString firstNonEmptySecretsValue(const QHash<QString, QString> &kv,
                                        std::initializer_list<const char *> names)
{
    for (const char *name : names) {
        const QString v = kv.value(QString::fromUtf8(name)).trimmed();
        if (!v.isEmpty())
            return v;
    }
    return {};
}

static QString normalizeOpenAICompatEndpoint(QString endpoint)
{
    endpoint = endpoint.trimmed();
    if (endpoint.isEmpty())
        return {};
    while (endpoint.endsWith('/'))
        endpoint.chop(1);

    if (endpoint.contains(QStringLiteral("/chat/completions")))
        return endpoint;

    if (endpoint.endsWith(QStringLiteral("/v1")))
        return endpoint + QStringLiteral("/chat/completions");

    if (endpoint.contains(QStringLiteral("/v1")))
        return endpoint + QStringLiteral("/chat/completions");

    return endpoint + QStringLiteral("/v1/chat/completions");
}

static QString normalizeLocalFilePath(const QString &path)
{
    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty())
        return {};

    const QUrl url(trimmed);
    if (url.isLocalFile())
        return QFileInfo(url.toLocalFile()).absoluteFilePath();

    return QFileInfo(trimmed).absoluteFilePath();
}

static QString fileDisplayName(const QString &path)
{
    if (path.isEmpty())
        return QStringLiteral("Untitled");
    return QFileInfo(path).fileName();
}

static QString logPreview(const QString &text, int maxLen = 120)
{
    const QString compact = text.simplified();
    if (compact.size() <= maxLen)
        return compact;
    return compact.left(maxLen) + QStringLiteral("...");
}

static QString toolEventPreview(const QString &toolName, const QJsonObject &args, int maxLen = 140)
{
    QString preview = toolName;
    if (!args.isEmpty()) {
        preview += QStringLiteral(" ");
        preview += QString::fromUtf8(QJsonDocument(args).toJson(QJsonDocument::Compact));
    }
    return logPreview(preview, maxLen);
}

static ProgrammingLanguage detectLanguageFromPath(const QString &path)
{
    const QString ext = QFileInfo(path).suffix().toLower();
    if (ext == QLatin1String("py")) return ProgrammingLanguage::Python;
    if (ext == QLatin1String("js")) return ProgrammingLanguage::JavaScript;
    if (ext == QLatin1String("ts")) return ProgrammingLanguage::TypeScript;
    if (ext == QLatin1String("java")) return ProgrammingLanguage::Java;
    if (ext == QLatin1String("cs")) return ProgrammingLanguage::CSharp;
    if (ext == QLatin1String("cpp") || ext == QLatin1String("cc") || ext == QLatin1String("cxx") || ext == QLatin1String("hpp") || ext == QLatin1String("hh"))
        return ProgrammingLanguage::Cpp;
    if (ext == QLatin1String("c")) return ProgrammingLanguage::C;
    if (ext == QLatin1String("go")) return ProgrammingLanguage::Go;
    if (ext == QLatin1String("rs")) return ProgrammingLanguage::Rust;
    if (ext == QLatin1String("rb")) return ProgrammingLanguage::Ruby;
    if (ext == QLatin1String("php")) return ProgrammingLanguage::PHP;
    if (ext == QLatin1String("swift")) return ProgrammingLanguage::Swift;
    if (ext == QLatin1String("kt") || ext == QLatin1String("kts")) return ProgrammingLanguage::Kotlin;
    if (ext == QLatin1String("sql")) return ProgrammingLanguage::SQL;
    if (ext == QLatin1String("html") || ext == QLatin1String("htm")) return ProgrammingLanguage::HTML;
    if (ext == QLatin1String("css")) return ProgrammingLanguage::CSS;
    return ProgrammingLanguage::Unknown;
}

static QVariantList vectorStringToVariantList(const QVector<QString> &items);

static QVariantMap issueToVariantMap(const CodeIssue &issue)
{
    return QVariantMap{
        {QStringLiteral("id"), issue.id},
        {QStringLiteral("severity"), int(issue.severity)},
        {QStringLiteral("type"), issue.type},
        {QStringLiteral("message"), issue.message},
        {QStringLiteral("lineNumber"), issue.lineNumber},
        {QStringLiteral("columnNumber"), issue.columnNumber},
        {QStringLiteral("suggestedFix"), issue.suggestedFix},
        {QStringLiteral("alternatives"), vectorStringToVariantList(issue.alternatives)},
        {QStringLiteral("rule"), issue.rule},
        {QStringLiteral("documentation"), issue.documentation},
    };
}

static QVariantList stringListToVariantList(const QStringList &items)
{
    QVariantList list;
    for (const auto &item : items)
        list.append(item);
    return list;
}

static QVariantList vectorStringToVariantList(const QVector<QString> &items)
{
    QVariantList list;
    for (const auto &item : items)
        list.append(item);
    return list;
}

static QJsonObject variantMapToJsonObject(const QVariantMap &map)
{
    QJsonObject obj;
    for (auto it = map.begin(); it != map.end(); ++it)
        obj.insert(it.key(), QJsonValue::fromVariant(it.value()));
    return obj;
}

static QVariantMap analysisToVariantMap(const CodeAnalysisResult &result)
{
    QVariantList issues;
    for (const auto &issue : result.issues)
        issues.append(issueToVariantMap(issue));

    return QVariantMap{
        {QStringLiteral("analysisId"), result.analysisId},
        {QStringLiteral("filename"), result.filename},
        {QStringLiteral("language"), int(result.language)},
        {QStringLiteral("lineCount"), result.lineCount},
        {QStringLiteral("characterCount"), result.characterCount},
        {QStringLiteral("complexity"), result.complexity},
        {QStringLiteral("criticalCount"), result.criticalCount},
        {QStringLiteral("errorCount"), result.errorCount},
        {QStringLiteral("warningCount"), result.warningCount},
        {QStringLiteral("infoCount"), result.infoCount},
        {QStringLiteral("quality"), result.quality},
        {QStringLiteral("maintainability"), result.maintainability},
        {QStringLiteral("security"), result.security},
        {QStringLiteral("performance"), result.performance},
        {QStringLiteral("analyzedAt"), result.analyzedAt.toString(Qt::ISODateWithMs)},
        {QStringLiteral("issues"), issues},
    };
}

static QVariantMap reviewToVariantMap(const CodeReview &review)
{
    QVariantList issues;
    for (const auto &issue : review.issues)
        issues.append(issueToVariantMap(issue));

    return QVariantMap{
        {QStringLiteral("reviewId"), review.reviewId},
        {QStringLiteral("author"), review.author},
        {QStringLiteral("reviewer"), review.reviewer},
        {QStringLiteral("overallScore"), review.overallScore},
        {QStringLiteral("reviewedAt"), review.reviewedAt.toString(Qt::ISODateWithMs)},
        {QStringLiteral("code"), review.code},
        {QStringLiteral("issues"), issues},
        {QStringLiteral("suggestions"), stringListToVariantList(review.suggestions)},
        {QStringLiteral("praise"), stringListToVariantList(review.praise)},
    };
}

static QVariantMap explanationToVariantMap(const CodeExplanation &explanation)
{
    return QVariantMap{
        {QStringLiteral("explanationId"), explanation.explanationId},
        {QStringLiteral("summary"), explanation.summary},
        {QStringLiteral("detailedExplanation"), explanation.detailedExplanation},
        {QStringLiteral("createdAt"), explanation.createdAt.toString(Qt::ISODateWithMs)},
        {QStringLiteral("keyComponents"), stringListToVariantList(explanation.keyComponents)},
        {QStringLiteral("suggestedImprovements"), stringListToVariantList(explanation.suggestedImprovements)},
    };
}

static QString selectionTargetLabel(const QString &path, int startLine, int endLine)
{
    if (path.isEmpty())
        return QStringLiteral("selected text");
    if (startLine > 0 && endLine >= startLine) {
        return QStringLiteral("%1:%2-%3")
            .arg(fileDisplayName(path))
            .arg(startLine)
            .arg(endLine);
    }
    return fileDisplayName(path);
}

static QString summarizeCheckpointFiles(const QVariantList &files)
{
    if (files.isEmpty())
        return QString{};

    QStringList preview;
    const qsizetype previewCount = std::min(files.size(), qsizetype(3));
    for (qsizetype i = 0; i < previewCount; ++i)
        preview << files.at(i).toString();

    QString summary = QStringLiteral("%1 file%2").arg(files.size()).arg(files.size() == 1 ? "" : "s");
    if (!preview.isEmpty())
        summary += QStringLiteral(": %1").arg(preview.join(QStringLiteral(", ")));
    if (files.size() > previewCount)
        summary += QStringLiteral(", +%1 more").arg(files.size() - previewCount);
    return summary;
}

static QStringList defaultKnowledgeExtensions()
{
    return {
        "cpp", "h", "hpp", "cc", "cxx",
        "qml", "js", "ts",
        "md", "txt", "rst",
        "json", "yaml", "yml",
        "cmake", "sh", "py", "rs"
    };
}

static QString summarizeKnowledgeHits(const QVariantList &hits, const QString &query)
{
    if (hits.isEmpty())
        return QStringLiteral("No results found for: %1").arg(query);

    QStringList lines;
    lines << QStringLiteral("Search results for: %1").arg(query);
    int idx = 1;
    for (const auto &value : hits) {
        const auto map = value.toMap();
        lines << QStringLiteral("[%1] %2 (chunk %3)\n%4")
                     .arg(idx++)
                     .arg(map.value("path").toString())
                     .arg(map.value("chunkIndex").toInt())
                     .arg(map.value("snippet").toString());
    }
    return lines.join(QStringLiteral("\n\n"));
}

static QString readTextPreview(const QString &path, int maxChars = 700)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    const QString text = QString::fromUtf8(f.readAll()).trimmed();
    if (text.size() <= maxChars)
        return text;
    return text.left(maxChars) + QStringLiteral("...");
}

static QString previewFirstMeaningfulLines(const QString &text, int maxLines = 4)
{
    const QStringList lines = text.split('\n', Qt::SkipEmptyParts);
    QStringList chosen;
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty())
            continue;
        chosen.append(trimmed);
        if (chosen.size() >= maxLines)
            break;
    }
    return chosen.join(QStringLiteral(" "));
}

static bool isImageMimeType(const QString &mimeType)
{
    return mimeType.startsWith(QStringLiteral("image/"));
}

static QString dataUrlFromBytes(const QByteArray &bytes, const QString &mimeType)
{
    const QString normalizedMime = mimeType.isEmpty()
        ? QStringLiteral("image/png")
        : mimeType;
    return QStringLiteral("data:%1;base64,%2")
        .arg(normalizedMime, QString::fromLatin1(bytes.toBase64()));
}

static QVariantList attachmentListFromImage(const QString &filePath, const QByteArray &bytes, const QString &mimeType, const QString &altText)
{
    QVariantMap attachment;
    attachment["type"] = QStringLiteral("image");
    attachment["path"] = QFileInfo(filePath).absoluteFilePath();
    attachment["fileName"] = QFileInfo(filePath).fileName();
    attachment["mimeType"] = mimeType.isEmpty() ? QStringLiteral("image/png") : mimeType;
    attachment["base64"] = QString::fromLatin1(bytes.toBase64());
    attachment["dataUrl"] = dataUrlFromBytes(bytes, mimeType);
    attachment["altText"] = altText;
    return {attachment};
}

static QVariantMap attachmentMapFromBytes(const QString &filePath,
                                          const QByteArray &bytes,
                                          const QString &mimeType,
                                          const QString &altText)
{
    QVariantMap attachment;
    attachment["type"] = QStringLiteral("image");
    attachment["path"] = QFileInfo(filePath).absoluteFilePath();
    attachment["fileName"] = QFileInfo(filePath).fileName();
    attachment["mimeType"] = mimeType.isEmpty() ? QStringLiteral("image/png") : mimeType;
    attachment["base64"] = QString::fromLatin1(bytes.toBase64());
    attachment["dataUrl"] = dataUrlFromBytes(bytes, mimeType);
    attachment["altText"] = altText;
    return attachment;
}

static QVariantMap attachmentMapFromImage(const QImage &image,
                                          const QString &filePath,
                                          const QString &mimeType,
                                          const QString &altText)
{
    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "PNG");
    return attachmentMapFromBytes(filePath, bytes, mimeType.isEmpty() ? QStringLiteral("image/png") : mimeType, altText);
}

static QString attachmentSummary(const QVariantMap &attachment)
{
    const QString fileName = attachment.value("fileName").toString();
    const QString altText = attachment.value("altText").toString();
    if (!fileName.isEmpty() && !altText.isEmpty())
        return QStringLiteral("%1 - %2").arg(fileName, altText);
    if (!fileName.isEmpty())
        return fileName;
    return altText;
}

static QString attachmentSummaryText(const QVariantList &attachments)
{
    if (attachments.isEmpty())
        return QString{};

    QStringList parts;
    for (const QVariant &value : attachments) {
        const QVariantMap map = value.toMap();
        const QString summary = attachmentSummary(map);
        if (!summary.isEmpty())
            parts << summary;
    }
    if (parts.isEmpty())
        return QStringLiteral("[attachments]");
    return QStringLiteral("[attachments] %1").arg(parts.join(QStringLiteral(", ")));
}

static QVariantList attachmentListFromVariantMaps(const QList<QVariantMap> &maps)
{
    QVariantList list;
    for (const auto &map : maps)
        list.append(map);
    return list;
}

static QString skillTitleFromPath(const QString &path)
{
    QFileInfo info(path);
    const QString base = info.dir().dirName();
    if (!base.isEmpty() && base != QStringLiteral("."))
        return base;
    return info.completeBaseName();
}

static QString skillPreview(const QString &content)
{
    return previewFirstMeaningfulLines(content, 3);
}

static QString markdownTitleFromContent(const QString &content)
{
    const QStringList lines = content.split('\n');
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (!trimmed.startsWith(QStringLiteral("#")))
            continue;
        QString title = trimmed;
        while (title.startsWith('#'))
            title.remove(0, 1);
        return title.trimmed();
    }
    return {};
}

static QVariantMap skillEntryForFile(const QString &path, const QString &kind)
{
    QVariantMap entry;
    entry["kind"] = kind;
    entry["path"] = QFileInfo(path).absoluteFilePath();
    entry["title"] = kind == QStringLiteral("instruction")
        ? QStringLiteral("AGENTS.md")
        : skillTitleFromPath(path);

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return entry;

    const QString content = QString::fromUtf8(f.readAll()).trimmed();
    const QString title = markdownTitleFromContent(content);
    if (!title.isEmpty())
        entry["title"] = title;
    entry["description"] = skillPreview(content);
    entry["content"] = content.left(4000);
    return entry;
}

static QVariantList discoverWorkspaceSkillEntries(const QString &workspacePath)
{
    QVariantList entries;
    if (workspacePath.trimmed().isEmpty())
        return entries;

    QSet<QString> seen;
    auto addEntry = [&](const QString &path, const QString &kind) {
        const QString absolute = QFileInfo(path).absoluteFilePath();
        if (absolute.isEmpty() || seen.contains(absolute))
            return;
        seen.insert(absolute);
        entries.append(skillEntryForFile(absolute, kind));
    };

    const QString root = QFileInfo(workspacePath).absoluteFilePath();
    const QString rootAgents = QDir(root).filePath(QStringLiteral("AGENTS.md"));
    if (QFileInfo::exists(rootAgents))
        addEntry(rootAgents, QStringLiteral("instruction"));

    QDirIterator agentsIter(root, QStringList{QStringLiteral("AGENTS.md")}, QDir::Files, QDirIterator::Subdirectories);
    while (agentsIter.hasNext()) {
        const QString path = agentsIter.next();
        if (path.contains(QStringLiteral("/.git/")))
            continue;
        addEntry(path, QStringLiteral("instruction"));
    }

    const QStringList skillRoots = {
        QDir(root).filePath(QStringLiteral(".neurx/skills")),
        QDir(root).filePath(QStringLiteral(".agents/skills")),
        QDir(root).filePath(QStringLiteral("skills")),
    };

    for (const QString &skillRoot : skillRoots) {
        if (!QFileInfo::exists(skillRoot))
            continue;
        QDirIterator skillIter(skillRoot, QStringList{QStringLiteral("SKILL.md")}, QDir::Files, QDirIterator::Subdirectories);
        while (skillIter.hasNext()) {
            const QString path = skillIter.next();
            addEntry(path, QStringLiteral("skill"));
        }
    }

    return entries;
}

static void unregisterToolAndDelete(ToolRegistry *registry, const QString &name)
{
    if (!registry)
        return;

    BaseTool *tool = registry->tool(name);
    if (!tool) {
        registry->unregisterTool(name);
        return;
    }

    registry->unregisterTool(name);
    tool->deleteLater();
}

static QString reminderSummary(const QVariantMap &map)
{
    return QStringLiteral("[%1] %2 at %3")
        .arg(map.value("id").toString(),
             map.value("title").toString(),
             map.value("dueAtUtc").toString());
}

// ── ChatModel ─────────────────────────────────────────────────────────────────

ChatModel::ChatModel(QObject *parent) : QAbstractListModel(parent) {}

QHash<int, QByteArray> ChatModel::roleNames() const
{
    return {
        {RoleRole,      "role"},
        {ContentRole,   "content"},
        {ThinkingRole,  "thinking"},
        {ToolCallsRole, "toolCalls"},
        {AttachmentsRole, "attachments"},
    };
}

QVariant ChatModel::data(const QModelIndex &idx, int role) const
{
    if (!idx.isValid() || idx.row() >= m_msgs.size()) return {};
    const auto &m = m_msgs[idx.row()];
    switch (role) {
    case RoleRole:      return m.role;
    case ContentRole:   return m.content;
    case ThinkingRole:  return m.thinking;
    case ToolCallsRole: return m.toolCalls;
    case AttachmentsRole:return m.attachments;
    default:            return {};
    }
}

void ChatModel::append(const ChatMessage &msg)
{
    beginInsertRows({}, m_msgs.size(), m_msgs.size());
    m_msgs.append(msg);
    endInsertRows();
}

void ChatModel::updateLastContent(const QString &delta)
{
    if (m_msgs.isEmpty()) return;
    m_msgs.last().content += delta;
    const auto idx = index(m_msgs.size() - 1);
    emit dataChanged(idx, idx, {ContentRole});
}

void ChatModel::replaceLast(const ChatMessage &msg)
{
    if (m_msgs.isEmpty()) {
        append(msg);
        return;
    }

    m_msgs.last() = msg;
    const auto idx = index(m_msgs.size() - 1);
    emit dataChanged(idx, idx, {RoleRole, ContentRole, ThinkingRole, ToolCallsRole, AttachmentsRole});
}

void ChatModel::appendToolCallToLastAssistant(const QVariantMap &card)
{
    for (int i = m_msgs.size() - 1; i >= 0; --i) {
        if (m_msgs[i].role != "assistant")
            continue;
        m_msgs[i].toolCalls.append(card);
        const auto idx = index(i);
        emit dataChanged(idx, idx, {ToolCallsRole});
        return;
    }
}

void ChatModel::updateToolCall(const QString &callId, const QVariantMap &card)
{
    for (int i = m_msgs.size() - 1; i >= 0; --i) {
        if (m_msgs[i].role != "assistant")
            continue;

        for (int j = 0; j < m_msgs[i].toolCalls.size(); ++j) {
            const auto existing = m_msgs[i].toolCalls[j].toMap();
            if (existing.value("id").toString() != callId)
                continue;
            m_msgs[i].toolCalls[j] = card;
            const auto idx = index(i);
            emit dataChanged(idx, idx, {ToolCallsRole});
            return;
        }
    }
}

void ChatModel::clear()
{
    beginResetModel();
    m_msgs.clear();
    endResetModel();
}

// ── AgentController ───────────────────────────────────────────────────────────

AgentController::AgentController(QObject *parent) : QObject(parent)
{
    m_chatModel = new ChatModel(this);
    m_registry  = new ToolRegistry(this);
    m_engine    = new AgentEngine(this);
    m_workspaceContext = new WorkspaceContext(this);
    m_workspaceIndex   = new WorkspaceIndex(this);
    m_skillManager     = new ClaudeSkillManager(this);
    m_codeMagic        = new DefaultCodeMagic(this);
    m_sandboxManager   = new DefaultSandboxManager(this);
    m_approvalManager  = new DefaultApprovalManager(this);

    connect(m_sandboxManager, &DefaultSandboxManager::sandboxExecutionEvent,
            this, &AgentController::onSandboxExecutionEvent);
    connect(m_codeMagic, &CodeMagic::analysisCompleted,
            this, &AgentController::onCodeMagicAnalysisCompleted);
    connect(m_codeMagic, &CodeMagic::generationCompleted,
            this, &AgentController::onCodeMagicGenerationCompleted);
    connect(m_codeMagic, &CodeMagic::refactoringCompleted,
            this, &AgentController::onCodeMagicRefactoringCompleted);
    connect(m_codeMagic, &CodeMagic::testsGenerated,
            this, &AgentController::onCodeMagicTestsGenerated);
    connect(m_codeMagic, &CodeMagic::errorOccurred,
            this, &AgentController::onCodeMagicErrorOccurred);

    const QString threadStoreBase = QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation))
        .filePath(QStringLiteral("threads"));
    m_threadStore = new FileBasedThreadStore(threadStoreBase, this);
    if (!m_threadStore->initialize())
        qWarning().noquote() << "[thread-store] failed to initialize at" << threadStoreBase;

    // Register providers
    auto *anthropic = new AnthropicProvider(this);
    auto *openai    = new OpenAIProvider(this);
    auto *ollama    = new OllamaProvider(this);
    auto *gemini    = new GeminiProvider(this);
    m_providers["anthropic"] = anthropic;
    m_providers["openai"]    = openai;
    m_providers["ollama"]    = ollama;
    m_providers["gemini"]    = gemini;

    m_currentProvider = "openai";
    m_currentModel    = openai->availableModels().first();
    m_anthropicEndpoint = QStringLiteral("https://api.anthropic.com/v1/messages");
    m_openaiEndpoint  = QString::fromUtf8(kSiliconFlowOpenAIEndpoint);
    m_sessionId = TaskSessionStore::defaultSessionId();
    m_threadCreatedAt = QDateTime::currentDateTimeUtc();

    loadSettings();
    configurePolicyManagers();
    setupEngine();
    if (!m_workspacePath.isEmpty())
        refreshWorkspaceSkills();
    restoreTaskSession();
    startLocalGateway();

    if (!m_currentFilePath.isEmpty() && QFileInfo::exists(m_currentFilePath)) {
        openEditorFile(m_currentFilePath);
    }
}

AgentController::CodeMagicInput AgentController::resolveCodeMagicInput() const
{
    CodeMagicInput input;
    if (!m_selectedText.trimmed().isEmpty()) {
        input.path = m_selectedFilePath.isEmpty() ? m_currentFilePath : m_selectedFilePath;
        input.code = m_selectedText;
        input.language = detectLanguageFromPath(input.path);
        input.targetLabel = selectionTargetLabel(input.path, m_selectedStartLine, m_selectedEndLine);
        input.hasSelection = true;
        return input;
    }

    input.path = m_currentFilePath;
    input.code = m_currentFileContent;
    input.language = detectLanguageFromPath(m_currentFilePath);
    input.targetLabel = fileDisplayName(m_currentFilePath);
    return input;
}

void AgentController::updateCodeMagicResult(const QVariantMap &result, const QString &targetLabel)
{
    m_codeMagicResult = result;
    m_codeMagicTargetLabel = targetLabel;
    emit codeMagicResultChanged();
}

static QStringList inferredToolTags(const QString &toolName)
{
    if (toolName == QStringLiteral("file_system"))
        return {QStringLiteral("files"), QStringLiteral("workspace"), QStringLiteral("io")};
    if (toolName == QStringLiteral("patch"))
        return {QStringLiteral("diff"), QStringLiteral("files"), QStringLiteral("edit")};
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command"))
        return {QStringLiteral("shell"), QStringLiteral("command"), QStringLiteral("execution")};
    if (toolName == QStringLiteral("search"))
        return {QStringLiteral("search"), QStringLiteral("workspace")};
    if (toolName == QStringLiteral("web_search") || toolName == QStringLiteral("web_fetch"))
        return {QStringLiteral("web"), QStringLiteral("network")};
    if (toolName == QStringLiteral("knowledge"))
        return {QStringLiteral("knowledge"), QStringLiteral("indexing")};
    if (toolName == QStringLiteral("checkpoint"))
        return {QStringLiteral("checkpoint"), QStringLiteral("rollback")};
    if (toolName == QStringLiteral("todo"))
        return {QStringLiteral("planning"), QStringLiteral("tasks")};
    if (toolName == QStringLiteral("codex_agent"))
        return {QStringLiteral("agent"), QStringLiteral("delegation")};
    return {QStringLiteral("tool")};
}

QString AgentController::approvalRiskLevelForTool(const QString &toolName, const QVariantMap &arguments) const
{
    const QString name = toolName.trimmed();
    if (name == QStringLiteral("run_command") || name == QStringLiteral("run_docker_command")) {
        const QString command = arguments.value(QStringLiteral("command")).toString().trimmed().toLower();
        const QStringList destructivePatterns = {
            QStringLiteral(R"(\brm\b.*\s-rf\b)"),
            QStringLiteral(R"(\bgit\b.*\breset\b.*\b--hard\b)"),
            QStringLiteral(R"(\bgit\b.*\bclean\b.*\b-f\b)"),
            QStringLiteral(R"(\bchmod\b.*\b-R\b.*\b777\b)"),
            QStringLiteral(R"(\bchown\b.*\b-R\b)"),
            QStringLiteral(R"(\bdd\b.*\bof=/dev/\w+\b)"),
            QStringLiteral(R"(\bmkfs\w*\b)"),
            QStringLiteral(R"(\bshutdown\b|\breboot\b|\bhalt\b)"),
        };
        for (const auto &pattern : destructivePatterns) {
            if (QRegularExpression(pattern, QRegularExpression::CaseInsensitiveOption).match(command).hasMatch())
                return QStringLiteral("critical");
        }
        return name == QStringLiteral("run_docker_command") ? QStringLiteral("low") : QStringLiteral("high");
    }

    if (name == QStringLiteral("file_system")
        || name == QStringLiteral("patch")
        || name == QStringLiteral("github")
        || name == QStringLiteral("gitlab")
        || name == QStringLiteral("jira"))
        return QStringLiteral("high");

    if (name == QStringLiteral("web_search")
        || name == QStringLiteral("web_fetch")
        || name == QStringLiteral("codex_agent"))
        return QStringLiteral("medium");

    return QStringLiteral("low");
}

bool AgentController::toolNeedsApproval(const QString &toolName, const QVariantMap &arguments,
                                        QString *riskLevel, QString *reason) const
{
    const QString risk = approvalRiskLevelForTool(toolName, arguments);
    if (riskLevel)
        *riskLevel = risk;

    QString resource;
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command"))
        resource = arguments.value(QStringLiteral("command")).toString();
    else if (toolName == QStringLiteral("patch"))
        resource = arguments.value(QStringLiteral("patch")).toString();
    else if (toolName == QStringLiteral("file_system")) {
        const QString op = arguments.value(QStringLiteral("operation")).toString();
        const QString path = arguments.value(QStringLiteral("path")).toString();
        const QString destination = arguments.value(QStringLiteral("destination")).toString();
        resource = destination.isEmpty()
            ? QStringLiteral("%1 %2").arg(op, path)
            : QStringLiteral("%1 %2 -> %3").arg(op, path, destination);
    }

    if (!m_approvalManager) {
        if (reason)
            *reason = QStringLiteral("No approval manager configured.");
        return !m_autoApproveTools || risk == QStringLiteral("high") || risk == QStringLiteral("critical");
    }

    const AskForApproval policy = m_approvalManager->getPolicyFor(toolName, resource);
    if (reason) {
        *reason = QStringLiteral("policy=%1, risk=%2")
                      .arg(int(policy))
                      .arg(risk);
    }

    if (policy == AskForApproval::Never)
        return false;
    if (!m_autoApproveTools)
        return true;
    if (policy == AskForApproval::OnRequest
        || policy == AskForApproval::Granular
        || policy == AskForApproval::UnlessTrusted)
        return true;
    if (policy == AskForApproval::OnFailure)
        return false;
    return risk == QStringLiteral("high") || risk == QStringLiteral("critical");
}

QVariantMap AgentController::buildToolPermissionState(const QString &toolName, const QVariantMap &context) const
{
    QVariantMap out;
    QString risk;
    QString reason;
    const bool needsApproval = toolNeedsApproval(toolName, context, &risk, &reason);
    out.insert(QStringLiteral("toolName"), toolName);
    out.insert(QStringLiteral("riskLevel"), risk);
    out.insert(QStringLiteral("requiresApproval"), needsApproval);
    out.insert(QStringLiteral("reason"), reason);
    if (m_approvalManager) {
        const QString resource = context.value(QStringLiteral("command")).toString().trimmed().isEmpty()
            ? context.value(QStringLiteral("path")).toString()
            : context.value(QStringLiteral("command")).toString();
        const AskForApproval policy = m_approvalManager->getPolicyFor(toolName, resource);
        out.insert(QStringLiteral("policy"), int(policy));
        out.insert(QStringLiteral("readOnlyMode"), m_approvalManager->isReadOnlyMode());
    }
    return out;
}

QVariantMap AgentController::buildToolCatalogEntry(BaseTool *tool) const
{
    QVariantMap entry;
    if (!tool)
        return entry;

    const QString name = tool->name();
    const QJsonObject schema = tool->parametersSchema();
    const QString schemaText = QString::fromUtf8(QJsonDocument(schema).toJson(QJsonDocument::Compact));
    const QStringList tags = inferredToolTags(name);
    const QVariantMap permission = buildToolPermissionState(name, QVariantMap{});

    int executionCount = 0;
    QString lastUsedAt;
    for (const auto &event : m_executionTimeline) {
        const QVariantMap ev = event.toMap();
        if (ev.value(QStringLiteral("toolName")).toString() == name) {
            ++executionCount;
            lastUsedAt = ev.value(QStringLiteral("timestamp")).toString();
        }
    }

    entry.insert(QStringLiteral("toolId"), name);
    entry.insert(QStringLiteral("name"), name);
    entry.insert(QStringLiteral("description"), tool->description());
    entry.insert(QStringLiteral("summary"), tool->summary(QJsonObject{}));
    entry.insert(QStringLiteral("schema"), schema.toVariantMap());
    entry.insert(QStringLiteral("schemaText"), schemaText);
    entry.insert(QStringLiteral("tags"), tags);
    entry.insert(QStringLiteral("category"), tags.contains(QStringLiteral("shell"))
                                                    ? QStringLiteral("Execution")
                                                    : tags.contains(QStringLiteral("files"))
                                                        ? QStringLiteral("Workspace")
                                                        : tags.contains(QStringLiteral("web"))
                                                            ? QStringLiteral("Network")
                                                            : QStringLiteral("General"));
    entry.insert(QStringLiteral("available"), true);
    entry.insert(QStringLiteral("executionCount"), executionCount);
    entry.insert(QStringLiteral("lastUsedAt"), lastUsedAt);
    entry.insert(QStringLiteral("permission"), permission);
    entry.insert(QStringLiteral("requiresApproval"), permission.value(QStringLiteral("requiresApproval")).toBool());
    entry.insert(QStringLiteral("riskLevel"), permission.value(QStringLiteral("riskLevel")).toString());
    return entry;
}

QVariantList AgentController::toolCatalog() const
{
    QVariantList list;
    if (!m_registry)
        return list;

    for (BaseTool *tool : m_registry->allTools()) {
        if (!tool)
            continue;
        list.append(buildToolCatalogEntry(tool));
    }
    return list;
}

QVariantList AgentController::discoverTools(const QString &query) const
{
    const QString needle = query.trimmed().toLower();
    const QVariantList catalog = toolCatalog();
    if (needle.isEmpty())
        return catalog;

    QVariantList results;
    for (const auto &item : catalog) {
        const QVariantMap entry = item.toMap();
        const QString haystack = QStringList{
            entry.value(QStringLiteral("name")).toString(),
            entry.value(QStringLiteral("description")).toString(),
            entry.value(QStringLiteral("schemaText")).toString(),
            entry.value(QStringLiteral("tags")).toStringList().join(QStringLiteral(" "))
        }.join(QStringLiteral(" ")).toLower();
        if (haystack.contains(needle))
            results.append(entry);
    }
    return results;
}

QVariantMap AgentController::toolSchema(const QString &toolName) const
{
    QVariantMap out;
    if (!m_registry)
        return out;

    BaseTool *tool = m_registry->tool(toolName);
    if (!tool) {
        out.insert(QStringLiteral("error"), QStringLiteral("Tool not found."));
        return out;
    }

    out.insert(QStringLiteral("toolId"), tool->name());
    out.insert(QStringLiteral("name"), tool->name());
    out.insert(QStringLiteral("description"), tool->description());
    out.insert(QStringLiteral("schema"), tool->parametersSchema().toVariantMap());
    out.insert(QStringLiteral("schemaText"), QString::fromUtf8(QJsonDocument(tool->parametersSchema()).toJson(QJsonDocument::Indented)));
    out.insert(QStringLiteral("permission"), buildToolPermissionState(tool->name(), QVariantMap{}));
    return out;
}

QVariantMap AgentController::executePendingTool(const QString &approvalId)
{
    const auto pending = m_pendingToolExecutions.value(approvalId);
    if (pending.toolName.isEmpty())
        return {{QStringLiteral("error"), QStringLiteral("Pending tool execution not found.")}};

    m_pendingToolExecutions.remove(approvalId);
    if (!m_registry)
        return {{QStringLiteral("error"), QStringLiteral("Tool registry is not available.")}};

    BaseTool *tool = m_registry->tool(pending.toolName);
    if (!tool)
        return {{QStringLiteral("error"), QStringLiteral("Unknown tool: %1").arg(pending.toolName)}};

    appendExecutionEvent(QStringLiteral("tool_execution"),
                         QStringLiteral("Tool execution started"),
                         QStringLiteral("running"),
                         pending.summary,
                         pending.toolName,
                         approvalId);

    QString accumulatedOutput;
    const QMetaObject::Connection outputConn = connect(tool, &BaseTool::outputChunk, this,
        [&](const QString &chunkCallId, const QString &chunk) {
            if (chunkCallId != approvalId)
                return;
            if (accumulatedOutput.isEmpty()) {
                appendExecutionEvent(QStringLiteral("tool_output"),
                                     QStringLiteral("Tool output"),
                                     QStringLiteral("running"),
                                     logPreview(chunk),
                                     pending.toolName,
                                     approvalId);
            }
            accumulatedOutput += chunk;
        });

    const QMetaObject::Connection eventConn = connect(tool, &BaseTool::eventOccurred, this,
        [&](const QString &chunkCallId, const QVariantMap &event) {
            if (chunkCallId != approvalId)
                return;
            appendExecutionEvent(event.value("kind").toString(),
                                 event.value("title").toString(),
                                 event.value("status").toString(),
                                 event.value("details").toString(),
                                 event.value("toolName").toString(),
                                 approvalId);
        });

    const ToolResult toolResult = tool->execute(approvalId, variantMapToJsonObject(pending.arguments));
    disconnect(outputConn);
    disconnect(eventConn);

    QVariantMap response;
    response.insert(QStringLiteral("toolName"), pending.toolName);
    response.insert(QStringLiteral("callId"), approvalId);
    response.insert(QStringLiteral("approved"), true);
    response.insert(QStringLiteral("isError"), toolResult.isError);
    response.insert(QStringLiteral("content"), toolResult.content);
    response.insert(QStringLiteral("summary"), pending.summary);
    if (!accumulatedOutput.isEmpty())
        response.insert(QStringLiteral("streamOutput"), accumulatedOutput);

    appendExecutionEvent(QStringLiteral("tool_execution"),
                         toolResult.isError ? QStringLiteral("Tool failed") : QStringLiteral("Tool completed"),
                         toolResult.isError ? QStringLiteral("error") : QStringLiteral("done"),
                         logPreview(toolResult.content),
                         pending.toolName,
                         approvalId);
    if (!m_restoringSessionHistory)
        saveTaskSession();

    if (toolResult.isError)
        response.insert(QStringLiteral("error"), toolResult.content);
    else
        emit successOccurred(QStringLiteral("%1 completed.").arg(pending.toolName));
    return response;
}

QVariantMap AgentController::toolPermissionState(const QString &toolName, const QVariantMap &context) const
{
    return buildToolPermissionState(toolName, context);
}

QVariantMap AgentController::toolExecutionStats(const QString &toolName) const
{
    QVariantMap stats;
    if (toolName.trimmed().isEmpty())
        return stats;

    int total = 0;
    int success = 0;
    int failed = 0;
    QString lastUsedAt;
    for (const auto &event : m_executionTimeline) {
        const QVariantMap ev = event.toMap();
        if (ev.value(QStringLiteral("toolName")).toString() != toolName)
            continue;
        const QString kind = ev.value(QStringLiteral("kind")).toString();
        if (kind != QStringLiteral("tool_execution"))
            continue;
        ++total;
        const QString status = ev.value(QStringLiteral("status")).toString();
        if (status == QStringLiteral("done"))
            ++success;
        else if (status == QStringLiteral("error"))
            ++failed;
        lastUsedAt = ev.value(QStringLiteral("timestamp")).toString();
    }

    stats.insert(QStringLiteral("toolName"), toolName);
    stats.insert(QStringLiteral("totalExecutions"), total);
    stats.insert(QStringLiteral("successfulExecutions"), success);
    stats.insert(QStringLiteral("failedExecutions"), failed);
    stats.insert(QStringLiteral("successRate"), total > 0 ? (100.0 * success) / total : 0.0);
    stats.insert(QStringLiteral("lastUsedAt"), lastUsedAt);
    return stats;
}

QVariantList AgentController::toolExecutionHistory(const QString &toolName, int limit) const
{
    QVariantList history;
    if (toolName.trimmed().isEmpty() || limit <= 0)
        return history;

    for (int i = m_executionTimeline.size() - 1; i >= 0; --i) {
        const QVariantMap ev = m_executionTimeline.at(i).toMap();
        if (ev.value(QStringLiteral("toolName")).toString() != toolName)
            continue;
        history.append(ev);
        if (history.size() >= limit)
            break;
    }
    return history;
}

QVariantMap AgentController::executeToolByName(const QString &toolName, const QVariantMap &arguments)
{
    QVariantMap response;
    if (!m_registry) {
        response.insert(QStringLiteral("error"), QStringLiteral("Tool registry is not available."));
        return response;
    }

    BaseTool *tool = m_registry->tool(toolName);
    if (!tool) {
        response.insert(QStringLiteral("error"), QStringLiteral("Unknown tool: %1").arg(toolName));
        return response;
    }

    QString riskLevel;
    QString reason;
    const bool needsApproval = toolNeedsApproval(toolName, arguments, &riskLevel, &reason);
    const QString callId = QUuid::createUuid().toString(QUuid::WithoutBraces);

    if (needsApproval && !m_autoApproveTools) {
        const QJsonObject jsonArgs = variantMapToJsonObject(arguments);
        m_pendingToolExecutions.insert(callId, PendingToolExecution{toolName, arguments, tool->summary(jsonArgs), riskLevel});
        emit toolApprovalRequired(callId, toolName, tool->summary(jsonArgs), riskLevel);
        response.insert(QStringLiteral("pending"), true);
        response.insert(QStringLiteral("approvalId"), callId);
        response.insert(QStringLiteral("toolName"), toolName);
        response.insert(QStringLiteral("riskLevel"), riskLevel);
        response.insert(QStringLiteral("reason"), reason);
        appendExecutionEvent(QStringLiteral("approval"),
                             QStringLiteral("Tool approval requested"),
                             QStringLiteral("running"),
                             QStringLiteral("%1 · %2").arg(toolName, riskLevel),
                             toolName,
                             callId);
        if (!m_restoringSessionHistory)
            saveTaskSession();
        return response;
    }

    appendExecutionEvent(QStringLiteral("tool_execution"),
                         QStringLiteral("Tool execution started"),
                         QStringLiteral("running"),
                         tool->summary(variantMapToJsonObject(arguments)),
                         toolName,
                         callId);

    QString accumulatedOutput;
    const QMetaObject::Connection outputConn = connect(tool, &BaseTool::outputChunk, this,
        [&](const QString &chunkCallId, const QString &chunk) {
            if (chunkCallId != callId)
                return;
            if (accumulatedOutput.isEmpty()) {
                appendExecutionEvent(QStringLiteral("tool_output"),
                                     QStringLiteral("Tool output"),
                                     QStringLiteral("running"),
                                     logPreview(chunk),
                                     toolName,
                                     callId);
            }
            accumulatedOutput += chunk;
        });

    const QMetaObject::Connection eventConn = connect(tool, &BaseTool::eventOccurred, this,
        [&](const QString &chunkCallId, const QVariantMap &event) {
            if (chunkCallId != callId)
                return;
            appendExecutionEvent(event.value("kind").toString(),
                                 event.value("title").toString(),
                                 event.value("status").toString(),
                                 event.value("details").toString(),
                                 event.value("toolName").toString(),
                                 callId);
        });

    const ToolResult toolResult = tool->execute(callId, variantMapToJsonObject(arguments));
    disconnect(outputConn);
    disconnect(eventConn);

    response.insert(QStringLiteral("toolName"), toolName);
    response.insert(QStringLiteral("callId"), callId);
    response.insert(QStringLiteral("isError"), toolResult.isError);
    response.insert(QStringLiteral("content"), toolResult.content);
    response.insert(QStringLiteral("summary"), tool->summary(variantMapToJsonObject(arguments)));
    response.insert(QStringLiteral("riskLevel"), riskLevel);
    if (!accumulatedOutput.isEmpty())
        response.insert(QStringLiteral("streamOutput"), accumulatedOutput);

    appendExecutionEvent(QStringLiteral("tool_execution"),
                         toolResult.isError ? QStringLiteral("Tool failed") : QStringLiteral("Tool completed"),
                         toolResult.isError ? QStringLiteral("error") : QStringLiteral("done"),
                         logPreview(toolResult.content),
                         toolName,
                         callId);
    if (!m_restoringSessionHistory)
        saveTaskSession();

    if (toolResult.isError) {
        response.insert(QStringLiteral("error"), toolResult.content);
        emit errorOccurred(toolResult.content);
    } else {
        emit successOccurred(QStringLiteral("%1 completed.").arg(toolName));
    }
    return response;
}

void AgentController::setCurrentSelection(const QString &filePath, const QString &code,
                                          int startLine, int endLine)
{
    const QString normalizedPath = normalizeLocalFilePath(filePath);
    const QString trimmedCode = code;

    if (normalizedPath.isEmpty() || trimmedCode.trimmed().isEmpty()) {
        clearCurrentSelection();
        return;
    }

    m_selectedFilePath = normalizedPath;
    m_selectedText = trimmedCode;
    m_selectedStartLine = startLine;
    m_selectedEndLine = endLine;
    emit currentSelectionChanged();
}

void AgentController::loadSettings()
{
    QSettings s;
    s.beginGroup(kSettingsGroup);

    const QString provider = s.value(kSettingsCurrentProvider, m_currentProvider).toString();
    const QString model = s.value(kSettingsCurrentModel, m_currentModel).toString();
    const QString anthropicEndpoint = s.value(kSettingsAnthropicEndpoint, m_anthropicEndpoint).toString();
    const QString endpoint = s.value(kSettingsOpenAIEndpoint, m_openaiEndpoint).toString();
    const QString anthropicApiKey = s.value(kSettingsAnthropicApiKey, m_anthropicApiKey).toString();
    const QString openaiApiKey = s.value(kSettingsOpenAIApiKey, m_openaiApiKey).toString();
    const QString geminiApiKey = s.value(kSettingsGeminiApiKey, m_geminiApiKey).toString();
    const bool autoApprove = s.value(kSettingsAutoApproveTools, m_autoApproveTools).toBool();
    const QString workspace = s.value(kSettingsWorkspacePath, QString{}).toString();
    const QString currentFile = s.value(kSettingsCurrentFilePath, QString{}).toString();

    s.endGroup();

    m_anthropicEndpoint = anthropicEndpoint.trimmed().isEmpty()
        ? QStringLiteral("https://api.anthropic.com/v1/messages")
        : anthropicEndpoint.trimmed();
    const QString envEndpoint = firstNonEmptyEnvValue({
        // SiliconFlow / OpenAI-compatible
        "SILICONFLOW_API_URL",
        "SILICONFLOW_API_ENDPOINT",
        "SILICONFLOW_API_BASE_URL",
        // Generic OpenAI-compatible
        "OPENAI_API_URL",
        "OPENAI_API_ENDPOINT",
        "OPENAI_API_BASE_URL",
        "OPENAI_BASE_URL",
    });

    const QString secretsPath = secretsEnvPathIfExists();
    const auto secrets = loadDotenvFile(secretsPath);
    const QString secretsEndpoint = firstNonEmptySecretsValue(secrets, {
        "SILICONFLOW_API_URL",
        "SILICONFLOW_API_ENDPOINT",
        "SILICONFLOW_API_BASE_URL",
        "OPENAI_API_URL",
        "OPENAI_API_ENDPOINT",
        "OPENAI_API_BASE_URL",
        "OPENAI_BASE_URL",
    });

    const QString settingsEndpoint = endpoint.trimmed();

    // Precedence: env > Settings(UI) > secrets.env > default.
    QString chosenEndpoint;
    if (!envEndpoint.isEmpty()) {
        chosenEndpoint = envEndpoint;
        m_openaiEndpointFromRuntime = true;
    } else if (!settingsEndpoint.isEmpty()) {
        chosenEndpoint = settingsEndpoint;
        m_openaiEndpointFromRuntime = false;
    } else if (!secretsEndpoint.isEmpty()) {
        chosenEndpoint = secretsEndpoint;
        m_openaiEndpointFromRuntime = true;
    } else {
        chosenEndpoint = QString::fromUtf8(kSiliconFlowOpenAIEndpoint);
        m_openaiEndpointFromRuntime = false;
    }
    m_openaiEndpoint = normalizeOpenAICompatEndpoint(chosenEndpoint);

    m_anthropicApiKey = anthropicApiKey.trimmed();
    m_geminiApiKey = geminiApiKey.trimmed();

    const QString envOpenaiKey = firstNonEmptyEnvValue({
        "SILICONFLOW_API_KEY",
        "OPENAI_API_KEY",
        "OPENAI_COMPATIBLE_API_KEY",
    });
    const QString secretsOpenaiKey = firstNonEmptySecretsValue(secrets, {
        "SILICONFLOW_API_KEY",
        "OPENAI_API_KEY",
        "OPENAI_COMPATIBLE_API_KEY",
    });
    const QString settingsOpenaiKey = openaiApiKey.trimmed();

    // Precedence: env > Settings(UI) > secrets.env.
    if (!envOpenaiKey.isEmpty()) {
        m_openaiApiKey = envOpenaiKey;
        m_openaiApiKeyFromRuntime = true;
    } else if (!settingsOpenaiKey.isEmpty()) {
        m_openaiApiKey = settingsOpenaiKey;
        m_openaiApiKeyFromRuntime = false;
    } else {
        m_openaiApiKey = secretsOpenaiKey;
        m_openaiApiKeyFromRuntime = !secretsOpenaiKey.isEmpty();
    }

    // Try to load from local secrets.json if still empty or as an override fallback
    if (m_openaiApiKey.isEmpty() || m_anthropicApiKey.isEmpty()) {
        QString secretsPath = QDir::current().filePath(".neurx/secrets.json");
        if (!workspace.isEmpty() && !QFileInfo::exists(secretsPath)) {
            secretsPath = QDir(workspace).filePath(".neurx/secrets.json");
        }
        if (QFileInfo::exists(secretsPath)) {
            QFile f(secretsPath);
            if (f.open(QIODevice::ReadOnly)) {
                const QJsonObject obj = QJsonDocument::fromJson(f.readAll()).object();
                if (m_openaiApiKey.isEmpty() && obj.contains("openai_api_key"))
                    m_openaiApiKey = obj["openai_api_key"].toString().trimmed();
                if (m_anthropicApiKey.isEmpty() && obj.contains("anthropic_api_key"))
                    m_anthropicApiKey = obj["anthropic_api_key"].toString().trimmed();
            }
        }
    }

    m_autoApproveTools = autoApprove;

    if (m_providers.contains(provider)) {
        m_currentProvider = provider;
        auto modelsForProvider = m_providers.value(m_currentProvider)->availableModels();
        if (!model.isEmpty() && modelsForProvider.contains(model))
            m_currentModel = model;
        else if (!modelsForProvider.isEmpty())
            m_currentModel = modelsForProvider.first();
    }

    if (!workspace.isEmpty())
        m_workspacePath = workspace;

    if (!currentFile.isEmpty())
        m_currentFilePath = currentFile;
}

void AgentController::saveSettings() const
{
    QSettings s;
    s.beginGroup(kSettingsGroup);
    s.setValue(kSettingsCurrentProvider, m_currentProvider);
    s.setValue(kSettingsCurrentModel, m_currentModel);
    s.setValue(kSettingsAnthropicEndpoint, m_anthropicEndpoint);

    // If endpoint/key are supplied via environment/secrets.env, treat them as runtime-only
    // and avoid persisting them into local QSettings.
    if (!m_openaiEndpointFromRuntime) {
        s.setValue(kSettingsOpenAIEndpoint, m_openaiEndpoint);
    }

    s.setValue(kSettingsAnthropicApiKey, m_anthropicApiKey);
    s.setValue(kSettingsGeminiApiKey, m_geminiApiKey);
    if (!m_openaiApiKeyFromRuntime) {
        s.setValue(kSettingsOpenAIApiKey, m_openaiApiKey);
    }
    s.setValue(kSettingsAutoApproveTools, m_autoApproveTools);
    s.setValue(kSettingsWorkspacePath, m_workspacePath);
    s.setValue(kSettingsCurrentFilePath, m_currentFilePath);
    s.endGroup();
    s.sync();
}

QVariantList AgentController::openFiles() const
{
    QVariantList files;
    for (int i = 0; i < m_documents.size(); ++i) {
        const auto &doc = m_documents.at(i);
        QVariantMap item;
        item["path"] = doc.path;
        item["name"] = fileDisplayName(doc.path);
        item["dirty"] = doc.dirty;
        item["active"] = (i == m_currentEditorIndex);
        files.append(item);
    }
    return files;
}

QVariantList AgentController::todoItems() const
{
    if (auto *todoTool = qobject_cast<TodoTool *>(m_registry ? m_registry->tool("todo") : nullptr))
        return todoTool->todoItems();
    return {};
}

QVariantList AgentController::recentCheckpoints() const
{
    if (auto *checkpointTool = qobject_cast<CheckpointTool *>(m_registry ? m_registry->tool("checkpoint") : nullptr))
        return checkpointTool->recentCheckpoints();
    return {};
}

QVariantList AgentController::recentSessions() const
{
    QVariantList sessions;
    const QList<QVariantMap> items = TaskSessionStore::listSessions();
    for (const auto &item : items)
        sessions.append(item);
    return sessions;
}

QVariantList AgentController::knowledgeSources() const
{
    if (auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr))
        return knowledgeTool->sources();
    return {};
}

QVariantList AgentController::scheduledTasks() const
{
    if (auto *reminderTool = qobject_cast<ReminderTool *>(m_registry ? m_registry->tool("schedule") : nullptr))
        return reminderTool->reminders();
    return {};
}

QJsonObject AgentController::localGatewayState() const
{
    QJsonObject state;
    state.insert(QStringLiteral("busy"), m_busy);
    state.insert(QStringLiteral("workspacePath"), m_workspacePath);
    state.insert(QStringLiteral("currentProvider"), m_currentProvider);
    state.insert(QStringLiteral("currentModel"), m_currentModel);
    state.insert(QStringLiteral("currentFilePath"), m_currentFilePath);
    state.insert(QStringLiteral("sessionId"), m_sessionId);
    state.insert(QStringLiteral("threadId"), m_sessionId);
    state.insert(QStringLiteral("todoCount"), int(todoItems().size()));
    state.insert(QStringLiteral("scheduledTaskCount"), int(scheduledTasks().size()));
    state.insert(QStringLiteral("knowledgeSourceCount"), int(knowledgeSources().size()));
    state.insert(QStringLiteral("pendingReminderCount"), m_pendingReminderPrompts.size());
    state.insert(QStringLiteral("workspaceSummary"), workspaceSummary());
    return state;
}

void AgentController::startLocalGateway()
{
    if (!m_gatewayServer)
        m_gatewayServer = new LocalGatewayServer(this);

    quint16 preferredPort = 18081;
    bool ok = false;
    const int envPort = qEnvironmentVariableIntValue("NEURX_GATEWAY_PORT", &ok);
    if (ok && envPort > 0 && envPort <= std::numeric_limits<quint16>::max())
        preferredPort = quint16(envPort);

    if (!m_gatewayServer->start(preferredPort,
        [this](const QString &message) {
            QMetaObject::invokeMethod(this, [this, message]() {
                sendMessage(message);
            }, Qt::QueuedConnection);
        },
        [this]() { return localGatewayState(); })) {
        m_localGatewayUrl.clear();
        m_localGatewayPort = 0;
        emit localGatewayUrlChanged();
        qWarning().noquote() << "[gateway] failed to start local gateway server";
        return;
    }

    m_localGatewayPort = m_gatewayServer->port();
    m_localGatewayUrl = m_gatewayServer->baseUrl();
    emit localGatewayUrlChanged();
    qInfo().noquote() << "[gateway] listening on" << m_localGatewayUrl;
}

void AgentController::setupEngine()
{
    m_engine->setProvider(m_providers.value(m_currentProvider));
    m_engine->setToolRegistry(m_registry);
    m_engine->setApprovalManager(m_approvalManager);
    m_engine->setActiveModel(m_currentModel);
    m_engine->setAutoApproveTools(m_autoApproveTools);
    if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value("anthropic"))) {
        anthropic->setEndpointOverride(m_anthropicEndpoint);
        anthropic->setApiKey(m_anthropicApiKey);
    }
    if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value("openai"))) {
        openai->setEndpointOverride(m_openaiEndpoint);
        openai->setApiKey(m_openaiApiKey);
    }
    if (auto *gemini = qobject_cast<GeminiProvider *>(m_providers.value("gemini"))) {
        gemini->setApiKey(m_geminiApiKey);
    }
    refreshSystemPrompt();

    connect(m_engine, &AgentEngine::tokenReceived,
            this, &AgentController::onTokenReceived);
    connect(m_engine, &AgentEngine::messageAdded,
            this, &AgentController::onMessageAdded);
    connect(m_engine, &AgentEngine::toolExecuting,
            this, &AgentController::onToolExecuting);
    connect(m_engine, &AgentEngine::toolFinished,
            this, &AgentController::onToolFinished);
    connect(m_engine, &AgentEngine::toolOutputChunk,
            this, &AgentController::onToolOutputChunk);
    connect(m_engine, &AgentEngine::toolApprovalRequired,
            this, [this](const ToolCall &call, const QString &riskLevel) {
                qInfo().noquote() << "[agent] tool approval required:" << call.name
                                  << "callId=" << call.id
                                  << "risk=" << riskLevel;
                appendExecutionEvent(
                    QStringLiteral("approval"),
                    riskLevel == QStringLiteral("high")
                        ? QStringLiteral("Approval required")
                        : QStringLiteral("Approval requested"),
                    QStringLiteral("waiting"),
                    riskLevel + QStringLiteral(" risk · ") + toolEventPreview(call.name, call.arguments),
                    call.name,
                    call.id);
                saveTaskSession();
                emit toolApprovalRequired(call.id, call.name,
                    m_registry->tool(call.name)
                        ? m_registry->tool(call.name)->summary(call.arguments)
                        : call.name,
                    riskLevel);
            });
    connect(m_engine, &AgentEngine::turnComplete,
            this, [this]() {
                qInfo().noquote() << "[agent] turn complete";
                setBusy(false);
                processScheduledReminderQueue();
            });
    connect(m_engine, &AgentEngine::errorOccurred,
            this, [this](const QString &e) {
                qWarning().noquote() << "[agent] error:" << e;
                setBusy(false);
                emit errorOccurred(e);
            });
    connect(m_engine, &AgentEngine::statusChanged,
            this, [this](AgentEngine::AgentStatus s) {
                setBusy(s != AgentEngine::AgentStatus::Idle);
            });

    if (m_workspaceContext) {
        connect(m_workspaceContext, &WorkspaceContext::recentFilesChanged,
                this, &AgentController::refreshSystemPrompt);
        connect(m_workspaceContext, &WorkspaceContext::gitBranchChanged,
                this, &AgentController::refreshSystemPrompt);
    }
    if (m_workspaceIndex) {
        connect(m_workspaceIndex, &WorkspaceIndex::indexChanged,
                this, &AgentController::refreshSystemPrompt);
    }
    emit workspaceSummaryChanged();
}

void AgentController::restoreTaskSession()
{
    const TaskSessionSnapshot snapshot = TaskSessionStore::loadLatest();
    if (!snapshot.isValid())
        return;

    applyTaskSession(snapshot);
}

void AgentController::applyTaskSession(const TaskSessionSnapshot &snapshot)
{
    const QString oldThreadId = m_sessionId;
    m_sessionId = snapshot.effectiveThreadId();
    m_parentThreadId = snapshot.parentThreadId;
    m_threadCreatedAt = snapshot.updatedAt.isValid()
        ? snapshot.updatedAt.toUTC()
        : QDateTime::currentDateTimeUtc();
    m_executionTimeline = snapshot.executionTimeline;
    emit executionTimelineChanged();
    if (oldThreadId != m_sessionId)
        emit currentThreadIdChanged();
    m_documents.clear();
    m_currentEditorIndex = -1;
    m_currentFilePath.clear();
    m_currentFileContent.clear();
    emit openFilesChanged();
    emit currentEditorIndexChanged();
    emit currentFilePathChanged();
    emit currentFileContentChanged();

    if (!snapshot.currentProvider.isEmpty() && m_providers.contains(snapshot.currentProvider)) {
        m_currentProvider = snapshot.currentProvider;
        m_engine->setProvider(m_providers.value(m_currentProvider));
    }

    if (!snapshot.currentModel.isEmpty()) {
        m_currentModel = snapshot.currentModel;
        m_engine->setActiveModel(m_currentModel);
    }

    if (!snapshot.workspacePath.isEmpty())
        setWorkspacePath(snapshot.workspacePath);

    if (auto *todoTool = qobject_cast<TodoTool *>(m_registry ? m_registry->tool("todo") : nullptr))
        todoTool->setTodoItems(snapshot.todoItems);

    if (m_approvalManager && !snapshot.approvalProfile.isEmpty())
        m_approvalManager->setDefaultPolicy(approvalPolicyFromVariantMap(snapshot.approvalProfile));

    m_engine->setHistory(snapshot.messages);
    rebuildChatModelFromHistory();

    if (!snapshot.currentFilePath.isEmpty() && QFileInfo::exists(snapshot.currentFilePath))
        openEditorFile(snapshot.currentFilePath);

    clearPendingAttachments();
}

void AgentController::rebuildChatModelFromHistory()
{
    m_chatModel->clear();
    m_streamingText.clear();
    m_streamingAssistantActive = false;
    m_restoringSessionHistory = true;

    for (const auto &msg : m_engine->history()) {
        if (msg.role == MessageRole::Tool) {
            for (const auto &result : msg.toolResults)
                onToolFinished(result);
            continue;
        }
        onMessageAdded(msg);
    }

    m_restoringSessionHistory = false;
}

void AgentController::saveTaskSession()
{
    TaskSessionSnapshot snapshot;
    const QString threadId = m_sessionId.trimmed().isEmpty()
        ? TaskSessionStore::defaultSessionId()
        : m_sessionId;
    snapshot.threadId = threadId;
    snapshot.sessionId = threadId;
    snapshot.parentThreadId = m_parentThreadId;
    snapshot.workspacePath = m_workspacePath;
    snapshot.currentProvider = m_currentProvider;
    snapshot.currentModel = m_currentModel;
    snapshot.currentFilePath = m_currentFilePath;
    snapshot.todoItems = todoItems();
    snapshot.executionTimeline = m_executionTimeline;
    if (m_approvalManager)
        snapshot.approvalProfile = approvalPolicyToVariantMap(m_approvalManager->getDefaultPolicy());
    snapshot.messages = m_engine->history();
    snapshot.updatedAt = QDateTime::currentDateTimeUtc();
    TaskSessionStore::saveLatest(snapshot);
    syncThreadStore();
    emit recentSessionsChanged();
}

StoredThread AgentController::buildStoredThreadSnapshot() const
{
    StoredThread thread;
    const QString threadId = m_sessionId.trimmed().isEmpty()
        ? TaskSessionStore::defaultSessionId()
        : m_sessionId.trimmed();
    const ThreadId id = ThreadId::fromString(threadId);
    thread.id = id;
    thread.metadata.threadId = id;
    thread.metadata.parentThreadId = ThreadId::fromString(m_parentThreadId);
    thread.metadata.mode = m_parentThreadId.trimmed().isEmpty()
        ? ThreadInitializationMode::Fresh
        : ThreadInitializationMode::Forked;
    thread.metadata.createdAt = m_threadCreatedAt.isValid()
        ? m_threadCreatedAt
        : QDateTime::currentDateTimeUtc();
    thread.metadata.lastModified = QDateTime::currentDateTimeUtc();
    thread.metadata.customMetadata = QVariantMap{
        {QStringLiteral("workspacePath"), m_workspacePath},
        {QStringLiteral("currentProvider"), m_currentProvider},
        {QStringLiteral("currentModel"), m_currentModel},
        {QStringLiteral("currentFilePath"), m_currentFilePath},
        {QStringLiteral("todoCount"), int(todoItems().size())},
        {QStringLiteral("messageCount"), int(m_engine ? m_engine->history().size() : 0)},
        {QStringLiteral("eventCount"), int(m_executionTimeline.size())},
        {QStringLiteral("approvalProfile"), m_approvalManager
            ? approvalPolicyToVariantMap(m_approvalManager->getDefaultPolicy())
            : QVariantMap{}},
    };
    thread.lastState = QVariantMap{
        {QStringLiteral("workspacePath"), m_workspacePath},
        {QStringLiteral("currentProvider"), m_currentProvider},
        {QStringLiteral("currentModel"), m_currentModel},
        {QStringLiteral("currentFilePath"), m_currentFilePath},
        {QStringLiteral("parentThreadId"), m_parentThreadId},
        {QStringLiteral("todoItems"), todoItems()},
        {QStringLiteral("executionTimeline"), m_executionTimeline},
        {QStringLiteral("messages"), messagesToVariantList(m_engine ? m_engine->history() : QList<AgentMessage>{})},
        {QStringLiteral("pendingAttachments"), m_pendingAttachments},
        {QStringLiteral("localSkills"), m_localSkills},
        {QStringLiteral("knowledgeSearchQuery"), m_knowledgeSearchQuery},
        {QStringLiteral("knowledgeSearchResults"), m_knowledgeSearchResults},
        {QStringLiteral("scheduledTasks"), scheduledTasks()},
        {QStringLiteral("approvalProfile"), m_approvalManager
            ? approvalPolicyToVariantMap(m_approvalManager->getDefaultPolicy())
            : QVariantMap{}},
    };
    thread.isActive = true;
    thread.lastExecuted = QDateTime::currentDateTimeUtc();
    return thread;
}

void AgentController::syncThreadStore()
{
    if (!m_threadStore)
        return;

    const StoredThread thread = buildStoredThreadSnapshot();
    if (thread.id.isNull())
        return;

    m_threadStore->upsertThread(thread, [](ThreadStoreError result) {
        if (result != ThreadStoreError::Success)
            qWarning().noquote() << "[thread-store] upsert failed:" << int(result);
    });
}

QString AgentController::inferExecutionKind(const QString &toolName) const
{
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command"))
        return QStringLiteral("command_execution");
    if (toolName == QStringLiteral("patch"))
        return QStringLiteral("file_change");
    if (toolName == QStringLiteral("search"))
        return QStringLiteral("search");
    if (toolName == QStringLiteral("web_search") || toolName == QStringLiteral("web_fetch"))
        return QStringLiteral("web");
    if (toolName == QStringLiteral("todo"))
        return QStringLiteral("todo");
    if (toolName == QStringLiteral("github") || toolName == QStringLiteral("gitlab") || toolName == QStringLiteral("jira"))
        return QStringLiteral("web");
    if (toolName == QStringLiteral("knowledge"))
        return QStringLiteral("knowledge");
    if (toolName == QStringLiteral("session_search"))
        return QStringLiteral("memory");
    if (toolName == QStringLiteral("schedule"))
        return QStringLiteral("reminder");
    if (toolName == QStringLiteral("codex_agent"))
        return QStringLiteral("subagent");
    return QStringLiteral("tool");
}

void AgentController::appendExecutionEvent(const QString &kind,
                                          const QString &title,
                                          const QString &status,
                                          const QString &details,
                                          const QString &toolName,
                                          const QString &callId)
{
    if (m_restoringSessionHistory)
        return;

    QVariantMap event;
    event["id"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    event["kind"] = kind;
    event["title"] = title;
    event["status"] = status;
    event["details"] = details;
    event["toolName"] = toolName;
    event["callId"] = callId;
    event["timestamp"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    m_executionTimeline.append(event);
    const int kMaxEvents = 120;
    while (m_executionTimeline.size() > kMaxEvents)
        m_executionTimeline.removeFirst();
    emit executionTimelineChanged();
    if (!toolName.isEmpty())
        emit toolCatalogChanged();
}

void AgentController::unloadMcpTools()
{
    const QStringList names = m_mcpToolNames;
    for (const QString &name : names)
        unregisterToolAndDelete(m_registry, name);
    m_mcpToolNames.clear();
    emit mcpToolsChanged();
}

void AgentController::unloadReminderTool()
{
    unregisterToolAndDelete(m_registry, "schedule");
    emit scheduledTasksChanged();
}

void AgentController::processScheduledReminderQueue()
{
    if (m_pendingReminderPrompts.isEmpty())
        return;
    if (!m_engine || m_engine->status() != AgentEngine::AgentStatus::Idle)
        return;

    const QString prompt = m_pendingReminderPrompts.takeFirst();
    qInfo().noquote() << "[agent] reminder follow-up:" << logPreview(prompt);
    QMetaObject::invokeMethod(this, [this, prompt]() {
        sendMessage(prompt);
    }, Qt::QueuedConnection);
}

bool AgentController::resumeTaskSession(const QString &sessionId)
{
    const TaskSessionSnapshot snapshot = TaskSessionStore::loadById(sessionId);
    if (!snapshot.isValid()) {
        emit errorOccurred(QStringLiteral("Session not found."));
        return false;
    }

    applyTaskSession(snapshot);
    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();
    emit workspacePathChanged();
    emit workspaceSummaryChanged();
    emit recentSessionsChanged();
    return true;
}

bool AgentController::forkCurrentThread()
{
    if (!m_engine) {
        emit errorOccurred(QStringLiteral("Agent engine is not available."));
        return false;
    }

    const QString previousThreadId = m_sessionId.trimmed().isEmpty()
        ? TaskSessionStore::defaultSessionId()
        : m_sessionId.trimmed();
    const QString forkedThreadId = TaskSessionStore::defaultSessionId();
    const QDateTime forkedAt = QDateTime::currentDateTimeUtc();

    TaskSessionSnapshot snapshot;
    snapshot.threadId = forkedThreadId;
    snapshot.sessionId = forkedThreadId;
    snapshot.parentThreadId = previousThreadId;
    snapshot.workspacePath = m_workspacePath;
    snapshot.currentProvider = m_currentProvider;
    snapshot.currentModel = m_currentModel;
    snapshot.currentFilePath = m_currentFilePath;
    snapshot.todoItems = todoItems();
    snapshot.executionTimeline = m_executionTimeline;
    if (m_approvalManager)
        snapshot.approvalProfile = approvalPolicyToVariantMap(m_approvalManager->getDefaultPolicy());
    snapshot.messages = m_engine->history();
    snapshot.updatedAt = forkedAt;

    if (!TaskSessionStore::saveLatest(snapshot)) {
        emit errorOccurred(QStringLiteral("Failed to fork current thread."));
        return false;
    }

    const QString oldThreadId = m_sessionId;
    m_sessionId = forkedThreadId;
    m_parentThreadId = previousThreadId;
    m_threadCreatedAt = forkedAt;
    if (oldThreadId != m_sessionId)
        emit currentThreadIdChanged();
    clearPendingAttachments();

    if (auto *store = qobject_cast<SessionStore *>(m_registry ? m_registry->tool("session_search") : nullptr))
        store->beginSession(m_workspacePath);

    saveSettings();
    saveTaskSession();
    emit recentSessionsChanged();
    emit successOccurred(QStringLiteral("Forked thread %1 from %2.").arg(forkedThreadId, previousThreadId));
    return true;
}

void AgentController::appendSessionStoreMessage(const QString &role, const QString &content)
{
    if (m_restoringSessionHistory)
        return;
    if (content.trimmed().isEmpty())
        return;
    if (auto *store = qobject_cast<SessionStore *>(m_registry ? m_registry->tool("session_search") : nullptr))
        store->appendMessage(role, content);
}

void AgentController::refreshSystemPrompt()
{
    QString prompt = kControllerSystemPrompt.trimmed();
    const QString workspaceSummary = m_workspaceContext ? m_workspaceContext->buildContextSummary() : QString{};
    const QString indexSummary = m_workspaceIndex ? m_workspaceIndex->buildContextSummary() : QString{};

    if (!workspaceSummary.isEmpty()) {
        prompt += "\n\nWorkspace context:\n" + workspaceSummary;
    }
    if (!indexSummary.isEmpty()) {
        prompt += "\n\nWorkspace index:\n" + indexSummary;
    }
    if (auto *memoryTool = qobject_cast<MemoryTool *>(m_registry ? m_registry->tool("memory") : nullptr)) {
        const QString memorySnapshot = memoryTool->buildSnapshot().trimmed();
        if (!memorySnapshot.isEmpty())
            prompt += "\n\nPersistent memory:\n" + memorySnapshot;
    }

    if (m_skillManager) {
        const QString skillsContext = m_skillManager->getSkillsContextMarkdown(1, 20);
        if (!skillsContext.trimmed().isEmpty())
            prompt += "\n\n" + skillsContext;
    }
    const QVariantList currentTodos = todoItems();
    if (!currentTodos.isEmpty()) {
        QStringList todoLines;
        for (const QVariant &item : currentTodos) {
            const QVariantMap map = item.toMap();
            todoLines << QStringLiteral("- [%1] %2: %3")
                             .arg(map.value("status").toString(),
                                  map.value("id").toString(),
                                  map.value("content").toString());
        }
        prompt += "\n\nCurrent task plan:\n" + todoLines.join('\n');
    }

    if (!m_localSkills.isEmpty()) {
        QStringList skillLines;
        skillLines << QStringLiteral("Workspace-local instructions and skills:");
        for (const QVariant &item : m_localSkills) {
            const QVariantMap map = item.toMap();
            QString line = QStringLiteral("- [%1] %2").arg(map.value("kind").toString(), map.value("title").toString());
            const QString description = map.value("description").toString().trimmed();
            const QString path = map.value("path").toString().trimmed();
            if (!description.isEmpty())
                line += QStringLiteral(": %1").arg(description);
            if (!path.isEmpty())
                line += QStringLiteral(" (%1)").arg(path);
            skillLines << line;
        }
        prompt += "\n\n" + skillLines.join('\n');
    }

    m_engine->setSystemPrompt(prompt);
    emit workspaceSummaryChanged();
}

void AgentController::refreshWorkspaceSkills()
{
    if (m_skillManager) {
        const QString error = m_skillManager->initialize(m_workspacePath);
        if (!error.isEmpty())
            qWarning().noquote() << "[skills] discovery error:" << error;
    }
    const QVariantList skills = discoverWorkspaceSkillEntries(m_workspacePath);
    if (skills == m_localSkills)
        return;
    m_localSkills = skills;
    emit localSkillsChanged();
    refreshSystemPrompt();
}

void AgentController::discoverCustomTools(const QString &workspacePath)
{
    if (workspacePath.isEmpty()) return;

    const QString toolsDir = QDir(workspacePath).filePath(".neurx/tools");
    if (!QFileInfo::exists(toolsDir)) return;

    QDirIterator it(toolsDir, QStringList{"*.json"}, QDir::Files);
    while (it.hasNext()) {
        const QString path = it.next();
        QFile f(path);
        if (f.open(QIODevice::ReadOnly)) {
            const QJsonObject obj = QJsonDocument::fromJson(f.readAll()).object();
            const QString name = obj["name"].toString();
            const QString desc = obj["description"].toString();
            const QString script = QFileInfo(path).dir().filePath(obj["script"].toString());
            const QJsonObject schema = obj["parameters"].toObject();

            if (!name.isEmpty() && !script.isEmpty()) {
                m_registry->registerTool(new CustomScriptTool(name, desc, script, schema, this));
                qInfo().noquote() << "[discovery] discovered custom tool:" << name;
            }
        }
    }
}

void AgentController::configurePolicyManagers()
{
    if (m_approvalManager) {
        ApprovalPolicy policy;
        policy.defaultPolicy = AskForApproval::OnRequest;
        policy.defaultReviewer = ApprovalsReviewer::User;
        policy.readOnlyMode = false;
        policy.doubleConfirmPatterns = {
            QStringLiteral(R"(\brm\b.*\s-rf\b)"),
            QStringLiteral(R"(\bgit\b.*\breset\b.*\b--hard\b)"),
            QStringLiteral(R"(\bgit\b.*\bclean\b.*\b-f\b)"),
            QStringLiteral(R"(\bchmod\b.*\b-R\b.*\b777\b)"),
            QStringLiteral(R"(\bchown\b.*\b-R\b)"),
            QStringLiteral(R"(\bdd\b.*\bof=/dev/\w+\b)"),
            QStringLiteral(R"(\bmkfs\w*\b)"),
        };
        m_approvalManager->setDefaultPolicy(policy);

        const QStringList protectedPatterns = {
            QStringLiteral(".git"),
            QStringLiteral(".agents"),
            QStringLiteral(".codex"),
            QStringLiteral(".env"),
        };
        for (const QString &pattern : protectedPatterns) {
            GranularApprovalConfig fileRule;
            fileRule.resourcePattern = pattern;
            fileRule.approval = AskForApproval::OnRequest;
            fileRule.action = QStringLiteral("prompt");
            fileRule.toolNames = {QStringLiteral("file_system"), QStringLiteral("patch"), QStringLiteral("run_command")};
            fileRule.permanent = true;
            m_approvalManager->addGranularRule(fileRule);
        }

        connect(m_approvalManager, &ApprovalManager::policyChanged,
                this, [this]() {
                    emit toolCatalogChanged();
                });
    }
}

QStringList AgentController::providers() const { return m_providers.keys(); }

QStringList AgentController::models() const
{
    auto *p = m_providers.value(m_currentProvider);
    return p ? p->availableModels() : QStringList{};
}

QString AgentController::workspaceSummary() const
{
    if (!m_workspaceContext || !m_workspaceIndex) return {};

    QString summary = m_workspaceContext->buildContextSummary();
    const QString indexSummary = m_workspaceIndex->buildContextSummary();
    if (!indexSummary.isEmpty()) {
        if (!summary.isEmpty())
            summary += "\n";
        summary += indexSummary;
    }
    return summary;
}

int AgentController::workspaceFileCount() const
{
    return m_workspaceIndex ? m_workspaceIndex->fileCount() : 0;
}

QStringList AgentController::workspaceTopExtensions() const
{
    return m_workspaceIndex ? m_workspaceIndex->topExtensions() : QStringList{};
}

QStringList AgentController::workspaceRecentFiles() const
{
    return m_workspaceContext ? m_workspaceContext->recentFiles() : QStringList{};
}

QStringList AgentController::searchWorkspacePaths(const QString &needle) const
{
    return m_workspaceIndex ? m_workspaceIndex->searchPaths(needle) : QStringList{};
}

QVariantList AgentController::checkpointPreview(const QString &checkpointId) const
{
    auto *checkpointTool = qobject_cast<CheckpointTool *>(m_registry ? m_registry->tool("checkpoint") : nullptr);
    if (!checkpointTool)
        return {};

    const QString normalizedId = checkpointId.trimmed();
    if (normalizedId.isEmpty())
        return {};

    QString error;
    const QVariantList files = checkpointTool->filesForCheckpoint(normalizedId, &error);
    if (!error.isEmpty())
        qWarning().noquote() << "[checkpoint] preview failed:" << error;
    return files;
}

bool AgentController::currentFileDirty() const
{
    if (m_currentEditorIndex < 0 || m_currentEditorIndex >= m_documents.size())
        return false;
    return m_documents.at(m_currentEditorIndex).dirty;
}

void AgentController::setAnthropicEndpoint(const QString &url)
{
    const QString normalized = url.trimmed().isEmpty()
        ? QStringLiteral("https://api.anthropic.com/v1/messages")
        : url.trimmed();
    if (m_anthropicEndpoint == normalized) return;
    m_anthropicEndpoint = normalized;
    if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value("anthropic"))) {
        anthropic->setEndpointOverride(m_anthropicEndpoint);
    }
    saveSettings();
    emit anthropicEndpointChanged();
}

void AgentController::setOpenaiEndpoint(const QString &url)
{
    const QString fallback = QString::fromUtf8(kSiliconFlowOpenAIEndpoint);
    const QString normalized = normalizeOpenAICompatEndpoint(url.trimmed().isEmpty() ? fallback : url);
    if (m_openaiEndpoint == normalized) return;
    m_openaiEndpoint = normalized;
    m_openaiEndpointFromRuntime = false;
    saveSettings();
    if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value("openai"))) {
        openai->setEndpointOverride(m_openaiEndpoint);
    }
    emit openaiEndpointChanged();
}

void AgentController::setAnthropicApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_anthropicApiKey == normalized) return;
    m_anthropicApiKey = normalized;
    if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value("anthropic"))) {
        anthropic->setApiKey(m_anthropicApiKey);
    }
    saveSettings();
    emit anthropicApiKeyChanged();
}

void AgentController::setOpenaiApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_openaiApiKey == normalized) return;
    m_openaiApiKey = normalized;
    m_openaiApiKeyFromRuntime = false;
    if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value("openai"))) {
        openai->setApiKey(m_openaiApiKey);
    }
    saveSettings();
    emit openaiApiKeyChanged();
}

void AgentController::setGeminiApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_geminiApiKey == normalized) return;
    m_geminiApiKey = normalized;
    if (auto *gemini = qobject_cast<GeminiProvider *>(m_providers.value("gemini"))) {
        gemini->setApiKey(m_geminiApiKey);
    }
    saveSettings();
    emit geminiApiKeyChanged();
}

void AgentController::setBraveApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_braveApiKey == normalized) return;
    m_braveApiKey = normalized;
    saveSettings();
    emit braveApiKeyChanged();
}

void AgentController::setCurrentFileContent(const QString &text)
{
    if (m_currentEditorIndex < 0 || m_currentEditorIndex >= m_documents.size()) {
        if (m_currentFileContent == text) return;
        m_currentFileContent = text;
        emit currentFileContentChanged();
        return;
    }

    auto &doc = m_documents[m_currentEditorIndex];
    if (doc.content == text) return;
    doc.content = text;
    doc.dirty = (doc.content != doc.savedContent);
    m_currentFileContent = text;
    emit openFilesChanged();
    emit currentFileContentChanged();
}

void AgentController::setCurrentEditorIndex(int index)
{
    if (index < 0 || index >= m_documents.size() || m_currentEditorIndex == index)
        return;

    m_currentEditorIndex = index;
    const auto &doc = m_documents.at(m_currentEditorIndex);
    qInfo().noquote() << QStringLiteral("[AgentController] setCurrentEditorIndex -> index=%1 path=%2").arg(index).arg(doc.path);
    const QString oldPath = m_currentFilePath;
    const QString oldContent = m_currentFileContent;
    m_currentFilePath = doc.path;
    m_currentFileContent = doc.content;

    if (oldPath != m_currentFilePath)
        emit currentFilePathChanged();
    if (oldContent != m_currentFileContent)
        emit currentFileContentChanged();
    emit currentEditorIndexChanged();
    emit openFilesChanged();
    saveSettings();
    refreshSystemPrompt();
}

void AgentController::copyPathToClipboard(const QString &path)
{
    const QString normalized = path.trimmed();
    if (normalized.isEmpty())
        return;
    if (auto *clipboard = QGuiApplication::clipboard())
        clipboard->setText(normalized);
}

void AgentController::setCurrentProvider(const QString &id)
{
    if (!m_providers.contains(id) || m_currentProvider == id) return;
    m_currentProvider = id;
    m_engine->setProvider(m_providers.value(id));
    if (id == "anthropic") {
        if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value(id))) {
            anthropic->setEndpointOverride(m_anthropicEndpoint);
            anthropic->setApiKey(m_anthropicApiKey);
        }
    }
    if (id == "openai") {
        if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value(id))) {
            openai->setEndpointOverride(m_openaiEndpoint);
            openai->setApiKey(m_openaiApiKey);
        }
    }
    m_currentModel = models().value(0);
    m_engine->setActiveModel(m_currentModel);
    saveSettings();
    emit currentProviderChanged();
    emit currentModelChanged();
}

void AgentController::setCurrentModel(const QString &model)
{
    if (m_currentModel == model) return;
    m_currentModel = model;
    m_engine->setActiveModel(model);
    saveSettings();
    emit currentModelChanged();
}

void AgentController::setWorkspacePath(const QString &path)
{
    if (m_workspacePath == path) return;
    m_pendingToolExecutions.clear();
    unloadMcpTools();
    m_workspacePath = path;
    if (m_workspaceContext) m_workspaceContext->setRootPath(path);
    if (m_workspaceIndex)   m_workspaceIndex->setRootPath(path);
    if (m_sandboxManager) {
        m_sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
        m_sandboxManager->setReadOnlyMode(false);
        m_sandboxManager->clearPaths();
        m_sandboxManager->addAllowedReadPath(path);
        m_sandboxManager->addAllowedWritePath(path);
    }

    // Re-instantiate file-system tools with the new root.
    unregisterToolAndDelete(m_registry, "file_system");
    unregisterToolAndDelete(m_registry, "patch");
    unregisterToolAndDelete(m_registry, "run_command");
    unregisterToolAndDelete(m_registry, "run_docker_command");
    unregisterToolAndDelete(m_registry, "search");
    unregisterToolAndDelete(m_registry, "web_search");
    unregisterToolAndDelete(m_registry, "web_fetch");
    unregisterToolAndDelete(m_registry, "codex_agent");
    unregisterToolAndDelete(m_registry, "checkpoint");
    unregisterToolAndDelete(m_registry, "memory");
    unregisterToolAndDelete(m_registry, "session_search");
    unregisterToolAndDelete(m_registry, "todo");
    unregisterToolAndDelete(m_registry, "knowledge");
    unregisterToolAndDelete(m_registry, "github");
    unregisterToolAndDelete(m_registry, "gitlab");
    unregisterToolAndDelete(m_registry, "jira");
    unloadReminderTool();

    m_registry->registerTool(new FileSystemTool(path, m_registry));
    m_registry->registerTool(new PatchTool(path, m_registry));
    m_registry->registerTool(new ShellTool(path, m_registry));
    m_registry->registerTool(new DockerShellTool(path, m_registry));
    m_registry->registerTool(new SearchTool(path, m_registry));
    m_registry->registerTool(new WebSearchTool(m_registry));
    m_registry->registerTool(new GeminiGroundingTool(m_registry));
    m_registry->registerTool(new WebFetchTool(m_registry));
    m_registry->registerTool(new CodexTool(path, m_registry));
    m_registry->registerTool(new DelegationTool(m_registry, m_providers.value(m_currentProvider), m_currentModel, m_registry));
    auto *checkpointTool = new CheckpointTool(path, m_registry);
    connect(checkpointTool, &CheckpointTool::checkpointRolledBack,
            this, [this]() {
                if (m_workspaceIndex)
                    m_workspaceIndex->refresh();
                if (!m_currentFilePath.isEmpty() && QFileInfo::exists(m_currentFilePath))
                    openEditorFile(m_currentFilePath);
                refreshSystemPrompt();
                emit recentCheckpointsChanged();
    });
    m_registry->registerTool(checkpointTool);
    m_registry->registerTool(new MemoryTool(path, m_registry));
    m_registry->registerTool(new GitHubTool(m_registry));
    m_registry->registerTool(new GitLabTool(m_registry));
    m_registry->registerTool(new JiraTool(m_registry));
    m_registry->registerTool(new SkillTool(m_skillManager, m_registry));
    auto *knowledgeTool = new KnowledgeTool(m_registry);
    knowledgeTool->setDbPath(QDir(path).filePath(QStringLiteral(".neurx/knowledge.db")));
    m_registry->registerTool(knowledgeTool);
    auto *reminderTool = new ReminderTool(path, m_registry);
    connect(reminderTool, &ReminderTool::reminderTriggered,
            this, [this](const QVariantMap &reminder) {
                const QString summary = reminderSummary(reminder);
                const QString prompt = QStringLiteral(
                    "Scheduled reminder triggered: %1. Acknowledge it and take the next relevant action.")
                    .arg(summary);
                ChatMessage msg;
                msg.role = QStringLiteral("tool");
                msg.content = QStringLiteral("schedule: due %1").arg(summary);
                m_chatModel->append(msg);
                appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
                saveTaskSession();
                emit successOccurred(QStringLiteral("Reminder due: %1").arg(summary));
                if (m_engine && m_engine->status() == AgentEngine::AgentStatus::Idle) {
                    QMetaObject::invokeMethod(this, [this, prompt]() {
                        sendMessage(prompt);
                    }, Qt::QueuedConnection);
                } else {
                    m_pendingReminderPrompts.append(prompt);
                }
            });
    connect(reminderTool, &ReminderTool::remindersChanged,
            this, &AgentController::scheduledTasksChanged);
    m_registry->registerTool(reminderTool);
    auto *sessionStore = new SessionStore(m_registry);
    sessionStore->beginSession(path);
    m_registry->registerTool(sessionStore);
    auto *todoTool = new TodoTool(m_registry);
    connect(todoTool, &TodoTool::todoItemsChanged,
            this, &AgentController::todoItemsChanged);
    connect(todoTool, &TodoTool::todoItemsChanged,
            this, [this]() {
                saveTaskSession();
                refreshSystemPrompt();
    });
    m_registry->registerTool(todoTool);

    if (auto *fileTool = qobject_cast<FileSystemTool *>(m_registry->tool("file_system")))
        fileTool->setSandboxManager(m_sandboxManager);
    if (auto *patchTool = qobject_cast<PatchTool *>(m_registry->tool("patch")))
        patchTool->setSandboxManager(m_sandboxManager);
    if (auto *shellTool = qobject_cast<ShellTool *>(m_registry->tool("run_command")))
        shellTool->setSandboxManager(m_sandboxManager);

    const QList<BaseTool *> mcpTools = McpServerLoader::loadFromConfig(path, m_registry);
    for (BaseTool *tool : mcpTools) {
        if (!tool)
            continue;
        if (m_registry->tool(tool->name())) {
            qWarning().noquote() << "[MCP] Skipping duplicate tool name:" << tool->name();
            tool->deleteLater();
            continue;
        }
        m_registry->registerTool(tool);
        m_mcpToolNames.append(tool->name());
    }
    emit mcpToolsChanged();
    emit toolCatalogChanged();

    if (!m_currentFilePath.isEmpty() && QFileInfo::exists(m_currentFilePath)) {
        openEditorFile(m_currentFilePath);
    }

    refreshWorkspaceSkills();
    discoverCustomTools(path);
    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();

    emit workspacePathChanged();
    emit workspaceSummaryChanged();
    emit recentCheckpointsChanged();
    emit knowledgeSourcesChanged();
}

bool AgentController::indexWorkspaceKnowledge()
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }
    if (m_workspacePath.isEmpty()) {
        emit errorOccurred(QStringLiteral("Open a workspace first."));
        return false;
    }

    const ToolResult result = knowledgeTool->execute(
        QStringLiteral("ui-knowledge-index"),
        QJsonObject{
            {"action", "index_directory"},
            {"path", m_workspacePath},
            {"extensions", QJsonArray::fromStringList(defaultKnowledgeExtensions())},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge: %1").arg(result.content);
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();
    m_knowledgeSearchQuery.clear();
    m_knowledgeSearchResults.clear();
    emit knowledgeSearchResultsChanged();
    emit knowledgeSourcesChanged();
    emit successOccurred(result.content);
    return true;
}

bool AgentController::indexCurrentFileKnowledge()
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }

    if (m_currentFilePath.isEmpty() || !QFileInfo::exists(m_currentFilePath)) {
        emit errorOccurred(QStringLiteral("Open a file first."));
        return false;
    }

    const ToolResult result = knowledgeTool->execute(
        QStringLiteral("ui-knowledge-index-file"),
        QJsonObject{
            {"action", "index_file"},
            {"path", m_currentFilePath},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge: %1").arg(result.content);
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();
    m_knowledgeSearchQuery.clear();
    m_knowledgeSearchResults.clear();
    emit knowledgeSearchResultsChanged();
    emit knowledgeSourcesChanged();
    emit successOccurred(result.content);
    return true;
}

bool AgentController::indexRecentFilesKnowledge()
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }

    const QStringList recentFiles = m_workspaceContext ? m_workspaceContext->recentFiles() : QStringList{};
    if (recentFiles.isEmpty()) {
        emit errorOccurred(QStringLiteral("No recent files to index."));
        return false;
    }

    int indexedCount = 0;
    QStringList indexedPaths;
    QStringList skippedPaths;
    for (const QString &path : recentFiles.mid(0, 8)) {
        if (path.trimmed().isEmpty() || !QFileInfo::exists(path)) {
            skippedPaths << path;
            continue;
        }

        const ToolResult result = knowledgeTool->execute(
            QStringLiteral("ui-knowledge-index-file"),
            QJsonObject{
                {"action", "index_file"},
                {"path", path},
            });
        if (result.isError) {
            skippedPaths << path;
            continue;
        }
        ++indexedCount;
        indexedPaths << path;
    }

    emit knowledgeSourcesChanged();

    if (indexedCount == 0) {
        emit errorOccurred(QStringLiteral("No recent files could be indexed."));
        return false;
    }

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge: indexed %1 recent file%2.")
                      .arg(indexedCount)
                      .arg(indexedCount == 1 ? "" : "s");
    if (!indexedPaths.isEmpty())
        msg.content += QStringLiteral(" %1").arg(indexedPaths.join(QStringLiteral(", ")));
    if (!skippedPaths.isEmpty())
        msg.content += QStringLiteral(" Skipped %1 path%2.")
                           .arg(skippedPaths.size())
                           .arg(skippedPaths.size() == 1 ? "" : "s");
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();
    m_knowledgeSearchQuery.clear();
    m_knowledgeSearchResults.clear();
    emit knowledgeSearchResultsChanged();
    emit successOccurred(QStringLiteral("Indexed %1 recent file%2.")
                            .arg(indexedCount)
                            .arg(indexedCount == 1 ? "" : "s"));
    return true;
}

QString AgentController::searchWorkspaceKnowledge(const QString &query)
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        const QString error = QStringLiteral("Knowledge tool is not available.");
        emit errorOccurred(error);
        return error;
    }

    const QString normalized = query.trimmed();
    if (normalized.isEmpty()) {
        const QString error = QStringLiteral("Search query cannot be empty.");
        emit errorOccurred(error);
        return error;
    }

    QString error;
    const QVariantList hits = knowledgeTool->searchEntries(normalized, 5, &error);
    const ToolResult result = error.isEmpty()
        ? ToolResult{
            QStringLiteral("ui-knowledge-search"),
            knowledgeTool->name(),
            false,
            summarizeKnowledgeHits(hits, normalized),
        }
        : ToolResult{
            QStringLiteral("ui-knowledge-search"),
            knowledgeTool->name(),
            true,
            error,
        };

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge search: %1").arg(result.content);
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();

    if (result.isError) {
        m_knowledgeSearchQuery = normalized;
        m_knowledgeSearchResults.clear();
        emit knowledgeSearchResultsChanged();
        emit errorOccurred(result.content);
        return result.content;
    }

    m_knowledgeSearchQuery = normalized;
    m_knowledgeSearchResults = hits;
    emit knowledgeSearchResultsChanged();
    emit knowledgeSourcesChanged();
    emit successOccurred(QStringLiteral("Knowledge search completed."));
    return result.content;
}

bool AgentController::removeKnowledgeSource(const QString &path)
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }

    QString error;
    if (!knowledgeTool->removeSourcePath(path, &error)) {
        emit errorOccurred(error.isEmpty() ? QStringLiteral("Failed to remove knowledge source.") : error);
        return false;
    }

    emit knowledgeSourcesChanged();
    emit successOccurred(QStringLiteral("Removed knowledge source."));
    return true;
}

bool AgentController::createReminder(const QString &title, int dueInMinutes, int repeatMinutes)
{
    auto *reminderTool = qobject_cast<ReminderTool *>(m_registry ? m_registry->tool("schedule") : nullptr);
    if (!reminderTool) {
        emit errorOccurred(QStringLiteral("Schedule tool is not available."));
        return false;
    }

    if (title.trimmed().isEmpty()) {
        emit errorOccurred(QStringLiteral("Title cannot be empty."));
        return false;
    }
    if (dueInMinutes < 0 || repeatMinutes < 0) {
        emit errorOccurred(QStringLiteral("Time values must be zero or greater."));
        return false;
    }

    const ToolResult result = reminderTool->execute(
        QStringLiteral("ui-schedule-create"),
        QJsonObject{
            {"action", "create"},
            {"title", title.trimmed()},
            {"due_in_minutes", dueInMinutes},
            {"repeat_minutes", repeatMinutes},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    emit scheduledTasksChanged();
    emit successOccurred(result.content);
    return true;
}

bool AgentController::cancelReminder(const QString &id)
{
    auto *reminderTool = qobject_cast<ReminderTool *>(m_registry ? m_registry->tool("schedule") : nullptr);
    if (!reminderTool) {
        emit errorOccurred(QStringLiteral("Schedule tool is not available."));
        return false;
    }

    const ToolResult result = reminderTool->execute(
        QStringLiteral("ui-schedule-cancel"),
        QJsonObject{
            {"action", "cancel"},
            {"id", id.trimmed()},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    emit scheduledTasksChanged();
    emit successOccurred(result.content);
    return true;
}

QStringList AgentController::parseSlashListItems(const QString &text) const
{
    QStringList items;
    QString normalized = text;
    normalized.replace("\r\n", "\n");
    normalized = normalized.trimmed();
    if (normalized.isEmpty())
        return items;

    const QStringList chunks = normalized.split('\n', Qt::SkipEmptyParts);
    for (QString chunk : chunks) {
        const QStringList fragments = chunk.split(';', Qt::SkipEmptyParts);
        for (QString fragment : fragments) {
            QString item = fragment.trimmed();
            if (item.isEmpty())
                continue;

            while (!item.isEmpty() && (item.startsWith('-') || item.startsWith('*') || item.startsWith(QStringLiteral("•"))))
                item = item.mid(1).trimmed();

            int i = 0;
            while (i < item.size() && item.at(i).isDigit())
                ++i;
            if (i > 0 && i < item.size() && (item.at(i) == '.' || item.at(i) == ')' || item.at(i) == ':'))
                item = item.mid(i + 1).trimmed();

            if (!item.isEmpty())
                items.append(item);
        }
    }
    return items;
}

QVariantList AgentController::buildPlanItems(const QStringList &items) const
{
    QVariantList todos;
    for (int i = 0; i < items.size(); ++i) {
        QVariantMap todo;
        todo["id"] = QStringLiteral("plan-%1").arg(i + 1);
        todo["content"] = items.at(i);
        todo["status"] = i == 0 ? QStringLiteral("in_progress") : QStringLiteral("pending");
        todos.append(todo);
    }
    return todos;
}

QString AgentController::buildSlashHelp() const
{
    return QStringLiteral(
        "Available commands:\n"
        "/help - show this command list\n"
        "/plan <items> - replace the current task plan with a list of items\n"
        "/skills [query] - list Claude-style skills or inspect one\n"
        "/review [topic] - ask for a code review focused on the current workspace\n"
        "/analyze - analyze the current file with CodeMagic\n"
        "/explain - explain the current file with CodeMagic\n"
        "/search <query> - search local workspace knowledge and paths\n"
        "/checkpoint [id] - open the checkpoint restore dialog or rollback by id\n"
        "/delegate <task> - ask the agent to delegate a subtask with codex_agent");
}

QVariantMap AgentController::analyzeCurrentFileWithCodeMagic()
{
    QVariantMap result;
    if (!m_codeMagic) {
        result.insert(QStringLiteral("error"), QStringLiteral("CodeMagic is not available."));
        return result;
    }
    const CodeMagicInput input = resolveCodeMagicInput();
    if (input.path.isEmpty() || input.code.trimmed().isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Open a file first."));
        return result;
    }

    CodeAnalysisResult analysis = m_codeMagic->analyzeCode(input.code, input.language);
    if (analysis.filename.isEmpty())
        analysis.filename = input.path;

    result = analysisToVariantMap(analysis);
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("kind"), QStringLiteral("analysis"));
    result.insert(QStringLiteral("targetLabel"), input.targetLabel);
    updateCodeMagicResult(result, input.targetLabel);
    appendExecutionEvent(
        QStringLiteral("code_magic_analysis"),
        QStringLiteral("Code analysis completed"),
        QStringLiteral("done"),
        QStringLiteral("%1 issue(s), quality %2")
            .arg(analysis.issues.size())
            .arg(QString::number(analysis.quality, 'f', 1)),
        QStringLiteral("code_magic"),
        analysis.analysisId);
    saveTaskSession();
    emit successOccurred(QStringLiteral("Code analysis completed for %1.").arg(input.targetLabel));
    return result;
}

QVariantMap AgentController::reviewCurrentFileWithCodeMagic()
{
    QVariantMap result;
    if (!m_codeMagic) {
        result.insert(QStringLiteral("error"), QStringLiteral("CodeMagic is not available."));
        return result;
    }
    const CodeMagicInput input = resolveCodeMagicInput();
    if (input.path.isEmpty() || input.code.trimmed().isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Open a file first."));
        return result;
    }

    const CodeReview review = m_codeMagic->reviewCode(input.code,
                                                      input.targetLabel,
                                                      QStringLiteral("NeurX"));
    result = reviewToVariantMap(review);
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("kind"), QStringLiteral("review"));
    result.insert(QStringLiteral("targetLabel"), input.targetLabel);
    updateCodeMagicResult(result, input.targetLabel);
    appendExecutionEvent(
        QStringLiteral("code_magic_review"),
        QStringLiteral("Code review completed"),
        QStringLiteral("done"),
        QStringLiteral("score %1, %2 issue(s)")
            .arg(QString::number(review.overallScore, 'f', 1))
            .arg(review.issues.size()),
        QStringLiteral("code_magic"),
        review.reviewId);
    saveTaskSession();
    emit successOccurred(QStringLiteral("Code review completed for %1.").arg(input.targetLabel));
    return result;
}

QVariantMap AgentController::explainCurrentFileWithCodeMagic()
{
    QVariantMap result;
    if (!m_codeMagic) {
        result.insert(QStringLiteral("error"), QStringLiteral("CodeMagic is not available."));
        return result;
    }
    const CodeMagicInput input = resolveCodeMagicInput();
    if (input.path.isEmpty() || input.code.trimmed().isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Open a file first."));
        return result;
    }

    const CodeExplanation explanation = m_codeMagic->explainCode(
        input.code,
        input.language);
    result = explanationToVariantMap(explanation);
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("kind"), QStringLiteral("explanation"));
    result.insert(QStringLiteral("targetLabel"), input.targetLabel);
    updateCodeMagicResult(result, input.targetLabel);
    appendExecutionEvent(
        QStringLiteral("code_magic_explain"),
        QStringLiteral("Code explanation completed"),
        QStringLiteral("done"),
        logPreview(explanation.summary.isEmpty() ? explanation.detailedExplanation : explanation.summary),
        QStringLiteral("code_magic"),
        explanation.explanationId);
    saveTaskSession();
    emit successOccurred(QStringLiteral("Code explanation completed for %1.").arg(input.targetLabel));
    return result;
}

QString AgentController::buildReviewPrompt(const QString &topic) const
{
    const QString focus = topic.trimmed();
    QString prompt = QStringLiteral(
        "Perform a focused code review of the current workspace.\n"
        "Find bugs, regressions, missing tests, and risky assumptions.\n"
        "Return findings first, ordered by severity, with file and line references when possible.\n"
        "If no issues are found, say so and mention any residual risk or testing gaps.");
    if (!focus.isEmpty())
        prompt += QStringLiteral("\nFocus on: %1").arg(focus);
    return prompt;
}

bool AgentController::handleSlashCommand(const QString &text)
{
    const QString trimmed = text.trimmed();
    if (!trimmed.startsWith('/'))
        return false;

    const QString body = trimmed.mid(1).trimmed();
    if (body.isEmpty()) {
        emit successOccurred(buildSlashHelp());
        return true;
    }

    const int splitAt = body.indexOf(' ');
    const QString command = (splitAt < 0 ? body : body.left(splitAt)).toLower();
    const QString args = splitAt < 0 ? QString{} : body.mid(splitAt + 1).trimmed();

    if (command == QStringLiteral("help") || command == QStringLiteral("commands") || command == QStringLiteral("?")) {
        emit successOccurred(buildSlashHelp());
        return true;
    }

    if (command == QStringLiteral("plan")) {
        if (args.isEmpty()) {
            submitToAgent(QStringLiteral(
                "Create a concise implementation plan for the current task. "
                "Use the todo tool to keep the plan current, and keep the plan short and actionable."));
            return true;
        }

        const QStringList items = parseSlashListItems(args);
        if (items.isEmpty()) {
            emit errorOccurred(QStringLiteral("Could not parse any plan items. Use new lines or semicolons between steps."));
            return true;
        }

        auto *todoTool = qobject_cast<TodoTool *>(m_registry ? m_registry->tool("todo") : nullptr);
        if (!todoTool) {
            emit errorOccurred(QStringLiteral("Todo tool is not available."));
            return true;
        }

        const QVariantList todos = buildPlanItems(items);
        todoTool->setTodoItems(todos);
        saveTaskSession();
        emit successOccurred(QStringLiteral("Plan updated with %1 item%2.").arg(todos.size()).arg(todos.size() == 1 ? "" : "s"));
        return true;
    }

    if (command == QStringLiteral("skills")) {
        if (!m_skillManager) {
            emit errorOccurred(QStringLiteral("Skills manager is not available."));
            return true;
        }

        const QString needle = args.trimmed();
        if (needle.isEmpty()) {
            QStringList lines;
            const QString skillsContext = m_skillManager->getSkillsContextMarkdown(1, 50);
            const QStringList contextLines = skillsContext.split('\n');
            for (const QString &line : contextLines) {
                const QString trimmedLine = line.trimmed();
                if (trimmedLine.startsWith(QStringLiteral("- **")) || trimmedLine.startsWith(QStringLiteral("- ")))
                    lines.append(trimmedLine);
            }
            if (lines.isEmpty()) {
                emit successOccurred(QStringLiteral("No Claude-style skills were discovered."));
            } else {
                emit successOccurred(QStringLiteral("Discovered skills:\n%1").arg(lines.join(QStringLiteral("\n"))));
            }
            return true;
        }

        const QVector<ClaudeSkill> allSkills = m_skillManager->getAllSkills();
        for (const auto &skill : allSkills) {
            const QString haystack = skill.metadata.skillId + QStringLiteral(" ")
                + skill.metadata.name + QStringLiteral(" ")
                + skill.metadata.description;
            if (!haystack.contains(needle, Qt::CaseInsensitive))
                continue;

            QString details = QStringLiteral("Skill: %1\nDescription: %2\nSource: %3\n")
                .arg(skill.metadata.name,
                     skill.metadata.description,
                     skill.filePath);

            if (!skill.metadata.tags.isEmpty())
                details += QStringLiteral("Tags: %1\n").arg(skill.metadata.tags.join(QStringLiteral(", ")));
            if (!skill.requiredEnvironmentVariables.isEmpty()) {
                QStringList envLines;
                for (const auto &env : skill.requiredEnvironmentVariables) {
                    envLines << QStringLiteral("- %1%2")
                                    .arg(env.name,
                                         env.required ? QStringLiteral(" (required)") : QString());
                }
                details += QStringLiteral("Environment:\n%1\n").arg(envLines.join(QStringLiteral("\n")));
            }
            if (!skill.markdownContent.trimmed().isEmpty()) {
                details += QStringLiteral("\nInstructions:\n%1")
                    .arg(skill.markdownContent.left(2400));
            }

            emit successOccurred(details);
            return true;
        }

        emit errorOccurred(QStringLiteral("No skill matched '%1'.").arg(needle));
        return true;
    }

    if (command == QStringLiteral("review")) {
        if (args.isEmpty() && !m_currentFilePath.isEmpty() && !m_currentFileContent.trimmed().isEmpty()) {
            const QVariantMap review = reviewCurrentFileWithCodeMagic();
            if (review.contains(QStringLiteral("error"))) {
                emit errorOccurred(review.value(QStringLiteral("error")).toString());
            } else {
                emit successOccurred(QStringLiteral("Code review score %1 with %2 issue(s).")
                                         .arg(review.value(QStringLiteral("overallScore")).toFloat(), 0, 'f', 1)
                                         .arg(review.value(QStringLiteral("issues")).toList().size()));
            }
            return true;
        }
        submitToAgent(buildReviewPrompt(args));
        return true;
    }

    if (command == QStringLiteral("analyze")) {
        const QVariantMap analysis = analyzeCurrentFileWithCodeMagic();
        if (analysis.contains(QStringLiteral("error"))) {
            emit errorOccurred(analysis.value(QStringLiteral("error")).toString());
        } else {
            emit successOccurred(QStringLiteral("Code analysis completed with %1 issue(s).")
                                     .arg(analysis.value(QStringLiteral("issues")).toList().size()));
        }
        return true;
    }

    if (command == QStringLiteral("explain")) {
        const QVariantMap explanation = explainCurrentFileWithCodeMagic();
        if (explanation.contains(QStringLiteral("error"))) {
            emit errorOccurred(explanation.value(QStringLiteral("error")).toString());
        } else {
            emit successOccurred(QStringLiteral("Code explanation ready for %1.")
                                     .arg(fileDisplayName(m_currentFilePath)));
        }
        return true;
    }

    if (command == QStringLiteral("search")) {
        if (args.isEmpty()) {
            emit errorOccurred(QStringLiteral("Usage: /search <query>"));
            return true;
        }

        const QString knowledgeResult = searchWorkspaceKnowledge(args);
        const QStringList pathMatches = searchWorkspacePaths(args);
        if (!pathMatches.isEmpty()) {
            emit successOccurred(QStringLiteral("Path matches: %1")
                                     .arg(pathMatches.mid(0, 5).join(QStringLiteral(", "))));
        } else if (!knowledgeResult.isEmpty()) {
            emit successOccurred(QStringLiteral("Local search completed."));
        }
        return true;
    }

    if (command == QStringLiteral("checkpoint")) {
        if (!args.isEmpty()) {
            rollbackCheckpoint(args);
            return true;
        }

        const QVariantList checkpoints = recentCheckpoints();
        if (checkpoints.isEmpty()) {
            emit successOccurred(QStringLiteral("No checkpoints available."));
            return true;
        }

        const QVariantMap checkpoint = checkpoints.first().toMap();
        const QString checkpointId = checkpoint.value(QStringLiteral("id")).toString();
        const QString description = checkpoint.value(QStringLiteral("description")).toString();
        const QVariantList files = checkpointPreview(checkpointId);
        emit checkpointRestoreRequested(checkpointId, description, files);
        return true;
    }

    if (command == QStringLiteral("delegate")) {
        if (args.isEmpty()) {
            emit errorOccurred(QStringLiteral("Usage: /delegate <task>"));
            return true;
        }

        submitToAgent(QStringLiteral(
            "Use the codex_agent tool to delegate the following subtask, then summarize the outcome and any follow-up work:\n%1")
                          .arg(args));
        return true;
    }

    emit errorOccurred(QStringLiteral("Unknown command: /%1. Type /help for available commands.").arg(command));
    return true;
}

void AgentController::syncKnowledgeForPathChange(const QString &oldPath, const QString &newPath, bool wasDirectory)
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool)
        return;

    QString error;
    const QString oldAbs = QFileInfo(oldPath).absoluteFilePath();
    if (!oldAbs.isEmpty()) {
        if (wasDirectory)
            knowledgeTool->removeSourcePrefix(oldAbs, &error);
        else
            knowledgeTool->removeSourcePath(oldAbs, &error);
        if (!error.isEmpty())
            qWarning().noquote() << "[knowledge] cleanup failed:" << error;
    }

    const QString newAbs = QFileInfo(newPath).absoluteFilePath();
    if (newAbs.isEmpty() || !QFileInfo::exists(newAbs))
        return;

    const ToolResult result = QFileInfo(newAbs).isDir()
        ? knowledgeTool->execute(
              QStringLiteral("ui-knowledge-index-directory"),
              QJsonObject{
                  {"action", "index_directory"},
                  {"path", newAbs},
                  {"extensions", QJsonArray::fromStringList(defaultKnowledgeExtensions())},
              })
        : knowledgeTool->execute(
              QStringLiteral("ui-knowledge-index-file"),
              QJsonObject{
                  {"action", "index_file"},
                  {"path", newAbs},
              });

    if (!result.isError)
        emit knowledgeSourcesChanged();
    else
        qWarning().noquote() << "[knowledge] reindex failed:" << result.content;
}

void AgentController::openEditorFile(const QString &filePath)
{
    const QString normalizedPath = normalizeLocalFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        emit errorOccurred(QStringLiteral("Invalid file path."));
        return;
    }

    QFile f(normalizedPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning().noquote() << "[AgentController] openEditorFile failed to open:" << normalizedPath;
        emit errorOccurred(QStringLiteral("Failed to open file: %1").arg(normalizedPath));
        return;
    }

    QTextStream in(&f);
    const QString content = in.readAll();

    int index = -1;
    for (int i = 0; i < m_documents.size(); ++i) {
        if (m_documents[i].path == normalizedPath) {
            index = i;
            break;
        }
    }

    if (index < 0) {
        EditorDocument doc;
        doc.path = normalizedPath;
        doc.content = content;
        doc.savedContent = content;
        doc.dirty = false;
        m_documents.append(doc);
        index = m_documents.size() - 1;
        emit openFilesChanged();
    } else if (!m_documents[index].dirty && m_documents[index].savedContent != content) {
        m_documents[index].content = content;
        m_documents[index].savedContent = content;
    }

    qInfo().noquote() << QStringLiteral("[AgentController] openEditorFile -> path=%1 index=%2 contentLen=%3").arg(normalizedPath).arg(index).arg(content.size());
    clearCurrentSelection();
    setCurrentEditorIndex(index);
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(normalizedPath);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(normalizedPath);
}

bool AgentController::createWorkspaceEntry(const QString &parentPath, const QString &name, bool directory)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString cleanName = QFileInfo(name.trimmed()).fileName();
    if (cleanName.isEmpty()) {
        emit errorOccurred(QStringLiteral("Name cannot be empty."));
        return false;
    }

    const QString absParent = QFileInfo(parentPath).isDir()
        ? QFileInfo(parentPath).absoluteFilePath()
        : QFileInfo(parentPath).absolutePath();
    if (!absParent.startsWith(m_workspacePath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    const QString absPath = QDir(absParent).filePath(cleanName);
    if (QFileInfo::exists(absPath)) {
        emit errorOccurred(QStringLiteral("Path already exists."));
        return false;
    }

    bool ok = false;
    if (directory) {
        ok = QDir().mkpath(absPath);
    } else {
        QSaveFile file(absPath);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            file.commit();
            ok = true;
        }
    }

    if (!ok) {
        emit errorOccurred(directory
                           ? QStringLiteral("Failed to create folder.")
                           : QStringLiteral("Failed to create file."));
        return false;
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();

    if (!directory)
        openEditorFile(absPath);

    m_lastWorkspaceActionType.clear();
    m_lastWorkspaceActionSource.clear();
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();

    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();
    return true;
}

bool AgentController::rollbackCheckpoint(const QString &checkpointId)
{
    auto *checkpointTool = qobject_cast<CheckpointTool *>(m_registry ? m_registry->tool("checkpoint") : nullptr);
    if (!checkpointTool) {
        emit errorOccurred(QStringLiteral("Checkpoint tool is not available."));
        return false;
    }

    const QString normalizedId = checkpointId.trimmed();
    if (normalizedId.isEmpty()) {
        emit errorOccurred(QStringLiteral("Checkpoint id cannot be empty."));
        return false;
    }

    const QVariantList affectedFiles = checkpointPreview(normalizedId);
    const QString affectedFilesSummary = summarizeCheckpointFiles(affectedFiles);

    const ToolResult result = checkpointTool->execute(
        QStringLiteral("ui-checkpoint-%1").arg(normalizedId),
        QJsonObject{
            {"action", "rollback"},
            {"checkpoint_id", normalizedId},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    QString detail = QStringLiteral("%1: %2").arg(result.name, result.content);
    if (!affectedFilesSummary.isEmpty())
        detail += QStringLiteral(" Restored %1.").arg(affectedFilesSummary);

    ChatMessage statusMsg;
    statusMsg.role = QStringLiteral("tool");
    statusMsg.content = detail;
    m_chatModel->append(statusMsg);

    appendSessionStoreMessage(QStringLiteral("tool"),
                              detail);
    saveTaskSession();
    emit recentCheckpointsChanged();

    QString successMessage = QStringLiteral("Restored checkpoint %1").arg(normalizedId);
    if (!affectedFilesSummary.isEmpty())
        successMessage += QStringLiteral(" (%1)").arg(affectedFilesSummary);
    successMessage += QStringLiteral(".");
    emit successOccurred(successMessage);
    return true;
}

bool AgentController::renameWorkspacePath(const QString &path, const QString &newName)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString absPath = QFileInfo(path).absoluteFilePath();
    if (!absPath.startsWith(m_workspacePath) || !QFileInfo::exists(absPath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    const QString cleanName = QFileInfo(newName.trimmed()).fileName();
    if (cleanName.isEmpty()) {
        emit errorOccurred(QStringLiteral("Name cannot be empty."));
        return false;
    }

    QFileInfo info(absPath);
    const QString parentPath = info.dir().absolutePath();
    const QString newAbsPath = QDir(parentPath).filePath(cleanName);
    if (newAbsPath == absPath)
        return true;
    if (QFileInfo::exists(newAbsPath)) {
        emit errorOccurred(QStringLiteral("Target already exists."));
        return false;
    }

    QDir parentDir(parentPath);
    const bool ok = parentDir.rename(info.fileName(), cleanName);
    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to rename path."));
        return false;
    }

    for (auto &doc : m_documents) {
        if (doc.path == absPath || doc.path.startsWith(absPath + "/")) {
            doc.path.replace(absPath, newAbsPath);
        }
    }

    if (m_currentFilePath == absPath || m_currentFilePath.startsWith(absPath + "/")) {
        m_currentFilePath.replace(absPath, newAbsPath);
        emit currentFilePathChanged();
    }

    if (m_currentEditorIndex >= 0 && m_currentEditorIndex < m_documents.size()) {
        m_currentFileContent = m_documents[m_currentEditorIndex].content;
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();

    emit openFilesChanged();
    syncKnowledgeForPathChange(absPath, newAbsPath, info.isDir());
    m_lastWorkspaceActionType.clear();
    m_lastWorkspaceActionSource.clear();
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();
    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();
    return true;
}

bool AgentController::deleteWorkspacePath(const QString &path)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString absPath = QFileInfo(path).absoluteFilePath();
    if (!absPath.startsWith(m_workspacePath) || !QFileInfo::exists(absPath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    QFileInfo info(absPath);
    bool ok = false;
    if (info.isDir()) {
        QDir dir(absPath);
        ok = dir.removeRecursively();
    } else {
        ok = QFile::remove(absPath);
    }

    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to delete path."));
        return false;
    }

    for (int i = m_documents.size() - 1; i >= 0; --i) {
        if (m_documents[i].path == absPath || m_documents[i].path.startsWith(absPath + "/")) {
            m_documents.removeAt(i);
            if (i == m_currentEditorIndex)
                m_currentEditorIndex = -1;
            else if (i < m_currentEditorIndex)
                --m_currentEditorIndex;
        }
    }

    if (m_currentFilePath == absPath || m_currentFilePath.startsWith(absPath + "/")) {
        m_currentFilePath.clear();
        m_currentFileContent.clear();
        emit currentFilePathChanged();
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();
    emit openFilesChanged();
    syncKnowledgeForPathChange(absPath, QString{}, info.isDir());
    m_lastWorkspaceActionType = "delete";
    m_lastWorkspaceActionSource = absPath;
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();
    saveSettings();
    refreshSystemPrompt();
    saveTaskSession();
    return true;
}

bool AgentController::moveWorkspacePath(const QString &path, const QString &destinationDir)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString absPath = QFileInfo(path).absoluteFilePath();
    const QString absDestinationDir = QFileInfo(destinationDir).absoluteFilePath();
    if (!absPath.startsWith(m_workspacePath) || !absDestinationDir.startsWith(m_workspacePath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    QFileInfo info(absPath);
    if (!info.exists()) {
        emit errorOccurred(QStringLiteral("Path does not exist."));
        return false;
    }

    QDir destDir(absDestinationDir);
    if (!destDir.exists()) {
        emit errorOccurred(QStringLiteral("Destination directory does not exist."));
        return false;
    }

    const QString newAbsPath = destDir.filePath(info.fileName());
    if (newAbsPath == absPath)
        return true;
    if (QFileInfo::exists(newAbsPath)) {
        emit errorOccurred(QStringLiteral("Target already exists."));
        return false;
    }

    const bool ok = info.isDir() ? QDir().rename(absPath, newAbsPath)
                                 : QFile::rename(absPath, newAbsPath);
    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to move path."));
        return false;
    }

    for (auto &doc : m_documents) {
        if (doc.path == absPath || doc.path.startsWith(absPath + "/")) {
            doc.path.replace(absPath, newAbsPath);
        }
    }

    if (m_currentFilePath == absPath || m_currentFilePath.startsWith(absPath + "/")) {
        m_currentFilePath.replace(absPath, newAbsPath);
        emit currentFilePathChanged();
    }

    if (m_currentEditorIndex >= 0 && m_currentEditorIndex < m_documents.size()) {
        m_currentFileContent = m_documents[m_currentEditorIndex].content;
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();
    emit openFilesChanged();
    syncKnowledgeForPathChange(absPath, newAbsPath, info.isDir());
    m_lastWorkspaceActionType = "move";
    m_lastWorkspaceActionSource = absPath;
    m_lastWorkspaceActionDestination = newAbsPath;
    emit undoWorkspaceActionChanged();
    saveSettings();
    refreshSystemPrompt();
    saveTaskSession();
    return true;
}

bool AgentController::undoLastWorkspaceAction()
{
    if (m_lastWorkspaceActionType != "move" || m_lastWorkspaceActionSource.isEmpty() || m_lastWorkspaceActionDestination.isEmpty())
        return false;

    const QString src = m_lastWorkspaceActionSource;
    const QString dest = m_lastWorkspaceActionDestination;
    if (!QFileInfo::exists(dest)) {
        emit errorOccurred(QStringLiteral("Nothing to undo."));
        return false;
    }

    QFileInfo info(dest);
    const bool ok = info.isDir() ? QDir().rename(dest, src)
                                 : QFile::rename(dest, src);
    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to undo move."));
        return false;
    }

    for (auto &doc : m_documents) {
        if (doc.path == dest || doc.path.startsWith(dest + "/")) {
            doc.path.replace(dest, src);
        }
    }

    if (m_currentFilePath == dest || m_currentFilePath.startsWith(dest + "/")) {
        m_currentFilePath.replace(dest, src);
        emit currentFilePathChanged();
    }

    if (m_currentEditorIndex >= 0 && m_currentEditorIndex < m_documents.size()) {
        m_currentFileContent = m_documents[m_currentEditorIndex].content;
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();
    emit openFilesChanged();

    m_lastWorkspaceActionType.clear();
    m_lastWorkspaceActionSource.clear();
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();
    saveSettings();
    refreshSystemPrompt();
    saveTaskSession();
    return true;
}

void AgentController::saveCurrentFile()
{
    if (m_currentEditorIndex < 0 || m_currentEditorIndex >= m_documents.size())
        return;

    auto &doc = m_documents[m_currentEditorIndex];
    if (doc.path.isEmpty())
        return;

    QSaveFile f(doc.path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return;

    QTextStream out(&f);
    out << doc.content;
    if (!f.commit())
        return;
    doc.savedContent = doc.content;
    doc.dirty = false;
    m_currentFileContent = doc.content;
    m_currentFilePath = doc.path;
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(doc.path);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(doc.path);
    emit openFilesChanged();
    emit currentFileContentChanged();
    saveSettings();
    saveTaskSession();

    if (auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr)) {
        const ToolResult result = knowledgeTool->execute(
            QStringLiteral("ui-knowledge-index-file"),
            QJsonObject{
                {"action", "index_file"},
                {"path", doc.path},
            });
        if (!result.isError) {
            emit knowledgeSourcesChanged();
        } else {
            qWarning().noquote() << "[knowledge] auto-index failed:" << result.content;
        }
    }
}

void AgentController::closeEditorTab(int index)
{
    closeEditorTabInternal(index, false);
}

void AgentController::forceCloseEditorTab(int index)
{
    closeEditorTabInternal(index, true);
}

void AgentController::closeEditorTabInternal(int index, bool allowDirtyClose)
{
    if (index < 0 || index >= m_documents.size())
        return;

    if (!allowDirtyClose && m_documents[index].dirty) {
        emit errorOccurred(QStringLiteral("Save the file before closing this tab."));
        return;
    }

    const bool closingCurrent = (index == m_currentEditorIndex);
    m_documents.removeAt(index);

    if (m_documents.isEmpty()) {
        m_currentEditorIndex = -1;
        const bool hadPath = !m_currentFilePath.isEmpty();
        const bool hadContent = !m_currentFileContent.isEmpty();
        m_currentFilePath.clear();
        m_currentFileContent.clear();
        if (hadPath) emit currentFilePathChanged();
        if (hadContent) emit currentFileContentChanged();
        emit currentEditorIndexChanged();
        emit openFilesChanged();
        saveSettings();
        refreshSystemPrompt();
        saveTaskSession();
        return;
    }

    if (closingCurrent) {
        const int nextIndex = std::min(index, static_cast<int>(m_documents.size()) - 1);
        m_currentEditorIndex = -1;
        emit openFilesChanged();
        setCurrentEditorIndex(nextIndex);
        return;
    }

    if (index < m_currentEditorIndex)
        --m_currentEditorIndex;

    emit openFilesChanged();
    emit currentEditorIndexChanged();
    saveSettings();
    saveTaskSession();
}

bool AgentController::autoApproveTools() const { return m_autoApproveTools; }
bool AgentController::canUndoWorkspaceAction() const
{
    return m_lastWorkspaceActionType == "move"
        && !m_lastWorkspaceActionSource.isEmpty()
        && !m_lastWorkspaceActionDestination.isEmpty();
}
void AgentController::setAutoApproveTools(bool v)
{
    if (m_autoApproveTools == v) return;
    m_autoApproveTools = v;
    m_engine->setAutoApproveTools(v);
    saveSettings();
    saveTaskSession();
    emit autoApproveToolsChanged();
    emit toolCatalogChanged();
}

void AgentController::setBusy(bool b)
{
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

void AgentController::sendMessage(const QString &text)
{
    const QString trimmed = text.trimmed();
    const bool hasAttachments = !m_pendingAttachments.isEmpty();
    if (trimmed.isEmpty() && !hasAttachments)
        return;
    if (trimmed.startsWith('/')) {
        if (handleSlashCommand(trimmed))
            return;
    }
    submitToAgent(text);
}

void AgentController::submitToAgent(const QString &text, const QVariantList &attachments)
{
    if (!m_engine || m_busy) {
        emit errorOccurred(QStringLiteral("Agent is busy."));
        return;
    }

    const QVariantList effectiveAttachments = attachments.isEmpty()
        ? m_pendingAttachments
        : attachments;
    const QString sessionText = text.trimmed().isEmpty()
        ? attachmentSummaryText(effectiveAttachments)
        : text;
    qInfo().noquote() << "[agent] user message:" << logPreview(text);
    m_streamingText.clear();
    m_streamingAssistantActive = false;
    appendSessionStoreMessage(QStringLiteral("user"), sessionText);
    m_engine->submitUserMessage(text, effectiveAttachments);
    if (attachments.isEmpty() && !m_pendingAttachments.isEmpty()) {
        m_pendingAttachments.clear();
        emit pendingAttachmentsChanged();
    }
    saveTaskSession();
}

bool AgentController::attachImageFromPath(const QString &filePath)
{
    const QString normalized = normalizeLocalFilePath(filePath);
    if (normalized.isEmpty()) {
        emit errorOccurred(QStringLiteral("Invalid image path."));
        return false;
    }

    QFile file(normalized);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred(QStringLiteral("Failed to open image file: %1").arg(normalized));
        return false;
    }

    const QByteArray bytes = file.readAll();
    if (bytes.isEmpty()) {
        emit errorOccurred(QStringLiteral("Image file is empty: %1").arg(normalized));
        return false;
    }

    QMimeDatabase mimeDb;
    const QString mimeType = mimeDb.mimeTypeForFile(normalized, QMimeDatabase::MatchContent).name();
    if (!isImageMimeType(mimeType) && !QImageReader(normalized).canRead()) {
        emit errorOccurred(QStringLiteral("Selected file is not a supported image: %1").arg(normalized));
        return false;
    }

    const QVariantMap attachment = attachmentMapFromBytes(
        normalized,
        bytes,
        mimeType.isEmpty() ? QStringLiteral("image/png") : mimeType,
        QFileInfo(normalized).fileName());

    m_pendingAttachments.append(attachment);
    emit pendingAttachmentsChanged();
    emit successOccurred(QStringLiteral("Attached image: %1").arg(QFileInfo(normalized).fileName()));
    return true;
}

bool AgentController::attachImageFromClipboard()
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        emit errorOccurred(QStringLiteral("Clipboard is not available."));
        return false;
    }

    const QImage image = clipboard->image();
    if (image.isNull()) {
        emit errorOccurred(QStringLiteral("Clipboard does not contain an image."));
        return false;
    }

    const QVariantMap attachment = attachmentMapFromImage(
        image,
        QStringLiteral("clipboard.png"),
        QStringLiteral("image/png"),
        QStringLiteral("Clipboard image"));

    m_pendingAttachments.append(attachment);
    emit pendingAttachmentsChanged();
    emit successOccurred(QStringLiteral("Attached image from clipboard."));
    return true;
}

void AgentController::clearPendingAttachments()
{
    if (m_pendingAttachments.isEmpty())
        return;
    m_pendingAttachments.clear();
    emit pendingAttachmentsChanged();
}

void AgentController::injectFile(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QTextStream in(&f);
    const QString content = in.readAll();
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(filePath);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(filePath);
    refreshSystemPrompt();
    m_engine->injectContext(filePath, content);
}

void AgentController::injectSelection(const QString &filePath, const QString &code,
                                      int startLine, int endLine)
{
    const QString normalizedPath = normalizeLocalFilePath(filePath);
    setCurrentSelection(normalizedPath.isEmpty() ? filePath : normalizedPath, code, startLine, endLine);
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(normalizedPath.isEmpty() ? filePath : normalizedPath);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(normalizedPath.isEmpty() ? filePath : normalizedPath);
    refreshSystemPrompt();
    m_engine->injectContext(normalizedPath.isEmpty() ? filePath : normalizedPath, code, startLine, endLine);
}

void AgentController::clearCurrentSelection()
{
    if (m_selectedFilePath.isEmpty() && m_selectedText.isEmpty() && m_selectedStartLine < 0 && m_selectedEndLine < 0)
        return;
    m_selectedFilePath.clear();
    m_selectedText.clear();
    m_selectedStartLine = -1;
    m_selectedEndLine = -1;
    emit currentSelectionChanged();
}

void AgentController::interrupt()     { m_engine->interrupt(); }
void AgentController::clearHistory()
{
    m_engine->clearHistory();
    m_chatModel->clear();
    m_executionTimeline.clear();
    m_pendingToolExecutions.clear();
    emit executionTimelineChanged();
    emit toolCatalogChanged();
    clearPendingAttachments();
    clearCurrentSelection();
    updateCodeMagicResult(QVariantMap{}, QString{});
    m_streamingAssistantActive = false;
    m_streamingText.clear();
    m_sessionId = TaskSessionStore::defaultSessionId();
    m_parentThreadId.clear();
    m_threadCreatedAt = QDateTime::currentDateTimeUtc();
    emit currentThreadIdChanged();
    if (auto *store = qobject_cast<SessionStore *>(m_registry ? m_registry->tool("session_search") : nullptr))
        store->beginSession(m_workspacePath);
    saveTaskSession();
    emit recentSessionsChanged();
}
void AgentController::approveTool(const QString &callId)
{
    if (m_pendingToolExecutions.contains(callId)) {
        const QVariantMap result = executePendingTool(callId);
        if (result.contains(QStringLiteral("error")))
            emit errorOccurred(result.value(QStringLiteral("error")).toString());
        return;
    }
    m_engine->approveTool(callId, true);
}

void AgentController::rejectTool(const QString &callId)
{
    if (m_pendingToolExecutions.contains(callId)) {
        const PendingToolExecution pending = m_pendingToolExecutions.take(callId);
        appendExecutionEvent(QStringLiteral("approval"),
                             QStringLiteral("Tool execution rejected"),
                             QStringLiteral("error"),
                             pending.summary,
                             pending.toolName,
                             callId);
        if (!m_restoringSessionHistory)
            saveTaskSession();
        emit errorOccurred(QStringLiteral("Tool execution denied by user."));
        return;
    }
    m_engine->approveTool(callId, false);
}

void AgentController::onTokenReceived(const TokenEvent &ev)
{
    if (ev.type == TokenEvent::Type::TextDelta) {
        if (!m_streamingAssistantActive) {
            ChatMessage cm;
            cm.role = "assistant";
            m_chatModel->append(cm);
            m_streamingAssistantActive = true;
        }
        m_streamingText += ev.delta;
        emit streamingTextChanged();
        m_chatModel->updateLastContent(ev.delta);
    }
}

void AgentController::onMessageAdded(const AgentMessage &msg)
{
    switch (msg.role) {
    case MessageRole::System:
        appendSessionStoreMessage(QStringLiteral("system"), msg.content);
        break;
    case MessageRole::User:
        break;
    case MessageRole::Assistant:
        appendSessionStoreMessage(QStringLiteral("assistant"), msg.content);
        break;
    case MessageRole::Tool:
        appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
        break;
    }
    if (msg.role == MessageRole::Tool) return; // tool results shown as cards

    const QString roleKind = (msg.role == MessageRole::Assistant)
        ? QStringLiteral("assistant_message")
        : (msg.role == MessageRole::User)
            ? QStringLiteral("user_message")
            : QStringLiteral("system_message");
    appendExecutionEvent(
        roleKind,
        roleKind == QStringLiteral("assistant_message")
            ? QStringLiteral("Assistant response")
            : roleKind == QStringLiteral("user_message")
                ? QStringLiteral("User input")
                : QStringLiteral("System note"),
        QStringLiteral("done"),
        logPreview(msg.content));
    if (!m_restoringSessionHistory)
        saveTaskSession();

    ChatMessage cm;
    switch (msg.role) {
    case MessageRole::User:      cm.role = "user";      break;
    case MessageRole::Assistant: cm.role = "assistant"; break;
    default:                     cm.role = "system";    break;
    }
    cm.content = msg.content;
    cm.attachments = msg.attachments;

    for (const auto &tc : msg.toolCalls) {
        QVariantMap card;
        card["id"]     = tc.id;
        card["name"]   = tc.name;
        card["status"] = "pending";
        card["args"]   = QJsonDocument(tc.arguments).toJson(QJsonDocument::Indented);
        cm.toolCalls.append(card);
    }

    if (msg.role == MessageRole::Assistant && m_streamingAssistantActive) {
        m_chatModel->replaceLast(cm);
        m_streamingAssistantActive = false;
    } else {
        m_chatModel->append(cm);
    }
}

void AgentController::onToolExecuting(const ToolCall &call)
{
    qInfo().noquote() << "[agent] tool executing:" << call.name
                      << "callId=" << call.id;
    appendExecutionEvent(
        inferExecutionKind(call.name),
        QStringLiteral("Tool running"),
        QStringLiteral("running"),
        toolEventPreview(call.name, call.arguments),
        call.name,
        call.id);
    if (!m_restoringSessionHistory)
        saveTaskSession();
    QVariantMap card;
    card["id"]     = call.id;
    card["name"]   = call.name;
    card["status"] = "running";
    card["args"]   = QJsonDocument(call.arguments).toJson(QJsonDocument::Indented);
    m_chatModel->appendToolCallToLastAssistant(card);
}

void AgentController::onToolFinished(const ToolResult &result)
{
    appendSessionStoreMessage(QStringLiteral("tool"),
                              QStringLiteral("%1: %2").arg(result.name, result.content));
    qInfo().noquote() << "[agent] tool finished:" << result.name
                      << "callId=" << result.callId
                      << "status=" << (result.isError ? "error" : "done")
                      << "preview=" << logPreview(result.content);
    appendExecutionEvent(
        inferExecutionKind(result.name),
        result.isError ? QStringLiteral("Tool failed") : QStringLiteral("Tool completed"),
        result.isError ? QStringLiteral("error") : QStringLiteral("done"),
        logPreview(result.content),
        result.name,
        result.callId);
    if (!m_restoringSessionHistory)
        saveTaskSession();
    QVariantMap card;
    card["id"]     = result.callId;
    card["name"]   = result.name;
    card["status"] = result.isError ? "error" : "done";
    card["result"] = result.content;
    m_chatModel->updateToolCall(result.callId, card);

    if (!result.isError
        && (result.name == QStringLiteral("file_system")
            || result.name == QStringLiteral("patch")
            || result.name == QStringLiteral("checkpoint"))) {
        emit recentCheckpointsChanged();
    }
    m_runningToolOutput.remove(result.callId);
}

void AgentController::onToolOutputChunk(const QString &callId, const QString &chunk)
{
    const bool firstChunk = !m_runningToolOutput.contains(callId) || m_runningToolOutput.value(callId).isEmpty();
    m_runningToolOutput[callId] += chunk;
    if (firstChunk) {
        appendExecutionEvent(
            QStringLiteral("tool_output"),
            QStringLiteral("Tool output"),
            QStringLiteral("running"),
            logPreview(chunk),
            QString{},
            callId);
        if (!m_restoringSessionHistory)
            saveTaskSession();
    }
    QVariantMap card;
    card["id"]     = callId;
    card["status"] = "running";
    card["result"] = m_runningToolOutput.value(callId);
    m_chatModel->updateToolCall(callId, card);
}

void AgentController::onSandboxExecutionEvent(const QVariantMap &event)
{
    const QString kind = event.value(QStringLiteral("kind")).toString();
    const QString title = event.value(QStringLiteral("title")).toString();
    const QString status = event.value(QStringLiteral("status")).toString();
    const QString details = event.value(QStringLiteral("details")).toString();
    const QString toolName = event.value(QStringLiteral("toolName")).toString();
    const QString callId = event.value(QStringLiteral("callId")).toString();

    appendExecutionEvent(kind.isEmpty() ? QStringLiteral("sandbox") : kind,
                         title.isEmpty() ? QStringLiteral("Sandbox event") : title,
                         status.isEmpty() ? QStringLiteral("running") : status,
                         details,
                         toolName,
                         callId);
    if (!m_restoringSessionHistory)
        saveTaskSession();
}

void AgentController::onCodeMagicAnalysisCompleted(const CodeAnalysisResult &result)
{
    appendExecutionEvent(
        QStringLiteral("code_magic_analysis"),
        QStringLiteral("Code analysis completed"),
        QStringLiteral("done"),
        QStringLiteral("%1 issue(s), quality %2")
            .arg(result.issues.size())
            .arg(QString::number(result.quality, 'f', 1)),
        QStringLiteral("code_magic"),
        result.analysisId);
    if (!m_restoringSessionHistory)
        saveTaskSession();
}

void AgentController::onCodeMagicGenerationCompleted(const GeneratedCode &code)
{
    appendExecutionEvent(
        QStringLiteral("code_magic_generation"),
        QStringLiteral("Code generation completed"),
        QStringLiteral("done"),
        logPreview(code.explanation.isEmpty() ? code.code : code.explanation),
        QStringLiteral("code_magic"),
        code.generationId);
    if (!m_restoringSessionHistory)
        saveTaskSession();
}

void AgentController::onCodeMagicRefactoringCompleted(const RefactoringResult &result)
{
    appendExecutionEvent(
        QStringLiteral("code_magic_refactor"),
        QStringLiteral("Code refactoring completed"),
        result.successful ? QStringLiteral("done") : QStringLiteral("error"),
        result.successful ? logPreview(result.explanation) : result.error,
        QStringLiteral("code_magic"),
        result.refactoringId);
    if (!m_restoringSessionHistory)
        saveTaskSession();
}

void AgentController::onCodeMagicTestsGenerated(const GeneratedTests &tests)
{
    appendExecutionEvent(
        QStringLiteral("code_magic_tests"),
        QStringLiteral("Tests generated"),
        QStringLiteral("done"),
        QStringLiteral("%1 test case(s), coverage %2%")
            .arg(tests.numberOfTests)
            .arg(tests.estimatedCoverage),
        QStringLiteral("code_magic"),
        tests.testId);
    if (!m_restoringSessionHistory)
        saveTaskSession();
}

void AgentController::onCodeMagicErrorOccurred(const QString &error)
{
    appendExecutionEvent(
        QStringLiteral("code_magic_error"),
        QStringLiteral("CodeMagic error"),
        QStringLiteral("error"),
        error,
        QStringLiteral("code_magic"));
    if (!m_restoringSessionHistory)
        saveTaskSession();
    emit errorOccurred(error);
}
