import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: shell

    readonly property color bg: "#111111"
    readonly property color surface: "#1a1a1a"
    readonly property color border: "#2b2b2b"
    readonly property color accent: "#19a974"
    readonly property color textPrimary: "#f3f3f3"
    readonly property color textMuted: "#a0a0a0"
    readonly property color panelAlt: "#151515"
    readonly property color panelHover: "#202020"
    readonly property color editorBg: "#0f1115"
    readonly property color selectionBg: "#173f31"
    readonly property color userBubble: "#123d2f"
    readonly property color agentBubble: "#171b22"
    readonly property color lineNumberBg: "#14181d"
    readonly property color lineNumberBorder: "#20262d"
    readonly property color highlightKeyword: "#6cb6ff"
    readonly property color highlightString: "#f69d50"
    readonly property color highlightComment: "#7f8c98"
    readonly property color highlightDirective: "#d2a8ff"
    readonly property int paneHandleWidth: 10
    readonly property int paneMinExplorerWidth: 220
    readonly property int paneMinEditorWidth: 340
    readonly property int paneMinAgentWidth: 380
    readonly property real userBubbleWidthRatio: 0.58
    readonly property real assistantBubbleWidthRatio: 0.86

    readonly property int workspaceMargin: 20

    property int selectedFileIndex: 1
    property string selectedFilePath: ""
    property int explorerPaneWidth: 280
    property int agentPaneWidth: 540
    property int runSteps: 4
    property bool agentRunning: false
    property int runClickSeq: 0
    property real runStartMs: 0
    property string lastPromptText: ""
    property string lastResponseLabel: qsTr("NeurX")
    property string lastRunDurationText: ""
    property string runtimeStatusText: Runtime.ping()
    property string editorPlainText: ""
    property string editorKind: "Text"
    property var diagnosticsSkillRecords: []
    property string selectedSkillName: ""
    property string skillStatusFilter: ""
    property bool skillActiveOnly: false
    property bool skillHighFailOnly: false
    property bool selectedSkillFailedOnly: false
    property string selectedSkillToolFilter: ""
    property string selectedSkillSearchText: ""
    property bool agentDetailsExpanded: false
    property int activeAssistantMessageIndex: -1
    property string copyNoticeText: ""
    property int agentRunTimeoutMs: 20000

    function escapeHtml(text) {
        return (text || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\"/g, "&quot;")
    }

    function syntaxKeywords(kind) {
        if (kind === "QML") {
            return ["import", "property", "readonly", "required", "signal", "function", "if", "else", "return", "true", "false", "var", "let", "const", "id", "onClicked", "anchors", "parent"]
        }
        if (kind === "C++") {
            return ["class", "const", "constexpr", "enum", "explicit", "false", "for", "if", "include", "int", "namespace", "nullptr", "override", "private", "protected", "public", "return", "signals", "slots", "static", "struct", "switch", "template", "true", "void", "while"]
        }
        return ["if", "else", "for", "while", "return", "function", "const", "let", "var", "true", "false"]
    }

    function lineNumberHtml(text) {
        var lineCount = Math.max(1, (text || "").split("\n").length)
        var numbers = []
        for (var index = 1; index <= lineCount; ++index) {
            numbers.push(index)
        }

        return "<pre style=\"margin:0;font-family:'Consolas','Courier New',monospace;font-size:14px;line-height:1.35;color:" + shell.textMuted + ";text-align:right;\">"
            + numbers.join("\n")
            + "</pre>"
    }

    function highlightCode(text, kind) {
        var source = text || ""
        if (!source.length) {
            return "<pre style=\"margin:0;font-family:'Consolas','Courier New',monospace;font-size:14px;line-height:1.35;color:" + shell.textPrimary + ";\"></pre>"
        }

        var keywords = syntaxKeywords(kind)
        var keywordPattern = keywords.length > 0 ? "\\b(?:" + keywords.join("|") + ")\\b" : "$^"
        var tokenPattern = new RegExp("(//[^\\n]*|/\\*[\\s\\S]*?\\*/|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|#[A-Za-z_][A-Za-z0-9_]*|" + keywordPattern + ")", "g")
        var highlighted = ""
        var lastIndex = 0
        var match

        while ((match = tokenPattern.exec(source)) !== null) {
            highlighted += escapeHtml(source.slice(lastIndex, match.index))
            var token = match[0]
            var color = shell.highlightKeyword

            if (token.indexOf("//") === 0 || token.indexOf("/*") === 0) {
                color = shell.highlightComment
            } else if (token.indexOf("#") === 0) {
                color = shell.highlightDirective
            } else if (token.indexOf("\"") === 0 || token.indexOf("'") === 0) {
                color = shell.highlightString
            }

            highlighted += "<span style=\"color:" + color + ";\">" + escapeHtml(token) + "</span>"
            lastIndex = match.index + token.length
        }

        highlighted += escapeHtml(source.slice(lastIndex))
        return "<pre style=\"margin:0;font-family:'Consolas','Courier New',monospace;font-size:14px;line-height:1.35;color:" + shell.textPrimary + ";\">"
            + highlighted.replace(/\t/g, "    ")
            + "</pre>"
    }

    function appendConversationMessage(kind, label, text, pending) {
        var parsed = shell.parseConversationPayload(text || "")
        conversationModel.append({
            kind: kind,
            label: label,
            text: text,
            bodyText: parsed.bodyText,
            modeText: parsed.modeText,
            planText: parsed.planText,
            pending: pending,
            durationText: pending ? qsTr("Working...") : "",
            copied: false
        })
        conversationList.positionViewAtEnd()
    }

    function copyConversationText(text) {
        if (!text || !text.length) {
            return
        }
        Runtime.copy_to_clipboard(text)
        shell.copyNoticeText = qsTr("Copied")
        copyNoticeTimer.restart()
    }

    function beginConversation(prompt, responseLabel, pendingText) {
        lastPromptText = prompt
        lastResponseLabel = responseLabel
        resultOutput.text = pendingText
        lastRunDurationText = qsTr("Working...")
        runStartMs = Date.now()
        appendConversationMessage("user", qsTr("You"), prompt, false)
        activeAssistantMessageIndex = conversationModel.count
        appendConversationMessage("assistant", responseLabel, pendingText, true)
    }

    function finishConversation(result, durationText) {
        resultOutput.text = result
        var parsed = shell.parseConversationPayload(result)
        diagnosticsSkillRecords = parseSkillRecords(result)
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
            conversationModel.setProperty(activeAssistantMessageIndex, "text", result)
            conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", parsed.bodyText)
            conversationModel.setProperty(activeAssistantMessageIndex, "modeText", parsed.modeText)
            conversationModel.setProperty(activeAssistantMessageIndex, "planText", parsed.planText)
            conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
            conversationModel.setProperty(activeAssistantMessageIndex, "durationText", durationText || "")
        }
        conversationList.positionViewAtEnd()
        activeAssistantMessageIndex = -1
    }

    function parseConversationPayload(text) {
        var source = text || ""
        var lines = source.split("\n")
        var modeText = ""
        var planText = ""
        var bodyLines = []
        var inHeader = true

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i]
            if (inHeader && line.indexOf("[mode] ") === 0) {
                modeText = line.substring(7).trim()
                continue
            }
            if (inHeader && line.indexOf("[plan] ") === 0) {
                planText = line.substring(7).trim()
                continue
            }
            if (inHeader && line.trim().length === 0 && (modeText.length > 0 || planText.length > 0)) {
                continue
            }
            inHeader = false
            bodyLines.push(line)
        }

        return {
            modeText: modeText,
            planText: planText,
            bodyText: bodyLines.join("\n").trim()
        }
    }

    function elapsedDurationText() {
        var startMs = Number(shell.runStartMs)
        var nowMs = Date.now()
        if (!isFinite(startMs) || startMs <= 0 || startMs > nowMs) {
            return qsTr("Worked just now")
        }
        var elapsedSeconds = Math.max(1, Math.round((nowMs - startMs) / 1000))
        return qsTr("Worked for %1s").arg(elapsedSeconds)
    }

    function sendAgentPrompt() {
        if (shell.agentRunning) {
            return
        }

        var prompt = promptEditor.text.trim()
        if (!prompt) {
            prompt = "hello"
        }
        promptEditor.text = ""

        shell.runClickSeq += 1
        shell.agentRunning = true
        shell.runtimeStatusText = qsTr("routing #") + shell.runClickSeq
        shell.beginConversation(prompt, qsTr("NeurX"), qsTr("Working on your request..."))
        agentRunTimeoutTimer.restart()
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            Runtime.run_agent_auto_async(prompt, shell.selectedFilePath || "", shell.runSteps)
        } catch (e) {
            resultOutput.text = qsTr("run_agent_failed: ") + e
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "modeText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "planText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
                activeAssistantMessageIndex = -1
            }
            shell.runtimeStatusText = qsTr("failed #") + shell.runClickSeq
            shell.agentRunning = false
            agentRunTimeoutTimer.stop()
        } finally {
            // Completion comes from Runtime.agentRunFinished.
        }
    }

    function sendCodeSuggestion() {
        var prompt = promptEditor.text.trim()
        var filePath = shell.selectedFilePath || ""
        promptEditor.text = ""
        shell.runtimeStatusText = qsTr("suggesting")
        shell.beginConversation(prompt, qsTr("NeurX"), qsTr("Preparing code suggestion..."))
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.run_code_assistant(prompt, filePath)
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.runtimeStatusText = qsTr("suggestion_done")
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", shell.lastRunDurationText)
            }
            activeAssistantMessageIndex = -1
        } catch (e) {
            resultOutput.text = qsTr("suggest_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.lastRunDurationText = qsTr("Working...")
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
            }
            activeAssistantMessageIndex = -1
        }
    }

    function resolvedAgentPrompt() {
        var prompt = promptEditor.text.trim()
        if (!prompt && shell.lastPromptText.length > 0) {
            prompt = shell.lastPromptText
        }
        if (!prompt) {
            prompt = "hello"
        }
        return prompt
    }

    function sendSkillSnapshot() {
        var prompt = resolvedAgentPrompt()
        shell.runtimeStatusText = qsTr("snapshot")
        shell.beginConversation(prompt, qsTr("Snapshot"), qsTr("Exporting skill snapshot..."))
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.export_agent_skill_snapshot(prompt, shell.runSteps)
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.runtimeStatusText = qsTr("snapshot_done")
            shell.finishConversation(resultOutput.text, shell.lastRunDurationText)
        } catch (e) {
            resultOutput.text = qsTr("snapshot_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.finishConversation(resultOutput.text, qsTr("failed"))
        }
    }

    function sendTrajectoryExport() {
        var prompt = resolvedAgentPrompt()
        shell.runtimeStatusText = qsTr("trajectory")
        shell.beginConversation(prompt, qsTr("Trajectory"), qsTr("Exporting agent trajectory..."))
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.export_agent_trajectory(prompt, shell.runSteps)
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.runtimeStatusText = qsTr("trajectory_done")
            shell.finishConversation(resultOutput.text, shell.lastRunDurationText)
        } catch (e) {
            resultOutput.text = qsTr("trajectory_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.finishConversation(resultOutput.text, qsTr("failed"))
        }
    }

    ListModel {
        id: conversationModel
    }

    ListModel {
        id: fileModel

        ListElement {
            label: "main.cpp"
            path: "app/app/main.cpp"
            kind: "C++"
            content: "#include <QGuiApplication>\n#include <QQmlApplicationEngine>\n#include <QQmlContext>\n#include <QUrl>\n\n#include \"bridge/AgentListModel.h\"\n#include \"bridge/LogModel.h\"\n#include \"bridge/neurx_bridge.h\"\n\nint main(int argc, char* argv[]) {\n    QGuiApplication app(argc, argv);\n    app.setApplicationName(\"Neurx App Shell\");\n\n    NeurxBridge bridge;\n    AgentListModel agent_model;\n    LogModel log_model;\n\n    QObject::connect(&bridge, &NeurxBridge::runtime_status_changed,\n        &agent_model, &AgentListModel::set_primary_agent_status);\n    QObject::connect(&bridge, &NeurxBridge::log_message,\n        &log_model, &LogModel::append);\n\n    QQmlApplicationEngine engine;\n    engine.rootContext()->setContextProperty(\"Runtime\", &bridge);\n    engine.rootContext()->setContextProperty(\"AgentModel\", &agent_model);\n    engine.rootContext()->setContextProperty(\"LogModel\", &log_model);\n\n    engine.load(QUrl(QStringLiteral(\"qrc:/neurx/app/qml/Main.qml\")));\n\n    if (engine.rootObjects().isEmpty()) {\n        return -1;\n    }\n\n    return app.exec();\n}"
        }

        ListElement {
            label: "Main.qml"
            path: "app/qml/Main.qml"
            kind: "QML"
            content: "import QtQuick\nimport QtQuick.Window\n\nWindow {\n    id: root\n    visible: true\n    visibility: Window.FullScreen\n    width: 1440\n    height: 900\n    minimumWidth: 1200\n    minimumHeight: 760\n    title: qsTr(\"Neurx Explorer / Editor / Agent\")\n    color: \"#111111\"\n\n    AppShell {\n        anchors.fill: parent\n    }\n}"
        }

        ListElement {
            label: "neurx_bridge.cpp"
            path: "app/bridge/neurx_bridge.cpp"
            kind: "C++"
            content: "#include \"neurx_bridge.h\"\n\n// Bridge runtime helpers live here."
        }

        ListElement {
            label: "AgentListModel.h"
            path: "app/bridge/AgentListModel.h"
            kind: "C++"
            content: "#pragma once\n\n#include <QAbstractListModel>\n#include <QString>\n#include <QVector>\n\nclass AgentListModel : public QAbstractListModel {\n    Q_OBJECT\n\npublic:\n    enum Roles {\n        IdRole = Qt::UserRole + 1,\n        NameRole,\n        StatusRole,\n    };\n\n    explicit AgentListModel(QObject* parent = nullptr);\n\n    int rowCount(const QModelIndex& parent = QModelIndex()) const override;\n    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;\n    QHash<int, QByteArray> roleNames() const override;\n\npublic slots:\n    void set_primary_agent_status(const QString& status, const QString& task);\n\nprivate:\n    struct AgentEntry {\n        QString id;\n        QString name;\n        QString status;\n    };\n\n    QVector<AgentEntry> entries_;\n};"
        }
    }

    function selectFile(index) {
        if (index < 0 || index >= fileModel.count) {
            return
        }

        selectedFileIndex = index
        var entry = fileModel.get(index)
        selectedFilePath = entry.path
        editorKind = entry.kind
        editorPlainText = entry.content
    }

    function clamp(value, minValue, maxValue) {
        if (maxValue < minValue) {
            return maxValue
        }
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function clampPaneWidths() {
        var available = Math.max(0, shell.width - (workspaceMargin * 2) - (paneHandleWidth * 2))
        var minEditor = Math.min(paneMinEditorWidth, available)
        var maxLeft = Math.max(paneMinExplorerWidth, available - paneMinAgentWidth - minEditor)
        explorerPaneWidth = clamp(explorerPaneWidth, paneMinExplorerWidth, maxLeft)

        var maxRight = Math.max(paneMinAgentWidth, available - explorerPaneWidth - minEditor)
        agentPaneWidth = clamp(agentPaneWidth, paneMinAgentWidth, maxRight)

        var editorWidth = available - explorerPaneWidth - agentPaneWidth
        if (editorWidth < paneMinEditorWidth) {
            var deficit = paneMinEditorWidth - editorWidth
            var reduceRight = Math.min(deficit, agentPaneWidth - paneMinAgentWidth)
            agentPaneWidth -= reduceRight
            deficit -= reduceRight

            if (deficit > 0) {
                var reduceLeft = Math.min(deficit, explorerPaneWidth - paneMinExplorerWidth)
                explorerPaneWidth -= reduceLeft
            }
        }
    }

    function parseResultField(text, key) {
        var lines = (text || "").split("\n")
        var prefix = key + "="
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(prefix) === 0) {
                return lines[i].slice(prefix.length)
            }
        }
        return ""
    }

    function exportSavedPath(text) {
        return parseResultField(text, "saved_path")
    }

    function exportActiveSkill(text) {
        return parseResultField(text, "active_skill")
    }

    function exportSkillExecutionStatus(text) {
        return parseResultField(text, "skill_execution_status")
    }

    function exportTraceCount(text) {
        return parseResultField(text, "trace_count")
    }

    function exportRegistryVersion(text) {
        return parseResultField(text, "registry_version")
    }

    function exportPromoteCount(text) {
        return parseResultField(text, "promote_count")
    }

    function exportRetireCount(text) {
        return parseResultField(text, "retire_count")
    }

    function exportLastAction(text) {
        return parseResultField(text, "last_action")
    }

    function exportLastObservation(text) {
        return parseResultField(text, "last_observation")
    }

    function parseSkillRecords(text) {
        var lines = (text || "").split("\n")
        var records = []
        for (var i = 0; i < lines.length; ++i) {
            var match = /^skill\[(\d+)\]\.([a-z_]+)=(.*)$/.exec(lines[i])
            if (!match) {
                continue
            }
            var index = parseInt(match[1], 10)
            var field = match[2]
            var value = match[3]
            if (!records[index]) {
                records[index] = {
                    skill_index: index,
                    name: "",
                    version: "",
                    intent: "",
                    status: "",
                    created_step: "",
                    updated_step: "",
                    promote_count: "",
                    fail_count: "",
                    success_rate: "",
                    avg_steps: "",
                    tool_cost: "",
                    stability: ""
                }
            }
            records[index][field] = value
        }

        var compact = []
        for (var j = 0; j < records.length; ++j) {
            if (records[j]) {
                compact.push(records[j])
            }
        }
        return compact
    }

    function selectedSkillRecord() {
        var records = filteredDiagnosticsSkillRecords()
        for (var i = 0; i < records.length; ++i) {
            if ((records[i].name || "") === selectedSkillName) {
                return records[i]
            }
        }
        for (var j = 0; j < diagnosticsSkillRecords.length; ++j) {
            if ((diagnosticsSkillRecords[j].name || "") === selectedSkillName) {
                return diagnosticsSkillRecords[j]
            }
        }
        return null
    }

    function skillStatusOptions() {
        var seen = { "": true }
        var options = [""]
        for (var i = 0; i < diagnosticsSkillRecords.length; ++i) {
            var status = (diagnosticsSkillRecords[i].status || "").trim()
            if (!status.length || seen[status]) {
                continue
            }
            seen[status] = true
            options.push(status)
        }
        return options
    }

    function filteredDiagnosticsSkillRecords() {
        var filtered = []
        for (var i = 0; i < diagnosticsSkillRecords.length; ++i) {
            var item = diagnosticsSkillRecords[i]
            if (skillStatusFilter.length > 0 && (item.status || "") !== skillStatusFilter) {
                continue
            }
            if (skillActiveOnly && (item.name || "") !== exportActiveSkill(resultOutput.text)) {
                continue
            }
            if (skillHighFailOnly && parseInt(item.fail_count || "0", 10) < 2) {
                continue
            }
            filtered.push(item)
        }
        return filtered
    }

    function clearSelectedSkillIfFilteredOut() {
        if (!selectedSkillName.length) {
            return
        }
        var records = filteredDiagnosticsSkillRecords()
        for (var i = 0; i < records.length; ++i) {
            if ((records[i].name || "") === selectedSkillName) {
                return diagnosticsSkillRecords[i]
            }
        }
        selectedSkillName = ""
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
    }

    function skillRecordPreview(text, skillRecord) {
        if (!skillRecord) {
            return ""
        }
        var lines = (text || "").split("\n")
        var prefix = "skill[" + skillRecord.skill_index + "]."
        var preview = []
        var active = exportActiveSkill(text)
        var execution = exportSkillExecutionStatus(text)
        var savedPath = exportSavedPath(text)
        if (skillRecord.name) {
            preview.push("selected_skill=" + skillRecord.name)
        }
        if (active.length > 0) {
            preview.push("active_skill=" + active)
        }
        if (execution.length > 0) {
            preview.push("skill_execution_status=" + execution)
        }
        if (savedPath.length > 0) {
            preview.push("saved_path=" + savedPath)
        }
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(prefix) === 0) {
                preview.push(lines[i])
            }
        }
        return preview.join("\n")
    }

    function trajectoryPreviewForSkill(text, skillRecord) {
        if (!skillRecord) {
            return ""
        }

        var lines = (text || "").split("\n")
        var skillName = skillRecord.name || ""
        var headers = []
        var stepMap = {}
        var activePrefix = /^active_skill\[(\d+)\]=(.*)$/
        var fieldPrefix = /^(step|task|input|action|observation|ok|active_skill|tool|tool_timeout_ms|tool_retries)\[(\d+)\]=(.*)$/

        for (var i = 0; i < lines.length; ++i) {
            var headerMatch = /^([^\[]+)=/.exec(lines[i])
            var stepMatch = fieldPrefix.exec(lines[i])
            if (stepMatch) {
                var index = stepMatch[2]
                if (!stepMap[index]) {
                    stepMap[index] = []
                }
                stepMap[index].push(lines[i])
                continue
            }
            if (headerMatch && headerMatch[1].indexOf("skill") !== 0) {
                headers.push(lines[i])
            }
        }

        var filtered = []
        for (var j = 0; j < lines.length; ++j) {
            var activeMatch = activePrefix.exec(lines[j])
            if (!activeMatch) {
                continue
            }
            if ((activeMatch[2] || "") !== skillName) {
                continue
            }
            var stepLines = stepMap[activeMatch[1]]
            if (!stepLines) {
                continue
            }
            filtered.push(stepLines.join("\n"))
        }

        var preview = []
        preview.push("selected_skill=" + skillName)
        preview.push("filtered_trace_steps=" + filtered.length)
        if (headers.length > 0) {
            preview.push(headers.join("\n"))
        }
        if (filtered.length > 0) {
            preview.push(filtered.join("\n\n"))
        } else {
            preview.push("no_trace_steps_for_skill=true")
            preview.push(skillRecordPreview(text, skillRecord))
        }
        return preview.join("\n")
    }

    function traceStepsForSkill(text, skillRecord) {
        if (!skillRecord) {
            return []
        }

        var lines = (text || "").split("\n")
        var skillName = skillRecord.name || ""
        var stepMap = {}
        var orderedIndexes = []
        var activePrefix = /^active_skill\[(\d+)\]=(.*)$/
        var fieldPrefix = /^(step|task|input|action|observation|ok|active_skill|tool|tool_timeout_ms|tool_retries)\[(\d+)\]=(.*)$/

        for (var i = 0; i < lines.length; ++i) {
            var stepMatch = fieldPrefix.exec(lines[i])
            if (!stepMatch) {
                continue
            }
            var field = stepMatch[1]
            var index = stepMatch[2]
            var value = stepMatch[3]
            if (!stepMap[index]) {
                stepMap[index] = {
                    step: "",
                    task: "",
                    input: "",
                    action: "",
                    observation: "",
                    ok: "false",
                    active_skill: "",
                    tool: "",
                    tool_timeout_ms: "0",
                    tool_retries: "0"
                }
                orderedIndexes.push(index)
            }
            stepMap[index][field] = value
        }

        var filtered = []
        for (var j = 0; j < orderedIndexes.length; ++j) {
            var item = stepMap[orderedIndexes[j]]
            if ((item.active_skill || "") === skillName) {
                filtered.push(item)
            }
        }
        return filtered
    }

    function selectedSkillTraceSteps() {
        return traceStepsForSkill(resultOutput.text, selectedSkillRecord())
    }

    function selectedSkillTraceToolOptions() {
        var steps = selectedSkillTraceSteps()
        var seen = { "": true }
        var options = [""]
        for (var i = 0; i < steps.length; ++i) {
            var toolName = (steps[i].tool || "").trim()
            if (!toolName.length || seen[toolName]) {
                continue
            }
            seen[toolName] = true
            options.push(toolName)
        }
        return options
    }

    function filteredSelectedSkillTraceSteps() {
        var steps = selectedSkillTraceSteps()
        var filtered = []
        var searchText = (selectedSkillSearchText || "").trim().toLowerCase()
        for (var i = 0; i < steps.length; ++i) {
            var item = steps[i]
            if (selectedSkillFailedOnly && (item.ok || "false") === "true") {
                continue
            }
            if (selectedSkillToolFilter.length > 0 && (item.tool || "") !== selectedSkillToolFilter) {
                continue
            }
            if (searchText.length > 0) {
                var actionText = (item.action || "").toLowerCase()
                var observationText = (item.observation || "").toLowerCase()
                if (actionText.indexOf(searchText) < 0 && observationText.indexOf(searchText) < 0) {
                    continue
                }
            }
            filtered.push(item)
        }
        return filtered
    }

    function traceStepPreview(stepRecord) {
        if (!stepRecord) {
            return ""
        }

        var lines = []
        lines.push("step=" + (stepRecord.step || ""))
        lines.push("task=" + (stepRecord.task || ""))
        lines.push("input=" + (stepRecord.input || ""))
        lines.push("action=" + (stepRecord.action || ""))
        lines.push("observation=" + (stepRecord.observation || ""))
        lines.push("active_skill=" + (stepRecord.active_skill || ""))
        lines.push("tool=" + (stepRecord.tool || ""))
        lines.push("tool_timeout_ms=" + (stepRecord.tool_timeout_ms || "0"))
        lines.push("tool_retries=" + (stepRecord.tool_retries || "0"))
        lines.push("ok=" + (stepRecord.ok || "false"))
        return lines.join("\n")
    }

    function filteredSkillContextPreview() {
        var skillRecord = selectedSkillRecord()
        if (!skillRecord) {
            return ""
        }

        var preview = []
        var steps = filteredSelectedSkillTraceSteps()
        preview.push("selected_skill=" + (skillRecord.name || ""))
        preview.push("failed_only=" + (selectedSkillFailedOnly ? "true" : "false"))
        preview.push("tool_filter=" + (selectedSkillToolFilter || ""))
        preview.push("search_text=" + (selectedSkillSearchText || ""))
        preview.push("filtered_trace_steps=" + steps.length)
        preview.push(skillRecordPreview(resultOutput.text, skillRecord))
        if (steps.length > 0) {
            var blocks = []
            for (var i = 0; i < steps.length; ++i) {
                blocks.push(traceStepPreview(steps[i]))
            }
            preview.push(blocks.join("\n\n"))
        } else {
            preview.push("no_trace_steps_for_current_filters=true")
        }
        return preview.join("\n")
    }

    function openFilteredSkillContext() {
        var text = filteredSkillContextPreview()
        if (!text.length) {
            return
        }
        selectedFileIndex = -1
        selectedFilePath = exportSavedPath(resultOutput.text)
        editorKind = "Text"
        editorPlainText = text
        shell.copyNoticeText = qsTr("Opened context")
        copyNoticeTimer.restart()
    }

    function openTraceStep(stepRecord) {
        if (!stepRecord) {
            return
        }
        selectedFileIndex = -1
        selectedFilePath = exportSavedPath(resultOutput.text)
        editorKind = "Text"
        editorPlainText = traceStepPreview(stepRecord)
        shell.copyNoticeText = qsTr("Opened step")
        copyNoticeTimer.restart()
    }

    function openSavedExport(path) {
        var next = (path || "").trim()
        if (!next.length) {
            return
        }
        var text = Runtime.read_text_file(next)
        if (text.indexOf("read_text_file_failed:") === 0) {
            shell.copyNoticeText = qsTr("Open failed")
            copyNoticeTimer.restart()
            return
        }
        selectedFileIndex = -1
        selectedFilePath = next
        editorKind = "Text"
        editorPlainText = text
        shell.copyNoticeText = qsTr("Opened export")
        copyNoticeTimer.restart()
    }

    function activateSkillRecord(skillRecord) {
        if (!skillRecord) {
            return
        }
        selectedSkillName = skillRecord.name || ""
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        var skillName = (skillRecord.name || "").trim()
        if (skillName.length > 0) {
            promptEditor.text = qsTr("Inspect skill %1").arg(skillName)
            promptEditor.forceActiveFocus()
            promptEditor.cursorPosition = promptEditor.text.length
        }
        selectedFileIndex = -1
        selectedFilePath = exportSavedPath(resultOutput.text)
        editorKind = "Text"
        editorPlainText = trajectoryPreviewForSkill(resultOutput.text, skillRecord)
    }

    function openSelectedSkillExport() {
        var savedPath = exportSavedPath(resultOutput.text)
        if (savedPath.length > 0) {
            openSavedExport(savedPath)
            return
        }
        var skillRecord = selectedSkillRecord()
        if (skillRecord) {
            selectedFileIndex = -1
            selectedFilePath = ""
            editorKind = "Text"
            editorPlainText = trajectoryPreviewForSkill(resultOutput.text, skillRecord)
        }
    }

    function inspectSelectedSkill() {
        var skillRecord = selectedSkillRecord()
        if (!skillRecord) {
            return
        }
        var skillName = (skillRecord.name || "").trim()
        if (!skillName.length) {
            return
        }
        promptEditor.text = qsTr("Inspect skill %1").arg(skillName)
        promptEditor.forceActiveFocus()
        promptEditor.cursorPosition = promptEditor.text.length
    }

    function hasStructuredExport(text) {
        return exportSavedPath(text).length > 0
            || exportActiveSkill(text).length > 0
            || exportTraceCount(text).length > 0
            || exportRegistryVersion(text).length > 0
    }

    function isFailureResult(text) {
        return text.indexOf("runtime_") === 0
            || text.indexOf("local_model_") === 0
            || text.indexOf("repo_not_found") === 0
    }

    Connections {
        target: Runtime

        function onAgentRunFinished(result) {
            agentRunTimeoutTimer.stop()
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.finishConversation(result, shell.lastRunDurationText)
            shell.runtimeStatusText = isFailureResult(result) ? qsTr("failed #") + shell.runClickSeq : qsTr("done #") + shell.runClickSeq
            shell.agentRunning = false
        }
    }

    Timer {
        id: agentRunTimeoutTimer
        interval: shell.agentRunTimeoutMs
        repeat: false
        onTriggered: {
            if (!shell.agentRunning) {
                return
            }
            var timeoutText = qsTr("runtime_timeout: agent request exceeded %1s").arg(Math.round(shell.agentRunTimeoutMs / 1000))
            resultOutput.text = timeoutText
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", timeoutText)
                conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", timeoutText)
                conversationModel.setProperty(activeAssistantMessageIndex, "modeText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "planText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
                activeAssistantMessageIndex = -1
            }
            shell.runtimeStatusText = qsTr("failed #") + shell.runClickSeq
            shell.agentRunning = false
        }
    }

    Component.onCompleted: {
        selectFile(selectedFileIndex)
        if (Runtime.checkpointModelChoices.length > 0) {
            Runtime.localModelName = Runtime.checkpointModelChoices[0].value
        }
        clampPaneWidths()
    }
    onWidthChanged: clampPaneWidths()

    Rectangle {
        anchors.fill: parent
        color: shell.bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: shell.explorerPaneWidth
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: qsTr("Explorer")
                        color: shell.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Project files")
                        color: shell.textMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.panelAlt
                        border.color: shell.border

                        ListView {
                            id: fileView
                            anchors.fill: parent
                            anchors.margins: 10
                            model: fileModel
                            spacing: 8
                            clip: true
                            currentIndex: shell.selectedFileIndex

                            delegate: Rectangle {
                                required property int index
                                required property string label
                                required property string path
                                required property string kind

                                width: ListView.view.width
                                height: 72
                                radius: 12
                                color: ListView.isCurrentItem ? shell.selectionBg : shell.editorBg
                                border.color: ListView.isCurrentItem ? shell.accent : shell.border

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: shell.selectFile(index)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: label
                                            color: shell.textPrimary
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 20
                                            radius: 8
                                            color: shell.panelAlt
                                            border.color: shell.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: kind
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                            }
                                        }
                                    }

                                    Text {
                                        text: path
                                        color: shell.textMuted
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                }
            }

            Rectangle {
                Layout.preferredWidth: shell.paneHandleWidth
                Layout.fillHeight: true
                color: shell.bg

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: 5
                    color: shell.panelAlt
                    border.color: shell.border
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    property real dragStartX: 0
                    property int dragStartWidth: 0

                    onPressed: function(mouse) {
                        dragStartX = mouse.x
                        dragStartWidth = shell.explorerPaneWidth
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        var delta = mouse.x - dragStartX
                        var available = Math.max(0, shell.width - (shell.workspaceMargin * 2) - (shell.paneHandleWidth * 2))
                        var maxLeft = Math.max(shell.paneMinExplorerWidth, available - shell.paneMinAgentWidth - shell.paneMinEditorWidth)
                        shell.explorerPaneWidth = shell.clamp(dragStartWidth + delta, shell.paneMinExplorerWidth, maxLeft)
                        shell.clampPaneWidths()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.max(0, shell.width - (shell.workspaceMargin * 2) - shell.explorerPaneWidth - shell.agentPaneWidth - (shell.paneHandleWidth * 2))
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: qsTr("Editor")
                            color: shell.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: selectedFilePath
                            color: shell.textMuted
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 28
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Read only")
                                color: shell.textMuted
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.editorBg
                        border.color: shell.border
                        clip: true

                        Rectangle {
                            id: editorGutter
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 60
                            color: shell.lineNumberBg
                            border.color: shell.lineNumberBorder

                            Text {
                                id: editorLineNumbers
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                y: 12 - editorFlick.contentY
                                textFormat: Text.RichText
                                text: shell.lineNumberHtml(shell.editorPlainText)
                            }
                        }

                        Flickable {
                            id: editorFlick
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.left: editorGutter.right
                            anchors.margins: 1
                            contentWidth: Math.max(width, editorText.paintedWidth + 32)
                            contentHeight: editorText.paintedHeight + 24
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: editorText
                                width: Math.max(editorFlick.width - 32, paintedWidth + 4)
                                height: paintedHeight + 2
                                x: 16
                                y: 12
                                text: shell.highlightCode(shell.editorPlainText, shell.editorKind)
                                textFormat: TextEdit.RichText
                                readOnly: true
                                wrapMode: TextEdit.NoWrap
                                selectByMouse: true
                                color: shell.textPrimary
                                selectionColor: shell.accent
                                selectedTextColor: shell.bg
                                font.family: "Consolas"
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Select a file from Explorer to load it into the editor.")
                                color: shell.textMuted
                                visible: shell.editorPlainText.length === 0
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: qsTr("Status")
                            color: shell.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Editing %1").arg(selectedFilePath)
                            color: shell.textPrimary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.paneHandleWidth
                Layout.fillHeight: true
                color: shell.bg

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: 5
                    color: shell.panelAlt
                    border.color: shell.border
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    property real dragStartX: 0
                    property int dragStartWidth: 0

                    onPressed: function(mouse) {
                        dragStartX = mouse.x
                        dragStartWidth = shell.agentPaneWidth
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        var delta = mouse.x - dragStartX
                        var available = Math.max(0, shell.width - (shell.workspaceMargin * 2) - (shell.paneHandleWidth * 2))
                        var maxRight = Math.max(shell.paneMinAgentWidth, available - shell.explorerPaneWidth - shell.paneMinEditorWidth)
                        shell.agentPaneWidth = shell.clamp(dragStartWidth - delta, shell.paneMinAgentWidth, maxRight)
                        shell.clampPaneWidths()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.agentPaneWidth
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 8
                    anchors.bottomMargin: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("Conversation")
                            color: shell.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 440
                        Layout.minimumHeight: 320
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        Timer {
                            id: copyNoticeTimer
                            interval: 1200
                            repeat: false
                            onTriggered: shell.copyNoticeText = ""
                        }

                        ListView {
                            id: conversationList
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            spacing: 12
                            model: conversationModel
                            boundsBehavior: Flickable.StopAtBounds
                            onContentHeightChanged: positionViewAtEnd()

                            delegate: Item {
                                width: conversationList.width
                                height: bubbleRect.height

                                Timer {
                                    id: copyResetTimer
                                    interval: 3000
                                    repeat: false
                                    onTriggered: conversationModel.setProperty(index, "copied", false)
                                }

                                Rectangle {
                                    id: bubbleRect
                                    width: model.kind === "user"
                                        ? Math.max(180, parent.width * shell.userBubbleWidthRatio)
                                        : Math.max(260, parent.width * shell.assistantBubbleWidthRatio)
                                    height: bubbleColumn.implicitHeight + 20
                                    x: model.kind === "user" ? parent.width - width : 0
                                    radius: 12
                                    color: model.kind === "user" ? shell.userBubble : shell.agentBubble
                                    border.color: model.kind === "user" ? Qt.rgba(1, 1, 1, 0.06) : shell.border

                                    HoverHandler {
                                        id: bubbleHover
                                        target: bubbleRect
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    }

                                    Column {
                                        id: bubbleColumn
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        RowLayout {
                                            spacing: 8
                                            Layout.fillWidth: true

                                            Rectangle {
                                                visible: model.kind !== "user"
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: shell.accent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: qsTr("C")
                                                    color: shell.bg
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                text: model.label
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                visible: model.kind !== "user"
                                                text: model.durationText
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            ToolButton {
                                                enabled: !model.pending && model.text.length > 0
                                                visible: bubbleHover.hovered || model.copied
                                                opacity: enabled ? 1.0 : 0.45
                                                Layout.alignment: Qt.AlignTop
                                                width: 24
                                                height: 24
                                                padding: 0
                                                text: ""
                                                background: Rectangle {
                                                    radius: 6
                                                    color: model.copied ? Qt.rgba(0.10, 0.66, 0.45, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                                                    border.color: model.copied ? Qt.rgba(0.10, 0.66, 0.45, 0.48) : Qt.rgba(255, 255, 255, 0.06)
                                                }
                                                contentItem: Image {
                                                    anchors.centerIn: parent
                                                    width: 14
                                                    height: 14
                                                    source: model.copied ? "qrc:/neurx/app/icons/check.svg" : "qrc:/neurx/app/icons/copy.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    sourceSize.width: 14
                                                    sourceSize.height: 14
                                                    opacity: enabled ? 1.0 : 0.45
                                                    smooth: true
                                                    mipmap: true
                                                }
                                                onClicked: {
                                                    shell.copyConversationText(model.bodyText && model.bodyText.length > 0 ? model.bodyText : model.text)
                                                    conversationModel.setProperty(index, "copied", true)
                                                    copyResetTimer.restart()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: model.modeText && model.modeText.length > 0
                                            radius: 999
                                            color: Qt.rgba(0.10, 0.66, 0.45, 0.14)
                                            border.color: Qt.rgba(0.10, 0.66, 0.45, 0.42)
                                            height: 22
                                            width: modeLabel.implicitWidth + 14

                                            Text {
                                                id: modeLabel
                                                anchors.centerIn: parent
                                                text: model.modeText
                                                color: shell.accent
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            visible: model.planText && model.planText.length > 0
                                            width: Math.max(120, bubbleRect.width - 26)
                                            text: model.planText
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            color: shell.textMuted
                                            font.pixelSize: 11
                                        }

                                        TextEdit {
                                            width: Math.max(120, bubbleRect.width - 26)
                                            text: model.bodyText && model.bodyText.length > 0 ? model.bodyText : model.text
                                            readOnly: true
                                            selectByMouse: true
                                            selectByKeyboard: true
                                            activeFocusOnPress: true
                                            persistentSelection: true
                                            cursorVisible: false
                                            mouseSelectionMode: TextEdit.SelectCharacters
                                            textFormat: TextEdit.PlainText
                                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                            color: shell.textPrimary
                                            selectionColor: shell.selectionBg
                                            selectedTextColor: shell.textPrimary
                                            font.pixelSize: 13
                                        }
                                    }

                                }
                            }
                        }

                        Rectangle {
                            visible: shell.copyNoticeText.length > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            radius: 999
                            color: Qt.rgba(0.09, 0.12, 0.11, 0.92)
                            border.color: Qt.rgba(0.39, 0.67, 0.54, 0.55)
                            z: 10

                            Text {
                                anchors.margins: 6
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: shell.textPrimary
                                font.pixelSize: 10
                                text: shell.copyNoticeText
                            }
                        }

                        TextEdit {
                            id: resultOutput
                            visible: false
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            text: qsTr("Run the agent to see output here.")
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        text: qsTr("Send")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        Layout.maximumHeight: 88
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        TextEdit {
                            id: promptEditor
                            anchors.fill: parent
                            anchors.margins: 10
                            text: ""
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            font.pixelSize: 13
                            focus: true
                            Keys.priority: Keys.BeforeItem

                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true
                                    shell.sendAgentPrompt()
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: qsTr("Ask the agent to inspect files or summarize state")
                            color: shell.textMuted
                            visible: promptEditor.text.length === 0 && !promptEditor.activeFocus
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 116
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.agentRunning ? shell.panelHover : shell.accent

                            Text {
                                anchors.centerIn: parent
                                text: shell.agentRunning ? qsTr("Running...") : qsTr("Run")
                                color: shell.bg
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !shell.agentRunning
                                onClicked: shell.sendAgentPrompt()
                            }
                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: hasStructuredExport(resultOutput.text)
                        implicitHeight: exportDetailsColumn.implicitHeight + 20
                        radius: 12
                        color: shell.panelAlt
                        border.color: shell.border

                        ColumnLayout {
                            id: exportDetailsColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: qsTr("Diagnostics")
                                    color: shell.textPrimary
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                ToolButton {
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                    enabled: visible
                                    padding: 0
                                    width: 24
                                    height: 24
                                    text: ""
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Copy saved path")
                                    contentItem: Text {
                                        text: "⧉"
                                        color: shell.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 14
                                    }
                                    onClicked: shell.copyConversationText(exportSavedPath(resultOutput.text))
                                }

                                ToolButton {
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                    enabled: visible
                                    padding: 0
                                    width: 24
                                    height: 24
                                    text: ""
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Open export")
                                    contentItem: Text {
                                        text: "↗"
                                        color: shell.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 14
                                    }
                                    onClicked: shell.openSavedExport(exportSavedPath(resultOutput.text))
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 6

                                Text {
                                    text: qsTr("Saved Path")
                                    color: shell.textMuted
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportSavedPath(resultOutput.text)
                                    color: shell.textPrimary
                                    elide: Text.ElideMiddle
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Active Skill")
                                    color: shell.textMuted
                                    visible: exportActiveSkill(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportActiveSkill(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportActiveSkill(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Execution")
                                    color: shell.textMuted
                                    visible: exportSkillExecutionStatus(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportSkillExecutionStatus(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportSkillExecutionStatus(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Trace Count")
                                    color: shell.textMuted
                                    visible: exportTraceCount(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportTraceCount(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportTraceCount(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Registry Version")
                                    color: shell.textMuted
                                    visible: exportRegistryVersion(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportRegistryVersion(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportRegistryVersion(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Promotions")
                                    color: shell.textMuted
                                    visible: exportPromoteCount(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportPromoteCount(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportPromoteCount(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Retirements")
                                    color: shell.textMuted
                                    visible: exportRetireCount(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportRetireCount(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportRetireCount(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Last Action")
                                    color: shell.textMuted
                                    visible: exportLastAction(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportLastAction(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportLastAction(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Last Observation")
                                    color: shell.textMuted
                                    visible: exportLastObservation(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportLastObservation(resultOutput.text)
                                    color: shell.textPrimary
                                    wrapMode: Text.WrapAnywhere
                                    visible: exportLastObservation(resultOutput.text).length > 0
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: diagnosticsSkillRecords.length > 0
                                spacing: 6

                                Text {
                                    text: qsTr("Skills")
                                    color: shell.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ComboBox {
                                        id: skillStatusCombo
                                        Layout.preferredWidth: 170
                                        model: shell.skillStatusOptions()
                                        currentIndex: Math.max(0, model.indexOf(shell.skillStatusFilter))

                                        delegate: ItemDelegate {
                                            required property var modelData
                                            required property int index
                                            width: parent ? parent.width : 170
                                            text: modelData && modelData.length > 0 ? modelData : qsTr("All statuses")
                                        }

                                        contentItem: Text {
                                            leftPadding: 10
                                            rightPadding: 10
                                            verticalAlignment: Text.AlignVCenter
                                            text: skillStatusCombo.displayText
                                            color: shell.textPrimary
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        displayText: currentText && currentText.length > 0 ? currentText : qsTr("All statuses")
                                        onActivated: {
                                            shell.skillStatusFilter = currentValue || currentText || ""
                                            shell.clearSelectedSkillIfFilteredOut()
                                        }
                                    }

                                    Text {
                                        text: qsTr("%1 skills").arg(shell.filteredDiagnosticsSkillRecords().length)
                                        color: shell.textMuted
                                        font.pixelSize: 11
                                    }

                                    CheckBox {
                                        text: qsTr("Active only")
                                        checked: shell.skillActiveOnly
                                        onToggled: {
                                            shell.skillActiveOnly = checked
                                            shell.clearSelectedSkillIfFilteredOut()
                                        }
                                    }

                                    CheckBox {
                                        text: qsTr("High fail")
                                        checked: shell.skillHighFailOnly
                                        onToggled: {
                                            shell.skillHighFailOnly = checked
                                            shell.clearSelectedSkillIfFilteredOut()
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                Repeater {
                                    model: filteredDiagnosticsSkillRecords()

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: skillColumn.implicitHeight + 14
                                        radius: 10
                                        color: shell.editorBg
                                        border.color: shell.selectedSkillName === (modelData.name || "")
                                            ? shell.accent
                                            : skillMouse.containsMouse ? shell.accent : shell.border

                                        ColumnLayout {
                                            id: skillColumn
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    text: modelData.name || qsTr("(unnamed)")
                                                    color: shell.textPrimary
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: modelData.status || qsTr("unknown")
                                                    color: shell.textMuted
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: modelData.version || ""
                                                    color: shell.textMuted
                                                }

                                                ToolButton {
                                                    padding: 0
                                                    width: 22
                                                    height: 22
                                                    text: "⧉"
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: qsTr("Copy skill context")
                                                    onClicked: shell.copyConversationText(shell.skillRecordPreview(resultOutput.text, modelData))
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: qsTr("success=%1 stability=%2 avg_steps=%3 fail=%4 promote=%5")
                                                    .arg(modelData.success_rate || "0")
                                                    .arg(modelData.stability || "0")
                                                    .arg(modelData.avg_steps || "0")
                                                    .arg(modelData.fail_count || "0")
                                                    .arg(modelData.promote_count || "0")
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                wrapMode: Text.WrapAnywhere
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.intent || ""
                                                color: shell.textPrimary
                                                font.pixelSize: 11
                                                wrapMode: Text.WrapAnywhere
                                                visible: text.length > 0
                                            }
                                        }

                                        MouseArea {
                                            id: skillMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            z: -1
                                            onClicked: shell.activateSkillRecord(modelData)
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: shell.selectedSkillName.length > 0 && shell.selectedSkillRecord() !== null
                                    implicitHeight: selectedSkillColumn.implicitHeight + 16
                                    radius: 10
                                    color: Qt.rgba(0.10, 0.15, 0.13, 0.95)
                                    border.color: shell.accent

                                    ColumnLayout {
                                        id: selectedSkillColumn
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: qsTr("Selected Skill")
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            Text {
                                                text: shell.selectedSkillRecord() ? shell.selectedSkillRecord().name || "" : ""
                                                color: shell.textPrimary
                                                font.bold: true
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Inspect")
                                                onClicked: shell.inspectSelectedSkill()
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Copy")
                                                onClicked: shell.copyConversationText(shell.selectedSkillRecord().name || "")
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Open")
                                                onClicked: shell.openSelectedSkillExport()
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Context")
                                                onClicked: shell.openFilteredSkillContext()
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Copy all")
                                                onClicked: shell.copyConversationText(shell.filteredSkillContextPreview())
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: shell.selectedSkillRecord() ? shell.selectedSkillRecord().intent || "" : ""
                                            color: shell.textPrimary
                                            wrapMode: Text.WrapAnywhere
                                            visible: text.length > 0
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: shell.selectedSkillRecord()
                                                ? qsTr("status=%1 version=%2 success=%3 stability=%4 avg_steps=%5 fail=%6 promote=%7")
                                                    .arg(shell.selectedSkillRecord().status || "unknown")
                                                    .arg(shell.selectedSkillRecord().version || "")
                                                    .arg(shell.selectedSkillRecord().success_rate || "0")
                                                    .arg(shell.selectedSkillRecord().stability || "0")
                                                    .arg(shell.selectedSkillRecord().avg_steps || "0")
                                                    .arg(shell.selectedSkillRecord().fail_count || "0")
                                                    .arg(shell.selectedSkillRecord().promote_count || "0")
                                                : ""
                                            color: shell.textMuted
                                            font.pixelSize: 11
                                            wrapMode: Text.WrapAnywhere
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: shell.selectedSkillTraceSteps().length > 0
                                            spacing: 6

                                            Text {
                                                text: qsTr("Trace Steps")
                                                color: shell.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                CheckBox {
                                                    text: qsTr("Failed only")
                                                    checked: shell.selectedSkillFailedOnly
                                                    onToggled: shell.selectedSkillFailedOnly = checked
                                                }

                                                ComboBox {
                                                    id: selectedSkillToolCombo
                                                    Layout.preferredWidth: 160
                                                    model: shell.selectedSkillTraceToolOptions()
                                                    currentIndex: Math.max(0, model.indexOf(shell.selectedSkillToolFilter))

                                                    delegate: ItemDelegate {
                                                        required property var modelData
                                                        required property int index
                                                        width: parent ? parent.width : 160
                                                        text: modelData && modelData.length > 0 ? modelData : qsTr("All tools")
                                                    }

                                                    contentItem: Text {
                                                        leftPadding: 10
                                                        rightPadding: 10
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: selectedSkillToolCombo.displayText
                                                        color: shell.textPrimary
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }

                                                    displayText: currentText && currentText.length > 0 ? currentText : qsTr("All tools")
                                                    onActivated: shell.selectedSkillToolFilter = currentValue || currentText || ""
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 180
                                                    Layout.preferredHeight: 30
                                                    radius: 8
                                                    color: shell.editorBg
                                                    border.color: shell.border

                                                    TextInput {
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        text: shell.selectedSkillSearchText
                                                        color: shell.textPrimary
                                                        font.pixelSize: 12
                                                        verticalAlignment: Text.AlignVCenter
                                                        clip: true
                                                        selectByMouse: true
                                                        onTextChanged: shell.selectedSkillSearchText = text
                                                    }

                                                    Text {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: qsTr("Search action/observation")
                                                        color: shell.textMuted
                                                        font.pixelSize: 12
                                                        visible: shell.selectedSkillSearchText.length === 0
                                                    }
                                                }

                                                Text {
                                                    text: qsTr("%1 steps").arg(shell.filteredSelectedSkillTraceSteps().length)
                                                    color: shell.textMuted
                                                    font.pixelSize: 11
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            Text {
                                                visible: shell.filteredSelectedSkillTraceSteps().length === 0
                                                text: qsTr("No steps match the current filters")
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                            }

                                            Repeater {
                                                model: shell.filteredSelectedSkillTraceSteps()

                                                delegate: Rectangle {
                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    implicitHeight: stepColumn.implicitHeight + 14
                                                    radius: 8
                                                    color: shell.editorBg
                                                    border.color: shell.border

                                                    ColumnLayout {
                                                        id: stepColumn
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: 4

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 8

                                                            Text {
                                                                text: qsTr("Step %1").arg(modelData.step || "?")
                                                                color: shell.textPrimary
                                                                font.bold: true
                                                            }

                                                            Text {
                                                                text: modelData.task || qsTr("unknown")
                                                                color: shell.textMuted
                                                            }

                                                            Item {
                                                                Layout.fillWidth: true
                                                            }

                                                            ToolButton {
                                                                text: qsTr("Copy")
                                                                onClicked: shell.copyConversationText(shell.traceStepPreview(modelData))
                                                            }

                                                            ToolButton {
                                                                text: qsTr("Open")
                                                                onClicked: shell.openTraceStep(modelData)
                                                            }

                                                            Text {
                                                                text: (modelData.ok || "false") === "true" ? qsTr("ok") : qsTr("failed")
                                                                color: (modelData.ok || "false") === "true" ? shell.accent : "#e57373"
                                                                font.bold: true
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("tool=%1 timeout=%2 retries=%3")
                                                                .arg(modelData.tool || "-")
                                                                .arg(modelData.tool_timeout_ms || "0")
                                                                .arg(modelData.tool_retries || "0")
                                                            color: shell.textMuted
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("action: %1").arg(modelData.action || "")
                                                            color: shell.textPrimary
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                            visible: text.length > 8
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("input: %1").arg(modelData.input || "")
                                                            color: shell.textMuted
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                            visible: text.length > 7
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("observation: %1").arg(modelData.observation || "")
                                                            color: shell.textPrimary
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                            visible: text.length > 13
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}
